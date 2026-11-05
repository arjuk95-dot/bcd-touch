"""Native packaging gate. Run on macOS after source builds and after staging."""
import hashlib,json,pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[2];g=r/'app/Madeira/gl'
receipt={"builtFromSource":True,"libraries":{}}
for name in ['libOSMesa.dylib','libMoltenVK.dylib']:
 p=g/name
 arch=subprocess.check_output(['lipo','-archs',str(p)],text=True).strip()
 assert arch=='arm64',(name,arch)
 loads=subprocess.check_output(['otool','-L',str(p)],text=True)
 for line in loads.splitlines()[2:]:
  dep=line.strip().split(' (')[0]
  assert dep.startswith(('/System/Library/','/usr/lib/','@rpath/libMoltenVK.dylib')),dep
 header=subprocess.check_output(['vtool','-show-build',str(p)],text=True)
 assert 'platform IOS' in header and 'IOSSIMULATOR' not in header,header
 receipt['libraries'][name]={"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"bytes":p.stat().st_size,"architecture":arch,"loadCommands":loads,"platform":header}
(g/'build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
