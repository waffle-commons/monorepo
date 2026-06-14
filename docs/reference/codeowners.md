# Reference — `CODEOWNERS`

> **Release:** `0.1.0-beta4`.
> **Scope:** `<umbrella>/CODEOWNERS`.
> **Purpose:** GitHub review routing — who must approve a PR before it can merge.

## Current contents

```text
@waffle-commons/waffle-core
```

A single line. The `@waffle-commons/waffle-core` GitHub team is the global code-owner for every file in this umbrella. Any PR against this repository requires at least one `@waffle-commons/waffle-core` approval (enforced by [`component-ruleset.json`](component-ruleset.md)'s `require_code_owner_review: true`).

## Why one team for the whole repo

The umbrella's content is small and tightly coupled — submodule pointer bumps, `loop.sh`, `CLAUDE.md`. Per-path ownership would add complexity for ~no benefit. Component-specific review concentrates in each component's *own* repository, where that repo's `CODEOWNERS` (often the same `@waffle-commons/waffle-core` team) takes over.

## Adding per-path ownership

If you ever need to scope reviews more tightly:

```text
# Global default — applied if no later rule matches.
*    @waffle-commons/waffle-core

# Documentation can be reviewed by the docs team only.
/docs/             @waffle-commons/waffle-core @waffle-commons/docs
/documentation/    @waffle-commons/waffle-core @waffle-commons/docs

# Release-flow files require release managers.
/loop.sh             @waffle-commons/waffle-core @waffle-commons/release
/coverage.sh      @waffle-commons/waffle-core @waffle-commons/release
/component-ruleset.json @waffle-commons/waffle-core @waffle-commons/release
```

Later rules **override** earlier ones (last-match-wins). Always end with the most-specific rules.

## Verifying the rule applies

```bash
gh api /repos/waffle-commons/monorepo/codeowners/errors
```

A clean response (no errors) means the file parses and every team referenced exists.

## Related

- [`component-ruleset.json` reference](component-ruleset.md) — enforces `CODEOWNERS` via `require_code_owner_review: true`.
- [GitHub's CODEOWNERS docs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners).
