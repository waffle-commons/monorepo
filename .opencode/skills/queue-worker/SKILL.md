---
name: queue-worker
description: "[Beta6 / RFC-015 boundary — NOT YET BUILT] Background processing: new waffle-commons/queue (contracts + Redis Streams driver + queue:work worker), SIGTERM drain, dead-letter, Igor-clean between messages"
compatibility: opencode
---

> **Status: planned (beta6 AXE 2). New component `waffle-commons/queue`. No code exists yet.** Scope
> is deliberately minimal — contracts + one solid driver + a worker, **not** a Messenger clone.

## What I do
I design **real background job processing** — distinct from beta5 finish-request deferral
(`[[async-concurrency]]`), which explicitly is *not* background processing. See `[[contracts-first]]`,
`[[component-scaffold]]`, `[[worker-safety]]`, `[[k8s-ops]]`.

## When to use
"queue / job / worker", "dispatch a background task", "dead-letter / retry", "queue:work", beta6 QUEUE.

## Mandates
- **QUEUE-01 — contracts:** `Waffle\Contracts\Queue\` — `MessageInterface`, `QueueDispatcherInterface`,
  `QueueConsumerInterface`, `FailedMessageStoreInterface`. Messages are strictly-typed serializable
  DTOs (**no closures, no object graphs**); the envelope carries id, attempts, available-at, and W3C
  trace context (from `[[observability]]`).
- **QUEUE-02 — Redis Streams driver + console worker:** one reference driver on Redis Streams (consumer
  groups give ack/retry for free). `bin/waffle queue:work` lives in `console/` (perimeter: contracts
  only): bounded retries, dead-letter via `FailedMessageStoreInterface`, **graceful SIGTERM drain**
  (ties into `[[k8s-ops]]` OPS-02). The worker is itself a long-running process — it **must pass `wfl
  igor` between messages** (no state bleed message-to-message).
- **QUEUE-03 — mailer scoping:** ship `Waffle\Contracts\Mailer\MailerInterface` + message DTO
  **contract only**; transactional mail is dispatched as a queue message. SMTP/API transports are
  **post-v1** (non-goal).

## Gate
Message survives a worker crash (Redis Streams pending-list reclaim); failed messages land in the
dead-letter store with the full envelope; `queue:work` drains cleanly on SIGTERM. New component
scaffolded from `component-template`. DoD: `composer mago` zero output, `composer tests` ≥95%, `wfl
igor` 0 KO.
