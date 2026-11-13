#!/usr/bin/env python3
"""Focused tests for pinned successful-step reuse; no network or Apple runner."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('reuse', ROOT/'tools/ci/verify-approved-native-evidence.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)


class ReuseTests(unittest.TestCase):
    def metadata(self):
        run = dict(id=m.RUN,head_sha=m.BASE,status='completed',conclusion='failure')
        job = dict(id=m.JOB,run_id=m.RUN,status='completed',conclusion='failure',steps=[dict(name=n,status='completed',conclusion='success')for n in m.REQUIRED_STEPS])
        artifact = dict(id=m.ARTIFACT,workflow_run=dict(id=m.RUN,head_sha=m.BASE),expired=False,digest='sha256:'+m.DIGEST)
        return run, job, artifact

    def test_only_successful_steps_of_failed_build_reused(self):
        m.verify_metadata(*self.metadata())

    def test_skipped_or_failed_native_step_rejected(self):
        for conclusion in ('failure','skipped',None):
            args = self.metadata(); args[1]['steps'][0]['conclusion'] = conclusion
            with self.assertRaises(ValueError): m.verify_metadata(*args)

    def test_duplicate_step_rejected(self):
        args=self.metadata();args[1]['steps'].append(args[1]['steps'][0])
        with self.assertRaises(ValueError):m.verify_metadata(*args)

    def test_other_run_job_or_artifact_rejected(self):
        for index in range(3):
            args=self.metadata();args[index]['id']=0
            with self.assertRaises(ValueError):m.verify_metadata(*args)
        args=self.metadata();args[2]['workflow_run']['head_sha']='0'*40
        with self.assertRaises(ValueError):m.verify_metadata(*args)

    def test_expired_or_changed_artifact_rejected(self):
        for field,value in [('expired',True),('digest','sha256:'+'0'*64)]:
            args=self.metadata();args[2][field]=value
            with self.assertRaises(ValueError):m.verify_metadata(*args)

    def test_real_artifact_when_supplied(self):
        import os
        if not os.environ.get('BCD_NATIVE_EVIDENCE_ZIP'):self.skipTest('optional real artifact not supplied')
        data=Path(os.environ['BCD_NATIVE_EVIDENCE_ZIP']).read_bytes()
        files=m.verified_files(data)
        self.assertEqual(sum(n.endswith('.png')for n in files),59)
        with self.assertRaisesRegex(ValueError,'hash mismatch'):m.verified_files(data+b'changed')

    def test_source_and_fixture_changes_fail(self):
        with tempfile.TemporaryDirectory()as d:
            root=Path(d)
            def git(*a):return subprocess.check_output(['git',*a],cwd=root,stderr=subprocess.DEVNULL,text=True).strip()
            git('init');git('config','user.email','test@example.invalid');git('config','user.name','Test')
            (root/'app').mkdir();(root/'app/Main.swift').write_text('original')
            (root/'.github/workflows').mkdir(parents=True);wf=root/'.github/workflows/touch-profiles-ipa.yml';wf.write_text('old')
            git('add','.');git('commit','-qm','base');old=m.BASE;m.BASE=git('rev-parse','HEAD')
            try:
                wf.write_text('workflow only');git('add','.');git('commit','-qm','workflow')
                m.verify_source(root)
                (root/'app/Main.swift').write_text('uncommitted')
                with self.assertRaises(ValueError):m.verify_source(root)
                git('add','.');git('commit','-qm','production')
                with self.assertRaises(ValueError):m.verify_source(root)
            finally:m.BASE=old


if __name__=='__main__':unittest.main()
