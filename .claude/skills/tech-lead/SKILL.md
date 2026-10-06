---
name: tech-lead
description: "Entry point for non-trivial work: phase-aware orchestration of coding, test, review and acceptance"
when_to_use: >-
  Any non-trivial, multi-skill, multi-component or ambiguous request; deciding what the current
  release phase (beta7 build, beta8 freeze, RC1) allows; when unsure which skill applies.
---

## What I do
I am the entry point for non-trivial Waffle-Commons changes. I sequence tasks and ensure nothing ships
without passing Dockerized tests, strict Mago analysis, the worker-safety audit and architectural
review — and I check that the work is allowed in the current release phase.

## 0. Which phase are we in?
Read `AGENTS.md` §5b and the status line of the current roadmap first.

| Phase | Branch | What is allowed | Skills |
|---|---|---|---|
| **beta7 — production surface** (October 2026, current) | `pre-release/0.1.0-beta7` | the `Roadmap_Beta7.md` items: NET, QUEUE, OPS, API, TEST, the `[CARRY-*]` follow-ups, the stretch tier last | `resilience-net`, `queue-worker`, `k8s-ops`, `api-surface`, `testing-bridge`, `ecoshield` |
| **beta8 — consolidation & API freeze** (November 2026) | `pre-release/0.1.0-beta8` | spike verdicts, BC fixes, deprecations, the naming pass, soak and audit fixes, docs — **no new capability** | `api-freeze`, `soak-endurance`, `security-audit`, `diataxis-doc`, `ecoshield` |
| **RC1 — certification** (December 2026) | `pre-release/1.0.0-RC1` | bug fixes only, deprecation removal, packaging | `rc-certification`, `soak-endurance` |

Work that belongs to an earlier phase is never squeezed in. In beta7 the stretch tier (`[DXP-01]`,
`[GATE-02]`) is cut first. After the beta8 tag, a feature is post-v1 (`Roadmap_Post_v1.md`).

**Beta7 capacity guard:** unless `[API-01]`, `[API-02]` and `[TEST-01]` have **code landed and green on
their own gates by mid-October**, the release splits: NET + OPS + QUEUE tag as beta7, and API + TEST
fold into the beta8 window. Raise the risk early; the decision is the maintainer's.

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
