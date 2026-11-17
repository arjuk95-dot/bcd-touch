#!/usr/bin/env python3
"""Targeted macOS build helper. Requires already-patched, pinned DXMT source.
Does not stage into the app: paired PE receipt must be accepted first.
"""
import argparse, collections, hashlib, json, pathlib, shutil, subprocess
p=argparse.ArgumentParser();p.add_argument('--repo',required=True);p.add_argument('--archive',required=True);p.add_argument('--output',required=True);a=p.parse_args()
r=pathlib.Path(a.repo).resolve(); archive=pathlib.Path(a.archive).resolve();out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
run=lambda args:subprocess.check_output([str(x) for x in args])
ar=['xcrun','--sdk','iphoneos','ar']; member='dxbc_converter_gs.o'
def members(path):
 data=path.read_bytes();assert data.startswith(b'!<arch>\n');pos=8;out=[]
 while pos<len(data):
  h=data[pos:pos+60];assert len(h)==60 and h[58:]==b'`\n'
  size=int(h[48:58]);body=data[pos+60:pos+60+size];assert len(body)==size
  name=h[:16].decode().strip()
  if name.startswith('#1/'):
   count=int(name[3:]);name=body[:count].rstrip(b'\0').decode();body=body[count:]
  else:name=name.rstrip('/')
  if not name.startswith('__.SYMDEF') and name not in ('','/','//'):
   out.append((name,hashlib.sha256(body).hexdigest()))
  pos+=60+size+(size%2)
 assert pos==len(data)
 return out
before=members(archive);assert sum(n==member for n,h in before)==1
src=r/'dxmt/src'; gs=src/'airconv/dxbc_converter_gs.cpp'; public=src/'airconv/airconv_public.h'
assert gs.read_text().count('geometry payload ABI size mismatch')==2
assert 'SM50_SHADER_GEOMETRY_PAYLOAD = 9' in public.read_text()
sdk=run(['xcrun','--sdk','iphoneos','--show-sdk-path']).decode().strip(); obj=out/member
includes=[r/'dxmt/include',r/'dxmt/libs',src/'winemetal',src/'airconv',r/'dxmt/include/native/directx',r/'dxmt/include/native/windows',r/'build/dxmt-ios/shader-headers',r/'toolchains/llvm-ios-build/include',r/'toolchains/llvm-project/llvm/include']
cmd=['xcrun','--sdk','iphoneos','clang++','-arch','arm64','-isysroot',sdk,'-miphoneos-version-min=18.0','-fblocks','-O2','-std=c++20','-fno-exceptions','-fno-rtti']+['-I'+str(x) for x in includes]+['-D_FILE_OFFSET_BITS=64','-D__STDC_CONSTANT_MACROS','-D__STDC_FORMAT_MACROS','-D__STDC_LIMIT_MACROS','-c',str(gs),'-o',str(obj)]
subprocess.run(cmd,check=True)
candidate=out/'libdxmt_combined-gs.a';assert candidate!=archive;shutil.copy2(archive,candidate)
subprocess.run(ar+['r',str(candidate),str(obj)],check=True);subprocess.run(['xcrun','--sdk','iphoneos','ranlib',str(candidate)],check=True)
after=members(candidate)
assert collections.Counter((n,h) for n,h in before if n!=member)==collections.Counter((n,h) for n,h in after if n!=member)
assert sum(n==member for n,h in after)==1
assert next(h for n,h in after if n==member)==hashlib.sha256(obj.read_bytes()).hexdigest()
assert next(h for n,h in before if n==member)!=next(h for n,h in after if n==member)
changed=[member]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
(out/'native-gs-receipt.json').write_text(json.dumps({'changed_members':changed,'archive_sha256':sha(candidate),'object_sha256':sha(obj),'source_sha256':sha(gs),'public_header_sha256':sha(public),'compile_command':cmd,'paired_PE_required':True,'device_tested':False},indent=2))
print(candidate)
