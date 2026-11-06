#!/usr/bin/env python3
"""wfl audit:* — the deterministic side of the release audit (the `release-audit` skill drives the agents).

Every subcommand takes the release the audit is for (0.1.0-beta8, 1.0.0-RC1 …) and works in
project_system/Audits/<Beta8|RC1|version>/<run>/ (gitignored, local only). --run defaults to release-audit.

  init      the run folder, its manifest (each repository's commit, the toolchain) and the split
            of the work across agents
  evidence  run the automated tools once per repository and keep their output (report-only, never a gate)
  status    what is done and what comes next; --json for the cockpit; --latest picks the newest run
  claims    a candidates file's claims without the finder's reasoning, for a blind verifier
  check     validate ledger.json; --gate also fails on an undecided finding, an unfixed "fix" or a
            deferred CRITICAL; --render writes ledger.md
  sign      record the maintainer's decision on one finding (fix | accept | post-v1). It refuses a
            command an AI agent runs: the sign-off is the maintainer's.
  fixed     record the commit that fixed a finding, once a finding-verifier confirmed the fix

Exit: 0 ok · 1 a problem was found · 2 usage error.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTAINER = os.environ.get('WFL_CONTAINER', 'waffle-dev')
GATEWAY_NAME = 'ecoshield-gateway'
GATEWAY_PATH = 'contributions/ecoshield-gateway'
UMBRELLA = 'umbrella'
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

# Security: the OWASP Top 10:2025 categories plus two Waffle lenses (beta6 swept the same twelve).
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
    'AG': 'Agentic layer (OWASP Top 10 for Agentic Applications 2026)',
}
CORE_LENSES = [k for k in LENSES if k != 'AG']
# A scope of three repositories or fewer bundles the twelve lenses into three finders (a pilot stays cheap).
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
METRIC_RULES = ('cyclomatic-complexity,excessive-nesting,excessive-parameter-list,halstead,'
                'kan-defect,too-many-methods,too-many-properties')

CANDIDATE_HEAD = re.compile(r'^### ([SM]-[A-Za-z0-9-]+?-\d{2,3}) · (' + '|'.join(SEVERITIES) + r') · (.+?)\s*$', re.M)
VERDICT_HEAD = re.compile(r'^### ([SM]-[A-Za-z0-9-]+?-\d{2,3}) · (' + '|'.join(VERDICTS) + r') · ('
                          + '|'.join(SEVERITIES) + r')\s*$', re.M)
FIELD = re.compile(r'^- ([a-z-]+): (.*)$', re.M)
COMPLETE = re.compile(r'^Status:\s*complete\s*$', re.M)
WHERE = re.compile(r'^(.+?):(\d+)(?:-(\d+))?$')


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


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f'.{path.name}.tmp')
    tmp.write_text(text, encoding='utf-8')
    os.replace(tmp, path)


def write_json(path: Path, data: dict) -> None:
    write_atomic(path, json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def check_version(version: str) -> str:
    if version.startswith('v'):
        die(f"a version never carries a 'v' prefix (got '{version}')", 2)
    if not re.fullmatch(r'\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?', version):
        die(f"'{version}' is not a release version such as 0.1.0-beta8 or 1.0.0-RC1", 2)
    return version


def version_dir(version: str) -> str:
    m = re.fullmatch(r'0\.1\.0-beta(\d+)', version)
    if m:
        return f'Beta{m.group(1)}'
    m = re.fullmatch(r'1\.0\.0-RC(\d+)', version)
    if m:
        return f'RC{m.group(1)}'
    return version


def run_dir(version: str, run: str) -> Path:
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', run):
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
    return json.loads(path.read_text(encoding='utf-8'))


def latest_run() -> Path:
    manifests = sorted((ROOT / 'project_system' / 'Audits').glob('*/*/manifest.json'),
                       key=lambda p: p.stat().st_mtime)
    if not manifests:
        raise Problem('no release audit run yet: `wfl audit:init <version>` starts one')
    return manifests[-1].parent


def resolve_run(args: argparse.Namespace) -> Path:
    if getattr(args, 'latest', False):
        return latest_run()
    if not args.version:
        die('give the release version (or --latest)', 2)
    return run_dir(check_version(args.version), args.run)


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
    m.setdefault('profile_history', []).append({'at': now(), 'profile': m.get('profile'), 'agents': m.get('agents'),
                                                'wave': m.get('wave')})
    m['profile'], m['agents'], m['wave'] = base, agents, a.wave or m.get('wave', DEFAULT_WAVE)
    write_json(rd / 'manifest.json', m)
    write_atomic(rd / 'MANIFEST.md', render_manifest(m))
    say(f'✓ {rel(rd)}: {agents_line(m)} (agents dispatched from now on)')
    return 0


# --- init -------------------------------------------------------------------------------
def security_units(repo_count: int, bundle: bool | None, agentic: bool) -> list[dict]:
    use_bundles = repo_count <= BUNDLE_MAX_REPOS if bundle is None else bundle
    if use_bundles:
        units = [{'id': b, 'lenses': lenses} for b, lenses in BUNDLES.items()]
    else:
        units = [{'id': lens, 'lenses': [lens]} for lens in CORE_LENSES]
    if agentic:
        units.append({'id': 'AG', 'lenses': ['AG'], 'scope': UMBRELLA})
    return units


def cmd_init(a: argparse.Namespace) -> int:
    version = check_version(a.version)
    rd = run_dir(version, a.run)
    if (rd / 'manifest.json').exists() and not a.force:
        raise Problem(f'{rel(rd)} already has a manifest: resume it (`wfl audit:status {version}'
                      + (f' --run {a.run}' if a.run != 'release-audit' else '') + '`) or start over with --force')
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
    gateway = (ROOT / GATEWAY_PATH / 'composer.json').is_file() and (
        GATEWAY_NAME in only or (not only and not a.no_gateway))
    agentic = a.with_agentic or (not only and not a.no_agentic)

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
    units = security_units(len(repos), a.bundle, agentic)
    modern = [{'id': g, 'repos': [n for n in names if n in selected]} for g, names in GROUPS.items()]
    modern = [u for u in modern if u['repos']]
    if gateway:
        modern.append({'id': 'gateway', 'repos': [GATEWAY_NAME]})
    manifest = {
        'schema': 1,
        'version': version,
        'run': a.run,
        'created': now(),
        'scope': 'partial' if only else 'full',
        'umbrella': umbrella,
        'repos': repos,
        'toolchain': toolchain(),
        'profile': a.profile,
        'agents': agents,
        'wave': a.wave,
        'security_units': units,
        'modernization_units': modern,
    }
    for sub in ('candidates', 'verdicts', 'evidence'):
        (rd / sub).mkdir(parents=True, exist_ok=True)
    write_json(rd / 'manifest.json', manifest)
    write_atomic(rd / 'MANIFEST.md', render_manifest(manifest))
    stale = [r['name'] for r in repos if r['pin_matches'] is False]
    say(f'✓ {rel(rd)}: {len(repos)} repositories, {len(units)} security and {len(modern)} modernization finders')
    say(f'  agents: {agents_line(manifest)}')
    if stale:
        say(f'  ! {", ".join(stale)}: the checked-out commit differs from the umbrella pin (the manifest records both)')
    if dirty:
        say(f'  ! audited with uncommitted changes in {", ".join(dirty)}')
    say(f'  next: wfl audit:evidence {version}' + (f' --run {a.run}' if a.run != 'release-audit' else ''))
    return 0


def render_manifest(m: dict) -> str:
    tc = m['toolchain']
    lines = [
        f"# Release audit manifest · {m['version']} ({m['run']})",
        '',
        f"Created {m['created']} · scope {m['scope']} · umbrella `{m['umbrella']['sha'][:12]}` on "
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
        lines.append(f"- `S-{u['id']}`: {names}" + (' (scope: the umbrella)' if u.get('scope') == UMBRELLA else ''))
    for u in m['modernization_units']:
        lines.append(f"- `M-{u['id']}`: {', '.join(u['repos'])}")
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
            rows.append((issue.get('code', '?'), f"{name}:{span.get('start', {}).get('line', '?')}", ann.get('message', '')))
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
    if wanted - {r['name'] for r in m['repos']}:
        raise Problem(f"not in this run's manifest: {', '.join(sorted(wanted - {r['name'] for r in m['repos']}))}")
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
            + [('modernization', f"M-{u['id']}") for u in m['modernization_units']])


def collect(rd: Path, m: dict) -> dict:
    units = []
    candidates: dict[str, dict] = {}
    for phase, stem in unit_files(m):
        path = rd / 'candidates' / f'{stem}.md'
        text = path.read_text(encoding='utf-8') if path.is_file() else ''
        complete = bool(COMPLETE.search(text))
        found = parse_candidates(text) if complete else []
        for c in found:
            candidates[c['id']] = {**c, 'file': stem, 'phase': phase}
        units.append({'unit': stem, 'phase': phase, 'state': 'done' if complete else ('partial' if text else 'missing'),
                      'candidates': len(found)})
    verdicts: dict[str, list[dict]] = {}
    for path in sorted((rd / 'verdicts').glob('*.md')):
        text = path.read_text(encoding='utf-8')
        if not COMPLETE.search(text):
            continue
        for v in parse_verdicts(text):
            verdicts.setdefault(v['id'], []).append({**v, 'file': path.stem})
    final = {cid: final_verdict([v['verdict'] for v in verdicts.get(cid, [])]) for cid in candidates}
    return {'units': units, 'candidates': candidates, 'verdicts': verdicts, 'final': final}


# --- ledger -------------------------------------------------------------------------------------
def repo_for(where_path: str, m: dict) -> dict | None:
    best = None
    for r in m['repos']:
        if where_path.startswith(r['path'] + '/') and (best is None or len(r['path']) > len(best['path'])):
            best = r
    return best or m['umbrella']


def file_lines(repo: dict, relpath: str) -> int | None:
    where = ROOT / repo['path'] if repo['path'] else ROOT
    run = subprocess.run(['git', '-C', str(where), 'show', f"{repo['sha']}:{relpath}"], capture_output=True)
    if run.returncode != 0:
        return None
    return run.stdout.count(b'\n') + (0 if run.stdout.endswith(b'\n') or not run.stdout else 1)


def validate(ledger: dict, m: dict, gate: bool) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    findings = ledger.get('findings')
    if not isinstance(findings, list):
        return ['ledger.json has no "findings" list'], warnings
    seen = set()
    for i, f in enumerate(findings):
        fid = f.get('id') or f'#{i + 1}'
        where = f'{fid}'
        for key in REQUIRED:
            if f.get(key) in (None, ''):
                errors.append(f'{where}: "{key}" is missing')
        if fid in seen:
            errors.append(f'{where}: duplicate id')
        seen.add(fid)
        for key, allowed in (('severity', SEVERITIES), ('verdict', ['CONFIRMED', 'PLAUSIBLE']), ('moscow', MOSCOW),
                             ('proposal', CHOICES), ('status', STATUSES), ('phase', PHASES)):
            if f.get(key) not in (None, '') and f.get(key) not in allowed:
                errors.append(f'{where}: {key} "{f.get(key)}" is not one of {", ".join(allowed)}')
        if f.get('lens') and f.get('phase') == 'security' and f['lens'] not in LENSES:
            errors.append(f'{where}: lens "{f["lens"]}" is not a security lens')
        loc = WHERE.match(str(f.get('where') or ''))
        if f.get('where') and not loc:
            errors.append(f'{where}: where "{f["where"]}" is not path:line')
        elif loc:
            repo = repo_for(loc.group(1), m)
            relpath = loc.group(1)[len(repo['path']) + 1:] if repo['path'] else loc.group(1)
            count = file_lines(repo, relpath)
            if count is None:
                errors.append(f"{where}: {loc.group(1)} does not exist at {repo['name']}@{repo['sha'][:12]}")
            elif int(loc.group(3) or loc.group(2)) > count:
                errors.append(f"{where}: line {loc.group(3) or loc.group(2)} is past the end of {loc.group(1)} ({count} lines)")
            if f.get('component') and repo['name'] != f['component'] and repo['name'] != UMBRELLA:
                warnings.append(f"{where}: component is {f['component']} but the path belongs to {repo['name']}")
        decision = f.get('decision')
        status = f.get('status')
        if decision is not None:
            if not isinstance(decision, dict) or decision.get('choice') not in CHOICES:
                errors.append(f'{where}: decision must be {{choice, reason, by, at}} with choice {", ".join(CHOICES)}')
            else:
                for key in ('by', 'at'):
                    if not decision.get(key):
                        errors.append(f'{where}: the decision has no "{key}" (record it with `wfl audit:sign`)')
                if decision['choice'] in ('accept', 'post-v1') and not (decision.get('reason') or '').strip():
                    errors.append(f"{where}: a {decision['choice']} decision needs its reason")
                expected = {'fix': ('open', 'fixed'), 'accept': ('accepted',), 'post-v1': ('deferred',)}[decision['choice']]
                if status not in expected:
                    errors.append(f"{where}: status {status} does not match the decision {decision['choice']}")
                if decision['choice'] == 'post-v1' and f.get('severity') == 'CRITICAL':
                    errors.append(f'{where}: a CRITICAL cannot move to post-v1: fix it or accept the risk')
        elif status not in (None, 'open'):
            errors.append(f'{where}: status {status} without a decision')
        if status == 'fixed':
            fb = f.get('fixed_by') or {}
            if not fb.get('repo') or not fb.get('commit'):
                errors.append(f'{where}: fixed without fixed_by (record it with `wfl audit:fixed`)')
        if gate:
            if decision is None:
                errors.append(f'{where}: no decision yet')
            elif decision.get('choice') == 'fix' and status != 'fixed':
                errors.append(f'{where}: decided "fix" but not fixed yet')
        elif decision and decision.get('choice') == 'fix' and not (f.get('roadmap') and f.get('ticket')):
            warnings.append(f'{where}: decided "fix" but has no roadmap item or ticket yet')
        if f.get('verdict') == 'PLAUSIBLE':
            warnings.append(f'{where}: PLAUSIBLE, not CONFIRMED')
    return errors, warnings


def ledger_counts(ledger: dict) -> dict:
    findings = ledger.get('findings') or []
    by_sev = {s: sum(1 for f in findings if f.get('severity') == s) for s in SEVERITIES}
    open_ = {s: sum(1 for f in findings if f.get('severity') == s and f.get('status') in (None, 'open')) for s in SEVERITIES}
    fixes = [f for f in findings if (f.get('decision') or {}).get('choice') == 'fix']
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
    findings = sorted(ledger.get('findings') or [],
                      key=lambda f: (SEVERITIES.index(f['severity']) if f.get('severity') in SEVERITIES else 9, f.get('id', '')))
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
        d = f.get('decision')
        decision = '—' if not d else f"{d.get('choice')} ({d.get('by', '?')}, {str(d.get('at', '?'))[:10]})"
        lines.append('| ' + ' | '.join(cell(x) for x in (
            f.get('id'), f.get('severity'), f.get('title'), f.get('where'), f.get('verdict'),
            f.get('moscow'), f.get('proposal'), decision, f.get('status'))) + ' |')
    return '\n'.join(lines) + '\n'


def load_ledger(rd: Path) -> dict:
    path = rd / 'ledger.json'
    if not path.is_file():
        raise Problem(f'no ledger at {rel(path)}: the audit-triager writes it after the verification')
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except ValueError as e:
        raise Problem(f'{rel(path)} is not valid JSON ({e})') from e


def cmd_check(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    m = load_manifest(rd)
    ledger = load_ledger(rd)
    errors, warnings = validate(ledger, m, a.gate)
    if a.render:
        write_atomic(rd / 'ledger.md', render_ledger(ledger))
    counts = ledger_counts(ledger)
    if a.json:
        print(json.dumps({'run': rel(rd), 'gate': a.gate, 'ok': not errors, 'errors': errors,
                          'warnings': warnings, 'counts': counts}, indent=2))
        return 1 if errors else 0
    say(f"ledger {rel(rd / 'ledger.json')}: {counts['findings']} findings · decided {counts['decided']} · "
        f"fixed {counts['fixed']}/{counts['fix']}")
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
    finders_done = [u for u in units if u['state'] == 'done']
    cands = col['candidates']
    unverified = sorted(cid for cid in cands if not col['verdicts'].get(cid))
    disputed = sorted(cid for cid in cands if col['verdicts'].get(cid) and col['final'][cid] is None)
    finals = [v for v in col['final'].values() if v]
    data = {
        'version': m['version'], 'run': m['run'], 'dir': rel(rd), 'scope': m['scope'],
        'profile': profile_label(m), 'agents': m.get('agents'), 'wave': m.get('wave', DEFAULT_WAVE),
        'evidence': {'done': len(ev_done), 'total': len(m['repos'])},
        'finders': {'done': len(finders_done), 'total': len(units),
                    'missing': [u['unit'] for u in units if u['state'] != 'done']},
        'candidates': len(cands),
        'verification': {'verified': len(cands) - len(unverified), 'unverified': unverified, 'disputed': disputed,
                         'confirmed': finals.count('CONFIRMED'), 'plausible': finals.count('PLAUSIBLE'),
                         'refuted': finals.count('REFUTED')},
        'ledger': None, 'gate': None,
    }
    ledger_path = rd / 'ledger.json'
    if ledger_path.is_file():
        try:
            ledger = json.loads(ledger_path.read_text(encoding='utf-8'))
            errors, _ = validate(ledger, m, gate=False)
            gate_errors, _ = validate(ledger, m, gate=True)
            data['ledger'] = {**ledger_counts(ledger), 'errors': len(errors)}
            data['gate'] = 'pass' if not gate_errors else 'fail'
        except ValueError:
            data['ledger'] = {'errors': 1, 'findings': 0}
            data['gate'] = 'fail'
    data['phase'], data['next'] = next_step(data, m)
    return data


def next_step(d: dict, m: dict) -> tuple[str, str]:
    suffix = f" --run {m['run']}" if m['run'] != 'release-audit' else ''
    if d['evidence']['done'] < d['evidence']['total']:
        return 'evidence', f"wfl audit:evidence {m['version']}{suffix}"
    if d['finders']['missing']:
        return 'finders', 'dispatch the finders for: ' + ', '.join(d['finders']['missing'])
    if d['verification']['unverified']:
        return 'verification', f"verify {len(d['verification']['unverified'])} candidate(s) (finding-verifier)"
    if d['verification']['disputed']:
        return 'verification', 'tie-break with a second verifier: ' + ', '.join(d['verification']['disputed'])
    led = d['ledger']
    if led is None:
        return 'triage', 'dispatch the audit-triager (ledger.json, consolidated.md, roadmap proposal)'
    if led.get('errors'):
        return 'triage', f"fix ledger.json: wfl audit:check {m['version']}{suffix}"
    if led['decided'] < led['findings']:
        return 'decisions', f"the maintainer decides {led['findings'] - led['decided']} finding(s): /audit in the cockpit"
    if led['integrated'] < led['fix']:
        return 'integration', 'write the approved fixes into the roadmap and the tickets (roadmap-steward)'
    if led['fixed'] < led['fix']:
        return 'closure', f"{led['fix'] - led['fixed']} fix(es) to land, verify and record (wfl audit:fixed)"
    return 'done', f"wfl audit:check {m['version']}{suffix} --gate"


def cmd_status(a: argparse.Namespace) -> int:
    rd = resolve_run(a)
    d = status_data(rd)
    if a.json:
        print(json.dumps(d, indent=2))
        return 0
    v = d['verification']
    say(f"release audit {d['version']} · run {d['run']} · scope {d['scope']} · {d['dir']}")
    say(f"  agents        {agents_line(load_manifest(rd))}")
    say(f"  evidence      {d['evidence']['done']}/{d['evidence']['total']} repositories")
    say(f"  finders       {d['finders']['done']}/{d['finders']['total']} done · {d['candidates']} candidates")
    say(f"  verification  {v['verified']}/{d['candidates']} verified · {v['confirmed']} confirmed · "
        f"{v['plausible']} plausible · {v['refuted']} refuted" + (f" · {len(v['disputed'])} disputed" if v['disputed'] else ''))
    led = d['ledger']
    if led:
        sev = ' · '.join(f'{s} {n}' for s, n in led.get('by_severity', {}).items() if n)
        say(f"  ledger        {led.get('findings', 0)} findings ({sev or 'none'}) · decided {led.get('decided', 0)} · "
            f"fixed {led.get('fixed', 0)}/{led.get('fix', 0)} · gate {d['gate']}")
    else:
        say('  ledger        not written yet')
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
        wanted = set(a.ids.split(','))
        found = [c for c in found if c['id'] in wanted]
    shas = {r['name']: r['sha'] for r in m['repos']}
    shas[UMBRELLA] = m['umbrella']['sha']
    say(f"# Claims to verify · {stem} · {m['version']} ({m['run']})")
    say('')
    say("Each claim stands alone. The finder's evidence, reasoning, proposed fix and severity are withheld on purpose:")
    say('judge every claim against the code at the commit given, try to refute it first, and set your own severity.')
    for c in found:
        lens = c.get('lens', '?')
        say('')
        say(f"## {c['id']}: {c['title']}")
        say(f"- lens: {lens} {LENSES.get(lens, '')}".rstrip())
        comp = c.get('component', '?')
        say(f"- component: {comp} @ {shas.get(comp, '?')}")
        say(f"- where: {c.get('where', '?')}")
        say(f"- claim: {c.get('claim', '?')}")
    if not found:
        say('')
        say('No candidates in this file.')
    return 0


# --- decisions --------------------------------------------------------------------------------------
def find(ledger: dict, fid: str) -> dict:
    for f in ledger.get('findings') or []:
        if f.get('id') == fid:
            return f
    raise Problem(f'no finding {fid} in the ledger')


def git_user() -> str:
    name = git(ROOT, 'config', 'user.name', check=False)
    return name or os.environ.get('USER', 'unknown')


def cmd_sign(a: argparse.Namespace) -> int:
    agent = os.environ.get('AI_AGENT', '')
    if agent.endswith('_agent') and os.environ.get('WFL_AUDIT_SIGNER') != 'cockpit':
        raise Problem('audit:sign records the maintainer\'s decision, so it refuses a command an AI agent runs. '
                      'Decide in the cockpit (/audit), or run it yourself in a terminal.')
    rd = resolve_run(a)
    ledger = load_ledger(rd)
    f = find(ledger, a.id)
    reason = (a.reason or '').strip()
    if a.choice in ('accept', 'post-v1') and not reason:
        raise Problem(f'a {a.choice} decision needs its reason, in quotes')
    if a.choice == 'post-v1' and f.get('severity') == 'CRITICAL':
        raise Problem('a CRITICAL cannot move to post-v1: fix it or accept the risk')
    if f.get('decision'):
        f.setdefault('decision_history', []).append(f['decision'])
    f['decision'] = {'choice': a.choice, 'reason': reason, 'by': git_user(), 'at': now()}
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
    if (f.get('decision') or {}).get('choice') != 'fix':
        raise Problem(f'{a.id} is not decided "fix": the maintainer decides first')
    if '@' not in a.commit:
        die('give the fix as <repository>@<commit>', 2)
    name, commit = a.commit.split('@', 1)
    repos = {r['name']: r for r in m['repos']}
    repos[UMBRELLA] = m['umbrella']
    if name not in repos:
        raise Problem(f"{name} is not a repository of this run ({', '.join(sorted(repos))})")
    repo = repos[name]
    full = git(ROOT / repo['path'] if repo['path'] else ROOT, 'rev-parse', '--verify', f'{commit}^{{commit}}', check=False)
    if not full:
        raise Problem(f'{commit} is not a commit in {name}')
    f['status'] = 'fixed'
    f['fixed_by'] = {'repo': name, 'commit': full, 'at': now()}
    write_json(rd / 'ledger.json', ledger)
    write_atomic(rd / 'ledger.md', render_ledger(ledger))
    say(f'✓ {a.id}: fixed by {name}@{full[:12]}')
    return 0


# --- command line ----------------------------------------------------------------------------------
def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog='wfl audit', description=__doc__.split('\n\n')[0])
    sub = p.add_subparsers(dest='cmd', required=True)

    def add(name: str, help_: str, version_optional: bool = False) -> argparse.ArgumentParser:
        sp = sub.add_parser(name, help=help_)
        if version_optional:
            sp.add_argument('version', nargs='?')
            sp.add_argument('--latest', action='store_true', help='the most recently created run')
        else:
            sp.add_argument('version')
        sp.add_argument('--run', default='release-audit', help='run name (default release-audit)')
        return sp

    sp = add('init', 'create the run folder and its manifest')
    sp.add_argument('--only', help='comma-separated repositories (a partial run)')
    sp.add_argument('--no-gateway', action='store_true', help='leave the EcoShield gateway out of a full run')
    sp.add_argument('--with-agentic', action='store_true', help='add the AG lens to a partial run')
    sp.add_argument('--no-agentic', action='store_true', help='leave the AG lens out of a full run')
    sp.add_argument('--bundle', dest='bundle', action='store_const', const=True, default=None,
                    help='bundle the security lenses into three finders')
    sp.add_argument('--no-bundle', dest='bundle', action='store_const', const=False,
                    help='one finder per lens, even for a small scope')
    sp.add_argument('--allow-dirty', action='store_true')
    sp.add_argument('--force', action='store_true', help='overwrite an existing manifest')

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

    sp = add('status', 'progress and the next step', version_optional=True)
    sp.add_argument('--json', action='store_true')
    sp.set_defaults(fn=cmd_status)

    sp = add('claims', "a candidates file's claims, without the finder's reasoning", version_optional=True)
    sp.add_argument('file', help='the candidates file, e.g. S-A05 or candidates/S-A05.md')
    sp.add_argument('--ids', help='only these candidate ids (comma-separated)')
    sp.set_defaults(fn=cmd_claims)

    sp = add('check', 'validate ledger.json', version_optional=True)
    sp.add_argument('--gate', action='store_true', help='release gate: every finding decided, every fix landed')
    sp.add_argument('--render', action='store_true', help='also write ledger.md')
    sp.add_argument('--json', action='store_true')
    sp.set_defaults(fn=cmd_check)

    sp = add('sign', "record the maintainer's decision on one finding")
    sp.add_argument('id')
    sp.add_argument('choice', choices=CHOICES)
    sp.add_argument('reason', nargs='?', default='')
    sp.set_defaults(fn=cmd_sign)

    sp = add('fixed', 'record the commit that fixed a finding')
    sp.add_argument('id')
    sp.add_argument('commit', help='<repository>@<commit>')
    sp.set_defaults(fn=cmd_fixed)
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
