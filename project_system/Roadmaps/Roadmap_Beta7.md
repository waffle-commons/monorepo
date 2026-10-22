---
title: "Waffle Ecosystem Roadmap: (Beta 7)"
date_created: 2026-06-07
date_updated: 2026-10-21
type: project
status: in-progress
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP 0.1.0-beta7

> **Status:** In progress — kicked off in September 2026 (release branches 2026-09-25, tooling and scaffolds 2026-09-29; see *Kickoff state & carry-overs* below). Mid-October checkpoint met on 2026-10-17: no split (see *Capacity guard*). Full scope decided 2026-10-21: nothing is cut, tag targeted for 5 November 2026
> 
> **Target Release:** **November 2026** — tag targeted for 5 November (re-dated 2026-10-21 from October 2026; the first release after the API Platform Conference, Lille — September 17–18, 2026)
> 
> **Core Mandate:** Close every gap between "high-performance framework" and **full production-ready API ecosystem**: traffic protection, outbound resilience, background processing, Kubernetes operability, API tooling, and testability. This is the release where the missing components get built — beta8 then freezes, so anything not landed here is post-v1.
> 
> **Commitment Tiers:** Committed — AXE 1 (NET), AXE 2 (QUEUE contracts + driver), AXE 3 (OPS), AXE 5 (TEST) · High — AXE 4 (API) · Stretch — `[DXP-01]`, `[GATE-02]` (kept in scope on 2026-10-21, see below).
> 
> **Capacity guard (added 2026-09-08, amended 2026-10-06):** beta7 is the **heaviest release of the train in the shortest window** — four brand-new repositories (`queue`, `openapi`, `serializer`, `testing`, each needing repo creation, scaffolding, CI, a `RELEASE_INCLUDE` entry and a first Packagist publication) plus eleven items across five axes. Plan against the measured evidence, not the intent: umbrella-tag cadence has run beta3→beta4 in 7 days, →beta5 in 24, →beta6 in 62. Beta6 was code-complete on 2026-08-02/03 and tagged in September, but that ~5-week tail was the maintainer's time off, not verification, documentation or wave prep, so it is not a planning baseline. The 2026-09-29 kickoff leaves about four weeks of build before an end-of-October tag. **Therefore:** the stretch tier (`[DXP-01]`, `[GATE-02]`) is cut on first contact with the schedule, not renegotiated late; and unless `[API-01]`, `[API-02]` and `[TEST-01]` have code landed and green on their own gates by **mid-October** (`wfl dod` green on `openapi`, `serializer` and `testing` with tests and coverage switched on), split the release — NET + OPS + QUEUE tag as beta7 in October, API + TEST fold into the beta8 window — instead of letting beta7 slide into November. **The freeze date (beta8, November) is what is being protected here; beta7's scope is not.**
>
> *Amended 2026-10-06:* the beta6 tail was first read as release work ("roughly five weeks of verification, documentation and wave prep"); it was time off. The checkpoint first asked for the four new repositories to be "scaffolded and green on their own gates", which the empty scaffolds already met on 2026-09-29 (tests and coverage switch on with the first class), so it now checks the items' code.
>
> *Checkpoint 2026-10-17 — met, no split:* `wfl dod` PASS on `openapi` (98.71 %), `serializer` (98.94 %) and `testing` (100 %), igor 0 KO, and `wfl check:all --with-tests` 27/27. The maintainer decided not to split: API + TEST stay in beta7. The stretch tier stays cut.
>
> *Decision 2026-10-21 — full scope, tag on 5 November 2026:* the maintainer decided that beta7 cuts nothing: `[DXP-01]` and `[GATE-02]` stay in scope, which supersedes the "stretch tier is cut on first contact" rule above and the 2026-10-17 note. Reason: finishing the production surface completely in beta7 matters more than an October tag; the maintainer works on it full-time from 2026-10-21 to 2026-10-23, then verification, docs and wave prep run to the tag. Per the master roadmap corollary, the later rows moved by the same week on the same day: beta8 ~3 December, RC1 ~12 December, Gold late January 2027 (`Roadmap_v1_Master.md`).

## 🧰 KICKOFF STATE & CARRY-OVERS (2026-09-29)

### Where the release starts

