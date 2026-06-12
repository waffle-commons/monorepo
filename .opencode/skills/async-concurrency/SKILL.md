---
name: async-concurrency
description: "[Beta5 / RFC-015 — RESEARCH SPIKE / NOT YET BUILT] Fiber-based finish-request deferral + concurrent HTTP-client promise pool, with a worker-throughput gate"
compatibility: opencode
---

> **Status: research spike + planned (beta5 AXE 2, RFC-015). No code exists yet.** `[ASYNC-01]` is a
> go/no-go spike; `[ASYNC-02]` is the next-tier promise pool. Do not treat as background processing —
> that is `[[queue-worker]]` (beta6).

## What I do
I design **cooperative concurrency** for FrankenPHP worker mode using native PHP Fibers — without
pretending it is multithreading. See `[[contracts-first]]`, `[[benchmark-gate]]`, `[[worker-safety]]`.

## When to use
"defer post-response work", "Fibers", "concurrent / parallel HTTP requests", "Promise", beta5 ASYNC.

## Mandates
- **ASYNC-01 — Fiber deferred runner (`waffle-commons/async`, `Waffle\Commons\Async`):** finish-request
  semantics — deferred work runs **after the response is flushed, before the worker accepts the next
  request**. Fibers are cooperative within one thread, **not** background threads. Enforce a bounded
  per-request deferral budget; when exceeded, surface an explicit "move this to a real queue"
  recommendation. It trades worker throughput for perceived latency.
- **ASYNC-02 — Concurrent HTTP client promises:** a `PromiseInterface` lands in `contracts` first; the
  concrete `Waffle\Commons\HttpClient\Promise\Promise` wraps multi-cURL / a Fiber scheduler so an array
  of outgoing requests resolves in parallel into consolidated typed responses. Composes with the
  default-on SSRF guard (`[[resilience-net]]`, SEC-02).

## Gate
- **ASYNC-01:** spike deliverable = prototype + load-test report **quantifying the worker-throughput
  regression**; go/no-go before it becomes a committed item.
- **ASYNC-02:** N parallel requests complete in ≈ the wall-clock of the slowest single request
  (bounded overhead).
- Statelessness: `wfl igor` clean across worker iterations (no leaked Fiber/promise state).
