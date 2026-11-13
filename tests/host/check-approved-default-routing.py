#!/usr/bin/env python3
"""Exercise the exact production launch-choice helper, not a copied routing policy."""
import os,subprocess,tempfile
from pathlib import Path
r=Path(__file__).resolve().parents[2]
live=(r/'app/Madeira/BCDControlPackLive.swift').read_text()
pure=live.split('// BEGIN APPROVED DEFAULT ROUTING (pure; exercised by launch-routing fixtures)',1)[1].split('// END APPROVED DEFAULT ROUTING',1)[0]
assert 'let route=BCDApprovedDefaultRouting.choose(' in live
assert 'tableSurface=route.table' in live
assert 'let candidate = BCDNoitaPack.matches' in live and ': route.pack' in live
assert 'UserDefaults.standard.set(tableKind(entry),forKey:"TouchPackPointer."' in live
preference=live.split('func setLaunchPreference',1)[1].split('func preferStockNextLaunch',1)[0]
assert 'TouchPackLocal.' not in preference, 'Mode toggle must not deselect personal layouts'
assert 'object(forKey:key) as? Bool ?? true' in live, 'Explicit stock preference remains respected'
assert 'enabled && BCDPackStore.shared.hasSurface' in (r/'app/Madeira/Library.swift').read_text()
preparation=live.split('func prepare(',1)[1].split('private func cached',1)[0]
assert 'usePreset(entry)' not in preparation, 'Background preparation must not change explicit stock/local choices'
assert 'url=installedExecutable(entry)' in live
assert 'url=LibraryEntry.hostURL(ofWindowsPath:entry.launchWindowsPath)' not in live
assert 'Identity(executable: entry.launchRelativePath.lowercased()' in live, 'Persisted identity must not be rewritten by proof lookup'
assert 'entry.steamAppID == 2371890 || entry.title.' in live
with tempfile.TemporaryDirectory(prefix='bcd-default-routing-') as t:
 t=Path(t);(t/'Routing.swift').write_text('import Foundation\n'+pure)
 # Existing pure model test extracts the same platform-independent gamepad structs.
 src=(r/'app/Madeira/TouchGamepad.swift').read_text().split('struct GamepadSample',1)[1].split('// MARK: - UIKit touch lifetime',1)[0]
 (t/'Gamepad.swift').write_text('import Foundation\nstruct GamepadSample'+src)
 sources=['BCDMouseJoystick.swift','BCDControlPack.swift','BCDControlPackAuthoring.swift','BCDQueensDomainPack.swift','BCDSulfurPack.swift','BCDDreadPack.swift','BCDChroniclesPack.swift','BCDTenebrisOwnerCompatibility.swift']
 subprocess.run([os.environ.get('SWIFTC','swiftc'),'-parse-as-library','-swift-version','5',*[str(r/'app/Madeira'/x) for x in sources],str(t/'Gamepad.swift'),str(t/'Routing.swift'),str(r/'tests/host/approved_default_routing_checks.swift'),'-o',str(t/'check')],check=True)
 subprocess.run([str(t/'check')],check=True)