- **Branches:** every repository (umbrella + 30 submodules) is on `pre-release/0.1.0-beta7`.
- **New components scaffolded** from `component-template` (namespace · package): `queue`
  (`Waffle\Commons\Queue`), `openapi` (`Waffle\Commons\OpenApi`), `serializer` (`Waffle\Commons\Serializer`),
  `testing` (`Waffle\Commons\Testing`). Each passes its Definition of Done on the empty scaffold (mago zero
  output, igor 0 KO; tests and coverage start with the first class), is in the `umbrella-ci` paths filter,
  and has its git hooks. **Maintainer actions still open:** commit the configured files and gitlinks,
  register the four packages on Packagist, set merge-commit-only + delete-branch-on-merge on the four
  repositories, add each one to `RELEASE_INCLUDE` when it ships code.
- **Toolchain baseline for the release** (the whole Dependabot backlog, applied in lockstep): mago 1.50,
  psalm 6.19, igor-php **0.9.7** (pinned by `.igor-version`, enforced in CI and in `wfl dod`), GitHub
  Actions checkout v7 / cache v6 / codecov v7 / paths-filter v4, TruffleHog pinned to a release instead
  of `main`, FrankenPHP **1.13.2** / PHP 8.5.12 (bumped from 1.12.7 / 8.5.11 on 2026-10-22: both are the
  2026-10-21 security releases for PHP2Shell, CVE-2026-109618 and CVE-2026-109619). PHPUnit 13 is a major and
  stays out of this release unless an item needs it. **`pcntl`** joined the development image, the
  skeleton `base` stage and the bench engine on 2026-09-30: the SIGTERM drain of `queue:work`
  (`[QUEUE-02]`, `[OPS-02]`) depends on it.
- **RFC homes (2026-09-30):** `[OPS-01]`/`[OPS-02]` are specified in **RFC-023** (Kubernetes Operability) and
  `[NET-02]`/`[NET-03]` in **RFC-024** (Outbound Resilience); `[OPS-03]` stays in RFC-014 and `[NET-01]` in
  RFC-017 §3.1. Each RFC lists the design questions to settle before its code lands.
- **Guard-rails added:** one canonical component CI workflow (`wfl ci:check` reports any drift), igor pin
  robust to the vendor cache, `wfl mcp:check` proving every MCP server with a real session, read-only
  `wfl sync:status`.

### Carried over — schedule these alongside the axes

- **`[CARRY-01]` Pool ping-before-dispense within a freshness window** (Retro_Beta6 §6): the benchmark traced
  Waffle's early saturation knee to the doubled DB round trip. Make the ping skippable when the
  connection was verified recently; keep the fail-safe for stale ones. Contracts-first if the pool
  contract changes.
- **`[CARRY-02]` Benchmark harness hardening** (before any new public number): run-unique result file
  names (a re-run must never overwrite a series); Engine C on symfony/runtime 7.4's native
  `FrankenPhpWorkerRunner` with `FRANKENPHP_LOOP_MAX=1000000` and no `APP_RUNTIME` override (its
  500-request default invalidated the beta6 soak comparison); Engine C in the memory test; an
  equivalent-features Symfony engine (security + CSRF + transaction subscriber) next to the bare one;
  host hardware recorded with every run; least-squares slopes published with their uncertainty.
- **`[CARRY-03]` "Keeps state on purpose" design note** (API Platform Conference feedback, 2026-09-17):
  runtime reset is already opt-in (`Container::reset()` resets only Resettable services); the strictness
  lives in the dev-mode `ComplianceScanner` and the igor gate, with `#[WorkerSafe]` as the only escape
  hatch. Decide — as an RFC-001 amendment, not code — whether a first-class "intentional state" marker
  is needed and how it differs from `#[WorkerSafe]`.
