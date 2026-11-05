"""Hard gate against mixed/stub OpenGL runtime or stale PE DLLs."""
import argparse,hashlib,json,pathlib,re,struct,subprocess
r=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--built',action='store_true');a=p.parse_args()
if a.built:
 for archive,symbols in {'libntdll_unix.a':['opengl32_unix_call_funcs','opengl32_unix_call_wow64_funcs'], 'libwin32u_unix.a':['winios_OpenGLInit']}.items():
  nm=subprocess.check_output(['nm','-gU',str(r/'app/Madeira'/archive)],text=True)
  for sym in symbols:assert re.search(r'\b_'+sym+r'\s*$',nm,re.M),(archive,sym)
 receipt={'wine':'469e08af66c2638b74422e3d068620d400272d55','pe':{}}
 for farm,machine in [('arm64ec-windows',0xa641),('aarch64-windows',0xaa64),('i386-windows',0x14c)]:
  f=r/'app/Madeira'/farm/'opengl32.dll';data=f.read_bytes()
  off=struct.unpack_from('<I',data,0x3c)[0];actual=struct.unpack_from('<H',data,off+4)[0]
  assert data[off:off+4]==b'PE\0\0' and actual==machine,(farm,hex(actual))
  receipt['pe'][farm]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'machine':hex(actual)}
 tc=r/'toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/llvm-objdump'
 dis=subprocess.check_output([str(tc),'-d',str(r/'app/Madeira/arm64ec-windows/opengl32.dll')],text=True)
 assert re.search(r'\bmov\s+x\d+, x18\b',dis),'Explicit TEB MOV missing'
 assert not re.search(r'\bstr\s+x18\b',dis),'Unpatchable direct x18 TEB store'
 out=r/'app/Madeira/gl';out.mkdir(exist_ok=True)
 (out/'wine-build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps(receipt,indent=2))
