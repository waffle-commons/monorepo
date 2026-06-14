---
title: "Waffle Ecosystem Roadmap: (Beta 3)"
date_created: 2026-05-28
date_updated: 2026-05-28
type: project
status: 🏗️ wip
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🗺️ Waffle Ecosystem Roadmap: Enterprise Auth & Stateless Data (Beta 3)

**Target Release:** `v0.1.0-beta3`

**Status:** `Approved by Architect`

**Theme:** Identity Federation, Stateless Persistence & CI/CD Industrialization

**Author:** Lead Software & DevSecOps Architect

**Reference RFCs:** RFC-021 (Universal Auth Bridge), RFC-022 (Universal Data & Persistence)

## 1. Executive Summary

Waffle Core `v0.1.0-beta2` successfully stabilized the core HTTP routing pipeline, optimized the dependency injection container, and eliminated technical debt across the codebase by enforcing a strict _Zero-Baseline Mago_ static analysis policy. Furthermore, all core refactoring of **Phase 4 (Skeleton Correction & Decoupling)** was completed ahead of schedule, validating our in-container DI-wiring and native PHP 8.5 Property Hook validations.

The core objective of the **Beta 3** wave is to transition Waffle from an ultra-fast HTTP execution pipeline into a **fully featured, enterprise-grade application ecosystem**. To achieve this, we are introducing two major, decoupled components designed from the ground up to respect FrankenPHP's resident memory worker execution constraints:

1. **`waffle-commons/auth`**: Implementation of the Universal Authentication Bridge (UAB), stateless Identity Federation (OIDC/OAuth2), and cryptographically signed user assertion propagation for legacy monoliths (the engine behind the _EcoShield_ gateway).
    
2. **`waffle-commons/data`**: Implementation of a unified, stateless database abstraction layer governed by a declarative Semantic Query Representation (SQR) and a resident connection pool engineered to prevent memory leaks.
    

This roadmap outlines the precise engineering phases required to build these components, establish deep cross-component synergies, and lock down our production-ready quality gates.

## 2. Milestone Overview & Historical Alignment

```
┌────────────────────────────────────────────────────────────────────────┐
│                        WAFFLE ROADMAP: BETA 3                          │
└────────────────────────────────────────────────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    ▼                               ▼                               ▼
[PHASE 0: CONTRACTS]      [PHASE 1: AUTH COMP]            [PHASE 2: DATA COMP]
Agnostic interfaces       UAB, stateless OIDC             UDPL, SQR AST, SQL/NoSQL
 & data structures.       & HMAC signatures.              Pools & Hook hydration.
                                    │                               │
                                    └───────────────┬───────────────┘
                                                    │
                                                    ▼
                                          [PHASE 3: SYNERGIES]
                                        Database-connected ABAC,
                                         Session-bound CSRF.
```

### ✅ Completed Milestones (Beta 2 Retrospective)

- **[x] Phase 1: Robust REST Routing & Hardening (P0)** — Dual-pass matching, route overloading, and standard HTTP 405 matching with the `Allow` header.
    
- **[x] Phase 2: Workspace Cognitive Architecture & AI Manifesto (P1)** — Condensation of `CLAUDE.md`, creation of `AGENTS.md`, and integration of `.opencode/skills/` routing directives.
    
- **[x] Phase 3: Self-Healing & Idempotent Release Wave (P1)** — Refactored `release-wave.yml` with Git submodule remote rewriting, PAT masking, parallel matrix CI execution, and idempotency guards.
    
- **[x] Phase 4: Skeleton Correction & Decoupling (P2)** — AppKernelFactory PSR-11 decoupling, removal of manual `new` statements, catch-all routing fallback, and HelloController DTO Property Hook validation.
    
- **[x] Phase 5: Local DX Tooling & Git Hooks (P2.5)** — Operational `wfl link`, `wfl unlink`, `wfl debug`, and `wfl bench` commands, alongside staged-file `mago guard` hooks and ultra-fast (< 1s) local incremental pre-commit validations.
    

## 3. Phase-by-Phase Execution Plan

### 🧱 Phase 0: Abstraction & Contracts Scaffolding (P0)

_Before writing any concrete implementation code for our two new packages, we must freeze the architectural boundaries within our central interfaces repository to strictly satisfy our component agnosticism invariant._

- **[ ] Security Contracts Upgrades (`waffle-commons/contracts`):**
    
    - Declare `AuthenticationBridgeInterface` governing the serialization, signing, and verification of client identities.
        
    - Declare `UserAssertionInterface` wrapping the standard payload structures.
        
    - Declare the `#[PublicAccess]` bypass security attribute.
        
- **[ ] Data Contracts Upgrades (`waffle-commons/contracts`):**
    
    - Declare `ConnectionPoolInterface` managing active resource allocation and request-bound reset lifecycles.
        
    - Declare `QueryCompilerInterface` translating semantic queries into native database syntaxes.
        
    - Declare `RepositoryInterface` exposing unified database actions.
        
    - Refactor the `MatchedRoute` DTO to support tenant-level path isolation criteria.
        

### 🔑 Phase 1: Component `waffle-commons/auth` (P1)

_This component delivers high-density security adapters required to process user identities asynchronously without ever relying on PHP's traditional, blocking server-side sessions._

