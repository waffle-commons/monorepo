---
name: tech-lead
description: "Entry point for non-trivial work: phase-aware orchestration of coding, test, review and acceptance"
when_to_use: >-
  Any non-trivial, multi-skill, multi-component or ambiguous request; deciding what the current
  release phase (beta8 freeze, then RC1) allows; when unsure which skill applies.
---

## What I do
I am the entry point for non-trivial Waffle-Commons changes. I sequence tasks and ensure nothing ships
without passing Dockerized tests, strict Mago analysis, the worker-safety audit and architectural
review — and I check that the work is allowed in the current release phase.

## 0. Which phase are we in?
Read `AGENTS.md` §5b and the status line of the current roadmap first. Beta7 shipped in November 2026;
beta8, the freeze, has been the current phase since its branches were cut on 2026-11-20.

| Phase | Branch | What is allowed | Skills |
|---|---|---|---|
| **beta8 — consolidation & API freeze** (current) | `pre-release/0.1.0-beta8` | spike verdicts, BC fixes, deprecations, the naming pass, soak and audit fixes, docs — **no new capability** | `api-freeze`, `soak-endurance`, `release-audit`, `security-audit`, `diataxis-doc`, `ecoshield` |
| **after the beta8 tag: RC1 — certification** | `pre-release/1.0.0-RC1` | bug fixes with regression tests, security fixes, docs; then `[RC-02]` deprecation removal and `[RC-03]` packaging | `rc-certification`, `soak-endurance`, `release-audit` |

**Beta8 guard:** every beta8 item is must-ship. An item that slips leaves v1 for `Roadmap_Post_v1.md`; it
never slides into RC1. Raise the risk early; the decision is the maintainer's.

**Dates:** the beta8 tag lands no earlier than ~8 December 2026. The maintainer sets the date at the
audit's triage (~26–28 November); plan on the central case, ~21 December. RC1 and Gold move by the same
amount (central case: RC1 ~30 December, Gold ~mid-February 2027). `AGENTS.md` §5b keeps "~3 Dec" until
the date is set.

## Orchestration protocol
1. **Triage:** decide whether the task needs `coding`, `refactoring` or `test`, plus the capability
   skill for the roadmap item. For anything touching `project_system/` direction, consult
   `roadmap-steward` first.
2. **Plan before acting:** identify the affected submodules. Sequence contracts-first
   (`contracts-first`): any new interface lands in `waffle-commons/contracts` before its consumer, and
   dependencies point only to `contracts` (+ `utils`). Large multi-repo work gets an Action Plan first,
   and file edits wait for the maintainer's "proceed".
3. **Execute:** load `coding` or `refactoring`. Strict PHP 8.5 types, Property Hooks, stateless design
   for FrankenPHP (`worker-safety`).
4. **Test:** load `test`. PHPUnit 12.5 coverage ≥95 %.
5. **Review:** load `code-review`. PSR compliance, zero-output Mago, `wfl igor` 0 KO, and no public-API
   change after the freeze.
6. **Accept:** for a roadmap item, dispatch the `acceptance-verifier` agent on the item's acceptance
   criteria. Code that passes its unit tests but not the roadmap criterion is not done.

## Definition of done
Run **`wfl dod [component]`** to execute the full gate (mago + tests + coverage + igor) in one shot. A
task is done when:
- [ ] `docker exec -w /waffle-commons/{component} waffle-dev composer tests` passes for all modified components (PHPUnit 12.5, ≥95% coverage).
- [ ] `docker exec -w /waffle-commons/{component} waffle-dev composer mago` emits **zero output** — no errors, warnings, info, or help messages.
- [ ] `wfl igor` reports **0 KO** across the affected components (worker-safety gate).
- [ ] The Mago Purge Protocol is respected (no baseline files exist or were modified).
- [ ] `code-review` verdict is `Approved`.
- [ ] Architecture remains completely stateless and decoupled (dependent only on `contracts` + `utils`).
- [ ] For a roadmap item: its acceptance criteria verified with evidence (`acceptance-verifier`).
