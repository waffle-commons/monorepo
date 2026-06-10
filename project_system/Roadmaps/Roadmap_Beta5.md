---
title: "Waffle Ecosystem Roadmap: (Beta 5)"
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
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP v0.1.0-beta5

> **Status:** Pending Validation — Active Draft (Subject to revision during v0.1.0-beta4 development)
> 
> **Target Release:** Summer 2026 (Post-BBL Core Expansion)
> 
> **Core Vision:** Transition Waffle-Commons from a high-performance HTTP runner to an event-driven, reactive, and Ahead-of-Time (AOT) optimized enterprise-grade application runtime.
> 
> **Commitment Tiers:** Committed — AXE 1 (AOT), AXE 4 (DBAL), AXE 5 (OBS) · Next — `[ASYNC-02]` · Research spikes (prototype + go/no-go before any commitment) — `[ASYNC-01]`, `[REACTIVE-01]`, `[AUTH-01]`.

## 🏗️ AXE 1: AHEAD-OF-TIME (AOT) METADATA COMPILATION

_To achieve sub-millisecond cold starts and optimize memory consumption in high-density container environments, Waffle will transition from dynamic runtime reflection to static compilation phases during CI/CD._

### `[AOT-01]` Compiled Dependency Injection Container

- **Specification:**
    
    - Design a build-time compiler command within the monorepo tooling.
    
    - Traverse the application codebase to map the complete object dependency graph, resolving typed constructor arguments and visibilities.
        
    - Generate a native, optimized PHP class (`CompiledContainer`) that instantiates all non-synthetic services directly via strict constructor parameters, completely bypassing PHP's runtime reflection and union/intersection type safety overhead.
        

### `[AOT-02]` Static Router Preheat

- **Specification:**
    
    - Parse Attribute-based router metadata (`#[Route]`) during the build phase.
        
    - Compile definitions into an optimized, multi-dimensional lookup array representation (Trie-based lookup tree).
        
    - Configure the core router to load this pre-compiled lookup tree instantly upon worker boot, removing directory scanning and runtime class-parsing from the execution path.
        

## ⚡ AXE 2: ASYNCHRONOUS CONCURRENCY & FIBERS

_Escaping synchronous blocking operations by introducing event-driven concurrency natively suited for memory-resident environments like FrankenPHP._

### `[ASYNC-01]` Fiber-Based Deferred Task Runner (Research Spike)

- **Specification:**
    
    - Develop a lightweight task runner component (`waffle-commons/async`, namespace `Waffle\Commons\Async`).
        
    - Implement a cooperative dispatcher exploiting native PHP Fibers. **Reality check:** Fibers provide cooperative concurrency within a single thread — they are not background threads. Deferred work therefore executes with *finish-request semantics*: after the response is flushed to FrankenPHP, but **before the worker accepts its next request**.
        
    - Enable developers to defer short post-response tasks (e.g., mail delivery, API log writing, third-party webhook payloads) out of the user-perceived latency path.
        
    - Enforce a bounded per-request deferral budget; when deferred workloads exceed it, surface an explicit recommendation to move the workload to a real queue/broker. This mechanism trades worker throughput for perceived latency — it is not a substitute for background processing.
        
    - **Spike deliverable:** prototype plus a load-test report quantifying worker-throughput impact; go/no-go decision before this graduates into a committed item.
        

### `[ASYNC-02]` Concurrent HTTP Client Pool with Promise Interface

- **Specification:**
    
    - Expand `waffle-commons/http-client` to support concurrent execution.
        
    - Introduce a non-blocking Promise abstraction: a `PromiseInterface` lands in `waffle-commons/contracts` first (contracts-first sequencing), with the concrete `Waffle\Commons\HttpClient\Promise\Promise` wrapping multi-cURL handles or Fiber scheduler loops.
        
    - Allow the client to resolve array collections of outgoing requests in parallel, returning consolidated typed responses.
        

## 🔄 AXE 3: REACTIVE STATE BROADCASTING VIA PROPERTY HOOKS

_Connecting state mutations directly to real-time communication protocols by exploiting modern PHP 8.5 syntax capabilities._

### `[REACTIVE-01]` Reactive Write-Hook Observers (Research Spike)

- **Specification:**
    
    - Create a declarative `#[Broadcast(channel: string)]` Attribute targeting DTO and Entity class properties.
        
    - Intercept property state modifications natively using PHP 8.5 write hooks (`set`). **Hooks must perform no I/O:** a write hook only enqueues a mutation record into a request-scoped broadcast buffer.
        
    - A dedicated middleware flushes the buffer through the Waffle Event Dispatcher and pushes serialized mutations via Server-Sent Events (SSE) or Mercure hub integrations after the response cycle — keeping side effects observable, testable, and out of property assignment.
        
    - **Constraint:** hooked properties cannot be `readonly` in PHP 8.5; this pattern applies only to mutable-state DTOs (`final class` + `public private(set)`), never to the existing `final readonly` DTOs.
        
    - **Spike deliverable:** prototype plus a statelessness audit (`wfl igor` clean across worker iterations); go/no-go before commitment.
        

## 💾 AXE 4: MEMORY-RESIDENT DATABASE POOLING

