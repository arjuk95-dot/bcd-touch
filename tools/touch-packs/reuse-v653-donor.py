#!/usr/bin/env python3
"""Reuse a pinned v653 runtime; rebuild only app code and missing link inputs.

This tool never builds, signs, publishes, installs, or modifies a donor. All
verification is pre-signing. Final sideload signing is a separate existing step.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import struct
import zipfile

PIN_FILE = Path(__file__).with_name('v653-donor.json')
CONVERTER_SOURCE_SHA = '073f903be98e973ff38f4d79f2c48d61ef938754a77b1caedda79c9f05a068c2'
RESOURCE_NAMES = (
    'aarch64-windows', 'arm64ec-windows', 'i386-windows', 'x86_64-vcruntime',
    'nls', 'compat', 'gl', 'vulkan', 'd3d12', 'soundfont', 'licenses', 'legal',
    'prefix-template.tar.gz', 'cacert.pem', 'recommendations.json',
    'BCDThemes.json', 'madeira-jit.js', 'Madeira JIT.shortcut',
)
# No artwork changed in the approved touch-only source diff. Assets.car and icon
# PNGs are therefore inherited from the donor, not mixed with a new asset build.
METADATA_KEYS = {
    'MadeiraCommit', 'MadeiraBuilt', 'MadeiraRepo', 'CFBundleVersion',
    'CFBundleShortVersionString', 'BCDValidationStatus',
    'BCDDeviceValidationStatus', 'BCDFullValidationRun',
    'BCDFullValidationRunStatus', 'BuildMachineOSBuild', 'DTCompiler',
    'DTPlatformBuild', 'DTPlatformName', 'DTPlatformVersion', 'DTSDKBuild',
    'DTSDKName', 'DTXcode', 'DTXcodeBuild',
}
FEX_ARCHIVES = (
    'FEXCore/Source/libFEXCore.a', 'FEXCore/Source/libFEXCore_Base.a',
    'FEXCore/Source/libJemallocLibs.a', 'External/cephes/libcephes_128bit.a',
    'External/fmt/libfmt.a', 'External/SoftFloat-3e/libsoftfloat_3e.a',
    'External/xxhash/cmake_unofficial/libxxhash.a',
)
APP_ARCHIVES = (
    'libgmp.a', 'libgnutls.a', 'libhogweed.a', 'libnettle.a',
    'libntdll_unix.a', 'libwin32u_unix.a', 'libwineserver.a',
    'libdxmt_combined.a', 'libmadeira_rppairing.a',
    'libavformat.a', 'libavcodec.a', 'libswresample.a', 'libavutil.a',
)


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')


def safe_name(name):
    if not name or '\\' in name or ':' in name or '\x00' in name:
        raise ValueError('Unsafe archive name: ' + repr(name))
    raw = name.rstrip('/')
    p = PurePosixPath(raw)
    if p.is_absolute() or any(x in ('', '.', '..') for x in raw.split('/')):
        raise ValueError('Unsafe archive path: ' + name)
    return p


def zip_members(archive):
    """Validate the entire directory before writing anything; donor has no links."""
    entries = archive.infolist()
    if len(entries) > 20000 or sum(i.file_size for i in entries) > 2 * 1024**3:
        raise ValueError('Archive exceeds bounded donor size')
    seen = set()
    files = set()
    for i in entries:
        p = safe_name(i.filename)
        key = str(p).casefold()
        if key in seen:
            raise ValueError('Duplicate/case-colliding archive path: ' + i.filename)
        seen.add(key)
        kind = stat.S_IFMT(i.external_attr >> 16)
        if kind not in (0, stat.S_IFREG, stat.S_IFDIR):
            raise ValueError('Links/special archive entries are not supported')
        if i.flag_bits & 1:
            raise ValueError('Encrypted archive entry')
        if not i.is_dir():
            files.add(key)
    for i in entries:
        if any(str(p).casefold() in files for p in safe_name(i.filename).parents if str(p) != '.'):
            raise ValueError('File used as archive parent')
    return entries


def fresh(path):
    path = Path(path)
    # Fail closed even for an existing empty directory or dangling symlink.
    if path.exists() or path.is_symlink():
        raise ValueError('Output already exists: ' + str(path))
    path.mkdir(parents=True)
    return path


def extract_member(archive, info, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    with archive.open(info) as src, target.open('xb') as dst:
        shutil.copyfileobj(src, dst, 1024 * 1024)
    os.chmod(target, 0o755 if (info.external_attr >> 16) & 0o111 else 0o644)


def inventory(app):
    result = {}
    for path in sorted(Path(app).rglob('*')):
        if path.is_symlink():
            raise ValueError('Unexpected symlink in app: ' + str(path))
        if path.is_file():
            result[path.relative_to(app).as_posix()] = {
                'sha256': digest(path), 'bytes': path.stat().st_size,
                'executable': bool(path.stat().st_mode & 0o111),
            }
        elif not path.is_dir():
            raise ValueError('Special file in app')
    return result


def manifest_digest(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def load_prepared(prepared):
    prepared = Path(prepared)
    receipt = json.loads((prepared / 'donor-manifest.json').read_text())
    pins = json.loads(PIN_FILE.read_text())
    if receipt['provenance'] != pins:
        raise ValueError('Donor provenance does not match checked-in pins')
    app = prepared / pins['app_path']
    if manifest_digest(receipt['files']) != pins['payload_manifest_sha256']:
        raise ValueError('Donor file manifest is not the pinned payload')
    if inventory(app) != receipt['files']:
        raise ValueError('Prepared donor contents changed')
    if digest(prepared / 'ConfigCatalog.generated.swift') != pins['catalog_sha256']:
        raise ValueError('Prepared config catalog changed')
    return app, receipt


def prepare(artifact, output, pins=None):
    pins = pins or json.loads(PIN_FILE.read_text())
    if digest(artifact) != pins['artifact_sha256']:
        raise ValueError('Artifact ZIP hash mismatch')
    with zipfile.ZipFile(artifact) as z:
        zip_members(z)
        ipa_info = z.getinfo(pins['ipa_member'])
        catalog_info = z.getinfo(pins['catalog_member'])
        output = fresh(output)
        ipa = output / 'donor.ipa'
        extract_member(z, ipa_info, ipa)
        extract_member(z, catalog_info, output / 'ConfigCatalog.generated.swift')
    if digest(ipa) != pins['ipa_sha256']:
        raise ValueError('Nested IPA hash mismatch')
    with zipfile.ZipFile(ipa) as z:
        entries = zip_members(z)
        prefix = pins['app_path'] + '/'
        for entry in entries:
            name = entry.filename.rstrip('/')
            if name not in ('Payload', pins['app_path']) and not name.startswith(prefix):
                raise ValueError('Unexpected IPA root: ' + name)
            if entry.is_dir():
                (output / name).mkdir(parents=True, exist_ok=True)
            else:
                extract_member(z, entry, output / name)
    app = output / pins['app_path']
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    expected = {'MadeiraCommit': pins['source'], 'MadeiraRepo': pins['repository'],
                'CFBundleIdentifier': pins['bundle_id'],
                'CFBundleShortVersionString': pins['version'], 'CFBundleVersion': pins['build'],
                'CFBundleExecutable': 'Madeira'}
    if any(info.get(k) != v for k, v in expected.items()):
        raise ValueError('Donor identity/source mismatch')
    if any(app.rglob('embedded.mobileprovision')):
        raise ValueError('Personal provisioning profile must not be reused')
    files = inventory(app)
    if manifest_digest(files) != pins['payload_manifest_sha256']:
        raise ValueError('Donor payload manifest mismatch')
    if digest(output / 'ConfigCatalog.generated.swift') != pins['catalog_sha256']:
        raise ValueError('Donor config catalog hash mismatch')
    receipt = {'provenance': pins, 'files': files,
               'catalog_sha256': digest(output / 'ConfigCatalog.generated.swift'),
               'validation': 'artifact and payload verified; no device testing inferred'}
    write_json(output / 'donor-manifest.json', receipt)
    return receipt


def copy_file_safe(source, target):
    # Source staging can replace tracked runtime resources, but never follow a
    # preexisting symlink in the destination tree.
    for p in [target, *target.parents]:
        if p.is_symlink():
            raise ValueError('Symlink in staging destination: ' + str(p))
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def stage(prepared, repo):
    app, _ = load_prepared(prepared)
    repo = Path(repo).absolute()
    if not (repo / 'app/Madeira.xcodeproj/project.pbxproj').is_file():
        raise ValueError('Expected BCD checkout')
    copied = []
    for name in RESOURCE_NAMES:
        src = app / name
        if not src.exists():
            raise ValueError('Required donor resource missing: ' + name)
        paths = src.rglob('*') if src.is_dir() else [src]
        for path in paths:
            if path.is_file():
                relative = path.relative_to(app)
                copy_file_safe(path, repo / 'app/Madeira' / relative)
                copied.append(relative.as_posix())
    # Existing Xcode copy phase needs this prebuilt framework; no framework build.
    fw = app / 'Frameworks/StikJIT.framework'
    if not (fw / 'StikJIT').is_file():
        raise ValueError('Missing donor StikJIT framework')
    for path in fw.rglob('*'):
        if path.is_file():
            copy_file_safe(path, repo / 'app/Frameworks/StikJIT.xcframework/ios-arm64/StikJIT.framework' / path.relative_to(fw))
    copy_file_safe(Path(prepared) / 'ConfigCatalog.generated.swift', repo / 'app/Madeira/ConfigCatalog.generated.swift')
    stage_converter_pin(app, repo)
    return {'staged_resources': len(copied), 'no_engine_build_performed': True}



def stage_converter_pin(app, repo):
    # Same bounded substitution as the successful v653 stage-converter.py, but
    # reuse the already hash-verified donor instead of downloading another IPA.
    provenance = app / 'd3d12/TOUCH-CONVERTER-PROVENANCE.json'
    data = json.loads(provenance.read_text())
    released = digest(app / 'd3d12/libmetalirconverter.dylib')
    if data.get('librarySHA256') != released or data.get('upstreamSourceFileSHA256') != CONVERTER_SOURCE_SHA:
        raise ValueError('Converter provenance/hash mismatch')
    deps = repo / 'build/madeira-d3d12/deps.sh'
    if deps.is_symlink():
        raise ValueError('Symlink converter dependency script')
    text = deps.read_text()
    old = 'local ios_lib_sha="' + CONVERTER_SOURCE_SHA + '"'
    new = 'local ios_lib_sha="' + released + '"'
    if text.count(old) == 1 and text.count(new) == 0:
        deps.write_text(text.replace(old, new))
    elif text.count(new) != 1 or text.count(old) != 0:
        raise ValueError('Unexpected converter pin declaration')
    copy_file_safe(provenance, repo / 'build-out/converter-provenance.json')


def macho_dependencies(executable):
    data = Path(executable).read_bytes()
    if len(data) < 32 or data[:4] != b'\xcf\xfa\xed\xfe' or struct.unpack_from('<I', data, 4)[0] != 0x100000c:
        raise ValueError('Expected thin arm64 Mach-O')
    ncmds, size = struct.unpack_from('<II', data, 16)
    pos, end = 32, 32 + size
    if end > len(data):
        raise ValueError('Truncated Mach-O commands')
    deps = set()
    for _ in range(ncmds):
        if pos + 8 > end:
            raise ValueError('Truncated Mach-O command')
        cmd, length = struct.unpack_from('<II', data, pos)
        if length < 8 or pos + length > end:
            raise ValueError('Invalid Mach-O command')
        if cmd in (0xc, 0x80000018, 0x8000001f, 0x80000023):
            if length < 24:
                raise ValueError('Invalid dylib command')
            offset = struct.unpack_from('<I', data, pos + 8)[0]
            if offset < 24 or offset >= length:
                raise ValueError('Invalid dylib name')
            deps.add(data[pos + offset:pos + length].split(b'\0')[0].decode('utf-8'))
        pos += length
    if pos != end:
        raise ValueError('Mach-O command count mismatch')
    return sorted(deps)


def assemble(prepared, compiled, output, source):
    donor, receipt = load_prepared(prepared)
    compiled = Path(compiled)
    if not re.fullmatch('[0-9a-f]{40}', source):
        raise ValueError('Expected full source commit')
    old = plistlib.loads((donor / 'Info.plist').read_bytes())
    new = plistlib.loads((compiled / 'Info.plist').read_bytes())
    if new.get('MadeiraCommit') != source or new.get('MadeiraRepo') != old['MadeiraRepo']:
        raise ValueError('Compiled app source metadata mismatch')
    if new.get('CFBundleIdentifier') != old['CFBundleIdentifier'] or new.get('CFBundleExecutable') != 'Madeira':
        raise ValueError('Compiled app identity mismatch')
    # Refuse unreviewed capability/URL/minimum-OS changes, rather than silently
    # mixing donor metadata with a binary that requires new capabilities.
    for key in old.keys() | new.keys():
        if key not in METADATA_KEYS and old.get(key) != new.get(key):
            raise ValueError('Unexpected app metadata change: ' + key)
    deps = macho_dependencies(compiled / 'Madeira')
    if deps != macho_dependencies(donor / 'Madeira'):
        raise ValueError('App dynamic dependency set changed; review required')
    output = fresh(output)
    app = output / 'Payload/Madeira.app'
    shutil.copytree(donor, app)
    shutil.copy2(compiled / 'Madeira', app / 'Madeira')
    for key in METADATA_KEYS:
        if key in new:
            old[key] = new[key]
        else:
            old.pop(key, None)
    (app / 'Info.plist').write_bytes(plistlib.dumps(old, fmt=plistlib.FMT_BINARY, sort_keys=False))
    # Main seal now invalid; keep nested donor signatures until existing signer
    # re-signs them inside out. No unrelated runtime file may change.
    seal = app / '_CodeSignature'
    if seal.exists():
        shutil.rmtree(seal)
    final = inventory(app)
    preserved = {p: v for p, v in receipt['files'].items()
                 if p not in ('Madeira', 'Info.plist') and not p.startswith('_CodeSignature/')}
    if {p: v for p, v in final.items() if p not in ('Madeira', 'Info.plist')} != preserved:
        raise ValueError('Runtime/resource preservation failed')
    result = {'donor': receipt['provenance'], 'app_source': source,
              'main_sha256': digest(app / 'Madeira'), 'dynamic_dependencies': deps,
              'preserved_files': len(preserved), 'files': final,
              'runtime_byte_identical_before_signing': True,
              'signed': False, 'installed': False, 'device_tested': False}
    write_json(output / 'reuse-receipt.json', result)
    return result


def verify(output):
    output = Path(output)
    expected = json.loads((output / 'reuse-receipt.json').read_text())
    if inventory(output / 'Payload/Madeira.app') != expected['files']:
        raise ValueError('Assembled app changed since pre-signing verification')
    return {'pre_signing_payload_verified': True, 'files': len(expected['files'])}


def link_inputs(repo, output):
    repo = Path(repo)
    paths = [Path('app/Madeira') / a for a in APP_ARCHIVES]
    paths += [Path('FEX/build-ios') / a for a in FEX_ARCHIVES]
    result = {}
    for relative in paths:
        path = repo / relative
        with path.open('rb') as f:
            if f.read(8) != b'!<arch>\n':
                raise ValueError('Missing/invalid static archive: ' + str(relative))
        result[relative.as_posix()] = {'sha256': digest(path), 'bytes': path.stat().st_size}
    write_json(output, {'archives': result, 'architecture_verified': False,
                        'note': 'Also run xcrun lipo -verify_arch arm64 on every archive on Mac.'})
    return {'linked_archives': len(result)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('prepare'); p.add_argument('--artifact', required=True); p.add_argument('--output', required=True)
    p = sub.add_parser('stage'); p.add_argument('--prepared', required=True); p.add_argument('--repo', required=True)
    p = sub.add_parser('assemble'); p.add_argument('--prepared', required=True); p.add_argument('--compiled-app', required=True); p.add_argument('--output', required=True); p.add_argument('--source', required=True)
    p = sub.add_parser('verify'); p.add_argument('--output', required=True)
    p = sub.add_parser('link-inputs'); p.add_argument('--repo', required=True); p.add_argument('--output', required=True)
    a = parser.parse_args()
    if a.command == 'prepare':
        r = prepare(a.artifact, a.output); r = {'verified_files': len(r['files']), 'donor_source': r['provenance']['source']}
    elif a.command == 'stage': r = stage(a.prepared, a.repo)
    elif a.command == 'assemble':
        r = assemble(a.prepared, a.compiled_app, a.output, a.source); r = {k: v for k, v in r.items() if k != 'files'}
    elif a.command == 'verify': r = verify(a.output)
    else: r = link_inputs(a.repo, a.output)
    print(json.dumps(r, indent=2))


if __name__ == '__main__':
    main()
