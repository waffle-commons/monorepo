# BENCH-GATE-RESULT — Beta6 AXE 5 (tri-engine k6 benchmark)

- **Date:** 2026-08-02 / 2026-08-03 (full-length soaks)
- **Subject:** `waffle-commons/skeleton` @ `pre-release/0.1.0-beta6`, FrankenPHP 1.12.2 / PHP 8.5
- **Harness:** `bench/` (this directory) — `run-bench.sh <engine> <scenario> [workload]`
- **Raw data:** `bench/results/*.json` + `*-mem.csv` (gitignored; archived to
  `project_system/Audits/Beta6/bench/`)

| Engine | Framework | Runtime | Role |
|---|---|---|---|
| **A** | Waffle-Commons (skeleton, prod image) | FrankenPHP worker, 4 workers | subject |
| **B** | Symfony (shared app) | php-fpm + nginx, `pm.static` 16 | classic-stack baseline |
| **C** | Symfony (same app) | FrankenPHP worker, 4 workers | runtime-held-constant control |

Pinned identically: 2 CPUs, 1 GiB, `APP_ENV=prod`, opcache `validate_timestamps=0`,
JIT `1234` / 128 M buffer, `MAX_REQUESTS=1000000`, one engine running at a time,
30 s warm-up before every measured window, identical 10 000-row `users` dataset.

---

## Verdicts at a glance

| Item | Verdict | Note |
|---|---|---|
| `[BENCH-01]` reproducible tri-engine harness | **PASS** | one command per run; Symfony app bootstrap-scripted |
| `[BENCH-02]` constant-load percentiles | **PASS** (latency) | vs PHP-FPM: decisive win. vs Symfony-on-worker: parity to 400 rps, earlier knee after |
| `[BENCH-02]` 5–10× RAM factor | **NOT TESTABLE HERE** | pinning made the claim unmeasurable — superseded by BENCH-05 |
| `[BENCH-03]` soak ΔM = 0 | **PASS** (full window) | 3 h/engine, 1.62 M requests each, ΔM negative on both |
| `[BENCH-04]` pool-starvation behaviour | **PASS** | 8× oversubscription, bounded, zero errors |
| `[BENCH-05]` memory vs concurrency | **PASS — claim REFRAMED** | FPM grows **10.5× faster** per concurrent request; 2.37× total at 128 concurrency; bare "5–10×" is **not** publishable as stated |

---

## `[BENCH-02]` Constant-arrival-rate ladder

Method: constant-arrival-rate steps 50 / 100 / 200 / 400 / 800 rps, **1 min per step**
(reduced from the specified 2 min — see *Deviations*), workloads `json`, `dbread`,
`dbwrite`.

**Read the per-rate table, not an aggregate.** An aggregate median over a ladder that
includes saturated steps is meaningless; the first draft of this report quoted one and
it was wrong.

p50 / p99 in ms:

| Workload | rps | A (Waffle worker) | B (Symfony FPM) | C (Symfony worker) |
|---|---:|---|---|---|
| json | 50 | 2.0 / 3.4 | 3.1 / 6.2 | 2.1 / 3.0 |
| json | 200 | 1.5 / 4.3 | 2.3 / 50.7 | 1.5 / 3.3 |
| json | 400 | 1.2 / 1321 | 2.2 / 5.9 | 1.1 / 3.4 |
| json | 800 | **1.0** / 38.2 | 587.8 / 1005 | 1.3 / 84.6 |
| dbread | 50 | 4.0 / 6.5 | 19.2 / 30.8 | 2.6 / 12.8 |
| dbread | 200 | 2.9 / 6.6 | 4877 / 5591 | 2.0 / 4.5 |
| dbread | 400 | 3.9 / 102.5 | 8424 / 8795 | 1.6 / 4.5 |
| dbread | 800 | 1845 / 2509 | 13102 / 19956 | 1.6 / 18.8 |
| dbwrite | 200 | 2.9 / 8.5 | 3348 / 3570 | 2.4 / 11.5 |
| dbwrite | 800 | 1945 / 2453 | 13020 / 15397 | 2.6 / 46.0 |

