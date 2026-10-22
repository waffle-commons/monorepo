# Waffle Beta6 — K6 Tri-Engine Benchmark Rig (AXE 5 / BENCH-01..04)

Reproducible harness comparing the **Waffle skeleton (prod stage)** against a
minimal, idiomatic **Symfony** API app deployed two ways, plus a variant of that app
doing Engine A's per-request work. Each comparison isolates one variable:

- **A vs C** — same runtime (FrankenPHP worker), different framework → isolates the framework,
  except that A also runs its secured pipeline and C does not.
- **B vs C** — same framework (Symfony), different runtime → isolates the runtime.
- **C vs D** — same app and runtime, D adding Engine A's per-request features → their cost in Symfony.
- **A vs D** — same runtime and per-request work, different framework → the framework at equal
  features (CARRY-02).

Published numbers live in the tracked [`BENCH-GATE-RESULT.md`](./BENCH-GATE-RESULT.md)
(benchmark-gate convention: baseline → representative load → verdict vs threshold → record).
The beta6 results there were measured on FrankenPHP 1.12.2; the rig now pins 1.13.2 on PHP 8.5.12
(the PHP2Shell security release, plus native `max_requests` thread recycling since 1.12.3), so a new
run is a new series.

## Engine matrix & fairness pinning

| | Engine A | Engine B | Engine C | Engine D |
|---|---|---|---|---|
| App | Waffle skeleton (prod image stage) | Symfony (shared app, gitignored) | same Symfony app | same app + Engine A's per-request features (derived, gitignored) |
| Runtime | FrankenPHP 1.13.2 worker | php:8.5-fpm + nginx | FrankenPHP 1.13.2 worker (symfony/runtime 7.4's native `FrankenPhpWorkerRunner`) | as Engine C (same Dockerfile) |
| Workers | **4** (pinned via `FRANKENPHP_CONFIG="worker ./public/index.php 4"`) | `pm.static`, **16** children | **4** (pinned) | **4** (pinned) |
| HTTP (in-network) | `http://engine-a` | `http://engine-b` | `http://engine-c` | `http://engine-d` |
| Host smoke port | `127.0.0.1:8081` | `127.0.0.1:8082` | `127.0.0.1:8083` | `127.0.0.1:8087` |

Identical on every engine (enforced in `docker-compose.bench.yml` + per-engine ini):

- `cpus: "2"`, `mem_limit: 1g`
- PHP 8.5, `APP_ENV=prod`, `APP_DEBUG=false`, no Xdebug
- `opcache.validate_timestamps=0`, `opcache.jit=1234`, `opcache.jit_buffer_size=128M`
  (reference profile: `workspace/docker/php/mode-bench.ini`; Engine A's copy is
  `engines/waffle/jit-bench.ini`)
- Engines run **sequentially** — `run-bench.sh` starts exactly ONE engine plus
  `bench-postgres`, never two engines at once (they would contend for the pinned CPUs)
- Same PostgreSQL 17 service, same `users` schema, same deterministic 10k-row seed,
  DB re-seeded between runs (`init.sql` TRUNCATEs and re-inserts; the volume is
  deliberately kept so the container and its page cache stay warm across engines)
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

## Engine D — Engine A's per-request work in Symfony (CARRY-02)

`scripts/bootstrap-symfony.sh` derives it from the bare app's lock, so every shared package stays at
the same version, adds `symfony/security-bundle` with its components pinned to 7.4, and copies the
tracked stubs in `scripts/stubs/app-secured/`. It fails if a shared package drifts or a Symfony
component leaves the 7.4 line (the bundle's ranges reach 8.x).

| Engine A (skeleton pipeline) | Engine D |
|---|---|
| `TrustedHostMiddleware` | `framework.trusted_hosts` |
| `CorsMiddleware`, empty allow-list | `CorsSubscriber`: no `Origin` or the request's own origin passes, any other origin gets 403 |
| `AuthenticationMiddleware` (anonymous without credentials) | stateless, eager firewall with an `access_token` authenticator; a presented token is refused (401) |
| `SecurityMiddleware` + `#[PublicAccess]` | `#[IsGranted('PUBLIC_ACCESS')]` on every action |
| `CsrfMiddleware` (no bench route requires a token) | stateless CSRF on; no action validates a token |
| `TransactionIsolationMiddleware`: one transaction per POST, PUT, PATCH, DELETE | `TransactionSubscriber`, opened after the authorisation check and before payload validation |
| `SecureHeadersMiddleware` | `SecureHeadersSubscriber`: the same three headers and values |

Not mirrored, for want of a Symfony counterpart: the anonymous session id (k6 empties its cookie jar
after every iteration, so Engine A issues a new id and a `Set-Cookie` on most bench requests), the
telemetry (APCu request counters and histogram, cache counters, the no-op span, the probe and metrics
path checks) and the `SecureContainer`. That work stays in Engine A's column.

`POST /greet` touches no table, yet on Engines A and D it runs in a transaction (BEGIN + COMMIT); on B
and C it never reaches the database. Run `scripts/check-features.sh` before a measured run: A and D must
refuse an untrusted `Host` (400) and a junk bearer token (401), send the three headers and commit one
transaction per `POST /greet`, and C must do none of that.

## Workload routes (identical on all engines)

| Route | Shape |
|---|---|
| `GET /` | static JSON |
| `GET /hello/{name}` | JSON with routed param |
| `POST /greet` | JSON body `{"name": ...}` → validated DTO → JSON |
| `GET /read/demo?id=<uuid>` | SELECT by primary key from `users` |
| `POST /write/demo` | transaction boundary + one trivial statement (`BEGIN` / `SELECT 1` / `COMMIT`) — **not** a durable write; the endpoint is public and CSRF-exempt, so neither engine commits a row |

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
`engines/symfony-app/` for Engines B and C, and `engines/symfony-app-secured/` for Engine D).

Everything goes through the runner (one engine at a time, warmup included):

```bash
cd bench

# BENCH-01 — harness smoke, every engine × every route:
scripts/run-bench.sh engine-a smoke
scripts/run-bench.sh engine-b smoke
scripts/run-bench.sh engine-c smoke
scripts/run-bench.sh engine-d smoke

# Before measuring: prove the per-request work each engine is credited with (CARRY-02).
scripts/check-features.sh

# BENCH-02 — constant-arrival-rate ladder 50/100/200/400/800 rps × 2 min per step.
# Produces the published PER-RATE latency table. It does NOT produce a RAM factor:
# this rig pins FPM to a static pool and caps every engine's memory, so it cannot
# measure how memory scales with concurrency — that is BENCH-05 (memscale) below.
# Add a workload as the third argument: json | hello | greet | dbread | dbwrite.
scripts/run-bench.sh engine-a constant dbread
scripts/run-bench.sh engine-b constant dbread
scripts/run-bench.sh engine-c constant dbread
scripts/run-bench.sh engine-d constant dbread

# BENCH-05 — memory as a function of CONCURRENCY (the experiment BENCH-02 cannot
# run). Pins only CPU, lets memory grow to 6g, and switches FPM to a dynamic pool
# so children spawn with load. Closed model: constant-vus steps, not arrival rate,
# because what decides FPM's process count is concurrent in-flight requests.
# Never mix these numbers with BENCH-02's — each pair answers exactly one question.
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m scripts/run-bench.sh engine-a-mem memscale
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m scripts/run-bench.sh engine-b-dyn memscale
# Engine C's leg (CARRY-02) splits the A-vs-B gap: A-mem vs C-mem holds the runtime
# constant, B-dyn vs C-mem holds the framework constant.
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m scripts/run-bench.sh engine-c-mem memscale
# Engine D's leg: C-mem vs D-mem is the memory cost of the features.
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m scripts/run-bench.sh engine-d-mem memscale

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
teardown → re-seed → archive. `report.sh` folds k6 JSON + CSV into the markdown
table for `BENCH-GATE-RESULT.md`.

Pool gauges / worker memory for BENCH-04 come from `/waffle-metrics`, which is
**loopback-only** — sample it from inside the container
(`docker exec engine-a php -r '...localhost/waffle-metrics...'`), not through the
published port.

## Where results land

- `results/` — raw k6 JSON + RSS CSVs, **gitignored**. Each run's files carry its id, the UTC start
  unless `RUN_ID` is set: `<engine>-<scenario>-<workload>-<run id>.json`, `…-mem.csv`, and `…-host.json`
  (host CPU, cores and RAM, the Docker VM's CPUs and memory, the engine's limits and image, the umbrella
  commit). `run-bench.sh` refuses to start over an existing series (CARRY-02).
- `report.sh` lists every run with its host. The soak table adds the least-squares RSS slope over the
  settled window, with its 95 % bound (AGENTS.md §7). Files from before CARRY-02 show as `unstamped`.
- Archived per run to `project_system/Audits/Beta6/bench/` (audit-artifact convention).
- Published, human-readable numbers: tracked [`BENCH-GATE-RESULT.md`](./BENCH-GATE-RESULT.md).

## Honest-method notes (recorded per benchmark-gate protocol)

- **`MAX_REQUESTS=1000000` on Engine A** — the skeleton worker script recycles
  every `MAX_REQUESTS` (default 500). The bench pins it to one million so worker
  recycling cannot mask a leak during the soak: any RSS drift is real drift.
  The value is deliberate and recorded here and in the compose file.
- **`FRANKENPHP_LOOP_MAX=1000000` on Engine C** — the same pin for Symfony's native
  `FrankenPhpWorkerRunner`, which also exits after 500 requests by default. Beta6 left it unset
  and forced the external `runtime/frankenphp-symfony` bridge through `APP_RUNTIME`, so its
  Engine C soak was not a leak test (*Engine C corrections* in `BENCH-GATE-RESULT.md`). Both
  fixed in CARRY-02; the host record keeps the engine's `APP_RUNTIME` and `FRANKENPHP_LOOP_MAX`.
- **Soak window** — target is 2–3 h per worker engine, sequential. If wall-clock
  forces the 90 min/engine fallback, the shortened window is recorded explicitly
  in `BENCH-GATE-RESULT.md`; the verdict states what was measured, not vibes.
- **Secrets in the compose file are bench fixtures** — self-describing, deliberately non-secret values
  committed on purpose for clean-clone reproducibility; never production material.
- **Engines are never co-resident** — every figure comes from a run where the
  measured engine and the DB were the only loaded services on the rig.
- **`bench-postgres` is intentionally left unpinned** — it is shared
  infrastructure, identical across runs; pinning the engines (not the DB) keeps
  the DB from becoming the artificial bottleneck at the top of the rps ladder.
- **k6 runs in its own container** on the compose network (own CPU allocation),
  under the `tools` profile so it never boots alongside the engines by accident.
