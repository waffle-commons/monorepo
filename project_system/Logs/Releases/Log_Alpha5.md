---
title: "Log Alpha 5"
date_created: '2026-05-02'
date_updated: '2026-05-02'
type: project
status: archived
tags:
  - waffle
  - alpha5
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-alpha5

> [!SUMMARY]
> Goal: "The Sentient Release" — give the framework **eyes** (observability), **shields** (active defense), and a **nervous system** (events), so a worker-mode failure can be seen and reacted to.

## 1. Technical Changelog (What changed)

### 👁️ Observability

- **New component `waffle-commons/log`:** native PSR-3 `StreamLogger` emitting structured JSON to `php://stdout` / `php://stderr` (Docker/Cloud-native). No Monolog dependency.
    
- **Core integration:** `LoggerInterface` injected into `AbstractKernel` and `ErrorHandlerMiddleware`. Every caught exception is logged with its stack trace; every request emits an access log (method, URL, IP, status, duration).
    

### ⚡ Events

- **New component `waffle-commons/event-dispatcher`:** PSR-14 dispatcher with a simple `ListenerProvider`.
    
- **Lifecycle hooks:** `RequestReceivedEvent`, `ControllerArgumentsResolvedEvent`, `ResponseGeneratedEvent`, `TerminateEvent` wired into the kernel.
    

### 🛡️ Active Defense

- **`SecurityMiddleware`** added to `waffle-commons/security`, making the `#[Rule]` attributes actually blocking (failure → `SecurityException` → 403 via the error handler). Wired into the default stack: `ErrorHandler > Routing > Security > Controller`.
    

### 🔒 Hardening

- **RouteCache RCE fix:** cache directory injected via the constructor; a non-writable `var/cache` now raises `InvalidConfigurationException` (fail-secure) instead of falling back to `/tmp`.
    
- **Trusted Hosts (anti-poisoning):** `trusted_hosts` configuration + `Host` header validation; a non-matching host is rejected with `400` before routing.
    

## 2. Quality Gate (Exit Criteria)

- [x] **Coverage:** ≥ 95% lines across all components.
    
- [x] **Green build:** PHPUnit green ecosystem-wide.
    

## 3. Release

- [x] Tag all components → **v0.1.0-alpha5** (lockstep).
    

## 4. Post-Mortem & Next Steps

- **Win:** the framework is no longer blind — structured logs, lifecycle events, and enforced ABAC are in place.
    
- **Debt incurred:** typing was occasionally lax and the static analyzers leaned on `baseline` files — flagged for eradication.
    
- **Next step:** [Roadmap Beta 0](../../Roadmaps/Roadmap_Beta0.md) — the "Mago Purge" (Zero-Baseline) and PHP 8.5 strictness pass.
