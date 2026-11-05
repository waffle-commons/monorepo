#!/usr/bin/env bash
# bench/scripts/check-pool-freshness.sh — the functional half of the CARRY-01
# gate (data/benchmarks/CARRY-01-GATE-RESULT.md): what the pool's ping freshness
# window does to Engine A's database work, and whether dead connections are
# still caught.
#
#   usage: check-pool-freshness.sh <window-ms>
#
# 1. Transactions per request: 200 GET /read/demo and 200 POST /greet, counted
#    on bench-postgres. The engine is stopped before each reading, because a
#    backend flushes its statistics when it exits.
# 2. Stale connections are caught: every app connection is killed
#    (pg_terminate_backend); after window + 1 s, 200 reads must all answer 200.
# 3. The window bounds the damage: the connections are killed again right after
#    a probe proved them alive (the worst case: the whole window is still
#    ahead), then read back to back; no read sent later than window + 250 ms
#    after the kill may fail (window 0: at most the one read in flight).
#
# Engine A runs alone with bench-postgres, like run-bench.sh. The report lands
# in results/ under a run id (RUN_ID, default the UTC start); exits 1 when a
# check fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$BENCH_DIR/docker-compose.bench.yml"

WINDOW="${1:-}"
[[ "$WINDOW" =~ ^[0-9]+$ ]] || { echo "usage: $0 <window-ms>" >&2; exit 2; }
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
[[ "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: RUN_ID may only hold [A-Za-z0-9._-]" >&2; exit 2; }
OUT="$BENCH_DIR/results/pool-freshness-engine-a-w${WINDOW}-${RUN_ID}.txt"
[[ ! -e "$OUT" ]] || { echo "error: $OUT already exists; never overwrite a run" >&2; exit 1; }
mkdir -p "$BENCH_DIR/results"

docker compose -f "$COMPOSE_FILE" up -d bench-postgres >/dev/null 2>&1
PG_OK=0
for _ in $(seq 1 30); do
  if docker compose -f "$COMPOSE_FILE" exec -T bench-postgres pg_isready -q -U waffle -d waffle 2>/dev/null; then
    PG_OK=1; break
  fi
  sleep 2
done
[[ "$PG_OK" -eq 1 ]] || { echo "error: bench-postgres not ready after 60s" >&2; exit 1; }

python3 - "$WINDOW" "$COMPOSE_FILE" "$RUN_ID" <<'PY' | tee "$OUT"
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

window_ms, compose_file, run_id = int(sys.argv[1]), sys.argv[2], sys.argv[3]
COMPOSE = ['docker', 'compose', '-f', compose_file]
ENGINE, BASE = 'engine-a', 'http://127.0.0.1:8081'
READ = ('GET', '/read/demo?id=00000000-0000-0000-0000-000000000000', None)
GREET = ('POST', '/greet', {'name': 'Ada'})
SLACK_MS = 250


def request(method, path, body):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={'Host': 'localhost', 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=10) as res:
            res.read()
            return res.status
    except urllib.error.HTTPError as error:
        return error.code
    except OSError:
        return 0


def psql(sql):
    out = subprocess.run(COMPOSE + ['exec', '-T', 'bench-postgres', 'psql', '-U', 'waffle', '-d', 'waffle', '-Atc', sql],
                         check=True, capture_output=True, text=True)
    return out.stdout.strip()


def commits():
    return int(psql("SELECT xact_commit FROM pg_stat_database WHERE datname = 'waffle'"))


def kill_app_connections():
    return int(psql("SELECT count(pg_terminate_backend(pid)) FROM pg_stat_activity WHERE datname = 'waffle' "
                    "AND backend_type = 'client backend' AND pid <> pg_backend_pid()"))


def start():
    env = dict(os.environ, DB_PING_FRESHNESS_MS=str(window_ms))
    subprocess.run(COMPOSE + ['up', '-d', '--force-recreate', ENGINE], check=True, capture_output=True, env=env)
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if request('GET', '/', None) == 200:
            return
        time.sleep(2)
    sys.exit(f'error: {ENGINE} never answered GET / with 200 within 180s')


def stop():
    subprocess.run(COMPOSE + ['rm', '-sf', ENGINE], check=True, capture_output=True)


def per_request(workload, n=200):
    start()
    for _ in range(10):
        request(*workload)
    before = commits()
    answered = sum(1 for _ in range(n) if request(*workload) == 200)
    stop()
    time.sleep(1)
    return answered, (commits() - before) / n


failed = []
print(f'pool freshness check  engine={ENGINE} DB_PING_FRESHNESS_MS={window_ms} run={run_id}')

for name, workload in (('GET /read/demo', READ), ('POST /greet', GREET)):
    answered, per = per_request(workload)
    print(f'  transactions per {name:<15} {per:5.2f}   ({answered}/200 answered 200)')
    if answered != 200:
        failed.append(f'{name} answered 200 only {answered}/200 times')

start()
for _ in range(50):
    request(*READ)
killed = kill_app_connections()
time.sleep(window_ms / 1000 + 1)
idle_failures = sum(1 for _ in range(200) if request(*READ) != 200)
print(f'  idle: killed {killed} connection(s), waited {window_ms + 1000} ms, failed reads {idle_failures}/200')
if killed == 0:
    failed.append('idle: no app connection to kill, so the check proves nothing')
if idle_failures:
    failed.append(f'idle: {idle_failures} read(s) failed after the window had passed')

for _ in range(50):
    request(*READ)
# Past the window, the next lease probes the connection: the kill then lands at
# the start of a fresh window, the most reads a dead connection can fail.
time.sleep(window_ms / 1000 + 0.2)
request(*READ)
killed = kill_app_connections()
t0 = time.monotonic()
sent, failures = 0, []
while (time.monotonic() - t0) * 1000 < window_ms + 2000:
    offset_ms = (time.monotonic() - t0) * 1000
    sent += 1
    if request(*READ) != 200:
        failures.append(offset_ms)
stop()
last = f'{max(failures):.0f} ms' if failures else 'none'
print(f'  load: killed {killed} connection(s), {sent} reads, {len(failures)} failed, last failure sent at {last} after the kill')
if killed == 0:
    failed.append('load: no app connection to kill, so the check proves nothing')
if window_ms == 0 and len(failures) > 1:
    failed.append(f'load: {len(failures)} reads failed without a window (at most the one in flight may)')
late = [f for f in failures if f > window_ms + SLACK_MS]
if window_ms > 0 and late:
    failed.append(f'load: {len(late)} read(s) failed later than window + {SLACK_MS} ms (last at {max(late):.0f} ms)')

for reason in failed:
    print(f'  FAIL  {reason}')
print('  verdict: ' + ('FAIL' if failed else 'PASS'))
sys.exit(1 if failed else 0)
PY
