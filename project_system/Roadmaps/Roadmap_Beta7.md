---
title: "Waffle Ecosystem Roadmap: (Beta 7)"
date_created: 2026-06-07
date_updated: 2026-10-07
type: project
status: in-progress
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP 0.1.0-beta7

> **Status:** In progress — kicked off in September 2026 (release branches 2026-09-25, tooling and scaffolds 2026-09-29; see *Kickoff state & carry-overs* below)
> 
> **Target Release:** **October 2026** (the first release after the API Platform Conference, Lille — September 17–18, 2026)
> 
> **Core Mandate:** Close every gap between "high-performance framework" and **full production-ready API ecosystem**: traffic protection, outbound resilience, background processing, Kubernetes operability, API tooling, and testability. This is the release where the missing components get built — beta8 then freezes, so anything not landed here is post-v1.
> 
> **Commitment Tiers:** Committed — AXE 1 (NET), AXE 2 (QUEUE contracts + driver), AXE 3 (OPS), AXE 5 (TEST) · High — AXE 4 (API) · Stretch — `[DXP-01]`, `[GATE-02]`.
> 
> **Capacity guard (added 2026-09-08, amended 2026-10-06):** beta7 is the **heaviest release of the train in the shortest window** — four brand-new repositories (`queue`, `openapi`, `serializer`, `testing`, each needing repo creation, scaffolding, CI, a `RELEASE_INCLUDE` entry and a first Packagist publication) plus eleven items across five axes. Plan against the measured evidence, not the intent: umbrella-tag cadence has run beta3→beta4 in 7 days, →beta5 in 24, →beta6 in 62. Beta6 was code-complete on 2026-08-02/03 and tagged in September, but that ~5-week tail was the maintainer's time off, not verification, documentation or wave prep, so it is not a planning baseline. The 2026-09-29 kickoff leaves about four weeks of build before an end-of-October tag. **Therefore:** the stretch tier (`[DXP-01]`, `[GATE-02]`) is cut on first contact with the schedule, not renegotiated late; and unless `[API-01]`, `[API-02]` and `[TEST-01]` have code landed and green on their own gates by **mid-October** (`wfl dod` green on `openapi`, `serializer` and `testing` with tests and coverage switched on), split the release — NET + OPS + QUEUE tag as beta7 in October, API + TEST fold into the beta8 window — instead of letting beta7 slide into November. **The freeze date (beta8, November) is what is being protected here; beta7's scope is not.**
>
> *Amended 2026-10-06:* the beta6 tail was first read as release work ("roughly five weeks of verification, documentation and wave prep"); it was time off. The checkpoint first asked for the four new repositories to be "scaffolded and green on their own gates", which the empty scaffolds already met on 2026-09-29 (tests and coverage switch on with the first class), so it now checks the items' code.

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
  of `main`, FrankenPHP **1.12.7** / PHP 8.5.11 (1.12.5 was a security release). PHPUnit 13 is a major and
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
        
    - Storage backends through the existing cache contracts (Redis for multi-worker correctness; in-memory fallback documented as single-worker only).
        
    - Emit standard `RateLimit-*` response headers and a fail-closed `429` with `Retry-After`.
        
    - **Statelessness compliance:** limiter state lives exclusively in the storage backend, never in worker memory; `wfl igor` must stay 0 KO.
        

### `[NET-02]` HTTP Client Resilience Policies

- **RFC:** RFC-024 §3.1 (outbound resilience policy).

- **Specification:**
    
    - Extend `waffle-commons/http-client` with declarative per-request policies: connect/total timeout (mandatory defaults — no infinite timeouts anywhere), bounded retry with exponential backoff + jitter, and idempotency awareness (never auto-retry non-idempotent methods unless explicitly opted in).
        
    - Policies are immutable DTOs; configuration lives in config, not code.
        
    - Compose with the beta4 `[SEC-02]` SSRF guardrail (resolve → validate → pin runs on every retry attempt).
        

### `[NET-03]` Circuit Breaker

- **RFC:** RFC-024 §3.2–3.3 (circuit breaker, composition with retries).

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

- **RFC:** RFC-023 §3.1–3.3 (health contract, endpoints, component probes).

- **Specification:**
    
    - Lightweight middleware exposing `/healthz` (liveness: process responsive) and `/readyz` (readiness: aggregated `HealthCheckInterface` probes — DB pool, Redis, queue driver, disk).
        
    - `Waffle\Commons\Contracts\Health\HealthCheckInterface` in contracts; components ship their own probes; fail-closed: an unregistered critical dependency means not-ready.
        
    - Constant-time, allocation-light handlers — these are hit every few seconds by orchestrators.
        

### `[OPS-02]` Graceful Shutdown & Connection Draining

- **RFC:** RFC-023 §3.4 (worker-mode signal path, shutdown sequence, CLI consumers).

- **Specification:**
    
    - Handle SIGTERM in the runtime: stop accepting work, flush deferred tasks (beta5 `[ASYNC-01]` if landed), return pooled connections (beta5 `[DBAL-01]`), close streams, then exit within the configurable grace period.
        
    - `/readyz` flips to not-ready immediately on SIGTERM so K8s stops routing before the drain.
        

### `[OPS-03]` Schema Migration Workflow Maturity

- **Specification:**
    
    - Build on the existing `data/src/Migration/MigrationRunner.php` — do not rewrite it.
        
    - Add versioned migration files, a ledger table, and console commands: `migrate`, `migrate:rollback`, `migrate:status`, `make:migration` (Maker conventions from RFC-020).
        
    - SQL dialects already supported by `data/` only; NoSQL backends are schema-less and out of scope.
        

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
        

### `[DXP-01]` Dev Profiler Headers (stretch)

- **Specification:**
    
    - Dev-mode middleware emitting `X-Waffle-Time`, `X-Waffle-Memory`, `X-Waffle-Queries` headers; no web toolbar (API-first).
        

## 🛡️ AXE 6: ECOSHIELD-GATEWAY ALPHA (DOGFOODING — stretch)

### `[GATE-02]` Gateway Lab Bootstrap

- **Specification:**
    
    - Grow the beta6 reverse-proxy POC (`Roadmap_Beta6.md` `[GATE-01]`) to **alpha** on beta7, in the gateway's own repository: legacy monolith lab + Waffle proxy app (catch-all `ProxyController` over the resilient client `[NET-02/03]`, strangler route served natively with cache + rate limiter `[NET-01]`).
        
    - Built **exclusively on public Waffle APIs** — any private-API reach-through is a framework design bug to fix, not to work around.
        

## ✅ ACCEPTANCE CRITERIA

- **NET:** limiter correct under concurrent multi-worker load (no over-admission beyond bucket size); breaker opens/half-opens per thresholds in fault-injection tests; zero infinite timeouts possible by construction.
- **QUEUE:** message survives worker crash (Redis Streams pending-list reclaim); failed messages land in the dead-letter store with full envelope; `queue:work` drains cleanly on SIGTERM.
- **OPS:** `/readyz` flips on dependency failure and on SIGTERM; rolling-restart under k6 load loses zero in-flight requests; `migrate` + `migrate:rollback` round-trip on every supported SQL dialect.
- **API:** generated `openapi.json` validates against the OpenAPI 3.1 schema; serializer round-trips every DTO shape in the test matrix (hooks, asymmetric visibility, nested DTOs, arrays).
- **All items:** `composer mago && composer tests` green, $\geq 95\%$ coverage, zero Mago baselines, `wfl igor` 0 KO; contracts-first sequencing; new submodules (`queue`, `openapi`, `serializer`, `testing`) scaffolded from `component-template`.
