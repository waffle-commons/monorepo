---
name: release-manager
description: "Per-component release steps inside the umbrella wave (Packagist, version stamps, readiness)"
when_to_use: >-
  Preparing one component for a release, release readiness (wfl pre-release), CHANGELOG entries and
  version stamps, the RC1 packaging pass [RC-03]. Never a release out of band unless explicitly
  asked.
---

## What I do
I handle the **per-component** mechanics of a release: each component is its own submodule published
on Packagist. In Waffle, all components ship **together** as a coordinated **umbrella wave** (one
`pre-release/<version>` branch per component, one umbrella tag) — I am the per-component half of that;
`[[release-wave]]` owns the orchestration. I never release a single component out of band unless
explicitly told to.

## Per-component release steps

For **each** component in the wave:

1. **Address the component by absolute path:** `{umbrella}/{component}` on the host (`{umbrella}` is the
   absolute path of the umbrella checkout), `/waffle-commons/{component}` in the container:
   ```bash
   git -C {umbrella}/{component} status --short --branch
   ```

2. **Prove it is green (definition of done):**
   ```bash
   docker exec -w /waffle-commons/{component} waffle-dev composer mago    # ZERO output
   docker exec -w /waffle-commons/{component} waffle-dev composer tests   # PHPUnit 12.5, ≥95%
   docker exec -w /waffle-commons/{component} waffle-dev composer igor    # 0 KO
   ```

3. **Sync release metadata** on the `pre-release/<version>` branch: composer constraints across
   sibling packages, `README`, `CHANGELOG` (stamp the **current** version only — see
   `[[diataxis-doc]]` / `[[roadmap-steward]]` — never bulk-bump history).
   The heading carries a **month-precision** date — `## [0.1.0-beta6] — 2026-09`, never `YYYY-MM-DD`.

4. **Tag — NO `v` prefix.** Tags are bare SemVer (`0.1.0-beta4`, `1.0.0-RC1`, `1.0.0`); the tag gate
   rejects a leading `v`. In an umbrella wave **the workflow creates and pushes each component's tag**
   from the pinned gitlink — never pre-push them. A manual component tag exists only for an explicitly
   requested out-of-band release, and the maintainer runs it:
   ```bash
   git -C {umbrella}/{component} tag 0.1.0-betaN        # NOT v0.1.0-betaN — out-of-band only, maintainer-run
   git -C {umbrella}/{component} push origin 0.1.0-betaN
   ```

5. **Packagist sync:** once the tag is on the remote, Packagist auto-syncs. Confirm the version
   resolves before moving on. A new package must be registered on Packagist **before** its first tag.

## Release-readiness check
`wfl pre-release <component>` (or `--all`, driven by `RELEASE_INCLUDE`) runs the DoD and checks that the
README carries the current version stamp and the CHANGELOG has a `## [<version>]` entry. It infers the
version from the `pre-release/<version>` branch, so it works for `1.0.0-RC1` as well.

When it runs with `--all`, it also holds the release on its audit, for beta8 and every later minor,
major or RC release: `wfl audit:check <version> --gate` must pass (the `[[release-audit]]` skill).
A patch release is exempt. `WFL_AUDIT_VERSION=<other>` points the gate at the run that covers this
release, such as the RC's run for a Gold that changes no code.

## RC1 packaging pass (`[RC-03]`)
Per component `composer.json`, on `pre-release/1.0.0-RC1`:
- **PHP constraint:** the roadmap says `>=8.5`, while every package declares `^8.5` today. Apply the form
  the maintainer picks, everywhere.
- **Sibling constraints:** `^1.0@RC` during the RC, then `^1.0` for Gold.
- **Metadata:** license, authors, description, keywords and `support` links complete and live.
- **README + CHANGELOG** final, with a link to `contracts/BC-POLICY.md`.

`wfl pre-release` and `wfl ci:check` cover the stamps, descriptions and toolchain; nothing checks the
other fields yet, so review them by hand (`[[rc-certification]]`).

> ⚠️ Pushing the **umbrella** tag auto-fires the LIVE wave, and the dispatch dry-run checks out
> `ref:<tag>` (the tag must already exist on the remote). Coordinate via `[[release-wave]]` — do not
> push tags ad hoc.
