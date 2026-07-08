---
title: "Waffle Ecosystem Roadmap: (Beta 5)"
date_created: 2026-06-07
date_updated: 2026-06-24
type: project
status: shipped
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
> **Commitment Tiers:** **Gate-0 (blocks release) — AXE 0 Pre-Release Hardening (all MUST items).** · Committed — AXE 1 (AOT), AXE 4 (DBAL), AXE 5 (OBS) · Next — `[ASYNC-02]` + AXE 0 SHOULD items · Research spikes (prototype + go/no-go before any commitment) — `[ASYNC-01]`, `[REACTIVE-01]`, `[AUTH-01]`.

## ✅ COMPLETION STATUS — 2026-06-24 (shipped, pending review)

All six axes are implemented and **gate-green** across the framework: every modified component passes
`composer mago` (zero output, with `cyclomatic-complexity` newly enabled — see CPLX-04 below), `composer
tests` (≥95 % coverage), and `wfl igor` (0 KO). Both template apps (`skeleton`, `workspace`) boot-smoke
clean. Work is **uncommitted, pending review** — no commits, tags, or release wave have been run.

- **AXE 0 (Gate-0):** all MUST done — `AUTHZ-01` (context-aware voters via DI + request-scoped
  `SecurityContextInterface`, IDOR test), `STATE-02`, `LEAK-03`, `DEP-04` (`composer audit` in
  `umbrella-ci.yml`). SHOULD: `MODERN-02` (`: never`), `ARCH-03` (ctor injection) done. COULD:
  `DX-01`, `FINAL-04`, `HARDEN-03`, `OBS-02` (denial log in `SecurityMiddleware` + server-side trace
  in `ErrorHandlerMiddleware`), `DOC-05` done.
- **AXE 1 (AOT):** `ContainerCompiler` + `CompiledContainerLoader` + `RouteTrie`, behind `WAFFLE_AOT=1`
  with reflection fallback; graph-identical snapshot test.
- **AXE 2 (ASYNC):** new `waffle-commons/async` (`DeferredTaskRunner`, bounded budget, Fiber isolation,
  `Resettable`) + http-client concurrent `Promise`/`sendRequests` fan-out.
- **AXE 3 (REACTIVE):** `#[Broadcast]` write-hooks → request-scoped `RequestBroadcastBuffer` →
  finish-request `BroadcastFlushListener` → SSE transport; no I/O in the hook.
- **AXE 4 (DBAL):** `PDOConnectionPool`/`RedisConnectionPool` (ping-before-dispense heal-on-lease,
  bounded, reset-rolls-back) + `TransactionIsolationMiddleware` (commit/rollback/rethrow).
- **AXE 5 (OBS):** `TracerInterface` no-op default in contracts; `telemetry-otel` is the sole OTel-SDK
  importer; spans in routing / security voter / all 7 data repos / response converters; W3C `traceparent`
  propagation; `telemetry` component `/waffle-metrics` (fail-closed) — wired into both apps.
- **AXE 6 (AUTH):** WebAuthn in `auth/` — `WebAuthnLibAdapter` (sole `web-auth/webauthn-lib` importer),
  strictly-typed DTOs, stateless (app-provided challenge store), fail-closed.

**Decisions recorded during this completion pass:**

- **`ARCH-01` — kept BY DESIGN, not collapsed.** The numeric `Level1…Level10` ladder is an
  object-**integrity / structural** check (a build/boot-time scan of resolved services), **not** access
  control; the context-aware `#[Voter]` ABAC is the single runtime access-control entry point. The two
  layers serve different purposes and intentionally coexist — see
  `documentation/explanation/security-two-layer-authorization.md`. `SecureContainer` exposes one documented
  `analyze()` signature; the prior dual-signature ambiguity is resolved.
- **`CPLX-04` — calibrated complexity ratchet.** `AbstractKernel` was already reduced (356 LOC) by
  ARCH-03/MODERN-02, and `GlobalsFactory`'s `$_SERVER` parsing was already split into focused mappers
  (`ServerRequestUriMapper`/`ServerRequestHeadersMapper`/`UploadedFilesNormalizer`). Mago's per-class
  `cyclomatic-complexity` lint is now **enabled repo-wide at threshold 50** (just above the codebase's
  cohesive-design ceiling of 45 — `Uri`, `JwtValidator`, the connection pool, etc.). This locks in a
  regression guard without fragmenting cohesive crypto/PSR-7/DB classes; future betas ratchet it down.
- **`POLICY-05` — suppressions.** The named targets (cache `FileCache` ×8, http-client `Client.php` ×1)
  are eliminated. `ControllerDispatcher`'s `string-member-selector` is now eliminated too (array-callable
  dispatch; inline + config ignore removed). Three `event-dispatcher` ignores are **irreducible**: Mago
  mis-resolves PSR-14's `@return iterable<callable>` stub into a self-contradictory type — documented
  scoped ignores, the codebase's accepted idiom for inherent friction.
