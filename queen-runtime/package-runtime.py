import hashlib, importlib.util, json, os, plistlib, shutil, subprocess, sys, zipfile
from pathlib import Path

root=Path(sys.argv[1]).resolve()
compiled=root/'build-out/QueenRuntime.xcarchive/Products/Applications/Madeira.app'
out=root/'build-out/runtime-package'
assert not out.exists()
app=out/'Payload/Madeira.app'
shutil.copytree(compiled,app)
identity='com.arjunkl.queensdomain.runtime'
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']==identity and info['QueenRuntimeOnly'] is True
assert info['CFBundleVersion']=='1' and info['MadeiraCommit']==os.environ['GITHUB_SHA']
assert not list(app.rglob('embedded.mobileprovision'))
sha=lambda p:hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
donor=json.loads((root/'build-out/donor/donor-manifest.json').read_text())
runtime_roots={'aarch64-windows','arm64ec-windows','i386-windows','x86_64-vcruntime','nls','compat','gl','vulkan','d3d12','soundfont'}
verified=[]
for name,expected in donor['files'].items():
    if name.split('/')[0] in runtime_roots:
        p=app/name
        assert p.is_file() and sha(p)==expected['sha256'], ('Stock runtime changed or absent',name)
        verified.append(name)
assert len(verified)>700, len(verified)
candidate=root/'app/Madeira/arm64ec-windows/xtajit64-queen-nav.dll'
if candidate.is_file():
    shutil.copy2(candidate,app/'arm64ec-windows/xtajit64-queen-nav.dll')
for p in app.rglob('Info.plist'):
    d=plistlib.loads(p.read_bytes())
    old=d.get('CFBundleIdentifier','')
    if old.startswith('com.arjunkl.bcdtouch.'):
        d['CFBundleIdentifier']=identity+old[len('com.arjunkl.bcdtouch'):]
        p.write_bytes(plistlib.dumps(d,fmt=plistlib.FMT_BINARY,sort_keys=False))
helpers=[]
for p in app.glob('PlugIns/*.appex/Info.plist'):
    ident=plistlib.loads(p.read_bytes())['CFBundleIdentifier']
    assert ident.startswith(identity+'.'),ident
    helpers.append(ident)
spec=importlib.util.spec_from_file_location('signer',root/'tools/ota-variants.py')
signer=importlib.util.module_from_spec(spec);spec.loader.exec_module(signer)
signer.fakesign(app)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
signed=subprocess.run(['codesign','--display','--entitlements',':-',str(app)],capture_output=True,check=True)
entitlements=plistlib.loads(signed.stdout)
for key in ['get-task-allow','com.apple.developer.kernel.increased-memory-limit','com.apple.developer.kernel.extended-virtual-addressing']:
    assert entitlements.get(key) is True,key
ipa=root/'build-out/Queen-Domain-Runtime-1.ipa'
subprocess.run(['zip','-qry',str(ipa),'Payload'],cwd=out,check=True)
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None
receipt={'bundle_id':identity,'helpers':helpers,'foundation':'stock653 runtime + 659 verified native object; current reviewed app source',
         'stock_runtime_files_verified':len(verified),'native_render_available':candidate.is_file(),'native_render_default':False,
         'ipa_sha256':sha(ipa),'ipa_bytes':ipa.stat().st_size,'signed':'ad-hoc; personal sideload signing required',
         'compile_verified':True,'device_tested':False,'speedup_measured':False,'game_assets_included':False}
(root/'build-out/runtime-receipt.json').write_text(json.dumps(receipt,indent=2))
(root/'build-out/ipa.sha256').write_text(receipt['ipa_sha256']+'  '+ipa.name+'\n')
print(json.dumps(receipt,indent=2))
