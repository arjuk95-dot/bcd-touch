#!/usr/bin/env python3
"""Restore only exact, previously ARM64-verified build654 link inputs. Never build.

The pinned successful artifact supplies 20 static libraries and six generated
FEX headers. Donor runtime staging/signing remains a separate guarded operation.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tarfile
import zipfile

PIN = Path(__file__).with_name('native-link-inputs-654.json')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_name(name):
    raw = name.rstrip('/')
    p = PurePosixPath(raw)
    require(raw and not p.is_absolute() and not any(c in raw for c in ('\\', ':', '\0'))
            and all(c not in ('', '.', '..') for c in raw.split('/')), 'Unsafe artifact path: ' + name)
    return str(p)


def verify_metadata(p, artifact, run, job):
    require(run.get('id') == p['run'] and run.get('head_sha') == p['head']
            and run.get('status') == 'completed' and run.get('conclusion') == 'success', 'Wrong/unsuccessful native source run')
    require(job.get('id') == p['job'] and job.get('run_id') == p['run']
            and job.get('status') == 'completed' and job.get('conclusion') == 'success', 'Wrong/unsuccessful native source job')
    for name in ('Require donor-compatible shader converter identity',
                 'Retain exact native link inputs for subsequent app-only updates', 'Archive (unsigned)'):
        matches = [s for s in job.get('steps', []) if s.get('name') == name]
        require(len(matches) == 1 and matches[0].get('conclusion') == 'success'
                and matches[0].get('status') == 'completed', 'Missing successful source stage: ' + name)
    wr = artifact.get('workflow_run', {})
    require(artifact.get('id') == p['artifact'] and artifact.get('name') == 'BCD-v653-native-link-inputs'
            and wr.get('id') == p['run'] and wr.get('head_sha') == p['head']
            and not artifact.get('expired', True) and artifact.get('digest') == 'sha256:' + p['sha256'],
            'Changed, expired or unrelated native archive artifact')


def read_artifact(path, p):
    data = Path(path).read_bytes()
    require(len(data) <= 64 * 1024**2 and sha(data) == p['sha256'], 'Native archive ZIP hash/size mismatch')
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        infos = z.infolist()
        require(len(infos) <= 40 and sum(i.file_size for i in infos) <= 256 * 1024**2, 'Native ZIP exceeds bounds')
        files, seen = {}, set()
        for i in infos:
            name = safe_name(i.filename)
            require(name.casefold() not in seen, 'Duplicate native ZIP entry')
            seen.add(name.casefold())
            require(stat.S_IFMT(i.external_attr >> 16) in (0, stat.S_IFREG, stat.S_IFDIR)
                    and not i.flag_bits & 1, 'Native ZIP links/special/encrypted entries forbidden')
            if not i.is_dir():
                files[name] = z.read(i)
    expected = {'native-link-inputs.json', 'toolchain.txt', 'source-pins.txt', 'FEX-ios-link-inputs.tar.gz'}
    expected.update('link-inputs/' + Path(n).name for n in p['archives'] if n.startswith('app/'))
    require(set(files) == expected, 'Unexpected native ZIP contents')
    manifest = json.loads(files['native-link-inputs.json'])
    require(manifest.get('architecture_verified') is True and manifest.get('archives') == p['archives'],
            'Native manifest is unverified or differs from reviewed hashes')
    require(files['toolchain.txt'].decode() == p['toolchain'], 'Native toolchain differs')
    require(sha(files['source-pins.txt']) == p['source_pins_sha256'], 'Native source pins differ')
    selected = {n: files['link-inputs/' + Path(n).name] for n in p['archives'] if n.startswith('app/')}
    with tarfile.open(fileobj=io.BytesIO(files['FEX-ios-link-inputs.tar.gz']), mode='r:gz') as t:
        members = t.getmembers()
        require(len(members) <= 1000 and sum(m.size for m in members) <= 64 * 1024**2, 'FEX tar exceeds bounds')
        seen = set()
        for m in members:
            name = safe_name(m.name)
            require(name == 'FEX/build-ios' or name.startswith('FEX/build-ios/'), 'FEX entry outside build inputs')
            require(name.casefold() not in seen and (m.isfile() or m.isdir()), 'FEX duplicate/link/special entry')
            seen.add(name.casefold())
            # Do not materialize cached build tools, object files or CMake scripts.
            if name in p['archives'] or name in p['headers']:
                require(m.isfile(), 'Native input is not a regular file')
                selected[name] = t.extractfile(m).read()
    wanted = p['archives'] | p['headers']
    require(set(selected) == set(wanted), 'Missing retained native input')
    for name, spec in wanted.items():
        body = selected[name]
        require(len(body) == spec['bytes'] and sha(body) == spec['sha256'], 'Native input hash mismatch: ' + name)
        if name in p['archives']:
            require(body.startswith(b'!<arch>\n') and len(body) > 8, 'Invalid/empty retained static archive: ' + name)
    return selected, manifest


def verify_sources(root, p):
    for path, expected in p['submodules'].items():
        actual = subprocess.check_output(['git', 'rev-parse', 'HEAD:' + path], cwd=root, text=True).strip()
        require(actual == expected, 'Native source gitlink changed: ' + path)
    # The app can change. Library recipes, ABI headers and submodules cannot.
    paths = ['FEX', 'wine', 'dxmt', 'madeira-dock', 'build', 'madeira-d3d12']
    subprocess.run(['git', 'diff', '--exit-code', p['head'], 'HEAD', '--', *paths], cwd=root, check=True)


def stage_files(root, files):
    for name, body in files.items():
        target = root / name
        require(not any(x.is_symlink() for x in (target, *target.parents)), 'Symlink native destination')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)


def validate_mac(root, p):
    toolchain = subprocess.check_output(['xcodebuild', '-version'], text=True)
    require(toolchain == p['toolchain'], 'Use the exact retained-library Xcode toolchain')
    for name in p['archives']:
        # -verify_arch consumes all later arguments as architectures: input MUST precede it.
        subprocess.run(['xcrun', 'lipo', str(root / name), '-verify_arch', 'arm64'], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('artifact', 'artifact-metadata', 'run-metadata', 'job-metadata', 'repo', 'receipt'):
        parser.add_argument('--' + name, required=True)
    a = parser.parse_args(); p = json.loads(PIN.read_text()); root = Path(a.repo).resolve()
    verify_metadata(p, json.loads(Path(a.artifact_metadata).read_text()),
                    json.loads(Path(a.run_metadata).read_text()), json.loads(Path(a.job_metadata).read_text()))
    verify_sources(root, p)
    files, manifest = read_artifact(a.artifact, p)
    receipt = dict(artifact=p['artifact'], artifactSHA256=p['sha256'], sourceRun=p['run'],
                   sourceHead=p['head'], converterIdentity=p['converter_identity'], archives=manifest['archives'],
                   generatedHeaders=p['headers'], architecture_verified=False,
                   scope='Exact retained link inputs only; no engine build and no new app/device validation.')
    output = Path(a.receipt); output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    stage_files(root, files)
    validate_mac(root, p)
    receipt['architecture_verified'] = True
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print('Restored and hash/ARM64-verified 20 native libraries and six generated FEX headers; no engine compilation.')


if __name__ == '__main__':
    main()
