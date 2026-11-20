---
name: benchmark-gate
description: "Run and record a benchmark gate (GATE-RESULT.md) and hold every published number to the same method"
when_to_use: >-
  "Is X worth it?", benchmarking the compiled container, GC churn, memory curve or drift, AOT / pool
  / telemetry overhead, CARRY-01 ping freshness, the EcoShield FinOps benchmark, "can we publish
  this number?", or any roadmap item tagged benchmark-gated.
---

## What I do
Several roadmap items are **benchmark-gated**: they proceed only if a measurement proves the win (or
proves the absence of a problem). I capture the baseline, run the benchmark under representative
worker-mode load, and write a `…-GATE-RESULT.md` decision record next to the component. The result —
**proceed** or **deferred** — is itself the deliverable. Every number that leaves the project (README,
conference, discussion post, commercial offer) meets the same bar. See `[[worker-safety]]`,
`[[soak-endurance]]`, `[[ecoshield]]`.

## When to use
"is X worth it?", "benchmark the compiled container", "measure GC churn / memory drift", "does this
meet the latency/overhead gate?", "the FinOps benchmark", "can we publish this number?", any roadmap
item tagged *benchmark-gated*.

## Gated items across the train
- **Beta4 STB-02** — buffer-pool object recycling. Gate: profile GC churn under load **first**;
  proceed only if there is material GC pressure. (Result shipped: `http/benchmarks/STB-02-GATE-RESULT.md`
  recorded 0 GC cycles / flat memory ⇒ **deferred**, no pooling code. Keep that record.)
- **Beta5 AOT-01/02** — compiled container/router measured against the runtime-reflection baseline;
  the compiled graph must be **snapshot-identical** to the runtime one.
- **Beta5 DBAL** — zero connection errors over a 24h soak incl. forced DB restarts (heal-on-lease);
  zero transaction leakage across worker iterations (Igor-style).
- **Beta5 OBS** — `/waffle-metrics` scrape overhead < 5ms; W3C trace context end-to-end across two
  services.
- **Beta6 BENCH-01..05 (shipped)** — `bench/BENCH-GATE-RESULT.md`. The flat "5–10× RAM vs PHP-FPM" claim
  did not survive: false below ~12 concurrent requests, crossover at 12–16, 2.37× at 128. The defensible
  claim is the growth **slope**: memory grows 10.5× slower per concurrent request than PHP-FPM.
- **Beta7 `[CARRY-01]`, `[CARRY-02]` (done, history):**
  - `[CARRY-01]`, the pool's ping freshness window, passed its gate on 2026-10-22
    (`data/benchmarks/CARRY-01-GATE-RESULT.md`): the `dbread` knee rose from 1200 to 1500 and ≥ 1600 rps
    in two repeats, and dead connections are still caught.
  - `[CARRY-02]` hardened the rig on 2026-10-22. Its clean full run (`carry02-20261101T015247Z`) is the
    current series, published in `bench/BENCH-GATE-RESULT.md` since 2026-11-02.
  - The method rules they set live in the protocol and the traps below.
- **Beta8 `[GATE-03]`** — the EcoShield FinOps benchmark: k6 ≥1000 rps, legacy PHP-FPM direct vs
  through the gateway — RAM ceiling, latency, breaking point (`[[ecoshield]]`).
- **RC1 `[RC-05]`** — the same benchmark re-run on the RC bits. Launch numbers come from the RC.
- **v1 success indicator #2** — <10 ms p99 hello-world in production worker mode, and a memory-growth
  slope ~10× lower per concurrent request than PHP-FPM, published **with** the measured total-RAM factor
  and the crossover point. Never a bare "5–10×".

## Method traps (each one invalidated a whole campaign)
- **Measure the production image,** never the dev image (bind mounts + opcache revalidation measure the
  file system).
