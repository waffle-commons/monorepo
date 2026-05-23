# Reference — `CLAUDE.md` conventions

> **Release:** `v0.1.0-beta1`.
> **Scope:** `<umbrella>/CLAUDE.md`.
> **Purpose:** the canonical project conventions, written as instructions for AI assistants but binding on humans as well.

## What it is

A single file at the umbrella root that tells any AI assistant (Claude Code, Cursor, Aider, …) the project's non-negotiable rules. The file is loaded automatically by tools that respect the convention.

Humans should also read it. It is, in effect, the contributor handbook.

## Sections

| Section | Codifies |
| :--- | :--- |
| **Build & Test Commands** | Canonical `docker exec` invocations for Mago, PHPUnit, Composer. |
| **PHP 8.5 Strict Coding Standards** | `declare(strict_types=1)`, no `mixed`, typed constants, Property Hooks, Asymmetric Visibility, `readonly`. |
| **Architecture Map & Monorepo Structure** | Component agnosticism rule, PSR enforcement, FrankenPHP worker-mode constraints. |
| **Documentation (Diátaxis)** | The four quadrants, content rules per quadrant. |
| **The Mago Purge Protocol** | Zero baselines, zero errors. |
| **🧠 SPECIALIZED AI SKILLS (ROUTING DIRECTIVE)** | Maps user intent to `.opencode/skills/<skill>/SKILL.md`. See [opencode-skills reference](opencode-skills.md). |

## The non-negotiables

If you only remember a handful of things from `CLAUDE.md`:

1. **All work happens inside Docker.** Never run PHP / Composer on the host machine.
2. **`declare(strict_types=1);` is the first line of every PHP file.** No exceptions.
3. **No `mixed` type.** Without explicit architect approval.
4. **Components only depend on `waffle-commons/contracts`.** Never on a sibling's concrete classes. Enforced by `mago guard`.
5. **No `$_SESSION`, no `$_SERVER` / `$_GET` / `$_POST`, no `sys_get_temp_dir()`.** FrankenPHP worker safety.
6. **Mago must pass with zero errors and no baseline files.** Fix issues, never ignore them.
7. **Every doc lives in the right Diátaxis quadrant.** Tutorial / how-to / reference / explanation — pick one.

## When you, the human contributor, are deciding something

Read `CLAUDE.md` first. If the file is silent on your question, file an issue or open a discussion to propose adding a rule — don't invent one in your PR description.

## When `CLAUDE.md` and a doc page disagree

`CLAUDE.md` wins. The other doc is wrong; fix it.

## When an AI assistant is mis-applying a rule

Two failure modes:

- **Too literal** — assistant blocks on a rule that doesn't apply to the current situation. Push back; the file is guidance, not law for cases nobody anticipated.
- **Ignored** — assistant blows past a rule. Ask it to re-read the specific section. Worst case, paste the rule into the chat.

## Editing `CLAUDE.md`

Significant change to the rules requires:

- An RFC issue describing the change and the rationale;
- `@waffle-commons/waffle-core` approval;
- A coordinated PR that updates `CLAUDE.md` and any doc pages that need to follow.

Trivial changes (typos, formatting, link fixes) can go straight to PR.

## Related

- [`.opencode/skills/` reference](opencode-skills.md) — the specialised AI prompts CLAUDE.md routes to.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — the rationale behind the Zero-Debt rule.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — the rationale behind the contracts-only dependency rule.
