---
title: "RFC-022: Universal Data & Persistence Layer (UDPL)"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-022: Universal Data & Persistence Layer (UDPL)

**Status:** Proposed (Planned for v1.x / Ecosystem Phase)

**Components:** `waffle-commons/data`

**Author:** Lead DevSecOps & Principal Systems Architect

**Tags:** database, dbal, persistence, connection-pooling, sql, nosql, state-isolation

**Reference RFCs:** RFC-001 (Core & Runtime), RFC-007 (Dependency Injection), RFC-011 (Data Integrity), RFC-013 (Caching System)

## 1. Summary

This RFC specifies the design and implementation guidelines for the **Universal Data & Persistence Layer (UDPL)**, contained in the future `waffle-commons/data` component. The UDPL is a lightweight, high-performance, and unified persistence layer designed to interface Waffle applications with any relational SQL engine (MySQL, MariaDB, PostgreSQL, Oracle, MSSQL, SQLite), document-based NoSQL store (Firebase/Firestore, MongoDB), key-value store (Redis, DynamoDB), wide-column store (Cassandra), flat-file JSON store, and API-driven provider (GraphQL, REST) under a single, cohesive architectural abstraction.

Crucially, the UDPL strictly rejects the stateful Active Record or heavy Unit of Work (Identity Map) patterns of traditional ORMs. It mandates stateless, memory-bounded, and asynchronous-ready operations optimized for FrankenPHP's Resident Worker runtime.

## 2. Motivation & Problem Statement

### 2.1 The Failure of Traditional ORMs in Worker Environments

Popular PHP Object-Relational Mappers (ORMs), such as Doctrine or Eloquent, were architected for short-lived, single-request execution lifecycles. When forced into resident memory worker environments like FrankenPHP, they introduce critical failure modes:

1. **Memory Leakage (Unit of Work Bloat):** The internal Identity Map caches every loaded entity. Over thousands of persistent worker loops, memory consumption grows linearly, eventually triggering Out-Of-Memory (OOM) process crashes (violating FinOps and Green IT principles).
    
2. **Connection Starvation & Loss:** Persistent workers hold database connections open. If the database server drops an idle connection (due to timeout or restart), standard ORMs throw fatal exceptions rather than executing automatic, non-blocking reconnections.
    
3. **Cross-Request Context Pollution:** Sharing stateful entities between subsequent HTTP worker loops can accidentally expose data from Request A to Request B if the entity manager state is not manually and meticulously flushed.
    

### 2.2 The Unified Interface Myth vs. Reality

Many frameworks attempt database abstraction by forcing SQL paradigms onto NoSQL structures (or vice versa), resulting in degraded query capabilities and leaky abstractions. Waffle requires an abstraction that unifies the _data ingestion and contract validation_ phases while preserving the specialized native query power of each storage engine.

## 3. Core Architecture & Layer Abstractions

The UDPL is divided into three distinct conceptual layers, ensuring strict Separation of Concerns and complying with the **Component Agnosticism** rule.

```
       +--------------------------------------------------------+
       |                  Application Controller                |
       +--------------------------------------------------------+
                                   |
                       Requests Readonly DTOs
                                   v
       +--------------------------------------------------------+
       |               Stateless Repository Layer               |
       |     (Interfaces defined in waffle-commons/contracts)    |
       +--------------------------------------------------------+
                                   |
                        Calls Semantic Query AST
                                   v
       +--------------------------------------------------------+
       |             Universal Driver Registry (UDR)            |
       |       (Connection Managers & Stateless Pools)         |
       +--------------------------------------------------------+
             /                     |                        \
  +------------------+   +--------------------+   +-------------------+
  |   SQL Adapters   |   |   NoSQL Adapters   |   |   JSON / GraphQL  |
  |  (MySQL, Oracle) |   | (Firebase, Mongo)  |   |    API Adapters   |
  +------------------+   +--------------------+   +-------------------+
```

### 3.1 The Semantic Query Representation (SQR)

To allow agnosticism, the UDPL introduces a stateless **Semantic Query Representation (SQR)**. Instead of raw SQL strings or driver-specific query builders, repositories compile database requests into a declarative, tree-structured semantic query object.

The SQR tree represents the intent of the query:

- **Target Scope:** The collection, table, or endpoint identifier.
    
- **Filter Tree:** A logical combination of field-level predicates (e.g., Equality, Range, Set Containment) represented conceptually as an Abstract Syntax Tree (AST).
    
