---
name: coding
description: Implement features and bug fixes in the waffle-commons PHP 8.5 monorepo following strict component conventions
compatibility: opencode
---

## What I do
Guide the implementation of new features and bug fixes across the 13 independent `waffle-commons` components. I enforce strict PHP 8.5 types, PSR compliance, stateless resident worker architecture (FrankenPHP), and the Mago Purge Protocol. For complex tasks, I orchestrate parallel `coding-worker` subagents and dispatch a `coding-integrator`.

## Scope constraint & Monorepo/Submodule Context
The `waffle-commons` codebase is a monorepo managing independent Git submodules. Each component is an autonomous Git repository released independently on Packagist.
Before taking any action or reviewing code, you must first identify the specific component you are modifying. 

**CRITICAL RULE:** To check what you have modified, you cannot run `git diff` at the root. You must enter the specific component's directory:
```bash
cd {component_dir} && git diff
```
Only review or integrate files that were created or meaningfully changed within the context of that specific component's Git repository.

## Complexity assessment — simple vs parallel

Treat a task as **simple** (implement directly) when it touches a single component or is a small, self-contained change (e.g., one new middleware, one routing rule, one DTO).

Treat a task as **complex** (parallelise) when:
- It spans multiple independent components (e.g., `routing` + `http` + `security`).
- It requires creating 4+ new files across interfaces, implementations, and tests.

## Workflow — simple task

1. **Understand before writing** — read the relevant interfaces in `contracts`. Components must ONLY depend on `waffle-commons/contracts`, never on concrete implementations of other components.
2. **Follow PSR Standards** — PSR-15 for middleware, PSR-14 for events, PSR-7/17 for HTTP.
3. **Immutability & State** — All classes should be `readonly` when possible. Use Asymmetric Visibility (`public private(set) type $name`). Make sure services are entirely stateless to avoid memory leaks in FrankenPHP worker mode.
4. **Validation** — Use PHP 8.5 Property Hooks (`set(string $value) { ... }`) instead of legacy getters/setters.
5. **Types** — Always start with `declare(strict_types=1);`. No `mixed` types. Typed constants everywhere.
6. **Error Handling** — Never silence errors. Throw specific exceptions (e.g., `ValidationException`) to be intercepted by `error-handler`. No native `$_SESSION` or `sys_get_temp_dir()`.
7. **After writing** — load the `test` skill, then load `code-review`. Verify with `docker exec -it -w /waffle-commons/{component} waffle-dev composer lint`.

## Workflow — complex task (parallel workers)

### Step 1 — Decompose
Break the task by component. Each slice must map to a specific Waffle component (e.g., Worker A handles `contracts`, Worker B handles `http`, Worker C handles `security`).

### Step 2 — Define shared interfaces
Define the interfaces in the `contracts` component first. Every worker must honour these strictly typed PSR-compliant contracts.

### Step 3 — Spawn workers in parallel
Dispatch `coding-worker` subagents simultaneously, instructing them: *"Do not touch files outside your assigned component. Output a handoff summary."*

### Step 4 & 5 — Collect & Integrate
Dispatch a single `coding-integrator` with all handoff summaries. The integrator wires everything together and runs `composer lint` and `composer test` inside the Docker container for each modified component.

### Step 6 — Verification
Load `test` to fill gaps, then `code-review`.
