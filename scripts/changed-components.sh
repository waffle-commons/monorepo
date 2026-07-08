#!/usr/bin/env bash
# changed-components — list the umbrella root + each submodule that has uncommitted
# git changes. The recurrent "what's dirty / what would I be committing?" check —
# review/commit prep, especially after a multi-component wave left things UNCOMMITTED.
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SELF"

dirty=0
report() {
  local label="$1" dir="$2"
  local n
  n="$(git -C "$dir" status --porcelain 2>/dev/null | grep -c . || true)"
  if [ "${n:-0}" -gt 0 ]; then
    printf '  ● %-24s %3s change(s)\n' "$label" "$n"
    dirty=$((dirty + 1))
  fi
}

echo "═══ uncommitted changes (umbrella + submodules) ═══"
report "(umbrella root)" "$SELF"
if [ -x "$SELF/scripts/list-components.sh" ]; then
  while IFS= read -r comp; do
    [ -n "$comp" ] || continue
    report "$comp" "$SELF/$comp"
  done < <("$SELF/scripts/list-components.sh" 2>/dev/null)
fi
echo "───────────────────────────────────────────────────"
if [ "$dirty" -eq 0 ]; then
  echo "✓ working tree clean across all tracked locations"
else
  echo "● $dirty location(s) with uncommitted changes"
fi
