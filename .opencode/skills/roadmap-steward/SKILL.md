---
name: roadmap-steward
description: Maintain project_system/ (RFCs + Roadmaps) as the direction source of truth — version-stamp convention, what's git-tracked, plan-first discipline for waves
compatibility: opencode
---

## What I do
I keep `project_system/` coherent — it is the **source of truth for project direction**. I read it
before planning roadmap work, and I maintain RFCs/Roadmaps without corrupting pinned history or the
gitignore boundary. See `[[diataxis-doc]]` (code docs), `[[release-wave]]` (executing a roadmap).

## When to use
"what's the plan for beta-N", "which RFC covers X", "amend the roadmap", "draft an RFC", "what ships in
v1", any planning that needs the canonical direction.

## The map
- **`project_system/RFCs/`** — `RFC_001 … RFC_022` (Core/Runtime, Security/ABAC, HTTP, Events, Logging,
  Errors, DI, Routing, Config, Contracts/Utils, DTOs, Console, Cache, Data, Async, OpenAPI, Advanced
  Security, DX, AOT, Maker, Universal Auth Bridge, Universal Data Layer).
- **`project_system/Roadmaps/`** — `Roadmap_v1_Master` (the release train) + per-release
  `Roadmap_Beta0…Beta8`, `Roadmap_RC1`, `Roadmap_v1_Gold`, `Roadmap_Post_v1`.
- **Train (post-BBL pivot, 2026-07):** beta4 (security/stability, shipped) → beta5
  (AOT/pooling/async/telemetry/WebAuthn, shipped) → beta6 (**stabilization & audit**: multi-engine
  audits, Diátaxis docs, EcoShield POC, K6 — shipped) → beta7 (**production surface**, current:
  `queue`/`openapi`/`serializer`/`testing`, NET, OPS) → beta8 (freeze) → `1.0.0-RC1`
  (EcoShield-Gateway 4-week soak) → `1.0.0` Gold. Dates (one-month slip, 2026-09-06): beta6 Sep 2026 ·
  beta7 Oct · beta8 Nov · RC1 Dec · Gold Jan 2027. Only beta6 lands before the API Platform
  Conference (Lille, Sep 17–18 2026), which drove the original train.
  EcoShield-Gateway (not Sentinel) is the v1 validation dogfood.

## Git boundary
Inside `project_system/`, `RFCs/`, `Roadmaps/`, and `Logs/` **are git-tracked** — roadmap edits have
real history and belong on the current `pre-release/<version>` branch (use `git mv` to rename tracked
roadmap files). **Only** `Audits/`, `Notes/`, `TODOs/`, and `*.pem` are gitignored (per
`project_system/.gitignore`). The user drives all commits/pushes — edit and stage, but never commit.

## Conventions
- **Version stamps:** `0.1.0-betaN` — **no `v` prefix** (the tag gate rejects a leading `v`). Fix the
  **current**-version stamp when something ships; **never bulk-bump** historical CHANGELOGs or
  `Waffle_Evolutions` — that history is pinned. Historical `Beta-N` prose stays as written.
- **Release dates:** month-precision `YYYY-MM`, never `YYYY-MM-DD`. CHANGELOG headings read
  `## [0.1.0-beta6] — 2026-09`; roadmap headers and release logs use the month and year in prose
  ("September 2026", "**Target Release:** **September 2026**"). Only the current release is stamped —
  shipped entries keep the date they were written with. Non-release dates (front-matter
  `date_created`/`date_updated`, audit and execution-status dates, conference dates) keep full
  `YYYY-MM-DD` precision.
- **Language:** English (these are framework-direction docs, not template apps).
- **Plan-first for waves:** large multi-repo work gets an **Action Plan first**; edit files only after
  explicit approval. Convert relative dates to absolute when recording decisions.

## Authoring an RFC / amending a roadmap
Mirror the existing front-matter (`title`/`date_created`/`date_updated`/`type`/`status`/`tags`). Keep
acceptance criteria measurable (gates, not vibes). Honor contracts-first sequencing and the standard
DoD in every item: `composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO.
