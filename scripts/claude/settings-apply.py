#!/usr/bin/env python3
"""scripts/claude/settings-apply.py — merge the hardened Claude Code settings.

Claude does not edit its own permission settings, so the person applies them
with this script. It merges, never replaces: existing rules stay, missing ones
are added, and each run prints what would change. Nothing is written without
--write.

Team settings (.claude/settings.json, committed):
  * Read deny rules for secret files (.env and its variants, keys, key stores,
    SSH identities): the Read tool can no longer open them. The waffle-cockpit
    guard covers the shell (`cat .env`) and the same files.
  * allow rules for the waffle-cockpit tools (mcp__waffle-cockpit__dod, xref,
    coverage_gaps, dod_history), which only run wfl and read the cockpit state.
  * the release audit (the release-audit skill): allow the commands a run
    needs (`wfl audit:init|evidence|calibrate|status|claims|check|fixed`), so
    dozens of agents do not prompt, and deny `wfl audit:sign` and the script
    behind it: a decision on a finding is the maintainer's, recorded in /audit
    or typed in their own terminal.

Personal opt-ins (.claude/settings.local.json, gitignored), only when asked:
  --telemetry     Claude Code's OpenTelemetry metrics on a local Prometheus
                  endpoint (http://localhost:9464/metrics; read by
                  `wfl ai:telemetry`). No prompt text, no tool arguments.
  --no-telemetry  removes those variables again.
  --sandbox       runs Bash in Claude Code's sandbox with a network allowlist
                  (Packagist, GitHub, Docker Hub, the CDNs); docker, git, gh and
                  wfl run outside it, as they need the Docker socket, SSH and
                  the iCloud backup folder. EXPERIMENTAL: try it, keep it if
                  nothing you use breaks.
  --no-sandbox    removes the sandbox block again.

Usage:   python3 scripts/claude/settings-apply.py [--write] [--telemetry|--no-telemetry] [--sandbox|--no-sandbox]
Exit:    0 on success.
"""
from __future__ import annotations

import argparse
import copy
import difflib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEAM = ROOT / ".claude/settings.json"
LOCAL = ROOT / ".claude/settings.local.json"

SECRET_DENY = [
    "Read(**/.env)",
    "Read(**/.env.local)",
    "Read(**/.env.*.local)",
    "Read(**/.env.dev)",
    "Read(**/.env.prod)",
    "Read(**/.env.production)",
    "Read(**/.env.staging)",
    "Read(**/*.pem)",
    "Read(**/*.key)",
    "Read(**/*.p12)",
    "Read(**/*.pfx)",
    "Read(**/*.jks)",
    "Read(**/*.keystore)",
    "Read(~/.ssh/**)",
]

COCKPIT_ALLOW = [
    "mcp__waffle-cockpit__dod",
    "mcp__waffle-cockpit__xref",
    "mcp__waffle-cockpit__coverage_gaps",
    "mcp__waffle-cockpit__dod_history",
]

AUDIT_ALLOW = [
    f"Bash({prefix}wfl audit:{sub}{rest})"
    for sub in ("init", "evidence", "calibrate", "status", "claims", "check", "fixed")
    for prefix in ("./bin/", "bin/", "")
    for rest in ("", " *")
]

# Deny rules take a leading wildcard without a warning; the cockpit guard covers what these spellings miss.
AUDIT_DENY = [
    "Bash(wfl audit:sign)",
    "Bash(wfl audit:sign *)",
    "Bash(bin/wfl audit:sign *)",
    "Bash(./bin/wfl audit:sign *)",
    "Bash(*/bin/wfl audit:sign *)",
    "Bash(scripts/release-audit.py sign *)",
    "Bash(./scripts/release-audit.py sign *)",
    "Bash(*/scripts/release-audit.py sign *)",
    "Bash(python3 scripts/release-audit.py sign *)",
    "Bash(python3 -I scripts/release-audit.py sign *)",
]

TELEMETRY_ENV = {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "prometheus",
    "OTEL_LOGS_EXPORTER": "none",
    "OTEL_METRIC_EXPORT_INTERVAL": "60000",
}

SANDBOX = {
    "enabled": True,
    "autoAllowBashIfSandboxed": False,
    "excludedCommands": ["docker *", "git *", "gh *", "wfl *", "bin/wfl *", "./bin/wfl *", "claude *"],
    "network": {
        "allowedDomains": [
            "packagist.org",
            "*.packagist.org",
            "repo.packagist.org",
            "github.com",
            "*.github.com",
            "*.githubusercontent.com",
            "registry-1.docker.io",
            "*.docker.io",
            "*.docker.com",
            "cdnjs.cloudflare.com",
            "cdn.jsdelivr.net",
            "unpkg.com",
            "registry.npmjs.org",
            "code.claude.com",
        ],
        "allowLocalBinding": True,
    },
}


def load(path: pathlib.Path) -> dict:
    return json.loads(path.read_text()) if path.exists() else {}


def merged_rules(rules: list[str], extra: list[str]) -> list[str]:
    return rules + [rule for rule in extra if rule not in rules]


def show(path: pathlib.Path, before: dict, after: dict) -> bool:
    old = json.dumps(before, indent=2).splitlines()
    new = json.dumps(after, indent=2).splitlines()
    diff = list(difflib.unified_diff(old, new, f"{path.name} (now)", f"{path.name} (after)", lineterm="", n=1))
    if not diff:
        print(f"= {path.relative_to(ROOT)}: already up to date")
        return False
    print("\n".join(diff))
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge the hardened Claude Code settings")
    parser.add_argument("--write", action="store_true")
    tel = parser.add_mutually_exclusive_group()
    tel.add_argument("--telemetry", action="store_true")
    tel.add_argument("--no-telemetry", action="store_true")
    box = parser.add_mutually_exclusive_group()
    box.add_argument("--sandbox", action="store_true")
    box.add_argument("--no-sandbox", action="store_true")
    args = parser.parse_args()

    team_before = load(TEAM)
    team = copy.deepcopy(team_before)
    perms = team.setdefault("permissions", {})
    perms["deny"] = merged_rules(perms.get("deny", []), SECRET_DENY + AUDIT_DENY)
    perms["allow"] = merged_rules(perms.get("allow", []), COCKPIT_ALLOW + AUDIT_ALLOW)

    local_before = load(LOCAL)
    local = copy.deepcopy(local_before)
    if args.telemetry:
        local.setdefault("env", {}).update(TELEMETRY_ENV)
    if args.no_telemetry and "env" in local:
        for key in TELEMETRY_ENV:
            local["env"].pop(key, None)
        if not local["env"]:
            del local["env"]
    if args.sandbox:
        local["sandbox"] = SANDBOX
    if args.no_sandbox:
        local.pop("sandbox", None)

    changed = [(TEAM, team) if show(TEAM, team_before, team) else None, (LOCAL, local) if show(LOCAL, local_before, local) else None]
    changed = [item for item in changed if item is not None]
    if not changed:
        return 0
    if not args.write:
        print("\n(dry run: nothing written; rerun with --write to apply)")
        return 0
    for path, data in changed:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print(f"✓ wrote {path.relative_to(ROOT)}")
    print("Restart Claude Code (or open /permissions) for the new rules to take effect.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
