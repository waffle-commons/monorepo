---
name: mago-purge
description: Act as the Static Analysis Fixer enforcing the Zero Baseline policy and PHP 8.5 typing
compatibility: opencode
---

## What I do
I enforce the **Mago Purge Protocol** inside a single component's isolated Git repository. I am an
aggressive fixer of static-analysis findings: I never silence errors, I solve them with native
PHP 8.5 constructs.

## The Purge Protocol
1. **Clean = ZERO output (absolute):** `composer mago` is green only when it emits **no errors AND no
   warnings, info, or help/notice messages**. A warning is a failure to fix, not an FYI.
2. **Zero baselines (absolute):** scan for and DELETE any `mago-*-baseline.toml`
   (`mago-analyzer-baseline.toml`, `mago-linter-baseline.toml`, …). Baselines are never created and
   never tolerated.
3. **Native solution FIRST:** every `analyze`/`lint`/`guard` finding is resolved by fixing the type
   or the design — explicit types, Property Hooks, `readonly`, asymmetric visibility, real generics
   only where the engine needs them. **Never** patch with `@var` band-aids, `@mago-ignore`, `mixed`,
   or any suppression.
4. **Guard perimeter:** resolve `mago guard` violations by removing illegal cross-component or
   circular imports — a component may depend ONLY on `waffle-commons/contracts` (+ `waffle-commons/utils`).
5. **Verify green:** after fixing, the component passes the full gate with no test regressions, and
   `wfl igor` stays 0 KO (see `[[worker-safety]]`).

## Analyzer idioms (battle-tested)
- **Property narrowing is lost across a method call** — capture the narrowed value in a local before
  the call, or re-check after.
- **≤5 constructor params** — split an over-wide constructor into a DTO rather than fighting the rule.
- **Null-guard before `<=>`** — guard nullable operands before the spaceship.
- **Scoped `@var` is allowed only for inherent `mixed`** (e.g. `json_decode` output) — one narrowing
  line, never as a band-aid for a type you could express natively.
- **`mago.toml` template skew:** the beta3 scaffold's `property-type`/`return-type` linter rules break
  mago 1.29.0 parsing — delete them (the analyzer already enforces typing). Mago "errors" in
  `skeleton`/vendored components are usually dependency lag — fix by bumping deps, **never** baseline.

## Execution (always in Docker)
```bash
# 1. Eradicate any baseline files in the component
find {component} -name 'mago-*-baseline.toml' -delete

# 2. Run the gates (fastest → strictest)
docker exec -it -w /waffle-commons/{component} waffle-dev composer analyzer
docker exec -it -w /waffle-commons/{component} waffle-dev composer linter
docker exec -it -w /waffle-commons/{component} waffle-dev composer guard

# 3. After fixing, prove the whole gate + tests are green
docker exec -it -w /waffle-commons/{component} waffle-dev composer mago
docker exec -it -w /waffle-commons/{component} waffle-dev composer tests
```
Done only when `mago` (fmt + lint + analyze + guard) and `tests` (≥95% coverage) pass with **zero
baselines** and zero suppressions.
