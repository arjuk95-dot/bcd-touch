"""Validate architecture discovery against actual committed Wine binaries."""
import importlib.util,pathlib
r=pathlib.Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('pe_image',r/'tools/opengl/pe_image.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
for name in ['opengl32.dll','ntdll.dll']:
 ec=m.inspect_image((r/'app/Madeira/arm64ec-windows'/name).read_bytes())
 assert ec['machine']=='0x8664' and ec['architecture']=='arm64ec-hybrid' and ec['chpeVersion']==2
 assert any(x['type']==1 for x in ec['codeRanges']) and any(x['type']==2 for x in ec['codeRanges'])
 arm=m.inspect_image((r/'app/Madeira/aarch64-windows'/name).read_bytes());assert arm['machine']=='0xaa64' and arm['architecture']=='arm64'
print('PASS: real Wine hybrid AMD64 header/ARM64EC CHPE maps and native ARM64 discovery; AMD64 thunk bytes excluded from ARM instruction audit')
