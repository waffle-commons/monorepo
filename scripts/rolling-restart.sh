#!/usr/bin/env bash
# rolling-restart — check the OPS acceptance criterion "a rolling restart under k6 load loses zero in-flight
# requests" (Roadmap_Beta7 OPS, RFC-023 §5.1) on this machine.
#
# Two replicas of Engine A (the skeleton's production image built from this tree, running the skeleton's
# Caddyfile as shipped) sit behind a load balancer that polls /readyz and never retries
# (bench/docker-compose.rolling.yml). k6 runs natively at a constant RATE through it while each replica in
# turn is drained, sent SIGTERM, restarted and waited for:
#   --path=marker  the Kubernetes path: a preStop step creates the drain marker and waits PRESTOP_SLEEP,
#                  then SIGTERM; CADDY_SHUTDOWN_DELAY stays at the image default, 0s (the default path)
#   --path=delay   no preStop hook (Docker, Compose, ECS): SIGTERM with CADDY_SHUTDOWN_DELAY=5s, as
#                  skeleton/docker-compose.prod.yml sets it
#   --path=none    the control: SIGTERM with neither. It must lose requests, or the check proves nothing.
# PASS = every request answered 2xx, each replica exited 0 within its stop grace and came back ready while
# k6 was still running, and both replicas served traffic. One laptop: a correctness check, never a
# capacity figure.
#
# Usage: scripts/rolling-restart.sh [--path=marker|delay|none] [--rate=N] [--build]
#        RATE (100), DURATION_S (75), PRESTOP_SLEEP (5), SETTLE (8) and RUN_ID also come from the environment.
# Exit:  0 on PASS, 1 on FAIL (the expected verdict of --path=none), 2 on a usage or setup error.
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$SELF/bench"

PATH_NAME="marker"
BUILD=0
RATE="${RATE:-100}"
for arg in "$@"; do
  case "$arg" in
    --path=marker|--path=delay|--path=none) PATH_NAME="${arg#--path=}" ;;
    --rate=*) RATE="${arg#--rate=}" ;;
    --build) BUILD=1 ;;
    *) echo "usage: scripts/rolling-restart.sh [--path=marker|delay|none] [--rate=N] [--build]" >&2; exit 2 ;;
  esac
done
[[ "$RATE" =~ ^[1-9][0-9]*$ ]] || { echo "error: --rate must be a positive integer" >&2; exit 2; }
DURATION_S="${DURATION_S:-75}"
PRESTOP_SLEEP="${PRESTOP_SLEEP:-5}"
SETTLE="${SETTLE:-8}"
WARM=10
STOP_GRACE=35
REPLICAS=(1 2)

case "$PATH_NAME" in
  delay) export CADDY_SHUTDOWN_DELAY=5s ;;
  *) export CADDY_SHUTDOWN_DELAY=0s ;;
esac

COMPOSE=(docker compose -f "$BENCH/docker-compose.bench.yml" -f "$BENCH/docker-compose.rolling.yml")
command -v k6 >/dev/null || { echo "error: k6 is not installed (it runs natively, off the replicas' CPUs)" >&2; exit 2; }

RUN_ID="${RUN_ID:-$(date -u '+%Y%m%dT%H%M%SZ')}"
[[ "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: RUN_ID must match [A-Za-z0-9._-]+" >&2; exit 2; }
OUT="$BENCH/results/rolling-restart-$PATH_NAME-$RUN_ID"
[[ ! -e "$OUT" ]] || { echo "error: $OUT exists: a run never overwrites another" >&2; exit 2; }
mkdir -p "$OUT"
EVENTS="$OUT/events.log"

now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }
stamp() { perl -MTime::HiRes=time -MPOSIX=strftime -e '$t = time; printf "%s.%03dZ\n", strftime("%Y-%m-%dT%H:%M:%S", gmtime($t)), ($t - int $t) * 1000'; }
event() { printf '%s  %s\n' "$(stamp)" "$*" | tee -a "$EVENTS"; }
status_of() { curl -s -o /dev/null -m 2 -w '%{http_code}' "$1" 2>/dev/null || true; }

