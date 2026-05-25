# SYSTEM DIRECTIVE: AI SKILLS INTEGRATION (CLAUDE CODE)

**Role:** You are a DevSecOps AI Tooling Architect configuring your own workspace. **Objective:** Integrate the existing OpenCode skills into your primary `CLAUDE.md` system prompt.

## CONTEXT

This monorepo project managing independent submodules contains advanced, specialized instructions located in the `.opencode/skills/` directory (e.g., `mago-purge`, `security-audit`, `diataxis-doc`, `component-scaffold`). To unlock your full potential, your root `CLAUDE.md` must be made aware of these files so you know exactly when and where to read them.

## YOUR TASK (STRICT EXECUTION)

**Step 1: Scan the Arsenal** Explore the `.opencode/skills/` directory. Read the `SKILL.md` or `.md` files present in the subdirectories to understand what each skill does.

**Step 2: Update your `CLAUDE.md`** Modify the `CLAUDE.md` file located at the root of the project. Append a new top-level section at the very bottom named exactly: `## 🧠 SPECIALIZED AI SKILLS (ROUTING DIRECTIVE)`

**Step 3: Write the Routing Logic** Under this new section, you must add a strict directive to yourself. Write something similar to this (adapt it based on what you find):

> **SELF-DIRECTIVE:** If the user requests a task that matches any of the specialized skills below, **YOU MUST READ the corresponding `SKILL.md` file BEFORE planning or taking any action.** These files contain strict, component-specific operating procedures.

**Step 4: Create the Skill Table** Generate a Markdown table in the `CLAUDE.md` file listing all the skills you discovered. The table must have 3 columns:

1. **Skill Name** (e.g., `security-audit`)
    
2. **Trigger / Description** (When should you use this skill? Summarize from your scan).
    
3. **File Path to Read** (e.g., `.opencode/skills/security-audit/SKILL.md`)
    

## RULES

- Do NOT delete or modify any existing rules in `CLAUDE.md` (like the Monorepo/Submodules constraints or the 4-step workflow). Only APPEND the new section.
    
- Do NOT modify any PHP or business logic files during this operation.
    
- Acknowledge this directive, execute the update on `CLAUDE.md`, and briefly summarize the skills you have integrated into your "brain".
---
# CLAUDE.md — System Guide for waffle-commons (PHP 8.5+)

This guide serves as the definitive reference for any LLM assistant working on the `waffle-commons` monorepo, a strict, high-performance, and fail-secure PHP 8.5 ecosystem designed for FrankenPHP resident worker mode.

## Build & Test Commands

All development and testing MUST occur inside Docker. Never run PHP natively on the host machine. The standard pattern is `docker exec -it -w /waffle-commons/{component} waffle-dev {command}`.

| Task | Command | What it does |
|------|---------|-------------|
| **Run all tests** | `docker exec -it -w /waffle-commons/{component} waffle-dev composer tests` | Runs PHPUnit 11 suite for a specific component (Target: >=95% coverage) |
| **Run specific test** | `docker exec -it -w /waffle-commons/{component} waffle-dev vendor/bin/phpunit --filter {TestName}` | Tests a single class or function |
| **Static Analysis (full)** | `docker exec -it -w /waffle-commons/{component} waffle-dev composer mago` | Runs `formatter` + `linter` + `analyzer` (Mago) in strict mode. Must yield 0-error exit code. |
| **Static Analysis (analyzer only)** | `docker exec -it -w /waffle-commons/{component} waffle-dev composer analyzer` | Runs `vendor/bin/mago analyze` alone — fastest way to gate on errors. |
| **Lint only** | `docker exec -it -w /waffle-commons/{component} waffle-dev composer linter` | Runs `vendor/bin/mago lint` alone. |
| **Fix Code Style** | `docker exec -it -w /waffle-commons/{component} waffle-dev composer formatter` | Applies automatic Mago code style fixes (`vendor/bin/mago fmt`). |
| **Install Dependencies**| `docker exec -it -w /waffle-commons/{component} waffle-dev composer install` | Installs dependencies for a specific component |

### Verify after changes
Always run this sequence inside the modified component's directory before claiming done:
```bash
docker exec -it -w /waffle-commons/{component} waffle-dev composer mago
docker exec -it -w /waffle-commons/{component} waffle-dev composer tests
```

---

## PHP 8.5 Strict Coding Standards

### Types & Validation (Mandatory)
- **Strict Types:** `declare(strict_types=1);` MUST be the first line of every PHP file.
- **No Mixed Types:** The `mixed` type is strictly forbidden without explicit architect approval.
- **Typed Constants:** Class and interface constants MUST be typed (e.g., `public const string DEFAULT_FORMAT = 'json';`).
- **Property Hooks:** Do NOT use legacy getters/setters. Enforce PHP 8.5 Property Hooks for DTO validation:
  ```php
  public string $email {
      set(string $value) {
          if (!filter_var($value, FILTER_VALIDATE_EMAIL)) throw new ValidationException('Invalid email');
          $this->email = $value;
      }
  }
  ```

### Immutability & Visibility
- Enforce **Asymmetric Visibility** (`public private(set) type $name`) and use `readonly` classes wherever possible.
  ```php
  readonly class UserDto {
      public function __construct(
          public private(set) string $id,
          public private(set) string $name,
      ) {}
  }
  ```

### Fail-Secure Error Handling
- Never silence errors with `@` or catch generic exceptions unnecessarily.
- Throw specific domain exceptions (e.g., `ValidationException`, `SecurityException`).
- Exceptions are globally intercepted and transformed by the `ErrorHandlerMiddleware`.

---

