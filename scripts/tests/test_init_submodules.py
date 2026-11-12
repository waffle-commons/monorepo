"""Tests for the submodule step of scripts/init.sh (wfl init): stdlib unittest, local repositories as
submodules, no network, no Docker.

Run: python3 -m unittest discover -s scripts/tests   (wfl ai:check runs it too)
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

INIT = Path(__file__).resolve().parent.parent / 'init.sh'
STUB = '#!/bin/sh\nexit 0\n'
# No user or system config, and the file protocol allowed: git refuses local submodule URLs by default.
GIT_ENV = {**os.environ, 'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 't@example.invalid',
           'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 't@example.invalid',
           'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_COUNT': '1',
           'GIT_CONFIG_KEY_0': 'protocol.file.allow', 'GIT_CONFIG_VALUE_0': 'always'}
REMOTES = {'academy': [{'README.md': 'private\n'}],
           'utils': [{'utils.txt': 'one\n'}, {'utils.txt': 'two\n'}],
           'workspace': [{'docker-compose.yml': 'services: {}\n'}]}


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(['git', '-C', str(cwd), *args], check=True, capture_output=True, text=True,
                          env=GIT_ENV).stdout.strip()


class InitSubmodulesTest(unittest.TestCase):
    """A fresh clone as an outsider sees it: `academy` cannot be read, `utils` is pinned behind its
    remote's tip, `workspace` at it (as every pin is right after a release)."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        umbrella = root / 'umbrella'
        umbrella.mkdir()
        git(umbrella, 'init', '-q', '-b', 'main')
        for name, commits in REMOTES.items():
            remote = root / 'remotes' / name
            remote.mkdir(parents=True)
            git(remote, 'init', '-q', '-b', 'main')
            for files in commits:
                for file, text in files.items():
                    (remote / file).write_text(text)
                git(remote, 'add', '-A')
                git(remote, 'commit', '-q', '-m', f'{name}: {sorted(files)}')
            git(umbrella, 'submodule', 'add', '-q', str(remote), name)
        self.utils_pin = git(umbrella / 'utils', 'rev-parse', 'HEAD~1')
        git(umbrella / 'utils', 'checkout', '-q', self.utils_pin)
        git(umbrella, 'config', '-f', '.gitmodules', 'submodule.academy.url', str(root / 'remotes' / 'private'))
        git(umbrella, 'add', 'utils', '.gitmodules')
        git(umbrella, 'commit', '-q', '-m', 'pins')
        self.clone = root / 'clone'
        git(root, 'clone', '-q', str(umbrella), str(self.clone))
        scripts = self.clone / 'scripts'
        scripts.mkdir()
        shutil.copy2(INIT, scripts / 'init.sh')
        for stub in ('doctor.sh', 'install-git-hooks.sh'):
            (scripts / stub).write_text(STUB)
            (scripts / stub).chmod(0o755)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def init(self) -> subprocess.CompletedProcess[str]:
        run = subprocess.run([str(self.clone / 'scripts' / 'init.sh'), '--https', '--skip-docker', '--skip-ai',
                              '--no-link'], cwd=self.clone, capture_output=True, text=True, env=GIT_ENV, timeout=120)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        return run

    def status(self) -> dict[str, str]:
        """Each submodule's `git submodule status` prefix: '-' not initialised, '+' off its pin, ' ' at it."""
        out = subprocess.run(['git', '-C', str(self.clone), 'submodule', 'status'], check=True,
                             capture_output=True, text=True, env=GIT_ENV).stdout
        return {line[1:].split()[1]: line[0] for line in out.splitlines() if line}

    def test_a_fresh_clone_checks_out_every_readable_submodule_at_its_pin(self) -> None:
        # The fresh-install failure of 2026-11-09: the unreadable academy made git abort before any
        # checkout, and workspace, pinned at its remote's tip, looked done with an empty working tree.
        run = self.init()
        self.assertIn('skipped (no access, or the network failed): academy', run.stderr)
        self.assertTrue((self.clone / 'workspace' / 'docker-compose.yml').is_file(), run.stdout + run.stderr)
        self.assertEqual(git(self.clone / 'utils', 'rev-parse', 'HEAD'), self.utils_pin)
        self.assertEqual((self.clone / 'utils' / 'utils.txt').read_text(), 'one\n')
        self.assertEqual(self.status(), {'academy': '-', 'utils': ' ', 'workspace': ' '})
        # A re-run tries the unreadable one again and checks nothing out a second time.
        rerun = self.init().stdout
        self.assertIn('initialising 1 submodule(s): academy', rerun)
        self.assertNotIn('never checked out', rerun)

    def test_a_rerun_checks_out_an_empty_clone_and_leaves_a_checked_out_one_alone(self) -> None:
        # An earlier run stopped by the same abort: both clones exist, neither is checked out.
        subprocess.run(['git', '-C', str(self.clone), 'submodule', 'update', '--init', '--jobs', '4'],
                       capture_output=True, text=True, env=GIT_ENV)
        self.assertEqual(git(self.clone / 'workspace', 'ls-files'), '')
        git(self.clone / 'utils', 'checkout', '-q', self.utils_pin)
        (self.clone / 'utils' / 'utils.txt').write_text('local work\n')
        run = self.init()
        self.assertIn('cloned but never checked out: workspace', run.stdout)
        self.assertTrue((self.clone / 'workspace' / 'docker-compose.yml').is_file(), run.stdout + run.stderr)
        self.assertEqual((self.clone / 'utils' / 'utils.txt').read_text(), 'local work\n')


if __name__ == '__main__':
    unittest.main()