K6_PID=""
STACK_UP=0
cleanup() {
  [[ -n "$K6_PID" ]] && kill "$K6_PID" 2>/dev/null
  [[ "$STACK_UP" -eq 1 ]] || return 0
  for n in "${REPLICAS[@]}"; do docker logs "rolling-app-$n" > "$OUT/app-$n.log" 2>&1 || true; done
  docker logs rolling-lb > "$OUT/lb.log" 2>&1 || true
  "${COMPOSE[@]}" rm -sf app-1 app-2 lb >/dev/null 2>&1 || true
  # The dbwrite workload inserted rows: reseed, as run-bench.sh does after a writing scenario.
  "${COMPOSE[@]}" exec -T bench-postgres psql -q -U waffle -d waffle -v ON_ERROR_STOP=1 \
    < "$BENCH/sql/init.sql" >/dev/null 2>&1 || echo "! reseeding bench-postgres failed" >&2
}
trap cleanup EXIT

wait_ready() {  # $1 = URL, $2 = timeout in seconds
  local deadline=$(( $(date +%s) + $2 ))
  while [[ "$(status_of "$1")" != 200 ]]; do
    (( $(date +%s) < deadline )) || return 1
    sleep 0.2
  done
}

if [[ "$BUILD" -eq 1 ]]; then
  event "building Engine A from this tree"
  "${COMPOSE[@]}" build engine-a >"$OUT/build.log" 2>&1 || { echo "error: build failed, see $OUT/build.log" >&2; exit 2; }
fi
docker image inspect waffle-bench-engine-a >/dev/null 2>&1 || { echo "error: no waffle-bench-engine-a image (pass --build)" >&2; exit 2; }

event "path=$PATH_NAME rate=${RATE}/s duration=${DURATION_S}s CADDY_SHUTDOWN_DELAY=$CADDY_SHUTDOWN_DELAY"
"${COMPOSE[@]}" up -d --wait bench-postgres >/dev/null 2>&1 || { echo "error: bench-postgres did not start" >&2; exit 2; }
STACK_UP=1
"${COMPOSE[@]}" up -d --force-recreate app-1 app-2 lb >"$OUT/up.log" 2>&1 || { echo "error: the stack did not start, see $OUT/up.log" >&2; exit 2; }
for n in "${REPLICAS[@]}"; do
  wait_ready "http://127.0.0.1:809$n/readyz" 60 || { echo "error: rolling-app-$n never became ready" >&2; exit 2; }
done
wait_ready "http://127.0.0.1:8093/readyz" 30 || { echo "error: the load balancer never answered 200" >&2; exit 2; }
event "both replicas ready; warming up through the load balancer"
for _ in $(seq 1 200); do curl -s -o /dev/null -m 2 "http://127.0.0.1:8093/hello/warm"; done

# The environment travels with the run: host, Docker VM, images, versions, knobs.
{
  echo "run_id: $RUN_ID"
  echo "recorded_at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "host: $(uname -srm) | $(sysctl -n machdep.cpu.brand_string 2>/dev/null || awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo)"
  echo "docker: $(docker info --format '{{.ServerVersion}} {{.OperatingSystem}} cpus={{.NCPU}} mem={{.MemTotal}}')"
  echo "subject image: $(docker image inspect waffle-bench-engine-a --format '{{.Id}} created {{.Created}}')"
  echo "runtime: $(docker exec rolling-app-1 frankenphp version)"
  echo "lb image: $(docker inspect rolling-lb --format '{{.Config.Image}}')"
  echo "k6: $(k6 version | head -1)"
  echo "umbrella: $(git -C "$SELF" rev-parse --short HEAD)$( [[ -n "$(git -C "$SELF" status --porcelain | head -1)" ]] && echo ' (dirty)')"
  echo "knobs: path=$PATH_NAME rate=$RATE duration_s=$DURATION_S prestop_sleep=$PRESTOP_SLEEP settle=$SETTLE stop_grace=$STOP_GRACE CADDY_SHUTDOWN_DELAY=$CADDY_SHUTDOWN_DELAY replicas=${#REPLICAS[@]} workers=4 MAX_REQUESTS=1000000"
} > "$OUT/environment.txt"

K6_START="$(now)"
# samples.csv.gz holds every sample with its time in ms: the per-replica timeline below comes from it.
K6_CSV_TIME_FORMAT=unix_milli k6 run -q --no-color --out csv="$OUT/samples.csv.gz" \
  -e TARGET=http://127.0.0.1:8093 -e RATE="$RATE" -e DURATION="${DURATION_S}s" \
  -e OUT="$OUT/k6-summary.json" "$BENCH/k6/scenarios/rolling-restart.js" >"$OUT/k6.log" 2>&1 &
