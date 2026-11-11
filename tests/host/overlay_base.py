"""Fetch an exact historical overlay input without changing checkout policy.

Publication forks may omit old commits. Only an explicit missing-ref response
permits trying the original public source, never an access or transport failure.
"""
import hashlib
import os
import re
import subprocess

FETCH_TIMEOUT = 120
LOCAL_TIMEOUT = 60


def _git(repo, *args, input=None, discard_output=False, timeout=LOCAL_TIMEOUT):
    env = dict(os.environ, LC_ALL='C', GIT_TERMINAL_PROMPT='0',
               GIT_NO_LAZY_FETCH='1', GIT_NO_REPLACE_OBJECTS='1')
    return subprocess.run(['git', '-C', str(repo), *args], input=input,
                          stdout=subprocess.DEVNULL if discard_output else subprocess.PIPE,
                          stderr=subprocess.PIPE, env=env, timeout=timeout)


def _require_success(result):
    if result.returncode:
        detail = result.stderr.decode(errors='replace').strip()
        raise RuntimeError(f"Historical overlay Git command failed: {detail}")


def _object(repo, oid, kind):
    result = _git(repo, 'cat-file', '--batch', input=(oid + '\n').encode())
    _require_success(result)
    if result.stdout == (oid + ' missing\n').encode():
        return None
    header, separator, body = result.stdout.partition(b'\n')
    fields = header.split()
    if not separator or len(fields) != 3 or fields[:2] != [oid.encode(), kind.encode()]:
        raise RuntimeError(f"Historical overlay {oid} is not the expected {kind} object")
    try:
        size = int(fields[2])
    except ValueError as exc:
        raise RuntimeError(f"Invalid object size for historical overlay {oid}") from exc
    if size < 0 or len(body) != size + 1 or body[-1:] != b'\n':
        raise RuntimeError(f"Incomplete historical overlay object {oid}")
    raw = body[:-1]
    digest = hashlib.sha1(kind.encode() + b' ' + str(size).encode() + b'\0' + raw).hexdigest()
    if digest != oid:
        raise RuntimeError(f"Corrupt historical overlay object {oid}")
    return raw


def _verify(repo, commit, tree):
    raw = _object(repo, commit, 'commit')
    if raw is None:
        return False
    if raw.split(b'\n', 1)[0] != ('tree ' + tree).encode():
        raise RuntimeError(f"Historical overlay {commit} does not have expected tree {tree}")
    if _object(repo, tree, 'tree') is None:
        raise RuntimeError(f"Historical overlay {commit} is missing tree {tree}")
    # Catch missing/corrupt descendants before a caller can fall back to its
    # patched working tree after a failed archive. Submodule pins stay untouched.
    _require_success(_git(repo, 'archive', '--format=tar', commit, discard_output=True))
    return True


def _missing_ref(result, commit):
    # Accept only explicit diagnostics naming this exact object. Any additional
    # authentication, permission, transport or other error makes this a hard fail.
    patterns = (
        rf"fatal: (?:remote error: |git )?upload-pack: not our ref {commit}",
        rf"fatal: couldn't find remote ref {commit}",
    )
    lines = result.stderr.decode(errors='replace').strip().splitlines()
    return bool(lines) and all(any(re.fullmatch(p, line) for p in patterns) for line in lines)


def ensure_overlay_base(repo, commit, tree, upstream):
    """Return commit only after verifying its identity and readable source tree."""
    if not all(re.fullmatch(r'[0-9a-f]{40}', oid) for oid in (commit, tree)):
        raise ValueError('Historical overlay inputs must be full commit and tree IDs')
    if _verify(repo, commit, tree):
        return commit
    for source in ('origin', upstream):
        result = _git(repo, '-c', 'fetch.fsckObjects=true', 'fetch', '-q',
                      '--depth=1', '--no-tags', '--no-recurse-submodules',
                      '--no-write-fetch-head', '--no-auto-maintenance', source, commit,
                      timeout=FETCH_TIMEOUT)
        if result.returncode:
            if source == 'origin' and _missing_ref(result, commit):
                continue
            _require_success(result)
        if not _verify(repo, commit, tree):
            raise RuntimeError(f"Fetch from {source} did not provide historical overlay {commit}")
        return commit
    raise RuntimeError(f"Historical overlay {commit} is unavailable")
