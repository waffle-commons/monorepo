---
title: "Waffle Ecosystem Roadmap: (Beta 4)"
date_created: 2026-06-07
date_updated: 2026-06-07
type: project
status: 🏗️ wip
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — OFFICIAL ECOSYSTEM ROADMAP v0.1.0-beta4

> **Status:** Approved Engineering Blueprint — Sprint Backlog
> 
> **Target Release:** Late June 2026 (J-5 before the Attineos BBL Talk)
> 
> **Core Mandate:** Prioritize critical security mitigations and architectural stability to achieve Release Candidate (RC) readiness, followed by developer experience (DX) and seamless monorepo-based Academy integration.
> 
> **Delivery Tiers (3-week window):** AXE 1 = must-ship · AXE 2 = pick four (ARCH-04, ARCH-05, ARCH-06, STB-01; STB-02 is benchmark-gated) · AXE 3 = deltas only (Igor shipped in beta3) · AXE 4–5 = stretch (Academy may be promoted to must-ship as BBL demo material).

## 🔴 AXE 1: CORE SECURITY PATCHES (CRITICAL PRIORITY)

These items address structural vulnerabilities identified during the framework audit. They must be resolved, verified, and backed by comprehensive unit tests to ensure a "fail-closed" security posture before any production deployment.

### `[SEC-01]` Session Fixation & Session Tossing Mitigation

- **Session ID Rotation:**
    
    - Update the authentication middleware to enforce immediate regeneration of the session identifier stored in the `WAFFLE_SID` cookie during any privilege level modification or successful authentication event.
    
    - Implement secure cookie generation parameters, forcing `HttpOnly`, `Secure`, and `SameSite=Lax` defaults.
        
- **Cryptographic CSRF Token Binding:**
    
    - Refactor the token generation and validation mechanisms within `CsrfTokenManager`.
        
    - Fold the authenticated user's unique identifier (the `subject` extracted from `UserIdentityInterface`) directly into the HMAC hashing payload.
        
    - Ensure that any token issued for an anonymous session becomes mathematically invalid the moment that session transition to an authenticated state, preventing session tossing exploits.
        

### `[SEC-02]` Internal SSRF (Server-Side Request Forgery) Protection

- **Host Resolution Guardrail:**
    
    - Enhance the native HTTP Client (`Waffle\Commons\HttpClient\Client`) to intercept request dispatching.
        
    - Enforce a mandatory DNS resolution phase of the target host prior to initiating any cURL handles.
        
    - **Pin the validated IP into the connection** (via `CURLOPT_RESOLVE`/connect-to) so the transport layer reuses the vetted address. Validating without pinning leaves a TOCTOU window exploitable through DNS rebinding (public IP at check time, private IP at connect time).
        
- **IP Address Blacklisting:**
    
    - Assert that the resolved IP address does not fall within private, loopback, or reserved CIDR ranges (including RFC 1918, RFC 4193, loopback, link-local, and multicast ranges).
        
    - Halt and reject the request immediately if an internal or unauthorized network address is resolved, shielding internal infrastructure.
        
- **Redirect Hardening:**
    
    - Disable automatic redirect following inside the transport, or re-run the full resolve → validate → pin cycle on every redirect hop; a single unvalidated hop voids the guardrail.
        

### `[SEC-03]` Timing-Attack Resistant Cryptographic Verifications

- **Constant-Time String Comparisons (audit & close gaps):**
    
    - `hash_equals()` is already enforced across `auth/` (`JwtValidator`, `ApiKeyAuthenticator`, `BasicAuthenticator`, `AuthBridgeVerifier`) and `security/` (`CsrfTokenManager`) — this item is a verification sweep, not a refactor.
        
    - Audit the remaining surface (session identifiers, any newly introduced comparisons) and mandate the exclusive use of time-constant string comparison algorithms for verifying HMAC signatures, CSRF tokens, API tokens, and session identifiers to prevent side-channel timing analysis.
        
    - Where feasible, add a lint/guard rule banning naive `===` comparisons on known sensitive-string call sites so the invariant stays enforced going forward.
        

### `[SEC-04]` Fail-Closed CORS (Cross-Origin Resource Sharing) Policies

- **Secure Default State:**
    
    - Introduce a dedicated CORS middleware — none exists in `security/` or `http/` today, so this is a net-new build (estimate accordingly). It must default to a strict fail-closed state: if no origins are explicitly configured, all cross-origin requests are rejected.
        
    - Ban wildcard (`*`) origins on endpoints that accept credentials or session state.
        
    - Implement a strict domain whitelist matching system that validates incoming Origin headers against the framework's native configuration.
        

### `[SEC-05]` Directory Traversal Prevention (Path Traversal Guardrails)