- **`[CARRY-04]` Perimeter design for `testing` and `openapi` — decided 2026-10-07:** `WaffleTestCase` must
  boot a kernel and `openapi:generate` must read route and DTO metadata without importing a sibling's
  concrete classes. The kickoff expected three new seams. A single contracts change covers it (the clock
  requirement and one property), with no recorded exception:
  - **Routes: no new seam.** `RouterInterface::getRoutes()` already returns `MatchedRoute` objects that carry
    the controller class and method, the path, the HTTP methods, the name and the argument types.
    `route:list`, `route:compile` and `security:audit` already consume it, and `security:audit` reflects on
    the controller method at build time: the pattern `openapi:generate` follows.
  - **Clock: PSR-20.** `psr/clock` joins the nine PSR packages contracts already requires. A system clock
    lives in `utils`, a frozen, advanceable clock in `testing`. New beta7 code (`[NET-01]`, `[NET-03]`,
    `[QUEUE-02]`) takes the clock by injection from its first class. The components that read the time
    directly today (auth, security, cache, telemetry, log) can move over later. Whether the limiter or the
    breaker also needs a monotonic reading is settled in RFC-024 §5.
  - **Kernel and doubles: the container on the kernel contract.** `KernelInterface` declares
    `public ContainerInterface $container { get; }`, the property `AbstractKernel` already exposes. There is
    no kernel-factory contract: `WaffleTestCase` gets the kernel from an abstract `createKernel()` that the
    app implements, and swaps its doubles in between `boot()` and `configure()`, before the container
    locks. Accepted limit: a double reaches what the container resolves (controllers and their
    dependencies), not a collaborator that an app factory builds up front. The app factories also register
    `ServerRequestFactoryInterface`, so a test builds its requests without importing `http`.
  - **`openapi:generate` lives in `openapi`**, as a `Console\CommandInterface` implementation registered in
    `bin/waffle` like the console commands. `console` needs no generator contract.
  - **DTO shape: one build-time reader in `utils`** (constructor parameters in, readable properties out,
    hooks, asymmetric visibility, nested DTOs). The serializer's normalizer compiler and the OpenAPI schema
    builder share it, so the spec matches what the serializer accepts and emits.
  - **PHPUnit:** `testing` requires `phpunit/phpunit` ^12.5, and its guard permits `PHPUnit\**` in one
    sub-namespace only, so the kernel client and the doubles stay free of PHPUnit.
  - **Rejected:** a kernel-factory contract with test overrides (a test-only parameter in a contract that
    beta8 freezes); a generator contract so that `console` can host the command; `openapi` reflecting DTOs
    on its own (the spec would drift from the serializer); a Waffle-specific clock interface (non-standard,
    so PSR-20 libraries would need an adapter).
- **`[CARRY-05]` igor 0.9.x write-through false positives:** 0.9.x flags writes *through* an injected
  service (`$this->cache->set(…)`) as "mutation on an injected dependency". Each case in this release is
  adjudicated in code (fixed or `#[WorkerSafe]` with its reason); propose the detector fix upstream in
  the igor-php fork.
- **`[CARRY-06]` Small follow-ups** (Retro_Beta6 §6): `Constant::ATTR_PARAMS` promotion, AOT compiled-memo
  runtime write-through, a PHPUnit step in the workspace CI job.
- **`[CARRY-07]` Workspace coverage policy — decided 2026-09-30:** the workspace demo app's coverage
  (54.40 %) is reported, not gated, in `scripts/dod.sh` as well — the same demo-app policy as `umbrella-ci`.
  It still has to pass mago, tests and igor; everything released (skeleton included) keeps the 95 % bar.
- **`[CARRY-08]` Skeleton OPcache preload — fixed 2026-09-30:**
  `config/preload.php` ran `opcache_compile_file()` over `vendor/waffle-commons` in directory order, which
  compiles without linking dependencies: 70 "Can't preload unlinked class" warnings at every PHP start, and
  those classes were not preloaded. The fix loads the framework classes through the Composer
  loader (`class_exists`), so parents and interfaces link first: 0 warnings, 470 → 503 preloaded classes,
  200/200 worker-mode requests served. The builder stage now runs `composer dump-autoload` before enabling
  preload (a file read during preload stays pinned for the whole process, so Composer read a stale map).
  Re-measure before quoting the beta6 benchmark again (it ran this image). Also open: the builder copies
  `composer.lock`, gitignored since beta6, so a `docker build` from a fresh clone fails at that `COPY`.
