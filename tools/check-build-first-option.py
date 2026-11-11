#!/usr/bin/env python3
"""Locally validate the selected one-shot TEST IPA workflow. Needs PyYAML.

This does not run native code, dispatch CI, or certify the broad regression suite.
"""
import argparse
import copy
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import zipfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
RETAIN_CHECKS = {8, 9, 10, 25, 26, 27, 28, 33, 34, 68, 70, 72, 78, 79,
                 90, 91, 93, 103, 108, 133, 136, 139, 140, 157, 178, 180,
                 181, 182, 183, 184, 185, 193, 194, 195, 196, 204, 206, 208,
                 209, 210, 211, 212, 213, 214, 215, 216, 218, 222, 223, 227,
                 259, 260, 275, 276, 277, 278, 279, 280, 282, 287, 288, 331,
                 338, 459, 463, 466, 503, 504, 528, 533, 563, 626, 628, 630,
                 631, 645, 646, 678, 688, 729}
ADDED = ["Require exact audited source and declare full suite pending",
         "Verify exact historical patch sources before UI and native builds",
         "Mark IPA metadata as TEST with full suite pending",
         "Verify TEST markers and record partial validation only"]
LAUNCH_BRANCH = "wo-bcd-v653-test-first-001"
LAUNCH_GUARD = ("github.repository == 'arjuk95-dot/bcd-touch' && "
                "github.ref == 'refs/heads/wo-bcd-v653-test-first-001' && "
                "github.event_name == 'push' && github.event.created == true && "
                "github.event.deleted == false")


def validate(candidate):
    inventory = json.loads((ROOT / "docs/touch-build-first-inventory.json").read_text())
    original_bytes = (ROOT / inventory["baseline_workflow"]).read_bytes()
    assert hashlib.sha256(original_bytes).hexdigest() == inventory["baseline_workflow_sha256"]
    source = yaml.safe_load(original_bytes)
    original = source["jobs"]["build"]["steps"]
    assert len(original) == 746
    expected_on = {"push": {"branches": [LAUNCH_BRANCH]}}
    assert candidate["on"] == expected_on
    assert candidate["concurrency"] == {
        "group": "bcd-touch-build-first-test-${{ github.ref }}", "cancel-in-progress": False}
    assert "full suite pending" in candidate["name"]
    assert set(candidate["jobs"]) == {"build-test-only"}
    job = candidate["jobs"]["build-test-only"]
    expected_settings = {k: v for k, v in source["jobs"]["build"].items() if k != "steps"}
    expected_settings["if"] = LAUNCH_GUARD
    assert {k: v for k, v in job.items() if k != "steps"} == expected_settings
    retained = []
    for i, (step, record) in enumerate(zip(original, inventory["source_step_inventory"], strict=True), 1):
        assert record["original_step"] == i
        assert record["recipe_sha256"] == hashlib.sha256(json.dumps(step, sort_keys=True).encode()).hexdigest()
        keep = (not step.get("name", "").startswith("Check") or i in RETAIN_CHECKS) and i != 15
        assert record["decision"] == ("retain" if keep else "defer")
        if keep:
            expected = copy.deepcopy(step)
            if i in (744, 746):
                expected["with"]["name"] += "-TEST-full-suite-pending"
                expected["with"]["path"] += "\nbuild-out/TEST-FULL-SUITE-PENDING.json\nbuild-out/TEST-FULL-SUITE-PENDING.txt"
            retained.append(expected)
    steps = job["steps"]
    actual = [s for s in steps if s.get("name") not in ADDED]
    assert actual == retained, "Retained recipes, conditions, caches, artifact inputs or ordering changed"
    assert [s["name"] for s in steps if s.get("name") in ADDED] == ADDED
    assert len(actual) == 304 and len(steps) == 308
    assert {s["id"] for s in original if "id" in s} == {s["id"] for s in steps if "id" in s}
    identifiers = {s["id"] for s in steps if "id" in s}
    for referenced in re.findall(r"steps\.([\w-]+)\.", json.dumps(candidate)):
        assert referenced in identifiers, "Missing step dependency: " + referenced
    assert steps[1]["name"] == ADDED[0]
    assert steps[2]["name"] == ADDED[1]
    assert steps[2]["run"] == ("python3 tests/host/check-overlay-base.py\n"
                               "python3 tests/host/check-overlay-base.py --verify-checkouts")
    positions = {s.get("name"): i for i, s in enumerate(steps)}
    assert positions[ADDED[2]] + 1 == positions["Archive (unsigned)"]
    assert positions["Prepare verified update for the existing BCD slot"] + 1 == positions[ADDED[3]]
    added = {s["name"]: s for s in steps if s.get("name") in ADDED}
    guard = added[ADDED[0]]["run"]
    assert inventory["source_fingerprint_sha256"] in guard
    assert "git', 'submodule', 'status', '--recursive'" in guard
    assert "all(line.startswith(' ')" in guard
    for s in steps:
        if "run" in s:
            subprocess.run(["bash", "-n"], input=s["run"], text=True, check=True)
    for s in added.values():
        if "python3 - <<'PY'" in s["run"]:
            compile(python_body(s["run"]), s["name"], "exec")
    audit_other_workflows(inventory)
    return inventory, added


