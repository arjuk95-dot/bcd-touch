"""Capture production HUD and actual hit regions in iOS simulators, labelled as previews."""
from pathlib import Path
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
import time
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'touch-evidence';out.mkdir(exist_ok=True)
def run(args,**kw):return subprocess.check_output(args,text=True,**kw).strip()
sdk=run(['xcrun','--sdk','iphonesimulator','--show-sdk-path'])
devices=json.loads(run(['xcrun','simctl','list','devices','available','--json']))['devices']
choices=[]
for family,name in [('phone','iPhone 16 Pro Max'),('pad','iPad Pro 11-inch (M4)')]:
    candidates=[dict(d,runtime=r) for r,ds in devices.items() for d in ds if name in d['name']]
    if not candidates:candidates=[dict(d,runtime=r) for r,ds in devices.items() for d in ds if ('iPhone' if family=='phone' else 'iPad') in d['name']]
    assert candidates,'No simulator available'
    choices.append((family,candidates[-1]))
receipt=[]
(out/'selected-devices.json').write_text(json.dumps(choices,indent=2))
print('Selected simulator devices:',choices,flush=True)
with tempfile.TemporaryDirectory(prefix='touch-preview-') as tmp:
    tmp=Path(tmp);app=tmp/'TouchPreview.app';app.mkdir()
    text=(ROOT/'app/Madeira/TouchGamepad.swift').read_text()
    state=tmp/'State.swift';state.write_text('import Foundation\nstruct GamepadSample'+text.split('struct GamepadSample',1)[1].split('// MARK: - UIKit touch lifetime',1)[0])
    sources=[ROOT/'app/Madeira/BCDMouseJoystick.swift',ROOT/'app/Madeira/BCDControlPack.swift',state,ROOT/'app/Madeira/BCDControlPackLive.swift',ROOT/'app/Madeira/BCDControlPackSurface.swift',ROOT/'tests/host/touch_pack_ui_stubs.swift',ROOT/'tests/host/touch_pack_preview.swift']
    subprocess.run(['xcrun','swiftc','-target',os.uname().machine+'-apple-ios18.0-simulator','-sdk',sdk,'-parse-as-library',*map(str,sources),'-o',str(app/'TouchPreview')],check=True)
    info=dict(CFBundleIdentifier='com.arjunkl.bcdtouch.preview',CFBundleExecutable='TouchPreview',CFBundleName='Touch Preview',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1',MinimumOSVersion='18.0',LSRequiresIPhoneOS=True,UIDeviceFamily=[1,2],UIRequiresFullScreen=True,UIInterfaceOrientation='UIInterfaceOrientationLandscapeLeft',UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'])
    (app/'Info.plist').write_bytes(plistlib.dumps(info))
    for family,device in choices:
        uid=device['udid']
        if device['state']!='Booted':subprocess.run(['xcrun','simctl','boot',uid],check=True)
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,timeout=180)
        for pilot in (ROOT/'packs/pilots').glob('*.json'):
            shutil.copyfile(pilot,app/'pack.json')
            subprocess.run(['xcrun','simctl','install',uid,str(app)],check=True)
            for debug in [False,True]:
                env=dict(os.environ,SIMCTL_CHILD_PACK_DEBUG='1' if debug else '0')
                subprocess.run(['xcrun','simctl','launch','--terminate-running-process',uid,'com.arjunkl.bcdtouch.preview'],env=env,check=True)
                time.sleep(3)
                name=f'{pilot.stem}-{family}-'+('hits' if debug else 'hud')+'.png'
                subprocess.run(['xcrun','simctl','io',uid,'screenshot',str(out/name)],check=True)
                receipt.append(dict(image=name,device=device['name'],runtime=device['runtime'],kind='simulator production renderer with engine stubs; no game running'))
        subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
(out/'preview-receipt.json').write_text(json.dumps(receipt,indent=2))
