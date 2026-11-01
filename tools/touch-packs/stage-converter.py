"""Recover the omitted, pinned iOS converter from the exact upstream release.

Run in macOS CI; no stock app or signing data is installed or modified.
"""
from pathlib import Path
import hashlib
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
URL = 'https://github.com/thebcd69/bcd-games/releases/download/v0.1.626/BCD.ipa'
IPA_SHA = '0243bac423688aafa659a20c99489f9b107e9463e55120750c1eda5875c441ba'
LIB_SHA = '073f903be98e973ff38f4d79f2c48d61ef938754a77b1caedda79c9f05a068c2'
DEST = ROOT / 'app/Madeira/d3d12/libmetalirconverter.dylib'
if DEST.exists() and hashlib.sha256(DEST.read_bytes()).hexdigest() == LIB_SHA:
    print('Pinned converter already present')
else:
    with tempfile.TemporaryDirectory(prefix='bcd-converter-') as tmp:
        archive = Path(tmp) / 'BCD.ipa'
        urllib.request.urlretrieve(URL, archive)
        if hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest() != IPA_SHA:
            raise RuntimeError('Upstream v0.1.626 IPA digest mismatch')
        with zipfile.ZipFile(archive) as z:
            candidates = [n for n in z.namelist() if n.endswith('/d3d12/libmetalirconverter.dylib')]
            if len(candidates) != 1:
                raise RuntimeError('Expected exactly one iOS converter in upstream IPA')
            data = z.read(candidates[0])
        if hashlib.sha256(data).hexdigest() != LIB_SHA:
            raise RuntimeError('Converter differs from build/madeira-d3d12/deps.sh pin')
        DEST.parent.mkdir(parents=True, exist_ok=True)
        DEST.write_bytes(data)
        print(f'Staged pinned converter: {len(data)} bytes, SHA-256 {LIB_SHA}')
