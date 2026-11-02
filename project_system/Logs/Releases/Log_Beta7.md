---
title: "Log Beta 7"
date_created: '2026-11-02'
date_updated: '2026-11-02'
type: project
status: draft
tags:
  - waffle
  - beta7
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle 0.1.0-beta7

> [!SUMMARY]
> Goal: **the production surface.** Close the gap between a fast framework and an API ecosystem ready
> for production: four new components (`queue`, `openapi`, `serializer`, `testing`), traffic protection
> and outbound resilience (NET), Kubernetes operability (OPS), dev profiler headers (`[DXP-01]`), the
> EcoShield gateway's alpha built on the local beta7 tree (`[GATE-02]`), and a hardened benchmark rig
> that re-measured every published number (`[CARRY-02]`). Full scope: nothing was cut. Every roadmap
> item was accepted on evidence on 2026-10-31. Release: November 2026.
>
> **Draft, 2026-11-02:** written before the wave. §3 holds the last pre-wave gate run; §5 and the
> Packagist check are completed on release day.

## 1. Technical Changelog (What changed)

### New components

| Component | What it does | Item |
|---|---|---|
| `queue` | Redis Streams driver: bounded retries, a back-off that doubles per failed delivery, a dead-letter store that keeps the full envelope. `console` gains `queue:work`: container reset after each message, exit at a message count or a memory ceiling, SIGTERM finishes the message in flight. Mail is a contract only (`MailerInterface`): a mail is a queue message | `[QUEUE-01..03]` |
| `openapi` | `openapi:generate` builds an OpenAPI 3.1 document from `#[Route]` and typed DTOs, validated against the official schema in its tests; `#[Operation]`, `#[Response]` and `#[Property]` overrides; a debug-only `/_docs` (Swagger UI pinned by SRI, under its own CSP) | `[API-01]` |
| `serializer` | Per-DTO normalizers compiled by `serializer:compile`, loaded without reflection on the `WAFFLE_AOT=1` path, with an interpreted fallback whose output must match byte for byte; JSON content negotiation (406 when nothing is acceptable) | `[API-02]` |
| `testing` | `WaffleTestCase` boots the app's kernel in-process and sends PSR-7 requests through the real pipeline, with doubles for the clock (PSR-20), the queue, the mailer, the HTTP client and the rate-limiter store (`require-dev`) | `[TEST-01]` |

### Traffic protection & outbound resilience — AXE 1

| Change | Evidence | Component |
|---|---|---|
| Token-bucket rate limiter per authenticated subject, else per client IP resolved behind trusted proxies (`TrustedProxyClientIpResolver`); `RateLimit-*` headers, `429` + `Retry-After`; the Redis store refills and takes in one Lua script; a Redis outage fails open by default (warning + metric), `closed` is configurable | 8 processes on one 50-token bucket admit exactly 50 of 800 calls; gateway lab: 632 of 1 800 admitted against a bound of 632.7 (`[NET-01]`) | `security`, `data`, `http` |
| Timeout policies that refuse any value below 1 ms or above their ceilings; bounded retries with back-off that never replay a non-idempotent method unless opted in | `ResiliencePoliciesTest` (`contracts`), `RetryingClientTest` (`[NET-02]`) | `contracts`, `http-client` |
| Circuit breaker with its state in Redis; transitions published as `CircuitStateChanged` and counted on `/waffle-metrics` | Fault injection on the workspace: open 2, half_open 2, closed 1, as on 2026-10-21 (`[NET-03]`) | `http-client`, `data`, `contracts` |
| **Fixed:** since beta5 every transport failure read as a request error, so it was never retried nor counted; an unsized body went out chunked next to the caller's `Content-Length`, and nginx answered 400 to every proxied POST and PUT | Found by the EcoShield gateway (`[GATE-02]`) | `http-client` |

### Kubernetes operability — AXE 3

