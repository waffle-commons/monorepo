#!/usr/bin/env python3
"""Report CI, Dependabot and toolchain drift of every component against component-template.

component-template is the canonical copy. For every library component (a submodule
with composer.json and .github/workflows/main.yml, template itself excluded) this checks:

  workflow    .github/workflows/main.yml equals the template's, ignoring comment lines and
              the per-component `extensions:` / `ini-values:` lines of setup-php
  dependabot  .github/dependabot.yml is byte-identical to the template's
  toolchain   require-dev constraints of the shared toolchain equal the template's (a package
              the component ships code against, such as testing's PHPUnit, sits in require
              with the same constraint)
  description composer.json description is real prose, not a template placeholder
  php-version mago.toml php-version equals the template's

and, for the umbrella:

  igor pin    every IGOR_VERSION in a workflow equals .igor-version
  igor hash   every workflow that pins igor checks the downloaded archive against one committed
              IGOR_SHA256_LINUX_AMD64 (`sha256sum -c`), the same hash everywhere
  pin         every `uses:` in every workflow (template, libraries, umbrella) names a full commit
              SHA with its version as a comment; the template and library workflows declare a
              top-level read-only `permissions:` block (S-B1-02)
  trufflehog  TruffleHog's `version:` input equals the version its pinned `uses:` names (the
              action otherwise runs the `latest` image)
  php floor   every composer.json of the ecosystem requires php ^8.5.12 or later, and the
              component CI (template, libraries, umbrella-ci) asserts PHP_VERSION_ID >= 80512
              before it installs anything (S-B1-07)
  security    component-template's SECURITY.md names both private channels, the response time
              and the supported versions; every library carries the same file, and skeleton the
              French policy (S-B1-08)
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
    runtime = composer.get("require", {})
    for pkg in TOOLCHAIN:
        declared = dev.get(pkg, runtime.get(pkg))
        if declared != tpl_dev.get(pkg):
            problems.append((c, "toolchain", f"{pkg} is {declared!r}, template has {tpl_dev.get(pkg)!r}"))
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

# Third-party code runs only at a fixed commit, and the igor archive is verified (S-B1-02).
UMBRELLA_WORKFLOWS = [".github/workflows/umbrella-ci.yml", ".github/workflows/release-wave.yml",
                      ".github/workflows/fresh-install.yml"]
COMPONENT_WORKFLOWS = [f"{TEMPLATE}/.github/workflows/main.yml"] + [f"{c}/.github/workflows/main.yml" for c in libraries]
PINNED = re.compile(r"uses:\s*[\w.-]+/[\w./-]+@[0-9a-f]{40}\s+#\s*v?\d+\.\d+\.\d+\s*$")
TRUFFLEHOG = re.compile(r"uses:\s*trufflesecurity/trufflehog@[0-9a-f]{40}\s+#\s*v?(\d+\.\d+\.\d+)\s*$")
igor_hashes = set()
for wf in COMPONENT_WORKFLOWS + UMBRELLA_WORKFLOWS:
    lines = read(wf).splitlines()
    for n, line in enumerate(lines, 1):
        ref = re.search(r"uses:\s*(\S+)", line)
        if ref and not ref.group(1).startswith(("./", "docker://")) and not PINNED.search(line):
            problems.append((wf, "pin", f"line {n}: {ref.group(1)} is not a commit SHA with a # version comment"))
        pinned_trufflehog = TRUFFLEHOG.search(line)
        if pinned_trufflehog:
            step = []
            for following in lines[n:]:
                if re.match(r"\s*- ", following) or not following.startswith(" " * 8):
                    break
                step.append(following)
            given = [v.strip("'\"").removeprefix("v")
                     for v in re.findall(r"^\s+version:\s*(\S+)\s*$", "\n".join(step), re.MULTILINE)]
            if given != [pinned_trufflehog.group(1)]:
                problems.append((wf, "trufflehog", f"line {n}: version input {given or 'missing'}, "
                                                   f"the pinned action is v{pinned_trufflehog.group(1)}"))
    text = "\n".join(lines)
    if "IGOR_VERSION:" in text:
        found = re.findall(r"IGOR_SHA256_LINUX_AMD64:\s*'([0-9a-f]{64})'", text)
        if len(found) != 1 or "sha256sum -c" not in text:
            problems.append((wf, "igor hash", "the igor archive is not checked against one committed SHA-256"))
        igor_hashes.update(found)
if len(igor_hashes) > 1:
    problems.append(("workflows", "igor hash", f"{len(igor_hashes)} different igor archive hashes"))
for wf in COMPONENT_WORKFLOWS:
    if not re.search(r"^permissions:\n  contents: read\n", read(wf), re.MULTILINE):
        problems.append((wf, "permissions", "no top-level read-only permissions block"))

# The PHP floor: no release before 8.5.12 installs or runs (S-B1-07).
PHP_FLOOR = (8, 5, 12)
composer_repos = [TEMPLATE] + libraries + [r for r in ("skeleton", "workspace", "academy/labs", "academy/sandbox")
                                           if exists(f"{r}/composer.json")]
for r in composer_repos:
    php = json.loads(read(f"{r}/composer.json")).get("require", {}).get("php", "")
    floor = re.fullmatch(r"\^(\d+)\.(\d+)\.(\d+)", php)
    if not floor or tuple(int(part) for part in floor.groups()) < PHP_FLOOR:
        problems.append((f"{r}/composer.json", "php floor", f"require.php is {php!r}, needs ^8.5.12 or later"))
for wf in COMPONENT_WORKFLOWS + [".github/workflows/umbrella-ci.yml"]:
    if "PHP_VERSION_ID >= 80512" not in read(wf):
        problems.append((wf, "php floor", "CI does not assert PHP_VERSION_ID >= 80512"))

# One security policy with a private channel, the same file in every library (S-B1-08).
tpl_security = read(f"{TEMPLATE}/SECURITY.md") if exists(f"{TEMPLATE}/SECURITY.md") else ""
for needed in ("security@eightyfour.ovh", "Report a vulnerability", "within 48 hours", "## Supported versions"):
    if needed not in tpl_security:
        problems.append((f"{TEMPLATE}/SECURITY.md", "security", f"the policy does not state {needed!r}"))
for c in libraries:
    if not exists(f"{c}/SECURITY.md") or read(f"{c}/SECURITY.md") != tpl_security:
        problems.append((f"{c}/SECURITY.md", "security", "differs from component-template's policy"))
skeleton_security = read("skeleton/SECURITY.md") if exists("skeleton/SECURITY.md") else ""
for needed in ("security@eightyfour.ovh", "Report a vulnerability", "sous 48 heures"):
    if needed not in skeleton_security:
        problems.append(("skeleton/SECURITY.md", "security", f"the French policy does not state {needed!r}"))

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
