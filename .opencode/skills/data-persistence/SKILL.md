---
name: data-persistence
description: Architect for the Universal Data & Persistence Layer (RFC-022) — stateless SQR, connection pools, Firestore paths, atomic flat-file
compatibility: opencode
---

## What I do
I design and review the **Universal Data & Persistence Layer (UDPL)** (RFC-022), the **shipped**
`waffle-commons/data` component — a stateless, memory-bounded persistence abstraction over SQL,
Firestore, Mongo, KeyValue, Cassandra, GraphQL, and flat-file JSON backends for FrankenPHP worker
mode. Read repos + live drivers + CRUD writes (save/delete/findById on all 7 backends) are landed. No
Active Record, no Unit-of-Work / Identity-Map.

## When to use
"Design the data layer", "RFC-022", "SQR / repository / connection pool / Firestore path /
flat-file write / hydration".

## Architecture mandates (RFC-022)
- **Stateless Semantic Query Representation (SQR):** repositories build a declarative AST
  (target scope · filter tree · projection list · bounded pagination) — **never** raw SQL strings.
  Driver adapters compile the SQR into the native backend format.
- **Stateless CRUD writes:** read contract `RepositoryInterface` (find/findOne/stream) is extended by
  `WritableRepositoryInterface` (`save` / `delete` / `findById`). Writes go through a pure
  **`DataMapperInterface`** (`target` / `identityField` / `fields` / `identify` / `toRow`) — entities stay
  immutable VOs (no Active Record). `save()` branches INSERT vs UPDATE on `identify()` (null ⇒ insert).
  Every backend implements it: SQL (transactional INSERT/UPDATE/DELETE), Firestore, Mongo (insert/upsert/
  deleteOne), KeyValue (SET/DEL, identity mandatory), Cassandra (CQL upsert), GraphQL (Hasura-style
  mutations), JSON flat-file (atomic read-modify-write).
- **Immutable hydration:** rows/documents map directly to `final readonly` DTOs; PHP 8.5 Property
  Hooks validate at construction and throw `ValidationException` on poisoned data. No change-tracking.
- **Worker safety:** every driver implements `ResettableInterface`; on `$kernel->reset()` it releases
  connections to the pool, resets transaction levels, clears statement caches. A crash mid-transaction
  triggers an automatic `rollback()`.

## Driver-family rules
- **Relational (PDO/native):** **stateless connection pooling** (health-PING before dispensing;
  non-blocking reconnect); **strict parameterization only** (no interpolation — OWASP A03); buffer
  streaming / cursors for large sets (never load all rows into memory).
- **Firestore/Firebase (COMPLETE):** `FirestoreRepository` (+ `Driver/Firestore/FirestoreClientInterface`
  port + `FirestoreRestClient`) enforces all three rules — Rule 1: `FirestoreScope` isolates
  `/artifacts/{appId}/public/data/{collection}` and `/artifacts/{appId}/users/{userId}/{collection}`
  (root impossible; `forPublic`/`forPrivate` translate a bad scope to `SecurityPathViolationException`);
  Rule 2: only equality reaches the driver, range/set/sort/offset resolved by `InMemoryEvaluator`;
  Rule 3: every read/write gated on `Contracts\Auth\SecurityContextInterface::isAuthenticated()` ⇒
  `UnauthenticatedAccessException` on an anonymous caller. `forPrivate` derives `{userId}` from the
  authenticated identity, so a caller can never reach another user's data.
- **Flat-file JSON:** `LOCK_EX` + **atomic write** (temp file → `rename()`) to prevent corruption.
- **GraphQL / API:** compile the SQR to query documents; execute via the async `http-client`.

## Beta5 SHIPPED — DBAL pooling (DBAL-01/02/03)
The generalised, worker-safe connection pool landed in beta5. Read the real code before touching it:

