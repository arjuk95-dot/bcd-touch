"""Extract only a hash-verified emulator DLL from the already delivered IPA."""
import hashlib, io, json, sys, zipfile
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
with zipfile.ZipFile(source) as outer:
    names = [n for n in outer.namelist() if n.endswith('.ipa')]
    assert len(names) == 1
    data = outer.read(names[0])
    assert len(data) == 193194921
    # Outer artifact SHA is checked by the build. Retain the exact inner IPA hash
    # in a receipt instead of presuming that ad-hoc signing timestamps reproduce.
    with zipfile.ZipFile(io.BytesIO(data)) as inner:
        dll = inner.read('Payload/Madeira.app/arm64ec-windows/xtajit64-queen-nav.dll')
    assert dll[:2] == b'MZ' and 1000000 < len(dll) < 20000000
destination.write_bytes(dll)
Path('build-out/native667-reuse.json').write_text(json.dumps({
    'artifact':14329248488, 'ipa_sha256':hashlib.sha256(data).hexdigest(),
    'dll_sha256':hashlib.sha256(dll).hexdigest(), 'dll_bytes':len(dll),
    'source':'e5b9da7de835b02c0ecd229ef3b921a061545e51', 'default_enabled':False,
    'no_new_fex_build':True, 'device_performance_verified':False},indent=2))
