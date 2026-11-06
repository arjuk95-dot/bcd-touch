#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright 2026 thebcd69 (BCD), contributors
# BCD Material: additional terms under GPL-3.0 section 7 apply; see LICENSE-BCD.md.
"""Observe production Dock path detection against a real Network.framework control.

Host diagnostic only: it neither launches Steam nor changes network configuration.
An available host path does not establish iPhone connectivity or Workshop success.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'app/Madeira/MadeiraDock.swift').read_text()
start = source.index('enum DockOffline {')
end = source.index('    private static let key =', start)
production = source[start:end] + '}\n'
assert 'static func begin()' in production and 'static var networkDown:' in production
probe = '''import Foundation
import Network
enum SteamSignIn {
    static func flag(_ name: String, default fallback: Bool) -> Bool { fallback }
}
''' + production + '''
extension DockOffline {
    static var observedPathStatus: String { String(describing: monitor.currentPath.status) }
}
final class Observation: @unchecked Sendable {
    private let lock = NSLock()
    private var status = "no update"
    private var updates = 0
    func record(_ path: NWPath) {
        lock.lock(); defer { lock.unlock() }
        status = String(describing: path.status)
        updates += 1
    }
    func read() -> (String, Int) {
        lock.lock(); defer { lock.unlock() }
        return (status, updates)
    }
}
let observation = Observation()
let control = NWPathMonitor()
let ready = DispatchSemaphore(value: 0)
control.pathUpdateHandler = { path in observation.record(path); ready.signal() }
let before = DockOffline.networkDown
DockOffline.begin()
control.start(queue: DispatchQueue(label: "dock.path.control"))
let received = ready.wait(timeout: .now() + 5) == .success
Thread.sleep(forTimeInterval: 2)
let (status, count) = observation.read()
let result: [String: Any] = [
    "hostDiagnosticOnly": true,
    "phoneTested": false,
    "networkConfigurationChanged": false,
    "productionBeforeBeginOffline": before,
    "productionPathStatus": DockOffline.observedPathStatus,
    "productionReportsOffline": DockOffline.networkDown,
    "controlUpdateReceived": received,
    "controlPathStatus": status,
    "controlUpdates": count,
    "discrepancy": status == "satisfied" && DockOffline.networkDown
]
let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
control.cancel()
'''
with tempfile.TemporaryDirectory(prefix='dock-path-observation-') as directory:
    root = Path(directory)
    swift = root / 'probe.swift'
    swift.write_text(probe)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', str(swift), '-o', str(root / 'probe')], check=True, timeout=60)
    result = json.loads(subprocess.check_output([str(root / 'probe')], text=True, timeout=15))
result['productionSourceSHA256'] = hashlib.sha256(production.encode()).hexdigest()
result['source'] = 'app/Madeira/MadeiraDock.swift: production DockOffline networking block'
result['meaning'] = ('Host observes an available control path while production reports offline.'
                     if result['discrepancy'] else
                     'No connected-control discrepancy observed on this host; phone permissions remain unverified.')
output = ROOT / 'touch-evidence/dock-network-observation.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
