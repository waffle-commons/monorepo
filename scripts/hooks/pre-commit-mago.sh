#!/usr/bin/env bash
# ============================================================================
# pre-commit-mago.sh — fast, incremental Mago gate
# Runs only on staged PHP files, grouped by component, inside the waffle-dev
# container. The DX-02 design target is a sub-150ms lint; that figure assumes a
# native Mago run, whereas routing every invocation through `docker exec` adds
# fixed container overhead, so in practice this finishes in ~1–3s on small
# commits. CI runs the full suite; this hook is the fast staged-only guard.
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

# Detect context: umbrella commit vs submodule commit (git sets GIT_DIR for hooks).
GIT_TOP="$(cd -P -- "$(git rev-parse --show-toplevel)" && pwd)"
IN_SUBMODULE=0
SUB_COMP=""
if [ "$GIT_TOP" != "$UMBRELLA_ROOT" ]; then
  IN_SUBMODULE=1
  SUB_COMP="${GIT_TOP#$UMBRELLA_ROOT/}"
fi

# ---------------------------------------------------------------------------
# Guard: Block commits carrying local path repositories in composer.json
# ---------------------------------------------------------------------------
STAGED_COMPOSER_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | grep -E '(^|/)composer\.json$' || true)

if [ -n "$STAGED_COMPOSER_FILES" ]; then
  for file in $STAGED_COMPOSER_FILES; do
    # The dev workspace is the development station: it stays permanently linked
    # (path repositories by design), so exempt its composer.json from the guard.
    if [ "$IN_SUBMODULE" -eq 1 ]; then
      file_owner="$SUB_COMP"
    else
      file_owner="$(dirname "$file")"
    fi
    if [ "$file_owner" = "workspace" ]; then
      continue
    fi
    if git show :"$file" | grep -qE '"type"[[:space:]]*:[[:space:]]*"path"|"url"[[:space:]]*:[[:space:]]*"\.\./' ; then
      printf '\033[0;31m[ERROR] Local linkage detected in file %s!\033[0m\n' "$file" >&2
      printf '\033[0;31mCommitting "path"-type repositories pointing to local paths is forbidden.\033[0m\n' >&2
      
      provider_name=$(git show :"$file" | awk -F'"url"[[:space:]]*:[[:space:]]*"\\.\\./' 'NF>1 {split($2, a, "\""); print a[1]}')
      consumer_name=$(dirname "$file")
      if [ "$consumer_name" = "." ] && [ "${IN_SUBMODULE:-0}" -eq 1 ]; then
        consumer_name="$SUB_COMP"
      fi
      if [ -n "$consumer_name" ] && [ "$consumer_name" != "." ] && [ -n "$provider_name" ]; then
        printf '\033[0;33mPlease unlink the components first by running:\033[0m\n' >&2
        printf '\033[0;33m  bin/wfl unlink %s %s\033[0m\n' "$consumer_name" "$provider_name" >&2
      else
        printf '\033[0;33mPlease unlink the components first by running bin/wfl unlink <consumer> <provider>\033[0m\n' >&2
      fi
      exit 1
    fi
  done
fi


is_known_component() {
  awk -v needle="$1" '
    /^[[:space:]]*path[[:space:]]*=/ {
      sub(/^[[:space:]]*path[[:space:]]*=[[:space:]]*/, "");
      if ($0 == needle) { found=1; exit }
    }
    END { exit !found }
  ' "$GITMODULES"
}



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
