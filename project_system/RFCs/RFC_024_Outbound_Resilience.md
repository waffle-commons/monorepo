---
title: "RFC-024: Outbound Resilience (Client Policies & Circuit Breaker)"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-024: Outbound Resilience (Client Policies & Circuit Breaker)

**Status:** In progress for `0.1.0-beta7` — HTTP client resilience policies (`[NET-02]`) and the circuit breaker (`[NET-03]`). Inbound rate limiting (`[NET-01]`) stays in RFC-017 §3.1 and shares this RFC's state-storage family. **Components:** `waffle-commons/http-client` (policies, retries, breaker), `waffle-commons/contracts` (policy, breaker and state-storage contracts), and the component that implements the shared state storage (open — §5) **Author:** DevSecOps Lead **Tags:** http-client, resilience, timeouts, retry, backoff, circuit-breaker

**Reference RFCs:** RFC-003 (HTTP & Middleware Pipeline), RFC-005 (Logging & Observability), RFC-015 (Asynchronous Execution — concurrent fan-out), RFC-017 (Advanced Security & Edge Protection — rate limiting), RFC-021 (Universal Authentication Bridge — outbound credentials)

## 1. Summary

Outbound calls must survive flaky upstreams without taking the worker down with them. This RFC defines
bounded, per-request resilience policies for `waffle-commons/http-client` — timeouts, retries only where
they are safe, exponential backoff with jitter — and a circuit breaker whose state is shared by every
worker. It is a hard prerequisite for the EcoShield Gateway alpha (`[GATE-02]`), which proxies to a
legacy upstream.

## 2. Motivation

- **Today's client** (`http-client/src/Client.php`) has hard ceilings — 1 s to connect, 10 s in total —
  does not follow redirects, and runs the SSRF guard (resolve → validate → pin) before every transfer. It
  has no retry and no breaker.
- **Naive retries make outages worse:** unbounded or synchronized retries turn a slow upstream into a retry
  storm, and retrying a non-idempotent request can duplicate a side effect.
- **A breaker in worker memory protects nothing:** each worker would open its own, N times over, and a new
  worker would start closed. The state must be shared.
- **Fail fast:** when an upstream is down, a gateway should answer in milliseconds instead of pinning
  every worker for the full timeout.

## 3. Technical Specifications

### 3.1 Resilience policy (`[NET-02]`)

- **Immutable policy DTO**, built from configuration rather than code: connect timeout, total timeout,
  maximum attempts, backoff (base, cap, jitter), the retryable statuses and transport errors, and an
  explicit opt-in for retrying non-idempotent methods.
- **No infinite timeout by construction.** cURL treats `0` as "no timeout", so the DTO's property hooks
  reject `≤ 0` and anything above the ceiling; today's ceilings become the defaults.
- **Idempotency.** Only idempotent methods (RFC 9110: `GET`, `HEAD`, `OPTIONS`, `PUT`, `DELETE`) are
  retried by default. `POST` and `PATCH` are retried only when the caller opts in explicitly.
- **Backoff:** exponential with full jitter. A `Retry-After` from a 429 or 503 is honoured only within
  the remaining budget.
- **Bounded total time.** The wall-clock across all attempts never exceeds the policy's total budget.
- **Every attempt re-runs the SSRF guard.** DNS can change between attempts, so resolve → validate → pin
  runs again each time.
- **Per-request override** through an immutable wither on the client (or a request attribute), never
  through mutable client state.

### 3.2 Circuit breaker (`[NET-03]`)

- **States:** closed → open when the failure rate over a window crosses the threshold (with a minimum
  number of calls); open → half-open after the cool-down; half-open admits a bounded number of trial calls,
  then closes on success or re-opens on failure.
- **Key:** the upstream origin (scheme, host, port).
- **Shared, atomic state.** State lives in shared storage (Redis), in the same storage family as the
  RFC-017 limiter, never in worker memory. Recording an outcome and changing state are single atomic
  operations (for example a Lua script), so concurrent workers agree on the state.
- **Fail fast.** An open breaker short-circuits the call before any handle is allocated, with a specific
  exception implementing a contracts exception interface, which the error handler maps to 503.
- **Observability.** Each transition is emitted as an event and as metrics (a transition counter and a
  state gauge through `MetricsRegistryInterface`). The event type (or its interface) lives in contracts,
  so listeners in other components never import `http-client`'s concrete classes.

### 3.3 Composition

- An open breaker short-circuits **every** attempt, including retries; each attempt's outcome is
  recorded.
- The concurrent path (`sendRequests()`, `promise()`) applies the policy per request and checks the
  breaker before a handle is allocated, exactly as it runs the SSRF guard today.
- `AuthenticatedClient` (RFC-021) keeps decorating the client, and credentials are applied again on every
  attempt.

## 4. Contributor Guidelines

- **Contracts-first:** the policy, breaker and storage contracts land in `waffle-commons/contracts` before
  their consumers; `mago guard` keeps the perimeter.
- **Stateless:** no retry counter or breaker state in a worker property. `wfl igor` stays at 0 KO — and a
  per-worker counter is a correctness bug even where igor would only warn.
- **Never retry a non-idempotent method silently.**
- **Test the state machine with an injected clock**, never with `sleep()`; exercise the behaviour under
  load through fault injection (the `chaos-runner` agent).

## 5. Open Questions (decide before the code lands)

1. **Where the Redis-backed state storage lives** — in `http-client`, through
   `RedisConnectionPoolInterface`, or in the component that already owns Redis — while keeping every
   consumer on the contract.
2. **Breaker behaviour when its own storage is unavailable** (treat as closed, or fail fast).
3. **Configuration keys** (frozen by beta8 `[FRZ-03]`).
4. **Whether `Retry-After` may extend a wait beyond the backoff cap** when it still fits the total budget.

## 6. Acceptance Criteria (`Roadmap_Beta7.md`)

- The breaker opens and half-opens per its thresholds in fault-injection tests.
- Zero infinite timeouts possible by construction.
- Standard gates: `composer mago` zero output, `composer tests` ≥95 % coverage, `wfl igor` 0 KO.
