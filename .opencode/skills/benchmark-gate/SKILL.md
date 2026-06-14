---
name: benchmark-gate
description: Run and record the benchmark gate that decides whether a performance/pooling item proceeds (GC churn, memory curve, AOT/pool/telemetry overhead) — produces a GATE-RESULT.md
compatibility: opencode
---

## What I do
Several roadmap items are **benchmark-gated**: they proceed only if a measurement proves the win (or
proves the absence of a problem). I capture the baseline, run the benchmark under representative
worker-mode load, and write a `…-GATE-RESULT.md` decision record next to the component. The result —
**proceed** or **deferred** — is itself the deliverable. See `[[worker-safety]]`.

## When to use
"is STB-02 / pooling worth it?", "benchmark the compiled container", "measure GC churn / memory
drift", "does this meet the latency/overhead gate?", any roadmap item tagged *benchmark-gated*.

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
- **v1 success indicators** — < 10ms p99 hello-world in worker mode; 5–10× RAM reduction vs PHP-FPM
  (EcoShield-Gateway FinOps benchmark, k6 ≥ 1000 rps).

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
```
Record the verdict in `{component}/benchmarks/<ITEM>-GATE-RESULT.md`. Never enable JIT/bench profile
numbers while xdebug is on.
