#!/usr/bin/env python3
"""Reuse artifact-backed UIKit steps only when their source/fixtures are unchanged."""
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import urllib.error
import urllib.request
import zipfile

BASE = '6422f99efbcc2b8e74a5e30469709600e4a6a5c9'
RUN = 43436217425
JOB = 131921906785
ARTIFACT = 14046716808
DIGEST = '68c9226115dd9b84baca2557bd25a27b67f070bc95ac7b834ef8b94656215325'
API = 'https://api.github.com/repos/arjuk95-dot/bcd-touch/'
ALLOWED_CHANGES = {
    '.github/workflows/touch-profiles-ipa.yml',
    'tools/ci/verify-approved-native-evidence.py',
    'tools/ci/check-donor-converter-inputs.py',
    'tests/host/check-native-evidence-reuse.py',
}
REQUIRED_STEPS = {
    'Verify clean source before combined native validation and build',
    'Compile changed production touch code and UIKit interaction fixtures',
    'Check control presets', 'Check preview build cache correctness',
    "Check BCD's touch controls", 'Check the app sources are in the Xcode project',
}
PASS_RECEIPTS = {
    'client-phase-1.txt', 'client-phase-2.txt', 'pack-interaction-regression.txt',
    'tenebris-interaction-regression.txt', 'tenebris-tap-interaction-regression.txt',
    'controls-window-routing.txt', 'free-placement-regression.txt',
    'noita-ui-regression.txt', 'authoring-fixtures.txt',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_source(root):
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root, text=True)
    changed = set(git('diff', '--name-only', BASE, 'HEAD').splitlines())
    require(changed <= ALLOWED_CHANGES,
            'Production/native fixture inputs changed; fresh validation required: ' + repr(sorted(changed - ALLOWED_CHANGES)))
    # Include every production source/header and all preset/test inputs, not just
    # selected files. Donor staging intentionally changes binary resources and the
    # config catalog, which these stubbed touch fixtures do not compile or read.
    paths = ['packs', 'tools/touch-packs', 'tests/fixtures', 'tests/host',
             'app/Madeira.xcodeproj', ':(glob)app/**/*.swift', ':(glob)app/**/*.h',
             ':(glob)app/**/*.m', ':(glob)app/**/*.mm', ':(glob)app/**/*.c',
             ':(exclude)app/Madeira/ConfigCatalog.generated.swift',
             ':(exclude)tests/host/check-native-evidence-reuse.py']
    dirty = git('diff', '--name-only', 'HEAD', '--', *paths).splitlines()
    require(not dirty, 'Uncommitted native inputs changed: ' + repr(dirty))
    return git('rev-parse', 'HEAD').strip()


def verify_metadata(run, job, artifact):
    require(run.get('id') == RUN and run.get('head_sha') == BASE and run.get('status') == 'completed', 'Wrong/incomplete evidence run')
    require(job.get('id') == JOB and job.get('run_id') == RUN and job.get('status') == 'completed', 'Wrong/incomplete evidence job')
    if 'head_sha' in job:
        require(job['head_sha'] == BASE, 'Wrong job source')
    for name in REQUIRED_STEPS:
        matches = [s for s in job.get('steps', []) if s.get('name') == name]
        require(len(matches) == 1 and matches[0].get('status') == 'completed' and matches[0].get('conclusion') == 'success', 'Native step not uniquely successful: ' + name)
    wr = artifact.get('workflow_run', {})
    require(artifact.get('id') == ARTIFACT and wr.get('id') == RUN and wr.get('head_sha') == BASE, 'Wrong artifact provenance')
    require(not artifact.get('expired', True) and artifact.get('digest') == 'sha256:' + DIGEST, 'Expired or changed artifact')


