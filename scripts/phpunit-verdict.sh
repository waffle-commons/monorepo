#!/usr/bin/env bash
# =============================================================================
# scripts/phpunit-verdict.sh — refuse a PHPUnit run that "passed" with issues.
#
# PHPUnit exits 0 on "OK, but there were issues!" unless the component's
# phpunit.xml opts into the matching failOn* attribute, and the components opt
# in unevenly — none fails on PHPUnit notices, the test-double notices the
# PHPUnit 12.5 house rule forbids. A zero exit code is therefore not a clean
# run. The gates (scripts/dod.sh, `wfl check:all --with-tests`) read PHPUnit's
# own verdict line as well: only "OK (N tests, M assertions)" passes, and any
# "OK, but …" (issues, skipped, incomplete or risky tests) fails.
#
# Usage:   scripts/phpunit-verdict.sh <file holding the phpunit output>
# Exit:    0 clean · 1 anything but a clean "OK (…)" (verdict + counts printed)
#          · 2 no PHPUnit verdict line in the file
# =============================================================================
set -euo pipefail

out="${1:?usage: scripts/phpunit-verdict.sh <phpunit-output-file>}"
[ -r "$out" ] || { printf 'phpunit-verdict: cannot read %s\n' "$out" >&2; exit 2; }

# PHPUnit colours its summary (colors="true"): strip the ANSI escapes first.
plain="$(sed -E $'s/\x1b\\[[0-9;]*m//g' "$out")"

verdict="$(printf '%s\n' "$plain" | grep -E '^(OK|FAILURES!|ERRORS!|No tests executed!)' | tail -n 1 || true)"
case "$verdict" in
  'OK ('*)
    exit 0
    ;;
  '')
    printf 'phpunit-verdict: no PHPUnit verdict line in %s\n' "$out" >&2
    exit 2
    ;;
  *)
    printf '%s\n' "$verdict"
    printf '%s\n' "$plain" | grep -E '^Tests: ' | tail -n 1 || true
    exit 1
    ;;
esac
