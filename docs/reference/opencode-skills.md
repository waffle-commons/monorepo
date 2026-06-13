# Reference — `.opencode/skills/`

> **Release:** `0.1.0-beta4`.
> **Scope:** `<umbrella>/.opencode/skills/`.
> **Purpose:** the project-specific AI prompt library. Each subdirectory contains a single `SKILL.md` that an AI assistant must consult before performing a matching task.

## Routing directive (binding)

`CLAUDE.md` carries this directive: *if the user's request matches a specialised skill, the assistant MUST read the corresponding `SKILL.md` before planning or acting.* These prompts encode component-specific operating procedures that override generic AI defaults.

## Available skills

| Skill name | Trigger | SKILL.md path |
| :--- | :--- | :--- |
| **tech-lead** | Default for non-trivial or multi-component work. Orchestrates `coding` / `refactoring` / `test` / `code-review`. | `.opencode/skills/tech-lead/SKILL.md` |
| **coding** | New features and bug fixes — PHP 8.5 strict types, PSR compliance, FrankenPHP statelessness, Mago Purge. | `.opencode/skills/coding/SKILL.md` |
| **refactoring** | Behaviour-preserving restructuring. Requires green tests first. | `.opencode/skills/refactoring/SKILL.md` |
| **test** | PHPUnit 12 tests, ≥95% coverage, mocking via `contracts` interfaces only. | `.opencode/skills/test/SKILL.md` |
| **code-review** | Pre-merge code review, monorepo-aware (per-component `git diff`). | `.opencode/skills/code-review/SKILL.md` |
| **mago-purge** | Aggressive Mago error cleanup, Zero Baseline policy. | `.opencode/skills/mago-purge/SKILL.md` |
| **security-audit** | DevSecOps audit: FrankenPHP statelessness, ABAC, DTO validation, no superglobals. | `.opencode/skills/security-audit/SKILL.md` |
| **component-scaffold** | Bootstrap a new `waffle-commons/*` component from the template. | `.opencode/skills/component-scaffold/SKILL.md` |
| **diataxis-doc** | Generate Diátaxis-categorised technical documentation. | `.opencode/skills/diataxis-doc/SKILL.md` |
| **release-manager** | Coordinate releases — tags, Packagist, submodule pointer bumps. | `.opencode/skills/release-manager/SKILL.md` |

## How a skill is loaded

The AI assistant invocation conventionally:

1. Reads `CLAUDE.md` first.
2. Determines if the user's task matches a skill from the routing table above.
3. Reads the corresponding `SKILL.md` **before** planning or editing files.
4. Defers to that skill's operating procedure for the duration of the task.

When in doubt about which skill applies, the assistant should default to **`tech-lead`** — which orchestrates the others.

## SKILL.md file shape

Every skill follows the same structure:

```markdown
---
name: <skill-name>
description: <one-line trigger description>
compatibility: opencode
---

## What I do
<scope and role>

## Workflow / Protocol
<step-by-step procedure>

## Definition of done
<checklist the skill must satisfy>
```

The frontmatter is read by OpenCode (and similar tools) to surface the skill in the assistant's tool list.

## Adding a new skill

1. Create `.opencode/skills/<name>/SKILL.md`.
2. Add a row to the routing table in `CLAUDE.md` (the `🧠 SPECIALIZED AI SKILLS` section).
3. Add a row to this reference page.
4. Open an umbrella PR — review by `@waffle-commons/waffle-core` per CODEOWNERS.

## Don't bypass skills silently

If you find yourself ignoring a skill ("I know better than this prompt"), that's a signal the skill needs updating, not bypassing. Open an issue against the umbrella, propose the change, and update `SKILL.md` through review.

## Related

- [`CLAUDE.md` reference](claude-md.md) — the file that routes to these skills.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — what `mago-purge` operationalises.
- [Add a new component](../how-to/add-a-new-component.md) — uses the `component-scaffold` skill.
