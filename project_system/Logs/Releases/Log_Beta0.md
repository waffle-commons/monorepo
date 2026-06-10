---
title: "Log Beta 0"
date_created: '2026-05-16'
date_updated: '2026-05-16'
type: project
status: archived
tags:
  - waffle
  - beta0
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-beta0

> [!SUMMARY]
> Goal: "Zero Debt, Maximum Control" — consolidate the strictness/hardening work into the Beta 0 line, eradicate all static-analysis baselines, and lock the architectural perimeter before the EcoShield proof of concept.

## 1. Technical Changelog (What changed)

### 🧹 The Mago Purge (Zero-Baseline)

- Eradicated every `mago-analyzer-baseline.toml` / `mago-linter-baseline.toml`.
    
- Hunted and fixed 200+ typing and covariance errors across the 14 existing components. Static analysis is now pure.
    

### 🏰 Mago Guard (The Fortress)

- Each component declares its architectural perimeter in `mago.toml` (`[guard.perimeter]`). Illegal cross-component coupling and circular dependencies are physically blocked in CI; everything depends only on `waffle-commons/contracts`.
    

### 🐘 PHP 8.5 Modernization

- Systematic asymmetric visibility (`public private(set)`) and typed constants across the core classes; obsolete getters removed.
    

### 📦 Data Integrity

- Self-validating `readonly` DTOs via PHP 8.5 **Property Hooks**; invalid data is rejected at the source with a `ValidationException` rendered as RFC 7807 `422`. The `ControllerArgumentResolver` hydrates DTOs from the PSR-7 body, triggering the hooks.
    

### 🆕 New Components

- **`waffle-commons/console`** (CLI): `cache:clear`, `route:list`, `security:audit`.
    
- **`waffle-commons/cache`** (PSR-6/16): `ArrayCache`, `FileCache`, `RedisCache`; `RouteCache` refactored onto the standardized component.
    

## 2. Quality Gate (Exit Criteria)

- [x] **Mago pure:** `mago analyze` + `mago guard` exit `0` across the ecosystem, zero baseline files.
    
- [x] **Tests:** 710 tests / 1422 assertions green.
    
- [x] **Coverage:** ≥ 95% lines on every package (including the new `cache`).
    
- [x] **Versions:** 15 components unified at `0.1.0-beta0`.
    

## 3. Release

- [x] Umbrella tag → **v0.1.0-beta0** (the canonical name for this consolidation release).
    

## 4. Post-Mortem & Next Steps

- **Win:** foundational R&D is complete — Waffle is an industrial, 100%-strict, zero-debt engine, certified across 15 components.
    
- **Next step:** [Roadmap Beta 1](../../Roadmaps/Roadmap_Beta1.md) — the PSR-18 HTTP client and worker-native security remediation for the EcoShield gateway.
