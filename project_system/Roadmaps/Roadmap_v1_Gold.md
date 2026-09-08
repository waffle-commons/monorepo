---
title: "Waffle Ecosystem Roadmap: (v1.0 Gold)"
date_created: 2026-06-07
date_updated: 2026-09-08
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
  - release
aliases: []
---
# 🧇 WAFFLE-COMMONS — GOLD RELEASE ROADMAP 1.0.0

> **Status:** Pending Validation — Draft
> 
> **Target Release:** January 2027 — re-dated 2026-09-06 for the one-month train slip; see `Roadmap_v1_Master.md`
> 
> **Core Mandate:** The launch itself. No engineering scope — every line of code shipped in RC1. Gold is packaging, publication, policy, and announcement.

## 🚀 AXE 1: THE RELEASE

### `[GOLD-01]` The 1.0.0 Wave

- Tag `1.0.0` on the soaked RC SHA set (zero code delta from the certified RC — if there is a delta, you are not at Gold, you are at RC2).
    
- Full wave: umbrella tag → dry-run → LIVE across every repo in the `RELEASE_INCLUDE` allow-list (27 with the four beta7 newcomers); verify Packagist stable channel for each.
    

### `[GOLD-02]` Support & Versioning Policy

- Publish the v1.x support policy: BC promise scope (per `contracts/BC-POLICY.md`), security-fix window, release cadence for 1.x minors, and the `release/1.0.x` maintenance-branch rule (created lazily, on the first backport need — per the established branching model).
    

## 🌍 AXE 2: PUBLIC PRESENCE

### `[LAUNCH-01]` Documentation Site

- `documentation/` (Diátaxis, completed in beta8) published online with versioned docs (v1.0 selector from day one), the beta→1.0 upgrade guide, and the generated OpenAPI reference for the demo apps.
    

### `[LAUNCH-02]` Production Starter Pack

- "Production Ready" kit: Docker Compose + FrankenPHP worker-mode config, Kubernetes manifests wired to `/healthz`/`/readyz` and graceful drain, GitHub Actions CI template (mago + tests + igor gates), `.env` conventions.
    
- The skeleton app `composer create-project` path verified end-to-end on a clean machine.
    

### `[LAUNCH-03]` Launch Material

- The EcoShield-Gateway story as flagship case study: Strangler-Fig architecture, FinOps benchmark (RC-sourced numbers), and the "Audit & Rescue" packaging — productizing that offer is itself post-v1 (`Roadmap_Post_v1.md` §4).
    
- Announcement post + Academy as the public on-ramp (`/academy` labs against v1.0).
    

## 📊 AXE 3: SUCCESS INDICATORS — FINAL VERIFICATION

Sign-off against the master roadmap, in writing, in `project_system/`:

1. **Stability:** ≥95% coverage everywhere, 100% on `contracts`/`security`/`auth`/`http`, zero baselines, igor 0 KO. ☐
2. **Performance:** <10ms p99 hello-world (worker mode, prod build); memory-growth slope ~10× lower per concurrent request vs PHP-FPM, with the measured total-RAM factor and crossover point published (RC benchmark — the former bare "5–10×" claim was reframed by beta6 `[BENCH-05]`). ☐
3. **Security:** zero known criticals on the final surface (beta8 audit + RC soak). ☐
4. **Adoption:** EcoShield-Gateway ≥4-week RC soak passed. ☐
5. **Completeness:** gap table in `Roadmap_v1_Master.md` fully closed or formally moved to non-goals. ☐

## 🔮 DAY-2 (immediately post-Gold)

- Open the 1.1 planning cycle from the refreshed `Roadmap_Post_v1.md` backlog (whatever beta7/beta8 cut: spike rejects (beta8 verdicts), mailer transports (beta7 `[QUEUE-03]`), extra queue drivers, additional content negotiation formats).
    
- First community feedback triage window: two weeks of issue-only focus before any 1.1 feature work.
