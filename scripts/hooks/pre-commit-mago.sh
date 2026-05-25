#!/usr/bin/env bash
# ============================================================================
# pre-commit-mago.sh — fast, incremental Mago gate
# Runs only on staged PHP files, grouped by component, inside the waffle-dev
# container. Designed to finish under 3s on small commits.
# Bypass with: SKIP_MAGO=1 git commit ...
# ============================================================================

set -euo pipefail

if [ "${SKIP_MAGO:-0}" = "1" ]; then
  printf '\033[0;33m⚡ SKIP_MAGO=1 — bypassing mago pre-commit\033[0m\n'
  exit 0
fi

HOOK_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_ROOT="$(cd -P -- "$HOOK_DIR/../.." && pwd)"
CONTAINER="waffle-dev"
GITMODULES="$UMBRELLA_ROOT/.gitmodules"

[ -f "$GITMODULES" ] || { printf '\033[0;31m✗ .gitmodules not found at %s\033[0m\n' "$GITMODULES" >&2; exit 1; }

is_known_component() {
  awk -v needle="$1" '
    /^[[:space:]]*path[[:space:]]*=/ {
      sub(/^[[:space:]]*path[[:space:]]*=[[:space:]]*/, "");
      if ($0 == needle) { found=1; exit }
    }
    END { exit !found }
  ' "$GITMODULES"
}

# Detect context: umbrella commit vs submodule commit (git sets GIT_DIR for hooks).
GIT_TOP="$(cd -P -- "$(git rev-parse --show-toplevel)" && pwd)"
IN_SUBMODULE=0
SUB_COMP=""
if [ "$GIT_TOP" != "$UMBRELLA_ROOT" ]; then
  IN_SUBMODULE=1
  SUB_COMP="${GIT_TOP#$UMBRELLA_ROOT/}"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP

# Collect staged PHP files (NUL-separated, robust to filenames with spaces).
while IFS= read -r -d '' f; do
  [ -z "$f" ] && continue
  if [ "$IN_SUBMODULE" -eq 1 ]; then
    comp="$SUB_COMP"
    rel="$f"
  else
    comp="${f%%/*}"
    [ "$comp" = "$f" ] && continue
    rel="${f#*/}"
  fi
  is_known_component "$comp" || continue
  printf '%s\0' "$rel" >> "$TMP/$comp.z"
done < <(git diff --cached -z --name-only --diff-filter=ACMR -- '*.php' 2>/dev/null || true)

if [ -z "$(ls -A "$TMP" 2>/dev/null)" ]; then
  printf '\033[0;32m✓ pre-commit: no staged PHP files in known components\033[0m\n'
  exit 0
fi

state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo absent)"
if [ "$state" != "running" ]; then
  printf '\033[0;31m✗ container %s not running (%s). Start with "wfl up" or bypass with SKIP_MAGO=1.\033[0m\n' "$CONTAINER" "$state" >&2
  exit 1
fi

FAILED=0
for ZFILE in "$TMP"/*.z; do
  comp="$(basename "$ZFILE" .z)"

  if ! docker exec -w "/waffle-commons/$comp" "$CONTAINER" test -x vendor/bin/mago 2>/dev/null; then
    printf '\033[0;33m! %s: vendor/bin/mago missing — run "wfl run %s composer install" (skipped)\033[0m\n' "$comp" "$comp" >&2
    continue
  fi

  printf '\033[0;36m→ mago fmt --check  [%s]\033[0m\n' "$comp"
  if ! xargs -0 docker exec -w "/waffle-commons/$comp" "$CONTAINER" vendor/bin/mago fmt --check -- < "$ZFILE"; then
    FAILED=$((FAILED + 1))
    continue
  fi

  printf '\033[0;36m→ mago lint         [%s]\033[0m\n' "$comp"
  if ! xargs -0 docker exec -w "/waffle-commons/$comp" "$CONTAINER" vendor/bin/mago lint -- < "$ZFILE"; then
    FAILED=$((FAILED + 1))
    continue
  fi
done

if [ "$FAILED" -gt 0 ]; then
  printf '\n\033[0;31m✗ pre-commit failed in %d component(s). Fix and re-stage (or SKIP_MAGO=1 to bypass).\033[0m\n' "$FAILED" >&2
  exit 1
fi

printf '\033[0;32m✓ pre-commit passed\033[0m\n'
