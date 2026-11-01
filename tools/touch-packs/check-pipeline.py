"""Run the actual GamepadInput queue/publisher on an iOS simulator with engine spies."""
from pathlib import Path
import json
import os
import plistlib
import subprocess
import tempfile
import time
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'touch-evidence';out.mkdir(exist_ok=True)
def run(args):return subprocess.check_output(args,text=True).strip()
sdk=run(['xcrun','--sdk','iphonesimulator','--show-sdk-path'])
devices=json.loads(run(['xcrun','simctl','list','devices','available','--json']))['devices']
choices=[dict(d,runtime=r) for r,ds in devices.items() for d in ds if d['name']=='iPhone 16 Pro Max']
device=choices[0];uid=device['udid']
(out/'pipeline-device.json').write_text(json.dumps(device,indent=2))
with tempfile.TemporaryDirectory(prefix='touch-pipeline-') as tmp:
    tmp=Path(tmp);app=tmp/'Pipeline.app';app.mkdir()
    text=(ROOT/'app/Madeira/TouchGamepad.swift').read_text()
    state=tmp/'State.swift';state.write_text('import Foundation\nstruct GamepadSample'+text.split('struct GamepadSample',1)[1].split('// MARK: - UIKit touch lifetime',1)[0])
    sources=[ROOT/'app/Madeira/BCDMouseJoystick.swift',state,ROOT/'app/Madeira/GamepadInput.swift',ROOT/'tests/host/gamepad_pipeline_stubs.swift',ROOT/'tests/host/gamepad_pipeline_app.swift']
    subprocess.run(['xcrun','swiftc','-target',os.uname().machine+'-apple-ios18.0-simulator','-sdk',sdk,'-parse-as-library',*map(str,sources),'-o',str(app/'Pipeline')],check=True)
    info=dict(CFBundleIdentifier='com.arjunkl.bcdtouch.pipeline',CFBundleExecutable='Pipeline',CFBundleName='Input Pipeline Fixture',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1',MinimumOSVersion='18.0',LSRequiresIPhoneOS=True,UIDeviceFamily=[1])
    (app/'Info.plist').write_bytes(plistlib.dumps(info))
    if device['state']!='Booted':subprocess.run(['xcrun','simctl','boot',uid],check=True)
    subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,timeout=180)
    subprocess.run(['xcrun','simctl','install',uid,str(app)],check=True,timeout=180)
    subprocess.run(['xcrun','simctl','launch',uid,'com.arjunkl.bcdtouch.pipeline'],check=True,timeout=120)
    data=Path(run(['xcrun','simctl','get_app_container',uid,'com.arjunkl.bcdtouch.pipeline','data']))/'Documents/pipeline-receipt.txt'
    for _ in range(30):
        if data.exists():break
        time.sleep(1)
    assert data.exists(),'Production pipeline fixture did not pass; inspect simulator crash logs'
    receipt=data.read_text();print(receipt,flush=True);(out/'pipeline-receipt.txt').write_text(receipt)
    subprocess.run(['xcrun','simctl','shutdown',uid],check=True,timeout=30)
