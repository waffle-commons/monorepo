---
name: diataxis-doc
description: Act as the Technical Writer mapping PHP 8.5 codebase details into Diátaxis documentation
compatibility: opencode
---

## What I do
I read PHP 8.5 code across the `waffle-commons` components and produce documentation categorized into
the Diátaxis framework under `documentation/`. Docs must mirror the code **exactly**.

## Diátaxis Quadrants (output under `documentation/`)
- `tutorials/` — learning-oriented, step-by-step.
- `how-to/` — problem-oriented recipes.
- `reference/` — code contracts, DTO properties, attribute specifications.
- `explanation/` — architecture (monorepo of submodules, FrankenPHP statelessness, agnosticism).

## Physical Signature Mandate (exactness)
Documentation MUST reproduce the **exact physical signatures** found in the source — never
paraphrased or invented:
- **Property Hooks:** show the literal `set(Type $value) { … }` block, including the thrown
  `ValidationException`.
- **Asymmetric visibility:** write `public private(set) Type $name` verbatim.
- **`readonly` DTOs & promoted constructors:** show the real constructor with promoted, typed params.
- **Typed constants:** `public const string NAME = '…';`.
- **`#[\Override]`** and attributes (`#[Route]`, `#[Voter]`, `#[PublicAccess]`, `#[Dto]`,
  `#[AsEventListener]`) shown with their real argument shapes.
- **Verify each signature against the file before publishing** — a doc that drifts from the code is
  a bug.

## Core Constraints
- Explicitly explain the PHP 8.5 feature each example uses.
- State that every component depends **only** on `waffle-commons/contracts` (+ `waffle-commons/utils`).
- Cite the source path (`component/src/...`) for non-trivial reference entries.

## Version stamps
- Doc/release version stamps are `0.1.0-betaN` — **no `v` prefix** (matches the no-`v` tag gate).
- Update the **current**-version stamp on a page when its component ships; **never bulk-bump**
  historical `CHANGELOG`/`Waffle_Evolutions` entries or past `Beta-N` prose — that history is pinned.
- The direction these docs track lives in `project_system/` — see `[[roadmap-steward]]`.
