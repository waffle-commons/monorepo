# How-To: Add a new component

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta6`.
> **Answers:** I want to ship a new `waffle-commons/<thing>` package. What's the process?

## When to add a component vs extend an existing one

Add a new component when:

- The new code is **independently useful** (a consumer outside the framework could `composer require` it).
- It has a clean PSR-x or W3C contract you can point at.
- It will only depend on `waffle-commons/contracts` (plus `waffle-commons/utils` and the PSR interface
  packages).

If those aren't all true, extend an existing component instead. New components have ongoing release / CI /
coverage cost.

## 1. Create the GitHub repository

Create `waffle-commons/<slug>` (public) — empty, or from the `component-template` GitHub template. Then:

- **Settings:** merge commits only (turn **squash and rebase off** — the release wave requires every pinned
  commit to be an ancestor of `main`, and a squash orphans it), delete branch on merge.
- **Rulesets:** `wfl rulesets:sync <slug>` applies the canonical set from the root `*-ruleset.json` files;
  `wfl rulesets:check <slug>` verifies it. See the [`component-ruleset` reference](../reference/component-ruleset.md).

## 2. Scaffold it into the umbrella

**Empty repository** — one command does it all (submodule, template seed, configuration, `composer install`,
Definition of Done):

```bash
wfl new-component <PascalName> <git-url> "<one-sentence description>" [package-slug]
# e.g. wfl new-component RateLimiter git@github.com:waffle-commons/rate-limiter.git \
#        "Token-bucket rate limiting for the Waffle framework."
```

**Repository created from the GitHub template** — it holds the template as of its creation date, so bring it
up to date first:

```bash
git submodule add git@github.com:waffle-commons/<slug>.git <slug>
rsync -a --exclude .git --exclude vendor/ --exclude graphify-out/ component-template/ <slug>/
(cd <slug> && ./configure-component.sh <PascalName> [package-slug] "<one-sentence description>")
docker exec -w /waffle-commons/<slug> waffle-dev composer install
```

`configure-component.sh` replaces three placeholders — `{COMPONENT_NAME}` (the PSR-4 segment, e.g.
`Waffle\Commons\OpenApi`), `{COMPONENT_SLUG}` (the lowercase Composer name, derived from the PascalCase
name unless given, e.g. `openapi`) and `{COMPONENT_DESCRIPTION}` (what Packagist shows). It installs the
component README, removes the template-only `images/`, **fails if a placeholder survives**, and deletes
itself.

## 3. Prove the gates

```bash
wfl dod <slug>
```

`composer mago` must print **zero** diagnostics and `composer igor` must report 0 KO with the pinned auditor
(`.igor-version`). Tests and coverage are **N/A only while `src/` holds no PHP file**: the first class
switches the full bar on (PHPUnit green, line coverage ≥ 95 %). The canonical CI workflow applies the same
rule.

## 4. Wire the umbrella

- **Gitlink:** commit `.gitmodules` **and** the submodule pointer; `git ls-files -s <slug>` must show
  `160000 <sha>`, or every CI `git submodule update --init -- <slug>` fails with a pathspec error.
- **umbrella-ci:** add `<slug>` to the `dorny/paths-filter` list in `.github/workflows/umbrella-ci.yml`.
- **Git hooks:** `./scripts/install-git-hooks.sh` (idempotent — see [Install git hooks](install-git-hooks.md)).
- **SEC-03:** if the component compares secrets, tokens or signatures, add it to the `sec03` job's
  submodule list **and** to its audit arguments.
- **Release allowlist:** add `<slug>` to `RELEASE_INCLUDE` in `.github/workflows/release-wave.yml` at release
  preparation, once the component ships code.
- `loop.sh`, `coverage.sh` and `wfl` derive the component set from `.gitmodules`
  (`scripts/list-components.sh`) — there is no hardcoded list to edit.

Then check nothing drifted:

```bash
wfl ci:check      # canonical CI workflow, Dependabot, toolchain, description, paths filter
wfl sync:status   # the new repo is on the release branch and its gitlink matches
```

## 5. Register it on Packagist

Submit `waffle-commons/<slug>` on Packagist **before the first tag**, so the release wave's tag reaches it.

## 6. Wire the documentation entries

| File | Add |
| :--- | :--- |
| `README.md` (this repo's root) | New row in the **What's inside** matrix. |
| `documentation/reference/index.md` | New row in the components table (framework-user perspective). |
| `documentation/reference/<my-thing>.md` | New reference page describing the component's public surface. |
| `docs/reference/repository-layout.md` | Mention the new directory. |

If the new component introduces user-facing concepts (an attribute, a middleware, a service contract), it
likely also needs an explanation page under `documentation/explanation/` and possibly a how-to under
`documentation/how-to/`.

## 7. Open the umbrella PR

Per-PR checklist:

- [ ] Repository on GitHub with merge-commit-only settings and the canonical rulesets (`wfl rulesets:check`).
- [ ] `.gitmodules` and the `160000` gitlink committed in the umbrella.
- [ ] `umbrella-ci` paths filter updated; `wfl ci:check` reports no drift.
- [ ] `wfl dod <slug>` green; git hooks installed.
- [ ] Package registered on Packagist.
- [ ] `README.md` matrix and `documentation/reference/index.md` updated; new reference page.

## Related

- [Release a component](release-a-component.md) — for the first real release of the new package.
- [`component-template` reference](../reference/repository-layout.md) — the scaffold's contents.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — why your new component must only
  depend on `contracts`.
