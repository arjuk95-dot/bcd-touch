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
URL='https://github.com/thebcd69/bcd-games/releases/download/v0.1.626/BCD.ipa'
SHA='0243bac423688aafa659a20c99489f9b107e9463e55120750c1eda5875c441ba'
required=['kernelbase-optin.dll','msi-optin.dll','oledlg-optin.dll','setupapi-optin.dll']
optional=['avifil32.dll','msvfw32.dll','msxml3.dll']
dest=ROOT/'app/Madeira/arm64ec-windows'
missing=[n for n in required+optional if not (dest/n).exists()]
receipt=dict(source=URL,archiveSHA256=SHA,scope='Only missing base runtime dependencies; existing source outputs retained',recovered=[])
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
                if data[pe:pe+4]!=b'PE\0\0' or struct.unpack_from('<H',data,pe+4)[0]!=0xa641:
                    raise RuntimeError('Not ARM64EC: '+name)
                (dest/name).write_bytes(data)
                receipt['recovered'].append(dict(name=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
for name in required:
    if not (dest/name).exists():raise RuntimeError('Missing required opt-in runtime: '+name)
(dest/'TOUCH-BASE-RUNTIME-PROVENANCE.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
(ROOT/'build-out').mkdir(exist_ok=True)
(ROOT/'build-out/base-runtime-provenance.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt,indent=2))
