#!/usr/bin/env bash
# bench/scripts/run-carry02.sh — the CARRY-02 re-measurement on the hardened rig, chained for one
# unattended night (Roadmap_Beta7 [CARRY-02], scheduled 2026-10-31).
#
#   usage: run-carry02.sh [--stop-others] [--dry-run] [--only=PHASE[,PHASE...]]
#
# Order, about 7 h 30 on an idle machine:
#   1. preflight: one smoke run per engine (engine-b is built on first use) and check-features.sh
#   2. bench02 — BENCH-02: engines A, C, D × json, dbread, dbwrite; 50/100/200/400/800 rps × 2 min per step
#      (about 1 h 40)
#   3. bench05 — BENCH-05: engine-a-mem, engine-b-dyn, engine-c-mem, engine-d-mem; 8..128 VUs × 2 min per step
#   4. bench03 — BENCH-03: engine-c then engine-d, 150 rps × 2 h each
#
# --only runs the named phases only, still in this order: --only=bench02 re-runs BENCH-02 alone (added
# 2026-11-01, when the first run's BENCH-02 tails were disturbed by other work on the laptop).
#
# Every run is run-bench.sh's own (run-unique id, host record, never overwrites a series): this script
# only sequences them and keeps going when one fails. The full output goes to
# results/carry02-<UTC>.log and one line per run (start, end, exit code) to results/carry02-<UTC>.summary.
#
# Nothing else may use the machine meanwhile, or the numbers are void. The script refuses to start while
# containers outside the bench are running; --stop-others stops them first and starts them again at the
# end (MCP server containers are left alone). It keeps the Mac awake with caffeinate: leave it on mains
# power with the lid open. Bash 3.2 compatible (the macOS /bin/bash).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"
RUN="$SCRIPT_DIR/run-bench.sh"
STOP_OTHERS=0
DRY_RUN=0
ONLY=""
for arg in "$@"; do
  case "$arg" in
    --stop-others) STOP_OTHERS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --only=*) ONLY=",${arg#--only=}," ;;
    *) echo "usage: $0 [--stop-others] [--dry-run] [--only=PHASE[,PHASE...]]" >&2; exit 2 ;;
  esac
done

# --only: a comma list of phases; an unknown name is refused before anything starts.
PHASES="${ONLY#,}"
PHASES="${PHASES%,}"
if [[ -n "$ONLY" ]]; then
  for phase in ${PHASES//,/ }; do
    case "$phase" in
      preflight | bench02 | bench05 | bench03) ;;
      *) echo "error: unknown phase \"$phase\" (preflight, bench02, bench05, bench03)" >&2; exit 2 ;;
    esac
  done
fi

# wanted <phase>: whether the run includes that phase (all of them without --only).
wanted() {
  [[ -z "$ONLY" || "$ONLY" == *",$1,"* ]]
}

# The whole chain runs under caffeinate (idle, display and system sleep held off), entered once.
if [[ $DRY_RUN -eq 0 && -z "${CARRY02_AWAKE:-}" ]] && command -v caffeinate >/dev/null 2>&1; then
  CARRY02_AWAKE=1 exec caffeinate -dims "$0" "$@"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$BENCH_DIR/results/carry02-$STAMP.log"
SUMMARY="$BENCH_DIR/results/carry02-$STAMP.summary"

# Running containers that are neither the bench's own nor an MCP server.
others() {
  docker ps --format '{{.Names}} {{.Image}}' | awk '$1 !~ /^(engine-|bench-)/ && $2 !~ /mcp/ { print $1 }'
}

STOPPED=""
restore() {
  [[ -n "$STOPPED" ]] || return 0
  echo "restarting:$STOPPED" | tee -a "$SUMMARY"
  # shellcheck disable=SC2086 # one container name per word
  docker start $STOPPED >/dev/null || echo "warning: could not restart every container:$STOPPED" | tee -a "$SUMMARY"
}

BUSY="$(others | tr '\n' ' ')"
if [[ -n "$BUSY" ]]; then
  if [[ $STOP_OTHERS -eq 0 ]]; then
    echo "error: other containers are running, so the machine is not idle: $BUSY" >&2
    echo "       stop them, or rerun with --stop-others (stopped now, started again at the end)" >&2
    exit 1
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would stop: $BUSY"
  else
    for name in $BUSY; do
      docker stop -t 20 "$name" >/dev/null
      STOPPED="$STOPPED $name"
    done
    trap restore EXIT
    echo "stopped:$STOPPED" | tee -a "$SUMMARY"
  fi
fi

# run <label> <command...>: one step, logged, never fatal to the chain.
run() {
  local label="$1"
  shift
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would run [$label]: $*"
    return 0
  fi
  local start code=0
  start="$(date -u +%H:%M:%S)"
  echo "===== $label — $start UTC" >>"$LOG"
  "$@" >>"$LOG" 2>&1 || code=$?
  printf '%-34s %s → %s UTC  exit %d\n' "$label" "$start" "$(date -u +%H:%M:%S)" "$code" | tee -a "$SUMMARY"
}

[[ $DRY_RUN -eq 1 ]] || echo "CARRY-02 chain $STAMP${PHASES:+ (only $PHASES)}: log $LOG, summary $SUMMARY" | tee -a "$SUMMARY"

if wanted preflight; then
  for engine in engine-a engine-b engine-c engine-d; do
    run "smoke $engine" "$RUN" "$engine" smoke
  done
  run "check-features" "$SCRIPT_DIR/check-features.sh"
fi

if wanted bench02; then
  for engine in engine-a engine-c engine-d; do
    for workload in json dbread dbwrite; do
      run "BENCH-02 $engine $workload" env RATES=50,100,200,400,800 STEP_DURATION=2m "$RUN" "$engine" constant "$workload"
    done
  done
fi

if wanted bench05; then
  for engine in engine-a-mem engine-b-dyn engine-c-mem engine-d-mem; do
    run "BENCH-05 $engine" env VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m "$RUN" "$engine" memscale
  done
fi

if wanted bench03; then
  for engine in engine-c engine-d; do
    run "BENCH-03 $engine" env RATE=150 DURATION=2h "$RUN" "$engine" soak
  done
fi

[[ $DRY_RUN -eq 1 ]] || echo "CARRY-02 chain done $(date -u +%H:%M:%S) UTC" | tee -a "$SUMMARY"
