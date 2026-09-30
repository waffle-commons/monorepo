---
name: api-freeze
description: "[Beta8 — the API freeze] Spike verdicts ([SPK-01..03]), contracts BC review + contracts/BC-POLICY.md ([FRZ-01]), deprecation sweep ([FRZ-02]), naming & convention pass ([FRZ-03]) and the 7-point freeze exit gate; after the beta8 tag, only bug fixes"
compatibility: opencode
---

## What I do
I run the freeze. The beta8 tag **is** the feature freeze, and `waffle-commons/contracts` becomes the
v1 API. Everything in beta8 is must-ship: an item that slips leaves v1 for `Roadmap_Post_v1.md`; it
does not slip into RC1. See `[[contracts-first]]`, `[[rc-certification]]`, `[[roadmap-steward]]`,
`[[security-audit]]`, `[[soak-endurance]]`, `[[diataxis-doc]]`.

## When to use
"API freeze", "BC review", "BC-POLICY", "deprecate X", "naming pass", "is this change allowed after the
freeze?", "spike verdict", beta8 AXE 1–2, the freeze exit gate.

## 1. Spike verdicts (`[SPK-01..03]`)
ASYNC-01 (Fiber deferral), REACTIVE-01 (write-hook broadcast) and AUTH-01 (WebAuthn) shipped as
production code in beta5. Beta8 records the formal verdict:
- **Go:** the item keeps its gates — full DoD, its benchmark record, and for AUTH-01 green W3C test
  vectors plus a passed security audit.
- **No-go:** removal before RC1, and a formal cut into `Roadmap_Post_v1.md` and the master roadmap's
  non-goals.

A half-implemented authentication scheme never ships in v1. Record each verdict and its evidence in
`Roadmap_Beta8.md` (`[[roadmap-steward]]`).

## 2. Contracts BC review (`[FRZ-01]`)
- **Scope:** every interface, class, enum, attribute, DTO, exception and constant in `contracts/src` —
  158 files in 28 namespaces on 2026-09-30, plus whatever beta7 adds. Each symbol is **confirmed**
  (frozen for v1.x) or **fixed now**.
- **Per symbol:**
  - final naming;
  - explicit parameter, return and property types (the beta4 `[ARCH-01]` bar, no `mixed`);
  - no leaked implementation (no sibling concrete class, vendor SDK or transport type in a signature);
  - complete PHPDoc semantics (preconditions, failure modes through contract exception interfaces, side
    effects, `extends ResettableInterface` when request-scoped);
  - extensibility — adding a method to an interface later breaks every implementer.
- **Parallelise per namespace** with the `bc-reviewer` agent and merge its tables into one ledger before
  fixing anything. Fixes follow contracts-first and ripple to consumers in the same wave
  (`wfl sync:contracts`, then gate each consumer).
- **`contracts/BC-POLICY.md`** (new file) states:
  - what the BC promise covers: interfaces, DTO shapes, enums, attributes, exception interfaces;
  - what it doesn't: `@internal` symbols, and component classes unless stated;
  - how deprecation works;
  - the SemVer rules from `1.0.0`.
  Every README links to it at RC1 (`[RC-03]`).
- **Marker baseline:** on 2026-09-30 contracts carries **no** `@internal`, `@deprecated`, `TODO` or
  `FIXME`. The exit gate requires zero TODO/FIXME, and every `@internal` added must be deliberate.

## 3. Deprecation sweep (`[FRZ-02]`)
Everything superseded during the beta series is deprecated in beta8 and **removed in RC1**
(`[RC-02]`): v1.0 ships zero deprecated symbols.

Engine rules, verified on PHP 8.5.11:
- Native `#[\Deprecated(message: '…', since: '0.1.0-beta8')]` works on **functions, methods, class
  constants, enum cases, global constants and traits**.
- It is a **fatal error** on **classes, interfaces, enums and properties**. For those, use a
  `@deprecated <reason>; use <replacement>` docblock, and list the symbol in the CHANGELOG and
  `BC-POLICY.md`.

How to sweep:
- Search both forms: `rg -F -e '#[\Deprecated' -e '@deprecated'` across `*/src`.
- Update the callers of each symbol, found with `wfl xref <Symbol> --tests`.
- Skeleton, workspace and the Academy labs move to the final APIs in the same wave
  (`[[demo-app-wiring]]`).

## 4. Naming & convention pass (`[FRZ-03]`)
One sweep across all components:
- namespaces (`Waffle\Commons\*`, `Waffle\Commons\Contracts\*`);
- exception hierarchies (every thrown exception implements a contracts exception interface);
- config key naming;
- console command names as `domain:action`;
- error response shapes.

The command names shipped today form the baseline:
- `cache:clear`, `container:compile`, `data:warmup`, `db:migrate`;
- `make:{command,controller,dto,entity,event-pair,http-client,middleware,repository,voter}`;
- `route:compile`, `route:list`, `security:audit`.

Beta7 adds `queue:work`, `openapi:generate` and the migration commands (their names are still open —
`[[k8s-ops]]`). An inconsistency found after v1 is permanent.

## 5. After the freeze (beta8 tag → Gold)
- **Allowed:** bug fixes with regression tests, security fixes, documentation, and deprecation
  **removal** in RC1.
- **Not allowed:** new features, new public symbols, signature changes, renames. "It's small" is no
  exception: that work belonged to beta8, and the freeze date moves instead (`Roadmap_RC1.md`).
- `code-review` treats a public-API change after the tag as **Blocking**.

## Freeze exit gate
Re-verified as RC1's entry gate (`[RC-01]`):
1. Zero open spike decisions; `Roadmap_Post_v1.md` updated with every cut.
2. `contracts/` BC review 100 % complete; `BC-POLICY.md` published; zero TODO/FIXME in contracts.
3. 72 h soak: zero memory drift, zero leaked connections/transactions, zero un-injected 5xx
   (`[[soak-endurance]]`).
4. Security audit: zero open criticals; report archived in `project_system/` (`[[security-audit]]`).
5. EcoShield-Gateway benchmark report produced; RAM factor documented (`[[ecoshield]]`).
6. Docs complete for all components; Academy labs green against beta8 (`[[diataxis-doc]]`,
   `wfl academy:test`).
7. Standard gates everywhere: `composer mago && composer tests`, ≥95 % coverage, zero baselines,
   `wfl igor` 0 KO.

Verify with the `acceptance-verifier` agent (scope: the beta8 freeze exit gate). Every point needs
evidence, not a statement.
