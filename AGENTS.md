# AGENTS.md — Waffle-Commons Central Brain

The single source of truth for **how any AI assistant must behave** in the `waffle-commons`
monorepo (PHP 8.5, FrankenPHP resident-worker, independent submodules each released to Packagist).
`/CLAUDE.md` is only a CLI router — operational standards live here.

> **Read order for every task:** this file → the matching `.opencode/skills/<skill>/SKILL.md`
> (see the Routing Table). When in doubt, start with `tech-lead`.

---

## 1. PHP 8.5 Strict Coding Standards (non-negotiable)

- **Strict types:** `declare(strict_types=1);` is the first statement of every PHP file.
- **No `mixed`:** forbidden without explicit architect approval — solve the type, never widen.
- **Typed constants:** `public const string FORMAT = 'json';`
- **Property Hooks for validation** (no legacy getters/setters):
  ```php
  public string $email {
      set(string $value) {
          if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
              throw new ValidationException('Invalid email');
          }
          $this->email = $value;
      }
  }
  ```
- **Asymmetric visibility + `readonly`** for DTOs:
  ```php
  readonly class UserDto {
      public function __construct(
          public private(set) string $id,
          public private(set) string $name,
      ) {}
  }
  ```
- **`#[\Override]`** on every method implementing/overriding an interface or parent.
- **Fail-secure errors:** never silence with `@`; never catch generic exceptions needlessly. Throw
  specific domain exceptions (`ValidationException`, `SecurityException`) — `ErrorHandlerMiddleware`
  transforms them.
- **Language:** all comments, identifiers, and emitted logs/exceptions in framework
  components are **English**. The **only** exceptions are the template-app
  directories — **`skeleton/`, `workspace/` AND `academy/`** (the last including its
  `docs/`, `labs/`, and `sandbox/` submodules) — where every comment, docblock,
  YAML/TOML/compose comment, and user-facing string is **French**. Code, namespaces,
  and contracts stay English even there (e.g. `Waffle\Academy\Labs\…`). Where an RFC
  requests French in a framework component (e.g. RFC-021 §6.3, RFC-022 §7.4), project
  policy is English outside those template dirs.

## 2. FrankenPHP Statelessness Mandate

Services must be **stateless and resettable** across requests (resident-memory worker mode):

- **No `$_SESSION`, no `session_start()`,** no native PHP session functions.
- **No superglobals** (`$_SERVER`, `$_GET`, `$_POST`, …) — use injected PSR-7
  `ServerRequestInterface` or `GlobalsFactory`.
- **No mutable static / singleton state** surviving a request; request-scoped services release on
  `$kernel->reset()` (implement `ResettableInterface` where applicable).
- **No `sys_get_temp_dir()`** or other ambient global state.

## 3. The Mago Purge Protocol (zero-baseline)

- **Zero baselines:** `mago-*-baseline.toml` files are forbidden — scan for and delete them. We fix
  errors; we never suppress them.
- **Native solution first:** resolve every `analyze`/`lint` finding with a proper PHP 8.5 type or
  refactor — not `@var` band-aids, ignore annotations, `mixed`, or baselines.
- **Guard perimeter (`mago guard`):** no circular dependencies, no illegal cross-component imports.
  **Every component depends ONLY on `waffle-commons/contracts`** — never a sibling's concrete classes.
- **Done = green:** `composer mago && composer tests` (≥95% coverage) pass for every modified
  component, in Docker.

## 4. Architecture & PSR

- **Monorepo of submodules** — each its own Git repo / Packagist release: `contracts`, `waffle`,
  `pipeline`, `security`, `auth`, `routing`, `http`, `http-client`, `log`, `event-dispatcher`,
  `container`, `config`, `cache`, `console`, `data`, `utils`, `error-handler`, `runtime`
  (+ `skeleton`, `workspace`, `documentation`, `component-template`).
- **PSR enforcement:** PSR-15 middleware, PSR-14 events, PSR-3 logging, PSR-7/17 HTTP messages &
  factories, PSR-18 HTTP client.
- **Documentation (Diátaxis):** lives in `documentation/` — `tutorials/`, `how-to/`, `reference/`,
  `explanation/`. See the `diataxis-doc` skill.

---

## 🧠 Specialized AI Skills — Routing Table

**SELF-DIRECTIVE:** if a request matches a skill below, **READ that `SKILL.md` BEFORE planning or
acting**. These files carry component-specific operating procedures that override general defaults.
When unsure, default to **`tech-lead`** (it orchestrates the others).

| Skill | Trigger / Use when… | File |
|-------|---------------------|------|
| `tech-lead` | Entry point for non-trivial / multi-skill / ambiguous work; sequences coding→test→review. | `.opencode/skills/tech-lead/SKILL.md` |
| `coding` | Implement a feature or bug fix across the components. | `.opencode/skills/coding/SKILL.md` |
| `refactoring` | "Refactor / clean up / restructure" — needs a green test baseline first. | `.opencode/skills/refactoring/SKILL.md` |
| `test` | Add/improve PHPUnit tests; target ≥95% coverage. | `.opencode/skills/test/SKILL.md` |
| `code-review` | "Review my changes" / pre-merge sanity (per-component diff). | `.opencode/skills/code-review/SKILL.md` |
| `mago-purge` | Fix Mago findings; eradicate baselines; harden types (native-first). | `.opencode/skills/mago-purge/SKILL.md` |
| `security-audit` | Security/compliance: statelessness, fail-closed ABAC, SSRF, HMAC, `#[PublicAccess]`. | `.opencode/skills/security-audit/SKILL.md` |
| `component-scaffold` | "Create a new component / bootstrap a package." | `.opencode/skills/component-scaffold/SKILL.md` |
| `diataxis-doc` | "Write/document" → Diátaxis docs with exact PHP 8.5 signatures. | `.opencode/skills/diataxis-doc/SKILL.md` |
| `release-manager` | Independent component releases on Packagist. | `.opencode/skills/release-manager/SKILL.md` |
| `maker-scaffold` | "Scaffold / make a controller, DTO, middleware, voter, command, HTTP client, event pair" via Waffle Maker (RFC-020). | `.opencode/skills/maker-scaffold/SKILL.md` |
| `auth-bridge-audit` | Audit the Universal Authentication Bridge (RFC-021, `auth` component): JWT, OAuth2/OIDC, HMAC assertions, API keys — fail-closed, stateless. | `.opencode/skills/auth-bridge-audit/SKILL.md` |
| `data-persistence` | Design the Universal Data & Persistence Layer (RFC-022): SQR, stateless pools, Firestore paths, atomic flat-file. | `.opencode/skills/data-persistence/SKILL.md` |
