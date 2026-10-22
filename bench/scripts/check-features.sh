#!/usr/bin/env bash
# bench/scripts/check-features.sh — before any measured run, check that each
# engine does the per-request work the bench attributes to it (CARRY-02).
#
#   usage: check-features.sh [engine ...]      (default: engine-a engine-c engine-d)
#
# Engine A (Waffle) and Engine D (its Symfony mirror) must refuse an untrusted
# Host (400) and a junk bearer token (401), send the three security headers, and
# commit one transaction per POST /greet, a route that touches no table. Engine
# C, the bare control, must do none of that. Requests go to the loopback ports
# with Host: localhost, which every engine trusts. One engine at a time, like
# run-bench.sh; exits 1 on any mismatch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE=(docker compose -f "$SCRIPT_DIR/../docker-compose.bench.yml")
GREETS=200

port_of() {
  case "$1" in
    engine-a) echo 8081 ;;
    engine-c) echo 8083 ;;
    engine-d) echo 8087 ;;
    *) echo "error: no feature expectations for '$1' (engine-a, engine-c, engine-d)" >&2; exit 2 ;;
  esac
}

# A runs Waffle's secured pipeline and D mirrors it; C is the bare control.
secured() { [[ "$1" == "engine-a" || "$1" == "engine-d" ]]; }

log() { printf '[check-features %s] %s\n' "$(date +%H:%M:%S)" "$*"; }

FAILS=0
check() { # <label> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    printf '  ok    %-40s %s\n' "$1" "$3"
  else
    printf '  FAIL  %-40s expected %s, got %s\n' "$1" "$2" "$3"
    FAILS=$((FAILS + 1))
  fi
}

http_status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

commits() {
  "${COMPOSE[@]}" exec -T bench-postgres psql -U waffle -d waffle -Atc \
    "SELECT xact_commit FROM pg_stat_database WHERE datname = 'waffle'"
}

if [[ $# -gt 0 ]]; then ENGINES=("$@"); else ENGINES=(engine-a engine-c engine-d); fi
for engine in "${ENGINES[@]}"; do port_of "$engine" >/dev/null; done

CURRENT=""
trap '[[ -z "$CURRENT" ]] || "${COMPOSE[@]}" rm -sf "$CURRENT" >/dev/null 2>&1 || true' EXIT

"${COMPOSE[@]}" up -d bench-postgres >/dev/null
PG_OK=0
for _ in $(seq 1 30); do
  if "${COMPOSE[@]}" exec -T bench-postgres pg_isready -q -U waffle -d waffle 2>/dev/null; then
    PG_OK=1; break
  fi
  sleep 2
done
[[ "$PG_OK" -eq 1 ]] || { echo "error: bench-postgres not ready after 60s" >&2; exit 1; }

for engine in "${ENGINES[@]}"; do
  base="http://127.0.0.1:$(port_of "$engine")"
  log "$engine: starting (force-recreate, alone with bench-postgres)"
  CURRENT="$engine"
  "${COMPOSE[@]}" up -d --force-recreate "$engine" >/dev/null
  up=0
  for _ in $(seq 1 36); do
    if [[ "$(http_status -H 'Host: localhost' "$base/")" == "200" ]]; then up=1; break; fi
    sleep 5
  done
  [[ "$up" -eq 1 ]] || { echo "error: $engine never answered GET / with 200 within 180s" >&2; exit 1; }

  if secured "$engine"; then host=400; bearer=401; headers=3; else host=200; bearer=200; headers=0; fi
  check "untrusted Host" "$host" "$(http_status -H 'Host: evil.example' "$base/")"
  check "junk bearer token" "$bearer" \
    "$(http_status -H 'Host: localhost' -H 'Authorization: Bearer not-a-token' "$base/")"
  response="$(curl -s -o /dev/null -D - -H 'Host: localhost' "$base/")"
  check "security headers (nosniff, DENY, CSP)" "$headers" \
    "$(grep -ciE "^(x-content-type-options: nosniff|x-frame-options: deny|content-security-policy: default-src 'self')" <<<"$response" || true)"
  # Informational: k6 empties its cookie jar after every iteration, so a
  # cookie-less request is what most bench requests look like.
  printf '  info  %-40s %s\n' "Set-Cookie on a cookie-less GET /" \
    "$(grep -ci '^set-cookie:' <<<"$response" || true)"

  before="$(commits)"
  greeted=0
  for _ in $(seq 1 "$GREETS"); do
    if [[ "$(http_status -H 'Host: localhost' -H 'Content-Type: application/json' \
          -d '{"name":"Ada"}' "$base/greet")" == "200" ]]; then
      greeted=$((greeted + 1))
    fi
  done
  check "POST /greet answered 200" "$GREETS" "$greeted"
  # Stop the engine before reading: a backend flushes its statistics when it
  # exits, but an idle one can hold them for up to 10 s (PGSTAT_IDLE_INTERVAL).
  "${COMPOSE[@]}" rm -sf "$engine" >/dev/null
  CURRENT=""
  sleep 1
  delta=$(( $(commits) - before ))
  if secured "$engine"; then
    want="at least $GREETS"; ok=$(( delta >= GREETS ))
  else
    want="under $(( GREETS / 10 ))"; ok=$(( delta < GREETS / 10 ))
  fi
  if [[ "$ok" -eq 1 ]]; then
    printf '  ok    %-40s %s\n' "commits for $GREETS POST /greet ($want)" "$delta"
  else
    printf '  FAIL  %-40s %s\n' "commits for $GREETS POST /greet ($want)" "$delta"
    FAILS=$((FAILS + 1))
  fi
done

log "bench-postgres left running (docker compose -f docker-compose.bench.yml down to stop)"
if [[ "$FAILS" -gt 0 ]]; then
  echo "$FAILS check(s) failed" >&2
  exit 1
fi
log "every check passed"