- **[ ] Universal Authentication Bridge (UAB - RFC-021 Specification):**
    
    - Implement `UserAssertionSigner`: serializes user identity claims into a compact Base64-URL payload, signed cryptographically using **HMAC-SHA256** with a shared environment key (`ECOSHIELD_AUTH_SECRET`).
        
    - Integrate an anti-replay mechanism by packing an issued-at (`iat`) timestamp, restricting the valid lifetime of the `X-EcoShield-Assert-User` HTTP header to exactly 5 seconds.
        
    - Implement IP-Binding validation on the receiver end to assert that the proxying remote address matches the signed payload IP.
        
- **[ ] Stateless OpenID Connect (OIDC) & OAuth2 Client:**
    
    - Create a non-blocking identity federation client leveraging `waffle-commons/http-client` to exchange authorization codes with external Identity Providers (e.g., Keycloak, Auth0).
        
    - Implement asynchronous cache warming of the discovery document (`/.well-known/openid-configuration`) using `waffle-commons/cache` to prevent cold start bottlenecks.
        
    - Process `state` and `nonce` parameters statelessly by injecting secure, signed, and short-lived cookies, bypassing server-side memory files.
        
- **[ ] Constant-Time Signature Verification:**
    
    - Mandate the use of native `hash_equals()` for all token signature verifications to shield the ecosystem against timing attacks.
        
    - Enforce a Fail-Closed initialization: any missing or misconfigured encryption secret must trigger a fatal security exception, instantly halting the boot sequence.
        

### 💾 Phase 2: Component `waffle-commons/data` (P1.5)

_This component abstracts database persistence. It is designed to run safely within long-running worker environments by replacing stateful tracking ORMs (Identity Maps) with stateless, lightweight, and memory-bounded hydration routines._

- **[ ] Worker-Safe Connection Pooling:**
    
    - Implement a PDO connection pool wrapper capable of recycling active database sockets at the end of each FrankenPHP worker loop.
        
    - Wire connection cleanup to the `ResettableInterface` contract: execute an automatic transactional rollback (`rollback()`), free lock tables, and clear prepared statement buffers inside the `$kernel->reset()` loop.
        
    - Implement the _Ping-Before-Dispense_ protocol: execute a sub-millisecond low-level socket ping before handing a database handle to a request middleware, preventing "MySQL server has gone away" fatal halts.
        
- **[ ] Semantic Query Representation (SQR) & Compilers:**
    
    - Design an object-oriented, declarative query builder mapping select, filter, and pagination intentions into an Abstract Syntax Tree (SQR AST).
        
    - Build SQL compilers: compile the SQR AST into strictly parameterized, prepared SQL queries for MySQL, SQLite, Oracle, and MSSQL.
        
    - Build the NoSQL compiler (Firebase/Firestore): compile the SQR AST into structured JSON API payloads, automatically wrapping queries inside strict private/public directory paths (RFC-022 boundaries).
        
- **[ ] PHP 8.5 Property Hooks Hydration:**
    
    - Map raw query tuples directly into immutable `final readonly` Data Transfer Objects (DTOs) during the fetch phase.
        
    - Enforce validation on instantiation: declare native **Property Hooks** inside DTO constructors to validate formats, ranges, and types (e.g., an email field validating itself via `set` hooks during database hydration).
        
    - Raise a standardized validation exception if corrupted or manipulated records are loaded from the database, preventing memory state poisoning.
        

### 🔗 Phase 3: Cross-Component Integrations & Synergies (P2)

_The true strength of a micro-component architecture lies in the secure and seamless composition of its independent building blocks. Beta 3 introduces three major synergies._

- **[ ] Fail-Closed ABAC Connected to the Database:**
    
    - Connect the authorization engine (`waffle-commons/security`) to the data layer: security `#[Voter]` classes query the stateless database pool to evaluate roles and fine-grained permissions under sub-millisecond execution times.
        
- **[ ] Stateless Session-Bound CSRF Tokens:**
    
    - Bind CSRF tokens generated by `CsrfMiddleware` to the unique anonymous browser session ID (`WAFFLE_SID`) and the client IP using the cryptographic HMAC generator of the `auth` component.
        
- **[ ] CLI Route & Cache Warmup:**
    
    - Extend `waffle-commons/console`: implement administrative commands (`waffle data:warmup`) to pre-compile and serialize SQR trees and routing tables directly into the shared memory of OPcache, reducing disk I/O on the first request.
        

## 🛑 Definition of Done (DoD) for Beta 3

The entire ecosystem will be certified and released under version `v0.1.0-beta3` only when:

1. **Agnosticism Preserved:** The new `auth` and `data` packages contain no direct coupling or cross-imports, depending exclusively on `waffle-commons/contracts` and explicit PSR interfaces.
    
2. **Stateless Stability:** Load-testing Waffle under FrankenPHP worker mode shows flat memory curves (zero memory leaks) after executing 50,000 concurrent database transactions and UAB security checks.
    
3. **Mago Purity:** `mago analyze` and `mago guard` return exit code `0` across all 15 components with absolutely zero baseline files or general suppressions.
    
4. **Localization Alignment:** All core framework code, exceptions, and CLI log messages are strictly written in **English** for international standards, while the starter `skeleton` may feature French comments to honor its Norman R&D heritage.