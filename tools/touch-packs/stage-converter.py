"""Recover the omitted, pinned iOS converter from the exact upstream release.

Run in macOS CI; no stock app or signing data is installed or modified.
"""
from pathlib import Path
import hashlib
import json
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = json.loads((Path(__file__).resolve().parent / 'base-release.json').read_text(encoding='utf-8'))
URL = BASE['ipaURL']
IPA_SHA = BASE['ipaSHA256']
LIB_SHA = '073f903be98e973ff38f4d79f2c48d61ef938754a77b1caedda79c9f05a068c2'
DEST = ROOT / 'app/Madeira/d3d12/libmetalirconverter.dylib'
if DEST.exists() and hashlib.sha256(DEST.read_bytes()).hexdigest() == LIB_SHA:
    print('Pinned converter already present')
else:
    with tempfile.TemporaryDirectory(prefix='bcd-converter-') as tmp:
        archive = Path(tmp) / 'BCD.ipa'
        urllib.request.urlretrieve(URL, archive)
        with archive.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        if digest != IPA_SHA:
            raise RuntimeError('Upstream ' + BASE['tag'] + ' IPA digest mismatch')
        with zipfile.ZipFile(archive) as z:
            candidates = [n for n in z.namelist() if n.endswith('/d3d12/libmetalirconverter.dylib')]
            if len(candidates) != 1:
                raise RuntimeError('Expected exactly one iOS converter in upstream IPA')
            data = z.read(candidates[0])
        released_sha = hashlib.sha256(data).hexdigest()
        # The release's bundled/signed file differs from the absent source-file pin.
        # Trust only bytes recovered from the *whole, hash-pinned exact release*;
        # keep deps.sh's normal per-file verification, with an explicit staging pin.
        if released_sha != LIB_SHA:
            deps = ROOT / 'build/madeira-d3d12/deps.sh'
            text = deps.read_text(encoding='utf-8')
            old = 'local ios_lib_sha="' + LIB_SHA + '"'
            if text.count(old) != 1:
                raise RuntimeError('Unexpected upstream converter pin declaration')
            deps.write_text(text.replace(old, 'local ios_lib_sha="' + released_sha + '"'), encoding='utf-8')
        provenance = dict(source=URL, release=BASE['tag'], baseCommit=BASE['commit'], archiveSHA256=IPA_SHA,
                          librarySHA256=released_sha, upstreamSourceFileSHA256=LIB_SHA,
                          note='Exact release dependency; source-file and release-file digests differ. No claim of byte identity to the absent source file.')
        DEST.parent.mkdir(parents=True, exist_ok=True)
        DEST.write_bytes(data)
        (DEST.parent/'TOUCH-CONVERTER-PROVENANCE.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
        (ROOT/'build-out').mkdir(exist_ok=True)
        (ROOT/'build-out/converter-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
        print(f'Staged exact release converter: {len(data)} bytes, SHA-256 {released_sha}; source pin {LIB_SHA}')