def audit_other_workflows(inventory):
    """Only two exact branch exclusions may differ; no second automatic job."""
    for path, expected in inventory["branch_exclusions"].items():
        current_bytes = (ROOT / path).read_bytes()
        assert hashlib.sha256(current_bytes).hexdigest() == expected["modified_sha256"]
        old = subprocess.check_output(["git", "show", inventory["baseline_remote_commit"] + ":" + path], cwd=ROOT)
        assert hashlib.sha256(old).hexdigest() == expected["original_sha256"]
        actual = yaml.safe_load(current_bytes)
        assert actual["on"]["push"].pop("branches-ignore") == [LAUNCH_BRANCH]
        assert actual == yaml.safe_load(old), "Changed more than the exact branch exclusion: " + path
    for path in (ROOT / ".github/workflows").glob("*.yml"):
        if path.name == "touch-test-build-first.yml":
            continue
        doc = yaml.safe_load(path.read_bytes())
        events = doc.get("on", doc.get(True))
        if isinstance(events, str):
            events = {events: {}}
        elif isinstance(events, list):
            events = {event: {} for event in events}
        assert not any(event in events for event in ("create", "workflow_run", "workflow_call")), path
        if "push" not in events:
            continue
        push = events["push"] or {}
        branches = push.get("branches")
        ignored = push.get("branches-ignore", [])
        matches = branches is None or any(fnmatch.fnmatchcase(LAUNCH_BRANCH, p) for p in branches)
        matches &= not any(fnmatch.fnmatchcase(LAUNCH_BRANCH, p) for p in ignored)
        assert not matches, "Another automatic workflow accepts the TEST branch: " + path.name


def python_body(command):
    return command.split("python3 - <<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]


def receipt_tests(added):
    """Exercise only new marker/receipt code on local disposable fake IPA fixtures."""
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        plist = root / "app/Madeira/Info.plist"
        plist.parent.mkdir(parents=True)
        original = dict(CFBundleIdentifier="com.arjunkl.bcdtouch", CFBundleVersion="653",
                        CFBundleDisplayName="BCD Touch Lab", MadeiraCommit="test-source")
        plist.write_bytes(plistlib.dumps(original))
        marker = python_body(added[ADDED[2]]["run"])
        subprocess.run(["python3", "-c", marker], cwd=root, check=True)
        marked = plistlib.loads(plist.read_bytes())
        assert all(marked[k] == v for k, v in original.items()), "Marker changed identity/version/source"
        assert marked["BCDValidationStatus"] == "TEST_ONLY_FULL_SUITE_PENDING"
        assert marked["BCDFullValidationRunStatus"] == "FAILED"
        out = root / "build-out"
        (out / "existing-update").mkdir(parents=True)
        for name, bundle_id in [("BCD-Touch-Lab-unsigned.ipa", "com.arjunkl.bcdtouch"),
                                ("existing-update/BCD-Touch-update-existing-unsigned.ipa", "com.thebcd69.bcd")]:
            data = dict(marked, CFBundleIdentifier=bundle_id)
            with zipfile.ZipFile(out / name, "w") as archive:
                archive.writestr("Payload/Madeira.app/Info.plist", plistlib.dumps(data))
        env = dict(os.environ, GITHUB_SHA="test-source", GITHUB_STEP_SUMMARY=str(root / "summary.txt"))
        receipt = python_body(added[ADDED[3]]["run"])
        subprocess.run(["python3", "-c", receipt], cwd=root, env=env, check=True)
        data = json.loads((out / "TEST-FULL-SUITE-PENDING.json").read_text())
        assert data["full_suite"] == "pending" and data["phone_validation"] == "not_run"
        assert data["last_full_suite_run"] == {"id": 43073552781, "result": "failure"}
        assert len(data["artifacts"]) == 2 and data["distribution"] == "TEST_ONLY"
        # Loss of the marker is an error, not a mislabeled successful receipt.
        with zipfile.ZipFile(out / "BCD-Touch-Lab-unsigned.ipa", "w") as archive:
            archive.writestr("Payload/Madeira.app/Info.plist", plistlib.dumps(original))
        rejected = subprocess.run(["python3", "-c", receipt], cwd=root, env=env, capture_output=True)
        assert rejected.returncode != 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, default=ROOT / ".github/workflows/touch-test-build-first.yml")
    args = parser.parse_args()
    candidate = yaml.safe_load(args.candidate.read_text())
    inventory, added = validate(candidate)
    # HEAD contains exactly the baseline plus the four reviewed option files.
    records = subprocess.check_output(["git", "ls-tree", "-rz", "HEAD"], cwd=ROOT).split(b"\0")
    excluded = set(inventory["allowed_new_files"]) | set(inventory["branch_exclusions"])
    raw = b"".join(r + b"\0" for r in records if r and r.split(b"\t", 1)[1].decode() not in excluded)
    assert hashlib.sha256(raw).hexdigest() == inventory["source_fingerprint_sha256"]
    changed = subprocess.check_output(["git", "diff", "--name-only", "HEAD"], cwd=ROOT, text=True).splitlines()
    assert set(changed) <= excluded, "Baseline source modified locally"
    source_fix = subprocess.check_output([
        "git", "diff", "--name-only", inventory["baseline_remote_commit"],
        "HEAD"], cwd=ROOT, text=True).splitlines()
    assert set(source_fix) - excluded == {
        "tests/host/dxmt_base.py", "tests/host/fexpatch_eval.py",
        "tests/host/overlay_base.py", "tests/host/check-overlay-base.py"}, "Unexpected production/source change"
    receipt_tests(added)
    print("PASS: 304 retained source steps, 442 explicitly deferred, all 17 IDs and cache/recipe bodies preserved")
    print("PASS: selected trigger isolation, source fingerprint, shell syntax, TEST-marker/receipt fixtures and missing-marker rejection")
    print("NOT RUN: native Mac build, full regression suite, signed packaging or phone validation")


if __name__ == "__main__":
    main()
