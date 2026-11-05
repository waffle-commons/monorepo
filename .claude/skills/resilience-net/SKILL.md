---
name: resilience-net
description: "Rate limiter, client timeout/retry policies, circuit breaker, state shared in Redis (beta7 NET, RFC-024)"
when_to_use: >-
  Rate limiting or throttling, 429 / Retry-After, outbound timeouts, retry with backoff, circuit
  breaker, [NET-01..03], RFC-017 section 3.1, RFC-024, where limiter and breaker state lives.
---

> **Status (2026-10-31): built and accepted (beta7).** `[NET-01]` follows RFC-017 §3.1; `[NET-02]` and
> `[NET-03]` follow **RFC-024**, whose design questions were decided on 2026-10-17 (§5). The acceptance check
> of 2026-10-31 passed every NET criterion; the evidence is in `Roadmap_Beta7.md` AXE 1. The EcoShield alpha
> runs all three (`[[ecoshield]]` `[GATE-02]`). Open: a ceiling for `RetryPolicy`'s back-off cap and budget
> (bounded from below only; a beta8 question); `RetryPolicy` retries an upstream `429`; the breaker keeps one
> circuit per origin, so in front of one monolith every proxied route shares it (watch in GATE-03).

## What I do
I design the inbound rate protection and outbound resilience an API ecosystem needs to survive load
and flaky upstreams. It is correct across workers because every piece of state lives in shared
storage. See `[[contracts-first]]`, `[[worker-safety]]`, `[[observability]]`, `[[security-audit]]`.

## When to use
"rate limit / throttle", "429 / Retry-After", "timeouts", "retry with backoff", "circuit breaker",
beta7 NET.

## What exists (2026-10-31)
- **Contracts:** `RateLimit\RateLimiterInterface`, `RateLimit\LimiterStateStorageInterface` and
  `RateLimit\RateLimitDecision`; `Http\ClientIpResolverInterface`; `HttpClient\TimeoutPolicy` and
  `HttpClient\RetryPolicy`; `CircuitBreaker\` (`CircuitBreakerPolicy`, `CircuitDecision`,
  `CircuitStateStorageInterface`, `Enum\CircuitState`, `Event\CircuitStateChanged`,
  `Exception\CircuitOpenExceptionInterface`).
- **Limiter:** `security`'s `Middleware\RateLimitMiddleware` (token bucket, `RateLimit-*` headers, `429`
  with `Retry-After`), keyed by the authenticated subject, else by the client IP resolved behind trusted
  proxies (`http`'s `ClientIp\TrustedProxyClientIpResolver`). The store is `data`'s
  `RedisLimiterStateStorage`: refill and take in one Lua script on the Redis clock. A storage error counts in
  `waffle_ratelimit_storage_errors_total`.
- **Client:** `Client::withTimeouts()`, and in `http-client`'s `Resilience\` the `RetryingClient` and the
  `CircuitBreakerClient`. The concurrent path settles batches through `SettlingClientInterface`: retries in
  waves, the breaker checked for every request before any is sent. The circuits live in `data`'s
  `CircuitBreaker\RedisCircuitStateStorage`, and `/waffle-metrics` counts the transitions.
- **Wiring:** the skeleton mounts the limiter right after authentication (`App\Factory\RateLimitFactory`)
  and wraps both outbound clients in `RetryingClient(CircuitBreakerClient(…))` (`App\Factory\HttpClientFactory`)
  on a phpredis pool (`App\Factory\RedisPoolFactory`, `redis_dsn`). Keys: `waffle.http_client.resilience.*`
  and `.breaker.*` (RFC-024 §5.3). The workspace wires the same clients.
- **Still true from the 2026-09-30 reading:** `cache` has no atomic primitive (no increment, no
  compare-and-set, no lock), so limiter and breaker state never goes through PSR-16.

## Mandates
### `[NET-01]` Token-bucket rate limiter
The contracts `Waffle\Commons\Contracts\RateLimit\RateLimiterInterface` and
`LimiterStateStorageInterface` land first. The middleware goes in `security/src/Middleware/`, keyed by
IP or authenticated subject (`Contracts\Auth\UserIdentityInterface`); an API key is limited through the
subject of the identity it authenticates (decided 2026-10-31: no per-token key). It emits `RateLimit-*`
headers and fails closed with `429` plus `Retry-After`.

- **Atomicity is the acceptance criterion.** "No over-admission beyond bucket size under concurrent
  multi-worker load" cannot hold on a PSR-16 `get()` → `set()`, because two workers read the same token
  count. The storage contract needs one atomic check-and-consume operation, e.g. a Redis Lua script.
  Wherever the Redis-backed implementation lives — using `RedisConnectionPoolInterface`, or in the
  component that already owns Redis — `security` sees only the contract. **Decided 2026-10-31:** the
  in-memory store exists only as `testing`'s `InMemoryLimiterStateStorage`, a single-process test double,
  never a production store: worker memory would break the stateless mandate.
- **Key trust.** Behind a proxy or a K8s ingress, `REMOTE_ADDR` is the proxy, so every client shares one
  bucket. Trusting `X-Forwarded-For` blindly lets a client choose its own key. The IP key therefore needs
  a trusted-proxy resolver (explicit proxy CIDR allow-list, right-most untrusted hop). **Built:**
  `Contracts\Http\ClientIpResolverInterface`, implemented by `http`'s `TrustedProxyClientIpResolver`; reuse it
  for every IP-bound check.
- **Storage outage. Decided 2026-10-17:** each limiter takes `on_storage_failure: open|closed`, default
  `open` with a warning log and a metric; `closed` is recommended on authentication endpoints, and
  authentication and authorization stay fail-closed regardless (RFC-017 §4). The chaos soak exercises it
  (`[[soak-endurance]]`).
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
  first. **Built:** `Contracts\CircuitBreaker\Event\CircuitStateChanged`, and the transitions are counted on
  `/waffle-metrics`.

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
- **Met on 2026-10-31:** `RedisLimiterConcurrencyTest` (8 processes on one 50-token bucket admit exactly 50
  of 800 calls, 4 runs of 4, while a non-atomic control store over-admits); the breaker's fault injection on
  the workspace (open 2, half_open 2, closed 1); `TimeoutPolicy` refuses any value below 1 ms or above its
  ceilings.