- **File Path Sanitization:**
    
    - Introduce a robust path sanitation helper method within the `Assert` service.
        
    - Strip or reject any sequence containing directory traversal segments (such as `../` or `..\`).
        
- **Developer Guardrails:**
    
    - Refactor core components handling file transfers to strictly validate storage destinations.
        
    - Update developer documentation to explicitly prohibit passing raw values from uploaded file metadata directly into transfer commands.
        

## 🟡 AXE 2: ARCHITECTURE, REFACTORING & STABILITY (HIGH PRIORITY)

These tasks target architectural bottlenecks and resource management in memory-resident environments, stabilizing Waffle under high-concurrency loads.

### `[STB-01]` Stream Resource Leak Resolution

- **System Handle Management:**
    
    - Fix resource synchronization within Stream wrappers encapsulating native PHP system resources.
        
    - Ensure that destroying or detaching a stream object cleanly and immediately releases the underlying file or network descriptor without throwing double-free exceptions or leaving dangling handles.
        

### `[STB-02]` Buffer Pool Object Recycling

- **Garbage Collector Churn Reduction (benchmark-gated):**
    
    - Minimize RAM overhead and Garbage Collection pauses during heavy traffic loads under FrankenPHP's Worker Mode.
        
    - **Gate:** profile GC churn under representative worker-mode load first; this item only proceeds if the benchmark demonstrates material GC pressure.
        
    - **Constraint:** pooling mutable Request/Response models is shared state across requests — in direct tension with the statelessness mandate and the Igor audit — and PSR-7 immutability (`with*()` clones) erodes most of the win. If the gate passes, restrict recycling to internal byte buffers/streams, never PSR-7 message objects.
        

### `[ARCH-01]` Explicit Return Type-Hinting

- **Strict Type Safety:**
    
    - Completely eliminate implicit or loose return signatures.
        
    - Enforce strict, explicit return types on all interface contracts and concrete class implementations to guarantee predictable type safety at runtime.
        

### `[ARCH-02]` Constructor-Based Router Injection

- **Dependency Injection Standardization:**
    
    - Refactor the pipeline orchestration. All middleware or dispatching units requiring routing capabilities must receive the Router interface strictly via constructor dependency injection.
        
    - Eliminate any procedural instantiations or service locator calls within active request lifecycles.
        

### `[ARCH-03]` Explicit Visibility on Property Hooks

- **PHP 8.5 Syntax Consistency:**
    
    - Enforce a strict architectural style guide for classes utilizing PHP 8.5 Property Hooks.
        
    - Every property using a read (`get`) or write (`set`) hook must explicitly state its visibilities and portabilities, preventing static analysis ambiguities.
        

### `[ARCH-04]` Unified Kernel Lifecycle Event Hooks

- **Framework Extensibility:**
    
    - Introduce formal, typified event hooks within the core request-response lifecycle.
        
    - Dispatch clean event payloads before the request enters the PSR-15 pipeline, after the response is compiled, and upon kernel termination.
        

### `[ARCH-05]` Refactored Response Conversion Engine

- **Type-Safe Dispatching:**
    
    - Clean up the controller dispatching logic inside `ControllerDispatcher`.
        
    - Replace loose method-check heuristics with explicit interface-based checks. Use a formal contract (such as `ResponseFactoryAwareInterface`) to pass factories into controllers.
        

### `[ARCH-06]` Standalone Uploaded Files Normalizer

- **Decoupling File Arrays:**
    
    - Extract the deep recursive processing logic used to parse PHP's native `$_FILES` superglobal out of the HTTP factories.
        
    - Relocate this logic into an isolated, unit-tested class to facilitate 100% code coverage and mockability.
        

## 📊 AXE 3: MEMORY METRICS & WORKER-MODE DIAGNOSTICS (MEDIUM PRIORITY)

Running applications in a persistent memory space requires specialized tooling to identify state pollution and memory drift before shipping code.

### `[DIAG-01]` "Igor-PHP" Memory Profiler — ✅ Shipped in beta3

- **Diagnostics Automation:**
    
    - Already delivered in beta3: the root `igor.sh` plus `igor:audit` (`MemoryAuditCommand` via `ProcessAuditRunner`) implement the baseline → replay → drift-analysis protocol below. No new build work in beta4.
        
    - **Beta4 scope:** keep `wfl igor` as a non-regression gate (0 KO required) in CI and in the definition of done.
        
    - **Analysis Protocol (as shipped):**
        
        1. Capture a baseline measurement of memory allocations.
            
        2. Automate a sequence of 100 identical HTTP requests against the target sandbox.
            
        3. Analyze the final allocation state.
            
        4. If a positive memory drift is detected, utilize reflection to trace the reference tree, pinpointing exactly which singleton, static cache, or container service failed to release data.
            

### `[DIAG-02]` Static Checker for State Reset Compliance (delta over beta3 Igor)

- **Container-Boot Validation:**
    
    - Delta: `Waffle\Contracts\Service\ResettableInterface` already exists in contracts, and the `wfl igor` remediation taxonomy enforces it post-hoc; the new work here is the dev-mode boot-time gate.
        
    - Implement a preventative security scanner that executes when booting the container in development mode.
        
    - If a class configured as a shared service (singleton) holds mutable internal states (non-readonly properties) but does not implement the `Waffle\Contracts\Service\ResettableInterface` (which mandates a `reset()` method), halt execution with an explicit architectural exception.
        

### `[DIAG-03]` Orphaned Connection Tracer

- **Database & Socket Monitoring:**
    
    - Implement a runtime tracer to monitor persistent connections, including active PDO databases, Redis client sockets, and file streams.
        
    - Raise warnings if any socket resource opened during a request's lifecycle is not closed or returned to the global connection pool when the middleware stack finishes execution.
        

## 🛠️ AXE 4: DEVELOPER EXPERIENCE (DX) & CLI TOOLS (MEDIUM PRIORITY)

Our developer tools must be highly polished, explicitly separated, and integrated without causing friction.

### `[DX-01]` Structural Separation of CLI Executables

- **Internal Monorepo Tool (`bin/wfl`):**
    
    - Reserved strictly for framework contributors working inside `waffle-commons`. Both `bin/wfl` and `bin/waffle` already exist — this item polishes and formalizes the separation rather than creating it.
        
    - **`bin/wfl check:all`:** Parallelize the Mago static gates (`mago fmt` + `mago lint` + `mago analyze` + `mago guard`) across all 22 internal packages, targeting under $10\text{s}$. PHPUnit suites are excluded from this budget (full tests across 22 packages cannot meet a seconds-scale target) and run via `check:all --with-tests`, the pre-push hook, or CI.
        
    - **`bin/wfl monorepo:sync`:** Automate package dependency and version synchronization across all sub-components.
        
- **Userland Application Tool (`bin/waffle`):**
    
    - Shipped inside client environments (like `/skeleton` and `/workspace`). Used by application developers to build business logic.
        
    - **Maker Commands Optimization:** Refactor code generators (`make:voter`, `make:controller`, `make:middleware`) to output pristine PHP 8.5 syntax, automatically scaffolding asymmetric visibilities and properties utilizing validation hooks.
        

### `[DX-02]` Standardized Non-Intrusive Git Hooks

- **Local Hook Installation:**
    
    - Git hooks are strictly bound to the framework's core monorepo for engineering enforcement.
        
    - **Pre-Commit Hook:** Run Mago linting solely on modified (staged) files. Must execute in $< 150\text{ms}$ and block commits on styling or strict-type violations.
        
    - **Pre-Push Hook:** Trigger the test suite, preventing pushes if coverage drops below $95\%$.
        
    - **Userland:** Ensure `/skeleton`, `/workspace`, have custom Git hooks, and `/component-template` contain no Git hooks, leaving consuming projects entirely unburdened.
        

### `[DX-03]` Hot-Reload and Container Experience

- **FrankenPHP Hot-Reloading:**
    
    - Tune development environment server parameters to listen for file system change events.
        
    - Automatically reload modified PHP scripts directly in the memory-resident application without requiring container restarts.
        
- **Workspace Theme:**
    
    - Pre-install a streamlined terminal prompt (Starship) within the SSH development container, displaying active PHP memory usage, Opcache status, and Git branch details.
        

### `[DX-04]` Multi-byte Trimming (`mb_trim()`)

- **String Sanitization:**
    
    - Replace procedural `trim()` calls with PHP 8.4's native `mb_trim()` across utils, DTO assertions, and input normalizers to correctly process multi-byte whitespace characters.
        

### `[DX-05]` Mockable Validation Services

- **Validator abstraction:**
    
    - Provide a mockable `ValidatorInterface` wrapping our static, ultra-performant `Assert` service.
        
    - This allows developers to easily mock validation rules in userland application testing.
        

## 🏗️ AXE 5: ACADEMY WORKSPACE INTEGRATION (ONBOARDING)

The Academy must be integrated as an isolated workspace directly inside the monorepo for easy user acquisition and testing.

### `[ACAD-01]` Mono-Repository Workspace Setup

- **Container Folder (`/academy`):**
    
    - Created at the monorepo root. Must contain no root `composer.json` file.
        
- **Isolated Packages:**
    
    - **`/academy/labs`:** The TDD testbed. Uses its own `composer.json` mapping local core packages via path repository links.
        
    - **`/academy/sandbox`:** The live FrankenPHP worker-mode testbed application.
        
    - **`/academy/obsidian`:** Built-in Markdown technical guides.
        

### `[ACAD-02]` Automated Grading Engine `bin/wfl academy:test`

- **Test Orchestration CLI:**
    
    - Command to inspect `/academy/labs/src` and run the matching lab tests via PHPUnit.
        
    - Renders a highly visual, terminal-based progress card detailing lab success metrics and code cleanliness.

## 🧭 CROSS-CUTTING ENGINEERING RULES

- **Contracts-first sequencing:** any new interface introduced by this roadmap (e.g., `ResponseFactoryAwareInterface`, `ValidatorInterface`) lands in `waffle-commons/contracts` **before** the consuming component — components depend only on contracts, and `mago guard` enforces the perimeter.
    
- **Definition of done (per modified component):** `composer mago && composer tests` green, ≥95% coverage, zero Mago baselines, `wfl igor` 0 KO.
    
- **Release mechanics:** umbrella tag pushed to the remote → dispatch dry-run against the pushed tag → LIVE release wave (the dry-run checks out `ref:<tag>`, so the tag must already exist on the remote).