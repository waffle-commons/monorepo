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
- **Beta7 `[CARRY-01]`** — make the pool's ping-before-dispense skippable within a freshness window. The
  beta6 benchmark traced Waffle's early saturation knee to that doubled DB round trip. Baseline = the
  beta6 knee. Proceed only if the knee moves **and** stale connections are still caught (the fail-safe
  stays). Contracts-first if the pool contract changes.
- **Beta8 `[GATE-03]`** — the EcoShield FinOps benchmark: k6 ≥1000 rps, legacy PHP-FPM direct vs
  through the gateway — RAM ceiling, latency, breaking point (`[[ecoshield]]`).
- **RC1 `[RC-05]`** — the same benchmark re-run on the RC bits. Launch numbers come from the RC.
- **v1 success indicator #2** — <10 ms p99 hello-world in production worker mode, and a memory-growth
  slope ~10× lower per concurrent request than PHP-FPM, published **with** the measured total-RAM factor
  and the crossover point. Never a bare "5–10×".

## Before any new public number — `[CARRY-02]` harness hardening
- **Run-unique result files.** `bench/scripts/run-bench.sh` names results
  `<engine>-<scenario>-<workload>`, so a re-run overwrites a series. The beta6 pool-size sweep survives
  only as numbers in `BENCH-GATE-RESULT.md`.
- **A fair Engine C:** symfony/runtime 7.4's native `FrankenPhpWorkerRunner` with
  `FRANKENPHP_LOOP_MAX=1000000` and no `APP_RUNTIME` override (its 500-request default invalidated the
  beta6 soak comparison). Engine C also runs the memory test.
- **An equivalent-features Symfony engine** (security + CSRF + transaction subscriber) next to the bare
  one, so framework overhead is compared like for like.
- **Host hardware recorded with every run**; least-squares slopes published with their uncertainty.
- **Re-measure after `[CARRY-08]`:** the beta6 numbers ran a skeleton image whose preload never fully
  worked.

## Method traps (each one invalidated a whole campaign)
- **Measure the production image,** never the dev image (bind mounts + opcache revalidation measure the
  file system).
- **Give the baseline the capacity its curve assumes.** `pm.max_children = 5` measured a queue;
  `pm = static` pre-allocates and hides the memory slope; `pm = ondemand` with a high ceiling tracks
  concurrency.
- **A leak is a positive slope,** measured from a settled baseline.
- **Publish the 95 % bound, not just the value.**
- **Worker recycling (`MAX_REQUESTS`) masks leaks:** pin it above the run's total and record it.
- **A laptop cannot measure capacity.** When the generator shares vCPUs with the subject, throughput
  past ~16 concurrent describes contention; quadrupling workers moving throughput <5 % is the tell.
- **Keep the invalidated series.** A bench that archives only its flattering runs proves nothing.

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
1. **Capture the baseline before any change** (numbers, not vibes). Without a baseline there is no gate.
2. **Run under representative load** — phpbench for micro/CPU; the worker-mode sandbox + `wfl igor`
   replay for memory/GC drift; k6 for end-to-end rps.
3. **Decide against the stated threshold**, not intuition. If the gate fails, the item is **deferred,
   not implemented** — that is a valid, expected outcome.
4. **Write `…-GATE-RESULT.md`**: baseline, method, raw numbers, threshold, verdict (**proceed** /
   **deferred**), and — if deferred — the constraint that justifies it (e.g. PSR-7 immutability erodes
   pooling wins; pooling mutable messages violates statelessness).

## Execution (in Docker)
```bash
docker exec -it -w /waffle-commons/{component} waffle-dev composer benchmark   # phpbench (default_report)
wfl bench                                                                      # switch container to 🚀 bench profile (JIT on, xdebug off)
wfl igor                                                                       # memory-drift replay for state leaks
cd bench && scripts/run-bench.sh <engine> <scenario> [workload]                # the tri-engine k6 rig (see bench/README.md)
```
Record the verdict in `{component}/benchmarks/<ITEM>-GATE-RESULT.md` (the ecosystem rig publishes in
`bench/BENCH-GATE-RESULT.md`; the gateway in its own `BENCHMARK_RESULTS.md`). Never enable JIT/bench
profile numbers while xdebug is on. Dispatch the `benchmark-runner` agent for a gated item and
`soak-analyst` for a memory series.
