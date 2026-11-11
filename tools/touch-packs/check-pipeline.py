"""Run the actual GamepadInput queue/publisher on an iOS simulator with engine spies."""
from pathlib import Path
import json
import os
import plistlib
import re
import sys
import subprocess
import tempfile
import time
ROOT=Path(__file__).resolve().parents[2]
# Fixture boundaries must not shadow a production type compiled in this target.
# This preflight also runs on hosts without the Apple SDK.
def declared_types(path):
    return set(re.findall(r"\b(?:class|struct|enum)\s+(\w+)\s*[:{]", path.read_text()))
production_types=declared_types(ROOT/'app/Madeira/GamepadInput.swift')
fixture_types=declared_types(ROOT/'tests/host/gamepad_pipeline_stubs.swift')
assert not production_types & fixture_types, f'Duplicate pipeline fixture types: {sorted(production_types & fixture_types)}'
print('PASS: production publisher fixture boundaries do not redeclare production types',flush=True)
if '--check-boundaries' in sys.argv:
    sys.exit(0)
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
    subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,timeout=360)
    subprocess.run(['xcrun','simctl','uninstall',uid,'com.arjunkl.bcdtouch.pipeline'],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    subprocess.run(['xcrun','simctl','install',uid,str(app)],check=True,timeout=180)
    folder=Path(run(['xcrun','simctl','get_app_container',uid,'com.arjunkl.bcdtouch.pipeline','data']))/'Documents'
    for index in range(6):
        subprocess.run(['xcrun','simctl','launch','--terminate-running-process',uid,'com.arjunkl.bcdtouch.pipeline'],env=dict(os.environ,SIMCTL_CHILD_RESERVATION_FIXTURE=str(index)),check=True,timeout=120)
        receipt=folder/f'reservation-{index}.txt'
        for _ in range(30):
            if receipt.exists():break
            time.sleep(1)
        if not receipt.exists():
            for evidence in folder.glob('*.txt'):(out/evidence.name).write_bytes(evidence.read_bytes())
            try:
                diagnostic=subprocess.run(['xcrun','simctl','spawn',uid,'log','show','--style','compact','--last','5m','--predicate','process == "Pipeline"'],capture_output=True,text=True,timeout=20)
                (out/'pipeline-simulator-app-log.txt').write_text((diagnostic.stdout+diagnostic.stderr)[-100000:])
            except subprocess.TimeoutExpired:(out/'pipeline-simulator-app-log.txt').write_text('Simulator log query timed out')
            reports=Path.home()/'Library/Logs/DiagnosticReports'
            for report in sorted(reports.glob('Pipeline*.ips'),key=lambda p:p.stat().st_mtime)[-2:]:
                if report.stat().st_size<=2*1024*1024:(out/report.name).write_bytes(report.read_bytes())
        assert receipt.exists(),f'Production startup reservation case {index} did not pass; inspect preserved startup/log/crash evidence'
        (out/receipt.name).write_text(receipt.read_text())
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',uid,'com.arjunkl.bcdtouch.pipeline'],check=True,timeout=120)
    data=Path(run(['xcrun','simctl','get_app_container',uid,'com.arjunkl.bcdtouch.pipeline','data']))/'Documents/pipeline-receipt.txt'
    for _ in range(30):
        if data.exists():break
        time.sleep(1)
    assert data.exists(),'Production pipeline fixture did not pass; inspect simulator crash logs'
    receipt=data.read_text();print(receipt,flush=True);(out/'pipeline-receipt.txt').write_text(receipt)
    subprocess.run(['xcrun','simctl','shutdown',uid],check=True,timeout=30)
