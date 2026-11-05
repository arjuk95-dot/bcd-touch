"""Stage metadata as resources; executable dylibs use Xcode's Embed Frameworks phase."""
import hashlib,json,pathlib,shutil
r=pathlib.Path(__file__).resolve().parents[2]
g=r/'app/Madeira/gl';info=r/'app/Madeira/gl-info';info.mkdir(exist_ok=True)
expected=json.loads((r/'tools/opengl/provenance.json').read_text())
assert json.loads((g/'provenance.json').read_text())==expected,'Dependency source pins differ'
receipt=json.loads((g/'build-receipt.json').read_text())
for name in ['libOSMesa.dylib','libMoltenVK.dylib']:
 assert hashlib.sha256((g/name).read_bytes()).hexdigest()==receipt['libraries'][name]['sha256'],name
for p in g.iterdir():
 if p.is_file() and p.suffix!='.dylib':shutil.copyfile(p,info/p.name)
print('Verified source artifact hashes; staged GL metadata separately from executable code')
