---
name: async-concurrency
description: "[Beta5 / RFC-015 — SHIPPED] Fiber finish-request deferral (waffle-commons/async) + concurrent HTTP-client promise fan-out, both worker-safe and bounded"
compatibility: opencode
---

## What I do
I maintain the **shipped** cooperative-concurrency layer (RFC-015, beta5 AXE 2) for FrankenPHP worker
mode — native PHP Fibers as an *isolation boundary*, not multithreading and not background processing
(that is `[[queue-worker]]`, beta6). See `[[contracts-first]]`, `[[benchmark-gate]]`,
`[[worker-safety]]`.

## When to use
"defer post-response work", "Fibers", "concurrent / parallel HTTP requests", "Promise", "deferral
budget", ASYNC-01/02.

## Shipped surface (read these before touching anything)
- **`contracts/src/Async/DeferredTaskInterface.php`** — `run()` + `name()`; a self-contained, bounded
  unit of post-response work (mail, webhooks, audit writes).
- **`contracts/src/Async/TaskRunnerInterface.php`** — `extends ResettableInterface`; `defer()` /
  `run()` / `pending()`. Request-scoped: the kernel clears the queue between requests.
- **`async/src/DeferredTaskRunner.php`** (ASYNC-01) — the NEW `waffle-commons/async` component.
- **`waffle/src/Event/Listener/DeferredTaskFlushListener.php`** — drains the queue on
  `TerminateEvent` (after the response is flushed, before the kernel resets request-scoped services).
- **`http-client/src/Client.php`** `sendRequests()` / `promise()` + **`http-client/src/Promise/Promise.php`**
  (ASYNC-02) — concurrent fan-out and the non-blocking promise.

## Invariants that MUST hold (regression guards)
- **Finish-request semantics (ASYNC-01):** deferred work runs AFTER the response is flushed and
  BEFORE the worker accepts the next request — it trades worker throughput for perceived latency.
  Fibers are cooperative within one thread, NOT background threads.
- **Bounded budget:** `DeferredTaskRunner` enforces a hard per-request ceiling (`DEFAULT_BUDGET = 64`);
  `defer()` throws `DeferralBudgetExceededException` past it (the "move this to a real queue" signal),
  and a budget `< 1` is refused eagerly at construction (`InvalidBudgetException`).
- **Abandoned-Fiber isolation:** `runOne()` runs each task in its own `Fiber` inside a `try`; a
  finish-request model has no scheduler, so it resumes a single suspension point and, if the Fiber is
  still suspended, logs a warning and abandons it. **The `unset($fiber)` MUST stay inside the `try`** —
  forcing the still-suspended Fiber's destruction there keeps any throwing destructor/`finally` inside
  the `catch`, so it is logged and contained instead of detonating as an uncaught fatal that aborts
  sibling tasks. `run()` snapshots-then-clears `$pending` so a task that defers another task does not
  grow the queue being drained. Do not move the `unset` after the `catch`.
- **Listener defence:** `DeferredTaskFlushListener` wraps the whole drain in a catch-all and logs +
  swallows — terminate runs after the response, so a throwable here must never break finish-request
  teardown. It lives in the kernel package (not `waffle-commons/async`) so the runner stays
  contracts-only and never imports the concrete `TerminateEvent`. Register it AFTER the broadcast
  flush (`[[reactive-broadcast]]`) — deferred work may outlast the latency-sensitive real-time push.
- **Concurrent fan-out (ASYNC-02):** `Client::sendRequests()` allocates ONE dedicated easy handle per
  request, registers them on a single multi handle, and drives one shared `curl_multi_exec()` loop, so
  N requests settle in roughly the wall-clock of the slowest; array keys are preserved 1:1. It reads
  each transfer's terminal result straight off the handle via `curl_errno()`/`curl_error()` — **no
  `curl_multi_info_read()` drain** (avoiding its mixed-typed by-ref out-param, POLICY-05). It is
  fail-fast: any transport/protocol/SSRF failure throws that request's mapped exception (partial
  results are never silently returned). A non-OK `CURLM_*` loop status is surfaced against the first
  request as a `NetworkException` (ASYNC02-01) rather than read as success.
- **Busy-spin guard (ASYNC02-05):** `drive()` parks on `curl_multi_select()`; when it returns `-1`
  (no fds yet) the loop `usleep()`s a small fixed back-off so it cannot pin a CPU at 100%.
- **Promise lifecycle:** `Promise` holds none of the cURL machinery — only settle state + callbacks
  behind injected `$resolver`/`$cleanup` closures. `wait()` runs the resolver exactly once (outcome
  cached, state transitions terminally once); `then()`/`catch()` are settle notifications returning
  nothing (no `mixed` propagates). `$cleanup` runs at most once — on settle, or from `__destruct()`
  if `wait()` is never called — so an un-waited promise never leaks handles (ASYNC02-04). The
  per-request `Promise` is marked `#[WorkerSafe(scope: 'per-request', …)]`: its single settle mutation
  is intentional and transient, never resident state.
- **SSRF composition:** the fan-out and promise paths both run the default-on SSRF guard (SEC-02,
  `[[resilience-net]]`) BEFORE allocating a handle — fail-closed, no socket opened on a bad host.

## Gate
- **ASYNC-01:** the spike's worker-throughput regression measurement is the go/no-go record
  (`[[benchmark-gate]]`); the deferral budget is the production safety valve.
- **ASYNC-02:** N parallel requests complete in ≈ the wall-clock of the slowest single request
  (bounded overhead).
- Statelessness: `wfl igor` clean across worker iterations (no leaked Fiber/promise state).
  Definition of done unchanged: `composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO
  (`wfl dod` runs the full per-component gate).
