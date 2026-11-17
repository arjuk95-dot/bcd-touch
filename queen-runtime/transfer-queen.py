"""Copy-only Queen transfer. Export reads BCD; restore writes a fresh Queen runtime.

Keep both apps closed. A private local backup is retained. No delete operation is
used, no network upload is performed, and existing destination files are refused.
"""
import argparse
import asyncio
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re

IDENTITY = 'com.arjunkl.queensdomain.runtime'
EXE = 'queensdomain-win64-shipping.exe'
CHUNK = 1024 * 1024


def safe(path):
    if not path or '\\' in path or ':' in path or '\x00' in path:
        raise ValueError('Unsafe relative path')
    p = PurePosixPath(path)
    if p.is_absolute() or any(x in ('', '.', '..') for x in path.split('/')):
        raise ValueError('Unsafe relative path')
    return p


def target_allowed(app):
    if app != IDENTITY and not app.startswith(IDENTITY + '.'):
        raise ValueError('Restore target must be the separate Queen runtime bundle')


def allowed(path, game_root):
    safe(path)
    prefixes = ['Documents/wine/drive_c/' + game_root + '/',
                'Documents/wine/drive_c/users/mobile/AppData/Local/QueensDomain/Saved/']
    return (any(path.startswith(p) for p in prefixes)
            or path in {'Documents/bcd-library.json', 'Documents/bcd-controls.json',
                        'Documents/bcd-control-presets.json', 'preferences.plist'}
            or (path.startswith('Documents/TouchPacks/') and path.endswith('.json')
                and PurePosixPath(path).name not in {'worker.json', 'jobs.json'})
            or re.fullmatch(r'Library/Application Support/GameConfigs/[0-9a-f]{16}\.cfg', path) is not None)


async def read_stream(service, remote, destination):
    before = await service.stat(remote)
    if before.get('st_ifmt') != 'S_IFREG':
        raise ValueError('Only regular files may be transferred: ' + remote)
    size = int(before['st_size'])
    handle = await service.fopen(remote, 'r')
    digest = hashlib.sha256()
    count = 0
    try:
        with destination.open('xb') as out:
            while count < size:
                data = await service.fread(handle, min(CHUNK, size - count))
                if not data:
                    raise IOError('Unexpected end of file: ' + remote)
                out.write(data); digest.update(data); count += len(data)
    finally:
        await service.fclose(handle)
    after = await service.stat(remote)
    if int(after['st_size']) != size or after.get('st_mtime') != before.get('st_mtime'):
        raise IOError('Source changed while copying; keep BCD closed: ' + remote)
    return {'bytes': count, 'sha256': digest.hexdigest()}


async def walk_files(service, remote):
    info = await service.stat(remote)
    kind = info.get('st_ifmt')
    if kind == 'S_IFREG':
        yield remote
    elif kind == 'S_IFDIR':
        for name in sorted(await service.listdir(remote)):
            if name in ('.', '..', ''):
                continue
            if '/' in name or '\\' in name or ':' in name:
                raise ValueError('Unsafe device directory entry')
            async for path in walk_files(service, remote.rstrip('/') + '/' + name):
                yield path
    else:
        raise ValueError('Links and special files are not copied: ' + remote)


async def export(service, source_app, game_root, output, profile=None):
    safe(game_root)
    if source_app == IDENTITY or source_app.startswith(IDENTITY + '.'):
        raise ValueError('Export source must be the existing BCD app')
    output.mkdir(parents=True, exist_ok=False)
    (output / '.gitignore').write_text('*\n', encoding='utf-8')
    library = json.loads(await service.get_file_contents('/Documents/bcd-library.json'))
    games = [e for e in library['entries'] if any(str(e.get(k, '')).replace('\\', '/').lower().endswith(EXE)
             for k in ('relativePath', 'steamProgram', 'program'))]
    if len(games) != 1:
        raise ValueError('Expected one Queen shipping executable in the existing library')
    entry = games[0]
    if not str(entry['relativePath']).replace('\\', '/').lower().startswith(game_root.lower().rstrip('/') + '/'):
        # Steam entries identify the containing game folder rather than its executable.
        if str(entry['relativePath']).replace('\\', '/').lower() != game_root.lower():
            raise ValueError('The selected game-root does not contain the Queen library entry')
    files = {}
    roots = ['/Documents/wine/drive_c/' + game_root,
             '/Documents/wine/drive_c/users/mobile/AppData/Local/QueensDomain/Saved',
             '/Documents/bcd-controls.json', '/Documents/bcd-control-presets.json', '/Documents/TouchPacks']
    if profile:
        if not re.fullmatch(r'[0-9a-f]{16}\.cfg', profile):
            raise ValueError('Expected the exact 16-hex Queen GameConfigs filename')
        roots.append('/Library/Application Support/GameConfigs/' + profile)
    for remote_root in roots:
        if not await service.exists(remote_root):
            continue
        async for remote in walk_files(service, remote_root):
            relative = remote.lstrip('/')
            if not allowed(relative, game_root):
                continue
            local = output / safe(relative)
            local.parent.mkdir(parents=True, exist_ok=True)
            files[relative] = await read_stream(service, remote, local)
            print('COPIED', relative, files[relative]['bytes'], flush=True)
    payload = json.dumps({'version': library['version'], 'entries': [entry]}, ensure_ascii=False, indent=2).encode('utf-8')
    local = output/'Documents/bcd-library.json'; local.parent.mkdir(parents=True,exist_ok=True);local.write_bytes(payload)
    files['Documents/bcd-library.json'] = {'bytes':len(payload),'sha256':hashlib.sha256(payload).hexdigest()}
    preferences = '/Library/Preferences/' + source_app + '.plist'
    if await service.exists(preferences):
        raw = plistlib.loads(await service.get_file_contents(preferences))
        prefixes = ('TouchPack', 'madeira.touch.', 'madeira.controls.', 'madeira.gyro.', 'madeira.library.')
        selected = {k:v for k,v in raw.items() if k.startswith(prefixes)}
        payload = plistlib.dumps(selected, fmt=plistlib.FMT_BINARY)
        (output/'preferences.plist').write_bytes(payload)
        files['preferences.plist'] = {'bytes':len(payload),'sha256':hashlib.sha256(payload).hexdigest()}
    manifest={'schema':1,'source_app':source_app,'game_root':game_root,'files':files,'source_modified':False}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    return manifest


