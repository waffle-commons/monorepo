#!/usr/bin/env bash
# =============================================================================
# scripts/flake-hunt.sh — hunt for flaky/non-deterministic tests.
#
# Runs a component's PHPUnit suite N times in a row inside the dev container,
# each run writing a JUnit report. On the FIRST failing iteration it extracts
# the offending testcase (class::name + failure/error message) from the JUnit
# XML and prints it, then stops. If all N runs are green it reports "N/N green".
#
# Usage:   scripts/flake-hunt.sh <component> [N=20] [--filter=PATTERN]
# Exit:    0 if all N runs pass, 1 on the first failure (or container/setup error).
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_RST=""
fi
info() { printf '%s→ %s%s\n' "$C_CYA" "$*" "$C_RST"; }
ok()   { printf '%s✓ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s! %s%s\n' "$C_YEL" "$*" "$C_RST" >&2; }
die()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; exit 1; }

COMP="${1:-}"
[ -n "$COMP" ] || die "usage: scripts/flake-hunt.sh <component> [N=20] [--filter=PATTERN]"
shift || true

N=20
FILTER=""
for a in "$@"; do
  case "$a" in
    --filter=*) FILTER="${a#--filter=}" ;;
    *[!0-9]*)   die "unknown argument: '$a' (expected N or --filter=PATTERN)" ;;
    *)          N="$a" ;;
  esac
done
[ "$N" -gt 0 ] 2>/dev/null || die "N must be a positive integer (got '$N')"

[ -d "$REPO_ROOT/$COMP" ] || die "component directory missing: $REPO_ROOT/$COMP"

state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || printf 'absent')"
[ "$state" = "running" ] || die "container '$CONTAINER' not running (state: $state). Try: wfl up"

WORKDIR="/waffle-commons/$COMP"
JUNIT="var/data/phpunit-coverage/flake-junit.xml"

# Build the phpunit argv inside the container. Coverage is intentionally OFF
# (flake-hunting is about determinism, not coverage) for speed.
PU_ARGS=(--log-junit "$JUNIT" --no-coverage)
[ -n "$FILTER" ] && PU_ARGS+=(--filter "$FILTER")

info "flake-hunt — $COMP × ${N}${FILTER:+ (filter: $FILTER)}…"

i=1
while [ "$i" -le "$N" ]; do
  printf '%s  run %d/%d…%s ' "$C_CYA" "$i" "$N" "$C_RST"
  if docker exec -w "$WORKDIR" "$CONTAINER" vendor/bin/phpunit "${PU_ARGS[@]}" >/tmp/flake-run.$$ 2>&1; then
    printf '%s✓%s\n' "$C_GRN" "$C_RST"
  else
    printf '%s✗%s\n' "$C_RED" "$C_RST"
    warn "FAILURE on run $i/$N — extracting failing testcase(s):"
    # Pull the failing testcase(s) from the JUnit XML via in-container PHP.
    docker exec -w "$WORKDIR" -e FLAKE_JUNIT="$JUNIT" "$CONTAINER" php -r '
      $path = getenv("FLAKE_JUNIT");
      if (!is_file($path)) { fwrite(STDERR, "  (no JUnit report at $path)\n"); exit(0); }
      $prev = libxml_use_internal_errors(true);
      $xml = simplexml_load_file($path);
      libxml_use_internal_errors($prev);
      if ($xml === false) { fwrite(STDERR, "  (could not parse $path)\n"); exit(0); }
      $found = 0;
      foreach ($xml->xpath("//testcase") ?: [] as $c) {
          foreach (["failure" => $c->failure, "error" => $c->error] as $kind => $node) {
              if (isset($node)) {
                  $found++;
                  $cls = (string)($c["class"] ?? "");
                  $name = (string)($c["name"] ?? "");
                  $msg = trim((string)($node[0]["message"] ?? (string)$node[0]));
                  $first = strtok($msg, "\n");
                  fwrite(STDERR, sprintf("  [%s] %s::%s\n        %s\n", strtoupper($kind), $cls, $name, $first));
              }
          }
      }
      if ($found === 0) { fwrite(STDERR, "  (suite failed but no <failure>/<error> in JUnit — see raw output below)\n"); }
    ' >&2 || true
    # If JUnit yielded nothing useful, surface the tail of the raw run output.
    sed 's/^/      /' /tmp/flake-run.$$ | tail -n 20 >&2
    rm -f /tmp/flake-run.$$
    die "flaked at run $i/$N"
  fi
  i=$((i + 1))
done

rm -f /tmp/flake-run.$$
ok "${N}/${N} green — no flake detected${FILTER:+ (filter: $FILTER)}"
exit 0
