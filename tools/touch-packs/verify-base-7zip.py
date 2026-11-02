"""Keep unchanged v0.1.626 7-Zip tools in this app-input-only archive."""
import hashlib
import json
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[2]
manifest = json.loads(Path(__file__).with_name('base-7zip.json').read_text(encoding='utf-8'))
for name, item in manifest['files'].items():
    data = (root / name).read_bytes()
    if item['normalizeLF']:
        data = data.replace(b'\r\n', b'\n')
    if hashlib.sha256(data).hexdigest() != item['sha256']:
        raise RuntimeError('Base 7-Zip file changed; rebuild and review provenance: ' + name)
    if name.endswith('.exe'):
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[pe:pe+4] != b'PE\0\0' or struct.unpack_from('<H', data, pe+4)[0] != 0x8664:
            raise RuntimeError('Expected pinned Windows x64 program: ' + name)
print('PASS: retained hash-pinned v0.1.626 7-Zip programs and unchanged source/shim; no rebuild needed')
