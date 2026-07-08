# Reference — `AGENTS.md` (the central brain)

> **Release:** `0.1.0-beta5`.
> **Scope:** `<umbrella>/AGENTS.md`.
> **Purpose:** the single source of truth for how any AI assistant must behave in the monorepo — the binding operating standards that [`CLAUDE.md`](claude-md.md) (the thin CLI router) redirects to.

## What it is

A single file at the umbrella root that carries the project's **non-negotiable operating standards** for AI assistants (and, in effect, the contributor handbook for humans). Where [`CLAUDE.md`](claude-md.md) is a thin router that ships the canonical Dockerized commands and points here, `AGENTS.md` holds the actual rules: PHP 8.5 coding standards, the FrankenPHP statelessness mandate, the Mago Purge Protocol, the worker-safety gate, the release train, and the **Skills Routing Table**.

> **Read order for every task:** `AGENTS.md` → the matching `.opencode/skills/<skill>/SKILL.md` (see the Routing Table). When in doubt, start with `tech-lead`.

## Sections

| Section | Codifies |
| :--- | :--- |
| **1. PHP 8.5 Strict Coding Standards** | `declare(strict_types=1)`, no `mixed`, typed constants, Property Hooks for validation, asymmetric visibility + `readonly` DTOs, `#[\Override]`, fail-secure errors, and the language policy (English everywhere except the `skeleton/`, `workspace/`, and `academy/` template dirs, which are French). |
| **2. FrankenPHP Statelessness Mandate** | No `$_SESSION` / `session_start()`, no superglobals (use PSR-7 / `GlobalsFactory`), no mutable static/singleton state across requests, no `sys_get_temp_dir()`. |
| **3. The Mago Purge Protocol** | Clean = ZERO output (no errors, warnings, info, help); zero baselines; native-first fixes; the `mago guard` perimeter (depend only on `contracts` + `utils`). |
| **4. Architecture & PSR** | The 26-submodule shape (21 framework components + template, scaffold, docs, and academy submodules), PSR enforcement (3/7/11/14/15/16/17/18), contracts-first sequencing, Diátaxis docs. |
| **5. Worker-Safety Gate (`wfl igor`)** | igor-php 0.7: 0 KO required; `#[WorkerSafe]`; **direct** `ResettableInterface`; the remediation taxonomy. |
| **5b. Release train & source of truth** | The `0.1.0-betaN` train (no `v` prefix), `project_system/` as the direction source of truth, and the umbrella-wave release mechanics. |
| **🧠 Specialized AI Skills — Routing Table** | Maps user intent → `.opencode/skills/<skill>/SKILL.md` (29 skills, grouped). The binding routing directive lives here. See the [OpenCode skills reference](opencode-skills.md). |
| **🤖 Subagents** | The 14 focused single-component workers (`.opencode/agents/<name>.md`, `mode: subagent`) that skills dispatch. |

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

`CLAUDE.md` is the **thin CLI router**: it ships the canonical `docker exec … waffle-dev` commands and a redirection directive, then defers here. `AGENTS.md` is the **rulebook**. When the two appear to differ, `AGENTS.md` wins and `CLAUDE.md` is corrected to route, not to restate.

## Editing `AGENTS.md`

A significant change to the standards requires:

- An RFC issue describing the change and rationale;
- `@waffle-commons/waffle-core` approval (per `CODEOWNERS`);
- A coordinated PR that updates `AGENTS.md` and any doc pages that must follow (this page, [`claude-md.md`](claude-md.md), [`opencode-skills.md`](opencode-skills.md)).

Trivial changes (typos, formatting, link fixes) can go straight to PR.

## Related

- [`CLAUDE.md` conventions](claude-md.md) — the thin CLI router that redirects here.
- [`.opencode/skills/` reference](opencode-skills.md) — the 29-skill library `AGENTS.md` routes to.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — the rationale behind §3.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — the rationale behind the `mago guard` perimeter.
- [`project_system/` — governance & roadmap](project-system.md) — the direction source of truth referenced by §5b.
