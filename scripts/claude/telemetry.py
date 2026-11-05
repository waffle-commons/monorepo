#!/usr/bin/env python3
"""scripts/claude/telemetry.py — what Claude Code's own metrics say (`wfl ai:telemetry`).

With telemetry on (scripts/claude/settings-apply.py --telemetry), each running
Claude Code session serves its OpenTelemetry metrics in Prometheus format on
http://localhost:9464/metrics: cost, tokens by type, lines added and removed,
commits, pull requests, edit decisions and active time. No prompt text and no
tool arguments are exported (OTEL_LOG_USER_PROMPTS / OTEL_LOG_TOOL_DETAILS stay
off). This prints a one-screen digest, or the raw lines with --raw.

Usage:   scripts/claude/telemetry.py [--url URL] [--raw]
Exit:    0 when the endpoint answered, 1 otherwise.
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.error
import urllib.request
from collections import defaultdict

SAMPLE = re.compile(r"^(claude_code_[a-z_]+?)(?:_total)?(?:\{([^}]*)\})?\s+([0-9.eE+-]+)")


def labels_of(text: str) -> dict[str, str]:
    return dict(re.findall(r'(\w+)="([^"]*)"', text or ""))


def main() -> int:
    parser = argparse.ArgumentParser(description="Digest of Claude Code's Prometheus metrics")
    parser.add_argument("--url", default="http://localhost:9464/metrics")
    parser.add_argument("--raw", action="store_true")
    args = parser.parse_args()

    try:
        with urllib.request.urlopen(args.url, timeout=5) as response:
            body = response.read().decode()
    except (urllib.error.URLError, OSError) as error:
        print(f"✗ {args.url} did not answer ({error}).", file=sys.stderr)
        print("  Telemetry is off, or no session has started since it was turned on:", file=sys.stderr)
        print("  python3 scripts/claude/settings-apply.py --telemetry --write, then restart Claude Code.", file=sys.stderr)
        return 1

    if args.raw:
        print("\n".join(line for line in body.splitlines() if line.startswith("claude_code_")))
        return 0

    totals: dict[str, float] = defaultdict(float)
    by_type: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    for line in body.splitlines():
        match = SAMPLE.match(line)
        if match is None:
            continue
        name, raw_labels, value = match.group(1), match.group(2), float(match.group(3))
        totals[name] += value
        kind = labels_of(raw_labels).get("type") or labels_of(raw_labels).get("decision")
        if kind:
            by_type[name][kind] += value

    if not totals:
        print("· the endpoint answered, with no claude_code metric yet (the first export comes after a minute)")
        return 0
    rows = [
        ("cost (USD)", "claude_code_cost_usage", "{:.2f}"),
        ("tokens", "claude_code_token_usage", "{:,.0f}"),
        ("lines of code", "claude_code_lines_of_code_count", "{:,.0f}"),
        ("commits", "claude_code_commit_count", "{:,.0f}"),
        ("pull requests", "claude_code_pull_request_count", "{:,.0f}"),
        ("edit decisions", "claude_code_code_edit_tool_decision", "{:,.0f}"),
        ("active time (s)", "claude_code_active_time_total", "{:,.0f}"),
        ("sessions", "claude_code_session_count", "{:,.0f}"),
    ]
    for label, name, fmt in rows:
        found = next((key for key in totals if key.startswith(name)), None)
        if found is None:
            continue
        detail = ", ".join(f"{k} {fmt.format(v)}" for k, v in sorted(by_type[found].items()))
        print(f"  {label:<16} {fmt.format(totals[found]):>12}" + (f"   ({detail})" if detail else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
