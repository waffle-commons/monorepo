---
name: testing-bridge
description: "[Beta6 / RFC-012 — NOT YET BUILT] New waffle-commons/testing: WaffleTestCase that boots the kernel in-process and dispatches simulated PSR-7 requests, plus time/queue/mailer/http test doubles"
compatibility: opencode
---

> **Status: planned (beta6 AXE 5). New component `waffle-commons/testing`. No code exists yet.**
> Dev-only (`require-dev` in userland).

## What I do
I design the **kernel testing bridge** that lets app developers test against the real pipeline without
a web server. EcoShield-Gateway and the Academy labs are the first consumers. See `[[test]]`,
`[[contracts-first]]`, `[[component-scaffold]]`.

## When to use
"WaffleTestCase", "boot the kernel in a test", "simulate a request", "in-memory queue/mailer/http test
double", beta6 TEST-01.

## Mandates
- **TEST-01 — `WaffleTestCase`:** boots the kernel **in-process**, dispatches simulated PSR-7 requests
  through the **real** PSR-15 pipeline (no web server), and returns typed responses for assertion.
- **Test doubles:** for time, queue (`InMemoryQueue` asserting dispatched messages —
  `[[queue-worker]]`), the mailer contract, and the HTTP client (record/replay). Doubles implement the
  same `contracts` interfaces as production — the perimeter holds.
- **Stateless between tests:** the bridge resets the kernel per test exactly as the worker resets per
  request — it must not become a source of cross-test state bleed (`wfl igor` mindset applies to the
  helper itself).

## Gate
A controller test boots → dispatches → asserts a typed response with no network; doubles record and
assert dispatched effects. New component scaffolded from `component-template`. DoD: `composer mago`
zero output, `composer tests` ≥95% (PHPUnit 12.5 — honor the expectation-less-mock rule from
`[[test]]`), `wfl igor` 0 KO.
