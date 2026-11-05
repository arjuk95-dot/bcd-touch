"""Inspect the actual exported IPA, not just a developer staging directory."""
import argparse,hashlib,json,pathlib,plistlib,struct,zipfile
from pe_image import inspect_image
p=argparse.ArgumentParser();p.add_argument('ipa',type=pathlib.Path);p.add_argument('--source',required=True);p.add_argument('--receipt',type=pathlib.Path,required=True);a=p.parse_args()
def sha(b):return hashlib.sha256(b).hexdigest()
def pe(b):
 o=struct.unpack_from('<I',b,0x3c)[0];assert b[o:o+4]==b'PE\0\0';return struct.unpack_from('<H',b,o+4)[0]
def macho(b):
 assert b[:4]==bytes.fromhex('cffaedfe') and struct.unpack_from('<I',b,4)[0]==0x100000c,'Expected ARM64 Mach-O'
 n=struct.unpack_from('<I',b,16)[0];offset=32;result={'dependencies':[],'codeSignature':False}
 for _ in range(n):
  cmd,size=struct.unpack_from('<II',b,offset);assert size>=8
  data=b[offset:offset+size]
  if cmd in [0xc,0xd,0x80000018,0x8000001f]:
   start=struct.unpack_from('<I',data,8)[0];name=data[start:].split(b'\0',1)[0].decode()
   if cmd==0xd:result['installName']=name
   else:result['dependencies'].append(name)
  if cmd==0x32:
   result['platform'],minimum,sdk=struct.unpack_from('<III',data,8)
   result['minimumOS']=[minimum>>16,(minimum>>8)&255,minimum&255]
  if cmd==0x25:
   minimum=struct.unpack_from('<I',data,8)[0];result['platform']=2;result['minimumOS']=[minimum>>16,(minimum>>8)&255,minimum&255]
  if cmd==0x1d:result['codeSignature']=struct.unpack_from('<I',data,12)[0]>0
  offset+=size
 return result
with zipfile.ZipFile(a.ipa) as z:
 assert z.testzip() is None,'ZIP CRC failure'
 mains=[n for n in z.namelist() if n.startswith('Payload/') and n.count('/')==2 and n.endswith('.app/Info.plist')]
 assert len(mains)==1
 root=mains[0].rsplit('/',1)[0]+'/'
 info=plistlib.loads(z.read(mains[0]));assert info['MadeiraCommit']==a.source
 assert info['CFBundleIdentifier'] in ['com.thebcd69.bcd','com.arjunkl.bcdtouch']
 result={'source':a.source,'bundleID':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'libraries':{},'pe':{},'physicalChecks':'pending'}
 source=json.loads(z.read(root+'gl-info/provenance.json'))
 assert source==json.loads((pathlib.Path(__file__).parent/'provenance.json').read_text())
 built=json.loads(z.read(root+'gl-info/build-receipt.json'));assert built['builtFromSource']
 wine=json.loads(z.read(root+'gl-info/wine-build-receipt.json'))
 assert wine['wine']==source['wine'] and not source['importedBinaries']
 app_min=[int(n) for n in info.get('MinimumOSVersion','17.0').split('.')];app_min=(app_min+[0,0])[:3]
 for name in ['libOSMesa.dylib','libMoltenVK.dylib']:
  b=z.read(root+'Frameworks/'+name);m=macho(b)
  assert m['platform']==2 and m['minimumOS']<=app_min,(name,m,app_min)
  assert m['installName']=='@rpath/'+name and m['codeSignature'],(name,m)
  for dep in m['dependencies']:assert dep.startswith(('/System/Library/','/usr/lib/','@rpath/libMoltenVK.dylib')),dep
  result['libraries'][name]={**m,'bytes':len(b),'packagedSHA256':sha(b),'sourceArtifactSHA256':built['libraries'][name]['sha256'],'signatureNote':'Xcode/ad-hoc signing may change the whole-file hash'}
 for farm,machine in [('arm64ec-windows',0x8664),('aarch64-windows',0xaa64),('i386-windows',0x14c)]:
  b=z.read(root+farm+'/opengl32.dll');parsed=inspect_image(b)
  if farm=='arm64ec-windows':assert parsed['architecture']=='arm64ec-hybrid' and parsed['explicitTEBMoves']>0 and not parsed['directTEBStores'],parsed
  else:assert pe(b)==machine
  assert sha(b)==wine['pe'][farm]['sha256'],farm
  result['pe'][farm]={**parsed,'sha256':sha(b)}
 for farm,suffix,machine in [('arm64ec-windows','x64',0x8664),('i386-windows','x86',0x14c)]:
  b=z.read(root+farm+'/bcd-opengl-smoke-'+suffix+'.exe');assert pe(b)==machine and b'240 textured shader frames' in b
 for name in ['Mesa-license.rst','MoltenVK-Apache-2.0.txt','SPIRV-Cross-Apache-2.0.txt','SPIRV-Tools-Apache-2.0.txt','cereal-BSD-3-Clause.txt']:
  assert len(z.read(root+'licenses/'+name))>100,name
 executable=z.read(root+info['CFBundleExecutable'])
 for marker in [b'first actual OpenGL present',b'no GLES fallback',b'Floating movement',b'Firing sensitivity multiplier']:
  assert marker in executable,marker
 result['dependencySources']=source
result['ipaSHA256']=sha(a.ipa.read_bytes());result['ipaBytes']=a.ipa.stat().st_size
a.receipt.parent.mkdir(parents=True,exist_ok=True);a.receipt.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
