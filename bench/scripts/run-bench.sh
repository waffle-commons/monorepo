#!/usr/bin/env bash
# bench/scripts/run-bench.sh — one measured bench run, end to end (BENCH-01).
#
#   usage: run-bench.sh <engine-a|engine-b|engine-c> <smoke|constant|soak|starve> [workload]
#
#   engine    engine-a = waffle skeleton (FrankenPHP worker)
#             engine-b = Symfony (php-fpm + nginx, pm.static)
#             engine-c = Symfony (FrankenPHP worker)
#             engine-a-mem / engine-b-dyn = BENCH-05 pair only (memory free to
#             grow, FPM pool dynamic) — never mix their numbers with BENCH-02
#   scenario  smoke    -> k6/scenarios/smoke.js
#             constant -> k6/scenarios/constant-load.js   (BENCH-02)
#             soak     -> k6/scenarios/soak.js            (BENCH-03)
#             starve   -> k6/scenarios/pool-starvation.js (BENCH-04)
#             memscale -> k6/scenarios/memory-scaling.js   (BENCH-05)
#   workload  json|hello|greet|dbread|dbwrite — only meaningful for `constant`
#             (exported to k6 as WORKLOAD; other scenarios fix their own mix)
#
# Env passthrough to k6 (all optional): RATES, STEP_DURATION, RATE, DURATION,
# VUS_STEPS (BENCH-05 concurrency steps).
# Compose-interpolated knobs: DB_POOL_SIZE (BENCH-04 sweep), MAX_REQUESTS
# (pinned to 1000000 here unless the caller overrides — Trap 3: worker recycle
# at the 500 default would mask leaks in the soak).
#
# Engines run ONE AT A TIME — this script starts exactly one engine plus
# bench-postgres, never two engines (fairness pinning, see bench/README.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$BENCH_DIR/docker-compose.bench.yml"
INIT_SQL="$BENCH_DIR/sql/init.sql"
RESULTS_DIR="$BENCH_DIR/results"

usage() {
  echo "usage: $0 <engine-a|engine-b|engine-c|engine-a-mem|engine-b-dyn> <smoke|constant|soak|starve|memscale> [workload]" >&2
  echo "       workload: json|hello|greet|dbread|dbwrite (constant only, default json)" >&2
  exit 2
}

log() { echo "[run-bench $(date '+%H:%M:%S')] $*"; }

[[ $# -ge 2 && $# -le 3 ]] || usage
ENGINE="$1"
SCENARIO="$2"
WORKLOAD_ARG="${3:-}"

case "$ENGINE" in
  engine-a|engine-b|engine-c|engine-a-mem|engine-b-dyn) ;;
  *) echo "error: unknown engine '$ENGINE'" >&2; usage ;;
esac

case "$SCENARIO" in
  smoke)    SCENARIO_FILE="smoke.js";           RESULT_WORKLOAD="all" ;;
  constant) SCENARIO_FILE="constant-load.js";   RESULT_WORKLOAD="${WORKLOAD_ARG:-json}" ;;
  soak)     SCENARIO_FILE="soak.js";            RESULT_WORKLOAD="all" ;;
  starve)   SCENARIO_FILE="pool-starvation.js"; RESULT_WORKLOAD="db" ;;
  memscale) SCENARIO_FILE="memory-scaling.js";  RESULT_WORKLOAD="dbread" ;;
  *) echo "error: unknown scenario '$SCENARIO'" >&2; usage ;;
esac

if [[ -n "$WORKLOAD_ARG" ]]; then
  case "$WORKLOAD_ARG" in
    json|hello|greet|dbread|dbwrite) ;;
    *) echo "error: unknown workload '$WORKLOAD_ARG'" >&2; usage ;;
  esac
  export WORKLOAD="$WORKLOAD_ARG"
fi

[[ -f "$COMPOSE_FILE" ]] || { echo "error: $COMPOSE_FILE not found" >&2; exit 1; }
[[ -f "$INIT_SQL" ]] || { echo "error: $INIT_SQL not found (DB seed contract — see k6/lib/common.js)" >&2; exit 1; }

COMPOSE=(docker compose -f "$COMPOSE_FILE")

# Trap 3: never let the soak be rescued by worker recycling.
export MAX_REQUESTS="${MAX_REQUESTS:-1000000}"

mkdir -p "$RESULTS_DIR"
MEM_CSV="$RESULTS_DIR/${ENGINE}-${SCENARIO}-${RESULT_WORKLOAD}-mem.csv"

