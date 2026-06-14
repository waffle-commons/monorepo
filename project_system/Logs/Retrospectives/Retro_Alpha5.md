---
title: Retrospective Alpha 5
date_created: 2026-05-02
date_updated: 2026-05-02
type: project
status: archived
tags:
  - project
  - retro
  - waffle
  - alpha5
aliases: []
---
# ⏪ Retrospective: Waffle Alpha 5 (The "Sentient" Release)

**Date:** May 2, 2026 **Author:** Lead DevSecOps & Architect

## 1. The Goal

Alpha 4 left a capable but **blind** framework: a PSR-15 pipeline with no observability and only theoretical security. Alpha 5 set out to give the engine eyes (logs), shields (active defense), and a nervous system (events).

## 2. What Shipped

- **`waffle-commons/log`** — native PSR-3 `StreamLogger`, structured JSON to stdout/stderr.
- **`waffle-commons/event-dispatcher`** — PSR-14 lifecycle hooks (`RequestReceived`, `Terminate`, …).
- **`SecurityMiddleware`** — made the `#[Rule]` ABAC attributes actually blocking, wired into the default stack.
- **Hardening** — RouteCache RCE fix (fail-secure cache dir) and Trusted-Hosts anti-poisoning.

## 3. What Went Well

- **Defense-in-depth landed.** The independent audit graded the result "Sentinel-grade" effective Zero-Trust, with total component cohesion — security is enforced *before* controller code runs.
- **Cloud-native from day one.** JSON logs aligned the framework with K8s/Datadog without a heavyweight logger.

## 4. What To Improve

- **Typing debt crept in.** To move fast, some typing was lax and the static analyzers leaned on `baseline` files — a compromise we refused to ship long-term.
- **Worker boot loop.** The auditor flagged `AbstractKernel::handle()` re-booting per request as a worker-mode performance killer.
- **No CLI.** Operating the framework (cache clear, route introspection) was impossible without a console.

## 5. Conclusion

Alpha 5 made Waffle observable and defensible — but it also revealed that we would not build on indebted foundations. The next release was redirected into a radical strictness pass: the **Mago Purge**, shipped as [Beta 0](../Roadmaps/Roadmap_Beta0.md).
