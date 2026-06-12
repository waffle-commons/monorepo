---
name: release-manager
description: Manage independent component releases on Packagist in the Waffle-Commons monorepo
compatibility: opencode
---

## What I do
I handle the **per-component** mechanics of a release: each component is its own submodule published
on Packagist. In Waffle, all components ship **together** as a coordinated **umbrella wave** (one
`pre-release/<version>` branch per component, one umbrella tag) — I am the per-component half of that;
`[[release-wave]]` owns the orchestration. I never release a single component out of band unless
explicitly told to.

## Per-component release steps

For **each** component in the wave:

1. **Navigate to the component:**
   ```bash
   cd {component_dir}
   ```

2. **Prove it is green (definition of done):**
   ```bash
   docker exec -it -w /waffle-commons/{component} waffle-dev composer mago    # ZERO output
   docker exec -it -w /waffle-commons/{component} waffle-dev composer tests   # PHPUnit 12.5, ≥95%
   docker exec -it -w /waffle-commons/{component} waffle-dev composer igor    # 0 KO
   ```

3. **Sync release metadata** on the `pre-release/<version>` branch: composer constraints across
   sibling packages, `README`, `CHANGELOG` (stamp the **current** version only — see
   `[[diataxis-doc]]` / `[[roadmap-steward]]` — never bulk-bump history).

4. **Tag — NO `v` prefix.** Tags are bare SemVer (`0.1.0-beta4`, `1.0.0-RC1`, `1.0.0`); the tag gate
   rejects a leading `v`.
   ```bash
   git tag 0.1.0-betaN        # NOT v0.1.0-betaN
   git push origin 0.1.0-betaN
   ```

5. **Packagist sync:** once the tag is on the remote, Packagist auto-syncs. Confirm the version
   resolves before moving on.

> ⚠️ Pushing the **umbrella** tag auto-fires the LIVE wave, and the dispatch dry-run checks out
> `ref:<tag>` (the tag must already exist on the remote). Coordinate via `[[release-wave]]` — do not
> push tags ad hoc.