- **Projection List:** The exact properties required (preventing select-all performance drains).
    
- **Pagination State:** Bounded offset/limit markers enforcing $O(1)$ memory consumption.
    

Specialized driver adapters interpret this SQR tree and compile it on-the-fly into the highly optimized native format of the selected backend (such as a parameterized SQL statement or a Firestore structured query payload).

### 3.2 The Stateless CRUD Surface

The read surface (`RepositoryInterface`: `find` / `findOne` / `stream` over an SQR) is extended by a
write surface, `WritableRepositoryInterface`, adding the mutating half of CRUD:

- `save(object $entity): void` — INSERT or UPDATE, chosen by the entity's mapped identity.
- `delete(object $entity): void`.
- `findById(string|int $id): ?object`.

Writes never use Active Record. Each entity is an immutable Value Object, and a pure **Data Mapper**
(`DataMapperInterface`: `target()`, `identityField()`, `fields()`, `identify()`, `toRow()`) translates
it to and from the flat storage row — the exact inverse of the read-side hydrator. `save()` performs an
INSERT when `identify()` returns null and an UPDATE/upsert otherwise; the mapper holds no per-call
state, so a repository remains safe to share across resident-worker requests.

Every backend family implements the write surface under its native semantics: relational drivers wrap a
transactional INSERT/UPDATE/DELETE (rollback on failure, RFC-022 §6); Mongo uses insert / replace-upsert
/ deleteOne; key-value stores require an explicit identity (no auto-id) and serialize the row to one
value; Cassandra compiles to a CQL `INSERT` (itself an upsert) or `DELETE`; GraphQL emits a
parameterized Hasura-style mutation; and the flat-file JSON store performs an atomic read-modify-write.

## 4. Driver-Specific Execution Specifications

The UDPL unifies multiple storage strategies by grouping them into three execution families, each governed by strict runtime requirements.

### 4.1 Relational SQL Driver Family (MySQL, MariaDB, PostgreSQL, Oracle, MSSQL, SQLite)

Relational drivers wrap standard driver extensions (such as `PDO` or driver-specific native layers) and must enforce:

- **Stateless Connection Pooling:** Under worker loops, connection lifecycles are completely decoupled from requests. The pool monitors connection health (executing an immediate, silent "PING" or reset before dispensing a connection to a request handler) and scales up/down within strict boundaries.
    
- **Strict Parameterization:** No inline variable interpolation is allowed. All values derived from user input are strictly bound via prepared parameters to neutralize SQL Injection vectors (OWASP A03:2021).
    
- **Buffer Streaming:** Large database result sets must be retrieved sequentially using cursors or non-buffered queries. Loading thousands of database rows into memory at once is forbidden.
    

### 4.2 Document, Key-Value & Wide-Column NoSQL Families

The NoSQL surface spans three sub-families, each served by a dedicated compiler that translates the stateless SQR into the backend's native query representation, under backend-appropriate constraints:

- **Document:** Firestore/Firebase and MongoDB. MongoDB supports rich server-side predicates (range, set membership, pattern) compiled directly into a native filter document; Firestore deliberately does **not** (see the three rules below) and defers everything but equality to in-memory processing.
- **Key-Value:** Redis and DynamoDB. A key-value store has no field-level filter or projection semantics, so the compiler accepts only key-equality (single-key `GET`) and key-membership (`MGET` / batch get) lookups and rejects any other predicate, ordering, or projection.
- **Wide-Column:** Cassandra. The SQR compiles to parameterized CQL; CQL-incompatible operators (`<>`, `NOT IN`, `LIKE`) and `OFFSET` pagination are rejected, and the compiler flags when a query would require `ALLOW FILTERING`.

For Cloud-Native and decentralized architectures, the **Firestore** adapter must be configured with a strict, secure default layout following three mandatory rules:

- **Rule 1 - Strict Path Boundaries:** No root-level collections are permitted. The driver must automatically enforce isolated path prefixing:
    
    - _Public Data Share:_ `/artifacts/{appId}/public/data/{collectionName}`
        
    - _Private User Data:_ `/artifacts/{appId}/users/{userId}/{collectionName}`
        
- **Rule 2 - No Complex Queries:** To avoid execution halts or errors due to missing remote indexes, complex compound queries or sort orderings must not be executed on the server. The driver must fetch data using simple, direct collection/document lookups and perform any required filtering or sorting in local memory.
    