- **`[CARRY-09]` The stock skeleton production image could not serve a request — fixed 2026-09-30:**
  the skeleton Caddyfile's `frankenphp` block had no `{$FRANKENPHP_CONFIG}`, so
  the Dockerfile's `FRANKENPHP_CONFIG="worker ./public/index.php"` was ignored and requests ran in classic mode,
  where `WaffleRuntime::loop()` still called `frankenphp_handle_request()` (it only checked that the function
  exists) and FrankenPHP threw — HTTP 500 on every request, in the prod image and in the skeleton's dev compose.
  Fix: the Caddyfile interpolates `{$FRANKENPHP_CONFIG}` (as FrankenPHP's official one does), and the runtime
  detects worker mode through the `FRANKENPHP_WORKER` process variable (set only for worker scripts, readable
  at boot and in every request), handling exactly one request otherwise. Verified on the rebuilt prod image:
  stock config 200×50 in worker mode; classic mode 200×50 with the fix, 500×50 without it. Still to do: a
  production-image smoke test (build + request) in CI, and hot reload for the skeleton's dev compose (it now
  inherits worker mode, so code changes need a container restart).
  **Follow-up 2026-09-30:** FrankenPHP 1.12.2 does not export `FRANKENPHP_WORKER`, so the flag-only detection
  put every 1.12.2 worker in a restart loop, each one serving a bogus boot-time request (seen live on
  `waffle-downstream`). When the flag is absent, the runtime now lets the first `frankenphp_handle_request()`
  call settle the mode — in classic mode FrankenPHP refuses with a `RuntimeException` before touching the
  handler. Verified on real FrankenPHP 1.12.2 and 1.12.7, in worker and classic mode.
- **`[CARRY-10]` Framework defects surfaced by the EcoShield Gateway — fixed 2026-09-30:**
  - `error-handler`: `ErrorHandlerMiddleware` logged every exception at `critical` with a full stack
    trace, client errors included, so any client could grow the log at will and alerting on `critical`
    was meaningless. It now renders first and logs by the rendered status: 5xx at `critical` with the
    trace, 4xx at `notice` without it; a renderer failure still logs the original fault.
  - `http`: `GlobalsFactory` emitted `mkdir(): File exists` whenever workers booting together raced to
    create the upload root. The creation now runs under a scoped error handler (no `@`), and the
    `is_dir()` re-check still throws when the directory really cannot be created.
  - Both are covered by regression tests (the `mkdir` one fails when the fix is reverted); `wfl dod` passes
    on both components. The gateway itself moved to the beta7 toolchain the same day (mago 1.50, igor
    0.9.7 pinned in its CI) — its own repository, its own CHANGELOG.

## 🛡️ AXE 1: TRAFFIC PROTECTION & OUTBOUND RESILIENCE

_An API ecosystem that cannot defend its inbound edge or survive flaky upstreams is not production-ready. These are also hard prerequisites for EcoShield-Gateway._

### `[NET-01]` Token-Bucket Rate Limiter Middleware

- **Specification:**
    
    - Introduce `Waffle\Commons\Contracts\RateLimit\RateLimiterInterface` + `LimiterStateStorageInterface` in contracts (contracts-first).
        
    - Implement a Token Bucket limiter as a `security/` middleware, keyed by IP, authenticated subject (`UserIdentityInterface`), or API token.
        
    - Storage backends behind `LimiterStateStorageInterface` (atomic operations, in contracts), shared with `[NET-03]`: the Redis implementation lives in `data` over its connection pool (multi-worker correctness); an in-memory fallback is documented as single-worker only. *Amended 2026-10-17:* this bullet first read "through the existing cache contracts"; PSR-16 `get`/`set` cannot be atomic, so concurrent workers would over-admit and fail the NET acceptance criterion (RFC-024 §5.1, RFC-017 §3.1).
        
    - Storage unavailable (*decided 2026-10-17*): each limiter takes `on_storage_failure: open|closed`, default `open` with a warning log and a metric; `closed` is recommended on authentication endpoints. Authentication and authorization stay fail-closed regardless (RFC-017 §4).
        
    - Emit standard `RateLimit-*` response headers and a fail-closed `429` with `Retry-After`.
        
    - **Statelessness compliance:** limiter state lives exclusively in the storage backend, never in worker memory; `wfl igor` must stay 0 KO.
        

### `[NET-02]` HTTP Client Resilience Policies

