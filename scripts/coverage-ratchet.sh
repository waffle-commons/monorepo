#!/usr/bin/env bash
# =============================================================================
# scripts/coverage-ratchet.sh — raise each component's coverage floor.
#
# .coverage-floors holds one "<component> <percent>" line per component. The
# DoD gate (scripts/dod.sh, step 3) fails a component whose line coverage falls
# below its floor, on top of the flat 95 % bar, so coverage can only go up.
# This script reads each component's last Clover report (written by `wfl dod`
# or `composer tests`) and raises the floor to it (two decimals, rounded down);
# it never lowers one. Run `wfl dod <component>` first for a fresh figure.
# Edit the file by hand, in a reviewed commit, to lower a floor on purpose.
#
# Usage:   scripts/coverage-ratchet.sh <component…> | --all [--dry-run]
# Exit:    0 on success, 1 when a measurement failed.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FLOORS="$REPO_ROOT/.coverage-floors"
CONTAINER="waffle-dev"
# Reported, not gated (scripts/dod.sh COVERAGE_EXEMPT); a scaffold has nothing to measure.
EXEMPT=" workspace component-template documentation academy "

DRY_RUN=0
COMPONENTS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --all)     while IFS= read -r c; do COMPONENTS+=("$c"); done < <("$REPO_ROOT/scripts/list-components.sh") ;;
    -*)        printf '✗ unknown option: %s\n' "$a" >&2; exit 1 ;;
    *)         COMPONENTS+=("$a") ;;
  esac
done
[ "${#COMPONENTS[@]}" -gt 0 ] || { printf 'usage: scripts/coverage-ratchet.sh <component…> | --all [--dry-run]\n' >&2; exit 1; }
[ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)" = running ] || { printf '✗ %s is not running (wfl up)\n' "$CONTAINER" >&2; exit 1; }
[ -f "$FLOORS" ] || printf '# Coverage floors: the DoD fails a component below its floor. Raised by `wfl coverage:ratchet`, never lowered by a tool.\n' > "$FLOORS"

failed=0
for comp in "${COMPONENTS[@]}"; do
  if [[ "$EXEMPT" == *" $comp "* ]]; then
    printf '  · %-18s exempt\n' "$comp"
    continue
  fi
  if [ -z "$(find "$REPO_ROOT/$comp" \( -name vendor -o -name tests -o -name var -o -name .git \) -prune -o -type f -name '*.php' -print -quit 2>/dev/null)" ]; then
    printf '  · %-18s scaffold (no source yet)\n' "$comp"
    continue
  fi
  pct="$(docker exec -w /waffle-commons "$CONTAINER" php scripts/coverage-percent.php "$comp" 2>/dev/null)"
  if [ -z "$pct" ]; then
    printf '  ✗ %-18s coverage unavailable\n' "$comp"
    failed=1
    continue
  fi
  new="$(awk -v p="$pct" 'BEGIN { printf "%.2f", int(p * 100) / 100 }')"
  old="$(awk -v c="$comp" '$1 == c { print $2 }' "$FLOORS")"
  if [ -n "$old" ] && awk -v n="$new" -v o="$old" 'BEGIN { exit !(n <= o) }'; then
    printf '  = %-18s %s%% (floor %s%% kept)\n' "$comp" "$pct" "$old"
    continue
  fi
  printf '  ↑ %-18s %s%% → floor %s%% (was %s)\n' "$comp" "$pct" "$new" "${old:-none}"
  if [ "$DRY_RUN" -eq 0 ]; then
    tmp="$(mktemp "$FLOORS.XXXXXX")"
    awk -v c="$comp" '$1 != c' "$FLOORS" > "$tmp"
    printf '%s %s\n' "$comp" "$new" >> "$tmp"
    { grep '^#' "$tmp"; grep -v '^#' "$tmp" | sort; } > "$FLOORS"
    rm -f "$tmp"
  fi
done
exit "$failed"
