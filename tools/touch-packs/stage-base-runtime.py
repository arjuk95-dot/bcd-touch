"""Recover missing unchanged runtime dependencies from the exact upstream release.

The native application is still freshly compiled from this fork. Existing source
build outputs remain in place. The original opt-in checks run after recovery.
"""
from pathlib import Path
import hashlib
import json
import struct
import tempfile
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE=json.loads((Path(__file__).resolve().parent/'base-release.json').read_text(encoding='utf-8'))
URL=BASE['ipaURL']
SHA=BASE['ipaSHA256']
required=['kernelbase-optin.dll','msi-optin.dll','oledlg-optin.dll','setupapi-optin.dll',
          'tbs-optin.dll','httpapi-optin.dll','qwave-optin.dll','xinputuap-optin.dll']
optional=['avifil32.dll','msvfw32.dll','msxml3.dll']
dest=ROOT/'app/Madeira/arm64ec-windows'
missing=[n for n in required+optional if not (dest/n).exists()]
receipt=dict(source=URL,release=BASE['tag'],baseCommit=BASE['commit'],archiveSHA256=SHA,scope='Only missing base runtime dependencies; existing source outputs retained',recovered=[])
baseline=(dest/'kernelbase.dll').read_bytes()
baseline_pe=struct.unpack_from('<I',baseline,0x3c)[0]
baseline_machine=struct.unpack_from('<H',baseline,baseline_pe+4)[0]
if missing:
    with tempfile.TemporaryDirectory(prefix='bcd-runtime-') as tmp:
        archive=Path(tmp)/'BCD.ipa';urllib.request.urlretrieve(URL,archive)
        with archive.open('rb') as stream:
            if hashlib.file_digest(stream,'sha256').hexdigest()!=SHA:raise RuntimeError('Base release digest mismatch')
        with zipfile.ZipFile(archive) as z:
            for name in missing:
                candidates=[n for n in z.namelist() if n.endswith('/arm64ec-windows/'+name)]
                if len(candidates)!=1:
                    if name in required:raise RuntimeError('Required runtime absent from exact base release: '+name)
                    continue
                data=z.read(candidates[0])
                if data[:2]!=b'MZ':raise RuntimeError('Not PE: '+name)
                pe=struct.unpack_from('<I',data,0x3c)[0]
                machine=struct.unpack_from('<H',data,pe+4)[0]
                if data[pe:pe+4]!=b'PE\0\0' or machine!=baseline_machine:
                    raise RuntimeError('PE machine differs from shipped kernelbase: '+name)
                (dest/name).write_bytes(data)
                receipt['recovered'].append(dict(name=name,bytes=len(data),peMachine=hex(machine),sha256=hashlib.sha256(data).hexdigest()))
for name in required:
    if not (dest/name).exists():raise RuntimeError('Missing required opt-in runtime: '+name)
(dest/'TOUCH-BASE-RUNTIME-PROVENANCE.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
(ROOT/'build-out').mkdir(exist_ok=True)
(ROOT/'build-out/base-runtime-provenance.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt,indent=2))
