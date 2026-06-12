---
name: resilience-net
description: "[Beta6 / RFC-017 — NOT YET BUILT] Traffic protection & outbound resilience: token-bucket rate limiter, retry/backoff+jitter, circuit breaker; state in shared storage, never worker memory"
compatibility: opencode
---

> **Status: planned (beta6 AXE 1, RFC-017). No code exists yet.** Hard prerequisite for
> EcoShield-Gateway.

## What I do
I design the inbound rate protection and outbound resilience an API ecosystem needs to survive load and
flaky upstreams — all stateless, with shared-storage state so it is correct across workers. See
`[[contracts-first]]`, `[[worker-safety]]`, `[[observability]]`.

## When to use
"rate limit / throttle", "429 / Retry-After", "retry with backoff", "circuit breaker", beta6 NET.

## Mandates
- **NET-01 — Token-bucket rate limiter:** `Waffle\Contracts\RateLimit\RateLimiterInterface` +
  `LimiterStateStorageInterface` in `contracts` first. Implement as a `security/` middleware keyed by
  IP / authenticated subject (`UserIdentityInterface`) / API token. Storage via the existing **cache
  contracts** (Redis for multi-worker correctness; in-memory fallback documented single-worker only).
  Emit `RateLimit-*` headers; fail-closed `429` with `Retry-After`. **Limiter state lives only in the
  storage backend, never in worker memory** — `wfl igor` 0 KO.
- **NET-02 — HTTP client resilience policies:** extend `http-client` with **immutable DTO** policies
  (config, not code): mandatory connect/total timeouts (**no infinite timeouts anywhere**), bounded
  retry with exponential backoff + jitter, idempotency awareness (never auto-retry non-idempotent
  methods unless explicitly opted in). Compose with SEC-02: **resolve → validate → pin runs on every
  retry hop**.
- **NET-03 — Circuit breaker:** closed/open/half-open around outbound calls, failure-rate thresholds +
  cool-down. State through the same `LimiterStateStorageInterface` family (Redis, shared) — never
  in-process. Expose transitions as kernel-lifecycle events and as `/waffle-metrics` gauges.

## Gate
Limiter correct under concurrent multi-worker load (no over-admission beyond bucket size); breaker
opens/half-opens per thresholds under fault injection; **zero infinite timeouts possible by
construction**. DoD: `composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO.