- **`AUTH-01` — W3C test-vector deviation (accepted, reviewed).** Verification is validated by an
  equivalent self-signing fixture exercising the full W3C ceremony (real CBOR/COSE/ES256), not the
  literal FIDO conformance vectors — documented in `auth/tests/.../WebAuthnFixtureFactory.php`.

**Release-completion remaining (left for review — no commits made):** initialize `async` as a registered
component (it has a local repo + `CHANGELOG`, but no `.gitmodules` entry / Packagist / release-manifest
inclusion yet — it also lacks a `version`, which trips a composer path-repo update); then gitlinks →
umbrella tag → dry-run → LIVE wave per the release-wave mechanics.

## 🛡️ AXE 0: PRE-RELEASE HARDENING (Audit-Driven — Gate-0)

_Source: full-project audit on **2026-06-14** (OWASP Top 10 + Modern-PHP review) across all 18 framework
components. **Headline:** **zero CRITICAL** findings — the injection / crypto / auth / SSRF surface is
genuinely robust: the SQR compiler emits `?`-placeholders with a separate parameter array and quote-
escapes identifiers per dialect (OWASP A03); `JwtValidator` rejects `alg:none`, allow-lists algorithms
and blocks HS/RS key-confusion; `CsrfTokenManager` is a stateless signed double-submit (`hash_equals`,
`random_bytes`); `SsrfGuard` is default-on with resolve→validate-all-IPs→`CURLOPT_RESOLVE`-pin and no
redirect-follow; no `unserialize`, no superglobals outside `GlobalsFactory`, no weak crypto primitives.
The findings below are the **one HIGH + the MEDIUM/LOW hardening backlog**; the MUST block gates the
beta5 tag ahead of every feature axe. DoD for each item is the standard gate: `composer mago` zero
output, `composer tests` ≥95 %, `wfl igor` 0 KO._

### 🔴 MUST HAVE — Security & Stability (blocks the beta5 release)

- **`[AUTHZ-01]` Context-aware authorization — close the ABAC capability gap** *(HIGH · OWASP A01 / IDOR)*
  - **Finding:** authorization is correctly **fail-closed** (`SecureContainer::analyze()` denies any action
    with no `#[Voter]` and no `#[PublicAccess]`), but voters are **context-free**:
    `VoterInterface::decide(): bool` takes no arguments and `SecureContainer::vote()` does `new $voterName()`
    with no DI (`security/src/Container/SecureContainer.php:175-204`, `contracts/.../Security/VoterInterface.php`).
    A voter therefore **cannot see the authenticated identity, the request, or the target resource**, so
    ownership / IDOR rules (“user A may not read user B’s record”) are **impossible to express** in the
    framework’s ABAC — apps must hand-roll them and must not over-trust the gate.
  - **Action:** contracts-first — evolve the contract to
    `decide(SecurityContextInterface $ctx, mixed $subject = null): bool`; resolve voters **through the container**
    (constructor DI) instead of `new $voterName()`; thread the authenticated `UserIdentity` + PSR-7 request +
    resolved resource into the decision. Keep deny-by-default.
  - **Gate:** an IDOR scenario test (subject-bound voter denies cross-owner access) passes; fail-closed
    snapshot unchanged; `wfl igor` 0 KO (no static SecurityContext).

- **`[STATE-02]` Remove `sys_get_temp_dir()` from the upload path** *(MEDIUM · A05 + statelessness mandate)*
  - **Finding:** `http/src/Factory/UploadedFileFactory.php:35` calls `tempnam(sys_get_temp_dir(), …)` — a
    forbidden ambient global (AGENTS §2/§59), writes to a shared world-readable dir, **never cleans the temp
    file up** (worker-mode file leak), and throws a generic `\RuntimeException`.
  - **Action:** stream to `php://temp` or a configured, request-scoped upload dir injected from config;
    guarantee cleanup on teardown; raise a domain exception.
  - **Gate:** `rg 'sys_get_temp_dir' <framework>/src` is empty; upload round-trip test green; `wfl igor` 0 KO.

- **`[LEAK-03]` Stop leaking internals on 4xx errors** *(MEDIUM · A01 / A05 info disclosure)*
  - **Finding:** `error-handler/src/Renderer/JsonErrorRenderer.php:55` masks `detail` only for `status >= 500`.
    A `SecurityException` carries code **403**, so its message is surfaced verbatim in production — leaking the
    **controller FQCN + method** (“`App\Foo::bar declares no #[Voter] …`”) to the client.
  - **Action:** mask every exception message by default (fall back to the RFC-7807 `title`); surface `detail`
    **only** for an explicit allow-list of client-safe types (validation field messages, route-not-found,
    method-not-allowed) regardless of status.
  - **Gate:** debug-off snapshot test proves a forced 403/400 exposes no class/method/path internals.

