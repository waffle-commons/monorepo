#!/usr/bin/env python3
"""wfl audit:* — the deterministic side of the release audit (the `release-audit` skill drives the agents).

Every subcommand takes the release the audit is for (0.1.0-beta8, 1.0.0-RC1 …) and works in
project_system/Audits/<Beta8|RC1|version>/<run>/ (gitignored, local only). --run defaults to release-audit.

  init       the run folder, its manifest (each repository's commit, the toolchain) and the split of the
             work across agents; --force moves an existing run aside first
  evidence   run the automated tools once per repository and keep their output (report-only, never a gate)
  calibrate  the calibration snapshots: known beta6 defects on their pre-fix trees, and where each one sits
  status     what is done and what comes next; --json for the cockpit; --latest picks the newest run
  claims     a candidates file's claims without the finder's reasoning, for a blind verifier
  check      validate ledger.json against the run's candidates and verdicts; --gate is the release gate:
             every run of the release complete and reconciled, every finding decided, every fix verified
             and released, the surface covered; --render writes ledger.md
  sign       record the maintainer's decision on one finding (fix | accept | post-v1), from the cockpit's
             /audit pane or typed in the maintainer's own terminal (guard rails, not a sandbox: the skill)
  fixed      record the commit that fixed a finding, once its fix-check HOLDS
  profile    change who runs a run's agents from now on
  required   whether a release waits for its audit (exit 0) or is exempt (exit 1)

Exit: 0 ok · 1 a problem was found · 2 usage error.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTAINER = os.environ.get('WFL_CONTAINER', 'waffle-dev')
GATEWAY_NAME = 'ecoshield-gateway'
GATEWAY_PATH = 'contributions/ecoshield-gateway'
UMBRELLA = 'umbrella'
RELEASE_RUN = 'release-audit'
TOOL_TIMEOUT = 900

# Modernization: one finder per group, each about 200 KB of PHP (measured 2026-11-05). A released
# repository missing here stops `init`, so a new component gets a group before its first audit.
GROUPS: dict[str, list[str]] = {
    'foundation': ['contracts', 'utils'],
    'kernel': ['waffle', 'pipeline', 'container', 'runtime', 'cache'],
    'http': ['http', 'http-client', 'routing'],
    'security': ['security', 'auth'],
    'data': ['data'],
    'console-ops': ['console', 'config', 'log', 'error-handler', 'event-dispatcher'],
    'api-async': ['serializer', 'openapi', 'queue', 'telemetry', 'telemetry-otel', 'async'],
    'app': ['skeleton', 'testing'],
}

# Security: the OWASP Top 10:2025 categories plus the Waffle lenses (beta6 swept the first twelve).
LENSES: dict[str, str] = {
    'A01': 'Broken Access Control (SSRF included)',
    'A02': 'Security Misconfiguration',
    'A03': 'Software Supply Chain Failures',
    'A04': 'Cryptographic Failures',
    'A05': 'Injection',
    'A06': 'Insecure Design',
    'A07': 'Authentication Failures',
    'A08': 'Software or Data Integrity Failures',
    'A09': 'Security Logging and Alerting Failures',
    'A10': 'Mishandling of Exceptional Conditions',
    'W1': 'Worker-state leaks across requests',
    'W2': 'Timing-safe comparisons',
    'WA': 'WebAuthn passkeys (scope: auth)',
    'AG': 'Agentic layer (OWASP Top 10 for Agentic Applications 2026)',
}
CORE_LENSES = [k for k in LENSES if k not in ('AG', 'WA')]
# The modernization lenses, named for the claims a verifier reads.
MODERN_LENSES: dict[str, str] = {'M1': 'Modern features', 'M2': 'Complexity (measured by Mago)', 'M3': 'Patterns and anti-patterns'}
# A scope of three repositories or fewer bundles the twelve core lenses into three finders (a pilot stays cheap).
BUNDLES: dict[str, list[str]] = {
    'B1': ['A01', 'A02', 'A03', 'A04'],
    'B2': ['A05', 'A06', 'A07', 'A08'],
    'B3': ['A09', 'A10', 'W1', 'W2'],
}
BUNDLE_MAX_REPOS = 3

# Who runs each role, chosen per run and recorded in the manifest (AGENTS.md §8): the skill passes these
# to every agent it dispatches. Finders carry the cost; verifiers are the precision gate and stay strong.
ROLES = ['finder', 'verifier', 'triager']
MODELS = ['opus', 'sonnet', 'haiku', 'fable']
EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max']
PROFILES: dict[str, dict[str, dict[str, str]]] = {
    'thorough': {'finder': {'model': 'opus', 'effort': 'high'}, 'verifier': {'model': 'opus', 'effort': 'high'},
                 'triager': {'model': 'opus', 'effort': 'high'}},
    'balanced': {'finder': {'model': 'opus', 'effort': 'medium'}, 'verifier': {'model': 'opus', 'effort': 'high'},
                 'triager': {'model': 'opus', 'effort': 'high'}},
    'economy': {'finder': {'model': 'sonnet', 'effort': 'medium'}, 'verifier': {'model': 'opus', 'effort': 'medium'},
                'triager': {'model': 'opus', 'effort': 'medium'}},
}
DEFAULT_PROFILE = 'balanced'
DEFAULT_WAVE = 6

SEVERITIES = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']
VERDICTS = ['CONFIRMED', 'PLAUSIBLE', 'REFUTED']
MOSCOW = ['MUST', 'SHOULD', 'COULD']
CHOICES = ['fix', 'accept', 'post-v1']
STATUSES = ['open', 'fixed', 'accepted', 'deferred']
PHASES = ['security', 'modernization']
REQUIRED = ['id', 'title', 'phase', 'lens', 'component', 'where', 'severity', 'verdict', 'moscow',
            'proposal', 'summary', 'fix', 'status']
# What a decision is about: a change to one of these after the sign-off voids it (`subject`).
SUBJECT_KEYS = ('id', 'title', 'severity', 'where', 'summary', 'fix')
METRIC_RULES = ('cyclomatic-complexity,excessive-nesting,excessive-parameter-list,halstead,'
                'kan-defect,too-many-methods,too-many-properties')
# The known defects the calibration replays, kept out of the audit agents' reading list.
CALIBRATION_SET = 'scripts/audit-calibration.json'
CALIBRATION_MARGIN = 15  # lines around a fix's hunk that still count as finding the defect
MAX_BASE_DEPTH = 3

CANDIDATE_HEAD = re.compile(r'^### ([SMC]-[A-Za-z0-9-]+?-\d{2,3}) · (' + '|'.join(SEVERITIES) + r') · (.+?)\s*$', re.M)
VERDICT_HEAD = re.compile(r'^### ([SM]-[A-Za-z0-9-]+?-\d{2,3}) · (' + '|'.join(VERDICTS) + r') · ('
                          + '|'.join(SEVERITIES) + r')\s*$', re.M)
FIELD = re.compile(r'^- ([a-z-]+): (.*)$', re.M)
COMPLETE = re.compile(r'^Status:\s*complete\s*$', re.M)
WHERE = re.compile(r'^(.+?):(\d+)(?:-(\d+))?$')
LOCATION = re.compile(r'([\w./@+-]+\.[A-Za-z0-9]+):(\d+)')
HUNK = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+\d+(?:,\d+)? @@', re.M)
ID_HEADING = re.compile(r'^### [SMC]-\S+')
RUN_NAME = re.compile(r'[a-z0-9][a-z0-9-]*')


class Problem(Exception):
    """A failure the user can act on: printed without a traceback, exit 1."""


# --- small helpers ------------------------------------------------------------------
def say(msg: str = '') -> None:
    print(msg)


def die(msg: str, code: int = 1) -> None:
    print(f'✗ {msg}', file=sys.stderr)
    sys.exit(code)


def now() -> str:
    return dt.datetime.now().astimezone().isoformat(timespec='seconds')


def git(cwd: Path, *args: str, check: bool = True) -> str:
    run = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True)
    if check and run.returncode != 0:
        raise Problem(f'git {" ".join(args)} failed in {cwd}: {run.stderr.strip() or run.returncode}')
    return run.stdout.strip()


def is_ancestor(where: Path, older: str, newer: str) -> bool:
    return subprocess.run(['git', '-C', str(where), 'merge-base', '--is-ancestor', older, newer],
                          capture_output=True).returncode == 0


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f'.{path.name}.tmp')
    tmp.write_text(text, encoding='utf-8')
    os.replace(tmp, path)


def write_json(path: Path, data: dict) -> None:
    write_atomic(path, json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def load_json(path: Path, what: str):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except ValueError as e:
        raise Problem(f'{what} ({rel(path)}) is not valid JSON ({e})') from e


def check_version(version: str) -> str:
    if version.startswith('v'):
        die(f"a version never carries a 'v' prefix (got '{version}')", 2)
    if not re.fullmatch(r'\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?', version):
        die(f"'{version}' is not a release version such as 0.1.0-beta8 or 1.0.0-RC1", 2)
    return version


def audit_required(version: str) -> bool:
    """beta8 and later betas, every X.Y.0 and its RCs; a patch release, and every other pre-release, is exempt."""
    beta = re.fullmatch(r'0\.1\.0-beta(\d+)', version)
    if beta:
        return int(beta.group(1)) >= 8
    return re.fullmatch(r'\d+\.\d+\.0(-RC\d+)?', version) is not None


def covers(audit_version: str, release: str) -> bool:
    """An audit covers its own release, and a final X.Y.Z is covered by one of its RCs (X.Y.Z-RCn)."""
    if audit_version == release:
        return True
    return re.fullmatch(r'\d+\.\d+\.\d+', release) is not None and \
        re.fullmatch(re.escape(release) + r'-RC\d+', audit_version) is not None


def version_dir(version: str) -> str:
    m = re.fullmatch(r'0\.1\.0-beta(\d+)', version)
    if m:
        return f'Beta{m.group(1)}'
    m = re.fullmatch(r'1\.0\.0-RC(\d+)', version)
    if m:
        return f'RC{m.group(1)}'
    return version


def run_dir(version: str, run: str) -> Path:
    if not RUN_NAME.fullmatch(run):
        die(f"run name '{run}' must be lowercase letters, digits and hyphens", 2)
    return ROOT / 'project_system' / 'Audits' / version_dir(version) / run


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def load_manifest(rd: Path) -> dict:
    path = rd / 'manifest.json'
    if not path.is_file():
        raise Problem(f'no manifest at {rel(path)}: start the run with `wfl audit:init <version>`')
    m = load_json(path, 'the manifest')
    if not isinstance(m, dict) or not isinstance(m.get('repos'), list) or not isinstance(m.get('umbrella'), dict):
        raise Problem(f'{rel(path)} is not a run manifest')
    return m


def created_of(path: Path) -> tuple[float, float]:
    try:
        return dt.datetime.fromisoformat(json.loads(path.read_text(encoding='utf-8'))['created']).timestamp(), 0.0
    except (ValueError, KeyError, TypeError, OSError):
        return 0.0, path.stat().st_mtime


def latest_run() -> Path:
    """The run created last (its manifest's `created`), so a profile change never moves it."""
    manifests = [p for p in (ROOT / 'project_system' / 'Audits').glob('*/*/manifest.json') if RUN_NAME.fullmatch(p.parent.name)]
    if not manifests:
        raise Problem('no release audit run yet: `wfl audit:init <version>` starts one')
    return max(manifests, key=created_of).parent


def resolve_run(args: argparse.Namespace) -> Path:
    if getattr(args, 'latest', False):
        return latest_run()
    if not args.version:
        die('give the release version (or --latest)', 2)
    return run_dir(check_version(args.version), args.run)


def sibling_runs(rd: Path) -> list[Path]:
    """The release's other runs (a pilot, a rehearsal); a run set aside by `init --force` is not one."""
    return [p for p in sorted(rd.parent.iterdir()) if p.is_dir() and p != rd and RUN_NAME.fullmatch(p.name)
            and (p / 'manifest.json').is_file()]


# --- repositories ---------------------------------------------------------------------
def release_repos() -> list[str]:
    """The released repositories that hold PHP: RELEASE_INCLUDE minus those without a composer.json."""
    wave = ROOT / '.github' / 'workflows' / 'release-wave.yml'
    m = re.search(r"^\s*RELEASE_INCLUDE:\s*'([^']*)'\s*$", wave.read_text(encoding='utf-8'), re.M)
    if not m:
        raise Problem(f'could not read RELEASE_INCLUDE from {rel(wave)}')
    names = [n.strip() for n in m.group(1).split(',') if n.strip()]
    return [n for n in names if (ROOT / n / 'composer.json').is_file()]


def repo_record(name: str, path: str, group: str | None) -> dict:
    where = ROOT / path if path else ROOT
    sha = git(where, 'rev-parse', 'HEAD')
    dirty = bool(git(where, 'status', '--porcelain', '--untracked-files=no'))
    pin = None
    if path and path != GATEWAY_PATH:
        tree = git(ROOT, 'ls-tree', 'HEAD', path, check=False).split()
        pin = tree[2] if len(tree) >= 3 and tree[1] == 'commit' else None
    return {
        'name': name, 'path': path, 'sha': sha, 'branch': git(where, 'rev-parse', '--abbrev-ref', 'HEAD'),
        'dirty': dirty, 'group': group, 'pin': pin,
        'pin_matches': None if pin is None else pin == sha,
    }


def where_of(repo: dict) -> Path:
    return ROOT / repo['path'] if repo['path'] else ROOT


def release_point(repo: dict) -> str | None:
    """What a repository releases now: the umbrella's gitlink for a component, the HEAD of the umbrella or gateway."""
    if repo['path'] and repo['path'] != GATEWAY_PATH:
        tree = git(ROOT, 'ls-tree', 'HEAD', repo['path'], check=False).split()
        return tree[2] if len(tree) >= 3 and tree[1] == 'commit' else None
    return git(where_of(repo), 'rev-parse', 'HEAD', check=False) or None


def docker_out(args: list[str], workdir: str | None = None, timeout: int = 60) -> str | None:
    cmd = ['docker', 'exec'] + (['-w', workdir] if workdir else []) + [CONTAINER] + args
    try:
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return run.stdout.strip() if run.returncode == 0 else None


def toolchain() -> dict:
    franken = 'unknown'
    dockerfile = ROOT / 'skeleton' / 'docker' / 'Dockerfile'
    if dockerfile.is_file():
        m = re.search(r"^ARG FRANKEN_VERSION='?([0-9.]+)", dockerfile.read_text(encoding='utf-8'), re.M)
        franken = m.group(1) if m else 'unknown'
    igor = (ROOT / '.igor-version').read_text(encoding='utf-8').strip() if (ROOT / '.igor-version').is_file() else 'unknown'
    mago = docker_out(['vendor/bin/mago', '--version'], '/waffle-commons/contracts') or 'unknown'
    return {
        'php': docker_out(['php', '-r', 'echo PHP_VERSION;']) or 'unknown',
        'frankenphp': franken,
        'mago': mago.replace('mago ', '').strip(),
        'igor': igor,
        'container': CONTAINER,
    }


# --- who runs the agents ------------------------------------------------------------------
def pairs_of(text: str | None, allowed: list[str], what: str) -> dict[str, str]:
    """`finder=sonnet,verifier=opus` → {role: value}; `sonnet` alone sets every role."""
    out: dict[str, str] = {}
    for part in [p.strip() for p in (text or '').split(',') if p.strip()]:
        role, _, value = part.rpartition('=')
        roles = [role] if role else ROLES
        if role and role not in ROLES:
            die(f"unknown role '{role}' (roles: {', '.join(ROLES)})", 2)
        if value not in allowed:
            die(f"unknown {what} '{value}' ({', '.join(allowed)})", 2)
        for r in roles:
            out[r] = value
    return out


def agents_of(profile: str, models: str | None, efforts: str | None) -> dict[str, dict[str, str]]:
    if profile not in PROFILES:
        die(f"unknown profile '{profile}' ({', '.join(PROFILES)})", 2)
    agents = {role: dict(PROFILES[profile][role]) for role in ROLES}
    for role, model in pairs_of(models, MODELS, 'model').items():
        agents[role]['model'] = model
    for role, effort in pairs_of(efforts, EFFORTS, 'effort').items():
        agents[role]['effort'] = effort
    return agents


def profile_label(m: dict) -> str:
    """The profile's name, `custom` when a role departs from it, `inherited` for a run made before profiles."""
    agents = m.get('agents')
    if not agents:
        return 'inherited'
    name = m.get('profile', DEFAULT_PROFILE)
    return name if agents == PROFILES.get(name) else 'custom'


def agents_line(m: dict) -> str:
    agents = m.get('agents')
    if not agents:
        return 'agents inherit the session model and effort (run made before profiles)'
    roles = ' · '.join(f"{r} {agents[r]['model']}/{agents[r]['effort']}" for r in ROLES if r in agents)
    return f"{profile_label(m)}: {roles} · wave {m.get('wave', DEFAULT_WAVE)}"


def cmd_profile(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    m = load_manifest(rd)
    base = a.profile or m.get('profile') or DEFAULT_PROFILE
    # A new profile starts from its table; otherwise the run's current choice is the starting point.
    agents = agents_of(base, None, None) if a.profile or not m.get('agents') else {r: dict(v) for r, v in m['agents'].items()}
    for role, model in pairs_of(a.model, MODELS, 'model').items():
        agents[role]['model'] = model
    for role, effort in pairs_of(a.effort, EFFORTS, 'effort').items():
        agents[role]['effort'] = effort
    if a.wave is not None and a.wave < 1:
        die('--wave is the number of agents running at once: 1 or more', 2)
    m.setdefault('profile_history', []).append({'at': now(), 'profile': m.get('profile'), 'agents': m.get('agents'),
                                                'wave': m.get('wave')})
    m['profile'], m['agents'], m['wave'] = base, agents, a.wave or m.get('wave', DEFAULT_WAVE)
    write_json(rd / 'manifest.json', m)
    write_atomic(rd / 'MANIFEST.md', render_manifest(m))
    say(f'✓ {rel(rd)}: {agents_line(m)} (agents dispatched from now on)')
    return 0


# --- init -------------------------------------------------------------------------------
def security_units(repo_count: int, bundle: bool | None, agentic: bool, webauthn: bool) -> list[dict]:
    use_bundles = repo_count <= BUNDLE_MAX_REPOS if bundle is None else bundle
    if use_bundles:
        units = [{'id': b, 'lenses': lenses} for b, lenses in BUNDLES.items()]
    else:
        units = [{'id': lens, 'lenses': [lens]} for lens in CORE_LENSES]
    if webauthn:
        units.append({'id': 'WA', 'lenses': ['WA'], 'scope': 'auth'})
    if agentic:
        units.append({'id': 'AG', 'lenses': ['AG'], 'scope': UMBRELLA})
    return units


def calibration_set() -> list[dict]:
    """The known defects, from scripts/audit-calibration.json: [{id, repo, fix, lens, files}]."""
    path = ROOT / CALIBRATION_SET
    if not path.is_file():
        return []
    data = load_json(path, 'the calibration set')
    defects = data.get('defects') if isinstance(data, dict) else None
    if not isinstance(defects, list):
        raise Problem(f'{CALIBRATION_SET} has no "defects" list')
    for d in defects:
        if not (isinstance(d, dict) and all(isinstance(d.get(k), str) and d.get(k) for k in ('id', 'repo', 'fix', 'lens'))
                and d['lens'] in LENSES and isinstance(d.get('files'), list) and d['files']):
            raise Problem(f'{CALIBRATION_SET}: every defect needs id, repo, fix, a lens of {", ".join(CORE_LENSES)} and its files')
    return defects


def calibration_units() -> list[dict]:
    """One unit per pre-fix tree: the defects one fix commit removed are replayed together."""
    units: list[dict] = []
    by_tree: dict[tuple[str, str], dict] = {}
    for d in calibration_set():
        unit = by_tree.get((d['repo'], d['fix']))
        if unit is None:
            unit = {'id': f'C-{len(units) + 1}', 'repo': d['repo'], 'fix': d['fix'], 'lenses': [], 'defects': []}
            by_tree[(d['repo'], d['fix'])] = unit
            units.append(unit)
        if d['lens'] not in unit['lenses']:
            unit['lenses'].append(d['lens'])
        unit['defects'].append({'id': d['id'], 'files': list(d['files'])})
    return units


def set_aside(rd: Path) -> Path:
    stamp = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
    target = rd.with_name(f'{rd.name}.{stamp}')
    rd.rename(target)
    return target


def cmd_init(a: argparse.Namespace) -> int:
    version = check_version(a.version)
    rd = run_dir(version, a.run)
    suffix = f' --run {a.run}' if a.run != RELEASE_RUN else ''
    if (rd / 'manifest.json').exists() and not a.force:
        raise Problem(f'{rel(rd)} already has a manifest: resume it (`wfl audit:status {version}{suffix}`) or start '
                      'over with --force, which moves the whole run aside first')
    if a.base and not a.only:
        raise Problem('a diff-scoped run (--base) audits what changed: name those repositories with --only a,b')
    if a.base:
        check_version(a.base)
    released = release_repos()
    grouped = [n for names in GROUPS.values() for n in names]
    missing = [n for n in released if n not in grouped]
    if missing:
        raise Problem(f'{", ".join(missing)} released but in no audit group: add them to GROUPS in scripts/release-audit.py')
    only = [n.strip() for n in (a.only or '').split(',') if n.strip()]
    unknown = [n for n in only if n not in released and n != GATEWAY_NAME]
    if unknown:
        raise Problem(f'not a released repository: {", ".join(unknown)}')
    selected = [n for n in released if not only or n in only]
    gateway = GATEWAY_NAME in only or (not only and not a.no_gateway)
    if gateway and not (ROOT / GATEWAY_PATH / 'composer.json').is_file():
        raise Problem(f'the EcoShield gateway checkout is missing ({GATEWAY_PATH}): clone it, or pass --no-gateway '
                      '(the run is then labelled trimmed, and a release gate does not count it as the full surface)')
    agentic = a.with_agentic or (not only and not a.no_agentic)
    wants_calibration = a.with_calibration or (not only and not a.no_calibration)
    cal_units = calibration_units() if wants_calibration else []
    trimmed = [] if only else [what for what, left_out in (('gateway', a.no_gateway), ('agentic', a.no_agentic),
                                                           ('calibration', a.no_calibration or (wants_calibration and not cal_units)))
                               if left_out]
    scope = 'diff' if a.base else 'partial' if only else 'trimmed' if trimmed else 'full'

    group_of = {n: g for g, names in GROUPS.items() for n in names}
    repos = [repo_record(n, n, group_of[n]) for n in selected]
    if gateway:
        repos.append(repo_record(GATEWAY_NAME, GATEWAY_PATH, 'gateway'))
    umbrella = repo_record(UMBRELLA, '', None)
    dirty = [r['name'] for r in repos + [umbrella] if r['dirty']]
    if dirty and not a.allow_dirty:
        raise Problem(f'uncommitted changes in {", ".join(dirty)}: the manifest pins commits, so commit first '
                      '(or pass --allow-dirty and say so in the report)')

    agents = agents_of(a.profile, a.model, a.effort)
    if a.wave is not None and a.wave < 1:
        die('--wave is the number of agents running at once: 1 or more', 2)
    units = security_units(len(repos), a.bundle, agentic, 'auth' in selected)
    modern = [{'id': g, 'repos': [n for n in names if n in selected]} for g, names in GROUPS.items()]
    modern = [u for u in modern if u['repos']]
    if gateway:
        modern.append({'id': 'gateway', 'repos': [GATEWAY_NAME]})
    aside = set_aside(rd) if (rd / 'manifest.json').exists() else None
    manifest = {
        'schema': 2,
        'version': version,
        'run': a.run,
        'created': now(),
        'scope': scope,
        'trimmed': trimmed,
        'base': {'audit': a.base} if a.base else None,
        'umbrella': umbrella,
        'repos': repos,
        'toolchain': toolchain(),
        'profile': a.profile,
        'agents': agents,
        'wave': a.wave,
        'security_units': units,
        'modernization_units': modern,
        'calibration_units': cal_units,
    }
    for sub in ('candidates', 'verdicts', 'evidence'):
        (rd / sub).mkdir(parents=True, exist_ok=True)
    write_json(rd / 'manifest.json', manifest)
    write_atomic(rd / 'MANIFEST.md', render_manifest(manifest))
    stale = [r['name'] for r in repos if r['pin_matches'] is False]
    if aside is not None:
        say(f'  moved the previous run aside: {rel(aside)}')
    say(f'✓ {rel(rd)}: {len(repos)} repositories, {len(units)} security, {len(modern)} modernization and '
        f'{len(cal_units)} calibration finders · scope {scope}' + (f" (left out: {', '.join(trimmed)})" if trimmed else ''))
    say(f'  agents: {agents_line(manifest)}')
    if stale:
        say(f'  ! {", ".join(stale)}: the checked-out commit differs from the umbrella pin (the manifest records both)')
    if dirty:
        say(f'  ! audited with uncommitted changes in {", ".join(dirty)}')
    say(f'  next: wfl audit:evidence {version}{suffix}' + (f', then wfl audit:calibrate {version}{suffix}' if cal_units else ''))
    return 0


def render_manifest(m: dict) -> str:
    tc = m['toolchain']
    scope = m['scope'] + (f" (left out: {', '.join(m['trimmed'])})" if m.get('trimmed') else '') \
        + (f" (base audit {m['base']['audit']})" if m.get('base') else '')
    lines = [
        f"# Release audit manifest · {m['version']} ({m['run']})",
        '',
        f"Created {m['created']} · scope {scope} · umbrella `{m['umbrella']['sha'][:12]}` on "
        f"`{m['umbrella']['branch']}`",
        f"Toolchain: PHP {tc['php']} · FrankenPHP {tc['frankenphp']} · Mago {tc['mago']} · igor {tc['igor']}",
        f"Agents: {agents_line(m)}",
        '',
        '| Repository | Commit | Branch | Umbrella pin | Group |',
        '|---|---|---|---|---|',
    ]
    for r in m['repos']:
        pin = '—' if r['pin'] is None else ('matches' if r['pin_matches'] else f"differs (`{r['pin'][:12]}`)")
        lines.append(f"| {r['name']} | `{r['sha'][:12]}`{' (dirty)' if r['dirty'] else ''} | {r['branch']} | {pin} | {r['group']} |")
    lines += ['', '## Finders', '']
    for u in m['security_units']:
        names = ', '.join(f"{lens} {LENSES[lens]}" for lens in u['lenses'])
        lines.append(f"- `S-{u['id']}`: {names}" + (f" (scope: {u['scope']})" if u.get('scope') else ''))
    for u in m['modernization_units']:
        lines.append(f"- `M-{u['id']}`: {', '.join(u['repos'])}")
    for u in m.get('calibration_units') or []:
        lines.append(f"- `{u['id']}`: calibration, {u['repo']} before `{u['fix']}` ({', '.join(u['lenses'])})")
    return '\n'.join(lines) + '\n'


# --- evidence ---------------------------------------------------------------------------
def run_tool(cmd: list[str], timeout: int = TOOL_TIMEOUT, cwd: Path | None = None) -> tuple[int, str, str]:
    try:
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
    except subprocess.TimeoutExpired:
        return 124, '', f'timed out after {timeout} s'
    except OSError as e:
        return 127, '', str(e)
    return run.returncode, run.stdout, run.stderr


def parse_json(text: str):
    text = text.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except ValueError:
        start = min([i for i in (text.find('{'), text.find('[')) if i >= 0], default=-1)
        if start < 0:
            return None
        try:
            return json.loads(text[start:])
        except ValueError:
            return None


def mago_rows(data) -> list[tuple[str, str, str]]:
    rows = []
    for issue in (data or {}).get('issues', []):
        for ann in issue.get('annotations', [])[:1]:
            span = ann.get('span', {})
            name = span.get('file_id', {}).get('name', '?')
            line = span.get('start', {}).get('line')
            # Mago's JSON counts lines from 0; the report cites them from 1, as editors do.
            rows.append((issue.get('code', '?'), f"{name}:{line + 1 if isinstance(line, int) else '?'}", ann.get('message', '')))
    return rows


def psalm_rows(data) -> list[tuple[str, str, str]]:
    rows = []
    for issue in data or []:
        if isinstance(issue, dict):
            rows.append((issue.get('type', '?'), f"{issue.get('file_name', '?')}:{issue.get('line_from', '?')}",
                         issue.get('message', '')))
    return rows


def evidence_for(repo: dict, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    workdir = f"/waffle-commons/{repo['path']}"
    host = ROOT / repo['path']
    summary: dict = {'repo': repo['name'], 'sha': repo['sha'], 'collected': now(), 'tools': {}}

    code, stdout, stderr = run_tool(['docker', 'exec', '-w', workdir, CONTAINER, 'vendor/bin/mago', 'lint',
                                     '--only', METRIC_RULES, '--reporting-format', 'json'])
    data = parse_json(stdout)
    (out / 'mago-metrics.json').write_text(stdout or stderr, encoding='utf-8')
    rows = mago_rows(data)
    summary['tools']['mago-metrics'] = {'ok': data is not None, 'count': len(rows), 'rows': rows[:40],
                                        'note': '' if data is not None else (stderr.strip()[-300:] or f'exit {code}')}

    if (host / 'vendor' / 'bin' / 'psalm').exists():
        code, stdout, stderr = run_tool(['docker', 'exec', '-w', workdir, CONTAINER, 'vendor/bin/psalm',
                                         '--taint-analysis', '--output-format=json', '--no-progress'])
        data = parse_json(stdout)
        (out / 'psalm-taint.json').write_text(stdout or stderr, encoding='utf-8')
        rows = psalm_rows(data)
        summary['tools']['psalm-taint'] = {'ok': data is not None, 'count': len(rows), 'rows': rows[:40],
                                           'note': '' if data is not None else (stderr.strip()[-300:] or f'exit {code}')}
    else:
        summary['tools']['psalm-taint'] = {'ok': False, 'count': 0, 'rows': [], 'note': 'psalm not installed here'}

    code, stdout, stderr = run_tool(['docker', 'exec', '-w', workdir, CONTAINER, 'composer', 'audit',
                                     '--format=json', '--locked'])
    data = parse_json(stdout)
    (out / 'composer-audit.json').write_text(stdout or stderr, encoding='utf-8')
    advisories = data.get('advisories', {}) if isinstance(data, dict) else {}
    found = [(pkg, a.get('advisoryId', '?'), a.get('title', '')) for pkg, items in
             (advisories.items() if isinstance(advisories, dict) else []) for a in items]
    summary['tools']['composer-audit'] = {'ok': data is not None, 'count': len(found), 'rows': found,
                                          'note': '' if data is not None else (stderr.strip()[-300:] or f'exit {code}')}

    if repo['path'] == GATEWAY_PATH:
        summary['tools']['igor'] = {'ok': False, 'count': 0, 'rows': [],
                                    'note': "outside igor.sh's scan: the gateway's own CI runs igor at the pinned version"}
    else:
        code, stdout, stderr = run_tool([str(ROOT / 'igor.sh'), '-c', repo['name']], cwd=ROOT)
        (out / 'igor.txt').write_text(stdout + stderr, encoding='utf-8')
        row = re.search(r'^\s*\[(OK|ERROR|WARN)\]\s+' + re.escape(repo['name']) + r'\s+(\d+)\s*$', stdout, re.M)
        state, dangerous = (row.group(1), int(row.group(2))) if row else ('unparsed', 0)
        summary['tools']['igor'] = {'ok': code == 0 and row is not None, 'count': dangerous, 'rows': [],
                                    'note': f'igor.sh status {state} · KO (dangerous state) {dangerous} · exit {code}'}

    code, stdout, stderr = run_tool(['docker', 'exec', '-w', '/waffle-commons', CONTAINER, 'php',
                                     'scripts/sec03-compare-audit.php', repo['path']])
    (out / 'compare-audit.txt').write_text(stdout + stderr, encoding='utf-8')
    summary['tools']['compare-audit'] = {'ok': code == 0, 'count': 0 if code == 0 else 1, 'rows': [],
                                         'note': (stdout.strip().splitlines() or [''])[-1][:200]}

    write_json(out / 'summary.json', summary)
    write_atomic(out / 'SUMMARY.md', render_evidence(summary))
    return summary


def render_evidence(s: dict) -> str:
    lines = [f"# Evidence · {s['repo']} @ `{s['sha'][:12]}`", '', f"Collected {s['collected']}. Report-only: no tool here is a gate.", '']
    for tool, res in s['tools'].items():
        state = 'ran' if res['ok'] else 'did not run cleanly'
        lines.append(f"## {tool}: {res['count']} item(s), {state}")
        if res.get('note'):
            lines.append(f"_{res['note']}_")
        for row in res.get('rows', [])[:40]:
            lines.append('- ' + ' · '.join(str(c) for c in row))
        lines.append('')
    return '\n'.join(lines)


def cmd_evidence(a: argparse.Namespace) -> int:
    if a.latest and a.version:  # `--latest queue`: the positional is a repository, not a version
        a.repos = [a.version] + list(a.repos or [])
        a.version = None
    rd = resolve_run(a)
    m = load_manifest(rd)
    wanted = set(a.repos or [])
    repos = [r for r in m['repos'] if not wanted or r['name'] in wanted]
    if wanted - {r['name'] for r in m['repos']} - {UMBRELLA}:
        raise Problem(f"not in this run's manifest: {', '.join(sorted(wanted - {r['name'] for r in m['repos']} - {UMBRELLA}))}")
    if docker_out(['true']) is None:
        raise Problem(f'the {CONTAINER} container is not running (wfl up)')
    rows = []
    for r in repos:
        say(f"→ {r['name']}")
        s = evidence_for(r, rd / 'evidence' / r['name'])
        rows.append((r['name'], s))
        say('  ' + ' · '.join(f"{t} {v['count']}" + ('' if v['ok'] else ' (!)') for t, v in s['tools'].items()))
    if any(u.get('scope') == UMBRELLA for u in m['security_units']) and (not wanted or UMBRELLA in wanted):
        out = rd / 'evidence' / UMBRELLA
        out.mkdir(parents=True, exist_ok=True)
        code, stdout, stderr = run_tool([sys.executable, str(ROOT / 'scripts' / 'ai-check.py'), '--no-claude'], cwd=ROOT)
        (out / 'ai-check.txt').write_text(stdout + stderr, encoding='utf-8')
        write_atomic(out / 'SUMMARY.md', f"# Evidence · umbrella AI layer\n\n`wfl ai:check --no-claude`: exit {code}.\n\n```text\n{stdout[-4000:]}\n```\n")
        say(f'→ umbrella AI layer: ai:check exit {code}')
    index = ['# Evidence index', '', '| Repository | ' + ' | '.join(['mago-metrics', 'psalm-taint', 'composer-audit', 'igor', 'compare-audit']) + ' |',
             '|---|---|---|---|---|---|']
    for sub in sorted((rd / 'evidence').glob('*/summary.json')):
        s = json.loads(sub.read_text(encoding='utf-8'))
        cells = []
        for tool in ('mago-metrics', 'psalm-taint', 'composer-audit', 'igor', 'compare-audit'):
            v = s['tools'].get(tool)
            cells.append('—' if v is None else f"{v['count']}{'' if v['ok'] else ' ⚠'}")
        index.append(f"| {s['repo']} | " + ' | '.join(cells) + ' |')
    write_atomic(rd / 'evidence' / 'INDEX.md', '\n'.join(index) + '\n')
    say(f"✓ evidence for {len(rows)} repositories in {rel(rd / 'evidence')}")
    return 0


# --- calibration ----------------------------------------------------------------------------
def extract(where: Path, rev: str, dest: Path) -> None:
    run = subprocess.run(['git', '-C', str(where), 'archive', '--format=tar', rev], capture_output=True)
    if run.returncode != 0:
        raise Problem(f'git archive {rev} failed in {where}: {run.stderr.decode(errors="replace").strip()}')
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(run.stdout)) as tar:
        try:
            tar.extractall(dest, filter='data')
        except TypeError:  # Python before 3.12: no extraction filter, so refuse what would leave dest
            for member in tar.getmembers():
                if member.name.startswith('/') or '..' in Path(member.name).parts:
                    raise Problem(f'git archive {rev} holds a path outside its tree: {member.name}')
            tar.extractall(dest)


def old_hunks(where: Path, fix: str, path: str) -> list[list[int]]:
    """The line ranges a fix changed in a file, numbered as in its parent (the tree the finder reads)."""
    out = git(where, 'diff', '--unified=0', f'{fix}^', fix, '--', path, check=False)
    hunks = []
    for m in HUNK.finditer(out):
        start = int(m.group(1))
        count = int(m.group(2)) if m.group(2) is not None else 1
        hunks.append([start, start + max(count, 1) - 1])
    return hunks


def cmd_calibrate(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    m = load_manifest(rd)
    units = m.get('calibration_units') or []
    if not units:
        raise Problem('this run has no calibration units (a full run has them unless --no-calibration; '
                      'a partial one with --with-calibration)')
    shas = {r['name']: r['sha'] for r in m['repos']}
    expected: dict = {'version': m['version'], 'run': m['run'], 'prepared': now(), 'margin': CALIBRATION_MARGIN, 'units': {}}
    for u in units:
        where = ROOT / u['repo']
        parent = git(where, 'rev-parse', '--verify', f"{u['fix']}^")
        out = rd / 'calibration' / u['id']
        if out.exists():
            shutil.rmtree(out)
        extract(where, parent, out / u['repo'])
        # Dependencies the code reads (an `Assert` in utils decided a beta6 defect): at the audited commit.
        for dep in ('utils', 'contracts'):
            if dep != u['repo'] and (ROOT / dep / 'composer.json').is_file():
                extract(ROOT / dep, shas.get(dep) or git(ROOT / dep, 'rev-parse', 'HEAD'), out / dep)
        expected['units'][u['id']] = {
            'repo': u['repo'], 'tree': parent, 'lenses': u['lenses'],
            'defects': {d['id']: {f: old_hunks(where, u['fix'], f) for f in d['files']} for d in u['defects']},
        }
        say(f"→ {u['id']}: {u['repo']} at {parent[:12]} ({', '.join(u['lenses'])}) in {rel(out)}")
    write_json(rd / 'calibration' / 'expected.json', expected)
    say(f"✓ {len(units)} calibration snapshot(s); dispatch one owasp-finder per unit in calibration mode "
        f"(it reads only calibration/<unit>/ and writes candidates/<unit>.md)")
    return 0


def locations_of(c: dict) -> list[tuple[str, int]]:
    return [(p, int(n)) for p, n in LOCATION.findall(' '.join(str(c.get(k, '')) for k in ('where', 'also')))]


def hits(locations: list[tuple[str, int]], defect: dict[str, list[list[int]]], margin: int) -> bool:
    return any(path.endswith(f) and any(start - margin <= line <= end + margin for start, end in ranges)
               for path, line in locations for f, ranges in defect.items())


def calibration_result(rd: Path, m: dict, col: dict) -> dict | None:
    """Recall on the known defects: a defect counts as found when a candidate sits on the lines its fix changed."""
    units = m.get('calibration_units') or []
    if not units:
        return None
    path = rd / 'calibration' / 'expected.json'
    expected = load_json(path, 'calibration/expected.json') if path.is_file() else None
    margin = (expected or {}).get('margin', CALIBRATION_MARGIN)
    states = {u['unit']: u['state'] for u in col['units']}
    rows = []
    for u in units:
        done = states.get(u['id']) == 'done'
        spots = [loc for c in col['calibration'].get(u['id'], []) for loc in locations_of(c)]
        for d in u['defects']:
            exp = (((expected or {}).get('units') or {}).get(u['id']) or {}).get('defects', {}).get(d['id'])
            rows.append({'defect': d['id'], 'unit': u['id'], 'repo': u['repo'],
                         'found': hits(spots, exp, margin) if done and exp is not None else None})
    return {'prepared': expected is not None, 'units': len(units), 'done': sum(1 for u in units if states.get(u['id']) == 'done'),
            'defects': len(rows), 'found': sum(1 for r in rows if r['found']), 'rows': rows}


# --- candidates and verdicts ---------------------------------------------------------------
def blocks(text: str, head: re.Pattern) -> list[dict]:
    found = list(head.finditer(text))
    out = []
    for i, mt in enumerate(found):
        end = found[i + 1].start() if i + 1 < len(found) else len(text)
        body = text[mt.end():end]
        nxt = re.search(r'^#{1,2} ', body, re.M)
        if nxt:
            body = body[:nxt.start()]
        fields: dict[str, str] = {}
        for key, value in FIELD.findall(body):
            fields.setdefault(key, value.strip())  # the first occurrence wins: a snippet cannot override a field
        out.append({'groups': mt.groups(), 'fields': fields})
    return out


def stray_headings(text: str, head: re.Pattern, section: str | None = None) -> list[str]:
    """Headings the parser would skip without a word: any `### ` line of `section`, and anywhere one that starts
    with an ID (`### S-A05-01 …`) yet misses the template. Code fences and other sections (`## Checked`) are free."""
    stray, fenced, inside = [], False, False
    for line in text.splitlines():
        if line.startswith('```'):
            fenced = not fenced
        elif fenced:
            continue
        elif line.startswith('## '):
            inside = section is not None and line.strip() == section
        elif line.startswith('### ') and not head.fullmatch(line.rstrip()) and (inside or ID_HEADING.match(line)):
            stray.append(line.strip()[:80])
    return stray


def parse_candidates(text: str) -> list[dict]:
    return [{'id': b['groups'][0], 'severity': b['groups'][1], 'title': b['groups'][2], **b['fields']}
            for b in blocks(text, CANDIDATE_HEAD)]


def parse_verdicts(text: str) -> list[dict]:
    return [{'id': b['groups'][0], 'verdict': b['groups'][1], 'severity': b['groups'][2], **b['fields']}
            for b in blocks(text, VERDICT_HEAD)]


def final_verdict(verdicts: list[str]) -> str | None:
    """Majority of the verdicts on one candidate; None while a refutation and a confirmation tie."""
    if not verdicts:
        return None
    refuted = verdicts.count('REFUTED')
    upheld = len(verdicts) - refuted
    if refuted and upheld and refuted == upheld:
        return None
    if refuted > upheld:
        return 'REFUTED'
    return 'CONFIRMED' if verdicts.count('CONFIRMED') > verdicts.count('PLAUSIBLE') else 'PLAUSIBLE'


def unit_files(m: dict) -> list[tuple[str, str]]:
    return ([('security', f"S-{u['id']}") for u in m['security_units']]
            + [('modernization', f"M-{u['id']}") for u in m['modernization_units']]
            + [('calibration', u['id']) for u in m.get('calibration_units') or []])


def collect(rd: Path, m: dict) -> dict:
    units = []
    candidates: dict[str, dict] = {}
    calibration: dict[str, list[dict]] = {}
    unparsed: list[str] = []
    for phase, stem in unit_files(m):
        path = rd / 'candidates' / f'{stem}.md'
        text = path.read_text(encoding='utf-8') if path.is_file() else ''
        complete = bool(COMPLETE.search(text))
        found = parse_candidates(text) if complete else []
        if complete:
            unparsed += [f'candidates/{stem}.md: "{h}"' for h in stray_headings(text, CANDIDATE_HEAD, '## Candidates')]
        for c in found:
            if phase == 'calibration':
                calibration.setdefault(stem, []).append(c)
            else:
                candidates[c['id']] = {**c, 'file': stem, 'phase': phase}
        units.append({'unit': stem, 'phase': phase, 'state': 'done' if complete else ('partial' if text else 'missing'),
                      'candidates': len(found)})
    verdicts: dict[str, list[dict]] = {}
    for path in sorted((rd / 'verdicts').glob('*.md')):
        if path.stem.startswith('fix-'):
            continue  # a fix-check, read by fix_check()
        text = path.read_text(encoding='utf-8')
        if not COMPLETE.search(text):
            continue
        unparsed += [f'verdicts/{path.name}: "{h}"' for h in stray_headings(text, VERDICT_HEAD)]
        for v in parse_verdicts(text):
            verdicts.setdefault(v['id'], []).append({**v, 'file': path.stem})
    final = {cid: final_verdict([v['verdict'] for v in verdicts.get(cid, [])]) for cid in candidates}
    return {'units': units, 'candidates': candidates, 'calibration': calibration, 'verdicts': verdicts,
            'final': final, 'unparsed': unparsed}


def needs_two(candidate: dict, verdicts: list[dict]) -> bool:
    """A HIGH or CRITICAL, as the finder or any verifier rates it, gets a verifier of its own."""
    return bool(({candidate.get('severity')} | {v.get('severity') for v in verdicts}) & {'HIGH', 'CRITICAL'})


def verification_of(col: dict) -> dict:
    cands, verdicts = col['candidates'], col['verdicts']
    return {
        'unverified': sorted(cid for cid in cands if not verdicts.get(cid)),
        'second': sorted(cid for cid in cands if len(verdicts.get(cid, [])) == 1 and needs_two(cands[cid], verdicts[cid])),
        'disputed': sorted(cid for cid in cands if verdicts.get(cid) and col['final'][cid] is None),
    }


# --- ledger -------------------------------------------------------------------------------------
def repo_for(where_path: str, m: dict) -> dict:
    best = None
    for r in m['repos']:
        if where_path.startswith(r['path'] + '/') and (best is None or len(r['path']) > len(best['path'])):
            best = r
    return best or m['umbrella']


_LINES: dict[tuple[str, str, str], int | None] = {}


def file_lines(repo: dict, relpath: str) -> int | None:
    key = (repo['path'], repo['sha'], relpath)
    if key not in _LINES:
        run = subprocess.run(['git', '-C', str(where_of(repo)), 'show', f"{repo['sha']}:{relpath}"], capture_output=True)
        _LINES[key] = None if run.returncode != 0 else \
            run.stdout.count(b'\n') + (0 if run.stdout.endswith(b'\n') or not run.stdout else 1)
    return _LINES[key]


def findings_of(ledger: dict) -> list[dict]:
    findings = ledger.get('findings') if isinstance(ledger, dict) else None
    return [f for f in findings if isinstance(f, dict)] if isinstance(findings, list) else []


def subject_of(f: dict) -> str:
    """The fingerprint of what a decision is about; a change to the finding afterwards voids the decision."""
    body = json.dumps({k: f.get(k) for k in SUBJECT_KEYS}, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(body.encode('utf-8')).hexdigest()[:16]


def location_errors(label: str, text, m: dict, component) -> tuple[list[str], list[str]]:
    errors, warnings = [], []
    loc = WHERE.match(text) if isinstance(text, str) else None
    if not loc:
        return [f'{label} "{text}" is not path:line'], warnings
    repo = repo_for(loc.group(1), m)
    if not repo['path'] and (ROOT / loc.group(1).split('/', 1)[0] / '.git').exists():
        return errors, warnings  # a sibling repository outside this run: no commit pins it here
    relpath = loc.group(1)[len(repo['path']) + 1:] if repo['path'] else loc.group(1)
    count = file_lines(repo, relpath)
    if count is None:
        errors.append(f"{label}: {loc.group(1)} does not exist at {repo['name']}@{repo['sha'][:12]}")
    elif int(loc.group(3) or loc.group(2)) > count:
        errors.append(f"{label}: line {loc.group(3) or loc.group(2)} is past the end of {loc.group(1)} ({count} lines)")
    if isinstance(component, str) and component and repo['name'] not in (component, UMBRELLA):
        warnings.append(f"{label}: component is {component} but the path belongs to {repo['name']}")
    return errors, warnings


def validate(ledger, m: dict, gate: bool) -> tuple[list[str], list[str]]:
    """The ledger's own rules: shape, fields, locations, decisions. The run-level rules are in triage_check()."""
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(ledger, dict):
        return ['ledger.json is not a JSON object'], warnings
    findings = ledger.get('findings')
    if not isinstance(findings, list):
        return ['ledger.json has no "findings" list'], warnings
    refuted = ledger.get('refuted')
    if refuted is not None and not (isinstance(refuted, list) and all(isinstance(r, dict) and isinstance(r.get('id'), str) for r in refuted)):
        errors.append('"refuted" must be a list of {id, control} objects')
    seen = set()
    unbound = 0
    for i, f in enumerate(findings):
        if not isinstance(f, dict):
            errors.append(f'#{i + 1}: a finding must be a JSON object')
            continue
        fid = f['id'] if isinstance(f.get('id'), str) and f['id'] else f'#{i + 1}'
        for key in REQUIRED:
            if f.get(key) in (None, ''):
                errors.append(f'{fid}: "{key}" is missing')
            elif not isinstance(f.get(key), str):
                errors.append(f'{fid}: "{key}" must be text')
        if fid in seen:
            errors.append(f'{fid}: duplicate id')
        seen.add(fid)
        for key, allowed in (('severity', SEVERITIES), ('verdict', ['CONFIRMED', 'PLAUSIBLE']), ('moscow', MOSCOW),
                             ('proposal', CHOICES), ('status', STATUSES), ('phase', PHASES)):
            if isinstance(f.get(key), str) and f.get(key) and f[key] not in allowed:
                errors.append(f'{fid}: {key} "{f[key]}" is not one of {", ".join(allowed)}')
        if isinstance(f.get('lens'), str) and f['lens'] and f.get('phase') == 'security' and f['lens'] not in LENSES:
            errors.append(f'{fid}: lens "{f["lens"]}" is not a security lens')
        if isinstance(f.get('where'), str) and f['where']:
            e, w = location_errors(f'{fid}: where', f['where'], m, f.get('component'))
            errors += e
            warnings += w
        for key in ('also', 'duplicates'):
            if f.get(key) is not None and not (isinstance(f[key], list) and all(isinstance(x, str) for x in f[key])):
                errors.append(f'{fid}: "{key}" must be a list of text')
        extras = f['also'] if isinstance(f.get('also'), list) else []
        for extra in extras:
            if isinstance(extra, str):
                errors += location_errors(f'{fid}: also', extra, m, None)[0]
        decision = f.get('decision')
        status = f.get('status')
        if decision is not None:
            if not isinstance(decision, dict) or decision.get('choice') not in CHOICES:
                errors.append(f'{fid}: decision must be {{choice, reason, residual_risk, by, at}} with choice {", ".join(CHOICES)}')
            else:
                for key in ('by', 'at'):
                    if not isinstance(decision.get(key), str) or not decision[key]:
                        errors.append(f'{fid}: the decision has no "{key}" (the maintainer records it in /audit or with `wfl audit:sign`)')
                texts = {k: decision.get(k) for k in ('reason', 'residual_risk', 'via', 'subject')}
                for key, value in texts.items():
                    if value is not None and not isinstance(value, str):
                        errors.append(f'{fid}: the decision\'s "{key}" must be text')
                if decision['choice'] in ('accept', 'post-v1'):
                    if not str(texts['reason'] or '').strip():
                        errors.append(f"{fid}: a {decision['choice']} decision needs its reason")
                    if not str(texts['residual_risk'] or '').strip():
                        errors.append(f"{fid}: a {decision['choice']} decision needs its residual risk")
                if texts['subject'] is None:
                    unbound += 1
                elif texts['subject'] != subject_of(f):
                    errors.append(f'{fid}: the finding changed after its decision (title, severity, location, summary or '
                                  'fix): the maintainer decides it again')
                expected = {'fix': ('open', 'fixed'), 'accept': ('accepted',), 'post-v1': ('deferred',)}[decision['choice']]
                if status not in expected:
                    errors.append(f"{fid}: status {status} does not match the decision {decision['choice']}")
                if decision['choice'] == 'post-v1' and f.get('severity') == 'CRITICAL':
                    errors.append(f'{fid}: a CRITICAL cannot move to post-v1: fix it or accept the risk')
        elif status not in (None, 'open'):
            errors.append(f'{fid}: status {status} without a decision')
        if status == 'fixed':
            fb = f.get('fixed_by') if isinstance(f.get('fixed_by'), dict) else {}
            if not isinstance(fb.get('repo'), str) or not fb.get('repo') or not isinstance(fb.get('commit'), str) or not fb.get('commit'):
                errors.append(f'{fid}: fixed without fixed_by (record it with `wfl audit:fixed`)')
        if gate:
            if decision is None:
                errors.append(f'{fid}: no decision yet')
            elif isinstance(decision, dict) and decision.get('choice') == 'fix' and status != 'fixed':
                errors.append(f'{fid}: decided "fix" but not fixed yet')
        elif isinstance(decision, dict) and decision.get('choice') == 'fix' and not (f.get('roadmap') and f.get('ticket')):
            warnings.append(f'{fid}: decided "fix" but has no roadmap item or ticket yet')
        if f.get('verdict') == 'PLAUSIBLE':
            warnings.append(f'{fid}: PLAUSIBLE, not CONFIRMED')
    if unbound:
        warnings.append(f'{unbound} decision(s) carry no fingerprint (signed before the 0.6 tooling): '
                        'a later change to those findings goes unnoticed')
    return errors, warnings


def triage_check(rd: Path, m: dict, ledger, col: dict) -> tuple[list[str], list[str]]:
    """The ledger against the run: every verified candidate accounted for, nothing invented, the report written."""
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(ledger, dict):
        return errors, warnings
    if ledger.get('version') != m['version'] or ledger.get('run') != m['run']:
        errors.append(f"ledger.json is for {ledger.get('version')} ({ledger.get('run')}), not {m['version']} ({m['run']})")
    findings = findings_of(ledger)
    ids = {f.get('id') for f in findings}
    dups = {d for f in findings for d in (f.get('duplicates') or []) if isinstance(d, str)}
    refuted = {r.get('id') for r in (ledger.get('refuted') or []) if isinstance(r, dict)} \
        if isinstance(ledger.get('refuted'), list) else set()
    for cid, verdict in sorted(col['final'].items()):
        if verdict in ('CONFIRMED', 'PLAUSIBLE') and cid not in ids and cid not in dups:
            errors.append(f'{cid}: {verdict} by verification, but in no ledger finding and no "duplicates" list')
        elif verdict == 'REFUTED' and cid not in refuted:
            errors.append(f'{cid}: REFUTED by verification, but missing from the ledger\'s "refuted" list')
    for fid in sorted(i for i in ids if isinstance(i, str) and i not in col['candidates']):
        errors.append(f'{fid}: not a candidate of this run')
    rank = {s: n for n, s in enumerate(SEVERITIES)}
    for f in findings:
        rated = [v.get('severity') for v in col['verdicts'].get(f.get('id'), []) if v.get('severity') in rank]
        if rated and f.get('severity') in rank and rank[f['severity']] > min(rank[s] for s in rated) and not f.get('notes'):
            warnings.append(f"{f['id']}: severity {f['severity']} is below its verifiers' {SEVERITIES[min(rank[s] for s in rated)]}, "
                            'and no note says why')
    if not (rd / 'consolidated.md').is_file():
        errors.append('consolidated.md is missing (the audit-triager writes it with the ledger)')
    return errors, warnings


def run_errors(m: dict, col: dict, cal: dict | None) -> list[str]:
    """What a run still lacks before its ledger can be trusted: finders, verification, calibration."""
    errors = []
    missing = [u['unit'] for u in col['units'] if u['state'] != 'done']
    if missing:
        errors.append(f'finders not complete: {", ".join(missing)}')
    errors += [f'{u}: a heading that does not parse (the template\'s "### <ID> · <SEVERITY> · <title>")' for u in col['unparsed']]
    v = verification_of(col)
    if v['unverified']:
        errors.append(f'not verified yet: {", ".join(v["unverified"])}')
    if v['second']:
        errors.append(f'HIGH or CRITICAL with a single verdict (each needs its own verifier): {", ".join(v["second"])}')
    if v['disputed']:
        errors.append(f'disputed (a third verifier breaks the tie): {", ".join(v["disputed"])}')
    if cal is not None:
        if not cal['prepared']:
            errors.append('the calibration is not prepared (wfl audit:calibrate)')
        elif cal['done'] < cal['units']:
            errors.append(f"calibration finders not complete: {cal['done']}/{cal['units']}")
    return errors


def fix_check(rd: Path, fid: str) -> dict | None:
    """The fix-check a finding-verifier wrote: `### FIX <ID> · HOLDS|FAILS` and `- fix: <repo>@<commit>`."""
    path = rd / 'verdicts' / f'fix-{fid}.md'
    if not path.is_file():
        return None
    text = path.read_text(encoding='utf-8')
    head = re.search(r'^### FIX ' + re.escape(fid) + r' · (HOLDS|FAILS)\s*$', text, re.M)
    if not head:
        return None
    line = re.search(r'^- fix: ([\w.-]+)@([0-9a-f]{7,40})\s*$', text[head.end():], re.M)
    return {'state': head.group(1), 'repo': line.group(1) if line else '', 'commit': line.group(2) if line else ''}


def closure_errors(rd: Path, m: dict, f: dict) -> list[str]:
    """A fixed finding: the commit exists, comes after the audit, is released, and its fix-check HOLDS."""
    fid = f.get('id', '?')
    fb = f.get('fixed_by') if isinstance(f.get('fixed_by'), dict) else {}
    repos = {r['name']: r for r in m['repos']}
    repos[UMBRELLA] = m['umbrella']
    repo = repos.get(fb.get('repo'))
    if repo is None:
        return [f'{fid}: fixed_by names {fb.get("repo")!r}, not a repository of this run']
    where = where_of(repo)
    full = git(where, 'rev-parse', '--verify', '--quiet', f"{fb.get('commit')}^{{commit}}", check=False)
    if not full:
        return [f"{fid}: fixed_by commit {fb.get('commit')} is not a commit in {repo['name']}"]
    errors = []
    if full == repo['sha'] or not is_ancestor(where, repo['sha'], full):
        errors.append(f"{fid}: the fix {full[:12]} does not come after the audited commit {repo['sha'][:12]}")
    point = release_point(repo)
    if not point or not is_ancestor(where, full, point):
        errors.append(f"{fid}: the fix {full[:12]} is not in what {repo['name']} releases ({(point or 'no pin')[:12]}): "
                      'merge it, then re-pin the umbrella')
    check = fix_check(rd, fid)
    if check is None:
        errors.append(f'{fid}: no fix-check (verdicts/fix-{fid}.md, written by a finding-verifier)')
    elif check['state'] != 'HOLDS':
        errors.append(f'{fid}: its fix-check FAILS')
    elif check['repo'] != repo['name'] or not full.startswith(check['commit']):
        errors.append(f"{fid}: the fix-check verified {check['repo'] or '?'}@{check['commit'] or '?'}, not {repo['name']}@{full[:12]}")
    return errors


def ancestry_errors(runs: list[tuple[Path, dict]]) -> list[str]:
    """Each audited commit sits in what its repository releases now: the audit applies to this release."""
    errors = []
    for rd, m in runs:
        for repo in m['repos'] + [m['umbrella']]:
            point = release_point(repo)
            if not point or not is_ancestor(where_of(repo), repo['sha'], point):
                errors.append(f"{repo['name']}: the commit audited by run {rd.name} ({repo['sha'][:12]}) is not in what it "
                              f"releases ({(point or 'no pin')[:12]})")
    return errors


def coverage_errors(runs: list[tuple[Path, dict]]) -> list[str]:
    """The release's complete runs, together, cover every released repository, the gateway, AG, WA and a calibration."""
    errors = []
    covered: set[str] = set()
    for _, m in runs:
        if set(CORE_LENSES) <= {lens for u in m['security_units'] for lens in u['lenses']}:
            covered |= {r['name'] for r in m['repos']}
    missing = [n for n in release_repos() if n not in covered]
    if missing:
        errors.append(f'not covered by a complete run of this release (every core lens): {", ".join(missing)}')
    if GATEWAY_NAME not in covered:
        errors.append(f'the EcoShield gateway is not covered: [AUD-01] audits its proxy path ({GATEWAY_PATH})')
    if not any(u['id'] == 'AG' for _, m in runs for u in m['security_units']):
        errors.append('the agentic layer (AG) is not covered by a complete run of this release')
    if 'auth' in covered and not any('auth' in {r['name'] for r in m['repos']} and any(u['id'] == 'WA' for u in m['security_units'])
                                     for _, m in runs):
        errors.append('auth has no WebAuthn (WA) unit in a complete run of this release')
    if not runs[0][1].get('calibration_units'):
        errors.append('the release run has no calibration (the known beta6 defects): it needs one unless it is diff-scoped')
    return errors + ancestry_errors(runs)


def run_gate_errors(rd: Path, m: dict, ledger, col: dict, cal: dict | None) -> tuple[list[str], list[str]]:
    """One run's own gate: complete, reconciled, every finding decided, every fix verified and released."""
    errors, warnings = validate(ledger, m, gate=True)
    triage, more = triage_check(rd, m, ledger, col)
    errors += run_errors(m, col, cal) + triage
    warnings += more
    for f in findings_of(ledger):
        if f.get('status') == 'fixed':
            errors += closure_errors(rd, m, f)
    return errors, warnings


def gate_errors(version: str, depth: int = 0) -> tuple[list[str], list[str]]:
    """The release gate: the release run's own gate, the release's other runs, and the surface they cover."""
    rd = run_dir(version, RELEASE_RUN)
    m = load_manifest(rd)
    ledger = load_ledger(rd)
    col = collect(rd, m)
    errors, warnings = run_gate_errors(rd, m, ledger, col, calibration_result(rd, m, col))
    runs = [(rd, m)]
    for other in sibling_runs(rd):
        name = other.name
        try:
            om = load_manifest(other)
            oledger = load_ledger(other) if (other / 'ledger.json').is_file() else None
        except Problem as e:
            errors.append(f'run {name}: {e}')
            continue
        if oledger is None:
            warnings.append(f'run {name}: no ledger, so it covers nothing')
            continue
        own, _ = validate(oledger, om, gate=False)
        errors += [f'run {name}: {e}' for e in own]
        undecided = 0
        for f in findings_of(oledger):
            decision = f.get('decision')
            if not isinstance(decision, dict):
                undecided += 1
            elif decision.get('choice') == 'fix':
                if f.get('status') != 'fixed':
                    errors.append(f"run {name}: {f.get('id')}: decided \"fix\" but not fixed yet")
                else:
                    errors += [f'run {name}: {e}' for e in closure_errors(other, om, f)]
        if undecided:
            warnings.append(f'run {name}: {undecided} finding(s) undecided, so outside this gate (decide them in /audit --run {name})')
        ocol = collect(other, om)
        complete = not run_errors(om, ocol, calibration_result(other, om, ocol)) and not triage_check(other, om, oledger, ocol)[0]
        if complete and not undecided:
            runs.append((other, om))
        else:
            warnings.append(f'run {name}: not complete, so its repositories do not count as covered')
    if m.get('scope') == 'diff':
        base = (m.get('base') or {}).get('audit')
        if not base:
            errors.append('a diff-scoped run names no base audit')
        elif depth >= MAX_BASE_DEPTH:
            errors.append(f'the base audits nest deeper than {MAX_BASE_DEPTH}')
        else:
            try:
                be, bw = gate_errors(base, depth + 1)
            except Problem as e:
                be, bw = [str(e)], []
            errors += [f'base audit {base}: {e}' for e in be]
            warnings += [f'base audit {base}: {w}' for w in bw]
        errors += ancestry_errors(runs)
    else:
        errors += coverage_errors(runs)
    return errors, warnings


def ledger_counts(ledger) -> dict:
    findings = findings_of(ledger)
    by_sev = {s: sum(1 for f in findings if f.get('severity') == s) for s in SEVERITIES}
    open_ = {s: sum(1 for f in findings if f.get('severity') == s and f.get('status') in (None, 'open')) for s in SEVERITIES}
    fixes = [f for f in findings if isinstance(f.get('decision'), dict) and f['decision'].get('choice') == 'fix']
    return {
        'findings': len(findings), 'by_severity': by_sev, 'open': open_,
        'decided': sum(1 for f in findings if f.get('decision')),
        'fix': len(fixes), 'fixed': sum(1 for f in fixes if f.get('status') == 'fixed'),
        'integrated': sum(1 for f in fixes if f.get('roadmap') and f.get('ticket')),
        'accepted': sum(1 for f in findings if f.get('status') == 'accepted'),
        'deferred': sum(1 for f in findings if f.get('status') == 'deferred'),
    }


def cell(text) -> str:
    return str(text if text is not None else '—').replace('|', '\\|').replace('\n', ' ')


def render_ledger(ledger: dict) -> str:
    findings = sorted(findings_of(ledger),
                      key=lambda f: (SEVERITIES.index(f['severity']) if f.get('severity') in SEVERITIES else 9, str(f.get('id', ''))))
    c = ledger_counts(ledger)
    lines = [
        f"# Release audit ledger · {ledger.get('version', '?')} ({ledger.get('run', '?')})",
        '',
        '> Generated by `wfl audit:check --render` from `ledger.json`. Do not edit this file: decisions go',
        '> through `/audit` in the cockpit or `wfl audit:sign`, fixes through `wfl audit:fixed`.',
        '',
        f"{c['findings']} findings · " + ' · '.join(f'{s} {n}' for s, n in c['by_severity'].items() if n)
        + f" · decided {c['decided']}/{c['findings']} · fixed {c['fixed']}/{c['fix']}",
        '',
        '| ID | Severity | Title | Where | Verdict | MoSCoW | Proposal | Decision | Status |',
        '|---|---|---|---|---|---|---|---|---|',
    ]
    for f in findings:
        d = f.get('decision') if isinstance(f.get('decision'), dict) else None
        decision = '—' if not d else f"{d.get('choice')} ({d.get('by', '?')}, {str(d.get('at', '?'))[:10]})"
        lines.append('| ' + ' | '.join(cell(x) for x in (
            f.get('id'), f.get('severity'), f.get('title'), f.get('where'), f.get('verdict'),
            f.get('moscow'), f.get('proposal'), decision, f.get('status'))) + ' |')
    return '\n'.join(lines) + '\n'


def load_ledger(rd: Path):
    path = rd / 'ledger.json'
    if not path.is_file():
        raise Problem(f'no ledger at {rel(path)}: the audit-triager writes it after the verification')
    return load_json(path, 'the ledger')


def cmd_check(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    m = load_manifest(rd)
    if a.for_release:
        check_version(a.for_release)
        if not covers(m['version'], a.for_release):
            raise Problem(f"the audit of {m['version']} does not cover the release {a.for_release}: an audit covers its own "
                          'release, and a final X.Y.Z is covered by one of its RCs (X.Y.Z-RCn)')
        if m['version'] != a.for_release:
            say(f"  ! the release {a.for_release} is covered by the audit of {m['version']}")
    ledger = load_ledger(rd)
    col = collect(rd, m)
    cal = calibration_result(rd, m, col)
    if a.gate and m['run'] == RELEASE_RUN:
        errors, warnings = gate_errors(m['version'])
    elif a.gate:
        errors, warnings = run_gate_errors(rd, m, ledger, col, cal)
    else:
        errors, warnings = validate(ledger, m, gate=False)
        triage, more = triage_check(rd, m, ledger, col)
        errors += run_errors(m, col, cal) + triage
        warnings += more
    if a.render and isinstance(ledger, dict):
        write_atomic(rd / 'ledger.md', render_ledger(ledger))
    counts = ledger_counts(ledger)
    if a.json:
        print(json.dumps({'run': rel(rd), 'gate': a.gate, 'ok': not errors, 'errors': errors,
                          'warnings': warnings, 'counts': counts, 'calibration': cal}, indent=2))
        return 1 if errors else 0
    say(f"ledger {rel(rd / 'ledger.json')}: {counts['findings']} findings · decided {counts['decided']} · "
        f"fixed {counts['fixed']}/{counts['fix']}" + (f" · calibration {cal['found']}/{cal['defects']} found" if cal else ''))
    for w in warnings:
        say(f'  ! {w}')
    for e in errors:
        say(f'  ✗ {e}')
    if a.render:
        say(f"  rendered {rel(rd / 'ledger.md')}")
    if errors:
        say(f"✗ audit:check {'gate ' if a.gate else ''}FAILED: {len(errors)} problem(s)")
        return 1
    say(f"✓ audit:check {'gate passed' if a.gate else 'clean'}")
    return 0


# --- status ---------------------------------------------------------------------------------------
def status_data(rd: Path) -> dict:
    m = load_manifest(rd)
    ev_done = [r['name'] for r in m['repos'] if (rd / 'evidence' / r['name'] / 'SUMMARY.md').is_file()]
    col = collect(rd, m)
    units = col['units']
    cands = col['candidates']
    v = verification_of(col)
    finals = [x for x in col['final'].values() if x]
    cal = calibration_result(rd, m, col)
    data = {
        'version': m['version'], 'run': m['run'], 'dir': rel(rd), 'scope': m['scope'], 'trimmed': m.get('trimmed') or [],
        'base': m.get('base'), 'profile': profile_label(m), 'agents': m.get('agents'), 'wave': m.get('wave', DEFAULT_WAVE),
        'evidence': {'done': len(ev_done), 'total': len(m['repos'])},
        'finders': {'done': sum(1 for u in units if u['state'] == 'done'), 'total': len(units),
                    'missing': [u['unit'] for u in units if u['state'] != 'done']},
        'candidates': len(cands),
        'verification': {'verified': len(cands) - len(v['unverified']), 'unverified': v['unverified'], 'second': v['second'],
                         'disputed': v['disputed'], 'confirmed': finals.count('CONFIRMED'),
                         'plausible': finals.count('PLAUSIBLE'), 'refuted': finals.count('REFUTED')},
        'calibration': cal, 'unparsed': col['unparsed'],
        'ledger': None, 'gate': None,
    }
    ledger = None
    if (rd / 'ledger.json').is_file():
        try:
            ledger = load_ledger(rd)
            errors, _ = validate(ledger, m, gate=False)
            errors += triage_check(rd, m, ledger, col)[0]
            data['ledger'] = {**ledger_counts(ledger), 'errors': len(errors)}
        except Problem:
            data['ledger'] = {'errors': 1, 'findings': 0}
    data['phase'], data['next'] = next_step(data, m)
    if data['phase'] == 'done' and ledger is not None:
        errors = gate_errors(m['version'])[0] if m['run'] == RELEASE_RUN else run_gate_errors(rd, m, ledger, col, cal)[0]
        data['gate'] = 'pass' if not errors else 'fail'
    return data


def next_step(d: dict, m: dict) -> tuple[str, str]:
    suffix = f" --run {m['run']}" if m['run'] != RELEASE_RUN else ''
    if d['evidence']['done'] < d['evidence']['total']:
        return 'evidence', f"wfl audit:evidence {m['version']}{suffix}"
    if d['calibration'] is not None and not d['calibration']['prepared']:
        return 'calibration', f"wfl audit:calibrate {m['version']}{suffix}"
    if d['finders']['missing']:
        return 'finders', 'dispatch the finders for: ' + ', '.join(d['finders']['missing'])
    if d['unparsed']:
        return 'finders', 'fix the headings that do not parse: ' + '; '.join(d['unparsed'])
    v = d['verification']
    if v['unverified']:
        return 'verification', f"verify {len(v['unverified'])} candidate(s) (finding-verifier)"
    if v['second']:
        return 'verification', (f"{len(v['second'])} HIGH or CRITICAL candidate(s) need their own verifier "
                                f"(wfl audit:claims {m['version']} <file> --ids <id> → verdicts/<id>.md): " + ', '.join(v['second']))
    if v['disputed']:
        return 'verification', 'break the tie with a third verifier (→ verdicts/<id>-tiebreak.md): ' + ', '.join(v['disputed'])
    led = d['ledger']
    if led is None:
        return 'triage', 'dispatch the audit-triager (ledger.json, consolidated.md, roadmap proposal)'
    if led.get('errors'):
        return 'triage', f"the ledger does not reconcile with the run: wfl audit:check {m['version']}{suffix}"
    if led['decided'] < led['findings']:
        return 'decisions', f"the maintainer decides {led['findings'] - led['decided']} finding(s): /audit in the cockpit"
    if led['integrated'] < led['fix']:
        return 'integration', 'write the approved fixes into the roadmap and the tickets (roadmap-steward)'
    if led['fixed'] < led['fix']:
        return 'closure', f"{led['fix'] - led['fixed']} fix(es) to land, fix-check and record (wfl audit:fixed)"
    return 'done', f"wfl audit:check {m['version']}{suffix} --gate"


def cmd_status(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    try:
        d = status_data(rd)
    except Problem as e:
        if a.json and (rd / 'manifest.json').is_file():
            print(json.dumps({'version': a.version or rd.parent.name, 'run': rd.name, 'dir': rel(rd),
                              'phase': 'unreadable', 'error': str(e)}, indent=2))
            return 0
        raise
    if a.json:
        print(json.dumps(d, indent=2))
        return 0
    v = d['verification']
    say(f"release audit {d['version']} · run {d['run']} · scope {d['scope']}"
        + (f" (left out: {', '.join(d['trimmed'])})" if d['trimmed'] else '') + f" · {d['dir']}")
    say(f"  agents        {agents_line(load_manifest(rd))}")
    say(f"  evidence      {d['evidence']['done']}/{d['evidence']['total']} repositories")
    say(f"  finders       {d['finders']['done']}/{d['finders']['total']} done · {d['candidates']} candidates")
    say(f"  verification  {v['verified']}/{d['candidates']} verified · {v['confirmed']} confirmed · "
        f"{v['plausible']} plausible · {v['refuted']} refuted" + (f" · {len(v['disputed'])} disputed" if v['disputed'] else '')
        + (f" · {len(v['second'])} awaiting their own verifier" if v['second'] else ''))
    cal = d['calibration']
    if cal:
        say(f"  calibration   {cal['done']}/{cal['units']} finders · {cal['found']}/{cal['defects']} known defects found"
            + ('' if cal['prepared'] else ' · not prepared'))
    led = d['ledger']
    if led:
        sev = ' · '.join(f'{s} {n}' for s, n in led.get('by_severity', {}).items() if n)
        say(f"  ledger        {led.get('findings', 0)} findings ({sev or 'none'}) · decided {led.get('decided', 0)} · "
            f"fixed {led.get('fixed', 0)}/{led.get('fix', 0)}" + (f" · gate {d['gate']}" if d['gate'] else ''))
    else:
        say('  ledger        not written yet')
    for u in d['unparsed']:
        say(f'  ! {u}: a heading that does not parse')
    say(f"  next          {d['next']}")
    return 0


def cmd_claims(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    m = load_manifest(rd)
    stem = Path(a.file).stem
    path = rd / 'candidates' / f'{stem}.md'
    if not path.is_file():
        raise Problem(f'no candidates file {rel(path)}')
    text = path.read_text(encoding='utf-8')
    if not COMPLETE.search(text):
        raise Problem(f'{rel(path)} is not complete yet (no "Status: complete" line)')
    found = parse_candidates(text)
    if a.ids:
        wanted = {i.strip() for i in a.ids.split(',') if i.strip()}
        unknown = sorted(wanted - {c['id'] for c in found})
        if unknown:
            raise Problem(f"not a candidate of {stem}: {', '.join(unknown)}")
        found = [c for c in found if c['id'] in wanted]
    shas = {r['name']: r['sha'] for r in m['repos']}
    shas[UMBRELLA] = m['umbrella']['sha']
    say(f"# Claims to verify · {stem} · {m['version']} ({m['run']})")
    say('')
    say("Each claim stands alone. The finder's evidence, reasoning, proposed fix and severity are withheld on purpose:")
    say('judge every claim against the code at the commit given, at every location, try to refute it first, and set')
    say('your own severity.')
    for c in found:
        lens = c.get('lens', '?')
        say('')
        say(f"## {c['id']}: {c['title']}")
        say(f"- lens: {lens} {LENSES.get(lens) or MODERN_LENSES.get(lens, '')}".rstrip())
        comp = c.get('component', '?')
        say(f"- component: {comp} @ {shas.get(comp, '?')}")
        say(f"- where: {c.get('where', '?')}")
        if c.get('also'):
            say(f"- also: {c['also']}")
        say(f"- claim: {c.get('claim', '?')}")
    if not found:
        say('')
        say('No candidates in this file.')
    return 0


# --- decisions --------------------------------------------------------------------------------------
def find(ledger, fid: str) -> dict:
    for f in findings_of(ledger):
        if f.get('id') == fid:
            return f
    raise Problem(f'no finding {fid} in the ledger')


def git_user() -> str:
    name = git(ROOT, 'config', 'user.name', check=False)
    return name or os.environ.get('USER', 'unknown')


def cmd_sign(a: argparse.Namespace) -> int:
    # The cockpit's /audit pane, or the maintainer's own terminal, typing the ID back. Claude's shell has no
    # terminal, and the cockpit guard refuses the command to Claude: guard rails, not a sandbox (the skill).
    via = 'cockpit' if os.environ.get('WFL_AUDIT_SIGNER') == 'cockpit' else 'terminal'
    if via == 'terminal':
        if os.environ.get('AI_AGENT', '').endswith('_agent') or os.environ.get('CLAUDECODE'):
            raise Problem("audit:sign records the maintainer's decision, so it refuses a command an AI agent runs. "
                          'Decide in the cockpit (/audit), or run it yourself in a terminal.')
        if not sys.stdin.isatty():
            raise Problem("audit:sign records the maintainer's decision: run it in your own terminal, where it asks you "
                          'to type the finding ID, or decide in the cockpit (/audit).')
    rd = resolve_run(a)
    ledger = load_ledger(rd)
    f = find(ledger, a.id)
    reason = (a.reason or '').strip()
    residual = (a.residual or '').strip()
    if a.choice in ('accept', 'post-v1') and not reason:
        raise Problem(f'a {a.choice} decision needs its reason, in quotes')
    if a.choice in ('accept', 'post-v1') and not residual:
        raise Problem(f'a {a.choice} decision needs its residual risk: --residual "what stays exposed, and to whom"')
    if a.choice == 'post-v1' and f.get('severity') == 'CRITICAL':
        raise Problem('a CRITICAL cannot move to post-v1: fix it or accept the risk')
    if via == 'terminal':
        typed = input(f'Type {a.id} to record "{a.choice}": ').strip()
        if typed != a.id:
            raise Problem('the ID typed does not match: nothing recorded')
    if f.get('decision'):
        f.setdefault('decision_history', []).append(f['decision'])
    f['decision'] = {'choice': a.choice, 'reason': reason, 'residual_risk': residual, 'by': git_user(), 'at': now(),
                     'via': via, 'subject': subject_of(f)}
    if a.choice == 'fix':
        f['status'] = 'fixed' if f.get('status') == 'fixed' else 'open'
    else:
        f['status'] = 'accepted' if a.choice == 'accept' else 'deferred'
    write_json(rd / 'ledger.json', ledger)
    write_atomic(rd / 'ledger.md', render_ledger(ledger))
    say(f"✓ {a.id}: {a.choice}" + (f' ({reason})' if reason else '') + f" · {f['decision']['by']} · {f['decision']['at']}")
    return 0


def cmd_fixed(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    m = load_manifest(rd)
    ledger = load_ledger(rd)
    f = find(ledger, a.id)
    if not isinstance(f.get('decision'), dict) or f['decision'].get('choice') != 'fix':
        raise Problem(f'{a.id} is not decided "fix": the maintainer decides first')
    if '@' not in a.commit:
        die('give the fix as <repository>@<commit>', 2)
    name, commit = a.commit.split('@', 1)
    repos = {r['name']: r for r in m['repos']}
    repos[UMBRELLA] = m['umbrella']
    if name not in repos:
        raise Problem(f"{name} is not a repository of this run ({', '.join(sorted(repos))})")
    repo = repos[name]
    where = where_of(repo)
    full = git(where, 'rev-parse', '--verify', '--quiet', f'{commit}^{{commit}}', check=False)
    if not full:
        raise Problem(f'{commit} is not a commit in {name}')
    if full == repo['sha'] or not is_ancestor(where, repo['sha'], full):
        raise Problem(f"{name}@{full[:12]} does not come after the audited commit {repo['sha'][:12]}: a fix lands after the audit")
    check = fix_check(rd, a.id)
    if check is None:
        raise Problem(f'no fix-check yet: a finding-verifier writes verdicts/fix-{a.id}.md ("### FIX {a.id} · HOLDS" and '
                      f'"- fix: {name}@{full[:12]}") first')
    if check['state'] != 'HOLDS':
        raise Problem(f'the fix-check of {a.id} FAILS: the finding stays open')
    if check['repo'] != name or not full.startswith(check['commit']):
        raise Problem(f"the fix-check verified {check['repo'] or '?'}@{check['commit'] or '?'}, not {name}@{full[:12]}")
    f['status'] = 'fixed'
    f['fixed_by'] = {'repo': name, 'commit': full, 'at': now()}
    write_json(rd / 'ledger.json', ledger)
    write_atomic(rd / 'ledger.md', render_ledger(ledger))
    say(f'✓ {a.id}: fixed by {name}@{full[:12]}')
    return 0


def cmd_required(a: argparse.Namespace) -> int:
    required = audit_required(check_version(a.version))
    say(f"{a.version}: {'the release waits for its audit' if required else 'exempt from the audit'}")
    return 0 if required else 1


# --- command line ----------------------------------------------------------------------------------
def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog='wfl audit', description=__doc__.split('\n\n')[0])
    sub = p.add_subparsers(dest='cmd', required=True)

    def add(name: str, help_: str, version_optional: bool = False) -> argparse.ArgumentParser:
        sp = sub.add_parser(name, help=help_)
        if version_optional:
            sp.add_argument('version', nargs='?')
            sp.add_argument('--latest', action='store_true', help='the run created last')
        else:
            sp.add_argument('version')
        sp.add_argument('--run', default=RELEASE_RUN, help=f'run name (default {RELEASE_RUN})')
        return sp

    sp = add('init', 'create the run folder and its manifest')
    sp.add_argument('--only', help='comma-separated repositories (a partial run)')
    sp.add_argument('--base', help='a diff-scoped run over --only: the release whose audit it builds on (e.g. 0.1.0-beta8)')
    sp.add_argument('--no-gateway', action='store_true', help='leave the EcoShield gateway out of a full run (trimmed)')
    sp.add_argument('--with-agentic', action='store_true', help='add the AG lens to a partial run')
    sp.add_argument('--no-agentic', action='store_true', help='leave the AG lens out of a full run (trimmed)')
    sp.add_argument('--with-calibration', action='store_true', help='add the calibration to a partial run')
    sp.add_argument('--no-calibration', action='store_true', help='leave the calibration out of a full run (trimmed)')
    sp.add_argument('--bundle', dest='bundle', action='store_const', const=True, default=None,
                    help='bundle the core security lenses into three finders')
    sp.add_argument('--no-bundle', dest='bundle', action='store_const', const=False,
                    help='one finder per lens, even for a small scope')
    sp.add_argument('--allow-dirty', action='store_true', help='audit uncommitted changes (say so in the report)')
    sp.add_argument('--force', action='store_true', help='start over: the existing run moves aside to <run>.<time>/')

    def who(parser_: argparse.ArgumentParser, default_profile: str | None) -> None:
        parser_.add_argument('--profile', default=default_profile, help=f"{' | '.join(PROFILES)} (default {DEFAULT_PROFILE})")
        parser_.add_argument('--model', help='per role, e.g. finder=sonnet,verifier=opus (a bare value sets every role)')
        parser_.add_argument('--effort', help='per role, e.g. finder=medium (low, medium, high, xhigh, max)')
        parser_.add_argument('--wave', type=int, default=None if default_profile is None else DEFAULT_WAVE,
                             help=f'agents running at once (default {DEFAULT_WAVE})')

    who(sp, DEFAULT_PROFILE)
    sp.set_defaults(fn=cmd_init)

    sp = add('profile', "change who runs an existing run's agents from now on", version_optional=True)
    who(sp, None)
    sp.set_defaults(fn=cmd_profile)

    sp = add('evidence', 'run the automated tools and keep their output', version_optional=True)
    sp.add_argument('repos', nargs='*', help='only these repositories (and umbrella for the AI layer)')
    sp.set_defaults(fn=cmd_evidence)

    sp = add('calibrate', 'the calibration snapshots: known defects on their pre-fix trees', version_optional=True)
    sp.set_defaults(fn=cmd_calibrate)

    sp = add('status', 'progress and the next step', version_optional=True)
    sp.add_argument('--json', action='store_true')
    sp.set_defaults(fn=cmd_status)

    sp = add('claims', "a candidates file's claims, without the finder's reasoning", version_optional=True)
    sp.add_argument('file', help='the candidates file, e.g. S-A05 or candidates/S-A05.md')
    sp.add_argument('--ids', help='only these candidate ids (comma-separated)')
    sp.set_defaults(fn=cmd_claims)

    sp = add('check', 'validate ledger.json against the run', version_optional=True)
    sp.add_argument('--gate', action='store_true', help='release gate: complete, reconciled, decided, fixed, covered')
    sp.add_argument('--for', dest='for_release', help='the release being tagged, when another audit covers it (Gold: its RC)')
    sp.add_argument('--render', action='store_true', help='also write ledger.md')
    sp.add_argument('--json', action='store_true')
    sp.set_defaults(fn=cmd_check)

    sp = add('sign', "record the maintainer's decision on one finding")
    sp.add_argument('id')
    sp.add_argument('choice', choices=CHOICES)
    sp.add_argument('reason', nargs='?', default='')
    sp.add_argument('--residual', default='', help='accept and post-v1: the residual risk (what stays exposed, and to whom)')
    sp.set_defaults(fn=cmd_sign)

    sp = add('fixed', 'record the commit that fixed a finding')
    sp.add_argument('id')
    sp.add_argument('commit', help='<repository>@<commit>')
    sp.set_defaults(fn=cmd_fixed)

    sp = sub.add_parser('required', help='whether a release waits for its audit (exit 0) or is exempt (exit 1)')
    sp.add_argument('version')
    sp.set_defaults(fn=cmd_required)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        return args.fn(args)
    except Problem as e:
        print(f'✗ {e}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
