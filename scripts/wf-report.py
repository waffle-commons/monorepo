#!/usr/bin/env python3
"""Summarize a Workflow / background-agent JSON output file.

Recurrent agent task: a workflow's result is a large JSON blob (often a wrapper
{summary, agentCount, logs, result:[...]}) whose per-item shape varies (review →
verified findings; remediation → fixed; wiring → wired/simplified; build →
created/updated). Re-deriving a compact view by hand each time is wasteful — this
prints a scannable digest instead.

Usage:
  scripts/wf-report.py <path-to-output.json> [--severity high|medium|low|all]

Reads stdin if no path is given.
"""
from __future__ import annotations
import json
import sys

SEV_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3, "nit": 4, "invalid": 5}


def load(path: str | None):
    raw = open(path).read() if path and path != "-" else sys.stdin.read()
    data = json.loads(raw)
    # Unwrap a double-encoded string, then the {summary,result} wrapper.
    if isinstance(data, str):
        data = json.loads(data)
    if isinstance(data, dict):
        data = data.get("result", data)
    return data if isinstance(data, list) else [data]


def trunc(s, n=220):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[: n - 1] + "…"


def title_of(item: dict) -> str:
    for k in ("area", "component", "app", "workstream", "name", "key"):
        if item.get(k):
            return str(item[k])
    return "(item)"


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    min_sev = "all"
    for a in sys.argv[1:]:
        if a.startswith("--severity"):
            min_sev = a.split("=", 1)[1] if "=" in a else "high"
    path = args[0] if args else None
    items = load(path)

    print(f"╔═ workflow report — {len(items)} item(s) ═╗")
    for item in items:
        if not isinstance(item, dict):
            print(f"\n■ {trunc(item)}")
            continue
        print(f"\n■ {title_of(item)}")
        for k in ("summary", "verification", "notes", "smokeTest", "mago", "tests", "coverage", "igor"):
            if item.get(k):
                print(f"   {k}: {trunc(item[k])}")
        # review-style verified findings
        verified = item.get("verified") or []
        if verified:
            def sev(f):
                v = f.get("verdict") or {}
                return SEV_ORDER.get(v.get("adjustedSeverity") or f.get("severity"), 9)
            for f in sorted(verified, key=sev):
                v = f.get("verdict") or {}
                s = v.get("adjustedSeverity") or f.get("severity") or "?"
                if min_sev != "all" and SEV_ORDER.get(s, 9) > SEV_ORDER.get(min_sev, 9):
                    continue
                print(f"   [{s}|real={v.get('isReal')}] {f.get('id')}: {trunc(f.get('title'),120)}")
        # remediation / wiring lists
        for key, fmt in (("fixed", lambda x: f"{x.get('id')}: {trunc(x.get('how'),100)}"),
                         ("wired", lambda x: f"{x.get('axis')}: {trunc(x.get('how'),100)}")):
            for x in item.get(key) or []:
                print(f"   ✓ {fmt(x)}")
        for s in item.get("simplified") or []:
            print(f"   ~ simplified: {trunc(s,140)}")
        # build-style created/updated
        for key in ("created", "updated"):
            vals = item.get(key) or []
            if vals:
                names = [v.split("/")[-1] for v in vals]
                print(f"   {key} ({len(names)}): {', '.join(names)}")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