- **RFC:** RFC-024 §3.1 (outbound resilience policy); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Extend `waffle-commons/http-client` with declarative per-request policies: connect/total timeout (mandatory defaults — no infinite timeouts anywhere), bounded retry with exponential backoff + jitter, and idempotency awareness (never auto-retry non-idempotent methods unless explicitly opted in).
        
    - Policies are immutable DTOs; configuration lives in config, not code.
        
    - Compose with the beta4 `[SEC-02]` SSRF guardrail (resolve → validate → pin runs on every retry attempt).
        
    - *Status 2026-10-17:* landed — contracts `TimeoutPolicy`/`RetryPolicy`, `Client::withTimeouts()`, `RetryingClient`; the concurrent path is not yet covered (RFC-024 §3.3).
        
    - *Status 2026-10-21:* the concurrent path is covered (RFC-024 §3.3). `RetryingClient` and `CircuitBreakerClient` settle batches through http-client's `SettlingClientInterface`: retries in waves, the breaker checked for every request before any is sent, promises deferred to the decorator. The workspace wires both clients from the `waffle.http_client.resilience.*` / `.breaker.*` keys (leaf names in RFC-024 §5.3), with the breaker state in Redis; live, the fan-out and proxy calls record their outcomes on their origins' circuits. Still open for `[NET-02]`/`[NET-03]`: the skeleton wiring (it has no Redis pool factory yet).
        
    - *Fault injection, 2026-10-21 (workspace stack: multi-worker FrankenPHP, shared Redis, policy 50 % / 10 calls / 60 s / 30 s cool-down / 1 trial):* `waffle-downstream` stopped under the fan-out route. The first failing request opened the circuit. While open, requests failed fast (503 in 11–23 ms, no call sent). After the cool-down, the trial with the upstream still down re-opened it; with the upstream back, the trial closed it. `/waffle-metrics` counted transitions to open 2, half_open 2, closed 1. The first run exposed a defect: since beta5 every transport failure read as `RequestException`, so it was never retried or counted. The fix is http-client 975881b, which drains the multi handle's completion messages.
        

### `[NET-03]` Circuit Breaker

- **RFC:** RFC-024 §3.2–3.3 (circuit breaker, composition with retries); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Implement a circuit breaker (closed/open/half-open) wrapping outbound calls, with failure-rate thresholds and cool-down windows.
        
    - State storage through the same `LimiterStateStorageInterface` family as `[NET-01]` — shared across workers via Redis, never in-process.
        
    - Expose breaker state transitions as events (kernel lifecycle hooks from beta4 `[ARCH-04]`) and as metrics on `/waffle-metrics` (beta5 `[OBS-02]`).
        

## 📨 AXE 2: BACKGROUND PROCESSING (NEW COMPONENT `waffle-commons/queue`)

_Beta5 `[ASYNC-01]` is finish-request deferral and explicitly **not** background processing. Production APIs need real job dispatch. Scope is deliberately minimal: contracts + one solid driver + a worker — not a Symfony Messenger clone._

### `[QUEUE-01]` Queue Contracts

