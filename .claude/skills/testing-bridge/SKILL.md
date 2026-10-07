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

## Perimeter (`[CARRY-04]`, decided 2026-10-07)
The record is in `Roadmap_Beta7.md`.
- **Kernel: the container is on the contract.** `KernelInterface` declares
  `public ContainerInterface $container { get; }`. There is no kernel-factory contract: `WaffleTestCase`
  gets the kernel from an abstract `createKernel()` that the app implements in one line (for example by
  calling its `AppKernelFactory::create()` with `Constant::ENV_TEST`). It swaps the doubles in with
  `$kernel->container->set()` between `boot()` and `configure()`, before the container locks. A double
  reaches what the container resolves (controllers and their dependencies), not a collaborator that the
  app factory builds up front.
- **Requests:** the bridge builds them with the PSR-17 `ServerRequestFactoryInterface` from the container,
  never with `http`'s concrete classes. The app factory registers it; the template apps do not yet.
- **Clock: PSR-20.** contracts requires `psr/clock`. The frozen, advanceable clock lives here; the system
  clock lives in `utils` (not built yet).
- **PHPUnit at runtime.** `testing` requires `phpunit/phpunit` ^12.5. Its `mago.toml` guard permits
  `PHPUnit\**` in one sub-namespace only (the `WaffleTestCase` layer), so the kernel client and the
  doubles stay free of PHPUnit.

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
