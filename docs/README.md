# Waffle Commons — Monorepo Documentation

> **Audience:** contributors and maintainers of the Waffle Commons monorepo.
> **Scope:** how to use *this* repository — submodules, Docker, scripts, releases.
> **Release:** `0.1.0-beta5`

For framework usage (writing controllers, configuring routing, securing endpoints), see [`/documentation`](../documentation/) — the framework's own Diátaxis tree.

## 📚 Diátaxis quadrants

Documentation is organised by what you're trying to do, following the [Diátaxis](https://diataxis.fr/) framework.

| Quadrant | Goal | When you need it |
| :--- | :--- | :--- |
| **[Tutorials](tutorials/)** | Learning-oriented | First time touching the monorepo. You want to be guided end-to-end. |
| **[How-To Guides](how-to/)** | Task-oriented | You already know the project. You want a concrete recipe for a specific job. |
| **[Reference](reference/)** | Information-oriented | You want to look up an exact flag, script signature, file location, or constant. |
| **[Explanation](explanation/)** | Understanding-oriented | You want to understand *why* the monorepo is structured the way it is. |

## 🗺️ Quick navigation

### Brand-new contributor?
- [**Set up your monorepo workspace**](tutorials/setup-your-monorepo-workspace.md) — clone, Docker, first build.
- [**Make your first cross-component change**](tutorials/make-your-first-cross-component-change.md) — submodule mechanics in practice.

### Doing a specific task?
- [**Run checks across all components**](how-to/run-checks-across-components.md) — `loop.sh`; memory-neutrality via `igor.sh` / `wfl igor`.
- [**Add a new component**](how-to/add-a-new-component.md) — from `component-template`.
- [**Update a submodule pointer**](how-to/update-a-submodule.md) — when a downstream change has merged.
- [**Release a component**](how-to/release-a-component.md) — tag, push, Packagist.
- [**Work on multiple components locally**](how-to/work-on-multiple-components-locally.md) — Composer path repositories.
- [**Install Git hooks**](how-to/install-git-hooks.md) — `scripts/install-git-hooks.sh` + Project Graphify.
- [**Bump submodule pointers in the umbrella**](how-to/bump-submodule-pointers.md).
- [**Check coverage across components**](how-to/check-coverage-across-components.md) — `coverage.sh`.

### Looking up a specific tool?
- [**Repository layout**](reference/repository-layout.md) — every directory explained.
- [**Docker dev environment**](reference/docker-environment.md) — `waffle-dev` container.
- [**`loop.sh`**](how-to/run-checks-across-components.md), [**`coverage.sh`**](how-to/check-coverage-across-components.md), [**`scripts/install-git-hooks.sh`**](how-to/install-git-hooks.md), **`zip-project.sh`**.
- [**`CLAUDE.md` conventions**](reference/claude-md.md) — the canonical project rules.
- [**OpenCode skills**](reference/opencode-skills.md) — `.opencode/skills/*` AI prompts.
- [**`component-ruleset.json`**](reference/component-ruleset.md) — GitHub branch protection ruleset.
- [**`CODEOWNERS`**](reference/codeowners.md) — review routing.

### Planning a change or proposing a feature?
- [**`project_system/` — governance & roadmap**](reference/project-system.md) — the **official roadmap**, the RFC design specs, and per-release logs & retrospectives. Align your proposal with the current [roadmap](../project_system/Roadmaps/Roadmap_Beta5.md) and the relevant RFC **before** you build.

### Why is it like this?
- [**Why a monorepo of submodules?**](explanation/why-monorepo-of-submodules.md) — the rationale and trade-offs.
- [**The Component Agnosticism rule**](explanation/component-agnosticism.md) — why every component depends only on `contracts`.
- [**The Mago Purge Protocol**](explanation/mago-purge-protocol.md) — Zero-Debt static analysis.
- [**Docker-first development**](explanation/docker-first-development.md) — why we don't support native PHP on host.
- [**The release cycle**](explanation/release-cycle.md) — semver, beta tags, Packagist.

## 🤝 Style and contribution

Doc style mirrors the framework docs in [`/documentation`](../documentation/README.md): GitHub-flavoured Markdown, an explicit `> **Release:** vX.Y.Z` banner at the top of every reference and explanation page, one Diátaxis quadrant per file. Code blocks are language-tagged. Cross-links use repo-relative paths.

When you ship a change to the monorepo's tooling, layout, or release flow, **also ship the corresponding doc update here**. CI does not fail on stale docs (yet) but reviewers will flag it.

## 📄 License

MIT — see [LICENSE](../LICENSE).
