# Explanation — Why a monorepo of submodules?

> **Diátaxis quadrant:** Explanation (understanding-oriented).
> **Release:** `v0.1.0-beta1`.

The Waffle ecosystem is **19 independent Git repositories** stitched together by **one umbrella repository** that pins each at a specific commit. Each component is also its own Packagist package, released on its own cadence. This shape surprises newcomers used to either (a) a true monorepo (single repo, single version, single CI) or (b) a poly-repo (many repos, no umbrella).

This page explains why we picked the middle path and what it costs.

## The constraints we started from

1. **Components must be independently consumable.** Someone using only `waffle-commons/log` should not have to pull in `waffle-commons/security`. Packagist publication implies independent repositories — Composer cannot install a subpath of a repository as a package.
2. **Components must evolve together at known good states.** Releasing `contracts@v0.2.0` without coordinating with `security`, `routing`, and `pipeline` immediately is how interfaces drift. Some kind of umbrella checkpoint is necessary.
3. **One contributor must be able to make a coordinated cross-component change.** Forking five separate repos to make a security fix that spans `contracts`, `security`, and `pipeline` is too high-friction.
4. **CI must be component-scoped.** `cache`'s tests should not be re-run because `routing` changed.

Independent Packagist publication satisfies (1) and (4). Per-component repos satisfy (4). Constraints (2) and (3) push toward *some* unified view of the whole ecosystem.

## The three shapes we considered

### Option A — True monorepo (`monorepo/contracts/`, `monorepo/security/`, …)

One repository. Every component lives at a path inside it. CI matrixes over component directories.

| Pro | Con |
| :--- | :--- |
| Atomic cross-component commits. | **Packagist cannot publish from a subpath.** Every release would need a one-off subtree-split tool. |
| Trivial code search across the ecosystem. | A single PR touching one component slows reviewers down with diffs they don't care about. |
| One CI config. | One catastrophic CI bug blocks the whole ecosystem. |

The Packagist constraint is the killer. We could solve it with `splitsh-lite` and per-component publishing repositories, but that's the same complexity as the submodule approach with extra moving parts.

### Option B — Pure poly-repo

Many repos. No umbrella. Each contributor figures out which repos to clone.

| Pro | Con |
| :--- | :--- |
| Each repo is small and self-contained. | No coordinated cross-component state. "What versions go together?" is unknowable without a separate document. |
| Independent CI, independent releases. | Cross-component refactors require N coordinated PRs with no umbrella PR to gate them. |
| | The dependency graph is invisible at the repo level. |

Workable for small ecosystems. Doesn't scale to 16 framework components plus skeleton + workspace + template.

### Option C — Umbrella with submodules (the path we picked)

Each component is its own GitHub repo (satisfies Packagist). The umbrella is a separate repo whose only content is **submodule pointers** and **cross-component tooling** (scripts, docs, shared CI helpers).

| Pro | Con |
| :--- | :--- |
| `git clone --recurse-submodules` gives every contributor a coherent ecosystem checkpoint. | Submodules confuse first-time contributors (detached HEAD, two-step commit). |
| Each component remains independently releasable to Packagist. | Cross-component change is three commits (per-component × 2 + umbrella pointer bump), not one. |
| Per-component CI stays scoped. | Pointer bumps can lag behind component releases. |
| The umbrella PR is a natural place to land cross-component refactors. | The umbrella's `git log` is dense — mostly pointer bumps. |

We accept the friction (two-step commit, pointer bumps) in exchange for clean Packagist publishing and visible cross-component state.

## What submodule pointers actually buy us

A clone of `monorepo` at SHA `X` gives a contributor the **exact** set of component SHAs the ecosystem was tested against. Drop `git clone --recurse-submodules ... && git checkout <release-tag>` and the integration tests in `workspace/` will pass — *every time, deterministically*. No "which contracts version goes with this security version?" guessing.

This is the property the umbrella exists to provide. Everything else (the scripts, the contributor docs) is tooling around it.

## Honest costs

| Cost | Who pays it |
| :--- | :--- |
| First-time contributors lose ~30 minutes to detached-HEAD confusion. | Newcomers. Mitigated by [the setup tutorial](../tutorials/setup-your-monorepo-workspace.md). |
| Cross-component changes are 3 commits in 3 places. | Frequent contributors. Mitigated by [path repositories during development](../how-to/work-on-multiple-components-locally.md). |
| Vendor caches in each component go stale during local cross-component work. | Frequent contributors. Mitigated by `composer update` after pointer bumps. |
| The umbrella's `git log` is mostly pointer bumps. | Reviewers searching for "when did X happen?". Mitigated by also searching the per-component repos directly. |

We deemed these costs acceptable for the constraints we're optimising. We revisit periodically — if Packagist ever supports subpath publication, Option A becomes worth re-evaluating.

## When *not* to follow this pattern

If you're building a framework with:

- ≤ 5 components,
- no per-component release cadence,
- and a single CI bill payer,

a true monorepo (Option A) is simpler and you don't need this complexity. The submodule shape pays off only when there really are many independent packages with diverging release cadences.

## Related

- [Repository layout](../reference/repository-layout.md) — the concrete tree.
- [The Component Agnosticism rule](component-agnosticism.md) — what keeps the components independent.
- [Make your first cross-component change](../tutorials/make-your-first-cross-component-change.md) — the friction in practice.
