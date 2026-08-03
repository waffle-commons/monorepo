# Waffle Beta6 — K6 Tri-Engine Benchmark Rig (AXE 5 / BENCH-01..04)

Reproducible harness comparing the **Waffle skeleton (prod stage)** against a
minimal, idiomatic **Symfony** API app deployed two ways. One Symfony codebase,
two deployments, so each comparison isolates exactly one variable:

- **A vs C** — same runtime (FrankenPHP worker), different framework → isolates the framework.
- **B vs C** — same framework (Symfony), different runtime → isolates the runtime.

Published numbers live in the tracked [`BENCH-GATE-RESULT.md`](./BENCH-GATE-RESULT.md)
(benchmark-gate convention: baseline → representative load → verdict vs threshold → record).

## Engine matrix & fairness pinning

| | Engine A | Engine B | Engine C |
|---|---|---|---|
| App | Waffle skeleton (prod image stage) | Symfony (shared app, gitignored) | same Symfony app |
| Runtime | FrankenPHP 1.12.2 worker | php:8.5-fpm + nginx | FrankenPHP worker (`runtime/frankenphp-symfony`) |
| Workers | **4** (pinned via `FRANKENPHP_CONFIG="worker ./public/index.php 4"`) | `pm.static`, **16** children | **4** (pinned) |
| HTTP (in-network) | `http://engine-a` | `http://engine-b` | `http://engine-c` |
| Host smoke port | `127.0.0.1:8081` | `127.0.0.1:8082` | `127.0.0.1:8083` |

Identical on every engine (enforced in `docker-compose.bench.yml` + per-engine ini):

- `cpus: "2"`, `mem_limit: 1g`
- PHP 8.5, `APP_ENV=prod`, `APP_DEBUG=false`, no Xdebug
- `opcache.validate_timestamps=0`, `opcache.jit=1234`, `opcache.jit_buffer_size=128M`
  (reference profile: `workspace/docker/php/mode-bench.ini`; Engine A's copy is
  `engines/waffle/jit-bench.ini`)
- Engines run **sequentially** — `run-bench.sh` starts exactly ONE engine plus
  `bench-postgres`, never two engines at once (they would contend for the pinned CPUs)
- Same PostgreSQL 17 service, same `users` schema, same deterministic 10k-row seed,
  DB re-seeded between runs (`down -v` drops the volume → `init.sql` replays)
- Warmup phase before every measured window

**FPM `pm.static = 16` rationale:** worker engines hold ONE booted app per worker
(4 × app heap ≪ 1 G). FPM pays a full Symfony prod boot per child; a child of this
app stack is ~55–65 MB RSS steady-state, so 16 static children ≈ 0.9–1 G — the same
RAM budget the worker engines get. `pm.static` (not `dynamic`) removes fork jitter
from the latency distribution. Engine B is therefore "classic PHP at its honest
best under the same 1 G", not a strawman.

**Waffle bench deltas (Engine A mounts, all under `engines/waffle/`):**

