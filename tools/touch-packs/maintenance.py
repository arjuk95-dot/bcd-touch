"""Small cross-platform source maintenance; never touches game/device data."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
for p in list((ROOT/'tools/touch-packs').glob('*.py'))+[ROOT/'tests/host/check-touch-worker.py']:
    s=p.read_text(encoding='utf-8').replace('.read_text(encoding='utf-8')', ".read_text(encoding='utf-8')")
    p.write_text(s,encoding='utf-8')
p=ROOT/'.gitignore';s=p.read_text(encoding='utf-8')
for line in ['.touch-worker-demo/','tools/touch-packs/__pycache__/','touch-evidence/','artifacts/']:
    if '\n'+line+'\n' not in s:s+='\n'+line+'\n'
p.write_text(s)
# Canonical hex object identifiers for newly added Xcode membership entries.
p=ROOT/'app/Madeira.xcodeproj/project.pbxproj';s=p.read_text(encoding='utf-8')
s=s.replace('BCDT000000000000000000A','BCD000000000000000000A').replace('BCDT000000000000000000B','BCD000000000000000000B')
p.write_text(s)
