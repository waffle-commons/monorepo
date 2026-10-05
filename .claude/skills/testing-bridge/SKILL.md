---
name: testing-bridge
description: "WaffleTestCase in-process kernel + test doubles in testing (beta7 TEST-01; scaffolded, no src)"
when_to_use: >-
  WaffleTestCase, booting the kernel in a test, simulating a PSR-7 request through the real
  pipeline, in-memory queue / mailer / HTTP test doubles, freezing the clock, [TEST-01], RFC-018
  section 3.3.
---

> **Status (2026-09-30):** `testing` (`Waffle\Commons\Testing`) is scaffolded and its DoD is green in
> scaffold mode; there is no `src/` yet. Committed tier. Userland installs it as `require-dev`. Its first
> consumers are EcoShield Gateway and the Academy labs.

## What I do
I design the kernel testing bridge that lets app developers test against the real pipeline without a
web server. See `[[test]]`, `[[contracts-first]]`, `[[queue-worker]]`, `[[ecoshield]]`.

## When to use
"WaffleTestCase", "boot the kernel in a test", "simulate a request", "in-memory queue / mailer / HTTP
test double", "freeze the clock", beta7 TEST-01.

## Perimeter first (`[CARRY-04]` — decide before the first class)
- **Kernel factory seam.** `WaffleTestCase` must boot an application's kernel without importing a
  sibling's concrete classes. contracts has `Core\KernelInterface` and `Core\TerminableInterface` but **no
  kernel factory seam** — each app builds its kernel in its own `AppKernelFactory`. Add the seam (for
  example an app-provided factory interface) to contracts first, or record the exception.
- **Clock.** contracts has no clock (no PSR-20 `ClockInterface`), and the time double needs one. Adopt
  PSR-20 or add a contract, contracts-first.
- **PHPUnit at runtime.** `testing` extends PHPUnit's `TestCase`, so its `mago.toml` guard must permit
  `PHPUnit\**` alongside contracts and utils.

## Mandates
- **`[TEST-01]` `WaffleTestCase`:** boots in-process, dispatches simulated PSR-7 requests through the
  **real** PSR-15 pipeline (no web server, no network) and returns typed responses for assertion.
- **Doubles implement the production contracts:**
  - time — a frozen, advanceable clock;
  - queue — `InMemoryQueue`, recording dispatched messages (`[[queue-worker]]`);
  - mailer — a spy on the mailer contract;
  - HTTP client — record/replay, never a live call from a test.
- **Stateless between tests.** Reset the kernel per test exactly as the worker resets per request (or
  boot a fresh one). The bridge must never become a source of cross-test state bleed; the igor mindset
  applies to its own classes.
- **PHPUnit 12.5 rules** from `[[test]]` apply to the bridge and to what it generates: no
  expectation-less mocks.

## Gate
- A controller test boots, dispatches and asserts a typed response with no network.
- The doubles record their effects and let tests assert them.
- A test can send the same request twice and observe no leaked state.
- DoD: `wfl dod testing` (plus contracts). Verify with `acceptance-verifier` (scope `TEST`).
