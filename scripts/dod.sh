#!/usr/bin/env bash
# =============================================================================
# scripts/dod.sh — Definition of Done for a single component.
#
# Per the project bar, a modified component is "done" only when ALL of:
#   1. composer mago   → ZERO output (zero errors AND zero warnings/info/help)
#   2. composer tests  → green
#   3. line coverage   → ≥ 95% (scripts/coverage-percent.php, not HTML scraping)
#   4. composer igor   → 0 KO with the pinned auditor (.igor-version); a stale
#                        binary fails the gate ("not defined" is tolerated)
#   5. compare-audit   → optional SEC-03 gate (--compare-audit), 0 findings
#
# Steps 2–3 are N/A only while the component holds no PHP outside tests/ (a
# fresh scaffold); the first class switches the full bar on.
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
# Demo-app policy, the same as umbrella-ci's workspace job: the contributor
# playground keeps the mago, tests-green and igor gates, but its coverage is
# reported, not gated. Everything released (skeleton included) holds the bar.
COVERAGE_EXEMPT=" workspace "

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
# The mago composer package fetches its binary on first use and prints a
# download progress bar; warm it first so that banner is never read as a finding.
dx sh -c 'test -x vendor/bin/mago && vendor/bin/mago --version' >/dev/null 2>&1 || true
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

# A freshly scaffolded component has no source yet: PHPUnit has no test to run
# and no file to measure. Tests and coverage are N/A until the first PHP file
# lands outside tests/ (src/, or app/ for the workspace) — from then on the full
# bar applies. mago and igor always run.
scaffold=0
if ! find "$REPO_ROOT/$COMP" \( -name vendor -o -name tests -o -name var -o -name .git \) -prune \
     -o -type f -name '*.php' -print 2>/dev/null | grep -q .; then
  scaffold=1
fi

# --- 2. tests ------------------------------------------------------------
info "2/5 composer tests…"
if [ "$scaffold" -eq 1 ]; then
  ok "tests N/A — scaffold: no PHP source outside tests/ yet"
elif dx composer tests >/tmp/dod-tests.$$ 2>&1; then
  ok "tests green"
else
  fail=1; warn "tests FAILED"
  sed 's/^/      /' /tmp/dod-tests.$$ >&2
fi
rm -f /tmp/dod-tests.$$

# --- 3. coverage ≥ threshold --------------------------------------------
info "3/5 line coverage (≥ ${THRESHOLD}%)…"
pct=""; cov_code=0
[ "$scaffold" -eq 0 ] && { pct="$(docker exec -w /waffle-commons "$CONTAINER" php scripts/coverage-percent.php "$COMP" 2>/tmp/dod-cov.$$)"; cov_code=$?; }
if [ "$scaffold" -eq 1 ]; then
  ok "coverage N/A — scaffold: no PHP source outside tests/ yet"
elif [ "$cov_code" -ne 0 ] || [ -z "$pct" ]; then
  fail=1; warn "coverage unavailable"
  sed 's/^/      /' /tmp/dod-cov.$$ >&2
elif awk -v p="$pct" -v t="$THRESHOLD" 'BEGIN { exit !(p >= t) }'; then
  ok "coverage ${pct}% (≥ ${THRESHOLD}%)"
elif [[ "$COVERAGE_EXEMPT" == *" $COMP "* ]]; then
  ok "coverage ${pct}% — reported, not gated (demo-app policy, as in umbrella-ci)"
else
  fail=1; warn "coverage ${pct}% (< ${THRESHOLD}%)"
fi
rm -f /tmp/dod-cov.$$

# --- 4. igor (0 KO; "not defined" tolerated) -----------------------------
# The bootstrapper downloads releases/latest unless its version file says
# otherwise, so seed the pinned auditor (.igor-version, as igor.sh and CI do)
# and refuse to trust a result produced by any other binary.
IGOR_VERSION="${IGOR_VERSION:-$(tr -d '[:space:]' < "$REPO_ROOT/.igor-version")}"
info "4/5 composer igor (0 KO, auditor ${IGOR_VERSION})…"
igor_bin_dir="vendor/igor-php/igor-php/resources/bin"
igor_version_out=""
if dx test -x vendor/bin/igor-php 2>/dev/null; then
  dx sh -c "mkdir -p '$igor_bin_dir' && printf '%s' '$IGOR_VERSION' > '$igor_bin_dir/.version'" >/dev/null 2>&1
  igor_version_out="$(dx vendor/bin/igor-php --version 2>&1 || true)"
fi
igor_out="$(dx composer igor 2>&1)"; igor_code=$?
if [ -n "$igor_version_out" ] && ! printf '%s\n' "$igor_version_out" | grep -qFx "igor-php version $IGOR_VERSION"; then
  fail=1; warn "igor auditor is not ${IGOR_VERSION} — a stale binary sits in $igor_bin_dir (delete it to re-fetch)"
  printf '%s\n' "$igor_version_out" | sed 's/^/      /' >&2
elif printf '%s' "$igor_out" | grep -qiE 'not defined|no such|script .* is not'; then
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
