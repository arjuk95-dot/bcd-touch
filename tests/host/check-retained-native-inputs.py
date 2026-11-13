#!/usr/bin/env python3
"""Portable adversarial checks for retained native inputs; no engine compilation."""
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('retained',ROOT/'tools/ci/restore-native-link-inputs.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
REAL=json.loads(m.PIN.read_text())

class RetainedTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name).resolve();self.path=self.root/'native.zip'
        self.p=copy.deepcopy(REAL)
        self.payload={name:(b'!<arch>\n' if name in self.p['archives'] else b'')+name.encode()
                      for name in self.p['archives']|self.p['headers']}
        for group in ('archives','headers'):
            self.p[group]={n:dict(bytes=len(self.payload[n]),sha256=m.sha(self.payload[n])) for n in self.p[group]}
        self.extra_tar=[];self.extra_zip=[];self.manifest_verified=True;self.repack()

    def repack(self):
        out=io.BytesIO()
        with tarfile.open(fileobj=out,mode='w:gz') as t:
            for n,b in self.payload.items():
                if n.startswith('FEX/'):
                    i=tarfile.TarInfo(n);i.size=len(b);t.addfile(i,io.BytesIO(b))
            for i,b in self.extra_tar:t.addfile(i,io.BytesIO(b))
        with zipfile.ZipFile(self.path,'w') as z:
            for n,b in self.payload.items():
                if n.startswith('app/'):z.writestr('link-inputs/'+Path(n).name,b)
            z.writestr('FEX-ios-link-inputs.tar.gz',out.getvalue())
            z.writestr('native-link-inputs.json',json.dumps(dict(architecture_verified=self.manifest_verified,archives=self.p['archives'])))
            z.writestr('toolchain.txt',self.p['toolchain']);z.writestr('source-pins.txt','pins')
            for n,b in self.extra_zip:z.writestr(n,b)
        self.p['sha256']=m.sha(self.path.read_bytes());self.p['source_pins_sha256']=m.sha(b'pins')

    def test_valid_inputs_and_safe_stage(self):
        files,manifest=m.read_artifact(self.path,self.p)
        self.assertEqual(len(files),26);self.assertTrue(manifest['architecture_verified'])
        m.stage_files(self.root/'repo',files)
        for n,b in files.items():self.assertEqual((self.root/'repo'/n).read_bytes(),b)

    def test_artifact_tampering(self):
        self.path.write_bytes(self.path.read_bytes()+b'x')
        with self.assertRaisesRegex(ValueError,'hash/size'):m.read_artifact(self.path,self.p)

    def test_unverified_source_manifest(self):
        self.manifest_verified=False;self.repack()
        with self.assertRaisesRegex(ValueError,'manifest'):m.read_artifact(self.path,self.p)

    def test_changed_library_bytes(self):
        self.payload['app/Madeira/libntdll_unix.a']+=b'changed';self.repack()
        with self.assertRaisesRegex(ValueError,'hash mismatch'):m.read_artifact(self.path,self.p)

    def test_changed_generated_header(self):
        self.payload[next(iter(self.p['headers']))]+=b'changed';self.repack()
        with self.assertRaisesRegex(ValueError,'hash mismatch'):m.read_artifact(self.path,self.p)

    def test_zip_traversal(self):
        self.extra_zip=[('../escape',b'no')];self.repack()
        with self.assertRaisesRegex(ValueError,'Unsafe'):m.read_artifact(self.path,self.p)

    def test_tar_traversal_and_link(self):
        for n,kind in [('FEX/build-ios/../../escape',tarfile.REGTYPE),('FEX/build-ios/link',tarfile.SYMTYPE)]:
            i=tarfile.TarInfo(n);i.type=kind;i.linkname='/tmp/out'
            self.extra_tar=[(i,b'')];self.repack()
            with self.assertRaises(ValueError):m.read_artifact(self.path,self.p)

    def test_symlink_stage_refused(self):
        repo=self.root/'repo';repo.mkdir();(repo/'app').symlink_to(self.root,target_is_directory=True)
        with self.assertRaisesRegex(ValueError,'Symlink'):m.stage_files(repo,{'app/file':b'no'})

    def test_arm64_command_input_before_variadic_architectures(self):
        with mock.patch.object(m.subprocess,'check_output',return_value=self.p['toolchain']),mock.patch.object(m.subprocess,'run') as run:
            m.validate_mac(self.root,self.p)
            self.assertEqual(run.call_count,20)
            for call in run.call_args_list:
                self.assertEqual(call.args[0][:2],['xcrun','lipo'])
                self.assertEqual(call.args[0][-2:],['-verify_arch','arm64'])
                self.assertEqual(call.kwargs,dict(check=True))

    def test_metadata_requires_successful_run_job_and_unique_stages(self):
        p=self.p
        a=dict(id=p['artifact'],name='BCD-v653-native-link-inputs',workflow_run=dict(id=p['run'],head_sha=p['head']),expired=False,digest='sha256:'+p['sha256'])
        r=dict(id=p['run'],head_sha=p['head'],status='completed',conclusion='success')
        j=dict(id=p['job'],run_id=p['run'],status='completed',conclusion='success',steps=[dict(name=n,status='completed',conclusion='success') for n in ['Require donor-compatible shader converter identity','Retain exact native link inputs for subsequent app-only updates','Archive (unsigned)']])
        m.verify_metadata(p,a,r,j)
        for item,key,value in [(a,'expired',True),(a,'digest','wrong'),(r,'head_sha','wrong'),(r,'conclusion','failure'),(j,'conclusion','failure')]:
            original=item[key];item[key]=value
            with self.assertRaises(ValueError):m.verify_metadata(p,a,r,j)
            item[key]=original
        j['steps'].append(j['steps'][0])
        with self.assertRaises(ValueError):m.verify_metadata(p,a,r,j)

    def test_real_pinned_artifact_if_provided(self):
        path=os.getenv('BCD_RETAINED_NATIVE_ZIP')
        if not path:self.skipTest('Exact artifact not supplied')
        files,manifest=m.read_artifact(path,REAL)
        self.assertEqual(len(files),26);self.assertTrue(manifest['architecture_verified'])

if __name__=='__main__':unittest.main()
