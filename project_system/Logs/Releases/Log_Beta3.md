---
title: "Log Beta 3"
date_created: '2026-06-07'
date_updated: '2026-06-07'
type: project
status: archived
tags:
  - waffle
  - beta3
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-beta3

> [!SUMMARY]
> Goal: Identity federation, stateless persistence & CI/CD industrialization — transform Waffle from an HTTP execution pipeline into a full enterprise-grade application ecosystem.

## 1. Technical Changelog (What changed)

### 🔑 New Component — `waffle-commons/auth` (Universal Authentication Bridge, RFC-021)

- `AuthBridgeSigner` / `AuthBridgeVerifier`: HMAC-SHA256-signed user assertions (`X-Wfl-Assert-User`), with an `iat` anti-replay window (default 5s) and receiver-side IP-binding validation.
    
- Stateless OIDC / OAuth2 client over `waffle-commons/http-client`, with discovery-document cache warming (`waffle-commons/cache`) and signed, short-lived `state`/`nonce` cookies (no server-side session files).
    
- Constant-time `hash_equals()` for every signature check; **fail-closed** boot — a missing/short shared secret aborts startup.
    

### 💾 New Component — `waffle-commons/data` (Universal Data & Persistence, RFC-022)

- Worker-safe PDO connection pool: transactional rollback + buffer clear on `$kernel->reset()` (via `ResettableInterface`), and a _ping-before-dispense_ probe to avoid "server has gone away" halts.
    
- Semantic Query Representation (SQR AST) with parameterized SQL compilers (MySQL/SQLite/Oracle/MSSQL) and a Firestore NoSQL compiler bound to private/public directory paths.
    
- PHP 8.5 Property-Hook hydration into immutable `final readonly` DTOs; poisoned records raise a standardized validation exception.
    

### 🔗 Cross-Component Synergies

- Fail-closed ABAC connected to the database (voters query the stateless pool).
    
- Stateless session-bound CSRF: tokens bound to the anonymous `WAFFLE_SID` and client IP via the `auth` HMAC generator.
    
- `waffle data:warmup` CLI to pre-compile SQR trees and routing tables into OPcache.
    

### 🧩 Core

- `AbstractKernel` drains resettable loggers on reset and implements `Contracts\Core\TerminableInterface` (post-response teardown for the worker loop).
    

## 2. Quality Gate (Exit Criteria)

- [x] **Agnosticism:** `auth` and `data` depend only on `waffle-commons/contracts` (no cross-imports).
    
- [x] **Stateless stability:** flat memory curves under sustained worker-mode load.
    
- [x] **Mago purity:** `analyze` + `guard` exit `0` across all 15 components, zero baselines.
    
- [x] **Coverage + worker safety:** per-component coverage gate green (18/18), `wfl igor` 0 KO.
    

## 3. Release

- [x] Umbrella tag → **v0.1.0-beta3** (released 2026-06-07).
    

## 4. Post-Mortem & Next Steps

- **Win:** enterprise-grade identity and persistence shipped statelessly, fully respecting the FrankenPHP worker model.
    
- **Next step:** [Roadmap Beta 4](../../Roadmaps/Roadmap_Beta4.md) — core security patches (AXE 1) and Release-Candidate readiness.