- **Specification:**
    
    - `Waffle\Commons\Contracts\Queue\`: `MessageInterface`, `QueueDispatcherInterface`, `QueueConsumerInterface`, `FailedMessageStoreInterface`.
        
    - Messages are strictly-typed, serializable DTOs (no closures, no object graphs); envelope carries id, attempts, available-at, and trace context (W3C propagation from beta5 `[OBS-01]`).
        

### `[QUEUE-02]` Redis Streams Driver + Console Worker

- **Specification:**
    
    - One reference driver on Redis Streams (consumer groups give ack/retry semantics for free); additional drivers are post-v1.
        
    - `bin/waffle queue:work` console command (lives in `console/`, depends only on contracts per the established perimeter): bounded retries, dead-letter via `FailedMessageStoreInterface`, graceful SIGTERM drain (ties into `[OPS-02]`).
        
    - Worker is itself a long-running FrankenPHP-style process: must pass the Igor statelessness audit between messages.
        

### `[QUEUE-03]` Mailer Scoping Decision

- **Specification:**
    
    - Ship `Waffle\Commons\Contracts\Mailer\MailerInterface` + message DTO **contract only**; transactional mail is dispatched as a queue message.
        
    - SMTP/API transport adapters are explicitly **post-v1** (non-goal in the master roadmap); userland may bind any PSR-compatible mailer to the interface meanwhile.
        

## ☸️ AXE 3: KUBERNETES OPERABILITY

_"Production-ready on Docker/K8s" is the founding vision — these are the table stakes that don't exist yet._

### `[OPS-01]` Health & Readiness Endpoints

- **RFC:** RFC-023 §3.1–3.3 (health contract, endpoints, component probes); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Lightweight middleware exposing `/healthz` (liveness: process responsive) and `/readyz` (readiness: aggregated `HealthCheckInterface` probes — DB pool, Redis, queue driver, disk).
        
    - `Waffle\Commons\Contracts\Health\HealthCheckInterface` in contracts; components ship their own probes; fail-closed: an unregistered critical dependency means not-ready.
        
    - Constant-time, allocation-light handlers — these are hit every few seconds by orchestrators.
        

### `[OPS-02]` Graceful Shutdown & Connection Draining

- **RFC:** RFC-023 §3.4 (worker-mode signal path, shutdown sequence, CLI consumers); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Handle SIGTERM in the runtime: stop accepting work, flush deferred tasks (beta5 `[ASYNC-01]` if landed), return pooled connections (beta5 `[DBAL-01]`), close streams, then exit within the configurable grace period.
        
    - `/readyz` flips to not-ready immediately on SIGTERM so K8s stops routing before the drain (through the `preStop` drain marker, RFC-023 §5.1 — revised 2026-10-17 after Caddy's `shutdown_delay` proved to stop FrankenPHP 1.12.7 at SIGTERM). No explicit post-loop pool close (RFC-023 §3.4, decided 2026-10-17).
        
    - *Decision 2026-10-22:* the skeleton adds Caddy's `shutdown_delay` as a second path for runtimes without a `preStop` hook (Docker, Compose, ECS): `CADDY_SHUTDOWN_DELAY` (default `0s`, `5s` in `docker-compose.prod.yml` with `stop_grace_period: 35s`), during which Caddy answers `/readyz` with the public 503 while PHP serves the rest. Reason: on FrankenPHP 1.13.2, adopted that day for PHP2Shell, PHP keeps serving through the delay (200, where 1.12.7 answered 500, same harness), so the 2026-10-17 objection no longer holds. Evidence: `wfl drain-check` passes all 9 checks on 1.13.2 and fails 3 on 1.12.7 (RFC-023 §5.1).
        

### `[OPS-03]` Schema Migration Workflow Maturity

- **Specification:**
    
    - Build on the existing `data/src/Migration/MigrationRunner.php` — do not rewrite it.
        
    - Add versioned migration files, a ledger table, and console commands: `db:migrate` (it already exists — extend it), `db:rollback`, `db:status`, `make:migration` (Maker conventions from RFC-020). *Amended 2026-10-17:* the names first read `migrate`, `migrate:rollback`, `migrate:status`; `bin/waffle db:migrate` already ships, so the family keeps its `db:` prefix.
        
    - SQL dialects already supported by `data/` only; NoSQL backends are schema-less and out of scope. *Scope change 2026-10-17:* the live migrate/rollback round trip runs on PostgreSQL, SQLite, MySQL and MariaDB (the images carry `pdo_pgsql`, `pdo_sqlite` and `pdo_mysql`; MySQL and MariaDB need their own containers); SQL Server and Oracle are covered by SQL-generation tests only, because no image carries `pdo_sqlsrv` or `pdo_oci`. Their live round trip moved to `Roadmap_Post_v1.md`.
        
    - *Status 2026-10-21:* landed. `MigrationRunner::rollback()` and `status()` work through `V.down.sql` scripts and a per-dialect ledger (contracts `MigrationState`, `Enum\MigrationStatus`). `console` gains `db:status`, `db:rollback [--steps=N]` and `make:migration`, wired into the skeleton and the workspace. A script with no SQL statement is refused, never logged, so an unedited scaffold cannot be recorded as applied. Found on the way: every DDL migration failed on MySQL and MariaDB (implicit commit, then PHP 8's `commit()` threw); fixed. Evidence: the live round trip passes on PostgreSQL, MySQL 8.4 and MariaDB 11.4 (`MigrationRoundTripTest`, against the workspace `waffle-mysql`/`waffle-mariadb` services) and on SQLite (`MigrationRunnerTest`); `MigrationLedgerTest` covers the SQL Server and Oracle ledger SQL; the full CLI cycle (make → refuse unedited → migrate → status → rollback 2 steps) ran on PostgreSQL through the workspace `bin/waffle`; `wfl dod` PASS on data, console, skeleton and workspace.
        

## 📜 AXE 4: API SURFACE TOOLING

### `[API-01]` OpenAPI Generation (NEW COMPONENT `waffle-commons/openapi`)

- **Specification:**
    
    - Generate `openapi.json` from existing `#[Route]` attributes and typed controller signatures/DTOs — zero manual YAML.
        
    - Build-time console command (`openapi:generate`) sharing the beta5 `[AOT-02]` metadata-parsing phase where possible; optional dev-only route serving the spec + Swagger UI.
        
    - Optional `#[OA\*]`-style attributes for response/description overrides; absence of attributes still yields a valid (if terse) spec.
        

