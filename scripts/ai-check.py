#!/usr/bin/env python3
"""wfl ai:check — lint the Claude Code operating layer of waffle-commons.

What it checks:
  skills      .claude/skills/*/SKILL.md: name = directory, short description,
              a when_to_use, known keys only, at most 500 body lines
  agents      .claude/agents/*.md: name = file, a "Use …" description, known keys
              only, preloaded skills exist, the tool policy below holds
  references  in the skills, agents and instruction/doc files: `wfl <sub>` exists,
              RFC-NNN exists, backticked repo paths exist, `x` skill / [[x]] resolve
  runtimes    no opencode / Antigravity left in the live files (history excluded)
  plugins     the repo marketplace, the vendored mattpocock-skills pin and curation
  settings    .claude/settings.json enables what the marketplace lists
  scripts     scripts/tests/test_*.py, the unit tests of the wfl helpers, pass
  claude      `claude plugin validate --strict` + `claude plugin test` (skipped with
              --no-claude or when the CLI is absent, e.g. in CI)

Usage: scripts/ai-check.py [--no-claude]     Exit: 0 clean, 1 on any error.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
os.chdir(ROOT)

SKILL_KEYS = {
    'name', 'description', 'when_to_use', 'argument-hint', 'arguments', 'disable-model-invocation',
    'user-invocable', 'allowed-tools', 'disallowed-tools', 'model', 'effort', 'context', 'agent',
    'background', 'hooks', 'paths', 'shell', 'metadata', 'license', 'compatibility',
}
AGENT_KEYS = {
    'name', 'description', 'tools', 'disallowedTools', 'model', 'permissionMode', 'maxTurns', 'skills',
    'mcpServers', 'hooks', 'memory', 'background', 'omitClaudeMd', 'effort', 'isolation', 'color',
    'initialPrompt', 'experimental',
}
# Tool policy: what each agent's body promises, enforced by its frontmatter.
READ_ONLY = {'acceptance-verifier', 'aot-verifier', 'bc-reviewer', 'flake-hunter', 'gate-runner'}
REPORT_WRITERS = {'benchmark-runner', 'chaos-runner', 'soak-analyst'}
# Skills the vendored plugin must never ship (see its VENDORED.md).
MP_EXCLUDED = {'implement', 'implement-spec', 'triage', 'wayfinder', 'prototype', 'setup-matt-pocock-skills', 'code-review'}
# Paths that live outside this checkout on purpose.
EXTERNAL_PATHS = {
    'bin/waffle',                     # the console entry of an app (skeleton/, workspace/)
    '.github/workflows/main.yml',     # the EcoShield gateway repository's CI
    'bench/scripts/perf-report.py',   # gateway repository
    'bench/drift.py',                 # gateway repository
}
EXTERNAL_PREFIXES = ('project_system/Audits/', 'project_system/Notes/', 'project_system/TODOs/', 'contributions/')
PATH_ROOTS = ('scripts', 'bin', 'project_system', 'docs', 'documentation', '.claude', '.claude-plugin', '.github',
              'bench', 'workspace', 'skeleton', 'academy', 'component-template')
REMOVED = re.compile(r'opencode|antigravity|\.agents/', re.I)

errors = []
notes = []


def err(where, msg):
    errors.append(f'{where}: {msg}')


# --- frontmatter --------------------------------------------------------------
def frontmatter(path):
    text = open(path, encoding='utf-8').read()
    m = re.match(r'^---\n(.*?)\n---\n?(.*)$', text, re.S)
    if not m:
        return None, text
    fm, key, block = {}, None, None
    for line in m.group(1).split('\n'):
        if block is not None:
            if line.startswith('  ') or line == '':
                fm[key] = (fm[key] + ' ' + line.strip()).strip()
                continue
            block = None
        if key is not None and isinstance(fm.get(key), list) and re.match(r'^\s+- ', line):
            fm[key].append(line.strip()[2:].strip())
            continue
        mm = re.match(r'^([A-Za-z_-]+):\s*(.*)$', line)
        if not mm:
            continue
        key, value = mm.group(1), mm.group(2).strip()
        if value in ('>-', '>', '|', '|-'):
            fm[key], block = '', True
        elif value == '':
            fm[key] = []
        else:
            fm[key] = value[1:-1].replace('\\"', '"') if len(value) > 1 and value[0] == value[-1] == '"' else value
    return fm, m.group(2)


skills = {}
for path in sorted(glob.glob('.claude/skills/*/SKILL.md')):
    name = os.path.basename(os.path.dirname(path))
    fm, body = frontmatter(path)
    skills[name] = path
    if fm is None:
        err(path, 'no frontmatter')
        continue
    if fm.get('name') != name:
        err(path, f"name '{fm.get('name')}' differs from the directory")
    if not re.fullmatch(r'[a-z0-9]+(-[a-z0-9]+)*', name):
        err(path, 'name is not lowercase-hyphenated')
    desc, wtu = fm.get('description') or '', fm.get('when_to_use') or ''
    if not desc:
        err(path, 'no description')
    elif len(desc) > 160:
        err(path, f'description is {len(desc)} chars (keep it under 160; put triggers in when_to_use)')
    if not wtu:
        err(path, 'no when_to_use (the trigger phrases)')
    if len(desc) + len(wtu) > 1536:
        err(path, 'description + when_to_use exceed the 1,536-character listing cap')
    for k in set(fm) - SKILL_KEYS:
        err(path, f"unknown frontmatter key '{k}'")
    if body.count('\n') > 500:
        err(path, f'body is {body.count(chr(10))} lines (keep SKILL.md under 500; move detail to a reference file)')

agents = {}
for path in sorted(glob.glob('.claude/agents/*.md')):
    name = os.path.basename(path)[:-3]
    fm, body = frontmatter(path)
    agents[name] = path
    if fm is None:
        err(path, 'no frontmatter')
        continue
    if fm.get('name') != name:
        err(path, f"name '{fm.get('name')}' differs from the file name (Claude Code registers agents by name)")
    desc = fm.get('description') or ''
    if not desc.startswith('Use '):
        err(path, 'description should start with "Use …" (Claude delegates on it)')
    for k in set(fm) - AGENT_KEYS:
        err(path, f"unknown frontmatter key '{k}'" + (' (an opencode key)' if k in ('mode', 'hidden') else ''))
    for s in fm.get('skills') or []:
        if s not in skills:
            err(path, f"preloads unknown skill '{s}'")
    denied = {t.strip() for t in (fm.get('disallowedTools') or '').split(',') if t.strip()}
    if name in READ_ONLY and not {'Write', 'Edit', 'NotebookEdit'} <= denied:
        err(path, 'read-only agent must disallow Write, Edit, NotebookEdit')
    if name in REPORT_WRITERS and not {'Edit', 'NotebookEdit'} <= denied:
        err(path, 'report-writing agent must disallow Edit, NotebookEdit')

for name in set(READ_ONLY) | set(REPORT_WRITERS):
    if name not in agents:
        err('scripts/ai-check.py', f"tool policy names '{name}', which is not an agent")

# --- references ---------------------------------------------------------------
dispatch = open('bin/wfl', encoding='utf-8').read()
WFL = set(re.findall(r'^\s{4}([a-z][a-z:-]*)\)', dispatch.split('main() {', 1)[-1], re.M))
WFL |= {'logs', 'cache', 'help'}
RFCS = {m.group(1) for f in os.listdir('project_system/RFCs') for m in [re.match(r'RFC_(\d{3})', f)] if m}
SUBMODULES = {l.split('=', 1)[1].strip() for l in open('.gitmodules') if l.strip().startswith('path')}
NAMES = set(skills) | set(agents)


def checked_out(path):
    first = path.split('/', 1)[0]
    return first not in SUBMODULES or (os.path.isdir(first) and len(os.listdir(first)) > 0)


def git_ignored(path):
    # A gitignored path (`bench/results/`, `.claude/settings.local.json`) exists only where someone created it:
    # a fresh clone or CI never has it, so checking it would pass on one machine and fail on the next.
    return subprocess.run(['git', 'check-ignore', '-q', '--', path], check=False,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def check_refs(path, text):
    for sub in set(re.findall(r'\bwfl ([a-z][a-z:-]*)', text)):
        if sub not in WFL and not (sub.endswith(':') and any(w.startswith(sub) for w in WFL)):
            err(path, f'`wfl {sub}` is not a wfl subcommand')
    for num in set(re.findall(r'\bRFC[-_ ](\d{3})\b', text)):
        if num not in RFCS:
            err(path, f'RFC-{num} does not exist in project_system/RFCs/')
    for ref in set(re.findall(r'`((?:\./)?(?:%s)/[^`\s]*)`' % '|'.join(re.escape(r) for r in PATH_ROOTS), text)):
        p = ref[2:] if ref.startswith('./') else ref
        if any(c in p for c in '*<>{}…') or p in EXTERNAL_PATHS or p.startswith(EXTERNAL_PREFIXES):
            continue
        if checked_out(p) and not os.path.exists(p.rstrip('/')) and not git_ignored(p):
            err(path, f'`{ref}` does not exist')
    # [[x]] is a cross-reference only inside skills and agents; docs use it for Obsidian syntax.
    wiki = set(re.findall(r'\[\[([a-z][a-z0-9-]+)\]\]', text)) if path.startswith('.claude/') else set()
    for name in set(re.findall(r'`([a-z][a-z0-9-]+)` (?:skill|agent|subagent)\b', text)) | wiki:
        if name not in NAMES:
            err(path, f"'{name}' is not a skill or an agent")


LIVE = (sorted(skills.values()) + sorted(agents.values())
        + ['AGENTS.md', 'CLAUDE.md', 'MCP.md', 'README.md']
        + sorted(glob.glob('docs/**/*.md', recursive=True)))
for path in LIVE:
    if os.path.isfile(path):
        check_refs(path, open(path, encoding='utf-8').read())

# --- removed runtimes -----------------------------------------------------------
SWEEP = LIVE + ['.mcp.json', 'bin/wfl'] + sorted(glob.glob('scripts/**/*', recursive=True)) \
    + sorted(glob.glob('.claude/plugins/waffle-cockpit/**/*', recursive=True)) \
    + ['.claude/settings.json', '.claude-plugin/marketplace.json', '.github/workflows/umbrella-ci.yml']
for path in SWEEP:
    if not os.path.isfile(path) or '__pycache__' in path or path == 'scripts/ai-check.py':
        continue
    try:
        for n, line in enumerate(open(path, encoding='utf-8'), 1):
            if REMOVED.search(line):
                err(f'{path}:{n}', 'mentions a removed runtime (opencode / Antigravity / .agents)')
    except UnicodeDecodeError:
        pass
for path in ('.opencode', '.antigravitycli', '.agents', 'opencode.json'):
    if os.path.lexists(path):
        err(path, 'a removed runtime is back on disk')
for path in ('.claude/skills', '.claude/agents'):
    if os.path.islink(path):
        err(path, 'is a symlink: claude plugin validate cannot read it')

# --- plugins ----------------------------------------------------------------------
market = '.claude-plugin/marketplace.json'
plugins = {}
try:
    for entry in json.load(open(market))['plugins']:
        src = entry['source']
        plugins[entry['name']] = src
        manifest = os.path.join(src, '.claude-plugin', 'plugin.json')
        if not os.path.isfile(manifest):
            err(market, f"{entry['name']}: no plugin at {src}")
        elif json.load(open(manifest)).get('name') != entry['name']:
            err(market, f"{entry['name']}: the plugin.json name differs from the entry name")
except (OSError, KeyError, ValueError) as e:
    err(market, f'unreadable ({e})')

mp = '.claude/plugins/mattpocock-skills'
if os.path.isdir(mp):
    vendored = open(os.path.join(mp, 'VENDORED.md'), encoding='utf-8').read()
    if not re.search(r'`[0-9a-f]{40}`', vendored):
        err(f'{mp}/VENDORED.md', 'no 40-character upstream commit')
    listed = {os.path.basename(s) for s in json.load(open(os.path.join(mp, '.claude-plugin', 'plugin.json')))['skills']}
    present = {os.path.basename(os.path.dirname(p)) for p in glob.glob(f'{mp}/skills/*/*/SKILL.md')}
    if listed != present:
        err(mp, f'manifest and skills differ: listed only {sorted(listed - present)}, on disk only {sorted(present - listed)}')
    for s in sorted((listed | present) & MP_EXCLUDED):
        err(mp, f"ships '{s}', which VENDORED.md excludes")

# --- settings ---------------------------------------------------------------------
settings = '.claude/settings.json'
if os.path.isfile(settings):
    try:
        conf = json.load(open(settings))
        enabled = {k.split('@')[0] for k, v in conf.get('enabledPlugins', {}).items() if v and k.endswith('@waffle-commons')}
        if enabled != set(plugins):
            err(settings, f'enabledPlugins ({sorted(enabled)}) differ from the marketplace ({sorted(plugins)})')
        if 'waffle-commons' not in conf.get('extraKnownMarketplaces', {}):
            err(settings, 'extraKnownMarketplaces does not declare waffle-commons')
        for event, groups in conf.get('hooks', {}).items():
            for group in groups:
                for hook in group.get('hooks', []):
                    for script in re.findall(r'\$CLAUDE_PROJECT_DIR"?/([\w./-]+)', hook.get('command', '')):
                        if not os.path.isfile(script):
                            err(settings, f'{event} hook runs a missing {script}')
    except ValueError as e:
        err(settings, f'invalid JSON ({e})')
else:
    notes.append(f'{settings} not present yet (apply the team settings)')

# --- script tests -------------------------------------------------------------------
if os.path.isdir('scripts/tests'):
    run = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts/tests'],
                         capture_output=True, text=True)
    tail = [l for l in (run.stdout + run.stderr).strip().splitlines() if l.strip()]
    if run.returncode != 0:
        err('scripts/tests', ' / '.join(tail[-3:]) or f'exit {run.returncode}')
    else:
        notes.append('script tests: ' + next((l for l in reversed(tail) if l.startswith('Ran ')), 'ok'))

# --- claude CLI ---------------------------------------------------------------------
if '--no-claude' not in sys.argv:
    if shutil.which('claude') is None:
        notes.append('claude CLI not found: plugin validate / test skipped')
    else:
        targets = ['.claude/skills', '.claude/agents', '.'] + sorted(set(plugins.values()))
        for target in targets:
            run = subprocess.run(['claude', 'plugin', 'validate', target, '--strict'], capture_output=True, text=True)
            if run.returncode != 0:
                err(f'claude plugin validate {target}', (run.stdout + run.stderr).strip().splitlines()[-1] if (run.stdout + run.stderr).strip() else f'exit {run.returncode}')
        cockpit = '.claude/plugins/waffle-cockpit'
        if os.path.isdir(cockpit):
            run = subprocess.run(['claude', 'plugin', 'test', cockpit], capture_output=True, text=True)
            summary = [l for l in (run.stdout + run.stderr).splitlines() if re.match(r'^\s*\d+ (pass|fail)', l)]
            if run.returncode != 0:
                err(f'claude plugin test {cockpit}', ' / '.join(summary) or f'exit {run.returncode}')
            else:
                notes.append(f"waffle-cockpit tests: {' / '.join(s.strip() for s in summary)}")

# --- report -------------------------------------------------------------------------
print(f'skills {len(skills)} · agents {len(agents)} · plugins {len(plugins)} · files swept {len(LIVE)}')
for n in notes:
    print(f'  · {n}')
if errors:
    for e in errors:
        print(f'  ✗ {e}')
    print(f'✗ ai:check FAILED: {len(errors)} problem(s)')
    sys.exit(1)
print('✓ ai:check clean')