## Architecture Map & Monorepo Structure

The Waffle-Commons codebase is a monorepo where each of the 13 components is an independent submodule with its own Packagist release:
`contracts`, `waffle`, `pipeline`, `security`, `routing`, `http`, `log`, `event-dispatcher`, `container`, `config`, `utils`, `error-handler`, `runtime`.

### Component Agnosticism
- Components MUST ONLY depend on `waffle-commons/contracts`.
- Never rely on concrete implementations from other components. Everything communicates via interfaces.

### PSR Standards Enforcement
- **PSR-15:** Middleware (HTTP Handlers).
- **PSR-14:** Event Dispatcher.
- **PSR-3:** Logging.
- **PSR-7/17:** HTTP Message and Factories.

### FrankenPHP Worker Mode Readiness
The framework is designed for Resident Memory worker mode (FrankenPHP).
- **No Native Sessions:** Never use `$_SESSION` or native PHP session functions.
- **No Superglobals:** Do NOT use `$_SERVER`, `$_GET`, `$_POST`, etc. Directly use `GlobalsFactory` or PSR-7 ServerRequest objects.
- **Stateless Services:** Avoid memory leaks. Services must be entirely stateless across requests.
- **No Native Temp Dirs:** Never use `sys_get_temp_dir()`.

---

## Documentation (Diátaxis)

Documentation is a first-class citizen located in `waffle-commons/documentation/`.
We follow the **Diátaxis framework**:
1. **Tutorials:** Learning-oriented.
2. **How-to Guides:** Problem-oriented.
3. **Reference:** Information-oriented (Mention PHP 8.5 attributes like `#[Route]`, `#[Rule]` and Property Hooks here).
4. **Explanation:** Understanding-oriented.

---

## The "Mago Purge Protocol"

Any refactoring or new code must strictly adhere to the Mago Purge Protocol:
- **Zero Errors:** Mago static analysis must pass completely.
- **No Baselines:** Zero tolerance for baseline files (`mago-analyzer-baseline.toml` is not allowed). We fix errors, we do not ignore them.

---

## 🧠 SPECIALIZED AI SKILLS (ROUTING DIRECTIVE)

**SELF-DIRECTIVE:** If the user requests a task that matches any of the specialized skills below, **YOU MUST READ the corresponding `SKILL.md` file BEFORE planning or taking any action.** These files contain strict, component-specific operating procedures (Submodule Git boundaries, PHP 8.5 type rules, Mago Purge Protocol, Diátaxis quadrants, FrankenPHP statelessness, ABAC, etc.) that take precedence over general defaults.

When unsure which skill applies, default to **`tech-lead`** — it orchestrates the others.

### Skill Routing Table

| Skill Name | Trigger / Description | File Path to Read |
|------------|----------------------|-------------------|
| `tech-lead` | Entry point for non-trivial changes. Orchestrates `coding`, `refactoring`, `test`, and `code-review`; sequences work so nothing ships without passing Docker tests, Mago analysis, and architectural review. Use when the request spans multiple skills or is ambiguous. | `.opencode/skills/tech-lead/SKILL.md` |
| `coding` | Implement new features or bug fixes across the 13 components, enforcing PHP 8.5 strict types, PSR compliance, stateless FrankenPHP worker design, and the Mago Purge Protocol. Use when the user asks to add functionality, fix bugs, or implement a feature. | `.opencode/skills/coding/SKILL.md` |
| `refactoring` | Safely restructure existing code (extract methods, enforce Property Hooks, Asymmetric Visibility, `readonly`) without altering behavior. Requires a green test baseline first. Use when the user says "refactor", "clean up", "restructure", or "eliminate tech debt". | `.opencode/skills/refactoring/SKILL.md` |
| `test` | Write and run PHPUnit 11+ tests targeting >=95% coverage, with strict typing, data providers, and mocking via `contracts` interfaces only. Use when the user asks to add, fix, or improve tests/coverage. | `.opencode/skills/test/SKILL.md` |
| `code-review` | Review newly written/modified code for PHP 8.5 correctness, security, PSR compliance, and architectural fit. Monorepo/Submodule aware (per-component `git diff`). Use for "review my changes", PR feedback, or pre-merge sanity checks. | `.opencode/skills/code-review/SKILL.md` |
| `mago-purge` | Aggressively fix Mago static analysis errors — Zero Baseline policy, removal of `mixed`, enforcement of PHP 8.5 typing, Property Hooks, Asymmetric Visibility. Use when the user asks to clean up Mago errors, eliminate `mago-analyzer-baseline.toml`, or harden types. | `.opencode/skills/mago-purge/SKILL.md` |
| `security-audit` | DevSecOps audit: zero-tolerance security checks for FrankenPHP statelessness (no `$_SESSION`, no `sys_get_temp_dir()`), superglobal purge, ABAC `#[Voter]` enforcement, DTO Property Hook validation. Use for "security review", "audit", "compliance check". | `.opencode/skills/security-audit/SKILL.md` |
| `component-scaffold` | Create entirely new autonomous Waffle components (own Git repo, PSR contracts, Docker workflow, Mago config). Use when the user says "create a new component", "scaffold X", or "bootstrap a new package". | `.opencode/skills/component-scaffold/SKILL.md` |
| `diataxis-doc` | Generate Diátaxis-categorized technical documentation (tutorials, how-to, reference, explanation) under `waffle-commons/documentation/`, surfacing PHP 8.5 attributes like `#[Route]`, `#[Rule]`, `#[Voter]`. Use for "write docs", "document this component", or doc gap-filling. | `.opencode/skills/diataxis-doc/SKILL.md` |
