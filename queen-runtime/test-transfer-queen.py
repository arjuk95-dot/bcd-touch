import asyncio
import importlib.util
import json
from pathlib import Path, PurePosixPath
import plistlib
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('transfer',Path(__file__).with_name('transfer-queen.py'))
transfer=importlib.util.module_from_spec(spec);spec.loader.exec_module(transfer)

class AFC:
    def __init__(self,files=None,readonly=False):
        self.files=dict(files or {});self.dirs={'/'};self.handles={};self.next=0;self.writes=[];self.readonly=readonly;self.corrupt=False
        for path in self.files:
            self.dirs.update(str(p) for p in PurePosixPath(path).parents)
    async def exists(self,p):return p in self.files or p in self.dirs
    async def isdir(self,p):return p in self.dirs
    async def stat(self,p):
        return {'st_ifmt':'S_IFDIR' if p in self.dirs else 'S_IFREG','st_size':len(self.files.get(p,b'')),'st_mtime':1}
    async def listdir(self,p):return sorted({PurePosixPath(x).parts[len(PurePosixPath(p).parts)] for x in self.files|dict.fromkeys(self.dirs) if x.startswith(p.rstrip('/')+'/') and x!=p})
    async def get_file_contents(self,p):return self.files[p]
    async def fopen(self,p,mode='r'):
        if mode=='w':
            if self.readonly:raise AssertionError('Source write attempted')
            self.files[p]=b'';self.writes.append(('open',p))
        else:assert p in self.files,p
        self.next+=1;self.handles[self.next]=[p,0];return self.next
    async def fread(self,h,n):
        p,offset=self.handles[h];data=self.files[p][offset:offset+n];self.handles[h][1]+=len(data)
        if self.corrupt and data:data=bytes([data[0]^1])+data[1:]
        return data
    async def fwrite(self,h,data):
        p,_=self.handles[h];self.files[p]+=data;self.writes.append(('write',p))
    async def fclose(self,h):del self.handles[h]
    async def makedirs(self,p):
        if self.readonly:raise AssertionError('Source mkdir attempted')
        self.dirs.add(p);self.writes.append(('mkdir',p))
    async def rename(self,source,dest):
        assert dest not in self.files
        self.files[dest]=self.files.pop(source);self.writes.append(('rename',dest))


class TransferTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp=tempfile.TemporaryDirectory();self.folder=Path(self.temp.name)/'backup'
        self.entry={'id':'unchanged-queen-id','title':'Queen','relativePath':'Games/QueensDomain/QueensDomain/Binaries/Win64/QueensDomain-Win64-Shipping.exe','controlLayout':'personal-original','controls':[{'x':.25}]}
        self.source=AFC({'/Documents/bcd-library.json':json.dumps({'version':1,'entries':[self.entry,{'relativePath':'Games/Other/Other.exe'}]}).encode(),
            '/Documents/wine/drive_c/'+self.entry['relativePath']:b'x'*(transfer.CHUNK+17),
            '/Documents/wine/drive_c/users/mobile/AppData/Local/QueensDomain/Saved/SaveGames/slot.sav':b'save-exact',
            '/Documents/bcd-controls.json':b'controls-exact',
            '/Documents/TouchPacks/personal-edits-v2.json':b'personal-exact',
            '/Documents/TouchPacks/worker.json':b'private-worker-secret',
            '/Library/Preferences/com.thebcd69.bcd.signed.plist':plistlib.dumps({'TouchPackLocal.queen':True,'steam-token':'must-not-copy'})},readonly=True)
        self.original=dict(self.source.files)
        await transfer.export(self.source,'com.thebcd69.bcd.signed','Games/QueensDomain',self.folder)
    async def asyncTearDown(self):self.temp.cleanup()
    async def test_round_trip_preserves_game_save_controls_id_and_source(self):
        dest=AFC();await transfer.restore(dest,transfer.IDENTITY+'.signed',self.folder)
        self.assertEqual(self.original,self.source.files)
        for path in self.original:
            if path.startswith('/Documents/wine/') or path.endswith(('bcd-controls.json','personal-edits-v2.json')):
                self.assertEqual(self.original[path],dest.files[path])
        self.assertEqual(json.loads(dest.files['/Documents/bcd-library.json'])['entries'],[self.entry])
        prefs=plistlib.loads(dest.files['/Library/Preferences/'+transfer.IDENTITY+'.signed.plist'])
        self.assertEqual(prefs,{'TouchPackLocal.queen':True})
        self.assertFalse(any('worker.json' in p for p in dest.files))
        self.assertEqual(dest.writes[-1],('rename','/Documents/bcd-library.json'))
    async def test_existing_destination_refused_before_write(self):
        dest=AFC({'/Documents/bcd-controls.json':b'existing'})
        with self.assertRaises(ValueError):await transfer.restore(dest,transfer.IDENTITY,self.folder)
        self.assertEqual(dest.writes,[]);self.assertEqual(dest.files['/Documents/bcd-controls.json'],b'existing')
    async def test_original_app_cannot_be_restore_target(self):
        dest=AFC()
        with self.assertRaises(ValueError):await transfer.restore(dest,'com.thebcd69.bcd.signed',self.folder)
        self.assertEqual(dest.writes,[])
    async def test_tampered_backup_refused_before_write(self):
        (self.folder/'Documents/bcd-controls.json').write_bytes(b'tampered')
        dest=AFC()
        with self.assertRaises(ValueError):await transfer.restore(dest,transfer.IDENTITY,self.folder)
        self.assertEqual(dest.writes,[])
    async def test_path_escape_refused_before_write(self):
        p=self.folder/'manifest.json';m=json.loads(p.read_text());m['files']['../escape']={'bytes':0,'sha256':'x'};p.write_text(json.dumps(m))
        dest=AFC()
        with self.assertRaises(ValueError):await transfer.restore(dest,transfer.IDENTITY,self.folder)
        self.assertEqual(dest.writes,[])
    async def test_internal_backup_link_refused_before_write(self):
        original=self.folder/'Documents/bcd-controls.json'
        real=self.folder/'Documents/controls-real.json'
        original.rename(real)
        try:original.symlink_to(real.name)
        except (OSError,NotImplementedError):self.skipTest('Local file links unavailable')
        dest=AFC()
        with self.assertRaises(ValueError):await transfer.restore(dest,transfer.IDENTITY,self.folder)
        self.assertEqual(dest.writes,[])
    async def test_corrupt_remote_copy_not_committed(self):
        dest=AFC();dest.corrupt=True
        with self.assertRaises(IOError):await transfer.restore(dest,transfer.IDENTITY,self.folder)
        self.assertNotIn('/Documents/bcd-library.json',dest.files)
        self.assertFalse(any(op=='rename' for op,_ in dest.writes))

if __name__=='__main__':unittest.main()
