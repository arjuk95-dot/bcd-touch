#!/usr/bin/env python3
"""Replace only exact retained virtual.o after pinned Wine headers are generated."""
from pathlib import Path
import subprocess as sp,sys,json,hashlib,collections,importlib.util
root=Path(sys.argv[1]).resolve(); bundle=Path(__file__).parent.resolve();out=root/'build-out/queen-floor';out.mkdir(parents=True,exist_ok=False)
def run(a):return sp.check_output(a,text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert 'Xcode 26.3' in run(['xcodebuild','-version'])
assert run(['git','-C',str(root/'wine'),'rev-parse','HEAD'])=='52a6004e68e818c5b09918215e973726e282425f'
src=root/'build/ntdll-unix/virtual_ios.c'
assert sha(src)=='81d49d59e321070a891c44e9e7309e142ecaed5161979ad183d1343859edcb9c'
archive=root/'app/Madeira/libntdll_unix.a';pin=json.loads((root/'tools/ci/native-link-inputs-654.json').read_text())['archives']['app/Madeira/libntdll_unix.a'];assert sha(archive)==pin['sha256']
# Reuse the666 independently reviewed archive parser (no mutation/build on import).
spec=importlib.util.spec_from_file_location('archive_members',root.parent/'queen-system-candidate/queen-native-candidate/compile-one-object.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
before=m.members(archive.read_bytes());assert sum(n=='virtual.o' for n,h in before)==1
sp.run(['patch','--fuzz=0','-p1','-i',str(bundle/'floor/floor-skip.patch')],cwd=root,check=True)
sdk=run(['xcrun','--sdk','iphoneos','--show-sdk-path']);w=root/'wine';b=root/'build/ntdll-unix';wb=w/'build-macos'
assert (wb/'include/config.h').is_file()
cmd=['xcrun','-sdk','iphoneos','clang','-arch','arm64','-isysroot',sdk,'-miphoneos-version-min=17.0','-O2','-fPIC','-fvisibility=hidden','-fno-stack-protector','-fno-strict-aliasing','-Wno-implicit-function-declaration','-Wno-int-conversion','-include',str(wb/'include/config.h'),'-include',str(b/'shims/wine_ios_exit.h')]
cmd+=['-I'+str(p) for p in [b/'shims',b.parent/'madsync',wb/'dlls/ntdll',w/'dlls/ntdll',w/'dlls/ntdll/unix',wb/'include',w/'include']]
cmd+=['-D'+x for x in ['HAVE_LINUX_NTSYNC_H=1','__WINESRC__','LTC_NO_PROTOTYPES','LTC_SOURCE','_NTSYSTEM_','_ACRTIMP=','WINBASEAPI=','BINDIR="/usr/local/bin"','LIBDIR="/usr/local/lib"','DATADIR="/usr/local/share"','SYSTEMDLLPATH=""','WINE_UNIX_LIB','WINE_IOS=1','get_thread_context=ntdll_get_thread_context','set_thread_context=ntdll_set_thread_context']]
probe=sp.run(['xcrun','-sdk','iphoneos','clang','-arch','arm64','-isysroot',sdk,'-miphoneos-version-min=17.0','-x','c','-fsyntax-only','-'],input='#include <sys/resource.h>\nvoid p(struct rusage_info_v6*r){(void)r->ri_page_wait_time_mach;}',text=True,capture_output=True)
if probe.returncode==0:cmd+=['-DMADEIRA_HAVE_RUSAGE_PAGE_WAIT_TIME_MACH=1']
obj=out/'virtual.o';cmd+=['-c',str(src),'-o',str(obj)];(out/'compile-command.json').write_text(json.dumps(cmd,indent=2));sp.run(cmd,check=True)
sp.run(['xcrun','lipo',str(obj),'-verify_arch','arm64'],check=True)
candidate=out/archive.name;candidate.write_bytes(archive.read_bytes());sp.run(['xcrun','ar','r',str(candidate),str(obj)],check=True);sp.run(['xcrun','ranlib',str(candidate)],check=True)
after=m.members(candidate.read_bytes());assert collections.Counter(x for x in before if x[0]!='virtual.o')==collections.Counter(x for x in after if x[0]!='virtual.o')
assert [(n,h) for n,h in after if n=='virtual.o']==[('virtual.o',sha(obj))];assert sha(candidate)!=sha(archive)
receipt={'baseline':sha(archive),'candidate':sha(candidate),'source':sha(src),'patch':sha(bundle/'floor/floor-skip.patch'),'object':sha(obj),'untouched_members':len(before)-1,'device_tested':False}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2));archive.write_bytes(candidate.read_bytes())
