---
name: refactoring
description: Safely refactor waffle-commons code, enforcing the Mago Purge Protocol and PHP 8.5 features
compatibility: opencode
---

## What I do
Execute safe refactors across Waffle components to improve structure, enforce PHP 8.5 capabilities, and rigorously eliminate technical debt according to the **Mago Purge Protocol**.

## Before touching anything
1. Establish a green baseline in Docker: `docker exec -it -w /waffle-commons/{component} waffle-dev composer test`
2. If tests are missing, load the `test` skill first.

## Refactoring rules

### The Mago Purge Protocol
- Refactoring MUST yield a 0-error exit code from Mago.
- **Zero tolerance for baselines:** Do not create or update `mago-analyzer-baseline.toml`. You must fix the underlying issues.

### PHP 8.5 Modernization
- **Strict Types:** Ensure `declare(strict_types=1);` is the first line. Eliminate all `mixed` types. Type all constants.
- **Immutability:** Convert classes to `readonly` where possible. Apply Asymmetric Visibility (`public private(set)`).
- **Validation:** Rip out legacy getters and setters. Replace them with PHP 8.5 Property Hooks.
- **Statelessness:** Purge any usage of `$_SERVER`, `$_POST`, `$_SESSION`, or `sys_get_temp_dir()`.

## Verification steps
After every refactor, inside the component's Docker scope:
```bash
docker exec -it -w /waffle-commons/{component} waffle-dev composer lint  # Mago analysis
docker exec -it -w /waffle-commons/{component} waffle-dev composer test  # PHPUnit 11
```
Both must pass flawlessly.
