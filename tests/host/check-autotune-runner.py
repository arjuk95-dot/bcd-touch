#!/usr/bin/env python3
"""Python runner regression: every fixture/chunk/rerun is preserved under bounded replay.
This tests orchestration with a subprocess spy, not Swift classification correctness.
"""
import ast
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'tests/host/check-autotune.py').read_text()
tree = ast.parse(source)
selected = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in {'uk', 'replay_fixture'}]
assert len(selected) == 2
FIX = ROOT / 'tests/fixtures/autotune'
logs = sorted(FIX.glob('*.log'))
expected = {p.stem: json.loads(p.with_suffix('.expect').read_text()) for p in logs}
keys = ('outcome', 'stage', 'matched', 'dialogs', 'status', 'next')

def exercise(workers, mismatch=False):
    calls = []
    def run(command, **kwargs):
        name = Path(command[-1]).stem
        chunk = command[command.index('--chunk') + 1] if '--chunk' in command else 'normal'
        calls.append((name, chunk))
        out = dict(expected[name], facts={'fixture': name})
        if mismatch and chunk == '7':
            out['facts'] = {'unexpected': True}
        return SimpleNamespace(returncode=0, stdout=json.dumps(out), stderr='')
    ns = dict(json=json, subprocess=SimpleNamespace(run=run), FIX=FIX, KEYS=keys)
    exec(compile(ast.Module(body=selected, type_ignores=[]), '<production runner>', 'exec'), ns)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(lambda p: ns['replay_fixture']('fixture-executable', p), logs))
    return results, Counter(calls)

serial, serial_calls = exercise(1)
parallel, parallel_calls = exercise(3)
assert serial == parallel and serial_calls == parallel_calls
assert all(result[1] for group in serial for result in group)
for p in logs:
    for chunk in ('0', '4093', '7'):
        assert serial_calls[p.stem, chunk] == 1
    exp = expected[p.stem]
    needs_normal = bool(exp.get('end', {}).get('killed') and exp['outcome'] in ('crashed', 'exited-early') and exp['matched'])
    assert serial_calls[p.stem, 'normal'] == int(needs_normal)
wrong, _ = exercise(3, mismatch=True)
assert all(not group[0][1] for group in wrong), 'chunk fact mismatch must fail'
preflight = source.index('if not all(required)')
assert all(source.index(f'{name} = build(') < preflight for name in ('replay', 'engine', 'glue_exe'))
assert preflight < source.index('if args.bless is not None:') < source.index('with ThreadPoolExecutor(max_workers=args.jobs)')
subprocess.run([sys.executable, str(ROOT / 'tests/host/check-autotune-compiler.py')], check=True)
print(f'PASS: runner only: all {len(logs)} fixtures, {sum(serial_calls.values())} subprocess calls, three chunks, required normal ends and exact ordered results preserved with 1/3 workers; mismatches fail; all builds precede replay/bless')
