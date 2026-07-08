#!/usr/bin/env bash
# =============================================================================
# scripts/dod.sh — Definition of Done for a single component.
#
# Per the project bar, a modified component is "done" only when ALL of:
#   1. composer mago   → ZERO output (zero errors AND zero warnings/info/help)
#   2. composer tests  → green
#   3. line coverage   → ≥ 95% (scripts/coverage-percent.php, not HTML scraping)
#   4. composer igor   → 0 KO   ("not defined" is tolerated: no worker-safety run)
#   5. compare-audit   → optional SEC-03 gate (--compare-audit), 0 findings
#
# Everything runs inside the dev container (waffle-dev) via docker exec.
#
# Usage:   scripts/dod.sh <component> [--compare-audit]
# Exit:    0 if every gate passes, 1 otherwise.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"
THRESHOLD=95

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_BLD=""; C_RST=""
fi
info() { printf '%s→ %s%s\n' "$C_CYA" "$*" "$C_RST"; }
ok()   { printf '%s✓ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s! %s%s\n' "$C_YEL" "$*" "$C_RST" >&2; }
die()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; exit 1; }

COMP="${1:-}"
[ -n "$COMP" ] || die "usage: scripts/dod.sh <component> [--compare-audit]"
shift || true

WITH_AUDIT=0
for a in "$@"; do
  case "$a" in
    --compare-audit) WITH_AUDIT=1 ;;
    *) die "unknown option: '$a' (use --compare-audit)" ;;
  esac
done

# Validate the component against the single source of truth.
if ! "$REPO_ROOT/scripts/list-components.sh" | grep -qx "$COMP"; then
  die "unknown component: '$COMP' (see: scripts/list-components.sh)"
fi
[ -d "$REPO_ROOT/$COMP" ] || die "component directory missing: $REPO_ROOT/$COMP"

# Container must be running.
state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || printf 'absent')"
[ "$state" = "running" ] || die "container '$CONTAINER' not running (state: $state). Try: wfl up"

WORKDIR="/waffle-commons/$COMP"
dx() { docker exec -w "$WORKDIR" "$CONTAINER" "$@"; }

printf '%s%s═══ Definition of Done — %s ═══%s\n' "$C_BLD" "$C_CYA" "$COMP" "$C_RST"

fail=0

# --- 1. mago (zero output is clean) --------------------------------------
info "1/5 composer mago (must be ZERO output)…"
mago_out="$(dx composer mago 2>&1)"; mago_code=$?
# "Zero output" means zero DIAGNOSTICS. A clean mago run still emits its own
# confirmation lines (" INFO All files are already formatted.", " INFO No issues
# found.") and Composer echoes its "> vendor/bin/mago …" script lines — both are
# benign. Anything else on a non-blank line (WARNING/ERROR/HELP/NOTE or finding
# text), or a non-zero exit, means NOT clean. Native-first: no baselines.
mago_noise="$(printf '%s\n' "$mago_out" | grep -vE '^[[:space:]]*$|^> |^[[:space:]]*INFO ' || true)"
if [ "$mago_code" -eq 0 ] && [ -z "$mago_noise" ]; then
  ok "mago clean (zero diagnostics)"
else
  fail=1; warn "mago NOT clean (exit $mago_code)"
  printf '%s\n' "$mago_out" | sed 's/^/      /' >&2
fi

# --- 2. tests ------------------------------------------------------------
info "2/5 composer tests…"
if dx composer tests >/tmp/dod-tests.$$ 2>&1; then
  ok "tests green"
else
  fail=1; warn "tests FAILED"
  sed 's/^/      /' /tmp/dod-tests.$$ >&2
fi
rm -f /tmp/dod-tests.$$

# --- 3. coverage ≥ threshold --------------------------------------------
info "3/5 line coverage (≥ ${THRESHOLD}%)…"
pct="$(docker exec -w /waffle-commons "$CONTAINER" php scripts/coverage-percent.php "$COMP" 2>/tmp/dod-cov.$$)"; cov_code=$?
if [ "$cov_code" -ne 0 ] || [ -z "$pct" ]; then
  fail=1; warn "coverage unavailable"
  sed 's/^/      /' /tmp/dod-cov.$$ >&2
elif awk -v p="$pct" -v t="$THRESHOLD" 'BEGIN { exit !(p >= t) }'; then
  ok "coverage ${pct}% (≥ ${THRESHOLD}%)"
else
  fail=1; warn "coverage ${pct}% (< ${THRESHOLD}%)"
fi
rm -f /tmp/dod-cov.$$

# --- 4. igor (0 KO; "not defined" tolerated) -----------------------------
info "4/5 composer igor (0 KO)…"
igor_out="$(dx composer igor 2>&1)"; igor_code=$?
if printf '%s' "$igor_out" | grep -qiE 'not defined|no such|script .* is not'; then
  ok "igor not defined for '$COMP' (tolerated — no worker-safety surface)"
elif [ "$igor_code" -eq 0 ] && ! printf '%s' "$igor_out" | grep -qiE 'mutation of state|KO \(Dangerous State\): *[1-9]'; then
  # Trust Igor's own "KO (Dangerous State): N" tally (mirrors the canonical
  # root igor.sh): the bare word "KO" appears in the ZERO-count summary label
  # ("❌ KO (Dangerous State): 0"), so matching it produced a false KO. Only a
  # real "mutation of state" finding or a non-zero Dangerous-State count fails.
  ok "igor 0 KO"
else
  fail=1; warn "igor reported KO (exit $igor_code)"
  printf '%s\n' "$igor_out" | sed 's/^/      /' >&2
fi

# --- 5. optional compare-audit (SEC-03) ----------------------------------
if [ "$WITH_AUDIT" -eq 1 ]; then
  info "5/5 SEC-03 compare-audit…"
  if docker exec -w /waffle-commons "$CONTAINER" php scripts/sec03-compare-audit.php "$COMP" >/tmp/dod-audit.$$ 2>&1; then
    ok "compare-audit clean"
  else
    fail=1; warn "compare-audit FOUND timing-unsafe comparisons"
    sed 's/^/      /' /tmp/dod-audit.$$ >&2
  fi
  rm -f /tmp/dod-audit.$$
else
  info "5/5 compare-audit skipped (pass --compare-audit to include)"
fi

printf '%s%s───────────────────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$fail" -eq 0 ]; then
  ok "DoD PASS — $COMP"
  exit 0
fi
die "DoD FAIL — $COMP (see findings above)"
