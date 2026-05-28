---
name: data-persistence
description: Architect for the Universal Data & Persistence Layer (RFC-022) — stateless SQR, connection pools, Firestore paths, atomic flat-file
compatibility: opencode
---

## What I do
I design and review the **Universal Data & Persistence Layer (UDPL)** (RFC-022), the future
`waffle-commons/data` component — a stateless, memory-bounded persistence abstraction over SQL,
Firestore, flat-file JSON, and API backends for FrankenPHP worker mode. No Active Record, no
Unit-of-Work / Identity-Map.

## When to use
"Design the data layer", "RFC-022", "SQR / repository / connection pool / Firestore path /
flat-file write / hydration".

## Architecture mandates (RFC-022)
- **Stateless Semantic Query Representation (SQR):** repositories build a declarative AST
  (target scope · filter tree · projection list · bounded pagination) — **never** raw SQL strings.
  Driver adapters compile the SQR into the native backend format.
- **Immutable hydration:** rows/documents map directly to `final readonly` DTOs; PHP 8.5 Property
  Hooks validate at construction and throw `ValidationException` on poisoned data. No change-tracking.
- **Worker safety:** every driver implements `ResettableInterface`; on `$kernel->reset()` it releases
  connections to the pool, resets transaction levels, clears statement caches. A crash mid-transaction
  triggers an automatic `rollback()`.

## Driver-family rules
- **Relational (PDO/native):** **stateless connection pooling** (health-PING before dispensing;
  non-blocking reconnect); **strict parameterization only** (no interpolation — OWASP A03); buffer
  streaming / cursors for large sets (never load all rows into memory).
- **Firestore/Firebase:** **no root collections** — enforce isolated paths
  `/artifacts/{appId}/public/data/{collection}` and `/artifacts/{appId}/users/{userId}/{collection}`;
  **no server-side compound/sort queries** (fetch simple, filter/sort in memory); **auth gate** before
  every transaction (`signInWithCustomToken` / `signInAnonymously`).
- **Flat-file JSON:** `LOCK_EX` + **atomic write** (temp file → `rename()`) to prevent corruption.
- **GraphQL / API:** compile the SQR to query documents; execute via the async `http-client`.

## Done (RFC-022 §7)
- Flat memory curve over 50k worker requests (no leaks); `mago analyze` zero errors/warnings, no
  baselines; all driver errors rethrown as `DatabaseExceptionInterface` (defined in `contracts`).

> **Localization note:** RFC-022 §7.4 requests **French** for the data component's
> logs/exceptions/audit messages, but project policy is **English everywhere except the `skeleton`
> component**. `waffle-commons/data` is not `skeleton`, so it emits **English**.