- `app.bench.yaml` over `/app/config/app.yaml` — adds `engine-a` to
  `trusted_hosts` (the allow-list is YAML-only; without it TrustedHostMiddleware
  400s every k6 request), switches cache to the in-memory `array` adapter (no
  Redis in the rig; comparable to Symfony's in-process compiled caches), pgsql →
  `bench-postgres`.
- `Caddyfile` over `/etc/caddy/Caddyfile` — identical to skeleton's except it
  interpolates `{$FRANKENPHP_CONFIG}`; the stock skeleton Caddyfile ignores that
  env var, so the 4-worker pin would otherwise silently not apply.
- `jit-bench.ini` into `conf.d/` — the JIT parity values above.

## Workload routes (identical on all three engines)

| Route | Shape |
|---|---|
| `GET /` | static JSON |
| `GET /hello/{name}` | JSON with routed param |
| `POST /greet` | JSON body `{"name": ...}` → validated DTO → JSON |
| `GET /read/demo?id=<uuid>` | SELECT by primary key from `users` |
| `POST /write/demo` | INSERT into `users` (server-generated values) |

`users` schema (= `skeleton/migrations/Version2026053101_CreateUsersTable.sql`):
`id VARCHAR(36) PK`, `email UNIQUE`, `password_hash`, `created_at`.

Note (Engine A): Waffle's CSRF protection is fail-closed on unsafe methods, but
it only guards actions carrying `#[RequiresCsrfToken]`. None of the five bench
routes does, so the POST workloads need no token handshake and none is
implemented — verify with `rg RequiresCsrfToken ../skeleton/src` before adding
one. If a future workload targets a CSRF-guarded action, the handshake becomes
mandatory or that workload silently measures 403s.

## Deterministic seed & the id-derivation scheme

`sql/init.sql` seeds **10 000 rows** via `generate_series`. The read workload needs
ids that k6 can compute without querying the DB, so ids are **md5-derived,
uuid-formatted text of the row number**:

```
n  ∈ 1..10000
h  = md5('bench-user-' + n)                      # 32 hex chars
id = h[0:8]-h[8:4]-h[12:4]-h[16:4]-h[20:12]      # 8-4-4-4-12
email         = 'user<n>@bench.waffle.local'
password_hash = md5('bench-pass-' + n)
```

k6 side (must match byte-for-byte):

```js
import crypto from 'k6/crypto';
function userId(n) {
  const h = crypto.md5(`bench-user-${n}`, 'hex');
  return `${h.substr(0,8)}-${h.substr(8,4)}-${h.substr(12,4)}-${h.substr(16,4)}-${h.substr(20,12)}`;
}
```

Re-seeding is automatic: `run-bench.sh` re-runs `sql/init.sql` after every
db-touching scenario, and that file `TRUNCATE`s before inserting, so every run
starts from the exact same 10 000 rows. (It does **not** drop the volume — the
container and its page cache are deliberately kept warm between engines.)

## Running the benches

Prerequisites: Docker running; Phase-B skeleton pre-work merged (`#[PublicAccess]`
on the hello routes, `GET /read/demo`, `DB_POOL_SIZE` knob, pgsql driver);
`scripts/bootstrap-symfony.sh` executed once (generates the gitignored
`engines/symfony-app/`, then Engines B/C build from it).

Everything goes through the runner (one engine at a time, warmup included):

```bash
cd bench

# BENCH-01 — harness smoke, every engine × every route:
scripts/run-bench.sh engine-a smoke
scripts/run-bench.sh engine-b smoke
scripts/run-bench.sh engine-c smoke

# BENCH-02 — constant-arrival-rate ladder 50/100/200/400/800 rps × 2 min per step.
# Produces the published PER-RATE latency table. It does NOT produce a RAM factor:
# this rig pins FPM to a static pool and caps every engine's memory, so it cannot
# measure how memory scales with concurrency — that is BENCH-05 (memscale) below.
# Add a workload as the third argument: json | hello | greet | dbread | dbwrite.
scripts/run-bench.sh engine-a constant dbread
scripts/run-bench.sh engine-b constant dbread
scripts/run-bench.sh engine-c constant dbread

# BENCH-05 — memory as a function of CONCURRENCY (the experiment BENCH-02 cannot
# run). Pins only CPU, lets memory grow to 6g, and switches FPM to a dynamic pool
# so children spawn with load. Closed model: constant-vus steps, not arrival rate,
# because what decides FPM's process count is concurrent in-flight requests.
# Never mix these numbers with BENCH-02's — each pair answers exactly one question.
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m scripts/run-bench.sh engine-a-mem memscale
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m scripts/run-bench.sh engine-b-dyn memscale

# BENCH-03 — soak ~150 rps, A then C (2–3 h each, sequential; B shorter, footprint
# only). ΔM = |mean RSS(last 10 min) − mean RSS(first 10 min after warmup)| ≤ ~1% / 5 MB:
scripts/run-bench.sh engine-a soak
scripts/run-bench.sh engine-c soak

# BENCH-04 — pool starvation, Engine A only (VUs 8→16→32→64 against the DB routes,
# pool=8; optional sweep DB_POOL_SIZE=16):
scripts/run-bench.sh engine-a starve
DB_POOL_SIZE=16 scripts/run-bench.sh engine-a starve
```

The runner: `up` ONE engine + `bench-postgres` → warmup → k6 (JSON to `results/`) →
`sample-memory.sh` (docker stats → RSS CSV every 5 s, engine-neutral: PHP memory ≠ RSS) →
teardown (`down -v`) → archive. `report.sh` folds k6 JSON + CSV into the markdown
table for `BENCH-GATE-RESULT.md`.

Pool gauges / worker memory for BENCH-04 come from `/waffle-metrics`, which is
**loopback-only** — sample it from inside the container
(`docker exec engine-a php -r '...localhost/waffle-metrics...'`), not through the
published port.

## Where results land

- `results/` — raw k6 JSON + RSS CSVs, **gitignored**.
- Archived per run to `project_system/Audits/Beta6/bench/` (audit-artifact convention).
- Published, human-readable numbers: tracked [`BENCH-GATE-RESULT.md`](./BENCH-GATE-RESULT.md).

## Honest-method notes (recorded per benchmark-gate protocol)

- **`MAX_REQUESTS=1000000` on Engine A** — the skeleton worker script recycles
  every `MAX_REQUESTS` (default 500). The bench pins it to one million so worker
  recycling cannot mask a leak during the soak: any RSS drift is real drift.
  The value is deliberate and recorded here and in the compose file.
- **Soak window** — target is 2–3 h per worker engine, sequential. If wall-clock
  forces the 90 min/engine fallback, the shortened window is recorded explicitly
  in `BENCH-GATE-RESULT.md`; the verdict states what was measured, not vibes.
- **Secrets in the compose file are bench fixtures** — fixed 64-char values
  committed on purpose for clean-clone reproducibility; never production material.
- **Engines are never co-resident** — every figure comes from a run where the
  measured engine and the DB were the only loaded services on the rig.
- **`bench-postgres` is intentionally left unpinned** — it is shared
  infrastructure, identical across runs; pinning the engines (not the DB) keeps
  the DB from becoming the artificial bottleneck at the top of the rps ladder.
- **k6 runs in its own container** on the compose network (own CPU allocation),
  under the `tools` profile so it never boots alongside the engines by accident.
