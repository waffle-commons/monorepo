---
name: release-wave
description: Orchestrate a coordinated multi-component umbrella release of waffle-commons (branch-per-component, no-v tags, dry-run on the pushed tag, LIVE wave)
compatibility: opencode
---

## What I do
I orchestrate a **full ecosystem release** of `waffle-commons`. All components ship **together** as one
coordinated wave on the release train (`0.1.0-beta4 → … → 1.0.0`). I own the orchestration;
`[[release-manager]]` owns the per-component steps. **Releases happen only when explicitly requested**
— never as a side effect of finishing work.

## When to use
"cut the beta-N release", "run the release wave", "tag the ecosystem", "promote to RC1". **Not** for a
single component out of band.

## Preconditions (hard gates)
- **Whole-roadmap done:** every axe of the target roadmap is finalized (the user gates this — e.g.
  Beta4 ships only after AXE 1–5 land).
- **Every component green:** `composer mago` (ZERO output) + `composer tests` (≥95%) + `wfl igor`
  (0 KO) on all modified components. See `[[mago-purge]]`, `[[worker-safety]]`.

## Wave protocol
1. **Branch per component:** one `pre-release/<version>` branch in *each* component repo (composer
   constraints across siblings, `README`, `CHANGELOG`). Delete the **previous** release's
   `pre-release/*` branches once the new ones are cut.
2. **Stamp current version only:** `0.1.0-betaN` — **NO `v` prefix** (the tag gate rejects a leading
   `v`). Never bulk-bump historical changelogs (see `[[roadmap-steward]]`).
3. **Push component tags** (bare SemVer) so Packagist syncs each package.
4. **Umbrella tag → dry-run → LIVE:**
   - Push the **umbrella** tag to the remote.
   - The dispatch **dry-run checks out `ref:<tag>`**, so the tag **must already exist on the remote**
     before the dry-run runs.
   - ⚠️ **Pushing the umbrella tag auto-fires the LIVE wave.** There is no "dry-run first then push" —
     the push *is* the trigger. Treat the push as the point of no return.
5. **Verify** Packagist resolves each package at the new version; confirm the wave's CI is green.

## New components in a wave
When a release introduces packages (beta6: `queue`, `openapi`, `serializer`, `testing`), scaffold each
from `component-template` (`[[component-scaffold]]`), register it in `.gitmodules` + `bin/wfl`, and
include it in the branch/tag set before the umbrella tag.

## Execution
```bash
# per component (loop): prove green, branch, stamp, tag — see release-manager
# then, once ALL are pushed:
git tag <umbrella-tag> && git push origin <umbrella-tag>   # ⚠️ fires the LIVE wave
```
> Coordinate the exact umbrella-tag name and dispatch workflow with the user — this is an
> outward-facing, hard-to-reverse action. Confirm before pushing.
