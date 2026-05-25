#!/usr/bin/env bash
# ============================================================================
# pre-push-sanity.sh — full Mago + PHPUnit gate before push
# Runs 'composer mago' and 'composer tests' on every component that has PHP
# changes in the about-to-be-pushed ref range. No-op when nothing is ahead.
# Bypass with: SKIP_MAGO=1 git push ...
# ============================================================================

set -euo pipefail

if [ "${SKIP_MAGO:-0}" = "1" ]; then
  printf '\033[0;33m⚡ SKIP_MAGO=1 — bypassing mago pre-push\033[0m\n'
  exit 0
fi

HOOK_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_ROOT="$(cd -P -- "$HOOK_DIR/../.." && pwd)"
CONTAINER="waffle-dev"
GITMODULES="$UMBRELLA_ROOT/.gitmodules"
ZERO="0000000000000000000000000000000000000000"

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

GIT_TOP="$(cd -P -- "$(git rev-parse --show-toplevel)" && pwd)"
IN_SUBMODULE=0
SUB_COMP=""
if [ "$GIT_TOP" != "$UMBRELLA_ROOT" ]; then
  IN_SUBMODULE=1
  SUB_COMP="${GIT_TOP#$UMBRELLA_ROOT/}"
fi

default_base() {
  for r in refs/remotes/origin/main refs/remotes/origin/master; do
    if git rev-parse --verify "$r" >/dev/null 2>&1; then
      git rev-parse "$r"
      return 0
    fi
  done
  return 1
}

COMPS=""
add_comp() {
  case " $COMPS " in
    *" $1 "*) : ;;
    *) COMPS="$COMPS $1" ;;
  esac
}

# Read git push protocol: <local_ref> <local_sha> <remote_ref> <remote_sha>
ANY_AHEAD=0
while read -r local_ref local_sha remote_ref remote_sha; do
  [ -z "${local_sha:-}" ] && continue
  [ "$local_sha" = "$ZERO" ] && continue   # branch deletion
  [ "$local_sha" = "$remote_sha" ] && continue  # already up-to-date
  ANY_AHEAD=1

  if [ "$remote_sha" = "$ZERO" ]; then
    if base="$(default_base)"; then
      range="$base..$local_sha"
    else
      range="$local_sha"
    fi
  else
    range="$remote_sha..$local_sha"
  fi

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ "$IN_SUBMODULE" -eq 1 ]; then
      add_comp "$SUB_COMP"
    else
      comp="${f%%/*}"
      [ "$comp" = "$f" ] && continue
      if is_known_component "$comp"; then
        add_comp "$comp"
      fi
    fi
  done < <(git diff --name-only "$range" -- '*.php' 2>/dev/null || true)
done

if [ "$ANY_AHEAD" -eq 0 ]; then
  printf '\033[0;32m✓ pre-push: nothing to push\033[0m\n'
  exit 0
fi

# Trim leading space and bail early if no components were touched.
COMPS="${COMPS# }"
if [ -z "$COMPS" ]; then
  printf '\033[0;32m✓ pre-push: no PHP changes in pushed range\033[0m\n'
  exit 0
fi

state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo absent)"
if [ "$state" != "running" ]; then
  printf '\033[0;31m✗ container %s not running (%s). Start with "wfl up" or bypass with SKIP_MAGO=1.\033[0m\n' "$CONTAINER" "$state" >&2
  exit 1
fi

FAILED=0
for comp in $COMPS; do
  printf '\033[0;36m→ composer mago   [%s]\033[0m\n' "$comp"
  if ! docker exec -w "/waffle-commons/$comp" "$CONTAINER" composer mago; then
    FAILED=$((FAILED + 1))
    continue
  fi
  printf '\033[0;36m→ composer tests  [%s]\033[0m\n' "$comp"
  if ! docker exec -w "/waffle-commons/$comp" "$CONTAINER" composer tests; then
    FAILED=$((FAILED + 1))
    continue
  fi
done

if [ "$FAILED" -gt 0 ]; then
  printf '\n\033[0;31m✗ pre-push failed in %d component(s). Fix and re-push (or SKIP_MAGO=1 to bypass).\033[0m\n' "$FAILED" >&2
  exit 1
fi

printf '\033[0;32m✓ pre-push passed\033[0m\n'
