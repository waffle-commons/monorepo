# Reference

> Information-oriented. Authoritative facts about the monorepo's structure, tools, and conventions. No tutorials, no opinions — just signatures and behaviour tables.

## Pages

### Repository

- [**Repository layout**](repository-layout.md) — every directory and what it contains.
- [**`project_system/` — governance & roadmap**](project-system.md) — the **official roadmap**, RFCs, and per-release logs & retrospectives.
- [**`CODEOWNERS`**](codeowners.md) — who reviews what.
- [**`component-ruleset.json`**](component-ruleset.md) — GitHub branch-protection ruleset shipped with this repo.
- [**`AGENTS.md` — the central brain**](agents-md.md) — the binding operating standards (coding, statelessness, Mago Purge, worker-safety, skills routing).
- [**`CLAUDE.md` conventions**](claude-md.md) — the thin CLI router → `AGENTS.md` (the canonical standards) + AI-assistant routing.
- [**OpenCode skills**](opencode-skills.md) — the `.opencode/skills/*` AI prompt library.

### Development environment

- [**Docker environment**](docker-environment.md) — the `waffle-dev` container, mounted paths, expected services.

### Scripts (top-level)

- [**`loop.sh`**](../how-to/run-checks-across-components.md) — fan a command across every component.
- [**`coverage.sh`**](../how-to/check-coverage-across-components.md) — read PHPUnit coverage and enforce the 95% bar.
- [**`scripts/install-git-hooks.sh`**](../how-to/install-git-hooks.md) — install pre-commit Mago + pre-push sanity hooks (and Project Graphify hooks) in every submodule.
- **`zip-project.sh`** — package the umbrella for distribution.

### CI / release workflows

- [**`release-wave.yml`**](workflows/release-wave.md) — propagates umbrella tag → every component repo (tag + GitHub Release with auto-generated notes).

## How reference pages are structured

Every reference page in this tree starts with:

```
> **Release:** 0.1.0-betaN
> **Scope:** which file / directory / command this page describes.
```

Followed by, in order: exact signature(s), behaviour, side effects, exit codes / return values, examples, related pages. No tutorial-style prose, no "why" content (that lives in [explanation](../explanation/)).

If a reference page diverges from the actual code behaviour, the **code wins** and the doc gets fixed — open a PR.
