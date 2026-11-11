#!/usr/bin/env python3
"""Run an explicit portable-check inventory; skipped coverage is a failure.

This runner does not rewrite tests, remove sanitizer checks, or infer migration
from a zero exit status alone. The parity workflow checks the pinned source
before any commands run. Receipts identify every command, input and output.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


SKIP = re.compile(r"(?im)^\s*(?:SKIP(?:PED)?\b|[^\n]*:\s*SKIP(?:PED)?\b)")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def validate_argv(argv, repo):
    if (not isinstance(argv, list) or len(argv) != 2 or argv[0] != "python3"
            or not re.fullmatch(r"tests/(?:host|opengl)/[a-z0-9-]+\.py", argv[1])):
        raise ValueError(f"unsupported check command: {argv!r}")
    path = (repo / argv[1]).resolve(strict=True)
    if not path.is_relative_to(repo):
        raise ValueError(f"check escaped source tree: {path}")
    return path


def classify_result(returncode, output):
    if returncode != 0:
        return "failed"
    if SKIP.search(output):
        return "coverage-skipped"
    return "passed"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, default=Path(__file__).with_name("portable-checks.json"))
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args()
    repo = args.repo.resolve(strict=True)
    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    if manifest.get("schema") != 1 or not manifest.get("checks"):
        raise ValueError("unknown or empty manifest")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
    if commit != manifest["baseline_commit"]:
        raise ValueError(f"source {commit} does not match pinned baseline {manifest['baseline_commit']}")
    if subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo, text=True).strip():
        raise ValueError("source tree is not clean")
    submodules = subprocess.check_output(["git", "submodule", "status", "--recursive"], cwd=repo, text=True)
    if any(line.startswith(("-", "+", "U")) for line in submodules.splitlines()):
        raise ValueError("all submodules must match their pinned revisions")
    checks = manifest["checks"]
    identities = [tuple(check["argv"]) for check in checks]
    if len(set(identities)) != len(identities):
        raise ValueError("duplicate commands in manifest")
    # Validate every entry before running the first command.
    paths = [validate_argv(check["argv"], repo) for check in checks]
    output = args.output.resolve()
    if output.is_relative_to(repo):
        raise ValueError("receipts must be outside the checked source tree")
    output.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": 1, "source_commit": commit, "submodules": submodules,
               "manifest_sha256": digest(manifest_bytes), "platform": sys.platform,
               "python": sys.version, "checks": [], "completed": False, "passed": False}
    start_all = time.monotonic()
    for index, (check, path) in enumerate(zip(checks, paths), 1):
        print(f"[{index}/{len(checks)}] START {check['name']}", flush=True)
        start = time.monotonic()
        try:
            run = subprocess.run(check["argv"], cwd=repo, text=True, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=args.timeout,
                                 env={**os.environ, "PYTHONUNBUFFERED": "1"})
            text, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as error:
            captured = error.stdout or b""
            if isinstance(captured, bytes):
                captured = captured.decode("utf-8", errors="replace")
            text, code = captured + "\nFAIL: portable-check timeout\n", 124
        status = classify_result(code, text)
        filename = f"{index:03d}-{path.stem}.log"
        (output / filename).write_text(text)
        receipt["checks"].append({**check, "script_sha256": digest(path.read_bytes()),
                                  "exit_code": code, "status": status,
                                  "seconds": round(time.monotonic() - start, 3),
                                  "log": filename, "log_sha256": digest(text.encode())})
        print(f"[{index}/{len(checks)}] {status.upper()} {check['name']} ({receipt['checks'][-1]['seconds']}s)", flush=True)
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    receipt["completed"] = len(receipt["checks"]) == len(checks)
    receipt["passed"] = receipt["completed"] and all(r["status"] == "passed" for r in receipt["checks"])
    receipt["seconds"] = round(time.monotonic() - start_all, 3)
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"{'PASS' if receipt['passed'] else 'FAIL'}: {len(checks)} explicit portable checks", flush=True)
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
