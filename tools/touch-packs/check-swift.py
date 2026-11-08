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
    core=[ROOT/'app/Madeira/BCDMouseJoystick.swift',ROOT/'app/Madeira/BCDControlPack.swift',ROOT/'app/Madeira/BCDControlPackAuthoring.swift',ROOT/'app/Madeira/BCDCursorPack.swift',ROOT/'app/Madeira/BCDNoitaPack.swift',state]
    exe=tmp/'checks'
    subprocess.run(['swiftc',*map(str,core),str(ROOT/'tests/host/touch_authoring_checks.swift'),str(ROOT/'tests/host/touch_cursor_checks.swift'),str(ROOT/'tests/host/touch_surface_tap_checks.swift'),str(ROOT/'tests/host/touch_pack_checks.swift'),'-o',str(exe)],check=True)
    (ROOT/'touch-evidence').mkdir(exist_ok=True)
    os.environ['NOITA_PACK_EXPORT']=str(ROOT/'touch-evidence/noita-controls-v4.json')
    subprocess.run([str(exe),*map(str,(ROOT/'packs/pilots').glob('*.json')),*['personal:'+str(p) for p in (ROOT/'packs/personal').glob('*.json')]],check=True)
    if os.uname().sysname=='Darwin':
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        arch=os.uname().machine
        library=(ROOT/'app/Madeira/Library.swift').read_text()
        def bridge(name):return library.split('// WO-BCD-TOUCH-001 '+name+' actor bridge begin',1)[1].split('// WO-BCD-TOUCH-001 '+name+' actor bridge end',1)[0]
        hooks=tmp/'LegacyHooks.swift'
        hooks.write_text('import Foundation\nstruct DockGame {}\nfinal class LegacyHookProbe {\nfunc begin(_ entry:LibraryEntry,remember:Bool=true,dock:DockGame?=nil) {\n'+bridge('launch')+'\n}\nfunc save(_ entry:LibraryEntry,isNew:Bool) {\n'+bridge('install')+'\n}\n}')
        content=(ROOT/'app/Madeira/ContentView.swift').read_text()
        routing=tmp/'WindowAttachment.swift'
        routing.write_text('import UIKit\nimport SwiftUI\nfinal class ControlsWindow: UIWindow {'+
            content.split('final class ControlsWindow: UIWindow {',1)[1].split('\nstruct TouchControlsOverlay:',1)[0]+
            '\nstruct TouchControlsOverlay:View { nonisolated init() {}\nvar body:some View { EmptyView() } }\n')
        subprocess.run(['xcrun','swiftc','-typecheck','-parse-as-library','-target',f'{arch}-apple-ios18.0-simulator','-sdk',sdk,*map(str,core),str(ROOT/'app/Madeira/BCDControlPackLive.swift'),str(ROOT/'app/Madeira/BCDCursorPackSettings.swift'),str(ROOT/'app/Madeira/BCDControlPackSurface.swift'),str(ROOT/'tests/host/touch_pack_ui_stubs.swift'),str(hooks),str(routing)],check=True)
        print('PASS: production pack views, window routing and legacy attachment typechecked against iOS SDK (engine/view boundaries stubbed)')
