#!/usr/bin/env python3
"""Offline regression tests for exact historical overlay source resolution."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

import dxmt_base
import fexpatch_eval
import overlay_base


class OverlayBaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'
        self.repo = self.root / 'checkout'
        self.empty = self.root / 'empty'
        self.env = dict(os.environ, GIT_AUTHOR_NAME='Overlay Test',
                        GIT_AUTHOR_EMAIL='overlay@example.invalid',
                        GIT_COMMITTER_NAME='Overlay Test',
                        GIT_COMMITTER_EMAIL='overlay@example.invalid')
        for path in (self.source, self.repo, self.empty):
            self.git(path, 'init', '-q', str(path), outside=True)
        (self.source / 'input').write_text('historical source\n')
        self.git(self.source, 'add', 'input')
        self.git(self.source, 'commit', '-qm', 'historical source')
        self.commit = self.git(self.source, 'rev-parse', 'HEAD').strip().decode()
        self.tree = self.git(self.source, 'rev-parse', 'HEAD^{tree}').strip().decode()
        (self.repo / 'sentinel').write_text('do not modify\n')
        self.git(self.repo, 'add', 'sentinel')
        self.git(self.repo, 'commit', '-qm', 'checkout remains here')
        self.git(self.repo, 'remote', 'add', 'origin', str(self.empty))
        (self.repo / '.git/FETCH_HEAD').write_text('preserve FETCH_HEAD\n')
        self.real_git = overlay_base._git

    def git(self, path, *args, outside=False):
        command = ['git', *args] if outside else ['git', '-C', str(path), *args]
        return subprocess.check_output(command, env=self.env, stderr=subprocess.PIPE)

    def snapshot(self):
        return tuple(self.git(self.repo, *args) for args in (
            ('rev-parse', 'HEAD'), ('config', '--local', '--list'),
            ('for-each-ref',), ('status', '--porcelain'),
        )) + ((self.repo / '.git/FETCH_HEAD').read_bytes(),)

    def resolve(self, **kwargs):
        before = self.snapshot()
        try:
            return overlay_base.ensure_overlay_base(
                self.repo, kwargs.get('commit', self.commit),
                kwargs.get('tree', self.tree), str(self.source))
        finally:
            self.assertEqual(before, self.snapshot(), 'HEAD, refs, config or checkout changed')

    def seed(self):
        self.git(self.repo, 'fetch', '-q', '--no-write-fetch-head', str(self.source), self.commit)

    def put_object(self, oid, kind, raw):
        path = self.repo / '.git/objects' / oid[:2] / oid[2:]
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(zlib.compress(kind.encode() + b' ' + str(len(raw)).encode() + b'\0' + raw))

    @staticmethod
    def fetches(spy):
        return [call for call in spy.call_args_list if 'fetch' in call.args]

    def test_cache_hit_does_not_fetch(self):
        self.seed()
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            self.assertEqual(self.resolve(), self.commit)
        self.assertEqual(self.fetches(spy), [])

    def test_origin_success_does_not_try_upstream(self):
        self.git(self.repo, 'remote', 'set-url', 'origin', str(self.source))
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            self.assertEqual(self.resolve(), self.commit)
        calls = self.fetches(spy)
        self.assertEqual([call.args[-2:] for call in calls], [('origin', self.commit)])
        self.assertEqual(calls[0].kwargs['timeout'], overlay_base.FETCH_TIMEOUT)

    def test_exact_missing_ref_falls_back_to_original_source(self):
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            self.assertEqual(self.resolve(), self.commit)
        calls = self.fetches(spy)
        self.assertEqual([call.args[-2:] for call in calls],
                         [('origin', self.commit), (str(self.source), self.commit)])
        self.assertTrue(all(call.kwargs['timeout'] == overlay_base.FETCH_TIMEOUT for call in calls))

    def test_missing_ref_diagnostics_are_narrow(self):
        for message in (
            f'fatal: remote error: upload-pack: not our ref {self.commit}\n',
            f'fatal: git upload-pack: not our ref {self.commit}\n',
            f"fatal: couldn't find remote ref {self.commit}\n",
        ):
            self.assertTrue(overlay_base._missing_ref(
                subprocess.CompletedProcess([], 128, b'', message.encode()), self.commit))
        for message in (
            f'fatal: remote error: upload-pack: not our ref {"0" * 40}\n',
            f'fatal: remote error: upload-pack: not our ref {self.commit}\nfatal: Authentication failed\n',
            '', 'fatal: not our ref HEAD\n',
        ):
            self.assertFalse(overlay_base._missing_ref(
                subprocess.CompletedProcess([], 128, b'', message.encode()), self.commit))

    def test_auth_access_and_transport_errors_never_fall_back(self):
        for error in (b'fatal: Authentication failed', b'fatal: repository access denied',
                      b'fatal: repository not found', b'fatal: Could not resolve host',
                      b'fatal: TLS certificate verification failed', b'error: arbitrary failure'):
            with self.subTest(error=error):
                def run(repo, *args, **kwargs):
                    if 'fetch' in args:
                        return subprocess.CompletedProcess(args, 128, b'', error)
                    return self.real_git(repo, *args, **kwargs)
                with mock.patch.object(overlay_base, '_git', side_effect=run) as spy:
                    with self.assertRaises(RuntimeError):
                        self.resolve()
                self.assertEqual([call.args[-2] for call in self.fetches(spy)], ['origin'])

    def test_fetch_timeout_is_hard_failure(self):
        def run(repo, *args, **kwargs):
            if 'fetch' in args:
                raise subprocess.TimeoutExpired(args, kwargs['timeout'])
            return self.real_git(repo, *args, **kwargs)
        with mock.patch.object(overlay_base, '_git', side_effect=run) as spy:
            with self.assertRaises(subprocess.TimeoutExpired):
                self.resolve()
        self.assertEqual([call.args[-2] for call in self.fetches(spy)], ['origin'])

    def test_successful_fetch_must_supply_expected_object(self):
        def run(repo, *args, **kwargs):
            if 'fetch' in args:
                return subprocess.CompletedProcess(args, 0, b'', b'')
            return self.real_git(repo, *args, **kwargs)
        with mock.patch.object(overlay_base, '_git', side_effect=run) as spy:
            with self.assertRaisesRegex(RuntimeError, 'did not provide'):
                self.resolve()
        self.assertEqual([call.args[-2] for call in self.fetches(spy)], ['origin'])

    def test_fetched_commit_must_match_expected_tree(self):
        self.git(self.repo, 'remote', 'set-url', 'origin', str(self.source))
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            with self.assertRaisesRegex(RuntimeError, 'expected tree'):
                self.resolve(tree='0' * 40)
        self.assertEqual([call.args[-2] for call in self.fetches(spy)], ['origin'])

    def test_upstream_success_without_object_is_rejected(self):
        def run(repo, *args, **kwargs):
            if 'fetch' in args and args[-2] == str(self.source):
                return subprocess.CompletedProcess(args, 0, b'', b'')
            return self.real_git(repo, *args, **kwargs)
        with mock.patch.object(overlay_base, '_git', side_effect=run) as spy:
            with self.assertRaisesRegex(RuntimeError, 'did not provide'):
                self.resolve()
        self.assertEqual(len(self.fetches(spy)), 2)

    def test_short_or_symbolic_inputs_are_rejected_before_git(self):
        with mock.patch.object(overlay_base, '_git') as spy:
            for commit, tree in (('HEAD', self.tree), (self.commit[:7], self.tree),
                                 (self.commit, 'HEAD^{tree}')):
                with self.assertRaises(ValueError):
                    self.resolve(commit=commit, tree=tree)
        spy.assert_not_called()

    def test_upstream_failure_is_not_suppressed(self):
        def run(repo, *args, **kwargs):
            if 'fetch' in args and args[-2] == str(self.source):
                return subprocess.CompletedProcess(args, 128, b'', b'fatal: Authentication failed')
            return self.real_git(repo, *args, **kwargs)
        with mock.patch.object(overlay_base, '_git', side_effect=run) as spy:
            with self.assertRaisesRegex(RuntimeError, 'Authentication failed'):
                self.resolve()
        self.assertEqual(len(self.fetches(spy)), 2)

    def test_wrong_tree_is_rejected_without_fetch(self):
        self.seed()
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            with self.assertRaisesRegex(RuntimeError, 'expected tree'):
                self.resolve(tree='0' * 40)
        self.assertEqual(self.fetches(spy), [])

    def test_corrupt_commit_is_rejected_without_fetch(self):
        raw = self.git(self.source, 'cat-file', 'commit', self.commit)
        self.put_object(self.commit, 'commit', raw.replace(b'historical source', b'changed source!!!'))
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            with self.assertRaises(RuntimeError):
                self.resolve()
        self.assertEqual(self.fetches(spy), [])

    def test_missing_tree_is_rejected_without_fetch(self):
        self.put_object(self.commit, 'commit', self.git(self.source, 'cat-file', 'commit', self.commit))
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            with self.assertRaisesRegex(RuntimeError, 'missing tree'):
                self.resolve()
        self.assertEqual(self.fetches(spy), [])

    def test_corrupt_tree_is_rejected_without_fetch(self):
        self.put_object(self.commit, 'commit', self.git(self.source, 'cat-file', 'commit', self.commit))
        self.put_object(self.tree, 'tree', self.git(self.source, 'cat-file', 'tree', self.tree).replace(b'input', b'other'))
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            with self.assertRaises(RuntimeError):
                self.resolve()
        self.assertEqual(self.fetches(spy), [])

    def test_missing_descendant_is_rejected_without_fetch(self):
        self.put_object(self.commit, 'commit', self.git(self.source, 'cat-file', 'commit', self.commit))
        self.put_object(self.tree, 'tree', self.git(self.source, 'cat-file', 'tree', self.tree))
        with mock.patch.object(overlay_base, '_git', wraps=self.real_git) as spy:
            with self.assertRaises(RuntimeError):
                self.resolve()
        self.assertEqual(self.fetches(spy), [])

    def test_both_integrations_keep_exact_source_contract(self):
        self.assertEqual((dxmt_base.OVERLAY_BASE, dxmt_base.OVERLAY_TREE, dxmt_base.OVERLAY_UPSTREAM),
                         ('db546ee466ad50ec6463edb5fa183de11db43761',
                          'a24bd7aad0c5087cabfc183353b58ee6c2f6f79c',
                          'https://github.com/willfaust/dxmt.git'))
        self.assertEqual((fexpatch_eval.OVERLAY_BASE, fexpatch_eval.OVERLAY_TREE, fexpatch_eval.OVERLAY_UPSTREAM),
                         ('3bec2ac498bf78156ab47c0c194b0e8cb2849756',
                          'e348431369f07995227d15e1ecf90fbf3c4d90c6',
                          'https://github.com/willfaust/FEX.git'))
        dxmt = self.root / 'dxmt'
        marker = dxmt / 'src/winemetal/unix/winemetal_unix.c'
        marker.parent.mkdir(parents=True)
        with mock.patch.object(dxmt_base, 'ensure_overlay_base', return_value=dxmt_base.OVERLAY_BASE) as resolver:
            self.assertEqual(dxmt_base.rev(dxmt), 'HEAD')
            resolver.assert_not_called()
            marker.write_text(dxmt_base.PIN_MARKER)
            self.assertEqual(dxmt_base.rev(dxmt), dxmt_base.OVERLAY_BASE)
            resolver.assert_called_once_with(dxmt, dxmt_base.OVERLAY_BASE,
                                             dxmt_base.OVERLAY_TREE, dxmt_base.OVERLAY_UPSTREAM)
        fex = self.root / 'FEX'
        marker = fex / 'Source/Windows/ARM64EC/Module.cpp'
        marker.parent.mkdir(parents=True)
        marker.write_text('no overlays')
        with mock.patch.object(fexpatch_eval, 'ensure_overlay_base', side_effect=RuntimeError('stop before archive')) as resolver:
            self.assertEqual(fexpatch_eval.overlay_base(self.root, self.root / 'out'), fex)
            resolver.assert_not_called()
            marker.write_text(fexpatch_eval.PIN_MARKER)
            with self.assertRaisesRegex(RuntimeError, 'stop before archive'):
                fexpatch_eval.overlay_base(self.root, self.root / 'out')
            resolver.assert_called_once_with(fex, fexpatch_eval.OVERLAY_BASE,
                                             fexpatch_eval.OVERLAY_TREE, fexpatch_eval.OVERLAY_UPSTREAM)


if __name__ == '__main__':
    if sys.argv[1:] == ['--verify-checkouts']:
        root = Path(__file__).resolve().parents[2]
        for name, module in (('dxmt', dxmt_base), ('FEX', fexpatch_eval)):
            overlay_base.ensure_overlay_base(root / name, module.OVERLAY_BASE,
                                             module.OVERLAY_TREE, module.OVERLAY_UPSTREAM)
            print(f'PASS: {name} historical overlay {module.OVERLAY_BASE} verified', flush=True)
    else:
        unittest.main(verbosity=2)