- **`[DEP-04]` Dependency-advisory release gate** *(LOW-effort · A06)*
  - **Finding:** no `composer audit` runs in the release path; the contracts-only perimeter keeps the surface
    tiny, but a Packagist tag should still be advisory-clean.
  - **Action:** add `composer audit` to the per-component CI gate and the release-wave dry-run.
  - **Gate:** 0 advisories across all components before the umbrella tag.

### 🟠 SHOULD HAVE — Modernization (keep the framework competitive)

- **`[ARCH-01]` Consolidate the fragmented security model** *(A04 — insecure design / maintainability)*
  - **Finding:** **three** authorization paradigms coexist: `#[Voter]` attributes (`SecureContainer`), the
    numeric `Level1Rule … Level10Rule` + `AbstractSecurity::$level`/`isSecure()` ladder, and
    `SecurityInterface::analyze(object, expectations)` (instanceof). `SecureContainer` even exposes **two**
    `analyze()` signatures (`(string,string)` vs `$security->analyze($instance)`).
  - **Action:** make the (context-aware) voter path the single authorization entry point; retire or clearly
    re-scope the level/expectations paths; one documented `analyze()` signature.

- **`[MODERN-02]` Type always-throwing helpers `never`, not `void`** *(PHP 8.1+ feature unused — high leverage)*
  - **Finding:** `waffle/src/Abstract/AbstractKernel.php:430` `logAndThrow(): void` always throws; the analyzer
    can’t prove it, which is *why* the kernel needs scattered post-guard null handling on `$this->container`.
  - **Action:** mark such helpers `: never`; sweep siblings. The analyzer then proves non-null after guards,
    deleting narrowing workarounds for free.

- **`[ARCH-03]` Replace kernel setter-injection + nullable state with constructor injection** *(temporal coupling)*
  - **Finding:** `AbstractKernel` holds required collaborators as `?T = null` populated via `set*()` (lines
    69-82) and relies on `validateState()` + scattered null checks — a half-constructed object is reachable.
  - **Action:** inject required collaborators immutably (or via a dedicated `KernelBuilder`), keeping the
    boot-time `#[WorkerSafe]` exceptions minimal.

- **`[CPLX-04]` Reduce the cyclomatic-complexity hotspots** *(refactor)*
  - **Finding:** `AbstractKernel` (441 LOC / 47 branch-lines), `Router` (269/37), `Stream` (386/37),
    `ControllerArgumentResolver` (242/33), `Uri` (414/31), `GlobalsFactory` (294/24).
  - **Action:** extract kernel boot/wiring into a `Bootstrapper`; split `GlobalsFactory`’s `$_SERVER` parsing
    into focused mappers; consider a mago lint complexity threshold.

- **`[POLICY-05]` Eliminate the last suppressions (zero-baseline integrity)** *(self-policy: AGENTS §38/§61)*
  - **Finding:** 8× `@`-error-suppression confined to `cache/src/Adapter/FileCache.php` (`@mkdir/@unlink/@rename/
    @file_get_contents/@file_put_contents/@chmod`), and 1× `@mago-ignore analysis:mixed-assignment` at
    `http-client/src/Client.php:148`. Functionally guarded, but both violate the “never silence / zero baseline”
    mandate.
  - **Action:** replace `@` with explicit return-value/exception handling; resolve the mixed-assignment with a
    typed local. `rg '@(mkdir|unlink|rename|file_get_contents|file_put_contents|chmod)' src` → 0.

### 🟡 COULD HAVE — Comfort (minor optimizations & documentation)

- **`[DX-01]` Unpredictable temp names** — swap `uniqid()` for `bin2hex(random_bytes(…))` in
  `data/src/Storage/JsonFileStore.php:120` and `console/src/Maker/AbstractMakerCommand.php:171`, matching the
  pattern `FileCache` already uses.
- **`[OBS-02]` Security & forensic logging** — emit a log event on authorization denials, and restore the
  server-side stack trace currently commented out at `error-handler/.../ErrorHandlerMiddleware.php:47` (logged,
  never sent to the client). Pairs naturally with **AXE 5 (OBS)**.
- **`[HARDEN-03]` Defense-in-depth** — collapse consecutive `LIKE` wildcards in
  `data/src/Evaluation/InMemoryEvaluator.php:113` to bound worst-case regex cost (already `preg_quote`-safe), and
  add an identifier allow-list alongside the dialect quote-escaping in `SQLCompiler`.
- **`[FINAL-04]` Seal the PSR surface** — mark the PSR-7/17 concretes (`Uri`, `Stream`, `Response`, `Request`,
  `ServerRequest`, the factories) and `container/src/Autowire.php` `final` unless an extension point is
  intentional.
- **`[DOC-05]` Document the authorization limits** — until `[AUTHZ-01]` lands, state explicitly that voters are
  policy-**presence** gates and that ownership/IDOR checks must live in handlers, so integrators don’t over-trust
  the gate.

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