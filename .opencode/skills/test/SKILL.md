---
name: test
description: Write and run PHPUnit 12.5 tests for waffle-commons targeting >=95% coverage
compatibility: opencode
---

## What I do
Write well-structured PHPUnit 12.5+ tests for `waffle-commons` components and verify they pass, enforcing strict code coverage targets (>=95%) and stateless testing.

## Test architecture
- **Location** — Tests live in the `tests/` directory of each specific component (e.g., `waffle-commons/security/tests/`). `tests/` is **also** Mago-linted/analyzed, so test code obeys the same zero-output bar.
- **PHPUnit 12.5** — Use native PHPUnit 12.5 features, strict typing (`declare(strict_types=1);`), and proper data providers.
- **Mocking** — Mock any interface dependency coming from `waffle-commons/contracts`. Do not instantiate concrete classes from other components.
- **PHPUnit 12.5 mock notices** — expectation-less mocks (intersection mocks, unused `setUp` mocks) trigger `OK, but there were issues!`. Use a concrete spy/fake, or annotate with `#[AllowMockObjectsWithoutExpectations]`. A spy that asserts via captured state beats a bare mock.

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
