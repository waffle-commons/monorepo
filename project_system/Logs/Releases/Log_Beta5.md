---
title: "Log Beta 5"
date_created: '2026-07-08'
date_updated: '2026-07-08'
type: project
status: archived
tags:
  - waffle
  - beta5
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-beta5

> [!SUMMARY]
> Goal: transition Waffle-Commons from a high-performance HTTP runner into an **event-driven, reactive,
> and Ahead-of-Time-optimized** enterprise runtime — while a Gate-0 pre-release security pass blocks the
> tag ahead of every feature axe. Three new components join the ecosystem (`async`, `telemetry`,
> `telemetry-otel`); every addition stays inside the `contracts` + `utils` perimeter and the `wfl igor`
> 0-KO worker-safety gate. Target: 2026-07-08.

## 1. Technical Changelog (What changed)

### 🛡️ AXE 0 — Pre-Release Hardening (Gate-0, audit-driven)

Sourced from the 2026-06-14 full-project audit (OWASP Top 10 + Modern-PHP) across all 18 framework
components — **zero CRITICAL** findings; the MUST block gated the tag.

- **AUTHZ-01** (HIGH · A01/IDOR) Context-aware ABAC: `VoterInterface::decide()` evolved contracts-first to
  `decide(SecurityContextInterface $ctx, mixed $subject = null)`; `SecureContainer` now resolves voters
  **through the container** (constructor DI) and threads the request-scoped `SecurityContext`
  (authenticated identity, roles, client IP) into the decision — ownership / IDOR rules are now
  expressible. Deny-by-default preserved; an IDOR scenario test proves cross-owner denial.
- **STATE-02** (MEDIUM · A05 + statelessness) `sys_get_temp_dir()` removed from the upload path:
  `http`'s stream-backed `UploadedFile` keeps content in `php://temp`, never touching the shared
  system temp dir.
- **LEAK-03** (MEDIUM · A01/A05) `error-handler` masks 4xx client-error `detail` by default (falls back
  to the RFC-7807 `title`); a forced 403/404 no longer leaks controller FQCN + method to the client.
- **DEP-04** (A06) `composer audit` added to the per-component CI gate and the release-wave dry-run — 0
  advisories before the umbrella tag.
- **SHOULD/COULD landed:** `MODERN-02` (`: never` on always-throwing helpers), `ARCH-03` (kernel
  constructor injection), `HARDEN-03` (SQL identifier NUL/control allow-list), `POLICY-05` (last `@`
  suppressions removed natively), `OBS-02` (denial logging + restored server-side trace), `DX-01`,
  `FINAL-04`, `DOC-05`.

### 🏗️ AXE 1 — Ahead-of-Time (AOT) Compilation

- **AOT-01** `console`'s `ContainerCompiler` + `container:compile` emit a **graph-identical**
  `CompiledContainer` (snapshot-verified against the runtime container), bypassing reflection.
- **AOT-02** `routing` gains a `RouteTrie` for reflection-free resolution; `waffle`'s
  `CompiledContainerLoader` takes the fast path only when `WAFFLE_AOT=1` **and** a compiled artifact
  exists, falling back to reflection otherwise.

### ⚡ AXE 2 — Asynchronous Concurrency & Fibers

- **ASYNC-01** (spike → shipped) New `waffle-commons/async`: `DeferredTaskRunner` implements the new
  contract `Async\TaskRunnerInterface`; tasks deferred via `defer()` run at **finish-request** (after the
  response flushes, before the next request), each inside its own `Fiber` isolation boundary so a thrown
  task — or a throwing destructor on an abandoned suspended task — is caught and logged without aborting
  siblings. Bounded per-request budget (`DEFAULT_BUDGET = 64`) raises `DeferralBudgetExceededException`;
  the pending queue is the only state → implements `ResettableInterface` directly.
- **ASYNC-02** `http-client` promise-based fan-out (`ConcurrentClientInterface` / `PromiseInterface`) for
  parallel outbound requests over the existing non-blocking `curl_multi` core.

### 🔄 AXE 3 — Reactive State Broadcasting

