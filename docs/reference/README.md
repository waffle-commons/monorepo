# Reference

> Information-oriented. Authoritative facts about the monorepo's structure, tools, and conventions. No tutorials, no opinions — just signatures and behaviour tables.

## Pages

### Repository

- [**Repository layout**](repository-layout.md) — every directory and what it contains.
- [**`CODEOWNERS`**](codeowners.md) — who reviews what.
- [**`component-ruleset.json`**](component-ruleset.md) — GitHub branch-protection ruleset shipped with this repo.
- [**`CLAUDE.md` conventions**](claude-md.md) — the canonical project rules + AI-assistant routing.
- [**OpenCode skills**](opencode-skills.md) — the `.opencode/skills/*` AI prompt library.

### Development environment

- [**Docker environment**](docker-environment.md) — the `waffle-dev` container, mounted paths, expected services.

### Scripts (top-level)

- [**`loop.sh`**](scripts/run-all.md) — fan a command across every component.
- [**`coverage.sh`**](scripts/check-coverage.md) — read PHPUnit coverage and enforce the 95% bar.
- [**`scripts/install-git-hooks.sh`**](scripts/install-git-hooks.md) — install pre-commit Mago + pre-push sanity hooks (and Project Graphify hooks) in every submodule.
- [**`zip-project.sh`**](scripts/zip-project.md) — package the umbrella for distribution.

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