- **Give the baseline the capacity its curve assumes.** `pm.max_children = 5` measured a queue;
  `pm = static` pre-allocates and hides the memory slope; `pm = ondemand` with a high ceiling tracks
  concurrency.
- **Compare like for like.** Next to a bare comparator, run one doing the subject's per-request work
  (Engine D: security, CSRF, one transaction per unsafe request). Pin every image by digest, and run the
  baseline on the subject's PHP.
- **A leak is a positive slope** (least squares), measured from a settled baseline.
- **Publish the 95 % bound, not just the value.**
- **Worker recycling masks leaks:** pin `MAX_REQUESTS`, and each comparator's own limit (Symfony's
  `FRANKENPHP_LOOP_MAX`), above the run's total, and record them. Engine C's 500-request default
  invalidated the beta6 soak comparison.
- **A laptop cannot measure capacity.** When the generator shares vCPUs with the subject, throughput
  past ~16 concurrent describes contention; quadrupling workers moving throughput <5 % is the tell.
- **Check that the host stayed idle** against its power log (`pmset -g log`) for the whole window. Two
  beta7 runs overlapped work and media on the laptop: both are kept as invalidated, nothing published.
- **Keep every series, invalidated ones included.** `bench/scripts/run-bench.sh` puts a `RUN_ID` in
  each file name and refuses to overwrite a series. A bench that archives only its flattering runs
  proves nothing.
- **A re-measurement is a new series.** Publish it beside the old one, keep the old one as written, and
  quote only the current one. A fix to what was measured calls for one (`[CARRY-08]`'s preload did).

## Publishing rules
- A number travels with its method, scope and uncertainty: engine, image, concurrency or rate, window
  length, host.
- Memory claims are **slope + crossover** (+ the RAM factor at a stated concurrency), never a flat
  percentage.
- Every published figure is re-derivable from archived raw data. Say where the data lives, and say when
  it no longer exists.
- EcoShield's commercial texts are French and follow the same rules — no warranty wording, no
  unmeasured environmental claim (`[[ecoshield]]`).

## Protocol
1. **Capture the baseline before any change** (numbers, not vibes), on today's rig: re-measure an
   inherited one (in `[CARRY-01]`, the beta6 knee no longer reproduced). Without a baseline there is no
   gate.
2. **Run under representative load** — phpbench for micro/CPU; the worker-mode sandbox + `wfl igor`
   replay for memory/GC drift; k6 for end-to-end rps. Interleave the compared settings on one image, and
   repeat.
3. **Fix the threshold before the comparison runs, then decide against it**, not intuition. When the
   change relaxes a safety check, the gate also proves the check still holds (`[CARRY-01]`: stale
   connections still caught). If the gate fails, the item is **deferred, not implemented** — that is a
   valid, expected outcome.
4. **Write `…-GATE-RESULT.md`**: baseline, method, raw numbers, threshold, verdict (**proceed** /
   **deferred**), and — if deferred — the constraint that justifies it (e.g. PSR-7 immutability erodes
   pooling wins; pooling mutable messages violates statelessness).

## Execution (in Docker)
```bash
docker exec -w /waffle-commons/{component} waffle-dev composer benchmark   # phpbench (default_report)
wfl bench                                                                      # switch container to 🚀 bench profile (JIT on, xdebug off)
wfl igor                                                                       # memory-drift replay for state leaks
{umbrella}/bench/scripts/run-bench.sh <engine> <scenario> [workload]           # the tri-engine k6 rig (see bench/README.md)
```
`{umbrella}` is the absolute path of the umbrella checkout; `run-bench.sh` locates `bench/` itself.
Record the verdict in `{component}/benchmarks/<ITEM>-GATE-RESULT.md` (the ecosystem rig publishes in
`bench/BENCH-GATE-RESULT.md`; the gateway in its own `BENCHMARK_RESULTS.md`). Never enable JIT/bench
profile numbers while xdebug is on. Dispatch the `benchmark-runner` agent for a gated item and
`soak-analyst` for a memory series.
