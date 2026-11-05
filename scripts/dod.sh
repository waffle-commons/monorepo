#!/usr/bin/env bash
# =============================================================================
# scripts/dod.sh — Definition of Done for a single component.
#
# Per the project bar, a modified component is "done" only when ALL of:
#   1. composer mago   → ZERO output (zero errors AND zero warnings/info/help)
#   2. composer tests  → green: exit 0 AND a clean "OK (…)" verdict — no issues,
#                        skipped, incomplete or risky tests (phpunit-verdict.sh)
#   3. line coverage   → ≥ 95% (scripts/coverage-percent.php, not HTML scraping)
#                        and never below the component's floor in .coverage-floors
#                        (a ratchet: `wfl coverage:ratchet` raises it, nothing lowers it)
#   4. composer igor   → 0 KO with the pinned auditor (.igor-version); a stale
#                        binary fails the gate ("not defined" is tolerated)
#   5. composer audit  → no security advisory on the locked dependencies; skipped,
#                        and said so, only when the advisory database is unreachable
#   6. compare-audit   → optional SEC-03 gate (--compare-audit), 0 findings
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
FLOORS="$REPO_ROOT/.coverage-floors"
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
info "1/6 composer mago (must be ZERO output)…"
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
# `-print -quit` stops at the first PHP file and its output is read whole. A
# `find | grep -q .` pipe broke under `set -o pipefail`: grep quit at the first
# line, find died of SIGPIPE, and a real component read as an empty scaffold,
# so its tests and coverage were skipped (contracts, every run).
scaffold=0
if [ -z "$(find "$REPO_ROOT/$COMP" \( -name vendor -o -name tests -o -name var -o -name .git \) -prune \
     -o -type f -name '*.php' -print -quit 2>/dev/null)" ]; then
  scaffold=1
fi

# --- 2. tests ------------------------------------------------------------
# A zero exit code is not enough: PHPUnit exits 0 on "OK, but there were
# issues!" unless phpunit.xml opts into failOn*, so its verdict line is read
# too (scripts/phpunit-verdict.sh) — only a clean "OK (…)" is green.
info "2/6 composer tests…"
if [ "$scaffold" -eq 1 ]; then
  ok "tests N/A — scaffold: no PHP source outside tests/ yet"
elif dx composer tests >/tmp/dod-tests.$$ 2>&1; then
  if verdict="$("$REPO_ROOT/scripts/phpunit-verdict.sh" /tmp/dod-tests.$$ 2>&1)"; then
    ok "tests green"
  else
    fail=1; warn "tests passed with PHPUnit issues — only a clean \"OK (…)\" run is green"
    printf '%s\n' "$verdict" | sed 's/^/      /' >&2
    printf '      details: docker exec -w /waffle-commons/%s %s vendor/bin/phpunit --no-coverage --display-all-issues\n' \
      "$COMP" "$CONTAINER" >&2
  fi
else
  fail=1; warn "tests FAILED"
  sed 's/^/      /' /tmp/dod-tests.$$ >&2
fi
rm -f /tmp/dod-tests.$$

# --- 3. coverage ≥ threshold --------------------------------------------
info "3/6 line coverage (≥ ${THRESHOLD}%)…"
pct=""; cov_code=0
[ "$scaffold" -eq 0 ] && { pct="$(docker exec -w /waffle-commons "$CONTAINER" php scripts/coverage-percent.php "$COMP" 2>/tmp/dod-cov.$$)"; cov_code=$?; }
if [ "$scaffold" -eq 1 ]; then
  ok "coverage N/A — scaffold: no PHP source outside tests/ yet"
elif [ "$cov_code" -ne 0 ] || [ -z "$pct" ]; then
  fail=1; warn "coverage unavailable"
  sed 's/^/      /' /tmp/dod-cov.$$ >&2
elif floor="$(awk -v c="$COMP" '$1 == c { print $2 }' "$FLOORS" 2>/dev/null)" && [ -n "$floor" ] \
     && awk -v p="$pct" -v f="$floor" 'BEGIN { exit !(p + 0.005 < f) }'; then
  fail=1; warn "coverage ${pct}% fell below its floor ${floor}% (.coverage-floors: the ratchet only goes up)"
elif awk -v p="$pct" -v t="$THRESHOLD" 'BEGIN { exit !(p >= t) }'; then
  ok "coverage ${pct}% (≥ ${THRESHOLD}%${floor:+, floor ${floor}%})"
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
info "4/6 composer igor (0 KO, auditor ${IGOR_VERSION})…"
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

# --- 5. composer audit (security advisories on the locked dependencies) --
# A library ships no lock file, but the dev checkout has one: auditing it covers
# what the tests ran against. Unreachable advisories are reported as skipped,
# never as clean.
info "5/6 composer audit (security advisories)…"
if ! dx test -f composer.lock 2>/dev/null; then
  ok "composer audit N/A — no composer.lock"
else
  audit_out="$(dx composer audit --locked --format=plain 2>&1)"; audit_code=$?
  if [ "$audit_code" -eq 0 ]; then
    ok "composer audit: no advisories on the locked dependencies"
  elif printf '%s' "$audit_out" | grep -qiE 'curl error|could not resolve|failed to download|network is unreachable|timed out'; then
    info "5/6 composer audit skipped — the advisory database is unreachable (offline)"
  else
    fail=1; warn "composer audit FOUND advisories or abandoned packages (exit $audit_code)"
    printf '%s\n' "$audit_out" | sed 's/^/      /' >&2
  fi
fi

# --- 6. optional compare-audit (SEC-03) ----------------------------------
if [ "$WITH_AUDIT" -eq 1 ]; then
  info "6/6 SEC-03 compare-audit…"
  if docker exec -w /waffle-commons "$CONTAINER" php scripts/sec03-compare-audit.php "$COMP" >/tmp/dod-audit.$$ 2>&1; then
    ok "compare-audit clean"
  else
    fail=1; warn "compare-audit FOUND timing-unsafe comparisons"
    sed 's/^/      /' /tmp/dod-audit.$$ >&2
  fi
  rm -f /tmp/dod-audit.$$
else
  info "6/6 compare-audit skipped (pass --compare-audit to include)"
fi

printf '%s%s───────────────────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$fail" -eq 0 ]; then
  ok "DoD PASS — $COMP"
  exit 0
fi
die "DoD FAIL — $COMP (see findings above)"
