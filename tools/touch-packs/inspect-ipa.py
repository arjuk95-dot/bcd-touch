"""Inspect the built fork without executing it or modifying any installed app."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct
import zipfile

p=argparse.ArgumentParser()
p.add_argument('ipa',type=Path)
p.add_argument('--expected-commit',required=True)
p.add_argument('--receipt',type=Path,required=True)
a=p.parse_args()
with zipfile.ZipFile(a.ipa) as z:
    names=z.namelist()
    mains=[n for n in names if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist',n)]
    if len(mains)!=1:raise RuntimeError('Expected exactly one main application')
    main=mains[0];root=main.rsplit('/',1)[0]+'/'
    info=plistlib.loads(z.read(main))
    if info['CFBundleIdentifier']!='com.arjunkl.bcdtouch':raise RuntimeError('Stock or unexpected bundle identifier')
    if info['CFBundleDisplayName']!='BCD Touch Lab':raise RuntimeError('Unexpected display name')
    if info.get('MadeiraCommit')!=a.expected_commit:raise RuntimeError('Artifact does not contain the expected source commit')
    schemes=[s for item in info.get('CFBundleURLTypes',[]) for s in item.get('CFBundleURLSchemes',[])]
    if 'bcdtouchlab' not in schemes or 'bcd' in schemes:raise RuntimeError('Fork callback isolation failed')
    nested=[]
    for name in names:
        if name!=main and name.endswith('/Info.plist'):
            other=plistlib.loads(z.read(name))
            if other.get('CFBundlePackageType') in ['APPL','XPC!']:
                identifier=other.get('CFBundleIdentifier','')
                if not identifier.startswith('com.arjunkl.bcdtouch.'):raise RuntimeError('Helper identifier is not isolated: '+identifier)
                nested.append(dict(path=name,identifier=identifier))
    with z.open(root+info['CFBundleExecutable']) as executable:header=executable.read(32)
    if header[:4]!=bytes.fromhex('cffaedfe') or struct.unpack('<I',header[4:8])[0]!=0x0100000c:
        raise RuntimeError('Main executable is not an arm64 Mach-O')
    licenses=['licenses/LICENSE-BCD.txt','licenses/LICENSE-MADEIRA-GPL-3.0.txt','licenses/THIRD-PARTY-NOTICES.txt']
    for name in licenses:
        if root+name not in names:raise RuntimeError('Required notice missing: '+name)
    provenance=json.loads(z.read(root+'d3d12/TOUCH-CONVERTER-PROVENANCE.json'))
    converter_sha=hashlib.sha256(z.read(root+'d3d12/libmetalirconverter.dylib')).hexdigest()
    runtime_provenance=json.loads(z.read(root+'arm64ec-windows/TOUCH-BASE-RUNTIME-PROVENANCE.json'))
    if any(n.endswith('/TouchPacks/worker.json') or n.endswith('/pairing-token.txt') for n in names):
        raise RuntimeError('Personal worker configuration must not be bundled')
    receipt=dict(kind='IPA metadata inspection; no device execution or signature validation',
        ipa=a.ipa.name,bytes=a.ipa.stat().st_size,
        base='adc9cc742f52601a42f52ac6b4fbcc701bdb16ad',appSource=info['MadeiraCommit'],
        bundleID=info['CFBundleIdentifier'],displayName=info['CFBundleDisplayName'],
        version=info['CFBundleShortVersionString'],build=info['CFBundleVersion'],built=info.get('MadeiraBuilt'),
        callbacks=schemes,architecture='arm64',helpers=nested,notices=licenses,
        provisioningProfileIncluded=root+'embedded.mobileprovision' in names,
        rootSignatureDirectoryPresent=any(n.startswith(root+'_CodeSignature/') for n in names),
        converterProvenance=provenance,packagedConverterSHA256=converter_sha,baseRuntimeProvenance=runtime_provenance,
        installationTested=False,guestTraceTested=False,physicallyTested=False)
with a.ipa.open('rb') as stream:receipt['sha256']=hashlib.file_digest(stream,'sha256').hexdigest()
a.receipt.parent.mkdir(parents=True,exist_ok=True)
a.receipt.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt,indent=2))
