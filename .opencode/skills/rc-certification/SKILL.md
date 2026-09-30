---
name: rc-certification
description: "[RC1 — 1.0.0-RC1] Freeze certification: beta8 exit gate re-run on the RC tree ([RC-01]), deprecation removal ([RC-02]), final packaging pass ([RC-03]), gateway soak + launch benchmark on RC bits ([RC-04/05]), wave rehearsal ([RC-06]); RC2 only on criticals; the Gold entry gate"
compatibility: opencode
---

## What I do
I certify that nothing needs changing. An RC adds **zero features**: if RC1 needs more than a bug fix,
that work belonged to beta8 and the freeze date moves; it does not leak into the RC. See
`[[api-freeze]]`, `[[soak-endurance]]`, `[[ecoshield]]`, `[[release-wave]]`,
`[[release-manager]]`.

## When to use
"RC1", "release candidate", "1.0.0-RC1", "packaging pass", "do we need an RC2?", "can we go Gold?",
December 2026 work.

## Naming and schedule
- **Tag `1.0.0-RC1`**, never `0.1.0-RC1`: the RC certifies the v1 API and must sort correctly for
  Composer.
- **Branches:** `pre-release/1.0.0-RC1` in every component, then `release/1.0.0`.
- **Tag by ~5 December 2026** for a January 2027 Gold: the ≥4-week soak starts at the tag.
- **Holidays:** the soak straddles the year-end holidays, so incident response must be staffed.
- **Slips:** a beta8 slip moves RC1 and Gold by the same amount. **The soak is never shortened to
  recover a date.**

## The items
- **`[RC-01]` Exit-gate re-verification.** Re-run the 7-point beta8 freeze exit gate
  (`[[api-freeze]]`) on the RC tree. A failure is a freeze regression, and its fix is the only
  permitted change. Collect the evidence with the `acceptance-verifier` agent.
- **`[RC-02]` Deprecation removal.** Delete every symbol deprecated in beta8, in both forms
  (`#[\Deprecated]` attribute and `@deprecated` docblock). Skeleton, workspace, Academy and EcoShield must
  compile and pass against the post-removal tree.
- **`[RC-03]` Packaging pass**, per component `composer.json`:
  - PHP constraint: the roadmap says `>=8.5` while every package declares `^8.5` today. Decide one form
    and apply it everywhere.
  - Inter-component constraints: `^1.0@RC` for the RC, then `^1.0` for Gold.
  - Metadata complete: license, authors, description, keywords; `support` links live.
  - README and CHANGELOG final; `BC-POLICY.md` linked from every README. Strict SemVer starts at
    `1.0.0`.
  - Tooling: `wfl pre-release` checks the README stamp and the `## [1.0.0-RC1]` CHANGELOG entry (it infers
    the version from `pre-release/1.0.0-RC1`); `wfl ci:check` checks descriptions and toolchain drift.
    Nothing checks the remaining composer fields yet, so review them per component.
- **`[RC-04]` Four-week gateway soak**: `[[soak-endurance]]`, `[[ecoshield]]`.
- **`[RC-05]` Launch benchmark re-run**: the beta8 FinOps benchmark (`[GATE-03]`) re-run on the RC bits.
  Launch numbers must come from the RC.
- **`[RC-06]` Wave rehearsal**: umbrella tag pushed → dry-run on the pushed tag → LIVE, validating
  Packagist metadata for every `RELEASE_INCLUDE` repo. That is 23 today and 27 once `queue`, `openapi`,
  `serializer` and `testing` ship code, including their first stable-channel publication. Mechanics are
  in `[[release-wave]]`; every git, tag and push step is the maintainer's.

## RC2 contingency — triggered, never planned
- **Trigger:** a **critical** defect during the soak — security, data corruption, crash, memory drift.
  Cosmetic and minor issues ride to `1.0.1`.
- **If triggered:** the fix plus targeted regression tests only; re-tag `1.0.0-RC2`; **restart the
  four-week clock**. Gold moves by ~5 weeks — acceptable; shipping the defect is not.

## Gold entry gate (`Roadmap_RC1.md`)
1. Soak completed uninterrupted: ≥4 weeks, zero criticals.
2. All components pass gates on the **exact RC SHA set** (no post-tag drift).
3. Wave rehearsal green end to end; Packagist pages verified for every `RELEASE_INCLUDE` repo.
4. Benchmark and audit reports archived; launch numbers sourced from RC bits.
5. `Roadmap_v1_Gold.md` launch checklist unblocked.

Gold is `1.0.0` on the soaked SHA set with **zero code delta**; any delta means RC2, not Gold.
