---
title: "Waffle Ecosystem Roadmap: (RC 1)"
date_created: 2026-06-07
date_updated: 2026-06-07
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
  - release
aliases: []
---
# 🧇 WAFFLE-COMMONS — RELEASE CANDIDATE ROADMAP v1.0.0-RC1

> **Status:** Pending Validation — Draft
> 
> **Target Tag:** Mid-February 2027 · **Soak window:** tag → mid-March 2027 (≥4 weeks)
> 
> **Core Mandate:** Prove that nothing needs changing. An RC adds **zero** features — it certifies the beta7 freeze under real conditions. If RC1 needs anything beyond a bug fix, that work was beta7's and the freeze date moves; it does not leak into the RC.
> 
> **Versioning:** tagged `1.0.0-RC1` (not `0.1.0-RC1`) — the RC certifies the v1 API and must order correctly for Composer. Branch: `pre-release/1.0.0-RC1` in every component.

## 🏁 AXE 1: FREEZE CERTIFICATION

### `[RC-01]` Beta7 Exit-Gate Re-Verification

- Re-run the entire beta7 freeze exit checklist on the RC1 tree. Any failure is a freeze regression → fix is the only permitted change.
    

### `[RC-02]` Deprecation Removal

- Delete every symbol marked `#[Deprecated]` in beta7. v1.0 ships with zero deprecated code. Skeleton, workspace, Academy, and EcoShield-Gateway must compile and pass against the post-removal tree.
    

### `[RC-03]` Final Packaging Pass

- Every component's `composer.json`: PHP `>=8.5` constraint, inter-component constraints pinned to `^1.0@RC` then `^1.0`, license/authors/description/keywords complete, `support` links live.
    
- README + CHANGELOG finalized per component (the per-component release branches carry exactly this).
    
- SemVer strict officially starts at the `1.0.0` tag; `BC-POLICY.md` linked from every README.
    

## 🛡️ AXE 2: PRODUCTION SOAK — ECOSHIELD-GATEWAY

### `[RC-04]` Four-Week Gateway Soak (success indicator #4)

- EcoShield-Gateway runs the full Strangler-Fig scenario on RC1 continuously for ≥4 weeks: production-like traffic profile, chaos injections (upstream outages → breaker behavior, Redis restarts → limiter/queue recovery, rolling restarts → drain correctness).
    
- **Pass:** zero critical incidents, zero memory drift, SLOs held (p99 latency, error budget). This soak **is** the v1 adoption criterion (replaces Sentinel).
    

### `[RC-05]` Launch-Asset Benchmark Re-Run

- Re-run the beta7 FinOps benchmark on the RC bits — published launch numbers must come from the RC, not a beta.
    

## 🔁 AXE 3: RELEASE REHEARSAL

### `[RC-06]` Wave Dry-Run Discipline

- Full release-wave rehearsal on the RC tag (umbrella tag pushed → dry-run on the pushed tag → LIVE), validating Packagist metadata for all 26 components, including the four beta6 newcomers' first stable-channel publication.
    

## ⚠️ RC2 CONTINGENCY CLAUSE

- **RC2 is never planned — only triggered.** Trigger: a **critical** defect found during the soak (security, data corruption, crash, memory drift). Cosmetic and minor issues ride to 1.0.1.
    
- If triggered: fix + targeted regression tests only, re-tag `1.0.0-RC2`, and **restart the 4-week soak clock** (a soak interrupted by a critical fix proved nothing). This pushes Gold by ~5 weeks — acceptable; shipping the defect is not.
    

## ✅ ACCEPTANCE CRITERIA — GOLD ENTRY GATE

1. Soak completed uninterrupted: ≥4 weeks, zero criticals.
2. All components pass gates on the exact RC SHA set (no post-tag drift).
3. Wave rehearsal green end-to-end; Packagist pages verified for all 26 components.
4. Benchmark + audit reports archived; launch numbers sourced from RC bits.
5. `Roadmap_v1_Gold.md` launch checklist unblocked.
