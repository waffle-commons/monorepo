#!/usr/bin/env python3
"""Report CI, Dependabot and toolchain drift of every component against component-template.

component-template is the canonical copy. For every library component (a submodule
with composer.json and .github/workflows/main.yml, template itself excluded) this checks:

  workflow    .github/workflows/main.yml equals the template's, ignoring comment lines and
              the per-component `extensions:` / `ini-values:` lines of setup-php
  dependabot  .github/dependabot.yml is byte-identical to the template's
  toolchain   require-dev constraints of the shared toolchain equal the template's
  description composer.json description is real prose, not a template placeholder
  php-version mago.toml php-version equals the template's

and, for the umbrella:

  igor pin    every IGOR_VERSION in a workflow equals .igor-version
  filter      umbrella-ci's paths filter lists every library component
  actions     umbrella workflows use the same action versions as the template. The umbrella
              has no Dependabot config on purpose: its fork ruleset blocks branch creation
              and GitHub refuses the Dependabot bypass there (422), so Dependabot bumps the
              template and this check makes the umbrella follow.

Exit 0 when nothing drifts, 1 otherwise. Read-only.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = "component-template"
TOOLCHAIN = ("phpunit/phpunit", "carthage-software/mago", "vimeo/psalm",
             "php-mock/php-mock-phpunit", "cyclonedx/cyclonedx-php-composer", "igor-php/igor-php")
PLACEHOLDER_DESC = re.compile(r"\{|component for Waffle framework|^TODO", re.IGNORECASE)
TTY = sys.stdout.isatty()
RED, GRN, DIM, RST = ("\033[0;31m", "\033[0;32m", "\033[2m", "\033[0m") if TTY else ("", "", "", "")


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def exists(path):
    return os.path.isfile(os.path.join(ROOT, path))


def normalize_workflow(text):
    kept = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("extensions:") or stripped.startswith("ini-values:"):
            continue
        kept.append(line.rstrip())
    return "\n".join(kept)


def php_version(path):
    m = re.search(r'^php-version\s*=\s*"([^"]+)"', read(path), re.MULTILINE)
    return m.group(1) if m else None


def action_versions(text):
    return dict(re.findall(r"uses:\s*([\w.-]+/[\w.-]+)@(\S+)", text))


components = subprocess.run([os.path.join(ROOT, "scripts", "list-components.sh")],
                            capture_output=True, text=True, check=True).stdout.split()
libraries = [c for c in components if c != TEMPLATE
             and exists(f"{c}/composer.json") and exists(f"{c}/.github/workflows/main.yml")]

tpl_workflow = read(f"{TEMPLATE}/.github/workflows/main.yml")
tpl_norm = normalize_workflow(tpl_workflow)
tpl_dependabot = read(f"{TEMPLATE}/.github/dependabot.yml")
tpl_dev = json.loads(read(f"{TEMPLATE}/composer.json"))["require-dev"]
tpl_php = php_version(f"{TEMPLATE}/mago.toml")
igor_pin = read(".igor-version").strip()

problems = []

for c in libraries:
    if normalize_workflow(read(f"{c}/.github/workflows/main.yml")) != tpl_norm:
        problems.append((c, "workflow", "main.yml differs from the template (beyond comments/extensions)"))
    if not exists(f"{c}/.github/dependabot.yml"):
        problems.append((c, "dependabot", "missing .github/dependabot.yml"))
    elif read(f"{c}/.github/dependabot.yml") != tpl_dependabot:
        problems.append((c, "dependabot", "differs from the template"))
    composer = json.loads(read(f"{c}/composer.json"))
    dev = composer.get("require-dev", {})
    for pkg in TOOLCHAIN:
        if dev.get(pkg) != tpl_dev.get(pkg):
            problems.append((c, "toolchain", f"{pkg} is {dev.get(pkg)!r}, template has {tpl_dev.get(pkg)!r}"))
    desc = composer.get("description", "")
    if not desc or PLACEHOLDER_DESC.search(desc):
        problems.append((c, "description", f"placeholder description: {desc!r}"))
    if exists(f"{c}/mago.toml") and php_version(f"{c}/mago.toml") != tpl_php:
        problems.append((c, "php-version", f"mago.toml php-version {php_version(f'{c}/mago.toml')!r} != {tpl_php!r}"))

# Every workflow that pins igor must pin .igor-version.
workflow_files = [f"{TEMPLATE}/.github/workflows/main.yml", ".github/workflows/umbrella-ci.yml"]
workflow_files += [f"{c}/.github/workflows/main.yml" for c in libraries]
for wf in workflow_files:
    for found in re.findall(r"IGOR_VERSION:\s*'([^']+)'", read(wf)):
        if found != igor_pin:
            problems.append((wf, "igor pin", f"IGOR_VERSION {found} != .igor-version {igor_pin}"))

# umbrella-ci must gate every library component.
umbrella_ci = read(".github/workflows/umbrella-ci.yml")
filter_block = re.search(r"filters: \|\n(.*?)\n\n", umbrella_ci, re.DOTALL)
filtered = set(re.findall(r"^\s+([\w-]+):\s+'", filter_block.group(1), re.MULTILINE)) if filter_block else set()
for c in libraries:
    if c not in filtered:
        problems.append(("umbrella-ci", "filter", f"'{c}' is not in the dorny/paths-filter list"))

# umbrella workflows use the same action versions as the component template.
tpl_actions = action_versions(tpl_workflow)
for wf in (".github/workflows/umbrella-ci.yml", ".github/workflows/release-wave.yml"):
    for action, version in action_versions(read(wf)).items():
        if action in tpl_actions and version != tpl_actions[action]:
            problems.append((wf, "actions", f"{action}@{version}, template uses @{tpl_actions[action]}"))

print(f"ci:check — {len(libraries)} library components against {TEMPLATE} (igor pin {igor_pin})")
if not problems:
    print(f"{GRN}✓ no drift{RST}")
    sys.exit(0)
for where, kind, detail in problems:
    print(f"  {RED}✗{RST} {where:<22} {kind:<12} {detail}")
print(f"{RED}✗ {len(problems)} drift finding(s){RST}")
sys.exit(1)
