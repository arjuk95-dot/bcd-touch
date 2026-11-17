#!/usr/bin/env python3
"""One FEX PE component baseline build; then guest-leaf routing incremental build.
Never replaces stock files. Fail closed if retained baseline does not reproduce.
Run from reconstructed source root; argument is candidate files directory.
"""
import hashlib,importlib.util,json,os,subprocess,sys,struct,re
from pathlib import Path
root=Path.cwd(); cfg=Path(sys.argv[1]).resolve(); out=root/'build-out/queen-nav';out.mkdir(parents=True,exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
def run(args,**kw):return subprocess.check_output(args,text=True,**kw)
assert run(['git','-C','FEX','rev-parse','HEAD']).strip()=='049a1b162e55c7b7328f7a86b53e0fbda05ddd22'
ship=root/'app/Madeira/arm64ec-windows/xtajit64.dll';stock=ship.read_bytes()
avx=root/'app/Madeira/arm64ec-windows/xtajit64-avx.dll';avxsha=sha(avx.read_bytes())
s=(root/'tools/build-xtajit64.sh').read_text()
a=s.index('echo "=== unpatched rebuild, compared with the committed xtajit64.dll ==="')
b=s.index('# madeira-bcd: the patched module replaces upstream',a)
s=s[:a]+s[b:]
end=s.index('\ngit -C FEX checkout -- "$CPUF"',s.index('python3 "$R/tools/patch-fex-ios-repne-bit-ops.py"'))
s=s[:end]+'\necho "Retained-overlay PE component baseline built; stock untouched"\n'
assert s.count('\nbuild\n')==1
assert 'cp "$B/Bin/libarm64ecfex.dll" "$SHIP"' not in s
script=out/'baseline-component.sh';script.write_text(s)
subprocess.run(['bash',str(script)],check=True)
B=Path(os.environ.get('FEX_ARM64EC_BUILD',str(root/'FEX/build-arm64ec')))
dll=B/'Bin/libarm64ecfex.dll';baseline=dll.read_bytes();(out/'baseline-xtajit64.dll').write_bytes(baseline)
spec=importlib.util.spec_from_file_location('pe',root/'tools/patch-wine-ntdll-sync.py');pe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pe)
a=pe.Pe(str(ship));b=pe.Pe(str(dll))
assert a.exports()==b.exports(),'Baseline exports/RVAs differ; stop, do not waive'
# Compare all mapped sections, excluding debug-only data. This is deliberately
# stricter than upstream warning-only fingerprinting: no drift gets shipped.
def sections(img):
    return {name:(va,vs,sha(img.d[raw:raw+min(vs,rs)])) for name,va,vs,raw,rs,ch in img.secs if not name.startswith('.debug') and name!='.buildid'}
# Exclude only PE-defined timestamp fields; do not mistake build time for code drift.
def normalized_sections(img):
    data=bytearray(img.d)
    # Observed remaining drift: only this human-readable __DATE__/__TIME__ log.
    pattern=rb'(\[build-id\] xtajit64 rev=ml908 compiled )([A-Z][a-z]{2} [ 0-9][0-9] [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2})(\x00)'
    matches=list(re.finditer(pattern,data));assert len(matches)==1
    m=matches[0];data[m.start(2):m.end(2)]=b'0'*len(m.group(2))
    for off in img.timestamp_offsets(): data[off:off+4]=b'\0'*4
    if img.dirs[0][0]:
        off=img.off(img.dirs[0][0])+4 # IMAGE_EXPORT_DIRECTORY.TimeDateStamp
        data[off:off+4]=b'\0'*4
    return {name:(va,vs,sha(data[raw:raw+min(vs,rs)])) for name,va,vs,raw,rs,ch in img.secs if not name.startswith('.debug') and name!='.buildid'}
diffs=[]
for sa,sb in zip(a.secs,b.secs):
    na,va,vs,ra,rsa,cha=sa; nb,vb,vsb,rb,rsb,chb=sb
    da=a.d[ra:ra+min(vs,rsa)];db=b.d[rb:rb+min(vsb,rsb)]
    changes=[i for i in range(min(len(da),len(db))) if da[i]!=db[i]]
    diffs.append({'name':na,'donor_layout':list(sa),'rebuilt_layout':list(sb),'different_bytes':len(changes),'length_delta':len(db)-len(da),'first_differences':[{'rva':hex(va+i),'donor':da[max(0,i-8):i+24].hex(),'rebuilt':db[max(0,i-8):i+24].hex()} for i in changes[:16]]})
