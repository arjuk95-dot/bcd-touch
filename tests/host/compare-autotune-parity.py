#!/usr/bin/env python3
"""Fail closed unless Linux/macOS ran the same complete core suite with identical results."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def compare(left, right):
    assert {left['platform'], right['platform']} == {'Linux', 'Darwin'}, 'need one result per platform'
    assert left['format'] == right['format'] == 1
    assert left['passed'] is True and right['passed'] is True, 'both full suites must pass'
    assert left['source'] == right['source'], 'different commits'
    assert left['inputs'] == right['inputs'], 'different source/fixture bytes'
    expected_inputs = {str(p.relative_to(ROOT)) for p in (ROOT / 'tests/fixtures/autotune').glob('*.log')} | {str(p.relative_to(ROOT)) for p in (ROOT / 'tests/fixtures/autotune').glob('*.expect')} | {
        'app/Madeira/AutoTuneCore.swift', 'app/Madeira/AutoTuneRules.generated.swift',
        'tests/host/autotune_replay.swift', 'tests/host/autotune_engine_checks.swift',
        'tests/host/check-autotune.py', 'tests/host/check-autotune-runner.py'}
    assert set(left['inputs']) == expected_inputs, 'incomplete source/fixture manifest' 
    for path, digest in left['inputs'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, f'input changed: {path}'
    expected = {p.stem: json.loads(p.read_text()) for p in (ROOT / 'tests/fixtures/autotune').glob('*.expect')}
    count = 0
    for report in (left, right):
        fixtures = report['fixtures']
        assert len(fixtures) == len(expected) and {f['fixture'] for f in fixtures} == set(expected), 'missing/duplicate fixture'
        count = 0
        for fixture in fixtures:
            assert set(fixture['chunks']) == {'0', '4093', '7'}, 'missing chunk run'
            assert all('error' not in run for run in fixture['chunks'].values()), 'failed replay'
            exp = expected[fixture['fixture']]
            normal = bool(exp.get('end', {}).get('killed') and exp['outcome'] in ('crashed', 'exited-early') and exp['matched'])
            assert (fixture['normal_end'] is not None) == normal, 'missing/extra normal-end rerun'
            count += 3 + int(normal)
        assert report['engine']['returncode'] == 0, 'engine checks failed'
    assert left['fixtures'] == right['fixtures'], 'platform replay results differ (including facts/normal ends)'
    assert left['engine'] == right['engine'], 'platform engine results differ'
    return len(expected), count

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('linux', type=Path)
    parser.add_argument('macos', type=Path)
    args = parser.parse_args()
    fixtures, runs = compare(json.loads(args.linux.read_text()), json.loads(args.macos.read_text()))
    print(f'PASS: exact Linux/macOS core parity, {fixtures} fixtures/{runs} replays plus engine checks; glue remains Mac-only')
