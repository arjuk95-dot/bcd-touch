from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[2]
for name in ['JITNetwork.swift','SavesAndShortcuts.swift']:
    p=ROOT/'app/Madeira'/name;s=p.read_text(encoding='utf-8').replace('bcd://','bcdtouchlab://')
    if '// Modified for WO-BCD' not in s:s='// Modified for WO-BCD-TOUCH-001 (2026-11-01): isolated URL callbacks.\n'+s
    p.write_text(s,encoding='utf-8')
p=ROOT/'.github/workflows/touch-ipa.yml';d=yaml.safe_load(p.read_text());d.pop(True,None);d['on']={'workflow_dispatch':None}
for step in d['jobs']['build']['steps']:
    if step.get('name','').startswith('Build native wine'):
        step['run']='''set -euo pipefail
trap 'tail -n 80 "$GITHUB_WORKSPACE/wine-native-configure.log" "$GITHUB_WORKSPACE/wine-native-make.log" 2>/dev/null || true' ERR
cd wine
mkdir -p build-native
cd build-native
W64=""; [ "$(uname -m)" != x86_64 ] || W64=--enable-win64
../configure $W64 > "$GITHUB_WORKSPACE/wine-native-configure.log" 2>&1
N=$(sysctl -n hw.ncpu)
make -j"$N" __tools__ > "$GITHUB_WORKSPACE/wine-native-make.log" 2>&1
make -j"$N" include >> "$GITHUB_WORKSPACE/wine-native-make.log" 2>&1
'''
    if step.get('name')=='Archive (unsigned)':
        step['run']=step['run'].replace('archive -archivePath','archive -archivePath')
p.write_text(yaml.safe_dump(d,sort_keys=False,width=160))
