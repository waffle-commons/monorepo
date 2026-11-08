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
NONE = 'Status: complete\n\n## Checked\n- nothing to report\n\n## Candidates\n\nNone.\n'


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


def candidate(cid: str, severity: str = 'MEDIUM', where: str = 'alpha/src/Foo.php:3', also: str = '') -> str:
    return (f'### {cid} · {severity} · Title of {cid}\n- lens: A05\n- component: alpha\n- where: {where}\n'
            + (f'- also: {also}\n' if also else '') + '- claim: c\n- evidence: SECRET-EVIDENCE\n- fix: SECRET-FIX\n\n')


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
            mock.patch.dict(os.environ),
        ]
        for p in self.patches:
            p.start()
        for name in ('AI_AGENT', 'CLAUDECODE', 'WFL_AUDIT_SIGNER'):
            os.environ.pop(name, None)  # the suite runs inside Claude Code too
        ra._LINES.clear()

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

    def rd(self, run: str = 'release-audit', version_dir: str = 'Beta8') -> Path:
        return self.root / 'project_system' / 'Audits' / version_dir / run

    def init(self, *extra: str, version: str = '0.1.0-beta8') -> dict:
        code, out, err = self.run_cli('init', version, '--no-gateway', *extra)
        self.assertEqual(code, 0, out + err)
        run = extra[extra.index('--run') + 1] if '--run' in extra else 'release-audit'
        return json.loads((self.rd(run, ra.version_dir(version)) / 'manifest.json').read_text())

    def complete(self, m: dict, rd: Path, cands: dict[str, str] | None = None) -> None:
        """Evidence for every repository and a complete candidates file for every unit."""
        for r in m['repos']:
            (rd / 'evidence' / r['name']).mkdir(parents=True, exist_ok=True)
            (rd / 'evidence' / r['name'] / 'SUMMARY.md').write_text('x')
        for _, stem in ra.unit_files(m):
            body = (cands or {}).get(stem)
            (rd / 'candidates' / f'{stem}.md').write_text(
                NONE if body is None else f'Status: complete\n\n## Checked\n- x\n\n## Candidates\n\n{body}')

    def finding(self, **over) -> dict:
        base = {'id': 'S-A05-01', 'title': 'Identifier injection', 'phase': 'security', 'lens': 'A05',
                'component': 'alpha', 'where': 'alpha/src/Foo.php:3', 'severity': 'MEDIUM', 'verdict': 'CONFIRMED',
                'moscow': 'MUST', 'proposal': 'fix', 'summary': 's', 'fix': 'f', 'status': 'open', 'decision': None}
        base.update(over)
        return base

    def write_ledger(self, *findings: dict, rd: Path | None = None, run: str = 'release-audit') -> None:
        ((rd or self.rd()) / 'ledger.json').write_text(json.dumps({'version': '0.1.0-beta8', 'run': run,
                                                                    'findings': list(findings), 'refuted': []}))

    def ledger(self, rd: Path | None = None) -> dict:
        return json.loads(((rd or self.rd()) / 'ledger.json').read_text())

    def sign(self, *args: str, typed: str | None = None, via: str = 'terminal') -> tuple[int, str, str]:
        if via == 'cockpit':
            with mock.patch.dict(os.environ, {'WFL_AUDIT_SIGNER': 'cockpit', 'AI_AGENT': 'claude-code_2-1-318_agent'}):
                return self.run_cli('sign', '0.1.0-beta8', *args)
        stdin = mock.MagicMock()
        stdin.isatty.return_value = True
        with mock.patch.object(ra.sys, 'stdin', stdin), mock.patch('builtins.input', return_value=typed or args[0]):
            return self.run_cli('sign', '0.1.0-beta8', *args)

    def commit_in(self, name: str, path: str, text: str) -> str:
        where = self.root / name
        (where / path).write_text(text)
        sh(where, 'commit', '-q', '-am', 'fix')
        return sh(where, 'rev-parse', 'HEAD')

    def repin(self) -> None:
        subprocess.run(['git', '-C', str(self.root), 'add', 'alpha', 'beta'], check=True, capture_output=True, env=GIT_ENV)
        sh(self.root, 'commit', '-q', '-m', 'pin')

    # --- versions and the init --------------------------------------------------
    def test_version_dir_and_v_prefix(self) -> None:
        self.assertEqual(ra.version_dir('0.1.0-beta8'), 'Beta8')
        self.assertEqual(ra.version_dir('1.0.0-RC1'), 'RC1')
        self.assertEqual(ra.version_dir('1.1.0'), '1.1.0')
        code, _, err = self.run_cli('init', 'v0.1.0-beta8')
        self.assertEqual(code, 2)
        self.assertIn("'v' prefix", err)

    def test_which_releases_wait_and_what_covers_them(self) -> None:
        # The same vectors as the cockpit's requiresAudit (hooks/audit.ts): pre-release.sh asks this script.
        for version, required in (('0.1.0-beta7', False), ('0.1.0-beta8', True), ('0.1.0-beta12', True), ('0.1.0-beta', False),
                                  ('0.1.0-beta8.1', False), ('1.0.0-RC1', True), ('1.0.0', True), ('1.0.1', False),
                                  ('1.1.0', True), ('1.1.0-RC2', True), ('1.1.0-beta1', False), ('2.0.0', True)):
            self.assertEqual(ra.audit_required(version), required, version)
        self.assertEqual(self.run_cli('required', '0.1.0-beta8')[0], 0)
        self.assertEqual(self.run_cli('required', '1.0.1')[0], 1)
        self.assertEqual(self.run_cli('required', 'v1.0.0')[0], 2)  # pre-release.sh holds the release on anything but 1
        self.assertTrue(ra.covers('1.0.0-RC2', '1.0.0'))
        self.assertTrue(ra.covers('0.1.0-beta8', '0.1.0-beta8'))
        self.assertFalse(ra.covers('0.1.0-beta8', '1.0.0-RC1'))
        self.assertFalse(ra.covers('1.0.0-RC1', '1.0.0-RC2'))
        self.init()
        self.write_ledger()
        code, _, err = self.run_cli('check', '0.1.0-beta8', '--gate', '--for', '1.0.0-RC1')
        self.assertEqual(code, 1)
        self.assertIn('does not cover the release 1.0.0-RC1', err)

    def test_init_pins_commits_and_splits_the_work(self) -> None:
        m = self.init()
        names = [r['name'] for r in m['repos']]
        self.assertEqual(names, ['alpha', 'beta'])  # docs-only has no composer.json
        alpha = m['repos'][0]
        self.assertEqual(alpha['sha'], self.alpha_sha)
        self.assertTrue(alpha['pin_matches'])
        self.assertEqual([u['id'] for u in m['security_units']], ['B1', 'B2', 'B3', 'AG'])  # 2 repos: bundled
        self.assertEqual([u['id'] for u in m['modernization_units']], ['core', 'more'])
        self.assertEqual((m['scope'], m['trimmed']), ('trimmed', ['gateway', 'calibration']))  # no set in this checkout
        self.assertTrue((self.rd() / 'MANIFEST.md').is_file())
        code, _, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway')
        self.assertEqual(code, 1)
        self.assertIn('already has a manifest', err)

    def test_init_partial_run_and_lenses(self) -> None:
        m = self.init('--only', 'alpha', '--no-bundle')
        self.assertEqual([r['name'] for r in m['repos']], ['alpha'])
        self.assertEqual(len(m['security_units']), 12)  # no AG in a partial run unless asked
        self.assertNotIn('AG', [u['id'] for u in m['security_units']])
        self.assertEqual(m['scope'], 'partial')
        self.assertEqual(ra.security_units(3, None, False, True)[-1], {'id': 'WA', 'lenses': ['WA'], 'scope': 'auth'})
        code, _, err = self.run_cli('init', '1.0.0-RC1', '--base', '0.1.0-beta8')
        self.assertEqual(code, 1)
        self.assertIn('--only', err)
        m = self.init('--only', 'alpha', '--base', '0.1.0-beta8', version='1.0.0-RC1')
        self.assertEqual((m['scope'], m['base']), ('diff', {'audit': '0.1.0-beta8'}))

    def test_init_refuses_dirty_and_ungrouped(self) -> None:
        (self.root / 'alpha' / 'src' / 'Foo.php').write_text('<?php // changed\n')
        code, _, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway')
        self.assertEqual(code, 1)
        self.assertIn('uncommitted changes in alpha', err)
        with mock.patch.object(ra, 'GROUPS', {'core': ['alpha']}):
            code, _, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway', '--allow-dirty')
        self.assertEqual(code, 1)
        self.assertIn('beta released but in no audit group', err)

    def test_init_wants_the_gateway_and_force_moves_the_old_run_aside(self) -> None:
        code, _, err = self.run_cli('init', '0.1.0-beta8')
        self.assertEqual(code, 1)
        self.assertIn('gateway checkout is missing', err)
        self.init()
        (self.rd() / 'candidates' / 'S-B1.md').write_text(NONE)
        self.write_ledger(self.finding())
        code, out, err = self.run_cli('init', '0.1.0-beta8', '--no-gateway', '--force')
        self.assertEqual(code, 0, err)
        self.assertIn('moved the previous run aside', out)
        aside = [p for p in self.rd().parent.iterdir() if p.name.startswith('release-audit.')]
        self.assertEqual(len(aside), 1)
        self.assertTrue((aside[0] / 'ledger.json').is_file())
        self.assertFalse((self.rd() / 'ledger.json').exists())
        self.assertFalse((self.rd() / 'candidates' / 'S-B1.md').exists())
        self.assertEqual(ra.sibling_runs(self.rd()), [])  # a run set aside never counts as a run of the release

    def test_profiles_overrides_and_a_change_mid_run(self) -> None:
        m = self.init()
        self.assertEqual((m['profile'], m['wave']), ('balanced', 6))
        self.assertEqual(m['agents']['finder'], {'model': 'opus', 'effort': 'medium'})
        self.assertEqual(m['agents']['verifier'], {'model': 'opus', 'effort': 'high'})
        self.assertEqual(ra.profile_label(m), 'balanced')
        code, out, _ = self.run_cli('profile', '0.1.0-beta8', '--profile', 'economy', '--model', 'triager=sonnet', '--wave', '3')
        self.assertEqual(code, 0)
        m = json.loads((self.rd() / 'manifest.json').read_text())
        self.assertEqual((m['agents']['finder']['model'], m['agents']['triager']['model'], m['wave']), ('sonnet', 'sonnet', 3))
        self.assertEqual(ra.profile_label(m), 'custom')
        self.assertEqual(m['profile_history'][0]['profile'], 'balanced')
        self.assertIn('Agents: custom', (self.rd() / 'MANIFEST.md').read_text())
        for bad in (['--profile', 'cheap'], ['--model', 'finder=gpt'], ['--effort', 'scout=low'], ['--wave', '0']):
            code, _, _ = self.run_cli('profile', '0.1.0-beta8', *bad)
            self.assertEqual(code, 2)
        self.assertEqual(ra.agents_of('thorough', 'sonnet', None)['verifier']['model'], 'sonnet')  # a bare value sets every role
        self.assertEqual(ra.profile_label({}), 'inherited')

    def test_latest_is_the_run_created_last(self) -> None:
        self.init('--run', 'pilot', '--only', 'alpha')
        pilot = self.rd('pilot') / 'manifest.json'
        older = json.loads(pilot.read_text())
        older['created'] = '2026-11-01T09:00:00+01:00'
        pilot.write_text(json.dumps(older))
        self.init()
        self.assertEqual(ra.latest_run(), self.rd())
        self.assertEqual(self.run_cli('profile', '0.1.0-beta8', '--run', 'pilot', '--profile', 'economy')[0], 0)
        self.assertEqual(ra.latest_run(), self.rd())  # a profile change rewrites the manifest, not its creation

    # --- candidates, verdicts, status ----------------------------------------------
    def test_parsing_majority_and_stray_headings(self) -> None:
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
        slips = ('Status: complete\n\n## Checked\n### Tool evidence\n\n## Candidates\n\n### S-A05-01 · Critical · lowercase\n'
                 '### S-A05-2 · LOW · one digit\n### S-A05-03 - LOW - dashes\n```\n### inside a fence\n```\n')
        self.assertEqual(ra.parse_candidates(slips), [])
        self.assertEqual(len(ra.stray_headings(slips, ra.CANDIDATE_HEAD, '## Candidates')), 3)
        self.assertEqual(ra.stray_headings('### Notes\n### S-A05-01 · OK · LOW\n', ra.VERDICT_HEAD), ['### S-A05-01 · OK · LOW'])

    def test_status_walks_the_phases(self) -> None:
        m = self.init('--no-agentic')
        self.assertEqual(ra.status_data(self.rd())['phase'], 'evidence')
        self.complete(m, self.rd(), {'S-B2': candidate('S-B2-01')})
        d = ra.status_data(self.rd())
        self.assertEqual((d['phase'], d['candidates']), ('verification', 1))
        (self.rd() / 'verdicts' / 'S-B2.md').write_text('Status: complete\n\n### S-B2-01 · CONFIRMED · MEDIUM\n')
        self.assertEqual(ra.status_data(self.rd())['phase'], 'triage')
        self.write_ledger(self.finding(id='S-B2-01'))
        self.assertEqual(ra.status_data(self.rd())['phase'], 'triage')  # no consolidated.md yet
        (self.rd() / 'consolidated.md').write_text('report')
        d = ra.status_data(self.rd())
        self.assertEqual((d['phase'], d['gate']), ('decisions', None))  # the gate is computed once all else is done
        (self.rd() / 'manifest.json').write_text('{broken')
        code, out, _ = self.run_cli('status', '0.1.0-beta8', '--json')
        self.assertEqual((code, json.loads(out)['phase']), (0, 'unreadable'))  # the cockpit says so, not "not started"

    def test_claims_withhold_the_reasoning_and_keep_every_location(self) -> None:
        self.init()
        (self.rd() / 'candidates' / 'S-B1.md').write_text(
            'Status: complete\n\n## Candidates\n\n' + candidate('S-B1-01', 'CRITICAL', also='alpha/src/Foo.php:4, beta/src/Bar.php:1'))
        code, out, _ = self.run_cli('claims', '0.1.0-beta8', 'S-B1')
        self.assertEqual(code, 0)
        self.assertIn('- claim: c', out)
        self.assertIn(self.alpha_sha, out)
        self.assertIn('- also: alpha/src/Foo.php:4, beta/src/Bar.php:1', out)
        for hidden in ('SECRET-EVIDENCE', 'SECRET-FIX', 'CRITICAL'):
            self.assertNotIn(hidden, out)
        code, out, _ = self.run_cli('claims', '0.1.0-beta8', 'S-B1', '--ids', ' S-B1-01')
        self.assertEqual(code, 0)
        self.assertIn('S-B1-01', out)
        code, _, err = self.run_cli('claims', '0.1.0-beta8', 'S-B1', '--ids', 'S-B1-1')
        self.assertEqual(code, 1)
        self.assertIn('not a candidate of S-B1: S-B1-1', err)

    # --- the ledger and the gate -------------------------------------------------------
    def test_validate_rules(self) -> None:
        m = self.init()
        ok = {'findings': [self.finding(also=['alpha/src/Foo.php:4'])]}
        self.assertEqual(ra.validate(ok, m, gate=False)[0], [])
        bad = {'findings': [
            self.finding(id='X-1', where='alpha/src/Missing.php:1'),
            self.finding(id='X-2', where='alpha/src/Foo.php:99'),
            self.finding(id='X-3', title=''),
            self.finding(id='X-4', status='accepted', decision={'choice': 'accept', 'reason': '', 'by': 'm', 'at': 't'}),
            self.finding(id='X-5', severity='CRITICAL', status='deferred',
                         decision={'choice': 'post-v1', 'reason': 'later', 'residual_risk': 'r', 'by': 'm', 'at': 't'}),
            self.finding(id='X-6', verdict='REFUTED'),
            self.finding(id='X-7', also=['alpha/src/Gone.php:2']),
            self.finding(id='X-8', status='accepted', decision={'choice': 'accept', 'reason': 5, 'by': 'm', 'at': 't'}),
            'not an object',
        ]}
        errors = '\n'.join(ra.validate(bad, m, gate=False)[0])
        for expected in ('Missing.php does not exist', 'line 99 is past the end', '"title" is missing',
                         'needs its reason', 'needs its residual risk', 'CRITICAL cannot move to post-v1',
                         'verdict "REFUTED"', 'X-7: also: alpha/src/Gone.php does not exist', '"reason" must be text',
                         '#9: a finding must be a JSON object'):
            self.assertIn(expected, errors)
        self.assertEqual(ra.validate(['a list'], m, gate=False)[0], ['ledger.json is not a JSON object'])
        gate = '\n'.join(ra.validate({'findings': [
            self.finding(id='G-1'),
            self.finding(id='G-2', decision={'choice': 'fix', 'reason': '', 'by': 'm', 'at': 't'}),
        ]}, m, gate=True)[0])
        self.assertIn('G-1: no decision yet', gate)
        self.assertIn('G-2: decided "fix" but not fixed yet', gate)

    def test_triage_reconciles_the_ledger_with_the_run(self) -> None:
        m = self.init('--no-agentic')
        rd = self.rd()
        self.complete(m, rd, {'S-B1': candidate('S-B1-01', 'CRITICAL') + candidate('S-B1-02')})
        (rd / 'verdicts' / 'S-B1.md').write_text('Status: complete\n\n### S-B1-01 · CONFIRMED · CRITICAL\n\n### S-B1-02 · REFUTED · LOW\n')
        self.assertIn('HIGH or CRITICAL with a single verdict', ' '.join(ra.run_errors(m, ra.collect(rd, m), None)))
        (rd / 'verdicts' / 'S-B1-01.md').write_text('Status: complete\n\n### S-B1-01 · REFUTED · CRITICAL\n')
        self.assertIn('a third verifier breaks the tie', ' '.join(ra.run_errors(m, ra.collect(rd, m), None)))
        (rd / 'verdicts' / 'S-B1-01-tiebreak.md').write_text('Status: complete\n\n### S-B1-01 · CONFIRMED · HIGH\n')
        col = ra.collect(rd, m)
        self.assertEqual(ra.run_errors(m, col, None), [])
        ledger = {'version': '0.1.0-beta8', 'run': 'release-audit', 'findings': [], 'refuted': []}
        errors = ' '.join(ra.triage_check(rd, m, ledger, col)[0])
        for expected in ('S-B1-01: CONFIRMED by verification, but in no ledger finding', 'S-B1-02: REFUTED by verification',
                         'consolidated.md is missing'):
            self.assertIn(expected, errors)
        self.assertIn('ledger.json is for 1.0.0-RC1', ' '.join(ra.triage_check(rd, m, {**ledger, 'version': '1.0.0-RC1'}, col)[0]))
        (rd / 'ledger.json').write_text(json.dumps(ledger))
        (rd / 'consolidated.md').write_text('report')
        code, out, _ = self.run_cli('check', '0.1.0-beta8', '--gate')  # an empty ledger no longer passes the gate
        self.assertEqual(code, 1)
        self.assertIn('S-B1-01: CONFIRMED by verification', out)
        lowered = {**ledger, 'findings': [self.finding(id='S-B1-01', severity='LOW')], 'refuted': [{'id': 'S-B1-02', 'control': 'c'}]}
        errors, warnings = ra.triage_check(rd, m, lowered, col)
        self.assertEqual(errors, [])
        self.assertIn("below its verifiers' CRITICAL", ' '.join(warnings))

    def test_sign_takes_the_pane_or_a_typed_answer_in_a_terminal(self) -> None:
        self.init()
        self.write_ledger(self.finding())
        for env in ({'AI_AGENT': 'claude-code_2-1-318_agent'}, {'CLAUDECODE': '1'}):
            with mock.patch.dict(os.environ, env):
                code, _, err = self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'fix')
            self.assertEqual(code, 1)
            self.assertIn('refuses a command an AI agent runs', err)
        stdin = mock.MagicMock()
        stdin.isatty.return_value = False
        with mock.patch.object(ra.sys, 'stdin', stdin):
            code, _, err = self.run_cli('sign', '0.1.0-beta8', 'S-A05-01', 'fix')
        self.assertEqual(code, 1)
        self.assertIn('run it in your own terminal', err)
        code, _, err = self.sign('S-A05-01', 'fix', typed='S-A05-02')
        self.assertEqual(code, 1)
        self.assertIn('does not match', err)
        code, _, err = self.sign('S-A05-01', 'accept', 'demo code path only')
        self.assertEqual(code, 1)
        self.assertIn('needs its residual risk', err)
        code, _, err = self.sign('S-A05-01', 'accept', 'demo code path only', '--residual', 'the demo route stays exposed in dev')
        self.assertEqual(code, 0, err)
        f = self.ledger()['findings'][0]
        self.assertEqual((f['status'], f['decision']['by'], f['decision']['via']), ('accepted', 'Maintainer Name', 'terminal'))
        self.assertEqual(f['decision']['subject'], ra.subject_of(f))
        code, _, err = self.sign('S-A05-01', 'fix', via='cockpit')
        self.assertEqual(code, 0, err)
        f = self.ledger()['findings'][0]
        self.assertEqual((f['status'], f['decision']['via'], len(f['decision_history'])), ('open', 'cockpit', 1))
        self.assertTrue((self.rd() / 'ledger.md').is_file())
        changed = self.ledger()
        changed['findings'][0]['severity'] = 'CRITICAL'
        m = json.loads((self.rd() / 'manifest.json').read_text())
        self.assertIn('changed after its decision', ' '.join(ra.validate(changed, m, gate=False)[0]))

    def test_fixed_needs_a_later_released_commit_and_a_fix_check(self) -> None:
        self.init()
        self.write_ledger(self.finding())
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{self.alpha_sha}')
        self.assertEqual(code, 1)
        self.assertIn('not decided "fix"', err)
        self.sign('S-A05-01', 'fix', via='cockpit')
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', 'alpha@deadbeef')
        self.assertEqual(code, 1)
        self.assertIn('not a commit in alpha', err)
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{self.alpha_sha[:10]}')
        self.assertEqual(code, 1)
        self.assertIn('does not come after the audited commit', err)
        fix = self.commit_in('alpha', 'src/Foo.php', '<?php\n// one\n// fixed\n// three\n')
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{fix[:10]}')
        self.assertEqual(code, 1)
        self.assertIn('no fix-check yet', err)
        check = self.rd() / 'verdicts' / 'fix-S-A05-01.md'
        for state, commit, expected in (('FAILS', fix[:12], 'FAILS'), ('HOLDS', '0000000', 'verified alpha@0000000')):
            check.write_text(f'Status: complete\n\n### FIX S-A05-01 · {state}\n- fix: alpha@{commit}\n')
            code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{fix[:10]}')
            self.assertEqual(code, 1)
            self.assertIn(expected, err)
        check.write_text(f'Status: complete\n\n### FIX S-A05-01 · HOLDS\n- fix: alpha@{fix[:12]}\n- reason: r\n')
        code, _, err = self.run_cli('fixed', '0.1.0-beta8', 'S-A05-01', f'alpha@{fix[:10]}')
        self.assertEqual(code, 0, err)
        f = self.ledger()['findings'][0]
        self.assertEqual(f['fixed_by']['commit'], fix)
        m = json.loads((self.rd() / 'manifest.json').read_text())
        self.assertIn('is not in what alpha releases', ' '.join(ra.closure_errors(self.rd(), m, f)))
        self.repin()
        self.assertEqual(ra.closure_errors(self.rd(), m, f), [])
        forged = {**f, 'fixed_by': {'repo': 'alpha', 'commit': 'not-a-sha'}}
        self.assertIn('is not a commit in alpha', ' '.join(ra.closure_errors(self.rd(), m, forged)))

    def test_release_gate_reads_every_run_and_the_surface(self) -> None:
        pilot_m = self.init('--run', 'pilot', '--only', 'alpha')
        pilot = self.rd('pilot')
        self.complete(pilot_m, pilot, {'S-B1': candidate('S-B1-01')})
        (pilot / 'verdicts' / 'S-B1.md').write_text('Status: complete\n\n### S-B1-01 · CONFIRMED · MEDIUM\n')
        self.write_ledger(self.finding(id='S-B1-01'), rd=pilot, run='pilot')
        (pilot / 'consolidated.md').write_text('report')
        with mock.patch.dict(os.environ, {'WFL_AUDIT_SIGNER': 'cockpit'}):
            self.assertEqual(self.run_cli('sign', '0.1.0-beta8', 'S-B1-01', 'fix', '--run', 'pilot')[0], 0)
        m = self.init('--no-calibration')
        self.complete(m, self.rd())
        self.write_ledger()
        (self.rd() / 'consolidated.md').write_text('report')
        errors, warnings = ra.gate_errors('0.1.0-beta8')
        text = '\n'.join(errors)
        for expected in ('run pilot: S-B1-01: decided "fix" but not fixed yet', 'the EcoShield gateway is not covered',
                         'the release run has no calibration'):
            self.assertIn(expected, text)
        self.assertNotIn('not covered by a complete run of this release', text)  # alpha and beta are
        self.assertNotIn('agentic layer', text)
        code, out, _ = self.run_cli('check', '0.1.0-beta8', '--gate')
        self.assertEqual(code, 1)
        self.assertIn('run pilot: S-B1-01', out)
        rc = self.init('--only', 'alpha', '--base', '0.1.0-beta8', version='1.0.0-RC1')
        rc_dir = self.rd(version_dir='RC1')
        self.complete(rc, rc_dir)
        (rc_dir / 'ledger.json').write_text(json.dumps({'version': '1.0.0-RC1', 'run': 'release-audit', 'findings': [], 'refuted': []}))
        (rc_dir / 'consolidated.md').write_text('report')
        rc_errors = '\n'.join(ra.gate_errors('1.0.0-RC1')[0])
        self.assertIn('base audit 0.1.0-beta8: the EcoShield gateway is not covered', rc_errors)  # the RC re-checks beta8

    def test_calibration_replays_a_known_defect_and_scores_it(self) -> None:
        fix = self.commit_in('alpha', 'src/Foo.php', '<?php\n// one\n// two quoted\n// three\n')
        self.repin()
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts' / 'audit-calibration.json').write_text(json.dumps({'defects': [
            {'id': 'FIX-T-1', 'repo': 'alpha', 'fix': fix[:10], 'lens': 'A05', 'files': ['src/Foo.php']}]}))
        m = self.init()
        self.assertEqual([u['id'] for u in m['calibration_units']], ['C-1'])
        self.assertNotIn('calibration', m['trimmed'])
        self.complete(m, self.rd())
        self.assertEqual(ra.status_data(self.rd())['phase'], 'calibration')
        code, out, err = self.run_cli('calibrate', '0.1.0-beta8')
        self.assertEqual(code, 0, out + err)
        snapshot = (self.rd() / 'calibration' / 'C-1' / 'alpha' / 'src' / 'Foo.php').read_text()
        self.assertIn('// two\n', snapshot)  # the pre-fix tree, not the fix
        expected = json.loads((self.rd() / 'calibration' / 'expected.json').read_text())
        self.assertEqual(expected['units']['C-1']['defects']['FIX-T-1'], {'src/Foo.php': [[3, 3]]})
        col = ra.collect(self.rd(), m)
        self.assertEqual(ra.calibration_result(self.rd(), m, col)['found'], 0)  # C-1.md says "None."
        (self.rd() / 'candidates' / 'C-1.md').write_text(
            'Status: complete\n\n## Candidates\n\n' + candidate('C-1-01', where='calibration/C-1/alpha/src/Foo.php:3'))
        cal = ra.calibration_result(self.rd(), m, ra.collect(self.rd(), m))
        self.assertEqual((cal['found'], cal['defects'], cal['rows'][0]['found']), (1, 1, True))
        self.assertNotIn('C-1-01', ra.collect(self.rd(), m)['candidates'])  # calibration candidates never reach the ledger

    def test_mago_lines_are_cited_from_one(self) -> None:
        data = {'issues': [{'code': 'too-many-methods', 'annotations': [
            {'span': {'file_id': {'name': 'src/Foo.php'}, 'start': {'line': 0}}, 'message': 'm'}]}]}
        self.assertEqual(ra.mago_rows(data), [('too-many-methods', 'src/Foo.php:1', 'm')])


if __name__ == '__main__':
    unittest.main()
