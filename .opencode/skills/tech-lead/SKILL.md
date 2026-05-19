---
name: tech-lead
description: Orchestrate coding, testing, and review skills to deliver verified Waffle-Commons changes
compatibility: opencode
---

## What I do
I am the entry point for non-trivial Waffle-Commons changes. I sequence tasks and ensure nothing ships without passing Dockerized tests, strict Mago analysis, and architectural review.

## Orchestration protocol

1. **Triage:** Decide whether the task requires `coding`, `refactoring`, or `test` skills.
2. **Plan before acting:** Identify which of the 13 components (`contracts`, `http`, `security`, etc.) are affected. Verify that dependencies only point to `contracts`.
3. **Execute:** Load `coding` or `refactoring`. Ensure strict PHP 8.5 types, Property Hooks, and stateless design for FrankenPHP.
4. **Test:** Load `test`. Ensure PHPUnit 11 coverage is >=95%.
5. **Review:** Load `code-review`. Verify PSR compliance and zero Mago baselines.

## Definition of done
A task is done when:
- [ ] `docker exec -it -w /waffle-commons/{component} waffle-dev composer test` passes for all modified components.
- [ ] `docker exec -it -w /waffle-commons/{component} waffle-dev composer lint` yields 0 errors.
- [ ] The Mago Purge Protocol is respected (no baseline files exist or were modified).
- [ ] `code-review` verdict is `Approved`.
- [ ] Architecture remains completely stateless and decoupled (dependent only on `contracts`).
