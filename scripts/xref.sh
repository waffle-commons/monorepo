#!/usr/bin/env bash
# xref — find references to a PHP symbol across every component's src/ (and tests/
# with --tests), vendor/ always excluded. Runs from the repo root with ripgrep
# (falls back to grep) and -g globs, and SANITY-CHECKS the sweep against a known-
# present anchor so a silently-broken scan (the host-bash-scan-pitfalls trap: BSD
# grep \b, zsh word-splitting) can never read as a false "0 references / clean".
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SELF"

SYMBOL=""
WITH_TESTS=0
for a in "$@"; do
  case "$a" in
    --tests) WITH_TESTS=1 ;;
    -*) ;;
    *) [ -z "$SYMBOL" ] && SYMBOL="$a" ;;
  esac
done
[ -n "$SYMBOL" ] || { echo "usage: wfl xref <Symbol> [--tests]" >&2; exit 2; }

ANCHOR='declare(strict_types=1)'
HAVE_RG=0; command -v rg >/dev/null 2>&1 && HAVE_RG=1

scan() {
  # -F / fixed-string: a PHP symbol is literal text (FQCNs contain '\', DTO/attr
  # snippets contain '(' ')' '=' ';') — treating it as a regex silently mis-matches
  # (that is exactly how the sanity anchor below catches a broken sweep).
  local pattern="$1"
  if [ "$HAVE_RG" -eq 1 ]; then
    local args=(--no-heading --line-number -F -g '*.php' -g '!**/vendor/**')
    [ "$WITH_TESTS" -eq 0 ] && args+=(-g '!**/tests/**')
    rg "${args[@]}" -- "$pattern" . 2>/dev/null || true
  else
    if [ "$WITH_TESTS" -eq 0 ]; then
      grep -rnF --include='*.php' -- "$pattern" . 2>/dev/null | grep -vE '/vendor/|/tests/' || true
    else
      grep -rnF --include='*.php' -- "$pattern" . 2>/dev/null | grep -v '/vendor/' || true
    fi
  fi
}

# A broken sweep finds nothing — including the anchor. Fail loudly instead of lying.
if [ -z "$(scan "$ANCHOR" | head -1)" ]; then
  echo "⚠ scan sanity check FAILED: anchor '$ANCHOR' returned 0 hits — the search is broken, not clean." >&2
  exit 3
fi

matches="$(scan "$SYMBOL")"
count="$(printf '%s' "$matches" | grep -c . || true)"
[ -n "$matches" ] && printf '%s\n' "$matches"
scope=$([ "$WITH_TESTS" -eq 1 ] && echo 'src+tests' || echo 'src only')
echo "─── ${count:-0} reference(s) to '$SYMBOL' ($scope, vendor excluded) ───"
