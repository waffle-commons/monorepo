---
name: ecoshield
description: "[Dogfood — the v1 adoption criterion] EcoShield Gateway, the standalone Strangler-Fig FinOps gateway in its own repo: alpha on beta7 ([GATE-02]), beta + FinOps benchmark on beta8 ([GATE-03]), ≥4-week RC1 soak and launch benchmark ([RC-04/05]) — public APIs only, French docs, independent versions, measurable claims"
compatibility: opencode
---

## What I do
I carry the dogfooding project that decides v1 adoption. EcoShield Gateway is a FinOps API gateway
placed in front of a legacy PHP monolith, following the Strangler Fig pattern: some routes are served
natively from the resident worker, everything else is proxied, and a PSR-16 "shield" cache absorbs
repeat reads. Success indicator #4 of `Roadmap_v1_Master.md` is this gateway running the full
Strangler-Fig scenario on RC1 for ≥4 weeks without a critical incident. See `[[soak-endurance]]`,
`[[benchmark-gate]]`, `[[resilience-net]]`, `[[security-audit]]`.

## When to use
"EcoShield", "the gateway", "GATE-02 / GATE-03", "FinOps benchmark", "gateway soak", "Strangler Fig",
moving the gateway onto a new framework release, any claim about the gateway's performance.

## Where it lives — an application, not a component
- Its own repository `waffle-commons/ecoshield-gateway`, checked out at
  `contributions/ecoshield-gateway/`. The umbrella gitignores it: never a submodule, never in
  `RELEASE_INCLUDE`, never covered by `wfl check:all` or `wfl igor`. Run its gates from its own directory.
- Published on Packagist and tagged `0.1.0` (POC) and `0.1.1` (measurement correction). It is a released
  artefact: change it only when the request names it (`AGENTS.md` §6).
- It consumes **released** framework versions from Packagist (`waffle-commons/*: ^0.1.0-beta6` today).
  Framework work lands and ships first; only then does the gateway move.

## Conventions (non-negotiable)
- **Public Waffle APIs only.** A needed private reach-through is a **framework design bug**: record it in
  the framework roadmap and fix it there, never work around it in the gateway. The beta6 POC needed none.
- **French documentation, English code.** README, CHANGELOG, `BENCHMARK_RESULTS.md`, bench reports and
  release notes are French — they are written for the Attineos catalogue. Identifiers, code comments and
  technical messages stay English.
- **Independent versioning.** The version describes the gateway, never the framework: `0.2.0` alpha
  (built on `0.1.0-beta7`) → `0.3.0` beta (on `0.1.0-beta8`) → `1.0.0` after the RC1 soak. The gateway
  build that soaks on `1.0.0-RC1` gets whatever version the maintainer chooses; the ladder fixes only those
  three steps. Each CHANGELOG entry names the framework version it was built and verified on; release
  headings are month-precision (`## [0.2.0] — 2026-10`).
- **Measurable claims only.** Every figure in README, CHANGELOG or offer text comes from a published run
  with its method and scope: slope + crossover, never a bare RAM percentage (the "~80 % RAM" claim was
  withdrawn); latency with its concurrency and rate. No warranty wording (`garantit` contradicts the MIT
  disclaimer), no invented statistic, no unmeasured environmental claim.
- **Production is the default compose.** Only the gateway publishes a port; the monolith is reachable
  only through it (an exposed upstream makes the shield bypassable). `docker-compose.dev.yml` (bind
  mounts), `docker-compose.perf.yml` (bounded measurement stack) and `docker-compose.symfony.yml` (the real
  Symfony 5.4 monolith) are overrides.
- **Diagnostics closed by default.** `/__ecoshield/memory` answers only when `ECOSHIELD_DIAGNOSTICS` is
  set: a gateway's heap footprint tells an attacker how their requests affect it.
- **Proxy invariants from the POC, regression-tested:** hop-by-hop headers stripped in both directions,
  including the fields named by `Connection`; `Host` recomputed; `X-Forwarded-*` appended, never trusted;
  ambiguous framing rejected (request smuggling); 502 without internal topology; the body stream passed
  **by reference** — one `(string)` cast would load the payload into worker memory, and a test asserts
  the same stream instance.