report={'raw_identical':sections(a)==sections(b),'timestamp_normalized_identical':normalized_sections(a)==normalized_sections(b),'sections':diffs}
(out/'baseline-comparison.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert report['timestamp_normalized_identical'],'Baseline has differences beyond PE timestamps; see baseline-comparison.json and captured DLLs'

assert sha(ship.read_bytes())==sha(stock) and sha(avx.read_bytes())==avxsha
objects=lambda:{str(p.relative_to(B)):sha(p.read_bytes()) for p in B.rglob('*') if p.is_file() and p.suffix in ('.o','.obj')}
before=objects()
assembly=root/'FEX/Source/Windows/ARM64EC/Module.S'
assembly_before_sha256=sha(assembly.read_bytes())
source_before=(root/'FEX/Source/Windows/ARM64EC/Module.cpp').read_bytes()
subprocess.run([sys.executable,str(cfg/'apply-native-nav.py'),str(root/'FEX')],check=True)
subprocess.run([sys.executable,str(cfg/'apply-guest-leaf-route.py'),str(root/'FEX')],check=True)
subprocess.run([sys.executable,str(cfg/'apply-guest-leaf-install.py'),str(root/'FEX')],check=True)
subprocess.run([sys.executable,str(cfg/'apply-copy-sampling.py'),str(root/'FEX')],check=True)
subprocess.run(['cmake','--build',str(B),'--target','arm64ecfex','-j2'],check=True)
after=objects();changed=[n for n in before.keys()|after.keys() if before.get(n)!=after.get(n)]
expected_objects={'Module.cpp','BranchOps.cpp','Dispatcher.cpp','Module.S','Core.cpp'}
assert len(changed)==5 and {Path(n).stem for n in changed}==expected_objects,('Unexpected object changes',changed)
assert assembly.read_text().count('  QUEEN_COPY_SAMPLE')==1
assert sha(assembly.read_bytes())!=assembly_before_sha256,'Sampled diagnostic writer missing'
candidate=out/'xtajit64-queen-nav.dll';candidate.write_bytes(dll.read_bytes())
c=pe.Pe(str(candidate))
assert set(c.exports())==set(a.exports())|{'QueenNativeLedgeFilter','QueenNativeBoundShaderState','QueenNativeGraphicsCommit'},'Unexpected export delta'
subprocess.run([sys.executable,str(cfg/'check-native-nav.py'),str(candidate),str(out/'helper-abi.json')],check=True)
toolchain=Path(os.environ['MINGW'])
for filename,argv in [
    ('candidate-disassembly.txt',[str(toolchain/'llvm-objdump'),'-d',str(candidate)]),
    ('candidate-pe-metadata.txt',[str(toolchain/'llvm-readobj'),'--coff-load-config','--coff-exports','--sections','--section-data',str(candidate)]),
]:
    (out/filename).write_text(run(argv))
(out/'assembly-preservation.json').write_text(json.dumps({'Module.S_before':assembly_before_sha256,'Module.S_after':sha(assembly.read_bytes()),'preserved':False,'scope':'sampled slow path plus exact uint32 NtDllRedirectionLUTSize load-width correction; no common-call target comparisons, stack/ABI layout changes or copy replacement'},indent=2))
assert sha(ship.read_bytes())==sha(stock) and sha(avx.read_bytes())==avxsha
receipt={'baseline_sha256':sha(baseline),'donor_sha256':sha(stock),'baseline_mapped_sections_identical':report['raw_identical'],'baseline_timestamp_normalized_identical':True,'candidate_sha256':sha(candidate.read_bytes()),'changed_objects':changed,'source_before_sha256':sha(source_before),'source_after_sha256':sha((root/'FEX/Source/Windows/ARM64EC/Module.cpp').read_bytes()),'stock_preserved':True,'device_tested':False}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt,indent=2))



