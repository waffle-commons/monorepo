---
title: "Log Beta 2"
date_created: '2026-05-29'
date_updated: '2026-05-29'
type: project
status: archived
tags:
  - waffle
  - beta2
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-beta2

> [!SUMMARY]
> Goal: Cognitive architecture, bulletproof CI/CD, and robust routing — turn the monorepo into an automated fortress with a flawless local developer experience.

## 1. Technical Changelog (What changed)

### 🚦 Robust REST Routing

- `#[Route]` now accepts an allowed-methods array (`methods: ['GET', ...]`); new `MethodNotAllowedExceptionInterface` (`getAllowedMethods()`).
    
- `Router::matchRequest()` does dual-pass matching / **route overloading** (same path, different controller per HTTP method).
    
- `JsonErrorRenderer` emits RFC-compliant `405` with a standard `Allow: GET, POST` header.
    

### 🤖 Cognitive Architecture & AI Manifesto

- `CLAUDE.md` condensed to a < 50-line CLI router; new `/AGENTS.md` manifesto (PHP 8.5 conventions, FrankenPHP statelessness, Zero-Baseline Mago Purge Protocol).
    
- New `.opencode/skills/`: `maker-scaffold`, `auth-bridge-audit`, `data-persistence` (+ aligned `mago-purge`, `security-audit`, `diataxis-doc`).
    

### 🚀 Self-Healing Release Wave (CI/CD)

- `release-wave.yml` made idempotent: dynamic submodule remote URL rewrite with PAT masking (`::add-mask::`), pre-flight Git-pointer ancestry assertions, re-run recovery (skips already-tagged submodules/releases), and API rate-limit back-off.
    

### 🐛 Skeleton Decoupling

- `AppKernelFactory` resolves the `ControllerDispatcher` / `ControllerArgumentResolver` through the container (no manual `new`); `HelloInput` `#[Dto]` demonstrates Property-Hook validation; low-priority catch-all proxy route exposed.
    

### 🛠️ Local DX Tooling

- `wfl link` / `wfl unlink` (in-container path-repository wiring), pre-commit protection blocking committed local path repos, and `wfl debug` (Xdebug) / `wfl bench` (JIT) profile toggling.
    

## 2. Quality Gate (Exit Criteria)

- [x] **REST compliance:** unhandled verbs return `405` with a valid `Allow` header.
    
- [x] **Zero-debt:** all 15 components pass `mago lint`/`analyze`/`guard` with 0 errors, 0 warnings, 0 baselines.
    
- [x] **Idempotent CI/CD:** `release-wave.yml` dry-run clean with masking + self-healing skips.
    
- [x] **Decoupled skeleton:** boots with zero hardcoded service instantiations, 100% green tests.
    
- [x] **Localization:** core CLI logs/exceptions in English; skeleton keeps its French heritage.
    

## 3. Release

- [x] Umbrella tag → **v0.1.0-beta2**.
    
- [x] Housekeeping re-tag → **v0.1.0-beta2.1** (2026-05-30; lockstep, no source changes).
    

## 4. Post-Mortem & Next Steps

- **Win:** the monorepo is now self-healing and AI-legible, the router is standards-compliant, and the skeleton showcases the decoupled architecture.
    
- **Next step:** [Roadmap Beta 3](../../Roadmaps/Roadmap_Beta3.md) — the Universal Authentication Bridge and the stateless Data & Persistence layer.