- **Contracts (`contracts/src/Data/Connection/`):** `ConnectionInterface` (backend-neutral lease:
  `kind()` / `isAlive()` / `id()`), the narrowed `PdoConnectionInterface` (typed `pdo()`) and
  `RedisConnectionInterface` (typed `client()`), `ConnectionPoolInterface` (the neutral
  `acquire()` / `release()` surface), and its narrowed `RelationalConnectionPoolInterface` (adds the
  request-scope methods + `prepare()`) / `RedisConnectionPoolInterface`. So relational and key-value
  pooling share ONE contract; relational consumers depend on the narrowed `Relational…` interface.
- **Implementations (`data/src/Connection/`):** `PDOConnectionPool` + `PdoConnection`,
  `RedisConnectionPool` + `RedisConnection`. Both pools `implements …PoolInterface, ResettableInterface`
  **DIRECTLY** (the shallow `wfl igor` scan needs the explicit clause).

### Invariants that MUST hold
- **Connection affinity (DBAL-01):** `beginRequestScope()` pins ONE lease — every `acquire()` while
  the scope is open returns that SAME `pinnedLease`, and `release()` of it is a no-op, so a downstream
  repository cannot return the middleware's transaction connection to the idle set mid-request.
  `endRequestScope()` unpins THEN releases (no-op when no scope is open). `beginRequestScope()` is
  idempotent within a scope.
- **`TransactionIsolationMiddleware` (DBAL-02) — `data/src/Middleware/`:** wraps every write verb
  (POST/PUT/PATCH/DELETE by default) in ONE transaction on the pinned connection. **Pipeline ordering
  is load-bearing:** place it INSIDE the ErrorHandler, AFTER Security, BEFORE the Dispatcher — a thrown
  exception then unwinds through this middleware (which rolls back and rethrows) before the error
  handler renders it. `beginRequestScope()` → `beginTransaction()` → handler → `commit()`; ANY
  throwable → `rollBackQuietly()` + rethrow; `endRequestScope()` in the `finally`. A write controller
  that catches its own exception and returns 2xx COMMITs, by design.
- **Transaction-aware repos:** `SQLRepository::executeWrite()` computes
  `$ownsTransaction = !$connection->inTransaction()` and only `beginTransaction()`/`commit()`/
  `rollBack()`s when it owns the transaction. When the middleware already opened one on the pinned
  connection, the repo *enlists* in it — never opens or commits a nested one — so its write is rolled
  back with the request on failure.
- **Heal-on-lease:** every idle handle is probed before it is dispensed — PDO runs the `pingQuery`
  (`SELECT 1`), Redis runs the injected `healthCheck` (`PING`); a dropped socket is discarded and
  transparently replaced, so a stale handle never reaches a caller. (`RedisConnectionPool` types its
  client as `object` and takes the client factory, `PING`, and reset as injected closures, so the
  component never assumes `ext-redis`.)
- **Origin-tracking (DBAL-03):** `$issued` is the set of underlying-handle `spl_object_id()`s the pool
  minted; `release()` of a lease whose handle this pool never issued (a foreign/other-backend lease)
  is a fail-soft no-op. All internal maps key by `spl_object_id()` so a connection is tracked by
  identity and can never be double-pooled or double-counted.
- **`reset()` between requests:** drops the `pinnedLease`, returns borrowed handles to idle, ROLLS
  BACK any dangling transaction (PDO) / runs the `onReset` hook `DISCARD`/`UNWATCH` (Redis, swallowing
  a throwing reset since it runs inside `Container::reset()`), CLEARS the prepared-statement cache, and
  re-establishes `$issued` to exactly the warm idle handles (so the set never grows unbounded). The
  sockets stay open so the next request reuses warm connections.

## Done (RFC-022 §7)
- Flat memory curve over 50k worker requests (no leaks); `mago analyze` zero errors/warnings, no
  baselines; all driver errors rethrown as `DatabaseExceptionInterface` (defined in `contracts`).

> **Localization note:** RFC-022 §7.4 requests **French** for the data component's
> logs/exceptions/audit messages, but project policy is **English everywhere except the template apps
> (`skeleton`, `workspace`, `academy`)**. `waffle-commons/data` is none of those, so it emits
> **English**.