### A vs B — the roadmap's actual claim: **decisive win**

Symfony on PHP-FPM collapses on DB workloads at 100–200 rps (at 200 rps `dbread` it
completed **5 094 of 12 000** scheduled requests), while Waffle holds single-digit
milliseconds through 400 rps. Roughly **4–8× the DB throughput headroom**, and ~4.8×
lower p50 at a matched low rate (dbread @ 50 rps: 4.0 ms vs 19.2 ms).

### A vs C — parity to 400 rps, then an earlier knee

Both worker engines are equivalent up to 400 rps. Above that, C sustains 800 rps on DB
workloads where A queues. Investigated rather than published as-is:

- **Not the connection pool.** Sweeping `DB_POOL_SIZE` 8 → 32 → 64 barely moved the
  median (75 / 85 / 74 ms).
- **Not a slow query or per-request connection cost.** At single-request concurrency
  A's DB route answers in 6.8–11.6 ms versus 4.8–14 ms for its no-DB route — no DB
  penalty.
- **It is per-request work.** Waffle's default pipeline is 12 middlewares (fail-closed
  ABAC, CSRF, auth, anonymous session, CORS, trusted-host, metrics, tracing,
  transaction isolation, secure headers) plus ping-before-dispense on pool lease, which
  doubles DB round trips. The Symfony baseline runs FrameworkBundle + DoctrineBundle
  only — **no security, no CSRF, no telemetry, no per-request transaction**.

> **Fairness caveat — state this wherever these numbers are quoted.** This is
> *Waffle's fully-secured default stack* against a *bare* Symfony app, not a
> like-for-like framework-overhead measurement. Waffle doing more work per request is
> the product decision, but it must not be presented as pure framework overhead.
> Beta7 should add an "equivalent-features Symfony" engine (security-bundle + CSRF +
> a transaction subscriber) to separate the two.

**Actionable optimisation identified:** make ping-before-dispense skippable for
connections leased within a freshness window — halves DB round trips on the hot path.
Recorded as a beta7 item.

---

## `[BENCH-03]` Soak — ΔM

Method: constant 150 rps, all five workloads round-robin, **3 hours per worker engine** (the full
window the roadmap specifies), RSS sampled every 5 s, `MAX_REQUESTS=1000000` so the worker loop
never recycles and cannot mask a leak.

| Engine | Requests | p50 / p99 | First window | Last window | ΔM | Verdict |
|---|---:|---|---|---|---|---|
| A (Waffle worker) | 1 620 001 | 1.85 / 6.23 ms | 73.21 MiB | 71.45 MiB | **−1.76 MiB** | **PASS** |
| C (Symfony worker) | 1 620 001 | 1.68 / 4.80 ms | 60.78 MiB | 60.49 MiB | **−0.29 MiB** | **PASS** |

Zero failed requests on either engine across 1.62 million requests each (1 729 RSS samples per run,
tolerance ±5 MiB). **Both deltas are negative** — memory ended *lower* than it began, which is the
opposite of a leak rather than merely a small one. Peak RSS: A 76.0 MiB, C 64.4 MiB. Cross-checked
against `wfl igor` (0 KO) on the same build.

**Why the full window mattered.** The initial 30-minute pass reported +1.5 MiB and, read alone,
looked like a mild upward drift; its 30-minute buckets ran 73.07 → 73.31 → 73.93 MiB, which
extrapolates to a slow leak. Over three hours the trajectory settles back
(73.07 / 73.31 / 73.93 / 73.22 / 70.77 / 71.75 / 70.64 MiB) and the drift inverts. The short window
was not wrong so much as **too short to distinguish settling from leaking** — exactly the failure
mode a ΔM gate exists to catch, and the reason the shortened run was re-done at full length rather
than published with a caveat.

Detection sensitivity improved accordingly: the bound on an undetectable leak rate falls from
~10 MB/h (30 min) to **~1.7 MB/h** (3 h), a ~6× sharper claim.

## `[BENCH-04]` Connection-pool starvation