- **REACTIVE-01** (spike → shipped) `#[Broadcast]` write-hook path in `waffle`: a request-scoped
  `RequestBroadcastBuffer` accumulates mutations (**no I/O in the hook**), and a `BroadcastFlushListener`
  flushes them over the `SseBroadcastTransport` at finish-request. Statelessness audited (`wfl igor`
  clean across worker iterations); confined to mutable-state DTOs (`final class` + `public private(set)`).

### 💾 AXE 4 — Memory-Resident Database Pooling

- **DBAL-01** `data` adds a `RedisConnectionPool` alongside the hardened `PDOConnectionPool` — bounded,
  **heal-on-lease** (ping/`SELECT 1` before dispense), reset-rolls-back — against the generalized
  contract pool interfaces (relational + Redis).
- **DBAL-02** `TransactionIsolationMiddleware` pins a request to a single pooled connection for
  transaction affinity, auto-wrapping writes and rolling back on any uncaught error (no lock leakage
  between worker loops).

### 📊 AXE 5 — Enterprise Telemetry & Worker Metrics

- **OBS-01** Contract-first tracing: `Telemetry\TracerInterface` (+ span/context) with a **no-op default
  in `contracts`**; new `waffle-commons/telemetry-otel` is the **sole** `open-telemetry/*` importer
  (`OtelTracer`/`OtelSpan` + `W3CTraceContextPropagator`). Spans thread through routing, the security
  voter, all 7 `data` repositories (`waffle.db.query`), `http-client` and response converters; W3C
  `traceparent` propagated on outbound calls.
- **OBS-02** New `waffle-commons/telemetry`: SDK-free `MetricsRegistry` backed by an `ApcuMetricStore`
  (metric state in APCu shared memory, **not** the resettable worker heap), stateless
  `Memory`/`Gc`/`PoolUtilization` collectors, `PrometheusExporter`, and a fail-closed `MetricsMiddleware`
  serving `/waffle-metrics` (404 unless a bearer token or allow-listed client IP matches). Wired into
  both template apps; `MeteredCache` closes the cache-hit-ratio metric.

### 🔑 AXE 6 — Passwordless Security (WebAuthn)

- **AUTH-01** (spike → shipped) `auth` ships registration + authentication ceremonies behind the new
  contract `WebAuthnVerifierInterface`; the `web-auth/webauthn-lib` import is isolated to a single
  stateless `WebAuthnLibAdapter` (app-provided challenge store, configurable UV, fail-closed). Supports
  FaceID / TouchID / hardware keys.

## 2. Quality Gate (Exit Criteria)

- [x] **Agnosticism:** `mago guard` perimeter clean — components depend only on `contracts` (+ `utils`).
  The two intentional exceptions (`telemetry-otel` → `open-telemetry/*`, `auth` → `web-auth/webauthn-lib`)
  are guard-permitted **only** in their single isolating adapter.
- [x] **Mago purity:** `fmt` + `lint` + `analyze` + `guard` exit `0` with zero baselines across all 23
  released components (`wfl check:all` → 23/23), with `cyclomatic-complexity` newly enabled repo-wide at
  threshold 50 (CPLX-04).
- [x] **Tests green:** `composer tests` green at ≥95 % coverage across touched components; both template
  apps pass (`skeleton` 23/23, `workspace` 13/13) and boot-smoke clean.
- [x] **Worker safety:** `wfl igor` → **0 KO / 0 ERROR**; `async`, `telemetry`, `telemetry-otel` all
  Igor-clean (`DeferredTaskRunner` directly `Resettable`; metric state lives in APCu, not the heap).
- [x] **`/waffle-metrics` verified LIVE** (fail-closed 404 without auth; emits memory / GC / pool / cache
  metrics), and distributed tracing propagates W3C `traceparent` end-to-end via the OTel bridge.

## 3. Release

- [x] Pre-release branch `pre-release/0.1.0-beta5` prepared; all doc/CHANGELOG stamps at
  `0.1.0-beta5 — 2026-07-08`; `RELEASE_INCLUDE` extended to **23** components (adds `async`, `telemetry`,
  `telemetry-otel`), umbrella-CI change-matrix + SEC-03 timing-scan updated to match.
