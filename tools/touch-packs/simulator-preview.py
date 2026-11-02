"""Landscape production-renderer fixtures executed inside an iPhone simulator, no guest game."""
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
candidates=[dict(d,runtime=r) for r,ds in devices.items() for d in ds if d['name']=='iPhone 16 Pro Max']
if not candidates:candidates=[dict(d,runtime=r) for r,ds in devices.items() for d in ds if 'iPhone' in d['name']]
device=candidates[0];uid=device['udid']
(out/'selected-devices.json').write_text(json.dumps(device,indent=2));print(device,flush=True)
with tempfile.TemporaryDirectory(prefix='touch-preview-') as tmp:
    tmp=Path(tmp);app=tmp/'TouchPreview.app';app.mkdir()
    text=(ROOT/'app/Madeira/TouchGamepad.swift').read_text()
    state=tmp/'State.swift';state.write_text('import Foundation\nstruct GamepadSample'+text.split('struct GamepadSample',1)[1].split('// MARK: - UIKit touch lifetime',1)[0])
    routing=(ROOT/'app/Madeira/ContentView.swift').read_text()
    window=tmp/'Window.swift';window.write_text('import UIKit\nfinal class ControlsWindow: UIWindow {'+routing.split('final class ControlsWindow: UIWindow {',1)[1].split('\nenum TouchControlsHost',1)[0])
    gate=tmp/'Gate.swift';gate.write_text('import UIKit\n@MainActor enum TouchMouseGate {'+routing.split('@MainActor enum TouchMouseGate {',1)[1].split('\n}\n',1)[0]+'\n}')
    sources=[ROOT/'app/Madeira/BCDMouseJoystick.swift',ROOT/'app/Madeira/BCDControlPack.swift',state,window,gate,ROOT/'app/Madeira/BCDControlPackLive.swift',ROOT/'app/Madeira/BCDControlPackSurface.swift',ROOT/'tests/host/touch_pack_ui_stubs.swift',ROOT/'tests/host/touch_pack_preview.swift']
    subprocess.run(['xcrun','swiftc','-target',os.uname().machine+'-apple-ios18.0-simulator','-sdk',sdk,'-parse-as-library',*map(str,sources),'-o',str(app/'TouchPreview')],check=True)
    info=dict(CFBundleIdentifier='com.arjunkl.bcdtouch.preview',CFBundleExecutable='TouchPreview',CFBundleName='Touch Preview',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1',MinimumOSVersion='18.0',LSRequiresIPhoneOS=True,UIDeviceFamily=[1,2],UIRequiresFullScreen=True,UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'])
    (app/'Info.plist').write_bytes(plistlib.dumps(info))
    pilots=list((ROOT/'packs/pilots').glob('*.json'))
    for p in pilots:shutil.copyfile(p,app/p.name)
    shutil.copyfile(pilots[0],app/'pack.json')
    if device['state']!='Booted':subprocess.run(['xcrun','simctl','boot',uid],check=True)
    subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,timeout=180)
    subprocess.run(['xcrun','simctl','uninstall',uid,'com.arjunkl.bcdtouch.preview'],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    subprocess.run(['xcrun','simctl','install',uid,str(app)],check=True,timeout=180)
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',uid,'com.arjunkl.bcdtouch.preview'],env=dict(os.environ,SIMCTL_CHILD_PACK_FIXTURES='1'),check=True,timeout=120)
    container=Path(run(['xcrun','simctl','get_app_container',uid,'com.arjunkl.bcdtouch.preview','data']))/'Documents'
    for _ in range(45):
        if len(list(container.glob('*.png')))==14 and (container/'client-phase-1.txt').exists():break
        time.sleep(1)
    for p in container.glob('client-*.txt'):shutil.copyfile(p,out/p.name)
    for p in container.glob('*routing*.txt'):shutil.copyfile(p,out/p.name)
    for p in container.glob('*regression*.txt'):shutil.copyfile(p,out/p.name)
    assert (container/'client-phase-1.txt').exists(),'Production Swift store client fixture did not finish'
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',uid,'com.arjunkl.bcdtouch.preview'],env=dict(os.environ,SIMCTL_CHILD_PACK_FIXTURES='1',SIMCTL_CHILD_PACK_CLIENT_RESUME='1'),check=True,timeout=120)
    for _ in range(30):
        if (container/'client-phase-2.txt').exists():break
        time.sleep(1)
    assert (container/'client-phase-2.txt').exists(),'Production Swift store restart fixture did not finish'
    images=list(container.glob('*.png'));assert len(images)==14,'Renderer/editor fixture export did not complete'
    for p in images:shutil.copyfile(p,out/p.name)
    for p in container.glob('*-swift-identity.txt'):shutil.copyfile(p,out/p.name)
    for p in container.glob('*-context-visibility.txt'):shutil.copyfile(p,out/p.name)
    for p in container.glob('client-*.txt'):shutil.copyfile(p,out/p.name)
    (out/'preview-receipt.json').write_text(json.dumps(dict(device=device['name'],runtime=device['runtime'],kind='offscreen production UIKit renderer fixtures on this simulator; phone 956x440 points with 62/62/0/21 insets; iPad 1194x834 points with 0/0/24/20 insets; no actual iPad boot or game',images=[p.name for p in images]),indent=2))
    subprocess.run(['xcrun','simctl','shutdown',uid],check=True,timeout=30)
