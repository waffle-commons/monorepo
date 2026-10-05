---
name: test
description: "Write and run PHPUnit 12.5 tests in one component to >=95% coverage with a clean OK verdict"
when_to_use: >-
  Adding or improving PHPUnit tests, coverage below 95% (wfl coverage:gaps), "OK, but there were
  issues!", mock notices, flaky or stateful tests, data providers.
argument-hint: "[component]"
---

## What I do
Write well-structured PHPUnit 12.5+ tests for `waffle-commons` components and verify they pass, enforcing strict code coverage targets (>=95%) and stateless testing.

## Test architecture
- **Location** — Tests live in the `tests/` directory of each specific component (e.g., `waffle-commons/security/tests/`). `tests/` is **also** Mago-linted/analyzed, so test code obeys the same zero-output bar.
- **PHPUnit 12.5** — Use native PHPUnit 12.5 features, strict typing (`declare(strict_types=1);`), and proper data providers.
- **Mocking** — Mock any interface dependency coming from `waffle-commons/contracts`. Do not instantiate concrete classes from other components.
- **PHPUnit 12.5 mock notices** — expectation-less mocks (intersection mocks, unused `setUp` mocks) trigger `OK, but there were issues!`. Use a concrete spy/fake, or annotate with `#[AllowMockObjectsWithoutExpectations]`. A spy that asserts via captured state beats a bare mock. The gates enforce it: `wfl dod` and `wfl check:all --with-tests` reject any run that does not end with a clean `OK (…)` (issues, skipped, incomplete or risky tests), even when PHPUnit exits 0. See the details with `vendor/bin/phpunit --no-coverage --display-all-issues`.

## Execution

All tests must be run via the standard Docker dev container:
```bash
docker exec -it -w /waffle-commons/{component} waffle-dev composer tests
# Or specifically:
docker exec -it -w /waffle-commons/{component} waffle-dev vendor/bin/phpunit --filter {TestName}
# Coverage gate (enforces the ≥95% bar and reports the per-class shortfall):
wfl coverage {component}
```

## Testing rules

- **Stateless Verification** — Ensure components do not leak state (critical for FrankenPHP worker mode).
- **Strict Exceptions** — Use `$this->expectException()` to test fail-secure paths.
- **No Native Dependencies** — Never rely on native `$_SESSION` state in tests. Use mocked `GlobalsFactory` or PSR-7 ServerRequests.
- **Target Coverage** — Refuse to consider testing complete if the coverage for the new/modified component classes is below 95%.

## Beta7 test patterns
- **Concurrency is not a unit test.** A rate limiter's "no over-admission" needs several processes
  against a real Redis, or k6 against a multi-worker FrankenPHP; a single-process test proves nothing
  about atomicity (`resilience-net`).
- **State machines with an injected clock.** A circuit breaker's open, half-open and closed transitions
  are tested by advancing a fake clock, never by sleeping.
- **SQL dialect matrix.** `pdo_mysql`, `pdo_pgsql` and `pdo_sqlite` are in `waffle-dev`, so migration
  round-trips run there against MySQL/MariaDB, PostgreSQL and SQLite (`k8s-ops`).
- **Crash and reclaim.** Queue tests kill a consumer mid-message and assert the reclaim and the
  dead-letter envelope (`queue-worker`).
- **No live network.** Outbound calls go through a record/replay double; once `waffle-commons/testing`
  ships, prefer `WaffleTestCase` for controller-level tests (`testing-bridge`).
