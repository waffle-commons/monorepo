---
name: reactive-broadcast
description: "[Beta5 / RFC-018 REACTIVE-01 — SHIPPED] #[Broadcast] write-hooks → request-scoped RequestBroadcastBuffer → finish-request BroadcastFlushListener → SSE transport; no I/O in the hook, worker-safe"
compatibility: opencode
---

## What I do
I maintain the **shipped** real-time reactive-broadcast layer (REACTIVE-01, beta5) — a `#[Broadcast]`
property attribute whose `set` write-hook records a mutation (NO I/O) into a request-scoped buffer
that a finish-request listener drains and pushes over an SSE transport. See `[[worker-safety]]`
(the buffer is the request-scoped state), `[[contracts-first]]`, `[[async-concurrency]]` (the broadcast
flush is registered BEFORE the deferred-task flush on `TerminateEvent`).

## When to use
"broadcast a property change", "real-time / SSE / Mercure push", "#[Broadcast]", "reactive mutation",
REACTIVE-01.

## Shipped surface (read these before touching anything)
- **`contracts/src/Reactive/Attribute/Broadcast.php`** — `#[Attribute(TARGET_PROPERTY)]`,
  `final readonly`, carries `string $channel`.
- **`contracts/src/Reactive/MutationRecord.php`** — `final readonly` (`channel`, `entityClass`,
  `property`, `mixed $value`); the immutable record of one mutation.
- **`contracts/src/Reactive/BroadcastBufferInterface.php`** — `extends ResettableInterface`;
  `record(MutationRecord)` (called from the hook, no I/O) + `drain(): list<MutationRecord>`.
- **`contracts/src/Reactive/BroadcastTransportInterface.php`** — `push()` / `pushBatch()`; the sink
  invoked by the flush, never from inside a write-hook.
- **`waffle/src/Reactive/RequestBroadcastBuffer.php`** — the request-scoped accumulator.
- **`waffle/src/Reactive/Sse/SseBroadcastTransport.php`** — the SSE transport.
- **`waffle/src/Event/Listener/BroadcastFlushListener.php`** — the finish-request flush.

## Invariants that MUST hold (regression guards)
- **No I/O in the set-hook:** a `#[Broadcast]` property's `set` write-hook does ONLY
  `$this->buffer?->record(new MutationRecord(...))` — never a network/disk call. The actual push
  happens later, in the finish-request flush, out of the property-assignment hot path.
- **Hooked DTO shape (PHP 8.5):** a broadcast-flagged DTO is a `final class` with
  `public private(set)` hooked properties — **NOT `final readonly`** (hooked properties cannot be
  `readonly` in PHP 8.5). Only unhooked value objects are `final readonly`.
- **Attach the buffer AFTER construction:** wire the buffer onto the DTO *after* the constructor runs,
  so the initial constructor assignment is NOT broadcast (`$this->buffer` is null during construction —
  the null-safe `?->record(...)` makes the ctor value a no-op). Only subsequent mutations broadcast.
- **Request-scoped buffer, DIRECT `ResettableInterface`:** `RequestBroadcastBuffer`
  `implements BroadcastBufferInterface, ResettableInterface` **DIRECTLY** — the shallow `wfl igor` scan
  needs the explicit clause even though `BroadcastBufferInterface` already extends it. `drain()`
  snapshots-then-clears `$records`; `reset()` empties it. The kernel resets it between requests so
  mutations never bleed across the worker loop.
- **Flush on `TerminateEvent`:** `BroadcastFlushListener` drains the buffer and `pushBatch`es after the
  response is emitted but before the kernel resets request-scoped services. Register it BEFORE the
  diagnostics listener and BEFORE the deferred-task flush (`[[async-concurrency]]`) so the cheap,
  latency-sensitive push runs first; the buffer also resets itself defensively so a skipped terminate
  never leaks mutations.
- **SSE injection defence:** `SseBroadcastTransport::frame()` interpolates the channel RAW into the
  `event:` line, so it MUST sanitize the channel first — `sanitizeChannel()` strips every CR/LF and C0
  control char (incl. NUL) via `preg_replace('/[\x00-\x1F\x7F]/', '', $channel)` so a channel cannot
  terminate the line and smuggle a second `data:`/`event:` field (SSE field/event injection). The
  payload is JSON-encoded (a value that cannot encode degrades to `{}`, never throws — the flush must
  never break teardown), so only the channel needs guarding. The sink is an injected
  `Closure(string): void` so the framing is unit-testable and an integrator can target FrankenPHP's
  native SSE output or a hub fan-out; a Mercure client, if wanted, ships as its OWN wrapper component
  (keeping the contracts perimeter dependency-free).

## Execution (in Docker)
```bash
docker exec -it -w /waffle-commons/contracts waffle-dev composer mago
docker exec -it -w /waffle-commons/waffle   waffle-dev composer mago
docker exec -it -w /waffle-commons/waffle   waffle-dev composer tests
docker exec -it -w /waffle-commons/waffle   waffle-dev composer igor   # buffer = request-scoped → 0 KO
```
Definition of done unchanged: `composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO
(`wfl dod` runs the full per-component gate).