_Mitigating database deadlocks and avoiding broken socket connections by building pooling capabilities specifically designed for long-running PHP processes._

### `[DBAL-01]` Adaptive PDO/Redis Connection Pooler

- **Specification:**
    
    - Build on the existing `Waffle\Contracts\Data\Connection\ConnectionPoolInterface` shipped with RFC-022 — implement against that contract rather than introducing a new abstraction.
        
    - Implement an in-memory manager inside the Waffle Kernel to pool active connection handles (PDO, Redis).
        
    - Instruct the Request Handler to borrow a connection from the pool at request startup and safely return it to the idle pool upon request termination.
        
    - **Heal-on-Lease Mechanism:** Build automated health checks (such as `SELECT 1` or ping protocols) that silently restore severed connections prior to leasing them to the request lifecycle, completely mitigating connection timeouts.
        

### `[DBAL-02]` Failsafe Transaction Isolation Middleware

- **Specification:**
    
    - Implement a kernel-level database transaction middleware.
        
    - Intercept incoming write actions and auto-wrap requests in standard database transactions.
        
    - Enforce a mandatory fallback rule: if any uncaught error, runtime exception, or worker failure occurs, immediately trigger a rollback of all active uncommitted transactions to avoid data corruption or lock leakages between sequential worker loops.
        

## 📊 AXE 5: ENTERPRISE TELEMETRY & WORKER METRICS

_Providing production-ready monitoring and full visibility over memory and processing times._

### `[OBS-01]` Integrated OpenTelemetry (OTel) Distributed Tracing

- **Specification:**
    
    - **Perimeter rule:** core components must not depend on the OTel SDK (contracts-only dependency perimeter; `mago guard` would reject it). Introduce `Waffle\Contracts\Telemetry\TracerInterface` (plus span/context abstractions) in `waffle-commons/contracts`, with a no-op default implementation.
        
    - Ship the OpenTelemetry SDK bridge as its own component (`waffle-commons/telemetry-otel`) implementing the contract.
        
    - Emit spans through the contract inside core framework hooks: routing resolution, ABAC security voter evaluation, database query execution, and response converters.
        
    - Propagate standard W3C Trace Context headers on outgoing HTTP calls to ensure transparent distributed tracing in microservice architectures.
        

### `[OBS-02]` Prometheus Worker Metrics Endpoint `/waffle-metrics`

- **Specification:**
    
    - Introduce a secure, lightweight diagnostics middleware.
        
    - Expose active worker metrics formatted for ingestion by Prometheus or Datadog collectors.
        
    - Track and export: memory footprint peaks, garbage collection cycle frequencies, average request processing times, database pool utilization rates, and cache hit ratios.
        

## 🔑 AXE 6: PASSWORDLESS SECURITY (WEBAUTHN)

_Providing native cryptographic authentication to align Waffle-Commons with modern security and zero-trust standards._

### `[AUTH-01]` Native Passkey & WebAuthn Verification Service (Research Spike)

- **Specification:**
    
    - Create a stateless WebAuthn authenticator component within `waffle-commons/auth`.
        
    - Model strictly-typed DTOs representing public key credential options (WebAuthn registration and assertion).
        
    - **Do not hand-roll the cryptographic stack** (CBOR decoding, COSE key parsing, attestation formats): define `Waffle\Contracts\Auth\WebAuthn\*` interfaces in contracts and ship the default adapter wrapping the audited `web-auth/webauthn-lib`. Supports Apple FaceID, Google TouchID, and physical hardware security keys (YubiKeys).
        
    - If a zero-dependency profile is a hard requirement, scope it down to **assertion-only** (login ceremonies) with `none`/`packed` attestation, and document every unsupported attestation format explicitly.
        
    - **Spike deliverable:** prototype validated against the W3C WebAuthn test vectors, plus a dedicated security-audit gate, before commitment.

## ✅ ACCEPTANCE CRITERIA & ENGINEERING RULES

_Beta5 graduates from draft to approved only once each axe carries measurable gates. Initial proposals:_

- **AOT:** container/router boot measured against the runtime-reflection baseline (capture the baseline first, then set the improvement target); the compiled container must produce a service graph identical to the runtime container (snapshot test).
    
- **ASYNC:** `[ASYNC-02]` — N parallel requests complete in roughly the wall-clock of the slowest single request (bounded overhead); `[ASYNC-01]` — spike report quantifies the worker-throughput regression before go/no-go.
    
- **DBAL:** zero connection errors across a 24h soak test including forced database restarts (heal-on-lease verified); zero transaction leakage across worker iterations (Igor-style audit).
    
- **OBS:** W3C trace context propagated end-to-end across two services; `/waffle-metrics` scrape overhead below 5ms.
    
- **AUTH:** verification passes the W3C WebAuthn test vectors; dedicated security-audit gate.
    
- **All items:** `composer mago && composer tests` green, ≥95% coverage, zero Mago baselines; **contracts-first sequencing** (new interfaces land in `waffle-commons/contracts` before any consuming component — the guard perimeter is non-negotiable); releases follow the wave mechanics (umbrella tag pushed → dry-run on the pushed tag → LIVE wave).