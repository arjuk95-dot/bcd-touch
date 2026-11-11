#!/usr/bin/env python3
"""Run exact-source AutoTune core using only a GNU libc import flag outside checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys
import time

SOURCE = "3f71fd2c5eeaf64c8970882841aebc5803dbf952"
FLAGS = ["-Xcc", "-D_GNU_SOURCE"]
PROBE = r'''import Foundation
let haystack: [UInt8] = [65, 0, 66, 67, 66, 67]
let needle: [UInt8] = [0, 66, 67]
let absent: [UInt8] = [99, 100]
haystack.withUnsafeBytes { h in
    needle.withUnsafeBytes { n in
        let hit = memmem(h.baseAddress!, h.count, n.baseAddress!, n.count)
        precondition(hit != nil)
        precondition(UnsafeRawPointer(hit!) - h.baseAddress! == 1)
        precondition(memmem(h.baseAddress!, 2, n.baseAddress!, n.count) == nil)
        precondition(memmem(h.baseAddress!, h.count, n.baseAddress!, 0) == h.baseAddress!)
    }
    absent.withUnsafeBytes { n in
        precondition(memmem(h.baseAddress!, h.count, n.baseAddress!, n.count) == nil)
    }
}
print("PASS: libc memmem binary match, offset, bounded search, empty needle, absent needle")
'''
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, required=True)
parser.add_argument("--swiftc", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
a = parser.parse_args()
source, swiftc, output = a.source.resolve(), a.swiftc.resolve(), a.output.resolve()
assert platform.system() == "Linux", "Linux-only interop experiment"
assert not output.is_relative_to(source), "wrapper and artifacts must stay outside source"
assert swiftc.is_file(), "official Swift toolchain missing"
output.mkdir(parents=True, exist_ok=True)
def git(*args):
    return subprocess.check_output(["git", *args], cwd=source, text=True).strip()
assert git("rev-parse", "HEAD") == SOURCE, "must test exact native source"
assert not git("status", "--porcelain"), "source checkout must be clean"
version = subprocess.check_output([str(swiftc), "--version"], text=True)
assert "Swift version 6.1.2" in version, version
metadata = {"source": SOURCE, "platform": platform.platform(), "swift": version,
            "passed": False, "swiftc_sha256": hashlib.sha256(swiftc.read_bytes()).hexdigest(),
            "submodule_state": git("submodule", "status", "--recursive"),
            "compiler_import_flags": FLAGS, "core_flags": ["-O", "-assert-config", "Debug"],
            "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "probe_sha256": hashlib.sha256(PROBE.encode()).hexdigest(), "stages": []}
(output / "memmem.swift").write_text(PROBE)
bin_dir = output / "bin"
bin_dir.mkdir(exist_ok=True)
wrapper = bin_dir / "swiftc"
wrapper.write_text("#!/bin/sh\nexec " + shlex.join([str(swiftc), *FLAGS]) + ' "$@"\n')
wrapper.chmod(0o755)
metadata["wrapper_sha256"] = hashlib.sha256(wrapper.read_bytes()).hexdigest()
env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
           CLANG_MODULE_CACHE_PATH=str(output / "module-cache"),
           SWIFT_MODULECACHE_PATH=str(output / "module-cache"), PYTHONUNBUFFERED="1")
def run(name, command):
    print(f"Starting {name}", flush=True)
    start = time.monotonic()
    result = subprocess.run(command, cwd=source, env=env)
    metadata["stages"].append({"name": name, "argv": command,
                               "seconds": time.monotonic() - start, "exit": result.returncode})
    result.check_returncode()
try:
    run("memmem compile", [str(wrapper), str(output / "memmem.swift"), "-o", str(output / "memmem")])
    run("memmem behavior", [str(output / "memmem")])
    run("receipt regression", [sys.executable, "tests/host/check-autotune-parity-report.py"])
    run("full core", [sys.executable, "tests/host/check-autotune.py", "--require-swift",
                      "--suite", "core", "--jobs", "3", "--optimize-core",
                      "--parity-output", str(output / "parity.json")])
    assert not git("status", "--porcelain"), "source changed during experiment"
    report = json.loads((output / "parity.json").read_text())
    assert report["source"] == SOURCE and report["passed"] is True
    assert len(report["fixtures"]) == 826
    assert sum(len(f["chunks"]) + int(f["normal_end"] is not None) for f in report["fixtures"]) == 2503
    metadata["receipt_sha256"] = hashlib.sha256((output / "parity.json").read_bytes()).hexdigest()
    metadata["passed"] = True
finally:
    (output / "interop-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
