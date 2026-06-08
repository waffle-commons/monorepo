# Explanation — The release cycle

> **Diátaxis quadrant:** Explanation.
> **Release:** `0.1.0-beta3`.

## The cadence

Components release **independently**, but the ecosystem evolves in **coordinated waves**. A Beta-1 wave produces a coherent set of `0.1.0-beta1` tags across every component; a Beta-2 wave produces `0.1.0-beta2` across the same set.

This is enabled by the `self.version` Composer trick — see below.

## Semver, as we use it

Until `1.0.0`, the version string format is `0.MINOR.PATCH-betaN`:

- `0` — pre-1.0; **anything can break**.
- `MINOR` — a planned milestone (currently `1`).
- `PATCH` — bug-fix bumps within a milestone.
- `-betaN` — pre-release qualifier within the current milestone.

After 1.0:

- MAJOR — breaking changes.
- MINOR — new features, backwards-compatible.
- PATCH — bug fixes only.

Beta-1 → Beta-2 is allowed to break interfaces (and Beta-1 did: `CsrfTokenManagerInterface::issue/validate/refresh` gained a `$sessionId` parameter). The discipline is documenting the break in the changelog and the release notes.

## The `self.version` trick

Many components' `composer.json` declares:

```json
"require": {
  "waffle-commons/contracts": "self.version"
}
```

`self.version` is a Composer convention meaning "the same version as me". It works because the umbrella coordinates wave releases — `security@0.1.0-beta3` requires `contracts@0.1.0-beta3`, `routing@0.1.0-beta3`, etc. The whole wave is internally consistent.

The cost: you cannot, in practice, mix-and-match component versions across a wave. If you want `security@0.1.0-beta3` you implicitly want every other component at `0.1.0-beta3`. This is the explicit design — coordinated waves over fine-grained interop.

## The release wave, step by step

A coordinated wave (e.g. `0.1.0-beta2` → `0.1.0-beta3`):

1. **Pre-release sanity** — every component is green on its `main`:
   ```bash
   ./loop.sh composer mago
   ./loop.sh composer tests
   ./loop.sh composer audit
   ./coverage.sh
   ```
2. **Topological release order.** Releases cascade upward:
   1. `contracts` (no internal deps).
   2. `utils` (depends only on contracts).
   3. Leaf framework components (`cache`, `config`, `http`, …).
   4. Higher-level components that depend on the leaves (`pipeline`, `security`, `routing`).
   5. The framework facade (`waffle`).
   6. App-side (`skeleton`).
   7. Integration (`workspace`).
3. **For each component**: bump `composer.json` version, tag a signed annotated tag, push. Packagist auto-detects via the configured webhook. See [release-a-component](../how-to/release-a-component.md).
4. **Bump the umbrella pointers.** After every component has tagged, in the umbrella:
   ```bash
   git submodule foreach 'git fetch origin && git switch main && git pull --ff-only'
   git add .
   git commit -m "Bump submodule pointers to 0.1.0-beta3"
   git push
   ```
   See [bump-submodule-pointers](../how-to/bump-submodule-pointers.md).
5. **Tag the umbrella** with the wave name:
   ```bash
   git tag -a 0.1.0-beta3 -m "Beta 3 wave"
   git push origin 0.1.0-beta3
   ```
6. **Publish release notes** in the umbrella's GitHub Releases page summarising what changed across every component.

## Beta vs. stable cadence

While pre-1.0:

- Beta tags can break interfaces. Documented breaks only.
- Patches (e.g. `0.1.0-beta1.1` if needed — Composer allows `+` build metadata or fourth segments) for genuine showstoppers between waves.
- Release notes are mandatory.

At 1.0:

- MAJOR bumps happen on a deliberate cadence — quarterly at most.
- MINOR bumps as feature work lands.
- PATCH bumps as bugs surface.

We're not at 1.0. This document will be revised at that point.

## Where the version lives

Each component's `composer.json` carries its version explicitly:

```json
{
  "name": "waffle-commons/security",
  "version": "0.1.0-beta1",
  ...
}
```

Bump it as part of the release commit. The Git tag must agree.

(Some Composer setups omit the `version` field and let Packagist infer from tags. We carry it explicitly because the `self.version` constraint resolves more cleanly with it, and because `composer show --self` then prints the right thing in dev.)

## Honest costs

| Cost | Mitigation |
| :--- | :--- |
| A release wave touches every component. | Mostly mechanical; mostly automatable. |
| One component being late blocks the wave. | Plan releases with a clear cut-off; consider patch-releases for the laggard if necessary. |
| `self.version` means consumers cannot mix-and-match. | This is the intentional design — coordinated waves over fine-grained interop. |
| Manual umbrella pointer bumps. | Could be automated with a workflow that watches per-component tags; we don't currently. |

## Related

- [Release a component](../how-to/release-a-component.md) — the per-component half.
- [Bump submodule pointers](../how-to/bump-submodule-pointers.md) — the umbrella half.
- [`component-ruleset.json` reference](../reference/component-ruleset.md) — required signatures, PR approvals enforced by the ruleset.
- [Why a monorepo of submodules?](why-monorepo-of-submodules.md) — what the umbrella is for.
