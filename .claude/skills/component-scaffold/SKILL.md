---
name: component-scaffold
description: "Create a new autonomous component from component-template and wire the umbrella, GitHub and Packagist"
when_to_use: >-
  "Create a new component", "bootstrap a package", wfl new-component, onboarding a new submodule
  (gitlink, .gitmodules, template-app vendor entries, rulesets, Packagist).
---

## What I do
I bring a new autonomous component (its own repository, a submodule of the umbrella, a Packagist
package) from nothing to "integrated". **A component is not integrated until every item below is
done** — the onboarding bit twice on Beta5 release day (a missing umbrella gitlink, a broken
template-app vendor entry). File edits are mine; every git, GitHub and Packagist action is the
maintainer's (`AGENTS.md` §6).

## 1. Scaffold
The canonical source is **`component-template`**. Never hand-roll a skeleton and never `cp -R` + `git
init`: the component must be a submodule whose history starts from its own remote.

- **From the umbrella (preferred):**
  `wfl new-component <PascalName> <git-url> "<one-sentence description>" [package-slug]`
  → `git submodule add` (only when the human asked for the component), seeds the template, runs the
  configure script, `composer install`, then `wfl dod`.
- **Repository created from the GitHub template** (e.g. the beta7 `queue`, `openapi`, `serializer`,
  `testing`): it holds the template as of its creation date. Sync the current template files first
  (`rsync -a --exclude .git --exclude vendor/ --exclude graphify-out/ component-template/ <slug>/`),
  then run `./configure-component.sh <PascalName> [package-slug] "<description>"` inside it.

`configure-component.sh` replaces `{COMPONENT_NAME}` (PSR-4 segment: `Waffle\Commons\OpenApi`),
`{COMPONENT_SLUG}` (lowercase Composer name, derived from the PascalCase name unless given:
`openapi`) and `{COMPONENT_DESCRIPTION}` (what Packagist shows — never leave a placeholder; 17 packages
once shipped "X component for Waffle framework."). It installs the component README, removes
`images/`, fails if a placeholder survives, and deletes itself.

## 2. Prove the gates on the empty scaffold
```bash
docker exec -w /waffle-commons/<slug> waffle-dev composer install   # writes composer.lock (tracked)
wfl dod <slug>
```
- `composer mago` → **zero output**. The template ships the ecosystem policy; no baseline, ever.
- Tests and coverage are **N/A only while `src/` holds no PHP file**; the first class switches the full
  bar on (PHPUnit green, ≥ 95 %). The canonical CI applies the same rule (`hashFiles('src/**/*.php')`).
- `composer igor` → 0 KO with the pinned auditor (`.igor-version`; a stale binary fails the gate).

## 3. Wire the umbrella (file edits; commits are the maintainer's)
- **Gitlink (Gap 2):** `.gitmodules` entry **and** a committed gitlink — `git ls-files -s <slug>` must show
  `160000 <sha>`. Without it every CI `git submodule update --init -- <slug>` fails with a pathspec error.
- **umbrella-ci:** add `<slug>` to the `dorny/paths-filter` list (`wfl ci:check` flags a missing entry).
- **Git hooks:** `scripts/install-git-hooks.sh` (idempotent).
- **SEC-03:** if the component compares secrets, tokens or signatures, add it to the `sec03` job's init
  list **and** audit arguments (a missing scan target is silently skipped).
- **`RELEASE_INCLUDE`** (`release-wave.yml`): at release preparation, once the component ships code.
- **Template apps (Gap 1):** only when a feature is wired into `skeleton`/`workspace` — mirror the
  component's `composer.lock` entry in `vendor/composer/installed.json` (see `demo-app-wiring`).

## 4. GitHub and Packagist (maintainer actions — prepare, never execute)
- Repository settings: **merge commits only** (squash and rebase off — the release wave requires every
  pinned gitlink to be an ancestor of `main`), delete branch on merge, a real description.
- Rulesets: `wfl rulesets:check <slug>` (the maintainer runs `rulesets:sync`).
- Packagist: register `waffle-commons/<slug>` **before its first tag**.
- Dependabot PRs opened against the raw template are superseded once the configured files land.

## 5. Build it contracts-first
Every interface the component implements lands in `waffle-commons/contracts` **before** the component
uses it (`contracts-first`). Perimeter: `contracts` + `utils` + PSR — never a sibling's concrete class.
A component that needs another third-party namespace (e.g. `testing` extending PHPUnit's `TestCase`)
permits it explicitly in its own `mago.toml` guard.

**Beta7 newcomers (2026-09-30):** `queue`, `openapi`, `serializer` and `testing` are configured and pass
DoD in scaffold mode. Their first class switches tests and coverage on. Each joins `RELEASE_INCLUDE`
only once it ships code, and each gets its first stable-channel publication at RC1 (`[RC-06]`).
Perimeter decisions to settle before the first class: `[CARRY-04]` in `contracts-first`.

## 6. Verify and report
- `wfl ci:check` → no drift (canonical CI byte-identical, Dependabot, toolchain, description, filter).
- `wfl sync:status` → the new repo sits on the release branch, gitlink `match`.
- Report the repository, package name, namespace, perimeter, the gate results, and the list of
  maintainer actions still pending (gitlink commit, settings, Packagist, `RELEASE_INCLUDE`).
