#!/usr/bin/env bash
# =============================================================================
# scripts/list-components.sh — print the canonical component list.
#
# .gitmodules is the SINGLE SOURCE OF TRUTH for which submodules make up the
# monorepo. Every other helper (coverage.sh, loop.sh, zip-project.sh, the
# dod/pre-release scripts) sources this so the component set never drifts.
#
# Usage:   scripts/list-components.sh
# Output:  one submodule path per line, in declaration order.
# Exit:    0 on success; 1 if .gitmodules is missing.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GITMODULES="$REPO_ROOT/.gitmodules"

if [ ! -f "$GITMODULES" ]; then
  printf '✗ .gitmodules not found at %s\n' "$GITMODULES" >&2
  exit 1
fi

awk '/^[[:space:]]*path[[:space:]]*=/ {
       sub(/^[[:space:]]*path[[:space:]]*=[[:space:]]*/, "");
       print
     }' "$GITMODULES"
