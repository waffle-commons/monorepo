---
title: "Waffle Ecosystem Roadmap: (Beta 7)"
date_created: 2026-06-07
date_updated: 2026-06-07
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP v0.1.0-beta7

> **Status:** Pending Validation — Draft (scope partially determined by beta5 spike outcomes and the beta6 retrospective)
> 
> **Target Release:** End of January 2027 — **the last feature release before v1**. The tag of beta7 *is* the feature freeze.
> 
> **Core Mandate:** Resolve every open decision, soak every deep change, freeze the public API, and re-audit the final security surface. A beta exists to change things; after beta7, nothing changes except bug fixes.
> 
> **Commitment Tiers:** Everything in this roadmap is must-ship — by definition, anything that slips here slips out of v1 entirely (to the post-v1 backlog), not to RC1.

## 🔬 AXE 1: SPIKE RESOLUTION (BETA5 GO/NO-GO DEBT)

_The three beta5 research spikes get their final verdict. "Go" means landing the production implementation here with full gates; "no-go" means a formal cut to the post-v1 backlog, documented in the master roadmap's non-goals._

### `[SPK-01]` `[ASYNC-01]` Fiber-Based Deferred Task Runner — verdict

- Land (with the load-test report's throughput budget enforced) or cut. If cut, the documented alternative is `waffle-commons/queue` (beta6) for everything beyond trivial deferral.
    

### `[SPK-02]` `[REACTIVE-01]` Reactive Write-Hook Observers — verdict

- Land (enqueue-only hooks + middleware flush, Igor-clean) or cut. If cut, SSE/Mercure remains available through explicit event dispatch.
    

### `[SPK-03]` `[AUTH-01]` WebAuthn / Passkeys — verdict

- Land (contracts + `web-auth/webauthn-lib` adapter, W3C test vectors green, security-audit gate passed) or cut to post-v1. **A half-implemented authentication scheme does not ship in a v1.**
    

## 🧊 AXE 2: API FREEZE (THE CENTRAL DELIVERABLE)

### `[FRZ-01]` Contracts BC Review

- **Specification:**
    
    - Exhaustive review of every interface, DTO, enum, and attribute in `waffle-commons/contracts` — each one is either confirmed (frozen for all of v1.x under strict SemVer) or fixed **now**.
        
    - Checklist per symbol: final naming, parameter/return types explicit (beta4 `[ARCH-01]` bar), no leaked implementation details, PHPDoc contract semantics (preconditions, failure modes) complete.
        
    - Produce `contracts/BC-POLICY.md`: what is covered by the BC promise (interfaces, DTO shapes) and what is not (internal classes, `@internal` markers).
        

### `[FRZ-02]` Deprecation Sweep

- **Specification:**
    
    - Everything superseded during the beta series gets `#[Deprecated]` now and **removed in RC1** — v1.0 ships zero deprecated symbols.
        
    - Cross-component grep for usages; skeleton/workspace/Academy templates updated to the final APIs.
        

### `[FRZ-03]` Naming & Convention Consistency Pass

- **Specification:**
    
    - One sweep across all components: namespace conventions (`Waffle\Commons\*` / `Waffle\Contracts\*`), exception hierarchies, config key naming, console command naming (`domain:action`), error response shapes.
        
    - Inconsistencies found after v1 are permanent — this is the last cheap moment.
        

## 🧯 AXE 3: SOAK & STABILIZATION

### `[STAB-01]` Deep-Change Soak Fixes

- **Specification:**
    
    - Dedicated bake time for the invasive beta5/beta6 machinery under sustained load: AOT compiled-vs-runtime container parity (snapshot diffs on real apps), DBAL pool exhaustion/reconnect edge cases, queue worker endurance, breaker/limiter behavior under chaos testing.
        
    - 72h continuous k6 soak on the workspace demo apps + EcoShield-Gateway: zero memory drift (Igor), zero connection leakage, zero 5xx not injected by the chaos scenario.
        

### `[GATE-02]` EcoShield-Gateway Beta + FinOps Benchmark

- **Specification:**
    
    - Execute Phase 3 of `Roadmap_EcoShield_Gateway.md` on beta7: k6 ≥1000 rps, Scenario A (direct legacy PHP-FPM) vs Scenario B (gateway) — RAM ceiling, latency, breaking point.
        
    - The benchmark report is a v1 launch asset **and** the empirical proof for success indicator #2 (5–10× RAM factor).
        

## 🔐 AXE 4: FINAL SECURITY RE-AUDIT

### `[AUD-01]` Full-Surface Audit

- **Specification:**
    
    - Re-run the complete audit (the one that produced the beta4 findings) against the **final** surface: everything beta4 fixed (regression check) plus the new beta5/beta6 attack surface — `/waffle-metrics`, connection pooling, rate limiter storage, queue payload handling, OpenAPI/Swagger dev routes, health endpoints, WebAuthn (if landed), the gateway proxy path (header smuggling, hop-by-hop handling, request smuggling).
        
    - Every finding is fixed in beta7 or formally risk-accepted with sign-off in the audit report. RC1 inherits zero open criticals.
        

## 📚 AXE 5: DOCUMENTATION & ONBOARDING COMPLETION

### `[DOC-01]` Diátaxis Completion

- **Specification:**
    
    - `documentation/` (tutorials / how-to / reference / explanation) covers every component at v1 API state — including the four beta6 newcomers.
        
    - Reference pages generated/verified against frozen contracts; upgrade guide "beta series → 1.0" drafted.
        

### `[DOC-02]` RFC & Internal Doc Reconciliation

- **Specification:**
    
    - Pending rewrites land: RFC-021 universal-auth reframing (RFC/skill/AGENTS), `Roadmap_Post_v1.md` refreshed to remove absorbed items, Academy labs aligned with final APIs.
        

## ✅ ACCEPTANCE CRITERIA — FREEZE EXIT GATE

Beta7 tags only when **all** of the following hold; this checklist is re-verified as RC1's entry gate:

1. Zero open spike decisions; post-v1 backlog updated with every cut.
2. `contracts/` BC review 100% complete; `BC-POLICY.md` published; zero TODO/FIXME in contracts.
3. 72h soak: zero memory drift, zero leaked connections/transactions, zero un-injected 5xx.
4. Security audit: zero open criticals; report archived in `project_system/`.
5. EcoShield-Gateway benchmark report produced; RAM factor documented.
6. Docs complete for all components; Academy labs green against beta7.
7. Standard gates everywhere: `composer mago && composer tests`, ≥95% coverage, zero baselines, `wfl igor` 0 KO.
