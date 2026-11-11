#!/usr/bin/env python3
"""Negative tests for parity receipt validation; does not stand in for Swift parity."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('parity', ROOT / 'tests/host/compare-autotune-parity.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
inputs = [ROOT / p for p in ('app/Madeira/AutoTuneCore.swift', 'app/Madeira/AutoTuneRules.generated.swift',
                            'tests/host/autotune_replay.swift', 'tests/host/autotune_engine_checks.swift',
                            'tests/host/check-autotune.py', 'tests/host/check-autotune-runner.py')]
inputs += sorted((ROOT / 'tests/fixtures/autotune').glob('*.log')) + sorted((ROOT / 'tests/fixtures/autotune').glob('*.expect'))
left = dict(format=1, platform='Linux', passed=True, source='fixture-source',
            inputs={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
            fixtures=[], engine=dict(returncode=0, stdout='fixture only', stderr=''))
for path in sorted((ROOT / 'tests/fixtures/autotune').glob('*.expect')):
    exp = json.loads(path.read_text())
    normal = bool(exp.get('end', {}).get('killed') and exp['outcome'] in ('crashed', 'exited-early') and exp['matched'])
    left['fixtures'].append(dict(fixture=path.stem, chunks={key: {'fixture': path.stem} for key in ('0', '4093', '7')},
                                 normal_end={'fixture': path.stem} if normal else None))
right = copy.deepcopy(left); right['platform'] = 'Darwin'
assert module.compare(left, right) == (826, 2503)
mutations = [lambda r: r.update(passed=False), lambda r: r.update(platform='Linux'),
             lambda r: r.update(source='other'), lambda r: r['inputs'].pop(next(iter(r['inputs']))),
             lambda r: r['fixtures'].pop(), lambda r: r['fixtures'][0]['chunks'].pop('7'),
             lambda r: r['fixtures'][0]['chunks']['7'].update(changed=True),
             lambda r: r['engine'].update(returncode=1),
             lambda r: r['fixtures'][0].update(normal_end={'extra': True})]
for mutate in mutations:
    bad = copy.deepcopy(right); mutate(bad)
    try:
        module.compare(left, bad)
    except AssertionError:
        pass
    else:
        raise AssertionError('invalid parity receipt accepted')
print('PASS: parity report validation and nine negative cases (synthetic receipts only)')
