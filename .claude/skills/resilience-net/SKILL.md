---
name: resilience-net
description: "Rate limiter, client timeout/retry policies, circuit breaker in shared storage (beta7 NET, not built yet)"
when_to_use: >-
  Rate limiting or throttling, 429 / Retry-After, outbound timeouts, retry with backoff, circuit
  breaker, [NET-01..03], RFC-017 section 3.1, RFC-024, where limiter and breaker state lives.
---

> **Status (2026-09-30): committed beta7 scope, no code yet.** Hard prerequisite for the EcoShield
> alpha (`[[ecoshield]]` `[GATE-02]`). `[NET-01]` is specified in RFC-017 §3.1; `[NET-02]` and
> `[NET-03]` in **RFC-024**, which lists the design questions to settle before their code lands.

## What I do
I design the inbound rate protection and outbound resilience an API ecosystem needs to survive load
and flaky upstreams. It is correct across workers because every piece of state lives in shared
storage. See `[[contracts-first]]`, `[[worker-safety]]`, `[[observability]]`, `[[security-audit]]`.

## When to use
"rate limit / throttle", "429 / Retry-After", "timeouts", "retry with backoff", "circuit breaker",
beta7 NET.

## What exists to build on (verified 2026-09-30)
- **`http-client/src/Client.php`:** connect and total timeouts are hard ceilings
  (`CONNECT_TIMEOUT_MS = 1000`, `TIMEOUT_MS = 10_000`), and redirects are not followed. The SSRF guard
  (`Security/SsrfGuard.php`: resolve → validate → pin through `CURLOPT_RESOLVE`) runs before any handle
  is allocated. `sendRequests()` and `promise()` provide the concurrent path. There is no retry and no
  breaker.
- **`cache/`:** PSR-16 adapters (`ArrayCache`, `FileCache`, `RedisCache`), a PSR-6 pool and
  stampede-aware `compute()`. It has **no atomic primitive**: no increment, no compare-and-set, no lock.
- **Redis access through contracts:** `Data\Connection\RedisConnectionPoolInterface`, whose leases
  expose `client(): object`.
- **Middleware homes:** `security/src/Middleware/` (Cors, Csrf, Security, AnonymousSession) and
  `pipeline/src/Middleware/` (TrustedHost, SecureHeaders).
- **Client identity:** every component reads `REMOTE_ADDR` directly. There is **no trusted-proxy
  client-IP resolution** anywhere.
- **Lifecycle events** are concrete classes in `waffle/src/Event/` (RequestReceived,
  ControllerArgumentsResolved, ResponseGenerated, Terminate). Metrics go through
  `contracts/src/Telemetry/Metrics/`.

## Mandates
### `[NET-01]` Token-bucket rate limiter
The contracts `Waffle\Commons\Contracts\RateLimit\RateLimiterInterface` and
`LimiterStateStorageInterface` land first. The middleware goes in `security/src/Middleware/`, keyed by
IP, authenticated subject (`Contracts\Auth\UserIdentityInterface`) or API token. It emits `RateLimit-*`
headers and fails closed with `429` plus `Retry-After`.

- **Atomicity is the acceptance criterion.** "No over-admission beyond bucket size under concurrent
  multi-worker load" cannot hold on a PSR-16 `get()` → `set()`, because two workers read the same token
  count. The storage contract needs one atomic check-and-consume operation, e.g. a Redis Lua script.
  Wherever the Redis-backed implementation lives — using `RedisConnectionPoolInterface`, or in the
  component that already owns Redis — `security` sees only the contract. The in-memory fallback is
  documented as **single-worker only**.
- **Key trust.** Behind a proxy or a K8s ingress, `REMOTE_ADDR` is the proxy, so every client shares one
  bucket. Trusting `X-Forwarded-For` blindly lets a client choose its own key. The IP key therefore needs
  a trusted-proxy resolver (explicit proxy CIDR allow-list, right-most untrusted hop). **This is an open
  design decision:** land it contracts-first and reuse it for every IP-bound check.
- **Storage outage.** Decide and document the fail mode per limiter (fail closed with 429/503, or fail
  open). The chaos soak exercises it (`[[soak-endurance]]`).
- **Authentication endpoints.** Beta6's audit deferred brute-force limiting and lockout to this item, so
  cover them (`[[auth-bridge-audit]]`).

### `[NET-02]` Client resilience policies
Immutable policy DTOs (configuration, not code) set per request: connect/total timeout, bounded retry
with exponential backoff and jitter, and idempotency awareness — never auto-retry a non-idempotent
method unless explicitly opted in.

- **No infinite timeout by construction.** cURL treats `0` as "no timeout", so the DTO's hooks reject
  `≤ 0` and anything above the ceiling. Today's ceilings become the defaults.
- **Every retry re-runs the SSRF guard** (resolve → validate → pin): DNS can change between attempts.
- **Bound the total time across attempts** so retries cannot multiply the worst case.

### `[NET-03]` Circuit breaker
Closed / open / half-open around outbound calls, with a failure-rate threshold and a cool-down.

- **State in shared storage**, from the same family as the limiter's. A per-worker breaker opens N times
  and protects nothing.
- **Transitions as events and as metrics.** Listeners in other components cannot import `http-client`'s
  or `waffle`'s concrete classes, so the transition event type (or its interface) lands in contracts
  first.

## Gate
- **Limiter:** no over-admission under **concurrent multi-worker** load, tested with several PHP
  processes against a real Redis or with k6 against a limited route on a multi-worker FrankenPHP. A
  single-process test proves nothing about atomicity. `RateLimit-*` and `Retry-After` are correct.
- **Breaker:** opens, half-opens and closes per its thresholds — the state machine unit-tested with an
  injected clock, the behaviour under fault injection with the `chaos-runner` agent against a bench
  stack.
- **Timeouts:** no code path can produce an unbounded transfer.
- **DoD:** `wfl dod <comp>` for contracts, security, http-client and the storage owner (mago zero output,
  tests ≥95 %, igor 0 KO). Verify the roadmap criteria with `acceptance-verifier` (scope `NET`).