SAMPLER_PID=""
CLEANED=0
cleanup() {
  [[ "$CLEANED" -eq 1 ]] && return 0
  CLEANED=1
  if [[ -n "$SAMPLER_PID" ]] && kill -0 "$SAMPLER_PID" 2>/dev/null; then
    log "stopping RSS sampler (pid $SAMPLER_PID)"
    kill "$SAMPLER_PID" 2>/dev/null || true
    wait "$SAMPLER_PID" 2>/dev/null || true
  fi
  log "tearing down $ENGINE"
  "${COMPOSE[@]}" stop -t 20 "$ENGINE" >/dev/null 2>&1 || true
  "${COMPOSE[@]}" rm -f "$ENGINE" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

seed_db() {
  log "(re)seeding bench database from sql/init.sql (drop/create + 10000 rows)"
  "${COMPOSE[@]}" exec -T bench-postgres \
    psql -q -U waffle -d waffle -v ON_ERROR_STOP=1 < "$INIT_SQL"
}

# --- 1. database -------------------------------------------------------------
log "starting bench-postgres"
"${COMPOSE[@]}" up -d bench-postgres

log "waiting for bench-postgres to accept connections"
PG_OK=0
for _ in $(seq 1 30); do
  if "${COMPOSE[@]}" exec -T bench-postgres pg_isready -q -U waffle -d waffle 2>/dev/null; then
    PG_OK=1; break
  fi
  sleep 2
done
[[ "$PG_OK" -eq 1 ]] || { echo "error: bench-postgres not ready after 60s" >&2; exit 1; }
log "bench-postgres is ready"

seed_db

# --- 2. engine (exactly ONE) -------------------------------------------------
log "starting $ENGINE (and only $ENGINE — engines are benched sequentially)"
# --force-recreate, always. Two reasons, one of which already cost a run:
#   1. Bind-mounted config (app.bench.yaml, ini files) is read ONCE at worker
#      boot. Editing it does not change compose's config hash, so a plain
#      `up -d` happily reuses a container still holding the OLD config in
#      memory — the run then measures a configuration that no longer exists on
#      disk, or fails for a reason already fixed.
#   2. Measurement hygiene: every run should start from a cold worker set, with
#      no opcache/JIT/pool state carried over from the previous engine's run.
"${COMPOSE[@]}" up -d --force-recreate "$ENGINE"

log "waiting for $ENGINE to answer GET / (in-network k6 probe, timeout 180s)"
ENGINE_OK=0
for _ in $(seq 1 36); do
  if "${COMPOSE[@]}" run --rm --quiet-pull k6 run --quiet --no-color \
       -e "TARGET=http://$ENGINE" /scripts/lib/probe.js >/dev/null 2>&1; then
    ENGINE_OK=1; break
  fi
  sleep 5
done
[[ "$ENGINE_OK" -eq 1 ]] || { echo "error: $ENGINE never answered GET / with 200 within 180s" >&2; exit 1; }
log "$ENGINE is up"

# --- 3. warmup ---------------------------------------------------------------
log "warmup: 30s over all 5 workloads (opcache/JIT/pool heat — not measured)"
"${COMPOSE[@]}" run --rm k6 run --quiet --no-color \
  -e "TARGET=http://$ENGINE" /scripts/lib/warmup.js

# --- 4. RSS sampler ----------------------------------------------------------
ENGINE_CID="$("${COMPOSE[@]}" ps -q "$ENGINE")"
[[ -n "$ENGINE_CID" ]] || { echo "error: cannot resolve container id for $ENGINE" >&2; exit 1; }
log "starting RSS sampler -> $MEM_CSV (docker stats, 5s ticks)"
bash "$SCRIPT_DIR/sample-memory.sh" "$ENGINE_CID" "$MEM_CSV" 5 &
SAMPLER_PID=$!

# --- 5. measured k6 run ------------------------------------------------------
K6_ENV=(-e "TARGET=http://$ENGINE")
for v in WORKLOAD RATES STEP_DURATION RATE DURATION VUS_STEPS; do
  if [[ -n "${!v:-}" ]]; then
    K6_ENV+=(-e "$v=${!v}")
    log "k6 env passthrough: $v=${!v}"
  fi
done

log "running k6 scenario $SCENARIO_FILE against http://$ENGINE"
K6_EXIT=0
"${COMPOSE[@]}" run --rm k6 run "${K6_ENV[@]}" \
  "/scripts/scenarios/$SCENARIO_FILE" || K6_EXIT=$?
if [[ "$K6_EXIT" -ne 0 ]]; then
  log "WARNING: k6 exited $K6_EXIT (threshold breach or abort) — summary JSON still written"
fi

# --- 6. teardown + DB reset --------------------------------------------------
cleanup

case "$SCENARIO:${WORKLOAD:-}" in
  smoke:*|soak:*|starve:*|constant:dbread|constant:dbwrite)
    log "db-touching scenario -> re-seeding so the next run is independent"
    seed_db
    ;;
  *)
    log "workload did not write to the db — seed left as-is"
    ;;
esac

log "bench-postgres left running for the next run (docker compose -f $COMPOSE_FILE down to stop)"
log "results: $RESULTS_DIR/${ENGINE}-${SCENARIO}-${RESULT_WORKLOAD}.json + $MEM_CSV"
log "done (k6 exit code: $K6_EXIT)"
exit "$K6_EXIT"
