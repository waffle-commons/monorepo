---
title: Retrospective Beta 4
date_created: 2026-06-13
date_updated: 2026-06-13
type: project
status: archived
tags:
  - project
  - retro
  - waffle
  - beta4
aliases: []
---
# ⏪ Retrospective: Waffle Beta 4 (Security Hardening & RC Readiness)

**Date:** June 13, 2026 **Author:** Lead Software & DevSecOps Architect

## 1. The Goal

Beta 3 turned Waffle into an enterprise-grade application ecosystem (federated identity + stateless
persistence). Beta 4 was the hardening wave: convert the framework-audit findings deliberately
deferred from Beta 3 into a fail-closed, Release-Candidate-grade security posture, stabilize the
architecture for resident-worker mode, polish the developer experience, and land the in-repo Academy
as BBL demo material.

## 2. What Shipped

- **AXE 1 — Security.** Session-ID rotation + cryptographic CSRF identity-binding, default-on SSRF
  guard with `CURLOPT_RESOLVE` IP pinning, a timing-attack audit + `compare-audit` scanner,
  fail-closed CORS, and path-traversal guardrails in `Assert`.
- **AXE 2/3 — Architecture & Diagnostics.** Stream fd-ownership safety, typed kernel lifecycle events,
  an interface-based response converter (`ResponseFactoryAwareInterface`), a standalone uploads
  normalizer; plus a boot-time state-reset `ComplianceScanner` and a dev-only orphaned-connection
  tracer. STB-02 buffer pooling was deferred on benchmark evidence.
- **AXE 4/5 — DX & Academy.** `bin/wfl` vs `bin/waffle` separation with `check:all` / `monorepo:sync`,
  non-intrusive git hooks, FrankenPHP hot-reload + Starship, the `mb_trim` sweep, and a mockable
  `ValidatorInterface`; the Academy (`labs` / `sandbox` / `obsidian`) with the `academy:test` grading
  engine.

## 3. What Went Well

- **Fail-closed by default.** SSRF and CORS both reject unless something is *explicitly* allow-listed —
  no permissive default waiting to be forgotten.
- **Two-layer worker safety.** Runtime `igor` (0 KO) and the new boot-time `ComplianceScanner` catch
  state pollution from two independent angles before it can ship.
- **Evidence-based deferral.** STB-02 was gated on a real GC-churn benchmark rather than intuition; the
  statelessness mandate won, with the decision recorded in the tree.
- **Contracts-first held.** The two new interfaces (`ResponseFactoryAwareInterface`,
  `ValidatorInterface`) landed in `contracts/` ahead of their consumers; `mago guard` kept the
  perimeter clean.

## 4. What To Improve

- **Sweep code generators, not just code.** The `mb_trim` migration initially missed the maker's
  `PropertyHookGenerator`, which was seeding bare `trim()` into every scaffolded DTO. It surfaced only
  in the pre-release conformance audit. Lesson: a refactor's blast radius includes the templates that
  emit code, and they deserve first-class sweep + test coverage.
- **Docker hook latency.** The `<150ms` pre-commit goal is met natively but not through `docker exec`;
  accepted as an environment cost rather than re-architected for beta4.
- **Ship the doc with the feature.** Fail-closed CORS shipped before its how-to existed; pairing a
  feature with its Diátaxis page in the same wave avoids a documentation backfill.

## 5. Conclusion

Beta 4 makes Waffle a credible Release-Candidate platform: the audit gaps are closed fail-closed,
worker safety is double-gated, and onboarding ships inside the repo. The remaining polish is small and
tracked. Next: [Beta 5](../../Roadmaps/Roadmap_Beta5.md) — the async, observability, and AOT research
spikes on the road to RC1 and V1 Gold.