### `[API-02]` DTO Serializer & Content Negotiation (NEW COMPONENT `waffle-commons/serializer`)

- **Specification:**
    
    - Scoped normalizer for strictly-typed DTOs ↔ JSON (request hydration + response serialization) honoring PHP 8.5 property hooks and asymmetric visibility — **not** a general-purpose serializer.
        
    - **AOT alignment:** normalizers are compilable per-DTO classes generated at build time (same philosophy as beta5 `[AOT-01]`), reflection-free at runtime.
        
    - `Accept`-header content negotiation middleware (JSON committed; others post-v1).
        
    - `data/`'s Hydrator remains DB-only; this component owns the HTTP boundary.
        

## 🧪 AXE 5: TESTABILITY (NEW COMPONENT `waffle-commons/testing`)

### `[TEST-01]` Kernel Testing Bridge

- **Specification:**
    
    - `WaffleTestCase`: boots the kernel in-process, dispatches simulated PSR-7 requests through the real pipeline (no web server), returns typed responses for assertion.
        
    - Test doubles for time, queue (`InMemoryQueue` asserting dispatched messages), mailer contract, and HTTP client (record/replay).
        
    - Dev-only component (`require-dev` in userland); EcoShield-Gateway and Academy labs are the first consumers.
        

### `[DXP-01]` Dev Profiler Headers (stretch — in scope, 2026-10-21)

- **Specification:**
    
    - Dev-mode middleware emitting `X-Waffle-Time`, `X-Waffle-Memory`, `X-Waffle-Queries` headers; no web toolbar (API-first).
        

## 🛡️ AXE 6: ECOSHIELD-GATEWAY ALPHA (DOGFOODING — stretch, in scope 2026-10-21)

### `[GATE-02]` Gateway Lab Bootstrap

- **Specification:**
    
    - Grow the beta6 reverse-proxy POC (`Roadmap_Beta6.md` `[GATE-01]`) to **alpha** on beta7, in the gateway's own repository: legacy monolith lab + Waffle proxy app (catch-all `ProxyController` over the resilient client `[NET-02/03]`, strangler route served natively with cache + rate limiter `[NET-01]`).
        
    - Built **exclusively on public Waffle APIs** — any private-API reach-through is a framework design bug to fix, not to work around.
        
    - *Decision 2026-10-22:* the gateway's runtime bump rides with this item. Its Dockerfile still builds on FrankenPHP 1.12.2 (no digest), exposed to PHP2Shell (CVE-2026-109618, CVE-2026-109619); moving it to beta7 moves it to FrankenPHP 1.13.2 or later with a digest pin. The maintainer chose to do it then rather than as a separate change.
        

## ✅ ACCEPTANCE CRITERIA

- **NET:** limiter correct under concurrent multi-worker load (no over-admission beyond bucket size); breaker opens/half-opens per thresholds in fault-injection tests; zero infinite timeouts possible by construction.
- **QUEUE:** message survives worker crash (Redis Streams pending-list reclaim); failed messages land in the dead-letter store with full envelope; `queue:work` drains cleanly on SIGTERM.
- **OPS:** `/readyz` flips on dependency failure and on SIGTERM; rolling-restart under k6 load loses zero in-flight requests; `db:migrate` + `db:rollback` round-trip live on PostgreSQL, SQLite, MySQL and MariaDB, with SQL-generation tests for SQL Server and Oracle (*scope change 2026-10-17*, see `[OPS-03]`).
- **API:** generated `openapi.json` validates against the OpenAPI 3.1 schema; serializer round-trips every DTO shape in the test matrix (hooks, asymmetric visibility, nested DTOs, arrays).
- **All items:** `composer mago && composer tests` green, $\geq 95\%$ coverage, zero Mago baselines, `wfl igor` 0 KO; contracts-first sequencing; new submodules (`queue`, `openapi`, `serializer`, `testing`) scaffolded from `component-template`.
