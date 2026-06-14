---
name: tech-lead
description: Orchestrate coding, testing, and review skills to deliver verified Waffle-Commons changes
compatibility: opencode
---

## What I do
I am the entry point for non-trivial Waffle-Commons changes. I sequence tasks and ensure nothing ships without passing Dockerized tests, strict Mago analysis, and architectural review.

## Orchestration protocol

1. **Triage:** Decide whether the task requires `coding`, `refactoring`, or `test` skills. For
   anything touching `project_system/` direction, consult `roadmap-steward` first.
2. **Plan before acting:** Identify which of the 23 submodule components are affected. Sequence
   contracts-first (`contracts-first` skill) — any new interface lands in `waffle-commons/contracts`
   before its consumer. Verify dependencies only point to `contracts` (+ `utils`).
3. **Execute:** Load `coding` or `refactoring`. Ensure strict PHP 8.5 types, Property Hooks, and
   stateless design for FrankenPHP (`worker-safety` skill).
4. **Test:** Load `test`. Ensure PHPUnit 12.5 coverage is >=95%.
5. **Review:** Load `code-review`. Verify PSR compliance, zero-output Mago, and `wfl igor` 0 KO.

## Definition of done
A task is done when:
- [ ] `docker exec -it -w /waffle-commons/{component} waffle-dev composer tests` passes for all modified components (PHPUnit 12.5, ≥95% coverage).
- [ ] `docker exec -it -w /waffle-commons/{component} waffle-dev composer mago` emits **zero output** — no errors, warnings, info, or help messages.
- [ ] `wfl igor` reports **0 KO** across the affected components (worker-safety gate).
- [ ] The Mago Purge Protocol is respected (no baseline files exist or were modified).
- [ ] `code-review` verdict is `Approved`.
- [ ] Architecture remains completely stateless and decoupled (dependent only on `contracts` + `utils`).
