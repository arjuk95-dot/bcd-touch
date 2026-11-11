#!/usr/bin/env python3
"""Verify the production move guard wiring and its pure association predicate."""
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'app/Madeira/BCDControlPackLive.swift').read_text()
mover = (ROOT / 'app/Madeira/ExternalDrives.swift').read_text()
page = (ROOT / 'app/Madeira/BCDGamePageLive.swift').read_text()
assert mover.index('BCDPackStore.shared.moveBlockReason(entry)') < mover.index('try Self.copyVerifyDelete(copy)')
assert 'let packMoveBlock = BCDPackStore.shared.moveBlockReason(entry)' in page
for key in ['TouchPackGenerated.', 'TouchPackLocal.', 'TouchPack.genre.', 'TouchPack.mode.']:
    assert key in source.split('func moveBlockReason', 1)[1].split('func authoringChoice', 1)[0]
assert 'catch { return BCDPackMoveSafety.reason }' in source
print('PASS: UI and pre-copy guard share pack association checks; preferences and unreadable state protected')
compiler = shutil.which('swiftc')
if not compiler:
    print('SKIP: production Swift association fixtures require swiftc')
    raise SystemExit(0)
helper = source.split('// MARK: - Move safety (Foundation-only regression boundary)', 1)[1]
fixtures = r'''
func check(_ json: String, _ expected: Bool) {
    precondition(BCDPackMoveSafety.blocks(Data(json.utf8), executable:"games/a/game.exe", gameKey:"key-a") == expected, json)
}
check("{}", false)
check("[]", false)
check(#"{"identity":{"executable":"games/b/game.exe"}}"#, false)
check(#"{"identity":{"executable":"GAMES/A/GAME.EXE"}}"#, true)
check(#"{"queued":{"request":{"identity":{"executable":"games/a/game.exe"}}}}"#, true)
check(#"{"key-a.preset":{"pack":{},"baseline":{}}}"#, true)
check(#"{"key-a":{"pack":{}}}"#, true)
check(#"{"key-ab":{"pack":{}}}"#, false)
check("broken JSON", true)
print("PASS: stock/unrelated paths unguarded; generated, queued, preset, legacy edits and corrupt state guarded")
'''
with tempfile.TemporaryDirectory(prefix='bcd-move-safety-') as tmp:
    path = Path(tmp) / 'main.swift'
    path.write_text('import Foundation\n' + helper + fixtures)
    exe = Path(tmp) / 'check'
    subprocess.run([compiler, str(path), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
