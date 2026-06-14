---
title: "Waffle Ecosystem Roadmap: (Beta 6)"
date_created: 2026-06-07
date_updated: 2026-06-07
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP v0.1.0-beta6

> **Status:** Pending Validation — Draft (Subject to revision after beta5 retrospective)
> 
> **Target Release:** Late November 2026
> 
> **Core Mandate:** Close every gap between "high-performance framework" and **full production-ready API ecosystem**: traffic protection, outbound resilience, background processing, Kubernetes operability, API tooling, and testability. This is the release where the missing components get built — beta7 then freezes, so anything not landed here is post-v1.
> 
> **Commitment Tiers:** Committed — AXE 1 (NET), AXE 2 (QUEUE contracts + driver), AXE 3 (OPS), AXE 5 (TEST) · High — AXE 4 (API) · Stretch — `[DXP-01]`, `[GATE-01]`.

## 🛡️ AXE 1: TRAFFIC PROTECTION & OUTBOUND RESILIENCE

_An API ecosystem that cannot defend its inbound edge or survive flaky upstreams is not production-ready. These are also hard prerequisites for EcoShield-Gateway._

### `[NET-01]` Token-Bucket Rate Limiter Middleware

- **Specification:**
    
    - Introduce `Waffle\Contracts\RateLimit\RateLimiterInterface` + `LimiterStateStorageInterface` in contracts (contracts-first).
        
    - Implement a Token Bucket limiter as a `security/` middleware, keyed by IP, authenticated subject (`UserIdentityInterface`), or API token.
        
    - Storage backends through the existing cache contracts (Redis for multi-worker correctness; in-memory fallback documented as single-worker only).
        
    - Emit standard `RateLimit-*` response headers and a fail-closed `429` with `Retry-After`.
        
    - **Statelessness compliance:** limiter state lives exclusively in the storage backend, never in worker memory; `wfl igor` must stay 0 KO.
        

### `[NET-02]` HTTP Client Resilience Policies

- **Specification:**
    
    - Extend `waffle-commons/http-client` with declarative per-request policies: connect/total timeout (mandatory defaults — no infinite timeouts anywhere), bounded retry with exponential backoff + jitter, and idempotency awareness (never auto-retry non-idempotent methods unless explicitly opted in).
        
    - Policies are immutable DTOs; configuration lives in config, not code.
        
    - Compose with the beta4 `[SEC-02]` SSRF guardrail (resolve → validate → pin runs on every retry attempt).
        

### `[NET-03]` Circuit Breaker

- **Specification:**
    
    - Implement a circuit breaker (closed/open/half-open) wrapping outbound calls, with failure-rate thresholds and cool-down windows.
        
    - State storage through the same `LimiterStateStorageInterface` family as `[NET-01]` — shared across workers via Redis, never in-process.
        
    - Expose breaker state transitions as events (kernel lifecycle hooks from beta4 `[ARCH-04]`) and as metrics on `/waffle-metrics` (beta5 `[OBS-02]`).
        

## 📨 AXE 2: BACKGROUND PROCESSING (NEW COMPONENT `waffle-commons/queue`)

_Beta5 `[ASYNC-01]` is finish-request deferral and explicitly **not** background processing. Production APIs need real job dispatch. Scope is deliberately minimal: contracts + one solid driver + a worker — not a Symfony Messenger clone._

### `[QUEUE-01]` Queue Contracts

- **Specification:**
    
    - `Waffle\Contracts\Queue\`: `MessageInterface`, `QueueDispatcherInterface`, `QueueConsumerInterface`, `FailedMessageStoreInterface`.
        
    - Messages are strictly-typed, serializable DTOs (no closures, no object graphs); envelope carries id, attempts, available-at, and trace context (W3C propagation from beta5 `[OBS-01]`).
        

### `[QUEUE-02]` Redis Streams Driver + Console Worker

- **Specification:**
    
    - One reference driver on Redis Streams (consumer groups give ack/retry semantics for free); additional drivers are post-v1.
        
    - `bin/waffle queue:work` console command (lives in `console/`, depends only on contracts per the established perimeter): bounded retries, dead-letter via `FailedMessageStoreInterface`, graceful SIGTERM drain (ties into `[OPS-02]`).
        
    - Worker is itself a long-running FrankenPHP-style process: must pass the Igor statelessness audit between messages.
        

### `[QUEUE-03]` Mailer Scoping Decision

- **Specification:**
    
    - Ship `Waffle\Contracts\Mailer\MailerInterface` + message DTO **contract only**; transactional mail is dispatched as a queue message.
        
    - SMTP/API transport adapters are explicitly **post-v1** (non-goal in the master roadmap); userland may bind any PSR-compatible mailer to the interface meanwhile.
        

## ☸️ AXE 3: KUBERNETES OPERABILITY

_"Production-ready on Docker/K8s" is the founding vision — these are the table stakes that don't exist yet._

### `[OPS-01]` Health & Readiness Endpoints

- **Specification:**
    
    - Lightweight middleware exposing `/healthz` (liveness: process responsive) and `/readyz` (readiness: aggregated `HealthCheckInterface` probes — DB pool, Redis, queue driver, disk).
        
    - `Waffle\Contracts\Health\HealthCheckInterface` in contracts; components ship their own probes; fail-closed: an unregistered critical dependency means not-ready.
        
    - Constant-time, allocation-light handlers — these are hit every few seconds by orchestrators.
        

### `[OPS-02]` Graceful Shutdown & Connection Draining

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

### `[GATE-01]` Gateway Lab Bootstrap

- **Specification:**
    
    - Execute Phase 1–2 of `Roadmap_EcoShield_Gateway.md` on beta6: legacy monolith lab + Waffle proxy app (catch-all `ProxyController` over the resilient client `[NET-02/03]`, strangler route served natively with cache + rate limiter `[NET-01]`).
        
    - Built **exclusively on public Waffle APIs** — any private-API reach-through is a framework design bug to fix, not to work around.
        

## ✅ ACCEPTANCE CRITERIA

- **NET:** limiter correct under concurrent multi-worker load (no over-admission beyond bucket size); breaker opens/half-opens per thresholds in fault-injection tests; zero infinite timeouts possible by construction.
- **QUEUE:** message survives worker crash (Redis Streams pending-list reclaim); failed messages land in the dead-letter store with full envelope; `queue:work` drains cleanly on SIGTERM.
- **OPS:** `/readyz` flips on dependency failure and on SIGTERM; rolling-restart under k6 load loses zero in-flight requests; `migrate` + `migrate:rollback` round-trip on every supported SQL dialect.
- **API:** generated `openapi.json` validates against the OpenAPI 3.1 schema; serializer round-trips every DTO shape in the test matrix (hooks, asymmetric visibility, nested DTOs, arrays).
- **All items:** `composer mago && composer tests` green, ≥95% coverage, zero Mago baselines, `wfl igor` 0 KO; contracts-first sequencing; new submodules (`queue`, `openapi`, `serializer`, `testing`) scaffolded from `component-template`.
