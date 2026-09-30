#!/usr/bin/env bash
# =============================================================================
# scripts/ci-check.sh — drift report: every component's CI workflow, Dependabot
# config and toolchain against component-template (the canonical copy), plus the
# umbrella's igor pin, paths filter and action versions. Read-only.
# Implementation: scripts/ci-check.py. Exit 0 = no drift, 1 = drift found.
# =============================================================================
set -euo pipefail
exec python3 "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/ci-check.py" "$@"
