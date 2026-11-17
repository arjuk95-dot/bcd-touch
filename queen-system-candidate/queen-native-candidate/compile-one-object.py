#!/usr/bin/env python3
"""Compile the reviewed Queen candidate only; replace one retained native member.
Run AFTER exact native restoration, before app archive. Does not build engines.
"""
import argparse, collections, hashlib, json, os, pathlib, shutil, subprocess

def sha(b): return hashlib.sha256(b).hexdigest()
def run(args, **kw): return subprocess.check_output(args, text=True, **kw).strip()
def members(data):
    assert data.startswith(b'!<arch>\n'), 'Not a regular ar archive'
    out=[]; pos=8
    while pos<len(data):
        h=data[pos:pos+60]; assert len(h)==60 and h[58:]==b'`\n'
        size=int(h[48:58]); body=data[pos+60:pos+60+size]; assert len(body)==size
        name=h[:16].decode().strip()
        if name.startswith('#1/'):
            length=int(name[3:]); name=body[:length].rstrip(b'\0').decode(); body=body[length:]
        else: name=name.rstrip('/')
        if not name.startswith('__.SYMDEF') and name not in ('','/','//'): out.append((name,sha(body)))
        pos+=60+size+(size%2)
    assert pos==len(data)
    return out

def main():
    p=argparse.ArgumentParser();p.add_argument('--repo',required=True);p.add_argument('--output',required=True);a=p.parse_args()
    root=pathlib.Path(a.repo).resolve(); out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
    patch=pathlib.Path(__file__).with_name('untracked-scan-only.patch')
    assert sha(patch.read_bytes())=='b7b2e47b02b9fb5fff13f1642964a74e78e73425978f401c7206950cc5f700b4'
    dx=root/'dxmt';src=dx/'src/dxmt/dxmt_dynamic.cpp'
    assert run(['git','rev-parse','HEAD'],cwd=dx)=='bbbb3aa539150601912b672126a566531074053f'
    assert sha(src.read_bytes())=='1312aa37ece19e8ef722500cb4794fcabb8cc344d9073ede161b521debb545ce'
    assert 'Xcode 26.3' in run(['xcodebuild','-version'])
    pin=json.loads((root/'tools/ci/native-link-inputs-654.json').read_text())
    archive=root/'app/Madeira/libdxmt_combined.a'
    spec=pin['archives']['app/Madeira/libdxmt_combined.a']
    original=archive.read_bytes(); assert len(original)==spec['bytes'] and sha(original)==spec['sha256']
    before=members(original); target='dxmt_dynamic.o'
    assert sum(n==target for n,_ in before)==1,'Expected exactly one dynamic object'
    subprocess.run(['patch','--fuzz=0','-p1','-i',str(patch.resolve())],cwd=dx,check=True)
    sdk=run(['xcrun','--sdk','iphoneos','--show-sdk-path'])
    obj=out/target
    includes=['src/nativemetal','include','libs','src/winemetal','src/airconv','src/util','src/dxmt','src/d3d9','src/d3d9/unix','src/d3d9shim','include/native/directx','include/native/windows']
    cmd=['xcrun','-sdk','iphoneos','clang++','-arch','arm64','-isysroot',sdk,'-miphoneos-version-min=18.0','-fblocks','-O2','-std=c++20','-fexceptions','-frtti']
    cmd += ['-Wno-'+w for w in ['unused-parameter','missing-field-initializers','missing-braces','extern-c-compat','unused-const-variable','unused-private-field','microsoft-exception-spec']]
    cmd += ['-I'+str(dx/i) for i in includes]+['-I'+str(root/'build/dxmt-ios/shader-headers')]
    cmd += ['-D'+d for d in ['DXMT_NATIVE=1','DXMT_MADEIRA=1','DXMT_IOS=1','DXMT_PAGE_SIZE=4096','NOMINMAX']]
    cmd += ['-c',str(src),'-o',str(obj)]
    (out/'compile-command.json').write_text(json.dumps(cmd,indent=2))
    subprocess.run(cmd,check=True)
    subprocess.run(['xcrun','lipo',str(obj),'-verify_arch','arm64'],check=True)
    replacement=out/'libdxmt_combined.a';shutil.copyfile(archive,replacement)
    subprocess.run(['xcrun','ar','r',str(replacement),str(obj)],check=True)
    subprocess.run(['xcrun','ranlib',str(replacement)],check=True)
    after=members(replacement.read_bytes())
    assert collections.Counter((n,h) for n,h in before if n!=target)==collections.Counter((n,h) for n,h in after if n!=target),'Unrelated archive members changed'
    assert sum(n==target for n,_ in after)==1
    assert next(h for n,h in after if n==target)==sha(obj.read_bytes())
    assert next(h for n,h in before if n==target)!=sha(obj.read_bytes()),'Candidate did not change native code'
    subprocess.run(['xcrun','lipo',str(replacement),'-verify_arch','arm64'],check=True)
    shutil.copyfile(replacement,archive)
    (out/'queen-native-receipt.json').write_text(json.dumps({'base_archive_sha256':sha(original),'candidate_archive_sha256':sha(replacement.read_bytes()),'patch_sha256':sha(patch.read_bytes()),'object_sha256':sha(obj.read_bytes()),'unchanged_other_members':len(before)-1,'native_test':'compile and member verification only; phone performance unmeasured'},indent=2))
if __name__=='__main__': main()

