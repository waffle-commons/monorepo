---
title: "Log Alpha 4"
date_created: '2026-01-20'
date_updated: '2026-01-20'
type: project
status: archived
tags:
  - waffle
  - alpha4
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-alpha4

> [!SUMMARY] 
> Goal: Finalize the transition to the **Pipeline (PSR-15)** architecture and reach **Zero Technical Debt** before starting development of the Sentinel demo.

## 1. Technical Changelog (What changed)

### 🏗️ Core Architecture

- **Pipeline** PSR-15 **:** The `Kernel` no longer calls the Router directly. It delegates to a `MiddlewareStack`.
    
- **Agnostic Orchestration:** Wiring via `AppKernelFactory`. The Core no longer knows the concrete implementations.
    
- **Breaking change:** Controllers must now return a `ResponseInterface` (or be converted by the Dispatcher).
    

### ⚙️ Configuration & Environment

- **Native DotEnv:** Creation of the `.env` loader in `waffle-commons/config`.
    
- **Environment** Aware **:** `index.php` dynamically detects `APP_ENV` (Prod/Dev). No more hardcoding.
    
- **YAML Config:** Strict use of the PECL `yaml` extension for performance.
    

### 🛡️ Error Handling

- **RFC 7807:** Integration of the `JsonErrorRenderer`.
    
- **Middleware:** `ErrorHandlerMiddleware` placed at `prepend()` to catch everything.
    

## 2. Quality Gate (Exit Criteria)

Before tagging, these indicators must be green.

### A. Unit Tests (PHPUnit)

_Target: Green Build + 95% Coverage._

- [x] **Core Tests:** Repaired (mocking the Stack instead of the Router).
    
- [x] **Global Coverage:** Verify that no component dropped below 95%.
    

## 3. Deployment Protocol (Checklist)

_Execute in strict order to avoid Composer conflicts._

### Step 1: Foundations

- [x] Tag `waffle-commons/contracts` -> **v0.1.0-alpha4**
    
- [x] Tag `waffle-commons/utils` -> **v0.1.0-alpha4**
    

### Step 2: Autonomous Components

- [x] Update `composer.json` (require contracts ^0.1.0-alpha4) for:
    
    - [x] `config`
        
    - [x] `http`
        
    - [x] `container`
        
- [x] Tag these 3 repositories -> **v0.1.0-alpha4**
    

### Step 3: Business Components

- [x] Update `composer.json` for:
    
    - [x] `pipeline`
        
    - [x] `routing`
        
    - [x] `security`
        
    - [x] `error-handler`
        
- [x] Tag these 4 repositories -> **v0.1.0-alpha4**
    

### Step 4: The Core (Waffle)

- [x] Update `waffle/composer.json` to require ALL the components above at `^0.1.0-alpha4`.
    
- [x] Commit: "chore: release alpha4".
    
- [x] Tag `waffle` -> **v0.1.0-alpha4**
    

### Step 5: The Skeleton (Workspace)

- [x] Update to use `waffle/waffle: ^0.1.0-alpha4`.
    
- [x] Verify that `AppKernelFactory` is up to date with the `DotEnv` loader.
    
- [x] Tag -> **v0.1.0-alpha4**
    

## 4. Post-Mortem & Next Steps

- **Win:** The framework is now installable and stable.
    
- **Next step:** [Roadmap Alpha 5](../../Roadmaps/Roadmap_Alpha5.md)