## Maturity ladder
| Step | Framework | Gateway | What must be true |
|---|---|---|---|
| `[GATE-01]` POC | beta6 | 0.1.x | ✅ shipped: proxy, rescue and shield on public APIs; igor 0 KO; 100 % coverage |
| `[GATE-02]` alpha | beta7 | 0.2.0 | the Strangler route served natively with cache **and the beta7 rate limiter** `[NET-01]`; the catch-all proxy **over the resilient client** `[NET-02/03]` (bounded timeouts, idempotency-aware retries, breaker); a reproducible legacy lab. **Beta7 stretch tier:** cut first when the schedule bites. |
| `[GATE-03]` beta | beta8 | 0.3.0 | the FinOps benchmark in its own repo: k6 **≥1000 rps**, Scenario A (legacy PHP-FPM direct) vs Scenario B (through the gateway) — RAM ceiling, latency, breaking point. The report is a v1 launch asset and the proof for indicator #2 (slope + measured RAM factor + crossover). |
| `[RC-04]` soak | RC1 | RC1 build | ≥4 weeks continuous, production-like traffic, chaos injections — `[[soak-endurance]]` |
| `[RC-05]` | RC1 | RC1 build | the FinOps benchmark re-run **on the RC bits**; launch numbers come from the RC, not a beta |
| `1.0.0` | 1.0.0 | 1.0.0 | once the soak passes |

## Carried into 0.2.0
From the 0.1.1 release notes and `BENCHMARK_RESULTS.md`:
- `MAX_REQUESTS` above the campaign total (10 000 000 rather than 1 000 000). The 3 h window contained a
  worker recycle, so it proves "no drift over a window containing a recycle", not "one worker ran 3 h".
- A per-step warm-up in the ladder: the first step starts cold and is penalised.
- The fate of the two demonstration routes (`/api/products/{id}`, `/api/users/{id}`).

**Done on 2026-09-30:**
- **Toolchain in lockstep with the umbrella:** mago `^1.50`, igor-php `^0.9.7`, and the CI igor job
  pinned to 0.9.7 with the robust pin check (a cached binary is dropped, and the check is an exact
  version-line match). Actions: checkout v7, cache v6, TruffleHog pinned. The igor 0.9.7 audit gives
  12 OK / 0 KO / 0 WARN after two fixes: `MAX_REQUESTS` read from the env registry, and a verified
  `#[WorkerSafe]` on `ResponseCache::store()`. Recorded in the gateway's CHANGELOG under
  `[Non publié]`.
- **Framework findings it surfaced, fixed in the framework** (`Roadmap_Beta7.md` `[CARRY-10]`, ships with
  beta7):
  - `ErrorHandlerMiddleware` now logs by rendered status — 5xx `critical` with the trace, 4xx `notice`
    without it;
  - `GlobalsFactory` no longer warns when workers race to create the upload root.
  The gateway gets both once it builds on `0.1.0-beta7`.

## Measuring it
The published harness uses a **native generator**: k6 on the host (never in a container on macOS),
CPU-bounded containers, a fixed arrival rate.
```bash
cd contributions/ecoshield-gateway
bench/legacy-symfony/bootstrap.sh     # the real Symfony 5.4 monolith (generated, not versioned)
docker compose -f docker-compose.yml -f docker-compose.perf.yml -f docker-compose.symfony.yml up -d --build
bench/scripts/perf-run.sh full        # soak + ladder + memscale + perimeter (~55 min)
DURATION=3h caffeinate -i bench/scripts/perf-run.sh full   # publication-grade soak (~3 h 50)
```
Traps specific to this harness, all recorded in `BENCHMARK_RESULTS.md` §8:
- Perimeter probes need a unique query, or the shield answers them from cache.
- Smuggling probes must target a **proxied** route; rescued routes never reach `ProxyController`.
- The warm-up must not write a summary that could pass for a measurement.
- k6 reports a sub-metric rate over the whole run: recompute it per step.
- A saturating subject (high latency, capped rate) is a result; a failing generator (fast subject, rate
  not held) is not. Latency tells them apart.
- Exclude `pm.max_children`-capped steps from the legacy slope, and only on a series that actually grew.

Analyse soaks with `[[soak-endurance]]` and the `soak-analyst` agent.

## Gates, in the gateway repo
```bash
docker exec -w /waffle-commons/contributions/ecoshield-gateway waffle-dev composer mago    # zero output
docker exec -w /waffle-commons/contributions/ecoshield-gateway waffle-dev composer tests
docker exec -w /waffle-commons/contributions/ecoshield-gateway waffle-dev composer igor    # 0 KO
```
Its CI (`.github/workflows/main.yml`) runs the same mago steps and PHPUnit; every git, tag and Packagist
action is the maintainer's.
