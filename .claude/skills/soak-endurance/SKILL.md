---
name: soak-endurance
description: "Soak and chaos method: 72 h soak (beta8 STAB-01), >=4-week EcoShield soak (RC1 RC-04), slope with 95% bound"
when_to_use: >-
  Soak, endurance, memory drift / delta-M / leak, 72 h, the four-week soak, chaos or fault
  injection, SLOs, "is this soak still valid?", any claim shaped like "runs for X without Y".
---

## What I do
I plan, run and judge endurance campaigns — the evidence behind "zero memory drift", "zero leaked
connections" and "zero un-injected 5xx". Two campaigns stand between beta8 and v1: the **72 h soak**
(`[STAB-01]`, item 3 of the freeze exit gate) and the **≥4-week gateway soak** on RC1 (`[RC-04]`,
success indicator #4, the v1 adoption criterion). See `[[ecoshield]]`, `[[benchmark-gate]]`,
`[[worker-safety]]`, `[[resilience-net]]`, `[[k8s-ops]]`.

## When to use
"soak", "endurance", "memory drift / ΔM / leak", "72 h", "four-week soak", "chaos / fault injection",
"is this soak still valid?", any claim shaped like "runs for X without Y".

## What each campaign must show
| Campaign | Subjects | Pass |
|---|---|---|
| beta8 `[STAB-01]` | the workspace demo apps + EcoShield Gateway; AOT compiled-vs-runtime parity on real apps, DBAL pool exhaustion and reconnect, queue-worker endurance, breaker and limiter under chaos | 72 h of continuous k6 load: zero memory drift (backed by `wfl igor`), zero connection leakage, zero 5xx not injected by the chaos scenario |
| RC1 `[RC-04]` | EcoShield Gateway, full Strangler-Fig scenario on the RC bits | ≥4 weeks: zero critical incidents, zero memory drift, SLOs held (p99 latency, error budget), under chaos: upstream outages → breaker, Redis restarts → limiter/queue recovery, rolling restarts → drain |

- The RC1 soak clock **starts at the `1.0.0-RC1` tag** and is **never shortened** to recover a date.
- An RC2 (critical defects only) **restarts** it.
- The window straddles the year-end holidays: staff incident response, or the soak certifies nothing.

## Method — the traps that invalidated whole campaigns
1. **Production image only.** Code baked in, opcache frozen, preload on. The dev image measures bind
   mounts and opcache revalidation, not PHP.
2. **A dedicated host for anything longer than a few hours.** The gateway's first 3 h soak died after
   ~70 min because the laptop's Docker VM ran out of resources. A laptop cannot hold 72 h or four
   weeks. The load generator must not share the subject's CPUs (the gateway harness runs k6 natively
   and bounds every container).
3. **Settle, then sample.** Warm up → rest → start sampling → load. A window starting on the previous
   run's peak regresses to a large negative slope that describes nothing.
4. **Recycling hides leaks.** Set `MAX_REQUESTS` above the campaign's requests per worker (the gateway
   plans 10 000 000) and record it. A window containing recycles supports only "no drift over a window
   with N recycles".
5. **A leak is a positive slope, judged with its bound.** Publish `slope ± 1.96·SE` with the window
   length. The bound shrinks with samples and duration, and it is the ceiling of an undetectable leak.
6. **Watch the instrument.** A sampling gap stretching to ~5× the nominal cadence, or subject and
   baseline collapsing together, is the host failing. Cut at the last stationary point, chosen from the
   series' shape and never from the slope it produces, and say where.
7. **Multi-worker heap series: regress the envelopes**, not the raw alternating series.
8. **Run-unique result files; keep invalidated series.** A re-run must never overwrite a series. The
   umbrella `bench/scripts/run-bench.sh` still names results `<engine>-<scenario>-<workload>`
   (`[CARRY-02]`). A campaign that archives only its good runs proves nothing.
9. **Record the environment with every run:** image digest, FrankenPHP and PHP versions, worker count,
   `MAX_REQUESTS`, pool sizes, host hardware, k6 version, UTC timestamps.

## Leaks other than memory
- **Connections and transactions:** the DIAG connection tracer (`runtime/src/Trace/ConnectionTracker.php`,
  with the dev-mode `waffle/src/Event/Listener/OrphanedConnectionListener.php`) and the pool gauges on
  `/waffle-metrics` (loopback or bearer only — sample from inside the container). An in-use count that
  ratchets upward is a leak.
- **Worker state:** `wfl igor` 0 KO before the campaign. Behaviour that changes with worker age
  (latency creep, cache hit-ratio drift) is state.
- **File descriptors:** sample the fd count of the worker processes next to memory.

## Chaos
The breaker, limiter, probes and drain are beta7 items (`[NET-01..03]`, `[OPS-01/02]`); the catalogue
applies once they exist. Inject one fault at a time, with timestamps, and check the specified reaction
(the `chaos-runner` agent carries the catalogue):
- **Upstream outage** → the breaker opens, fails fast, half-opens after its cool-down.
- **Redis restart** → the limiter and queue reconnect with the documented fail mode.
- **Database restart** → heal-on-lease, zero leaked connections.
- **Rolling restart** → zero lost in-flight requests. This needs **≥2 replicas behind a load
  balancer** (or a real cluster such as kind or k3d): restarting the only replica of a compose stack is
  an outage, not a drain test.

Any 5xx outside an injection window and its recovery tail fails the campaign.

## SLOs for the RC1 soak
Propose them, then record the maintainer's numbers in `Roadmap_RC1.md` **before** the tag: p99 latency
per route class, an error budget (share of 5xx outside injection windows), zero criticals. An SLO chosen
after the data is a fit, not a test.

## Harnesses
- **EcoShield, native generator:** `RATE=300 DURATION=3h bench/scripts/perf-run.sh soak` in
  `contributions/ecoshield-gateway` (`[[ecoshield]]`); analysis with `bench/scripts/perf-report.py`
  or `bench/drift.py`.
- **Umbrella tri-engine rig:** `bench/scripts/run-bench.sh engine-a soak` (and `engine-c`), memory
  sampled by `bench/scripts/sample-memory.sh`. Results are gitignored under `bench/results/` and archived
  to `project_system/Audits/<release>/bench/`, which is gitignored too: the archive is local only.
- Neither harness runs for 72 h or four weeks as it stands. Result rotation, periodic analysis and
  alerting are part of the beta8 work.

## Output of a campaign
A report next to the harness (`SOAK-<campaign>.md`): environment, valid window, slope ± bound per
series, ΔM against the budget, connection / fd / 5xx counts, injections with their observed reactions,
**established** and **not established** lists, and where the raw data lives. Dispatch `soak-analyst`
for the analysis and `chaos-runner` for injections.