Method: closed-model ramp 8 → 16 → 32 → 64 VUs against `dbread`/`dbwrite` with
`DB_POOL_SIZE=8` — i.e. **8× oversubscription** of the pool at peak.

| Metric | Value |
|---|---|
| Sustained throughput | **868.8 req/s** (417 066 requests) |
| Latency p50 / p95 / p99 / p99.9 | 25.0 / 76.9 / 81.6 / **98.4 ms** |
| `pool_exhausted` (5xx) | **0** |
| Failed requests | **0.00 %** |
| RSS mean / peak | 70.3 / 74.0 MiB (flat) |

**PASS.** Degradation is bounded and graceful: at 8× oversubscription the p99.9 stays
under 100 ms, no request is rejected, no deadlock occurs, and the pool returns to idle
with no leaked or severed connections. Lease-wait latency shows up as the orderly
climb from ~4 ms (unsaturated) to 25 ms p50, exactly the expected queueing behaviour.

**This reframes the BENCH-02 result.** BENCH-02 uses an *open* model (unbounded
arrival), where exceeding capacity queues without limit — textbook behaviour for any
system without admission control, not a Waffle defect. Under the *closed* model real
clients actually impose, the same engine and the same 8-connection pool sustain
**868 rps with a sub-100 ms p99.9**. Quote BENCH-04 for capacity, BENCH-02 for
latency-under-arrival-rate.

---

## `[BENCH-05]` Memory vs concurrency — the corrected RAM experiment

Method: closed model, `constant-vus` steps **8 → 16 → 32 → 64 → 128**, 2 min each,
workload `dbread` (holds a connection for the life of the request, so a request in
flight genuinely occupies a worker or child). CPU pinned at 2 (controlled variable);
memory raised to 6 GiB and FPM switched to `pm=dynamic, max_children=128` so the
dependent variable can actually move.

### RSS by concurrency

| concurrency | A — Waffle worker | B — Symfony FPM (dynamic) | B/A |
|---:|---:|---:|---:|
| 8 | 68.0 MiB | 59.4 MiB | **0.87×** |
| 16 | 68.4 MiB | 73.4 MiB | 1.07× |
| 32 | 71.1 MiB | 96.4 MiB | 1.36× |
| 64 | 74.5 MiB | 130.9 MiB | 1.76× |
| 128 | 80.6 MiB | 191.2 MiB | **2.37×** |

**Growth rate — the real result:**

| Engine | RSS slope | Interpretation |
|---|---|---|
| A (worker) | **+0.105 MiB** per concurrent request | fixed worker set; memory ~flat |
| B (FPM) | **+1.099 MiB** per concurrent request | one process per in-flight request |

**FPM's memory grows 10.5× faster per unit of concurrency.** That ratio — not a single
total-RAM number — is the defensible claim, and it is the mechanism the "5–10×" slogan
was always gesturing at.

### What this means for the "5–10× RAM" claim — state it this way

- **At low concurrency the claim is false, and inverted.** At 8 concurrent requests
  Symfony/FPM uses *less* total RAM than Waffle (0.87×), because Waffle pays a fixed
  floor — 256 MB opcache + 128 MB JIT buffer shared across a resident worker set —
  that FPM amortises differently. Publishing "5–10× less RAM" without qualification
  would be refutable by anyone running a small instance.
- **The crossover is near 12–16 concurrent requests.** Below it FPM wins on total RAM;
  above it Waffle wins, and the gap widens without bound.
- **Measured, at 128 concurrent: 2.37×.** That is the number this rig earned.
- **5× extrapolates to ≈490 concurrent requests** on these slopes — beyond the measured
  range, and it also requires `max_children` ≳ 490, since at 128 children FPM stops
  growing and starts queueing instead. **10× is not reachable by extrapolation** here,
  because Waffle's slope is small but not zero.

> **Recommendation for the conference:** publish the *slope* (10.5× lower memory growth
> per concurrent request), the measured 2.37× at 128 concurrency, and the crossover
> point. Do not publish a bare "5–10×". The slope is the honest, defensible, and
> frankly more interesting claim — it says the two runtimes have different *shapes*,
> not merely different constants.

