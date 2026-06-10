---
title: "Waffle Ecosystem Roadmap: Intelligence, Routing & Automation (Beta 2)"
date_created: 2026-02-12
date_updated: 2026-05-27
type: project
status: 🟢 done
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🗺️ Waffle Ecosystem Roadmap: Intelligence, Routing & Automation (Beta 2)  
  
**Target Release:** `v0.1.0-beta2`  
  
**Theme:** Cognitive Architecture, Bulletproof CI/CD & Robust Routing  
  
**Status:** `Proposed`  
  
**Author:** Lead DevSecOps & Principal Systems Architect  
  
**Reference RFCs:** RFC-012 (Console), RFC-018 (DX), RFC-020 (Maker), RFC-021 (Auth Bridge)  
  
## 1. Executive Summary  
  
While Waffle `v0.1.0-beta1` successfully established the "Zero-Debt" framework foundations and introduced the core transparent proxy requirements (specifically `waffle-commons/http-client`), its deployment revealed crucial stability, configuration, and automation bottlenecks. The automated release workflows failed on Git submodule bounds, the skeleton template shipped with tight Kernel coupling, and the router lacked standard HTTP verb restriction.  
  
**Waffle Beta 2** is the consolidation, intelligence, and hardening release. It focuses on transforming the monorepo into an automated fortress, introducing advanced REST routing safeguards, deploying a structured AI prompt workspace, and establishing a flawless local developer experience (DX).  
  
## 2. Phase-by-Phase Execution Plan  
  
### 🚨 Phase 1: Robust REST Routing & Hardening (P0)  
  
_The routing engine must be upgraded to support strict HTTP method matching, route overloading, and standard-compliant error handling._  
  
- Attribute and Contract Upgrades (`contracts`):  
  
  - Harden the `#[Route]` attribute to accept an array of allowed HTTP methods: `public array $methods = ['GET']`.  
  
  - Create the `MethodNotAllowedExceptionInterface` (exposing `getAllowedMethods(): array`).  
  
- Overloaded Route Resolution (`routing`):  
  
  - Refactor `Router::matchRequest()` to implement a dual-pass matching loop.  
  
  - Allow the same path pattern to map to different controllers depending on the HTTP method (e.g., `GET /api/resources` vs. `POST /api/resources`).  
  
  - Ensure that if a path matches but no candidate supports the requested HTTP method, a strict `MethodNotAllowedException` is thrown carrying the unique, merged list of accepted methods.  
  
- RFC-Compliant HTTP 405 & Allow Header (`error-handler`):  
  
  - Configure `JsonErrorRenderer` to catch `MethodNotAllowedExceptionInterface`.  
  
  - Enforce the insertion of the standard `Allow` response header containing the comma-separated list of allowed methods (e.g., `Allow: GET, POST`) on any HTTP 405 error response.  
  
  
## 🤖 Phase 2: Workspace Cognitive Architecture & AI Manifesto (P1)  
  
_We must structure and automate how AI agents (such as Claude Code or local LLMs) interact with our monorepo to maintain zero technical debt._  
  
- Claude Entry Point Refactor (`CLAUDE.md`):  
  
  - Condense the root `CLAUDE.md` to under 50 lines to act strictly as a high-speed CLI cheat sheet and redirection router.  
  
- The AI Manifesto (`AGENTS.md`):  
  
  - Create a global `/AGENTS.md` file specifying strict PHP 8.5 coding conventions (asymmetric visibility, property hooks, typed constants), FrankenPHP worker statelessness rules, and the "Zero-Baseline" Mago Purge Protocol.  
  
- Upgraded and Specialized Skills (`.opencode/skills/`):  
  
  - **Audit and Hardening:** Ensure `mago-purge`, `security-audit`, and `diataxis-doc` are fully aligned.  
  
  - **New Skill - `maker-scaffold`**: Specializes in generating zero-debt code using Waffle Maker (RFC-020) and enforces strict English standards for the core components, while supporting localized templates for the skeleton.  
  
  - **New Skill - `auth-bridge-audit`**: Handles security reviews for the Universal Authentication Bridge (RFC-021).  
  
  - **New Skill - `data-persistence`**: Specializes in the stateless Universal Data & Persistence Layer (RFC-022).  
  
  
## 🚀 Phase 3: Self-Healing & Idempotent Release Wave (P1)  
  
