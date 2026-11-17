#!/usr/bin/env python3
"""Check compiler-produced mixed-ABI helper, not hand-written guest/native casts."""
import importlib.util,json,struct,sys
from pathlib import Path
repo=Path.cwd();dll=Path(sys.argv[1]);out=Path(sys.argv[2])
spec=importlib.util.spec_from_file_location('pe',repo/'tools/patch-wine-ntdll-sync.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
p=m.Pe(str(dll));ranges=p.code_map()
kind=lambda r:[k for s,l,k in ranges if s<=r<s+l]
assert p.machine==0x8664 and any(k==1 for _,_,k in ranges),'Not an ARM64EC PE'
report={}
for name in ['QueenNativeLedgeFilter','QueenNativeBoundShaderState','QueenNativeGraphicsCommit']:
 r=p.exports()[name];o=p.off(r)
 assert kind(r)==[2],('Helper export must be a compiler x64 forwarder',hex(r),kind(r))
 assert p.d[o:o+10]==m.FFS,'Unexpected helper forwarding ABI'
 target=r+14+struct.unpack_from('<i',p.d,o+10)[0]
 assert kind(target)==[1],('Forwarder does not target ARM64EC code',hex(target),kind(target))
 assert p.section_of(target)[5]&0x20000000,'Helper target not executable'
 report[name]={'export_rva':hex(r),'native_rva':hex(target),'compiler_forwarder':True,'native_code_kind':'ARM64EC','device_tested':False}
out.write_text(json.dumps(report,indent=2));print(json.dumps(report))