K6_PID=$!
event "k6 started"
sleep "$WARM"

FAILURES=0
for n in "${REPLICAS[@]}"; do
  name="rolling-app-$n"
  if [[ "$PATH_NAME" == marker ]]; then
    docker exec "$name" touch /tmp/waffle-draining
    event "$name: preStop — drain marker created, sleeping ${PRESTOP_SLEEP}s"
    sleep "$PRESTOP_SLEEP"
  fi
  t0="$(now)"
  event "$name: SIGTERM (docker stop -t $STOP_GRACE)"
  docker stop -t "$STOP_GRACE" "$name" >/dev/null
  code="$(docker inspect -f '{{.State.ExitCode}}' "$name")"
  event "$name: exited $code after $(perl -e "printf '%.1f', $(now) - $t0")s"
  [[ "$code" == 0 ]] || FAILURES=$((FAILURES + 1))
  docker start "$name" >/dev/null
  t0="$(now)"
  if wait_ready "http://127.0.0.1:809$n/readyz" 60; then
    event "$name: restarted, /readyz 200 after $(perl -e "printf '%.1f', $(now) - $t0")s"
  else
    event "$name: NOT ready 60s after its restart"
    FAILURES=$((FAILURES + 1))
  fi
  sleep "$SETTLE"
done
RESTARTS_DONE="$(now)"

wait "$K6_PID"
K6_EXIT=$?
K6_PID=""
event "k6 finished (exit $K6_EXIT)"
[[ -f "$OUT/k6-summary.json" ]] || { echo "error: k6 wrote no summary, see $OUT/k6.log" >&2; exit 2; }

# Restarts that ended after the load stopped were not tested under load.
if perl -e "exit !($RESTARTS_DONE > $K6_START + $DURATION_S)"; then
  event "the restarts outlasted the k6 run: raise DURATION_S"
  FAILURES=$((FAILURES + 1))
fi

read -r REQUESTS FAILED APP1 APP2 < <(python3 -I - "$OUT/k6-summary.json" <<'PY'
import json, sys

metrics = json.load(open(sys.argv[1]))['metrics']
value = lambda name, key: int((metrics.get(name) or {}).get('values', {}).get(key, 0))
print(value('http_reqs', 'count'), value('http_req_failed', 'passes'),
      value('served_by{upstream:app-1}', 'count'), value('served_by{upstream:app-2}', 'count'))
PY
)
# Each failed request, as the scenario logged it (k6 escapes the JSON inside its own log line).
grep -h 'source=console' "$OUT/k6.log" > "$OUT/failed-requests.log" 2>/dev/null || true
{
  echo "requests: $REQUESTS"
  echo "failed:   $FAILED"
  echo "served:   app-1 $APP1, app-2 $APP2"
  # The load balancer really moved the traffic: each replica's longest stretch without a request
  # should span its drain and restart, matching the events above.
  python3 -I - "$OUT/samples.csv.gz" <<'PY'
import csv, gzip, sys
from datetime import datetime, timezone

served = {}
with gzip.open(sys.argv[1], 'rt', newline='') as fh:
    for row in csv.DictReader(fh):
        if row['metric_name'] == 'served_by':
            tags = dict(t.split('=', 1) for t in row['extra_tags'].split('&') if '=' in t)
            served.setdefault(tags.get('upstream', 'none'), []).append(int(row['timestamp']))
clock = lambda ms: datetime.fromtimestamp(ms / 1000, timezone.utc).strftime('%H:%M:%S.%f')[:-3]
for upstream in sorted(served):
    times = sorted(served[upstream])
    gap, start = max(((b - a, a) for a, b in zip(times, times[1:])), default=(0, times[0]))
    print(f'gap:      {upstream} longest without a request {gap / 1000:.1f}s, {clock(start)} → {clock(start + gap)} UTC')
PY
} | tee -a "$EVENTS"
(( FAILED == 0 )) || FAILURES=$((FAILURES + 1))
(( APP1 > 0 && APP2 > 0 )) || { event "a replica served nothing"; FAILURES=$((FAILURES + 1)); }

if (( FAILURES == 0 )); then
  echo "✓ rolling-restart ($PATH_NAME): $REQUESTS requests, none lost, every replica drained and came back — $OUT"
  exit 0
fi
echo "✗ rolling-restart ($PATH_NAME): $FAILED of $REQUESTS requests failed, $FAILURES check(s) failed — $OUT"
exit 1