_The distributed submodule tagging and release workflow must be made completely bulletproof to eliminate manual release operations._  
  
- Submodule Authentication & URL Rewrite (`.github/workflows/`):  
  
  - Refactor `release-wave.yml` to dynamically parse `.gitmodules` and rewrite submodule remote URLs to HTTPS paths authenticated with the release Personal Access Token (PAT).  
  
- Pre-Flight Git Pointer Assertions:  
  
  - Add a validation step verifying that each submodule local SHA pinned by the monorepo is fully pushed and is an ancestor of the remote `origin/main` branch before creating any release tags.  
  
- Absolute Re-run Recovery & Idempotency:  
  
  - Ensure that if a wave release fails mid-flight, re-running the workflow skips already-tagged submodules or already-created GitHub Releases without throwing halting errors.  
  
- Log Masking & Rate Limit Mitigation:  
  
  - Enforce strict token masking (`::add-mask::`) on all dynamic git remote URLs.  
  
  - Introduce a mild sequential back-off delay (2–5 seconds) between submodule API releases to prevent triggering GitHub's API rate limits.  
  
  
## 🐛 Phase 4: Skeleton Correction & Decoupling (P2)  
  
_The starter skeleton must be patched to act as a production-grade showcase of the framework's decoupled architecture._  
  
- Kernel Decoupling Fix (`skeleton`):  
  
  - Refactor `src/Factory/AppKernelFactory.php` to resolve core workflow services (such as the `ControllerDispatcher` and `ControllerArgumentResolver`) through the container instead of direct, tight `new` instantiations.  
  
- Demonstration of Property Hook Validation:  
  
  - Implement a clean, read-only DTO class `HelloInput` inside `HelloController.php` marked with the `#[Dto]` attribute.  
  
  - Use native PHP 8.5 Property Hooks on `HelloInput` properties (e.g., verifying that `{name}` is non-empty) to prove that the `ControllerArgumentResolver` successfully hydrates and triggers native domain-level validation.  
  
- Catch-All Routing Demo:  
  
  - Expose a low-priority catch-all route mapped to a proxying showcase.  
  
  
## 🛠️ Phase 5: Local DX Tooling & Git Hooks (P2.5)  
  
_The developer tooling must be finalized to ensure seamless cross-component development._  
  
- Automated Component Linking (`bin/wfl`):  
  
  - Implement `wfl link <consumer> <provider>` and `wfl unlink <consumer> <provider>`.  
  
  - These commands must dynamically edit the consumer's `composer.json` using secure, in-container inline PHP scripts to inject/remove the relative local `path` repository, and run `composer update` on the modified dependency.  
  
- Path-Repository Push Protection (pre-commit):  
  
  - Update `scripts/hooks/pre-commit-mago.sh` to parse staged `composer.json` files.  
  
  - If any `"type": "path"` or relative `"url": "../` keys are detected, **instantly block the commit**, output a clear error message in **English**, and instruct the developer to run `wfl unlink`.  
  
- Profiler Profile Toggling:  
  
  - Ensure `wfl debug` (Xdebug active, JIT off) and `wfl bench` (JIT active, Xdebug off) profiles restart the worker process instantly and cleanly.  
  
  
## 🛑 Definition of Done (DoD) for Beta 2  
  
1. **REST Compliance:** Route overloading works. Requests targeting registered paths with unhandled HTTP methods return a strict HTTP 405 error with a valid, non-empty `Allow` header.  
  
2. **Zero-Debt Static Analysis:** All 15 components pass `mago lint`, `mago analyze`, and `mago guard` with exactly `0` errors, `0` warnings, and zero baseline files.  
  
3. **Idempotent CI/CD:** Pushing an umbrella tag executes `release-wave.yml` successfully on a dry-run, showing clean credentials masking and self-healing skip logic.  
  
4. **Decoupled Skeleton:** The skeleton boots and resolves its Kernel factories with zero hardcoded service instantiations, showing 100% green tests.  
  
5. **Secure Commits:** The Git pre-commit hook successfully prevents committing local composer symlinks.  
  
6. **Localization:** All core framework CLI logs, exceptions, and developer feedback are rendered in **English** to ensure international standard compliance, while the skeleton may feature French code comments and outputs to mark its "French Tech" heritage.