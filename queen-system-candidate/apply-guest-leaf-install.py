#!/usr/bin/env python3
from pathlib import Path
import sys,subprocess
root=Path(sys.argv[1]);here=Path(__file__).resolve().parent
p=root/'Source/Windows/ARM64EC/Module.cpp';s=p.read_text()
a='#include "QueenNativeRhi.h"';assert s.count(a)==1
s=s.replace(a,a+'\n#include "QueenGuestLeafInstall.h"')
a='  InstallQueenNativeRhi(MainModule);';assert s.count(a)==1
s=s.replace(a,a+'\n  InstallQueenGuestLeaf(MainModule);')
for n in ['QueenGuestLeafInstall.h','QueenGuestLeafFingerprint.h']:
 dest=p.parent/n;assert not dest.exists();dest.write_bytes((here/n).read_bytes())
hashdest=p.parent/'QueenFingerprintHash.h'
if hashdest.exists():
 assert hashdest.read_bytes()==(here/'QueenFingerprintHash.h').read_bytes()
else:
 hashdest.write_bytes((here/'QueenFingerprintHash.h').read_bytes())
bytesdest=p.parent/'QueenGuestLeafBytes.h';assert not bytesdest.exists()
subprocess.run([sys.executable,str(here/'generate-guest-leaf.py'),str(bytesdest)],check=True)
p.write_text(s)
print('Queen guest leaf installer: full TLS/thread identity contracts, originals retained')
