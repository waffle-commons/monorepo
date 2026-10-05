# Reference — `AGENTS.md` (the central brain)

> **Release:** `0.1.0-beta7`.
> **Scope:** `<umbrella>/AGENTS.md`.
> **Purpose:** the single source of truth for how any AI assistant must behave in the monorepo — the binding operating standards that [`CLAUDE.md`](claude-md.md) imports into every Claude Code session.

## What it is

A single file at the umbrella root that carries the project's **non-negotiable operating standards** for AI assistants (and, in effect, the contributor handbook for humans). [`CLAUDE.md`](claude-md.md) imports it with `@AGENTS.md`, so it is in context in every Claude Code session, and adds only the Claude Code specifics. `AGENTS.md` holds the actual rules: PHP 8.5 coding standards, the FrankenPHP statelessness mandate, the Mago Purge Protocol, the worker-safety gate, the release train, git safety, evidence, and the skills / subagents / plugins layer.

> **For every task:** `AGENTS.md` (always in context) → the matching skill in `.claude/skills/`. When in doubt, start with `tech-lead`.

## Sections

| Section | Codifies |
| :--- | :--- |
| **1. PHP 8.5 Strict Coding Standards** | `declare(strict_types=1)`, no `mixed`, typed constants, Property Hooks for validation, asymmetric visibility + `readonly` DTOs, `#[\Override]`, fail-secure errors, and the language policy (English everywhere except the `skeleton/`, `workspace/`, and `academy/` template dirs, which are French). |
| **2. FrankenPHP Statelessness Mandate** | No `$_SESSION` / `session_start()`, no superglobals (use PSR-7 / `GlobalsFactory`), no mutable static/singleton state across requests, no `sys_get_temp_dir()`. |
| **3. The Mago Purge Protocol** | Clean = ZERO output (no errors, warnings, info, help); zero baselines; native-first fixes; the `mago guard` perimeter (depend only on `contracts` + `utils`). |
| **4. Architecture & PSR** | The submodule shape (21 framework components, the four beta7 components `queue`/`openapi`/`serializer`/`testing`, plus the template apps, the scaffold, docs and academy — enumerate with `scripts/list-components.sh`), PSR enforcement (3/7/11/14/15/16/17/18), contracts-first sequencing, Diátaxis docs. |
| **5. Worker-Safety Gate (`wfl igor`)** | One auditor version everywhere (`.igor-version`, currently 0.9.7); 0 KO required; `#[WorkerSafe]`; **direct** `ResettableInterface`; the remediation taxonomy. |
| **5b. Release train & source of truth** | The `0.1.0-betaN` train (no `v` prefix), `project_system/` as the direction source of truth, and the umbrella-wave release mechanics. |
| **6. Git & release safety** | Agents edit files; the human commits, pushes, tags, merges and releases — each only on an explicit request. Tags `N.N.N` fire the LIVE wave; merges to `main` are merge commits, never squash; never "sync" with `git submodule update --remote`. Enforced by the team permission rules (`.claude/settings.json`) and the `waffle-cockpit` guard; third-party skills obey it too. |
| **7. Evidence & measurement** | Acceptance means evidence; measure the production image; a leak is a positive slope with its 95 % bound; commercial texts stay measurable. |
| **8. Skills, subagents and plugins** | The binding routing rule (load the matching skill before acting; `tech-lead` when unsure), the Claude Code frontmatter rules `wfl ai:check` enforces, and the repository plugins. Catalogue: [Claude Code skills reference](claude-skills.md). |
| **9. Third-party skills** | The vendored, pinned `mattpocock-skills`: its configuration (`docs/agents/`) and the precedence rule (`AGENTS.md` wins). |

## The non-negotiables

If you internalise nothing else from `AGENTS.md`:

1. **All work happens inside Docker** (`waffle-dev`). Never run PHP / Composer on the host.
2. **`declare(strict_types=1);` first**, no `mixed`, Property Hooks for validation.
3. **Stateless & resettable** across requests — no superglobals, no `$_SESSION`, no surviving mutable static. `wfl igor` must report **0 KO**.
4. **Components depend only on `waffle-commons/contracts`** (plus `utils`). Enforced by `mago guard`.
5. **`composer mago` clean = zero output**, and **no baseline files**, ever.
6. **Definition of done per modified component:** `composer mago && composer tests` green (PHPUnit 12.5, ≥95% coverage) **and** `wfl igor` 0 KO.
7. **Route before acting:** match the task to a skill and read its `SKILL.md` first; default to `tech-lead`.

## Relationship to `CLAUDE.md`

`CLAUDE.md` starts with `@AGENTS.md`, which puts this file in context, then adds the Claude Code specifics: the canonical `docker exec … waffle-dev` commands, the `wfl` surface, MCP and the plugins. `AGENTS.md` is the **rulebook**. When the two appear to differ, `AGENTS.md` wins and `CLAUDE.md` is corrected, not the other way round.

## Editing `AGENTS.md`

A significant change to the standards requires:

- An RFC issue describing the change and rationale;
- `@waffle-commons/waffle-core` approval (per `CODEOWNERS`);
- A coordinated PR that updates `AGENTS.md` and any doc pages that must follow (this page, [`claude-md.md`](claude-md.md), [`claude-skills.md`](claude-skills.md)).

Trivial changes (typos, formatting, link fixes) can go straight to PR.

## Related

- [`CLAUDE.md` conventions](claude-md.md) — the thin CLI router that redirects here.
- [Claude Code skills, subagents and plugins](claude-skills.md) — the catalogue §8 routes to.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — the rationale behind §3.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — the rationale behind the `mago guard` perimeter.
- [`project_system/` — governance & roadmap](project-system.md) — the direction source of truth referenced by §5b.