def validate_backup(folder):
    manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    assert manifest['schema']==1
    safe(manifest['game_root'])
    folded=set()
    for relative,spec in manifest['files'].items():
        if not allowed(relative,manifest['game_root']) or relative.casefold() in folded:
            raise ValueError('Invalid or case-colliding backup path')
        folded.add(relative.casefold())
        file=folder/safe(relative)
        if not file.resolve(strict=True).is_relative_to(folder.resolve(strict=True)):
            raise ValueError('Backup path escapes selected root')
        cursor=file
        while cursor != folder:
            if cursor.is_symlink() or getattr(cursor, 'is_junction', lambda: False)():
                raise ValueError('Backup links are not supported')
            cursor=cursor.parent
        with file.open('rb') as stream:
            digest=hashlib.file_digest(stream,'sha256').hexdigest()
        if file.stat().st_size!=spec['bytes'] or digest!=spec['sha256']:
            raise ValueError('Backup integrity failed: '+relative)
    return manifest


async def mkdirs(service,path):
    current=''
    for part in path.strip('/').split('/'):
        current+='/'+part
        if not await service.exists(current):
            await service.makedirs(current)
        elif not await service.isdir(current):
            raise ValueError('Destination parent is not a directory')


async def restore(service,target_app,folder):
    target_allowed(target_app)
    manifest=validate_backup(folder)
    if target_app==manifest['source_app']:
        raise ValueError('Source and target apps must be different')
    def remote(relative):
        return '/Library/Preferences/'+target_app+'.plist' if relative=='preferences.plist' else '/'+relative
    # Complete preflight before the first write. No existing destination file is overwritten.
    for relative in manifest['files']:
        if await service.exists(remote(relative)) or await service.exists(remote(relative)+'.queen-partial'):
            raise ValueError('Destination already contains '+remote(relative)+'; use a fresh runtime container')
    completed=[]
    for relative in sorted(manifest['files'],key=lambda p:p=='Documents/bcd-library.json'):
        dest=remote(relative);temp=dest+'.queen-partial';spec=manifest['files'][relative]
        await mkdirs(service,str(PurePosixPath(dest).parent))
        handle=await service.fopen(temp,'w')
        try:
            with (folder/safe(relative)).open('rb') as stream:
                while data:=stream.read(CHUNK):
                    await service.fwrite(handle,data)
        finally:
            await service.fclose(handle)
        handle=await service.fopen(temp,'r');digest=hashlib.sha256();count=0
        try:
            while count<spec['bytes']:
                data=await service.fread(handle,min(CHUNK,spec['bytes']-count))
                if not data: raise IOError('Incomplete destination copy')
                count+=len(data);digest.update(data)
        finally:
            await service.fclose(handle)
        if count!=spec['bytes'] or digest.hexdigest()!=spec['sha256']:
            raise IOError('Destination verification failed: '+dest)
        if await service.exists(dest):
            raise ValueError('Destination appeared during transfer; app must remain closed')
        await service.rename(temp,dest)
        completed.append(dest);print('VERIFIED',dest,flush=True)
    return {'target_app':target_app,'completed':completed,'source_modified':False}


async def main(args):
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.house_arrest import HouseArrestService
    if args.mode=='restore': target_allowed(args.app)
    device=await create_using_usbmux(serial=args.serial,connection_type='USB')
    service=None
    try:
        service=await HouseArrestService.create(device,args.app,documents_only=False)
        if args.mode=='export': result=await export(service,args.app,args.game_root,args.output,args.profile)
        else: result=await restore(service,args.app,args.input)
        print(json.dumps(result,indent=2))
    finally:
        if service: await service.close()
        await device.close()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest='mode',required=True)
    for mode in ('export','restore'):
        q=sub.add_parser(mode);q.add_argument('--serial',required=True);q.add_argument('--app',required=True)
        if mode=='export':
            q.add_argument('--game-root',required=True,help='Game folder relative to BCD drive_c')
            q.add_argument('--output',required=True,type=Path);q.add_argument('--profile',help='Exact Queen GameConfigs hex filename')
        else:q.add_argument('--input',required=True,type=Path)
    asyncio.run(main(p.parse_args()))
