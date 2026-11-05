#!/usr/bin/env bash
# drain-check — prove the skeleton's graceful-shutdown contract (OPS-02, RFC-023 §5.1) on one FrankenPHP
# image. It runs skeleton/docker/frankenphp/Caddyfile as shipped, in front of a stub worker app, and sends
# the container a SIGTERM:
#   1. CADDY_SHUTDOWN_DELAY unset (the image default, the Kubernetes path): a request in flight at SIGTERM
#      completes with 200 and the process exits 0.
#   2. CADDY_SHUTDOWN_DELAY set (no preStop hook): during the delay /readyz answers Caddy's 503 with the
#      public body while PHP still serves every other path; then the ports close, the request in flight
#      completes with 200 and the process exits 0.
# FrankenPHP 1.12.7 fails 2 (every PHP request during shutdown_delay got a 500); 1.13.1 fixed it. Re-run
# this on every FrankenPHP bump.
#
# Usage: scripts/drain-check.sh [image]   (default: the skeleton Dockerfile's pinned base image)
# Exit:  0 when every check passes, 1 otherwise.
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CADDYFILE="$SELF/skeleton/docker/frankenphp/Caddyfile"
DOCKERFILE="$SELF/skeleton/docker/Dockerfile"

arg_default() { sed -nE "s/^ARG $1='?([^']*)'?\$/\1/p" "$DOCKERFILE" | head -1; }
IMAGE="${1:-dunglas/frankenphp:$(arg_default FRANKEN_VERSION)-php$(arg_default PHP_VERSION)-$(arg_default OS)$(arg_default FRANKEN_DIGEST)}"
DELAY=4

mkdir -p "$SELF/tmp"
WORK="$(mktemp -d "$SELF/tmp/drain-check.XXXXXX")"
mkdir -p "$WORK/public"
cat > "$WORK/public/index.php" <<'PHP'
<?php

declare(strict_types=1);

// drain-check stub: every path answers 200 from PHP; ?sleep=<ms> holds the request open.
$handler = static function (): void {
    $sleep = (int) ($_GET['sleep'] ?? 0);
    if ($sleep > 0) {
        usleep($sleep * 1000);
    }
    header('Content-Type: application/json');
    header('X-Served-By: php');
    echo '{"status":"ok"}';
};

while (frankenphp_handle_request($handler)) {
    gc_collect_cycles();
}
PHP

failures=0
NAME="drain-check-$$"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*"; failures=$((failures + 1)); }

# probe <path> → "<status> <served-by> <body>" (status 000 when nothing answered).
probe() {
  local headers="$WORK/headers" body="$WORK/body" code
  : > "$headers"; : > "$body"
  code="$(curl -s -m 3 -D "$headers" -o "$body" -w '%{http_code}' "http://127.0.0.1:$PORT$1")" || code="${code:-000}"
  local by; by="$(tr -d '\r' < "$headers" | sed -n 's/^[Xx]-[Ss]erved-[Bb]y: //p' | head -1)"
  echo "$code ${by:-caddy} $(cat "$body")"
}

start() { # $1 = extra env flag or empty
  docker rm -f "$NAME" >/dev/null 2>&1
  local env=(-e SERVER_NAME=:80 -e "FRANKENPHP_CONFIG=worker ./public/index.php")
  [ -n "$1" ] && env+=(-e "$1")
  docker run -d --name "$NAME" -p 127.0.0.1::80 -w /app -v "$WORK:/app:ro" \
    -v "$CADDYFILE:/etc/caddy/Caddyfile:ro" "${env[@]}" "$IMAGE" \
    frankenphp run --config /etc/caddy/Caddyfile >/dev/null || return 1
  PORT="$(docker port "$NAME" 80/tcp | head -1 | sed 's/.*://')"
  local i=0
  until [ "$(probe /readyz | cut -d' ' -f1-2)" = "200 php" ]; do
    i=$((i + 1)); [ "$i" -ge 40 ] && return 1; sleep 0.5
  done
}

finish() { # $1 = in-flight result file, $2 = in-flight pid, $3 = stopper pid
  wait "$2"; wait "$3"
  local inflight; inflight="$(cat "$1")"
  [ "$inflight" = 200 ] && pass "request in flight at SIGTERM completed with 200" \
    || fail "request in flight at SIGTERM ended with $inflight"
  local code; code="$(docker inspect --format '{{.State.ExitCode}}' "$NAME")"
  [ "$code" = 0 ] && pass "process exited 0" || fail "process exited $code"
  local errors; errors="$(docker logs "$NAME" 2>&1 | grep -c -i -E 'not running|panic|fatal|segfault|corrupt')"
  [ "$errors" = 0 ] && pass "no crash or 'not running' line in the log" || fail "$errors crash or 'not running' line(s) in the log"
}

docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull -q "$IMAGE" >/dev/null || { echo "✗ cannot pull $IMAGE"; exit 1; }
echo "→ drain-check on $IMAGE ($(docker run --rm --entrypoint frankenphp "$IMAGE" version | cut -d' ' -f1-4))"

echo "1. CADDY_SHUTDOWN_DELAY unset (default, the Kubernetes path)"
if start ""; then
  curl -s -o /dev/null -m 20 -w '%{http_code}' "http://127.0.0.1:$PORT/?sleep=2000" > "$WORK/inflight1" &
  inflight=$!
  sleep 0.5
  docker stop -t 30 "$NAME" >/dev/null &
  stopper=$!
  finish "$WORK/inflight1" "$inflight" "$stopper"
else
  fail "the container did not become ready"
fi

echo "2. CADDY_SHUTDOWN_DELAY=${DELAY}s (no preStop hook)"
if start "CADDY_SHUTDOWN_DELAY=${DELAY}s"; then
  curl -s -o /dev/null -m 20 -w '%{http_code}' "http://127.0.0.1:$PORT/?sleep=$(( (DELAY + 2) * 1000 ))" > "$WORK/inflight2" &
  inflight=$!
  sleep 0.5
  docker stop -t 30 "$NAME" >/dev/null &
  stopper=$!
  sleep 1
  ready="$(probe /readyz)"
  other="$(probe /)"
  [ "$ready" = '503 caddy {"status":"unavailable"}' ] && pass "/readyz during the delay: 503 from Caddy, public body" \
    || fail "/readyz during the delay: $ready"
  [ "$(echo "$other" | cut -d' ' -f1-2)" = "200 php" ] && pass "/ during the delay: 200 from PHP" \
    || fail "/ during the delay: $other"
  sleep $((DELAY))
  closed="$(probe / | cut -d' ' -f1)"
  [ "$closed" = 000 ] && pass "ports closed after the delay" || fail "after the delay / still answered $closed"
  finish "$WORK/inflight2" "$inflight" "$stopper"
else
  fail "the container did not become ready"
fi

if [ "$failures" -gt 0 ]; then
  echo "✗ drain-check: $failures check(s) failed on $IMAGE"
  exit 1
fi
echo "✓ drain-check: the skeleton's shutdown contract holds on $IMAGE"
