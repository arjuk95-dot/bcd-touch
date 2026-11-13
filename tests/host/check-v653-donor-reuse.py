#!/usr/bin/env python3
"""Portable adversarial tests of donor preparation and pre-signing assembly."""
import importlib.util
import io
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import struct
import tempfile
import unittest
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('donor', ROOT / 'tools/touch-packs/reuse-v653-donor.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)


def macho(dependency='/usr/lib/libSystem.B.dylib', payload=b'old-code'):
    name = dependency.encode() + b'\0'
    length = (24 + len(name) + 7) // 8 * 8
    command = struct.pack('<6I', 0xc, length, 24, 0, 0, 0) + name
    command += b'\0' * (length - len(command))
    return struct.pack('<8I', 0xfeedfacf, 0x100000c, 0, 2, 1, length, 0, 0) + command + payload


def make_zip(path, entries):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            for name, data in entries:
                i = zipfile.ZipInfo(name); i.external_attr = 0o100644 << 16
                z.writestr(i, data)


class DonorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.base = Path(self.tmp.name)
        self.pins = dict(repository='arjuk95-dot/bcd-touch', run_id=43227989116,
                         source='3' * 40, artifact_id=13955942602,
                         ipa_member='build-out/BCD-Touch-Lab-unsigned.ipa',
                         catalog_member='build-out/ConfigCatalog.generated.swift',
                         bundle_id='com.arjunkl.bcdtouch', version='0.1.653', build='653',
                         app_path='Payload/Madeira.app')
        self.info = dict(MadeiraCommit='3' * 40, MadeiraRepo=self.pins['repository'],
                         CFBundleIdentifier=self.pins['bundle_id'], CFBundleVersion='653',
                         CFBundleShortVersionString='0.1.653', CFBundleExecutable='Madeira',
                         MinimumOSVersion='18.0', CFBundleURLTypes=[{'CFBundleURLSchemes': ['bcdtouchlab']}])
        prefix = self.pins['app_path'] + '/'
        files = [('Info.plist', plistlib.dumps(self.info)), ('Madeira', macho()),
                 ('Assets.car', b'unchanged artwork'), ('_CodeSignature/CodeResources', b'old seal'),
                 ('PlugIns/MadeiraJITHelper.appex/MadeiraJITHelper', macho()),
                 ('PlugIns/MadeiraJITHelper.appex/_CodeSignature/CodeResources', b'helper seal'),
                 ('Frameworks/StikJIT.framework/StikJIT', macho())]
        files += [('d3d12/libmetalirconverter.dylib', b'converter'),
                  ('d3d12/TOUCH-CONVERTER-PROVENANCE.json', json.dumps({'librarySHA256': hashlib.sha256(b'converter').hexdigest(), 'upstreamSourceFileSHA256': m.CONVERTER_SOURCE_SHA}).encode())]
        files += [(n + '/payload.bin' if '.' not in n else n, n.encode()) for n in m.RESOURCE_NAMES]
        self.entries = [(prefix + n, data) for n, data in files]
        self.ipa = self.base / 'input.ipa'; self.artifact = self.base / 'artifact.zip'
        self.pin_file = self.base / 'pins.json'
        self.old_pin = m.PIN_FILE; m.PIN_FILE = self.pin_file
        self.repack()

    def tearDown(self):
        m.PIN_FILE = self.old_pin; self.tmp.cleanup()

    def repack(self):
        make_zip(self.ipa, self.entries)
        self.pins['ipa_sha256'] = m.digest(self.ipa)
        make_zip(self.artifact, [(self.pins['ipa_member'], self.ipa.read_bytes()),
                                (self.pins['catalog_member'], b'generated donor catalog')])
        self.pins['artifact_sha256'] = m.digest(self.artifact)
        self.pins['catalog_sha256'] = hashlib.sha256(b'generated donor catalog').hexdigest()
        files = {n.removeprefix(self.pins['app_path'] + '/'): {'sha256': hashlib.sha256(b).hexdigest(), 'bytes': len(b), 'executable': False} for n, b in self.entries}
        self.pins['payload_manifest_sha256'] = m.manifest_digest(files)
        self.pin_file.write_text(json.dumps(self.pins))

    def prepared(self):
        out = self.base / 'prepared'; m.prepare(self.artifact, out); return out

    def compiled(self, prepared):
        out = self.base / 'compiled.app'; out.mkdir()
        info = dict(self.info, MadeiraCommit='4' * 40, CFBundleVersion='654',
                    CFBundleShortVersionString='0.1.654')
        (out / 'Info.plist').write_bytes(plistlib.dumps(info))
        (out / 'Madeira').write_bytes(macho(payload=b'new touch code'))
        (out / 'Assets.car').write_bytes(b'recompiled assets not used')
        return out

    def test_prepare_and_assemble_preserve_runtime_helpers_art(self):
        p = self.prepared(); c = self.compiled(p); out = self.base / 'assembled'
        r = m.assemble(p, c, out, '4' * 40)
        self.assertTrue(r['runtime_byte_identical_before_signing'])
        app = out / 'Payload/Madeira.app'
        self.assertEqual((app / 'Assets.car').read_bytes(), b'unchanged artwork')
        self.assertTrue((app / 'PlugIns/MadeiraJITHelper.appex/_CodeSignature/CodeResources').is_file())
        self.assertFalse((app / '_CodeSignature').exists())
        self.assertEqual((app / 'Madeira').read_bytes(), (c / 'Madeira').read_bytes())
        self.assertTrue(m.verify(out)['pre_signing_payload_verified'])
        (app / 'gl/payload.bin').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'changed'): m.verify(out)

    def test_wrong_artifact_hash(self):
        self.artifact.write_bytes(self.artifact.read_bytes() + b'changed')
        with self.assertRaisesRegex(ValueError, 'ZIP hash'): self.prepared()
        self.assertFalse((self.base / 'prepared').exists())

    def test_wrong_nested_ipa_hash(self):
        self.pins['ipa_sha256'] = '0' * 64; self.pin_file.write_text(json.dumps(self.pins))
        with self.assertRaisesRegex(ValueError, 'IPA hash'): self.prepared()

    def test_wrong_identity(self):
        self.entries[0] = (self.entries[0][0], plistlib.dumps(dict(self.info, MadeiraCommit='0' * 40)))
        self.repack()
        with self.assertRaisesRegex(ValueError, 'identity/source'): self.prepared()

    def test_donor_tampering(self):
        p = self.prepared(); (p / 'Payload/Madeira.app/gl/payload.bin').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'contents changed'): m.load_prepared(p)

    def test_catalog_tampering(self):
        p = self.prepared(); (p / 'ConfigCatalog.generated.swift').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'catalog changed'): m.load_prepared(p)

    def test_preexisting_output_not_overwritten(self):
        p = self.prepared(); snapshot = (p / 'donor-manifest.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'already exists'): m.prepare(self.artifact, p)
        self.assertEqual((p / 'donor-manifest.json').read_bytes(), snapshot)

    def test_path_traversal_and_collision(self):
        bad_names = ['../escape', '/escape', 'Payload/../escape', 'C:/escape', 'a\\b', 'a//b', 'a/./b']
        for name in bad_names:
            with self.subTest(name=name):
                zbytes = io.BytesIO(); make_zip(zbytes, [(name, b'x')]); zbytes.seek(0)
                with zipfile.ZipFile(zbytes) as z, self.assertRaises(ValueError): m.zip_members(z)
        for names in [('a', 'a'), ('a', 'A'), ('a', 'a/b')]:
            zbytes = io.BytesIO(); make_zip(zbytes, [(n, b'x') for n in names]); zbytes.seek(0)
            with zipfile.ZipFile(zbytes) as z, self.assertRaises(ValueError): m.zip_members(z)

    def test_symlinks_rejected(self):
        zbytes = io.BytesIO()
        with zipfile.ZipFile(zbytes, 'w') as z:
            i = zipfile.ZipInfo('link'); i.external_attr = 0o120777 << 16; z.writestr(i, '../outside')
        zbytes.seek(0)
        with zipfile.ZipFile(zbytes) as z, self.assertRaisesRegex(ValueError, 'Links'): m.zip_members(z)

    def test_unexpected_ipa_root(self):
        self.entries.append(('Payload/Other.app/main', b'bad')); self.repack()
        with self.assertRaisesRegex(ValueError, 'Unexpected IPA root'): self.prepared()

    def test_personal_provision_rejected(self):
        self.entries.append(('Payload/Madeira.app/embedded.mobileprovision', b'personal')); self.repack()
        with self.assertRaisesRegex(ValueError, 'Personal provisioning'): self.prepared()

    def test_unreviewed_metadata_change(self):
        p = self.prepared(); c = self.compiled(p)
        info = plistlib.loads((c / 'Info.plist').read_bytes()); info['MinimumOSVersion'] = '26.0'
        (c / 'Info.plist').write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(ValueError, 'metadata change'): m.assemble(p, c, self.base / 'out', '4' * 40)

    def test_dynamic_dependency_change(self):
        p = self.prepared(); c = self.compiled(p); (c / 'Madeira').write_bytes(macho('/new/framework'))
        with self.assertRaisesRegex(ValueError, 'dependency set'): m.assemble(p, c, self.base / 'out', '4' * 40)

    def test_wrong_architecture(self):
        p = self.prepared(); c = self.compiled(p); (c / 'Madeira').write_bytes(b'not arm64')
        with self.assertRaisesRegex(ValueError, 'arm64'): m.assemble(p, c, self.base / 'out', '4' * 40)

    def test_manifest_cannot_authorize_changed_runtime(self):
        p = self.prepared(); app = p / 'Payload/Madeira.app'
        (app / 'gl/payload.bin').write_bytes(b'changed')
        manifest = json.loads((p / 'donor-manifest.json').read_text())
        manifest['files'] = m.inventory(app)
        (p / 'donor-manifest.json').write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, 'pinned payload'): m.load_prepared(p)

    def test_link_manifest_rejects_nonarchive(self):
        repo = self.base / 'repo'; (repo / 'app/Madeira').mkdir(parents=True)
        (repo / 'app/Madeira/libgmp.a').write_bytes(b'not a library')
        with self.assertRaisesRegex(ValueError, 'static archive'): m.link_inputs(repo, self.base / 'links.json')

    def test_stage_does_not_follow_symlink(self):
        p = self.prepared(); repo = self.base / 'repo'
        (repo / 'app/Madeira.xcodeproj').mkdir(parents=True)
        (repo / 'app/Madeira.xcodeproj/project.pbxproj').write_text('fixture')
        (repo / 'app/Madeira').symlink_to(self.base / 'outside')
        with self.assertRaisesRegex(ValueError, 'Symlink'): m.stage(p, repo)

    def test_resource_stage(self):
        p = self.prepared(); repo = self.base / 'repo'
        (repo / 'app/Madeira.xcodeproj').mkdir(parents=True)
        (repo / 'app/Madeira.xcodeproj/project.pbxproj').write_text('fixture')
        deps = repo / 'build/madeira-d3d12/deps.sh'; deps.parent.mkdir(parents=True)
        deps.write_text('local ios_lib_sha=\"' + m.CONVERTER_SOURCE_SHA + '\"\n')
        r = m.stage(p, repo)
        self.assertEqual(r['staged_resources'], len(m.RESOURCE_NAMES) + 2)
        self.assertIn(hashlib.sha256(b'converter').hexdigest(), deps.read_text())
        m.stage(p, repo)  # idempotent known pin, not blind replacement
        deps.write_text('local ios_lib_sha=\"unknown\"\n')
        with self.assertRaisesRegex(ValueError, 'pin declaration'): m.stage(p, repo)
        self.assertEqual((repo / 'app/Madeira/ConfigCatalog.generated.swift').read_bytes(), b'generated donor catalog')
        self.assertFalse((repo / 'app/Madeira/Madeira').exists())


if __name__ == '__main__': unittest.main()
