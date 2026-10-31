---
name: queue-worker
description: "Background jobs in queue: contracts, Redis Streams driver, dead letters, queue:work + SIGTERM drain (beta7 QUEUE)"
when_to_use: >-
  Queue, job or worker, dispatching a background task, dead-letter and retry, queue:work, SIGTERM
  drain, sending mail asynchronously (mailer contract), [QUEUE-01..03].
---

> **Status (2026-09-30):** `queue` (`Waffle\Commons\Queue`) is scaffolded from `component-template`
> and passes its DoD in scaffold mode. There is no PHP in `src/` yet; tests and coverage switch on
> with the first class. Scope is deliberately minimal — contracts, one solid driver and a worker, **not**
> a Messenger clone. RFC-015 holds the boundary with the beta5 deferral.

## What I do
I design real background job processing. It is distinct from beta5 finish-request deferral
(`[[async-concurrency]]`), which runs after the response inside the same request and is explicitly not
a queue. See `[[contracts-first]]`, `[[worker-safety]]`, `[[k8s-ops]]`, `[[observability]]`,
`[[testing-bridge]]`.

## When to use
"queue / job / worker", "dispatch a background task", "dead-letter / retry", "queue:work", "send mail
asynchronously", beta7 QUEUE.

## Mandates
### `[QUEUE-01]` Contracts
`Waffle\Commons\Contracts\Queue\`: `MessageInterface`, `QueueDispatcherInterface`,
`QueueConsumerInterface`, `FailedMessageStoreInterface`.

- **Messages** are strictly-typed serializable DTOs: no closures, no object graphs.
- **The envelope** carries id, attempts, available-at and W3C trace context, injected and extracted
  through the shipped `Telemetry\TextMapPropagatorInterface`.
- **Payload safety:** encode as JSON, and decode only into an **allow-listed** message class, through
  its constructor and property hooks so validation runs. **Never `unserialize()` a payload** — a queue is
  an input channel (A08), and it is on the beta8 audit list.

### `[QUEUE-02]` Redis Streams driver + worker
One reference driver on Redis Streams; additional drivers are post-v1.

- **Consumer groups:** `XADD`, `XREADGROUP`, `XACK`, and pending-list reclaim with `XAUTOCLAIM`. That
  needs Redis ≥ 6.2; the workspace runs `redis:7-alpine`, and `ext-redis` is in the dev image.
- **`bin/waffle queue:work`** lives in `console/` and depends only on contracts; the concrete driver is
  wired in `bin/waffle`, the established command perimeter. Retries are bounded; after the last one the
  message goes to the dead-letter store with its full envelope.
- **SIGTERM drain through `pcntl`.** Since 2026-09-30 `pcntl` is in the development image
  (`waffle-dev`), the skeleton `base` stage (hence its prod image) and the bench engine; a SIGTERM
  handler was verified to fire in both images' PHP (8.5.11 ZTS). Pattern: `pcntl_async_signals(true)`
  plus a handler that sets a stop flag; the worker finishes and acks the in-flight message, then exits
  within the grace period (`[[k8s-ops]]` `[OPS-02]`, RFC-023 §3.4).
- **Reset between messages.** The worker is a long-running process, so it resets between messages
  exactly as the HTTP worker resets between requests:
  - reset the container's resettable services after **every** message, in a `finally` — the equivalent
    of `$kernel->reset()` in `WaffleRuntime`;
  - recycle the process on a max-messages or memory ceiling;
  - `wfl igor` 0 KO on every class it runs.
- **Do not copy the one-shot commands' `#[WorkerSafe]` reason.** "CLI-only: constructed per
  `bin/waffle` invocation" is **false** for `queue:work`, where one invocation handles thousands of
  messages.

### `[QUEUE-03]` Mailer scoping
`Waffle\Commons\Contracts\Mailer\MailerInterface` plus a message DTO — a **contract only**.
Transactional mail is dispatched as a queue message. SMTP and API transports are post-v1 (a non-goal
in the master roadmap).

## Gate
- A message survives a worker crash: kill the worker mid-message, and the pending entry is reclaimed
  and processed again. Handlers must be idempotent or de-duplicate on the message id.
- Failed messages land in the dead-letter store with the full envelope (id, attempts, error, trace
  context).
- `queue:work` drains cleanly on SIGTERM: the in-flight message is finished and acked, nothing is lost,
  and the process exits 0.
- `[TEST-01]`'s `InMemoryQueue` double implements the same contracts.
- DoD: `wfl dod queue`, `wfl dod console` and `wfl dod contracts` (mago zero output, tests ≥95 %, igor
  0 KO). Verify with `acceptance-verifier` (scope `QUEUE`).