- **Rule 3 - Authentication Gate:** The NoSQL driver must ensure that custom or anonymous authentication is successfully resolved (`signInWithCustomToken` or `signInAnonymously`) _prior_ to executing any query. Every storage transaction must be guarded by an active identity check.

> **Implementation note (complete).** `waffle-commons/data` ships `FirestoreRepository` over a
> `Driver/Firestore/FirestoreClientInterface` port (live `FirestoreRestClient`): Rule 1 via
> `FirestoreScope` (root collections impossible by construction; a malformed scope raises
> `SecurityPathViolationException`), Rule 2 via the `FirestoreCompiler` + `InMemoryEvaluator`
> (only equality is pushed to the server; range/set/sort/offset run in memory after a simple fetch),
> and Rule 3 via the injected `Waffle\Commons\Contracts\Auth\SecurityContextInterface` — every read and
> write asserts `isAuthenticated()` first, raising `UnauthenticatedAccessException` otherwise. The
> private-scope constructor derives `{userId}` from the authenticated identity, so cross-tenant access
> is impossible.
    

### 4.3 Document Flat-File & API Family (JSON, GraphQL)

- **Flat-File JSON Storage:** Highly useful for microservice configurations or embedded environments. The JSON driver operates on local physical files, enforcing strict read/write locks (`LOCK_EX`) and atomic updates (writing to a temporary file first, then executing a rename) to prevent file corruption in concurrent environments.
    
- **GraphQL / Web API Integration:** Elevates external third-party microservices to the status of virtual database engines. The SQR is compiled into standard GraphQL query documents, executed via the asynchronous `http-client` component.
    

## 5. Data Integrity & PHP 8.5 Hydration

The UDPL achieves maximum execution speed by removing the conceptual overhead of "Entities". There is no change-tracking state kept on data objects. All database rows or documents are mapped directly to immutable Data Transfer Objects (DTOs) during the retrieval phase.

### 5.1 The Hydration Flow

1. **Tuple Retrieval:** The driver adapter executes the query and retrieves the raw data record as a flat associative array of primitives.
    
2. **Type Mapping:** The Hydrator maps database types (e.g., converting integer markers or string timestamps into native PHP types).
    
3. **Property Hook Validation:** The Hydrator instantiates the target DTO, passing the mapped primitives to the constructor. At this precise microsecond, PHP 8.5 **Property Hooks** intercept the property assignments, executing strict validation assertions (e.g., verifying boundary ranges, formatting rules, or non-empty constraints).
    
4. **Immutability Guarantee:** The calling code receives a final, read-only DTO. Since the class is `readonly`, its internal state is cryptographically guaranteed to be valid and immutable.
    

If any database corruption causes an invalid record to be loaded, the property hook immediately throws a `ValidationException`, preventing the application from executing logic with poisoned memory states.

## 6. Worker Mode Safety & Pool Management

To ensure total statelessness and prevent memory leaks, all UDPL drivers must implement the `ResettableInterface` and hook into Waffle's request cleanup cycle:

- **Request-Bound Reset:** When `WaffleRuntime` completes an HTTP loop and calls `$kernel->reset()`, the `Container` resets any request-scoped services. The UDPL connection manager must intercept this call to release active connections back to the shared pool, reset transaction levels, and clear any local statement caches.
    
- **Transaction Guard:** If a worker thread crashes or experiences a network timeout while inside an active transaction, the connection manager must automatically execute a `rollback()` during the recovery loop, ensuring the database state is never left in an uncommitted, locked condition.
    

## 7. Definition of Done (DoD) for implementation

The UDPL component (`waffle-commons/data`) will be certified as complete once the following gates are satisfied:

1. **Zero-Memory Accumulation:** Stress-testing the database client over 50,000 consecutive simulated worker requests (using `k6` against FrankenPHP) must result in a flat memory consumption curve (no memory leaks).
    
2. **Mago Purity:** The entire database adapter suite compiles with exactly **zero errors and zero warnings** under `mago analyze` without using baseline configuration files.
    
3. **Unified Exception Strategy:** All database-specific driver exceptions (e.g., PDO, Redis, or Firestore connection failures) must be caught by the driver adapter and rethrown as a standardized, clean `DatabaseExceptionInterface` defined in `waffle-commons/contracts`.
