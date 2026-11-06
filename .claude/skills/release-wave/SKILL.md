---
name: release-wave
description: "Orchestrate the umbrella release wave: branch per component, no-v tags, dry-run, LIVE wave"
when_to_use: >-
  "Cut the beta-N release", "run the release wave", "tag the ecosystem", "promote to RC1". Releases
  happen only on an explicit request and tags are live. Not for a single component out of band.
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
   Release dates are **month-precision** `YYYY-MM` — `## [0.1.0-beta6] — 2026-09`, never a full date.
3. **Merge each component into its default branch — MANDATORY.** `release-wave.yml` fails closed
   unless every gitlink SHA is an ancestor of that repo's default branch (`git merge-base
   --is-ancestor $sha $default_branch`, else `exit 3`). Push each `pre-release/<version>` branch,
   then **fast-forward or merge-commit** it into `main` and push.
   ⚠️ **Never squash-merge:** a squash creates a new commit and orphans the branch tip, so the
   umbrella's gitlink stops being reachable and the wave refuses to tag *all* components.
   Re-pin the umbrella gitlinks to the merged SHAs and commit the umbrella before tagging.
   Verify per repo: `git merge-base --is-ancestor <gitlink-sha> origin/main && echo OK`.
   The workflow creates the component tags itself — do **not** pre-push them.
   Before the umbrella tag, `wfl pre-release --all` must be READY. From beta8 on, that includes the
   release audit's gate (`wfl audit:check <version> --gate`, the `[[release-audit]]` skill).
4. **Umbrella tag → dry-run → LIVE:**
   - Push the **umbrella** tag to the remote.
   - The dispatch **dry-run checks out `ref:<tag>`**, so the tag **must already exist on the remote**
     before the dry-run runs.
   - ⚠️ **Pushing the umbrella tag auto-fires the LIVE wave.** There is no "dry-run first then push" —
     the push *is* the trigger. Treat the push as the point of no return.
5. **Verify** Packagist resolves each package at the new version; confirm the wave's CI is green.

## New components in a wave
When a release introduces packages (beta7: `queue`, `openapi`, `serializer`, `testing`):
- **Scaffold** each from `component-template` (`[[component-scaffold]]`). The tooling reads the
  component list from `.gitmodules` (`scripts/list-components.sh`), so no script needs registering.
- **Register each on Packagist before its first tag.**
- **Add each to `RELEASE_INCLUDE`** in `.github/workflows/release-wave.yml` once it ships code (23 → up
  to 27). A newcomer without code — for instance one moved to beta8 by the capacity split — stays out.

## Around the tag
- **Relock the workspace** after committing the component changes and before tagging:
  `workspace/composer.lock` records the path-repository HEADs.
- **Write the release-day records:** `project_system/Logs/Releases/Log_<Release>.md` and
  `Logs/Retrospectives/Retro_<Release>.md` (`[[roadmap-steward]]`).

## RC1 and Gold
- **RC1 is `1.0.0-RC1`**, never `0.1.0-RC1`, cut from `pre-release/1.0.0-RC1` in every component;
  `release/1.0.0` follows.
- **`[RC-06]` wave rehearsal:** the full protocol on the RC tag, validating Packagist metadata for every
  `RELEASE_INCLUDE` repo, including the newcomers' first stable-channel publication
  (`[[rc-certification]]`).
- **Gold** is `1.0.0` on the soaked RC SHA set with zero code delta. A delta means RC2, and the
  four-week soak restarts.

## Execution
```bash
# per component (loop): prove green, branch, stamp, tag — see release-manager
# then, once ALL are pushed:
git tag <umbrella-tag> && git push origin <umbrella-tag>   # ⚠️ fires the LIVE wave
```
> The person's request for the release ("release beta7", "run the wave") is the go-ahead for the
> whole protocol, umbrella tag included (AGENTS.md §6). The `waffle-cockpit` guard lets through only
> the tag named by its `releaseTag` option. If it refuses, ask the person to set `releaseTag` to that
> version in their user settings. Never work around the guard. Stop and ask when the tag name, the
> component set or a gate result is in doubt: the push is the point of no return.
