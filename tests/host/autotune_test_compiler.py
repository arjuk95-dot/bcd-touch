"""Checked optimization for test executables only. Never used by the app build."""
from pathlib import Path
import subprocess

CORE_FLAGS = ["-O", "-assert-config", "Debug"]


def valid_probe(result):
    return (result.get("positive") == 0
            and all(result.get(name, {}).get("returncode", 0) < 0
                    and result[name].get("diagnostic_matched") is True
                    for name in ("assert", "precondition")))


def verify_checked_optimization(swiftc, directory):
    directory = Path(directory)
    source, exe = directory / "assert-probe.swift", directory / "assert-probe"
    source.write_text('''
@main struct AssertionProbe {
    static func main() {
        switch CommandLine.arguments[1] {
        case "assert": assert(false, "bcd-assert-negative-probe")
        case "precondition": precondition(false, "bcd-precondition-negative-probe")
        default: print("bcd-positive-probe")
        }
    }
}
''')
    built = subprocess.run([swiftc, "-parse-as-library", "-swift-version", "5", *CORE_FLAGS,
                            str(source), "-o", str(exe)], capture_output=True, text=True, timeout=120)
    if built.returncode:
        raise RuntimeError("checked optimization probe failed to compile: " + built.stderr[-3000:])
    positive = subprocess.run([str(exe), "ok"], capture_output=True, text=True, timeout=30)
    result = {"positive": positive.returncode, "flags": CORE_FLAGS}
    if positive.stdout.strip() != "bcd-positive-probe":
        raise RuntimeError("checked optimization positive control did not run")
    for name in ("assert", "precondition"):
        probe = subprocess.run([str(exe), name], capture_output=True, text=True, timeout=30)
        result[name] = {"returncode": probe.returncode,
                        "diagnostic_matched": f"bcd-{name}-negative-probe" in probe.stdout + probe.stderr}
    if not valid_probe(result):
        raise RuntimeError(f"optimized test assertions are not proved active: {result}")
    result["passed"] = True
    return result
