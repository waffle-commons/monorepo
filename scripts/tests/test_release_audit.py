"""Tests for scripts/release-audit.py (wfl audit:*): stdlib unittest, throwaway git repositories, no Docker.

Run: python3 -m unittest discover -s scripts/tests   (wfl ai:check runs it too)
"""
from __future__ import annotations

import importlib.util
import io
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('release_audit', HERE.parent / 'release-audit.py')
ra = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ra)

GIT_ENV = {**os.environ, 'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 't@example.invalid',
           'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 't@example.invalid'}


def sh(cwd: Path, *args: str) -> str:
    return subprocess.run(['git', '-C', str(cwd), *args], check=True, capture_output=True, text=True, env=GIT_ENV).stdout.strip()


def repo(path: Path, files: dict[str, str]) -> str:
    path.mkdir(parents=True)
    sh(path, 'init', '-q', '-b', 'main')
    for name, text in files.items():
        (path / name).parent.mkdir(parents=True, exist_ok=True)
        (path / name).write_text(text)
    sh(path, 'add', '-A')
    sh(path, 'commit', '-q', '-m', 'initial')
    return sh(path, 'rev-parse', 'HEAD')


class AuditTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.alpha_sha = repo(root / 'alpha', {'composer.json': '{}', 'src/Foo.php': '<?php\n// one\n// two\n// three\n'})
        repo(root / 'beta', {'composer.json': '{}', 'src/Bar.php': '<?php\n'})
        (root / 'docs-only').mkdir()
        (root / '.github' / 'workflows').mkdir(parents=True)
        (root / '.github' / 'workflows' / 'release-wave.yml').write_text(
            "env:\n  RELEASE_INCLUDE: 'alpha,beta,docs-only'\n")
        sh(root, 'init', '-q', '-b', 'main')
        sh(root, 'config', 'user.name', 'Maintainer Name')
        sh(root, 'add', '.github')
        subprocess.run(['git', '-C', str(root), 'add', 'alpha', 'beta'], check=True, capture_output=True, env=GIT_ENV)
        sh(root, 'commit', '-q', '-m', 'umbrella')
        self.root = root
        self.patches = [
            mock.patch.object(ra, 'ROOT', root),
            mock.patch.object(ra, 'GROUPS', {'core': ['alpha'], 'more': ['beta']}),
            mock.patch.object(ra, 'docker_out', lambda *a, **k: None),
        ]
        for p in self.patches:
            p.start()
        os.environ.pop('AI_AGENT', None)

    def tearDown(self) -> None:
        for p in self.patches:
            p.stop()
        self.tmp.cleanup()

    # --- helpers ---------------------------------------------------------------
    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                code = ra.main(list(argv))
            except SystemExit as e:
                code = int(e.code or 0)
        return code, out.getvalue(), err.getvalue()

    def rd(self) -> Path:
        return self.root / 'project_system' / 'Audits' / 'Beta8' / 'release-audit'

    def init(self, *extra: str) -> dict:
        code, out, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway', *extra)
        self.assertEqual(code, 0, out + err)
        return json.loads((self.rd() / 'manifest.json').read_text())

    def finding(self, **over) -> dict:
        base = {'id': 'S-A05-01', 'title': 'Identifier injection', 'phase': 'security', 'lens': 'A05',
                'component': 'alpha', 'where': 'alpha/src/Foo.php:3', 'severity': 'MEDIUM', 'verdict': 'CONFIRMED',
                'moscow': 'MUST', 'proposal': 'fix', 'summary': 's', 'fix': 'f', 'status': 'open', 'decision': None}
        base.update(over)
        return base

    def write_ledger(self, *findings: dict) -> None:
        (self.rd() / 'ledger.json').write_text(json.dumps({'version': '0.1.0-beta8', 'run': 'release-audit',
                                                           'findings': list(findings)}))

    # --- tests -----------------------------------------------------------------
    def test_version_dir_and_v_prefix(self) -> None:
        self.assertEqual(ra.version_dir('0.1.0-beta8'), 'Beta8')
        self.assertEqual(ra.version_dir('1.0.0-RC1'), 'RC1')
        self.assertEqual(ra.version_dir('1.1.0'), '1.1.0')
        code, _, err = self.run_cli('init', 'v0.1.0-beta8')
        self.assertEqual(code, 2)
        self.assertIn("'v' prefix", err)

    def test_init_pins_commits_and_splits_the_work(self) -> None:
        m = self.init()
        names = [r['name'] for r in m['repos']]
        self.assertEqual(names, ['alpha', 'beta'])  # docs-only has no composer.json
        alpha = m['repos'][0]
        self.assertEqual(alpha['sha'], self.alpha_sha)
        self.assertTrue(alpha['pin_matches'])
        self.assertEqual([u['id'] for u in m['security_units']], ['B1', 'B2', 'B3', 'AG'])  # 2 repos: bundled
        self.assertEqual([u['id'] for u in m['modernization_units']], ['core', 'more'])
        self.assertTrue((self.rd() / 'MANIFEST.md').is_file())
        code, _, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway')
        self.assertEqual(code, 1)
        self.assertIn('already has a manifest', err)

    def test_init_partial_run_and_lenses(self) -> None:
        m = self.init('--only', 'alpha', '--no-bundle')
        self.assertEqual([r['name'] for r in m['repos']], ['alpha'])
        self.assertEqual(len(m['security_units']), 12)  # no AG in a partial run unless asked
        self.assertNotIn('AG', [u['id'] for u in m['security_units']])

    def test_init_refuses_dirty_and_ungrouped(self) -> None:
        (self.root / 'alpha' / 'src' / 'Foo.php').write_text('<?php // changed\n')
        code, _, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway')
        self.assertEqual(code, 1)
        self.assertIn('uncommitted changes in alpha', err)
        with mock.patch.object(ra, 'GROUPS', {'core': ['alpha']}):
            code, _, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway', '--allow-dirty')
        self.assertEqual(code, 1)
        self.assertIn('beta released but in no audit group', err)

    def test_parsing_and_majority(self) -> None:
        text = ('Status: complete\n\n## Candidates\n\n'
                '### S-B1-01 · HIGH · Missing check\n- lens: A01\n- component: alpha\n- where: alpha/src/Foo.php:2\n'
                '- claim: no voter runs\n- evidence: secret reasoning\n\n```php\n- claim: not a field\n```\n')
        c = ra.parse_candidates(text)
        self.assertEqual(c[0]['id'], 'S-B1-01')
        self.assertEqual(c[0]['claim'], 'no voter runs')
        v = ra.parse_verdicts('### S-B1-01 · REFUTED · LOW\n- reason: guarded\n')
        self.assertEqual(v[0]['verdict'], 'REFUTED')
        self.assertIsNone(ra.final_verdict(['CONFIRMED', 'REFUTED']))
        self.assertEqual(ra.final_verdict(['CONFIRMED', 'REFUTED', 'CONFIRMED']), 'CONFIRMED')
        self.assertEqual(ra.final_verdict(['CONFIRMED', 'PLAUSIBLE']), 'PLAUSIBLE')
        self.assertEqual(ra.final_verdict(['REFUTED']), 'REFUTED')

    def test_status_walks_the_phases(self) -> None:
        self.init('--no-agentic')
        self.assertEqual(ra.status_data(self.rd())['phase'], 'evidence')
        for name in ('alpha', 'beta'):
            (self.rd() / 'evidence' / name).mkdir(parents=True)
            (self.rd() / 'evidence' / name / 'SUMMARY.md').write_text('x')
        d = ra.status_data(self.rd())
        self.assertEqual(d['phase'], 'finders')
        cand = ('Status: complete\n\n### {id} · MEDIUM · T\n- lens: A05\n- component: alpha\n'
                '- where: alpha/src/Foo.php:3\n- claim: c\n')
        for stem in ('S-B1', 'S-B2', 'S-B3', 'M-core', 'M-more'):
            body = cand.format(id='S-B2-01') if stem == 'S-B2' else 'Status: complete\n\nNo candidates.\n'
            (self.rd() / 'candidates' / f'{stem}.md').write_text(body)
        d = ra.status_data(self.rd())
        self.assertEqual((d['phase'], d['candidates']), ('verification', 1))
        (self.rd() / 'verdicts' / 'S-B2.md').write_text('Status: complete\n\n### S-B2-01 · CONFIRMED · MEDIUM\n')
        self.assertEqual(ra.status_data(self.rd())['phase'], 'triage')
        self.write_ledger(self.finding(id='S-B2-01'))
        d = ra.status_data(self.rd())
        self.assertEqual((d['phase'], d['gate']), ('decisions', 'fail'))

    def test_claims_withhold_the_reasoning(self) -> None:
        self.init()
        (self.rd() / 'candidates' / 'S-B1.md').write_text(
            'Status: complete\n\n### S-B1-01 · CRITICAL · Missing check\n- lens: A01\n- component: alpha\n'
            '- where: alpha/src/Foo.php:2\n- claim: no voter runs\n- evidence: SECRET-EVIDENCE\n- fix: SECRET-FIX\n')
        code, out, _ = self.run_cli('claims', '0.1.0-beta8', 'S-B1')
        self.assertEqual(code, 0)
        self.assertIn('no voter runs', out)
        self.assertIn(self.alpha_sha, out)
        for hidden in ('SECRET-EVIDENCE', 'SECRET-FIX', 'CRITICAL'):
            self.assertNotIn(hidden, out)

    def test_validate_rules(self) -> None:
        m = self.init()
        ok = {'findings': [self.finding()]}
        self.assertEqual(ra.validate(ok, m, gate=False)[0], [])
        bad = {'findings': [
            self.finding(id='X-1', where='alpha/src/Missing.php:1'),
            self.finding(id='X-2', where='alpha/src/Foo.php:99'),
            self.finding(id='X-3', title=''),
            self.finding(id='X-4', status='accepted', decision={'choice': 'accept', 'reason': '', 'by': 'm', 'at': 't'}),
            self.finding(id='X-5', severity='CRITICAL', status='deferred',
                         decision={'choice': 'post-v1', 'reason': 'later', 'by': 'm', 'at': 't'}),
            self.finding(id='X-6', verdict='REFUTED'),
        ]}
        errors = '\n'.join(ra.validate(bad, m, gate=False)[0])
        for expected in ('Missing.php does not exist', 'line 99 is past the end', '"title" is missing',
                         'needs its reason', 'CRITICAL cannot move to post-v1', 'verdict "REFUTED"'):
            self.assertIn(expected, errors)
        gate = '\n'.join(ra.validate({'findings': [
            self.finding(id='G-1'),
            self.finding(id='G-2', decision={'choice': 'fix', 'reason': '', 'by': 'm', 'at': 't'}),
        ]}, m, gate=True)[0])
        self.assertIn('G-1: no decision yet', gate)
        self.assertIn('G-2: decided "fix" but not fixed yet', gate)

    def test_sign_refuses_an_agent_and_records_the_maintainer(self) -> None:
        self.init()
        self.write_ledger(self.finding())
        with mock.patch.dict(os.environ, {'AI_AGENT': 'claude-code_2-1-318_agent'}):
            code, _, err = self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'fix')
        self.assertEqual(code, 1)
        self.assertIn('refuses a command an AI agent runs', err)
        code, _, err = self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'accept')
        self.assertEqual(code, 1)
        self.assertIn('needs its reason', err)
        code, out, err = self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'accept', 'demo code path only')
        self.assertEqual(code, 0, err)
        f = json.loads((self.rd() / 'ledger.json').read_text())['findings'][0]
        self.assertEqual((f['status'], f['decision']['by']), ('accepted', 'Maintainer Name'))
        self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'fix')
        f = json.loads((self.rd() / 'ledger.json').read_text())['findings'][0]
        self.assertEqual((f['status'], len(f['decision_history'])), ('open', 1))
        self.assertTrue((self.rd() / 'ledger.md').is_file())

    def test_fixed_needs_a_fix_decision_and_a_real_commit(self) -> None:
        self.init()
        self.write_ledger(self.finding())
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{self.alpha_sha}')
        self.assertEqual(code, 1)
        self.assertIn('not decided "fix"', err)
        self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'fix')
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', 'alpha@deadbeef')
        self.assertEqual(code, 1)
        self.assertIn('not a commit in alpha', err)
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{self.alpha_sha[:10]}')
        self.assertEqual(code, 0, err)
        ledger = json.loads((self.rd() / 'ledger.json').read_text())
        self.assertEqual(ledger['findings'][0]['fixed_by']['commit'], self.alpha_sha)
        m = json.loads((self.rd() / 'manifest.json').read_text())
        self.assertEqual(ra.validate(ledger, m, gate=True)[0], [])


if __name__ == '__main__':
    unittest.main()
