"""Tests for scripts/claude/session-context.sh (the SessionStart hook): stdlib unittest, fake git and
docker on a minimal PATH, no Docker.

Run: python3 -m unittest discover -s scripts/tests   (wfl ai:check runs it too)
"""
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / 'claude' / 'session-context.sh'
BASH = shutil.which('bash')
JQ = shutil.which('jq')

# Each fake prints on stdout what the real command prints, failures included: git prints HEAD in a
# repository without a commit, and docker inspect prints an empty line when it gets no answer.
FAKE_GIT = r'''#!/bin/sh
printf '%s\n' "$FAKE_GIT_OUT"
exit "$FAKE_GIT_RC"
'''
FAKE_DOCKER = r'''#!/bin/sh
case "$1" in
  inspect) printf '%s\n' "$FAKE_INSPECT_OUT"; exit "$FAKE_INSPECT_RC" ;;
  version) exit "$FAKE_VERSION_RC" ;;
esac
exit 1
'''
NOT_REACHABLE = 'Docker is not reachable (start Docker Desktop, then wfl up; PHP gates cannot run until then).'


@unittest.skipUnless(BASH, 'bash not found')
class SessionContextTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.bin = Path(self.tmp.name)
        (self.bin / 'bash').symlink_to(BASH)
        for name, body in (('git', FAKE_GIT), ('docker', FAKE_DOCKER)):
            (self.bin / name).write_text(body)
            (self.bin / name).chmod(0o755)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_hook(self, *, branch: str = 'main', git_rc: int = 0, inspect: str = 'running',
                 inspect_rc: int = 0, version_rc: int = 0) -> str:
        """Run the hook as Claude Code does; jq is on the PATH only once context() put it there."""
        env = {'PATH': str(self.bin), 'CLAUDE_PROJECT_DIR': self.tmp.name,
               'FAKE_GIT_OUT': branch, 'FAKE_GIT_RC': str(git_rc), 'FAKE_INSPECT_OUT': inspect,
               'FAKE_INSPECT_RC': str(inspect_rc), 'FAKE_VERSION_RC': str(version_rc)}
        run = subprocess.run([str(HOOK)], capture_output=True, text=True, env=env, timeout=10)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.count('\n'), 1, f'not one line: {run.stdout!r}')
        return run.stdout

    def context(self, **fakes: str | int) -> str:
        """The additionalContext of the JSON payload, which must parse."""
        if JQ is None:
            self.skipTest('jq not found')
        if not (self.bin / 'jq').exists():
            (self.bin / 'jq').symlink_to(JQ)
        payload = json.loads(self.run_hook(**fakes))
        self.assertEqual(payload['hookSpecificOutput']['hookEventName'], 'SessionStart')
        return payload['hookSpecificOutput']['additionalContext']

    def test_docker_down_still_gives_valid_json(self) -> None:
        # The start that broke the hook: the daemon is down, inspect prints an empty line and fails.
        context = self.context(inspect='', inspect_rc=1, version_rc=1)
        self.assertTrue(context.endswith('; ' + NOT_REACHABLE), context)

    def test_missing_container(self) -> None:
        self.assertIn('; waffle-dev is absent (wfl up starts it;', self.context(inspect='', inspect_rc=1))

    def test_running_and_stopped_container(self) -> None:
        self.assertTrue(self.context().endswith('; waffle-dev is running.'))
        self.assertIn('; waffle-dev is exited (wfl up starts it;', self.context(inspect='exited'))

    def test_failing_git_reports_a_question_mark(self) -> None:
        self.assertIn('umbrella on ?; release phase none', self.context(branch='HEAD', git_rc=128))

    def test_branch_sets_the_phase_and_quotes_are_encoded(self) -> None:
        self.assertIn('release phase beta8 freeze:', self.context(branch='pre-release/0.1.0-beta8'))
        self.assertIn('umbrella on fix/"quoted";', self.context(branch='fix/"quoted"'))

    def test_without_jq_the_line_is_plain_text(self) -> None:
        # A SessionStart hook may print plain text: Claude Code adds it to the context as it is.
        out = self.run_hook(inspect='', inspect_rc=1, version_rc=1)
        self.assertTrue(out.startswith('waffle-commons session: umbrella on main; '), out)
        self.assertTrue(out.endswith('; ' + NOT_REACHABLE + '\n'), out)


if __name__ == '__main__':
    unittest.main()
