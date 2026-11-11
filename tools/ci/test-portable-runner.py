#!/usr/bin/env python3
"""Negative tests for the migration experiment's fail-closed wrapper."""
import importlib.util
from pathlib import Path

path = Path(__file__).with_name("run-portable-checks.py")
spec = importlib.util.spec_from_file_location("portable_runner", path)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
assert runner.classify_result(0, "PASS: all assertions\n") == "passed"
assert runner.classify_result(1, "PASS: earlier assertion\n") == "failed"
assert runner.classify_result(124, "") == "failed"
for output in ("SKIP: no compiler\n", "check: SKIP missing tool\n", "Skipped unavailable SDK\n"):
    assert runner.classify_result(0, output) == "coverage-skipped", output
assert runner.classify_result(0, "iOS: skipping explorer.exe launch; top_window stays 0\nPASS\n") == "passed"
for argv in ([], ["sh", "check.sh"], ["python3", "../../secret.py"],
             ["python3", "tests/host/check-ok.py", "--skip"]):
    try:
        runner.validate_argv(argv, Path.cwd().resolve())
    except ValueError:
        continue
    raise AssertionError(f"accepted unsafe command {argv}")
print("PASS: nonzero exit, timeout and skipped coverage fail; command inventory is constrained")
