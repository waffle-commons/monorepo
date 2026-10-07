---
name: code-review
description: "Review new or modified code in one component: standards (PHP 8.5, security, perimeter) and spec"
when_to_use: >-
  "Review my changes", a pre-merge or pre-commit sanity check, reviewing a component's diff, or
  checking an implementation against its roadmap item's acceptance criteria. Runs per component (git
  diff inside the submodule).
argument-hint: "[component]"
---

## What I do
Review **new or modified** code in the Waffle-Commons monorepo. Produce a concise, actionable report enforcing PHP 8.5 strict standards, security constraints, and PSR compliance.

## Scope constraint & Monorepo/Submodule Context
The `waffle-commons` codebase is a monorepo managing independent Git submodules. Each component is an autonomous Git repository released independently on Packagist.
Before taking any action or reviewing code, you must first identify the specific component you are modifying. 

**CRITICAL RULE:** At the umbrella root, `git diff` shows only the gitlinks. Read the component's own diff by absolute path (`{umbrella}` is the absolute path of the umbrella checkout):
```bash
git -C {umbrella}/{component} diff
```
Only review or integrate files that were created or meaningfully changed within the context of that specific component's Git repository.

## Two axes, reported separately
A change can follow every rule and still build the wrong thing, or build exactly what was asked
while breaking the rules. Review it on two axes and never let one mask the other:
- **Standards**: does the diff follow this repository's rules? (the checklist below)
- **Spec**: does the diff do what its roadmap item or RFC asked, no more and no less?

For a large diff, run each axis in its own subagent so the two reviews do not contaminate each
other, then put the reports side by side.

## Axis 1: Standards (this repository's rules)

### Architecture & Layering
- [ ] Component only depends on `waffle-commons/contracts` (+ `waffle-commons/utils`), not concrete implementations of other components.
- [ ] Any new interface landed in `contracts` **before** its consumer (contracts-first sequencing).
- [ ] Conforms strictly to required PSR standards (PSR-15, PSR-14, PSR-3, PSR-7/17).
- [ ] Service is stateless and safe for FrankenPHP Resident Memory worker mode — `wfl igor` 0 KO; any mutable per-request state class **directly** implements `ResettableInterface` or carries `#[WorkerSafe]`.
- [ ] No native PHP sessions or `sys_get_temp_dir()` calls used.

### PHP 8.5 Standards & Types
- [ ] `declare(strict_types=1);` is present on the very first line of the file.
- [ ] No `mixed` types used.
- [ ] All constants are strictly typed.
- [ ] Property Hooks used for DTO validation instead of legacy getters/setters.
- [ ] Asymmetric Visibility (`public private(set) type $name`) and `readonly` classes used for immutability.
- [ ] No directly accessed superglobals (e.g., `$_SERVER`, `$_POST`); uses `GlobalsFactory` or PSR-7 HTTP objects.

### Security & Error Handling
- [ ] Throws specific Waffle exceptions (e.g., `ValidationException`, `SecurityException`) meant to be caught by `ErrorHandlerMiddleware`.
- [ ] No `@` error-control operators used (insecure).

### Testing & Static Analysis
- [ ] Tests use PHPUnit 12.5+ (no expectation-less-mock notices — concrete spy or `#[AllowMockObjectsWithoutExpectations]`; `tests/` is Mago-linted too).
- [ ] `composer mago` emits **zero output** — no errors, **and no warnings, info, or help/notice messages**.
- [ ] **Critical:** No `mago-*-baseline.toml` files added or modified. The "Mago Purge Protocol" mandates zero tolerance for baselines.

### Documentation
- [ ] If applicable, documentation in `waffle-commons/documentation/` is updated.
- [ ] Documentation updates respect the Diátaxis framework (Tutorials, How-to, Reference, Explanation).
- [ ] Modern PHP attributes and hooks are documented with their real shapes — the contracts attributes are `#[Route]`, `#[Dto]`, `#[Voter]`, `#[PublicAccess]`, `#[RequiresCsrfToken]` and `#[Broadcast]` (there is no `#[Rule]` attribute).

### Release phase
- [ ] The change is allowed in the current phase (`tech-lead` §0). After the beta8 tag, any new public symbol, signature change or rename is **Blocking**.
- [ ] A deprecation uses the form the engine accepts: native `#[\Deprecated]` on functions, methods, class constants, enum cases, constants and traits; a `@deprecated` docblock on classes, interfaces, enums and properties (the attribute is a fatal error there — `api-freeze`).

### Judgement calls (smell baseline)
Name a smell only as a heuristic ("possible Feature Envy"), quote the hunk, and never grade it
**Blocking**. A documented rule of this repository always wins over the baseline, and anything Mago
already enforces is skipped.
- **Mysterious name**: the name does not say what the thing does or holds. Rename it.
- **Duplicated code**: the same logic shape in two hunks or files. Extract it once.
- **Feature envy**: a method that works mostly on another object's data. Move it there.
- **Data clumps / primitive obsession**: fields that travel together, or a string standing in for a
  domain concept. Give the concept its own small (readonly) type.
- **Shotgun surgery / divergent change**: one change scattered over many files, or one file changed
  for unrelated reasons. Regroup by reason to change.
- **Speculative generality**: a parameter, hook or abstraction no requirement asks for. Delete it.
- **Middle man / message chains**: a class that only delegates, or `a->b()->c()->d()` reach-through.
  Call the real target, or hide the walk behind one method.

## Axis 2: Spec (did we build what was asked?)
1. **Find the spec.** In this order: the roadmap item id in the commit messages, branch or request
   (`[NET-01]`, `[CARRY-10]` …) and its acceptance criteria in `project_system/Roadmaps/`; the RFC
   section it implements in `project_system/RFCs/`; a spec path the user gave. If none exists, ask.
   If the user says there is none, report "no spec available" and skip this axis.
2. **Compare the diff with it**, quoting the criterion for each finding:
   - requirements that are missing or only partly done;
   - behaviour nobody asked for (scope creep, or a feature after the freeze);
   - requirements that look implemented but behave wrongly.
3. **Proving** a roadmap item done needs evidence (tests, command output). That belongs to the
   `acceptance-verifier` agent. This axis only reviews the code against the spec.

## Output format
Report the two axes under `## Standards` and `## Spec`. Do not merge or re-rank findings across axes.
Inside each axis, group findings by severity:

**Blocking** — must fix before merge (type error, security issue, architectural violation, Mago baseline usage, FrankenPHP memory leak risk, a missing or wrong acceptance criterion)  
**Important** — should fix (style violation, missing PHPUnit 12.5 test, lack of property hooks, unrequested scope)  
**Suggestion** — optional improvement (naming, minor simplification, a judgement-call smell)

If there are no findings in a category, omit it. End with one line per axis giving its worst issue,
then a one-line verdict: `Approved`, `Approved with suggestions`, or `Changes required`.