### Throughput at the same concurrency (secondary, but decisive)

Both engines under the *fairer* dynamic-pool FPM configuration:

| Engine | throughput | p50 | p99 | errors |
|---|---:|---:|---:|---:|
| A — Waffle worker | **781.6 req/s** | 35.0 ms | 223.9 ms | 0.00 % |
| B — Symfony FPM (dynamic, 128 children) | 100.5 req/s | 303.7 ms | 2076.0 ms | 0.03 % |

**7.8× the throughput at identical concurrency and CPU.** This also retires the concern
that BENCH-02's `pm.static` pinning unfairly penalised FPM: given a dynamic pool with
128 children — a *more* favourable configuration — FPM still delivers an eighth of the
throughput at 8.7× the p50 latency.

---

## Deviations from the specification (all deliberate, none silent)

1. **BENCH-02 step duration 1 min, not 2**, and three workloads (`json`, `dbread`,
   `dbwrite`) rather than five. Time-boxing for a same-day release; costs statistical
   smoothing per step, not validity. `hello`/`greet` are covered by the smoke pass.
2. ~~BENCH-03 soak 30 min per engine.~~ **Resolved 2026-08-03:** re-run at the full 3 h per
   worker engine. The shortened window is retained in the history only as the reason the re-run
   happened — its apparent +1.5 MiB upward drift did not survive the longer observation.
3. **The 5–10× RAM factor is not published from BENCH-02.** The harness pinned
   `pm.static, max_children=16` and `mem_limit: 1g`, which makes FPM's memory constant
   by construction and truncates the dependent variable — it cannot demonstrate *or*
   refute the claim. BENCH-05 was built to answer it properly. Publishing a factor from
   BENCH-02 would have been a fabricated number.
4. **Engine A is built by a bench-specific Dockerfile.** Skeleton's own prod image
   resolves `waffle-commons/*` from Packagist — the released beta5 — which both
   boot-loops against beta6 app code and would have measured the wrong framework
   version. The bench builder performs skeleton's real prod install, then overlays each
   vendored component's `src/` from the working tree and re-dumps an authoritative
   classmap.
5. **`intl` is not installed on engines B/C.** Unused by every workload and the single
   slowest build step; opcache/JIT parity — what actually shapes throughput — is intact.

## Defects found by this benchmark (all fixed at source)

| Defect | Where | Consequence |
|---|---|---|
| No `pdo_pgsql` / `pdo_mysql` in the shipped prod image | `skeleton/docker/Dockerfile` | every DB route in the template failed; user-facing since beta5 |
| `/greet` GET-only while its docblock documents `POST` | `skeleton/src/Controller/HelloController.php` | documented call returned 405 |
| Demo routes lacked `#[PublicAccess]` | `skeleton/src/Controller/HelloController.php` | 403 through the real pipeline; controller tests bypassed it |
| `driver: mysql` with no DB service in compose | `skeleton/config/app.yaml` | default template pairing could not work |
| k6 and `init.sql` used different id schemes | `bench/k6/lib/common.js` | **every `dbread` was a miss** — invisible on A (200 `found:false`), loud on B/C (404) |
| Engine miss semantics diverged (200 vs 404) | `bench/scripts/stubs/.../BenchController.php` | an id drift could masquerade as "Symfony is broken" |

## Reproducing

```bash
cd bench
./scripts/bootstrap-symfony.sh                     # generates the gitignored Symfony app
docker compose -f docker-compose.bench.yml build
./scripts/run-bench.sh engine-a smoke              # gate: require 0 % failures first
RATES=50,100,200,400,800 STEP_DURATION=2m ./scripts/run-bench.sh engine-a constant dbread
RATE=150 DURATION=3h ./scripts/run-bench.sh engine-a soak
DB_POOL_SIZE=8 ./scripts/run-bench.sh engine-a starve
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m ./scripts/run-bench.sh engine-a-mem memscale
./scripts/report.sh
```
