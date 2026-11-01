"""Repackage a verified build for SideStore without compiling or changing its code."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import struct
import subprocess
import zipfile


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def text_digest(executable):
    """Hash actual instructions, excluding the Mach-O signature/load-command edits."""
    data = executable.read_bytes()
    if data[:4] != bytes.fromhex('cffaedfe'):
        raise ValueError('Expected thin arm64 executable')
    position = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, size = struct.unpack_from('<II', data, position)
        if size < 8 or position + size > len(data):
            raise ValueError('Invalid Mach-O load command')
        if command == 0x19:
            for index in range(struct.unpack_from('<I', data, position + 64)[0]):
                section = position + 72 + index * 80
                if data[section:section + 16].rstrip(b'\0') == b'__text':
                    length = struct.unpack_from('<Q', data, section + 40)[0]
                    offset = struct.unpack_from('<I', data, section + 48)[0]
                    if not length or offset + length > len(data):
                        raise ValueError('Invalid instruction section')
                    return hashlib.sha256(data[offset:offset + length]).hexdigest()
        position += size
    raise ValueError('Instruction section missing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=['existing', 'separate'], required=True)
    parser.add_argument('--expected-source', required=True)
    parser.add_argument('--expected-ipa-sha', required=True)
    args = parser.parse_args()
    if digest(args.ipa) != args.expected_ipa_sha:
        raise ValueError('Unexpected source IPA')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    staging = output / 'staging'
    subprocess.run(['ditto', '-x', '-k', str(args.ipa.resolve()), str(staging)], check=True)
    apps = list((staging / 'Payload').glob('*.app'))
    if len(apps) != 1:
        raise ValueError('Expected one application')
    app = apps[0]
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    original = info['CFBundleIdentifier']
    if original != 'com.arjunkl.bcdtouch' or info.get('MadeiraCommit') != args.expected_source:
        raise ValueError('Unexpected source identity or commit')
    if (app / 'embedded.mobileprovision').exists():
        raise ValueError('Do not redistribute a personal provisioning profile')
    target = 'com.thebcd69.bcd' if args.mode == 'existing' else original
    executables = [app / info['CFBundleExecutable']]
    for extension in app.glob('PlugIns/*.appex'):
        nested = plistlib.loads((extension / 'Info.plist').read_bytes())
        executables.append(extension / nested['CFBundleExecutable'])
    before = {str(p.relative_to(app)): text_digest(p) for p in executables}

    def rewrite(value):
        if isinstance(value, str) and (value == original or value.startswith(original + '.')):
            return target + value[len(original):]
        if isinstance(value, dict):
            return {key: rewrite(item) for key, item in value.items()}
        if isinstance(value, list):
            return [rewrite(item) for item in value]
        return value

    for path in app.rglob('Info.plist'):
        data = rewrite(plistlib.loads(path.read_bytes()))
        if path == app / 'Info.plist':
            data['BCDTouchPackagingVariant'] = args.mode
            if args.mode == 'existing':
                for entry in data.get('CFBundleURLTypes', []):
                    if 'bcdtouchlab' in entry.get('CFBundleURLSchemes', []):
                        entry['CFBundleURLSchemes'] = ['bcd', 'bcdtouchlab']
        path.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_BINARY, sort_keys=False))

    # Reuse upstream's bounded ad-hoc signer, not its publication/mail commands.
    signer_path = Path(__file__).resolve().parents[1] / 'ota-variants.py'
    spec = importlib.util.spec_from_file_location('bcd_ota_signer', signer_path)
    signer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(signer)
    signer.fakesign(app)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    signed = subprocess.run(['codesign', '--display', '--entitlements', ':-', str(app)],
                            capture_output=True, check=True)
    entitlements = plistlib.loads(signed.stdout)
    for key in ['get-task-allow', 'com.apple.developer.kernel.increased-memory-limit',
                'com.apple.developer.kernel.extended-virtual-addressing']:
        if entitlements.get(key) is not True:
            raise ValueError('Missing sideload entitlement: ' + key)
    after = {str(p.relative_to(app)): text_digest(p) for p in executables}
    if before != after:
        raise ValueError('Packaging changed executable instructions')
    final = plistlib.loads((app / 'Info.plist').read_bytes())
    helpers = [plistlib.loads(p.read_bytes())['CFBundleIdentifier']
               for p in app.glob('PlugIns/*.appex/Info.plist')]
    if final['CFBundleIdentifier'] != target or any(not h.startswith(target + '.') for h in helpers):
        raise ValueError('Inconsistent main/helper identifiers')
    schemes = [s for entry in final.get('CFBundleURLTypes', []) for s in entry.get('CFBundleURLSchemes', [])]
    if args.mode == 'existing' and not {'bcd', 'bcdtouchlab'}.issubset(schemes):
        raise ValueError('Existing and fork callbacks must both remain available')
    name = 'BCD-Touch-update-existing-unsigned.ipa' if args.mode == 'existing' else 'BCD-Touch-Lab-sideload-unsigned.ipa'
    result = output / name
    subprocess.run(['zip', '-qry', str(result), 'Payload'], cwd=staging, check=True)
    with zipfile.ZipFile(result) as archive:
        if archive.testzip() is not None:
            raise ValueError('Packaged archive failed CRC validation')
    receipt = dict(mode=args.mode, ipa=name, bytes=result.stat().st_size, sha256=digest(result),
                   sourceIPA=args.expected_ipa_sha, appSource=args.expected_source,
                   bundleID=target, displayName=final['CFBundleDisplayName'], helpers=helpers,
                   callbacks=schemes, requestedEntitlements=entitlements,
                   instructionHashes=after, instructionsUnchanged=True,
                   adHocSigned=True, personalSigningStillRequired=True,
                   installed=False, dataPreservationVerified=False, physicallyTested=False)
    (output / 'package-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
