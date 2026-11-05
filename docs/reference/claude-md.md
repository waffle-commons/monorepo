# Reference — `CLAUDE.md` conventions

> **Release:** `0.1.0-beta7`.
> **Scope:** `<umbrella>/CLAUDE.md`.
> **Purpose:** the Claude Code entry file at the umbrella root — it imports `AGENTS.md` (the binding standards) and adds the Claude Code specifics: the canonical Dockerized commands, the `wfl` surface, MCP and the repository plugins. Written for AI assistants, binding on humans too.

## What it is

A thin file at the umbrella root that Claude Code loads automatically. Its first line, `@AGENTS.md`, **imports** the rulebook, so the standards are in context in every session. (Claude Code reads `AGENTS.md` on its own only when no `CLAUDE.md` exists; a sentence that merely *told* it to read `AGENTS.md` was skipped whenever it chose not to open the file.) The rest of `CLAUDE.md` is Claude Code specifics; the per-task procedures are the skills in `.claude/skills/`.

Humans should read it too — then follow the link into `AGENTS.md` for the full standards.

## Sections

| Section | Codifies |
| :--- | :--- |
| **Canonical commands** | The Dockerized `docker exec … waffle-dev` invocations, the `composer` intents (`mago`, `tests`, `igor`, …), and the `wfl` CLI wrapper. |
| **`@AGENTS.md` import** | The first line: puts the binding standards in context for every session. |
| **MCP, plugins, skills & subagents** | Where the MCP servers, the repository plugins (`waffle-cockpit`, `mattpocock-skills`) and the skills / subagents come from. |
| **Before planning or editing** | Load the matching skill (`tech-lead` when unsure), consult `project_system/`, respect the release phase, and the hard invariants (contracts-only perimeter, zero Mago output, statelessness / `wfl igor` 0 KO). |

> The operational standards themselves — PHP 8.5 strict coding, the FrankenPHP statelessness mandate, the Mago Purge Protocol, the worker-safety gate, git safety and the skills rules — live in [`AGENTS.md`](../../AGENTS.md). `CLAUDE.md` imports them; it never restates them.

## The non-negotiables

If you only remember a handful of things (the full, binding set lives in `AGENTS.md`):

1. **All work happens inside Docker.** Never run PHP / Composer on the host machine.
2. **`declare(strict_types=1);` is the first line of every PHP file.** No exceptions.
3. **No `mixed` type.** Without explicit architect approval.
4. **Components only depend on `waffle-commons/contracts`.** Never on a sibling's concrete classes. Enforced by `mago guard`.
5. **No `$_SESSION`, no `$_SERVER` / `$_GET` / `$_POST`, no `sys_get_temp_dir()`.** FrankenPHP worker safety.
6. **Mago must pass with zero errors and no baseline files.** Fix issues, never ignore them.
7. **Every doc lives in the right Diátaxis quadrant.** Tutorial / how-to / reference / explanation — pick one.

## When you, the human contributor, are deciding something

Read `AGENTS.md` first (`CLAUDE.md` routes you there). If it is silent on your question, file an issue or open a discussion to propose adding a rule — don't invent one in your PR description.

## When `AGENTS.md` and a doc page disagree

`AGENTS.md` (the source of truth `CLAUDE.md` routes to) wins. The other doc is wrong; fix it.

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

- [`AGENTS.md` — the central brain](agents-md.md) — the binding operating standards `CLAUDE.md` routes to.
- [Claude Code skills, subagents and plugins](claude-skills.md) — the skill catalogue and the repository plugins.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — the rationale behind the Zero-Debt rule.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — the rationale behind the contracts-only dependency rule.
