---
title: Retrospective Beta 1
date_created: 2026-05-25
date_updated: 2026-05-25
type: project
status: archived
tags:
  - project
  - retro
  - waffle
  - beta1
aliases: []
---
# ⏪ Retrospective: Waffle Beta 1 (Remediation & Proxying)

**Date:** May 25, 2026 **Author:** Lead DevSecOps & Architect

## 1. The Goal

With Beta 0's zero-debt foundation in place, Beta 1 had two jobs: close the worker-native security gaps surfaced by the post-Beta 0 audit, and build the outbound **proxy engine** required to make Waffle the EcoShield gateway.

## 2. What Shipped

- **Hotfixes** — removed insecure `unserialize()` (cache RCE) and the `putenv()` global mutation (worker isolation), replacing the latter with a read-only config registry.
- **Decoupling** — `AbstractKernel` resolves its terminal handler from the container; the `ReflectionTrait` was eradicated into dedicated services.
- **`waffle-commons/http-client`** — a PSR-18 client tuned for FrankenPHP: non-blocking cURL-multi transfer and bounded-memory streaming in both directions.

## 3. What Went Well

- **OWASP gaps closed.** No unfiltered deserialization, no process-global env mutation — the framework is safe to run as a resident worker.
- **Proxy unblocked.** Waffle can now both receive and emit HTTP without pinning a worker thread, the prerequisite for transparent proxying.

## 4. What To Improve

- **Release friction.** The distributed submodule tagging workflow stumbled on Git bounds and manual steps.
- **Coupled skeleton.** The starter template still wired its kernel by hand.
- **Routing gaps.** The router could not restrict HTTP verbs (no standard `405`).

These three pain points became the Beta 2 backlog (CI/CD automation, skeleton decoupling, robust REST routing).

## 5. Conclusion

Beta 1 turned a secure HTTP *receiver* into a secure HTTP *gateway*. The remaining work was about industrializing the release process and polishing the developer experience — the focus of [Beta 2](../Roadmaps/Roadmap_Beta2.md).