| Change | Evidence | Item |
|---|---|---|
| `/healthz` (liveness, never a dependency) and `/readyz` (the components' health checks, fail-closed), mounted before tracing and the trusted-host check; each check has its own timeout (database connect 2 s, Redis read 1 s) | `/healthz` ≈ 5 µs, `/readyz` ≈ 6 µs + 1.1 µs per probe, nothing retained over 100 000 calls; a database that never answers yields not-ready in 2 s instead of a lease hanging past 15 s | `[OPS-01]` |
| Graceful drain: `/readyz` flips through a `preStop` drain marker, or during Caddy's `shutdown_delay` | A rolling restart of two replicas under k6 lost 0 of 7 501 requests on each path; `wfl drain-check` 9/9 on FrankenPHP 1.13.2 | `[OPS-02]` |
| `db:rollback`, `db:status` and `make:migration` next to `db:migrate`. **Fixed:** every DDL migration failed on MySQL and MariaDB | Live round trip on PostgreSQL, MySQL, MariaDB and SQLite; SQL-generation tests for SQL Server and Oracle (scope change 2026-10-17) | `[OPS-03]` |

### Developer experience & carry-overs

| Item | Outcome |
|---|---|
| `[DXP-01]` | Dev-only profiler headers (`X-Waffle-Time`, `X-Waffle-Memory`, `X-Waffle-Queries`, `Server-Timing`) in `telemetry` |
| `[CARRY-01]` | The PDO pool skips its liveness ping within a freshness window (`DB_PING_FRESHNESS_MS`, 500 ms in the skeleton): transactions per pooled read 4.21 → 2.12 on the bench rig |
| `[CARRY-02]` | Benchmark harness hardened, then the re-measurement (§2) |
| `[CARRY-03]` | `ResettableInterface` stays optional: state kept on purpose is declared with `#[WorkerSafe(reason: …)]` (RFC-001 §5) |
| `[CARRY-04]` | Perimeter of `testing` and `openapi` decided 2026-10-07: PSR-20 clock, `KernelInterface::$container`, no route seam |
| `[CARRY-05]` | igor 0.9.x write-through false positives adjudicated in code (78 verified `#[WorkerSafe]`, 27 of them write-through); the detector fix waits in the igor-php fork for its upstream PR |
| `[CARRY-06]` | `Constant::ATTR_PARAMS`; the compiled container builds its inlined services through `Container::memoise()` (one shared instance, one reset per `reset()`); PHPUnit in the workspace CI job |
| `[CARRY-07]` | Workspace coverage reported, not gated (demo-app policy); everything released keeps the 95 % bar |
| `[CARRY-08]` | Skeleton OPcache preload fixed (70 "unlinked class" warnings) |
| `[CARRY-09]` | The stock skeleton production image answered 500 to every request (its Caddyfile ignored `FRANKENPHP_CONFIG`): fixed |
| `[CARRY-10]` | `ErrorHandlerMiddleware` logs by rendered status (5xx `critical` with the trace, 4xx `notice` without); `GlobalsFactory` no longer warns when workers race to create the upload root |

### Templates (`skeleton`, `workspace`)

- The skeleton wires the rate limiter, the resilient clients, the probes, the migration commands and,
  in debug mode only, the API docs and the profiler headers. The workspace wires the resilient
  clients, the migration commands, `queue:work` and the debug-only API docs.
- **Fixed:** the default Redis cache had no server in dev, so the kernel never booted; a tmpfs
  `mode: 1777` in `docker-compose.prod.yml`, read as decimal, left the upload root unwritable;
  `bin/waffle` resolved the controllers path from the working directory; the production image now
  ships `bin/` and `migrations/`, so a Kubernetes Job runs `db:migrate` from the release image.
- **Security:** PHP 8.5.12 on FrankenPHP 1.13.2, the security releases for PHP2Shell
  (CVE-2026-109618, CVE-2026-109619), base image pinned by digest; Composer pinned by digest in the
  dev and builder stages (it was `composer:latest`).

### Documentation

A reference page and a how-to guide for each new component (`queue`, `serializer`, `openapi`,
`testing`); how-to guides for rate limiting, resilient outbound calls and running on Kubernetes; the
migrations guide covers rollback and status; `reference/configuration-keys.md` lists every `waffle.*`
key the skeleton declares; `explanation/performance.md` carries the beta7 series. `Waffle_Evolutions.md`
is refreshed for this release.

### Infrastructure & tooling (umbrella only)

- Claude Code operating layer in `.claude/` (skills, subagents, team settings), `wfl init` / `wfl doctor`,
  the `waffle-cockpit` mod (status lines, `/dod`, the Bash guard, the release-tag guard) and a pinned
  copy of `mattpocock/skills`; `wfl ai:check` lints the layer in CI.
- Strictness and supply chain: coverage floors that only ratchet up, mutation testing against floors,
  CycloneDX SBOMs, images pinned by digest (`wfl images:pin`, `COPY --from=<image>` included since
  2026-11-02), an install check with the network off, backups.
- CI: one canonical component workflow (`wfl ci:check`); every component workflow starts Redis, so
  the Redis-backed suites no longer skip on GitHub; the igor pin is enforced in CI.

## 2. Benchmark results (`[CARRY-02]`)

Full method and raw data: `bench/BENCH-GATE-RESULT.md`, section *Beta7 re-measurement*. Run
`carry02-20261101T015247Z` (2026-11-01, 01:52–08:19 UTC), FrankenPHP 1.13.2 / PHP 8.5.12, four
engines: A (Waffle skeleton, production image), B (Symfony on php-fpm + nginx), C (Symfony on its
native worker runner), D (Symfony doing A's per-request work). The archive is local:
`project_system/Audits/Beta7/bench/carry02-20261101T015247Z/`.

| Gate | Result |
|---|---|
| Rig hardening | ✅ run-unique series, a host record per run, soak slopes with their 95 % bound, Engine C on Symfony's native runner, Engine D added, images pinned by digest |
| BENCH-02 JSON | ✅ parity: A answers like C, and at least as fast as D |
| BENCH-02 database | ⚠️ **Waffle is slower:** 0.3–0.4 ms above D at the median at 50–100 rps, 0–0.3 ms at 200–800 rps, p99 up to 0.8 ms above D's; cause not investigated (beta8). A's RSS is 7.7–10 MiB below D's at every rate |
| BENCH-05 memory vs concurrency | ✅ FPM's memory grows **12.5× faster** per concurrent request than Waffle's (+1.478 vs +0.118 MiB; beta6: 10.5×); FPM uses less below ≈14 concurrent requests and 2.81× more at 128 |
| BENCH-03 soak, C and D, 150 rps × 2 h | ✅ C +0.15 ± 0.11 MiB/h, D −1.00 ± 0.12 MiB/h, zero errors |

**Not established:** capacity (one laptop, the load generator on the same host, 2 CPUs per engine);
multi-hour stability (the soaks are 2 h, and Waffle's own endurance claim waits for beta8's 72-hour
soak); why Waffle's database path is slower than D's.

**Kept, not published:** two invalidated runs, `carry02-20261031T164459Z` and
`carry02-20261101T000522Z`: the laptop was in use while they ran. A's dbread step at 800 rps in the
published run overlapped a macOS Contacts sync and is flagged.

## 3. Quality gates

Final pre-wave run, 2026-11-02:

- `wfl pre-release --all`: **READY** for all 27 repositories in `RELEASE_INCLUDE`. 26 DoD PASS (Mago zero
  output, a clean PHPUnit verdict, coverage at or above 95 % and each component's floor, `wfl igor` 0 KO
  with auditor 0.9.7, `composer audit` without advisories); `documentation` has no `composer.json`, so
  only its paperwork applies. Every README is stamped `0.1.0-beta7`, every CHANGELOG has its entry,
  and a CycloneDX SBOM was written for each package.
- Line coverage: 100 % on `async`, `contracts`, `error-handler`, `event-dispatcher`, `pipeline`,
  `telemetry`, `telemetry-otel` and `testing`; the lowest are `cache` 95.57 %, `data` 95.90 % and
  `config` 96.00 %. The four new components: `openapi` 99.06 %, `queue` 97.55 %, `serializer` 98.94 %,
  `testing` 100 %.
- Acceptance check of 2026-10-31 (two `acceptance-verifier` runs, targeted tests in `waffle-dev`): NET,
  QUEUE, OPS, API and "all items" pass on evidence.
- `wfl ci:check`: no drift across the 25 library components (igor pin 0.9.7).
- `wfl rulesets:check`: 30 repositories aligned, 0 drifted.
- `wfl ai:check`: clean.

## 4. Known gaps carried forward

- **Database path:** 0.3–0.4 ms slower at the median than Symfony doing the same work (beta8
  performance question).
- **`RetryPolicy`** bounds its back-off cap and budget from below only; a ceiling is a beta8 question.
- **`[CARRY-05]`:** the igor-php detector fix needs its upstream PR; once a release carries it and the pin
  moves, the 27 method-level annotations become one per dependency.
- **`[GATE-02]`:** the gateway's alpha (0.2.0) moves from the local beta7 tree to the released packages
  after the wave: drop the local framework copies, `composer update 'waffle-commons/*'`, rerun the
  gates and the lab on the production image.
- **Toolchain bumps not taken before the tag:** Dependabot proposes mago 1.58.2, igor-php 0.10.1, psalm
  6.20.1 and php-mock-phpunit 2.16.0 on `contracts` (igor stays pinned at 0.9.7 by `.igor-version`).
- **`contracts` still carries `mixed`** (`Reactive\MutationRecord::$value`, the `MatchedRoute` and
  `Route` docblocks): for the beta8 BC review.

## 5. Release mechanics

*Completed on release day.* What the wave enforces, as of 2026-11-02:

- `RELEASE_INCLUDE` lists 27 repositories: the 25 framework components, `documentation` and `skeleton`.
  `component-template`, `workspace` and the private `academy` are never tagged.
- `release-wave.yml` refuses to tag a component whose pinned gitlink is not an ancestor of its default
  branch (exit 3): merges into `main` are merge commits, never a squash.
- Pushing the umbrella tag `0.1.0-beta7` fires the LIVE wave (`on.push.tags`); `workflow_dispatch` with
  `dry_run` runs on a tag that already exists.
- `queue`, `openapi`, `serializer` and `testing` were registered on Packagist on 2026-10-31; the wave's
  tag is their first version.
- After the wave: Packagist shows `0.1.0-beta7` for all 27 packages.