- [x] `async` composer path-repo trip resolved (missing `version` / malformed `installed.json` dist
  block); `skeleton` `composer install` verified clean.
- [x] **Missing umbrella gitlinks fixed.** The three new component repos were built, committed and pushed
  (`async`@`0dc815b`, `telemetry`@`6c5e320`, `telemetry-otel`@`7bf8b4b` — all on `origin/main`, all
  matching the `composer.lock` references), and were correctly declared in `.gitmodules`, the umbrella-ci
  change-matrix, the SEC-03 scan args, and the release-wave `RELEASE_INCLUDE` — **but their gitlinks were
  never committed to the superproject** (`async` was mis-staged as plain files; `telemetry` /
  `telemetry-otel` were untracked). Every `git submodule update --init -- <name>` in CI therefore failed
  with `pathspec '<name>' did not match any file(s) known to git`; the **SEC-03 timing-safe comparison
  gate** surfaced it first (`telemetry` is hard-coded in its init list), and the per-component `check`
  matrix + the LIVE release-wave would have hit the identical error. Resolved by staging all three as
  proper submodule gitlinks (mode `160000`) at their pushed SHAs. No workflow YAML change was needed — the
  wiring was already correct and only waiting on the gitlinks.
- [ ] Commit the three gitlinks on `pre-release/0.1.0-beta5` + bump the remaining dirty gitlinks → push
  branch (umbrella-ci re-runs green) → umbrella tag **0.1.0-beta5** (no `v` prefix) pushed → dispatch
  dry-run on the pushed tag → **LIVE** release wave.

## 4. Post-Mortem & Next Steps

- **Win:** the framework grew by three components and six feature axes (AOT, async, reactive, pooling,
  telemetry, WebAuthn) **without breaching the perimeter** — every new capability is contract-first and
  worker-safe, and the SDK-heavy pieces (OTel, webauthn-lib) are quarantined to a single adapter each.
- **Gate-0 held the line:** the security-hardening pass ran *before* the feature axes, and the one HIGH
  finding — context-free voters (an ABAC / IDOR capability gap) — was closed by evolving the voter
  contract rather than papering over it in apps.
- **Decisions recorded (not silently resolved):** `ARCH-01` — the numeric `Level1…10` integrity ladder
  and the context-aware `#[Voter]` ABAC are kept side-by-side **by design** (structural check vs runtime
  access control); `CPLX-04` — complexity ratchet locked at 50, to be tightened in future betas;
  `POLICY-05` — three `event-dispatcher` ignores are irreducible PSR-14 stub friction (documented scoped
  ignores, not a baseline); `AUTH-01` — verification validated against an equivalent self-signing W3C
  ceremony fixture (real CBOR/COSE/ES256), an accepted deviation from the literal FIDO vectors.
- **Caught at release prep (two new-component onboarding gaps).** Both traced to the same root — a
  brand-new component was treated as "done" once its own repo was green, before it was fully integrated:
  (1) `async` lacked a composer `version` and had a malformed `installed.json` dist entry in the
  `skeleton` vendor, crashing `composer install` with a null-download-type `TypeError` — fixed by
  mirroring the lock entry; (2) the umbrella superproject never committed **gitlinks** for `async` /
  `telemetry` / `telemetry-otel`, so `.gitmodules` + CI referenced submodules that didn't exist in the
  tree — the SEC-03 gate failed on `git submodule update --init -- telemetry`, and the `check` matrix +
  release-wave would have followed. Fixed by staging the three gitlinks at their pushed SHAs. Lesson:
  onboarding a new component isn't complete until (a) every template app can `composer install` it clean
  **and** (b) its gitlink is committed in the umbrella — both belong on the `wfl new-component` checklist.
- **Next step:** [Roadmap Beta 6](../../Roadmaps/Roadmap_Beta6.md) — the production-surface wave (queue
  workers, OpenAPI generation, serializer, and the in-process testing bridge) on the road to RC1 and V1
  Gold.
