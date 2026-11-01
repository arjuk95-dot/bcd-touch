import os
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='bcd-touch-check-') as tmp:
    tmp=Path(tmp)
    source=(ROOT/'app/Madeira/TouchGamepad.swift').read_text()
    pure=source.split('struct GamepadSample',1)[1].split('// MARK: - UIKit touch lifetime',1)[0]
    pure='import Foundation\nstruct GamepadSample'+pure
    state=tmp/'State.swift';state.write_text(pure)
    core=[ROOT/'app/Madeira/BCDMouseJoystick.swift',ROOT/'app/Madeira/BCDControlPack.swift',state]
    exe=tmp/'checks'
    subprocess.run(['swiftc',*map(str,core),str(ROOT/'tests/host/touch_pack_checks.swift'),'-o',str(exe)],check=True)
    subprocess.run([str(exe),*map(str,(ROOT/'packs/pilots').glob('*.json'))],check=True)
    if os.uname().sysname=='Darwin':
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        arch=os.uname().machine
        subprocess.run(['xcrun','swiftc','-typecheck','-parse-as-library','-target',f'{arch}-apple-ios18.0-simulator','-sdk',sdk,*map(str,core),str(ROOT/'app/Madeira/BCDControlPackLive.swift'),str(ROOT/'app/Madeira/BCDControlPackSurface.swift'),str(ROOT/'tests/host/touch_pack_ui_stubs.swift')],check=True)
        print('PASS: production pack views typechecked against iOS SDK (engine stubs)')