def verified_files(data):
    require(hashlib.sha256(data).hexdigest() == DIGEST, 'Native evidence ZIP hash mismatch')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        infos = archive.infolist()
        require(len(infos) <= 1000 and sum(i.file_size for i in infos) <= 64 * 1024**2, 'Evidence exceeds size limit')
        seen, selected = set(), {}
        for info in infos:
            name = info.filename.rstrip('/')
            p = PurePosixPath(name)
            require(name and not p.is_absolute() and not any(c in name for c in ('\\', ':', '\x00')) and all(c not in ('', '.', '..') for c in name.split('/')), 'Unsafe evidence path')
            require(name.casefold() not in seen, 'Duplicate evidence path')
            seen.add(name.casefold())
            require(stat.S_IFMT(info.external_attr >> 16) in (0, stat.S_IFREG, stat.S_IFDIR), 'Evidence links/special files forbidden')
            require(not info.flag_bits & 1, 'Encrypted evidence forbidden')
            if name.startswith('touch-evidence/') and not info.is_dir():
                relative = p.relative_to('touch-evidence')
                require(len(relative.parts) == 1, 'Unexpected nested touch evidence')
                selected[str(relative)] = archive.read(info)
        for name in PASS_RECEIPTS:
            require(selected.get(name, b'').startswith(b'PASS:'), 'Passing receipt absent: ' + name)
        images = {name for name in selected if name.endswith('.png')}
        require(len(images) == 59 and all(selected[n].startswith(b'\x89PNG\r\n\x1a\n') for n in images), 'Renderer images missing/invalid')
        preview = json.loads(selected['preview-receipt.json'])
        require(set(preview['images']) == images and len(preview['images']) == 59, 'Renderer receipt does not match images')
        require(preview.get('runtime') == 'com.apple.CoreSimulator.SimRuntime.iOS-18-6', 'Unexpected simulator runtime')
        require(b'pulses=2 rt=0' in selected.get('tenebris-tap-timing-regression.txt', b''), 'Tap timing receipt absent')
        return selected


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    root = Path(__file__).resolve().parents[2]
    head = verify_source(root)
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'BCD-native-provenance'}
    if os.environ.get('GH_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GH_TOKEN']
    def get(path):
        with urllib.request.urlopen(urllib.request.Request(API + path, headers=headers), timeout=45) as response:
            return json.load(response)
    run = get(f'actions/runs/{RUN}')
    job = get(f'actions/jobs/{JOB}')
    artifact = get(f'actions/artifacts/{ARTIFACT}')
    verify_metadata(run, job, artifact)
    try:
        urllib.request.build_opener(NoRedirect).open(urllib.request.Request(API + f'actions/artifacts/{ARTIFACT}/zip', headers=headers), timeout=45)
        raise ValueError('Expected artifact signed redirect')
    except urllib.error.HTTPError as error:
        require(error.code in (301, 302, 303, 307, 308), 'Artifact download failed')
        location = error.headers['Location']
    require(location.startswith('https://'), 'Non-HTTPS artifact redirect')
    # Never forward the GitHub credential to the signed blob host.
    with urllib.request.urlopen(location, timeout=90) as response:
        data = response.read(32 * 1024**2 + 1)
    require(len(data) <= 32 * 1024**2, 'Artifact exceeds compressed-size limit')
    files = verified_files(data)
    out = root / 'touch-evidence'
    require(not out.exists() and not out.is_symlink(), 'Evidence destination already exists; do not mix runs')
    out.mkdir()
    for name, content in files.items():
        (out / name).write_bytes(content)
    receipt = dict(run=RUN, head=BASE, reusedAtHead=head, job=JOB, artifact=ARTIFACT, sha256=DIGEST,
                   productionUnchanged=True, fixturesUnchanged=True, fullRunSucceeded=False,
                   reusedSteps=sorted(REQUIRED_STEPS), deviceTested=False,
                   scope='Only successful native Swift/UIKit and simulator fixture steps reused. Converter identity, final app build, packaging and physical game testing are not certified.')
    (out / 'reused-native-provenance.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('Verified exact unchanged touch production/fixtures and pinned artifact; reusing successful native steps only. Full build and phone testing not claimed.')


if __name__ == '__main__':
    main()
