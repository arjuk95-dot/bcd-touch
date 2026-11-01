import os
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='bcd-touch-check-') as tmp:
    tmp=Path(tmp)
    source=(ROOT/'app/Madeira/TouchGamepad.swift').read_text(encoding='utf-8')
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
        library=(ROOT/'app/Madeira/Library.swift').read_text()
        def bridge(name):return library.split('// WO-BCD-TOUCH-001 '+name+' actor bridge begin',1)[1].split('// WO-BCD-TOUCH-001 '+name+' actor bridge end',1)[0]
        hooks=tmp/'LegacyHooks.swift'
        hooks.write_text('import Foundation\nstruct DockGame {}\nfinal class LegacyHookProbe {\nfunc begin(_ entry:LibraryEntry,remember:Bool=true,dock:DockGame?=nil) {\n'+bridge('launch')+'\n}\nfunc save(_ entry:LibraryEntry,isNew:Bool) {\n'+bridge('install')+'\n}\n}')
        subprocess.run(['xcrun','swiftc','-typecheck','-parse-as-library','-target',f'{arch}-apple-ios18.0-simulator','-sdk',sdk,*map(str,core),str(ROOT/'app/Madeira/BCDControlPackLive.swift'),str(ROOT/'app/Madeira/BCDControlPackSurface.swift'),str(ROOT/'tests/host/touch_pack_ui_stubs.swift'),str(hooks)],check=True)
        print('PASS: production pack views typechecked against iOS SDK (engine stubs)')
