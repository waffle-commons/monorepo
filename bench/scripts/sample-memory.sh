#!/usr/bin/env bash
# bench/scripts/sample-memory.sh — RSS sampler for one container.
#
# Usage: sample-memory.sh <container-id-or-name> <output.csv> [interval-seconds]
#
# Appends one CSV line per tick:  epoch,mem_used_bytes,mem_limit_bytes,mem_pct
# Uses `docker stats --no-stream` in a loop (every 5 s by default) so each line
# carries a real epoch timestamp — the engine-neutral RAM metric of the bench
# (PHP memory_get_usage != RSS; docker/cgroup is the arbiter).
#
# Launched in the background by run-bench.sh; stops cleanly on TERM/INT or when
# the container disappears.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <container-id-or-name> <output.csv> [interval-seconds]" >&2
  exit 2
fi

CONTAINER="$1"
OUT="$2"
INTERVAL="${3:-5}"

RUNNING=1
trap 'RUNNING=0' TERM INT

mkdir -p "$(dirname "$OUT")"
echo "epoch,mem_used_bytes,mem_limit_bytes,mem_pct" > "$OUT"

# "123.4MiB / 1GiB" -> bytes for both sides (awk does the unit math).
to_bytes() {
  awk -v s="$1" 'BEGIN {
    n = s + 0
    if      (s ~ /KiB/) n *= 1024
    else if (s ~ /MiB/) n *= 1024*1024
    else if (s ~ /GiB/) n *= 1024*1024*1024
    else if (s ~ /kB/)  n *= 1000
    else if (s ~ /MB/)  n *= 1000*1000
    else if (s ~ /GB/)  n *= 1000*1000*1000
    printf "%.0f", n
  }'
}

while [[ "$RUNNING" -eq 1 ]]; do
  line="$(docker stats --no-stream --format '{{.MemUsage}}|{{.MemPerc}}' "$CONTAINER" 2>/dev/null || true)"
  if [[ -z "$line" ]]; then
    # Container gone (teardown) — stop sampling.
    break
  fi
  mem_usage="${line%%|*}"
  mem_pct="${line##*|}"
  used="$(to_bytes "${mem_usage%%/*}")"
  limit="$(to_bytes "${mem_usage##*/}")"
  echo "$(date +%s),${used},${limit},${mem_pct%\%}" >> "$OUT"
  sleep "$INTERVAL" &
  wait $! || true   # interruptible sleep so TERM stops us within a tick
done
