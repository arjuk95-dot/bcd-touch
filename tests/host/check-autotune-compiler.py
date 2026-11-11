#!/usr/bin/env python3
"""Optimization must be opt-in, assertion-checked and confined to core tests."""
import ast
import copy
from pathlib import Path
from autotune_test_compiler import CORE_FLAGS, valid_probe

assert CORE_FLAGS == ["-O", "-assert-config", "Debug"]
good = {"positive": 0, "assert": {"returncode": -4, "diagnostic_matched": True},
        "precondition": {"returncode": -5, "diagnostic_matched": True}}
assert valid_probe(good)
for name in ("assert", "precondition"):
    for change in ({"returncode": 0}, {"diagnostic_matched": False}):
        bad = copy.deepcopy(good); bad[name].update(change); assert not valid_probe(bad)
    bad = copy.deepcopy(good); bad.pop(name); assert not valid_probe(bad)
assert not valid_probe({})
bad = copy.deepcopy(good); bad["positive"] = 1; assert not valid_probe(bad)
tree = ast.parse(Path(__file__).with_name("check-autotune.py").read_text())
build = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "build")
assert isinstance(build.args.defaults[-1], ast.Constant) and build.args.defaults[-1].value is False
calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == "build"]
assert len(calls) == 3
for call in calls:
    name = call.args[1].value
    optimized = [k.value for k in call.keywords if k.arg == "optimized"]
    if name in ("replay", "engine"):
        assert len(optimized) == 1 and ast.unparse(optimized[0]) == "args.optimize_core"
    else:
        assert name == "madeira-autotune-glue-check" and not optimized
print("PASS: optional core optimization retains negative assertion probes and never changes glue flags")
