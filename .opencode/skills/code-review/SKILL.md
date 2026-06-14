---
name: code-review
description: Review newly written or modified code in waffle-commons for correctness, PHP 8.5 style, security, and architectural fit
compatibility: opencode
---

## What I do
Review **new or modified** code in the Waffle-Commons monorepo. Produce a concise, actionable report enforcing PHP 8.5 strict standards, security constraints, and PSR compliance.

## Scope constraint & Monorepo/Submodule Context
The `waffle-commons` codebase is a monorepo managing independent Git submodules. Each component is an autonomous Git repository released independently on Packagist.
Before taking any action or reviewing code, you must first identify the specific component you are modifying. 

**CRITICAL RULE:** To check what you have modified, you cannot run `git diff` at the root. You must enter the specific component's directory:
```bash
cd {component_dir} && git diff
```
Only review or integrate files that were created or meaningfully changed within the context of that specific component's Git repository.

## Review checklist

### Architecture & Layering
- [ ] Component only depends on `waffle-commons/contracts` (+ `waffle-commons/utils`), not concrete implementations of other components.
- [ ] Any new interface landed in `contracts` **before** its consumer (contracts-first sequencing).
- [ ] Conforms strictly to required PSR standards (PSR-15, PSR-14, PSR-3, PSR-7/17).
- [ ] Service is stateless and safe for FrankenPHP Resident Memory worker mode — `wfl igor` 0 KO; any mutable per-request state class **directly** implements `ResettableInterface` or carries `#[WorkerSafe]`.
- [ ] No native PHP sessions or `sys_get_temp_dir()` calls used.

### PHP 8.5 Standards & Types
- [ ] `declare(strict_types=1);` is present on the very first line of the file.
- [ ] No `mixed` types used.
- [ ] All constants are strictly typed.
- [ ] Property Hooks used for DTO validation instead of legacy getters/setters.
- [ ] Asymmetric Visibility (`public private(set) type $name`) and `readonly` classes used for immutability.
- [ ] No directly accessed superglobals (e.g., `$_SERVER`, `$_POST`); uses `GlobalsFactory` or PSR-7 HTTP objects.

### Security & Error Handling
- [ ] Throws specific Waffle exceptions (e.g., `ValidationException`, `SecurityException`) meant to be caught by `ErrorHandlerMiddleware`.
- [ ] No `@` error-control operators used (insecure).

### Testing & Static Analysis
- [ ] Tests use PHPUnit 12.5+ (no expectation-less-mock notices — concrete spy or `#[AllowMockObjectsWithoutExpectations]`; `tests/` is Mago-linted too).
- [ ] `composer mago` emits **zero output** — no errors, **and no warnings, info, or help/notice messages**.
- [ ] **Critical:** No `mago-*-baseline.toml` files added or modified. The "Mago Purge Protocol" mandates zero tolerance for baselines.

### Documentation
- [ ] If applicable, documentation in `waffle-commons/documentation/` is updated.
- [ ] Documentation updates respect the Diátaxis framework (Tutorials, How-to, Reference, Explanation).
- [ ] Modern PHP attributes (`#[Route]`, `#[Rule]`) and hooks are documented.

## Output format
Report findings grouped by severity:

**Blocking** — must fix before merge (type error, security issue, architectural violation, Mago baseline usage, FrankenPHP memory leak risk)  
**Important** — should fix (style violation, missing PHPUnit 12.5 test, lack of property hooks)  
**Suggestion** — optional improvement (naming, minor simplification)

If there are no findings in a category, omit it. End with a one-line verdict: `Approved`, `Approved with suggestions`, or `Changes required`.
