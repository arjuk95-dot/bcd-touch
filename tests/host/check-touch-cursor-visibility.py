#!/usr/bin/env python3
"""Compile exact production cursor preference/policy; assert presentation-only wiring."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'app/Madeira/HardwareInput.swift').read_text()
pure = source.split('// BEGIN TOUCH CURSOR VISIBILITY (Foundation-only policy and preference tests)', 1)[1].split('// END TOUCH CURSOR VISIBILITY', 1)[0]
tests = r'''
let suite = "bcd-touch-cursor-test-" + UUID().uuidString
let defaults = UserDefaults(suiteName:suite)!
defer { defaults.removePersistentDomain(forName:suite) }
let a = "C:\\Games\\Inscryption\\Inscryption.exe"
let b = "C:\\Games\\SKALD\\SKALD.exe"
let before = defaults.dictionaryRepresentation()
assert(!BCDTouchCursorVisibility.hidden(for:a,defaults:defaults))
assert(!BCDTouchCursorVisibility.hidden(for:b,defaults:defaults))
assert(Set(defaults.dictionaryRepresentation().keys) == Set(before.keys), "Reading must not seed or migrate preferences")
defaults.set("untouched",forKey:"other-layout")
BCDTouchCursorVisibility.setHidden(true,for:a,defaults:defaults)
assert(BCDTouchCursorVisibility.hidden(for:a,defaults:defaults))
assert(!BCDTouchCursorVisibility.hidden(for:b,defaults:defaults))
let reopened = UserDefaults(suiteName:suite)!
assert(BCDTouchCursorVisibility.hidden(for:a,defaults:reopened), "Choice must survive reopening")
BCDTouchCursorVisibility.setHidden(false,for:a,defaults:defaults)
assert(!BCDTouchCursorVisibility.hidden(for:a,defaults:reopened))
assert(defaults.string(forKey:"other-layout") == "untouched")
let count = defaults.dictionaryRepresentation().count
BCDTouchCursorVisibility.setHidden(true,for:"",defaults:defaults)
assert(!BCDTouchCursorVisibility.hidden(for:"",defaults:defaults))
assert(defaults.dictionaryRepresentation().count == count)
for hidden in [false,true] {
    for touch in [false,true] {
        for mouse in [false,true] {
            for desktop in [false,true] {
                assert(BCDTouchCursorVisibility.suppress(hidden:hidden,touchActive:touch,hardwareMouseConnected:mouse,desktop:desktop)
                    == (hidden && touch && !mouse && !desktop))
            }
        }
    }
}
print("PASS: opt-in per-game cursor hiding, recovery, isolation, no read-time writes, hardware/desktop safe")
'''
render = source.split('private func renderCursor() {',1)[1].split('\n    }',1)[0]
assert 'let visible = !suppress &&' in render
assert 'BCDTouchCursorVisibility.hidden(for: $0.windowsPath)' in render
assert 'hardwareMouseConnected:mouseConnected,desktop:Self.desktopMode' in render
assert 'func refreshTouchCursorVisibility() { renderCursor() }' in source
for forbidden in ['updateRoute(', 'updateAutoLock(', 'winios_pointer(', 'winios_cursor_show(', 'setMouseInUse(', 'cursorState.shown =']:
    assert forbidden not in render, 'Visibility must not mutate routing or guest state: '+forbidden
print('PASS: presentation-only production wiring; guest cursor/routing unchanged')
with tempfile.TemporaryDirectory(prefix='bcd-cursor-visibility-') as temp:
    src = Path(temp)/'main.swift';exe = Path(temp)/'check'
    src.write_text('import Foundation\n'+pure+'\n'+tests)
    subprocess.run([os.environ.get('SWIFTC','swiftc'),str(src),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
