---
title: "Roadmap Alpha 5 (Observability & Stability)"
date_created: '2026-01-20'
date_updated: '2026-01-20'
type: project
status: active
tags:
  - observability
  - roadmap
  - waffle
  - project
  - security
  - refactoring
aliases: []
---
# 🗺️ Operational Battle Plan: Alpha 5 (The "Sentient" Release)

**Target:** v0.1.0-alpha5 **Theme:** Observability, Defense & Events **Philosophy:** "If it crashes, I want to know why (Logs) and I want to be able to react (Events)."

## 🏗️ Phase 1: Cleanup & Hardening (The Foundation)

_Before adding floors, we reinforce the concrete._

### 1.1 Securing the Cache (RCE Fix) ✅

- **Problem:** `sys_get_temp_dir()` is shared on mutualized servers. An attacker could modify the PHP cache file.
    
- **Action:** Modify `waffle-commons/routing/src/Cache/RouteCache.php`.
    
- **Spec:**
    
    - Inject the `var/cache` directory path via the constructor (coming from `Kernel::getCacheDir()`).
        
    - If `var/cache` is not writable, throw an `InvalidConfigurationException` (Fail Secure) rather than falling back to `/tmp`.
        

### 1.2 "Trusted Hosts" Protection (Anti-Poisoning) ✅

- **Problem:** Currently, `$_SERVER['HTTP_HOST']` is trusted. Risk of injecting malicious links into emails (password reset).
    
- **Action:** Modify `waffle-commons/http` and `waffle-commons/config`.
    
- **Spec:**
    
    - Add `trusted_hosts: []` in `config/app.yaml`.
        
    - In `ServerRequestFactory`, check whether the `Host` header matches the list.
        
    - If no match -> immediate `400 Bad Request` (even before routing).
        

## 👁️ Phase 2: Observability (The Eyes)

_The most critical component for production._

### 2.1 New Component: `waffle-commons/log` ✅

- **Standard:** PSR-3 (`Psr\Log\LoggerInterface`).
    
- **Implementation:** `StreamLogger`.
    
    - Do not use Monolog (too heavy for now).
        
    - Write directly to `php://stdout` and `php://stderr` (Docker-native format).
        
- **Format:** Structured JSON (to be parsed by Datadog/CloudWatch).
    
`{"level": "error", "message": "...", "context": {...}, "timestamp": "..."}`
    

### 2.2 Core Integration ✅

- **Action:** Inject `LoggerInterface` into `AbstractKernel` and `ErrorHandlerMiddleware`.
    
- **Behavior:**
    
    - Every Exception caught by the ErrorHandler MUST be logged with its stack trace.
        
    - Every incoming request MUST generate an "Access" log (Method, URL, IP, Response Code, Duration).
        

## ⚡ Phase 3: Nervous System (Event Dispatcher)

_To decouple the Core from future features._

### 3.1 New Component: `waffle-commons/event-dispatcher`

- **Standard:** PSR-14 (`EventDispatcherInterface`).
    
- **Design:** A simple `ListenerProvider` (a map of events to callables).
    

### 3.2 Lifecycle Wiring

- **Action:** Modify `waffle/src/Kernel.php`.
    
- **Events to create:**
    
    1. `RequestReceivedEvent` (before routing).
        
    2. `ControllerArgumentsResolvedEvent` (before the controller call).
        
    3. `ResponseGeneratedEvent` (before sending).
        
    4. `TerminateEvent` (after sending, for heavy tasks).
        

## 🛡️ Phase 4: Active Defense (Security Middleware)

_Make the `#[Rule]` attributes actually blocking._

### 4.1 Security Middleware ✅

- **Action:** Create `SecurityMiddleware` in `waffle-commons/security`.
    
- **Logic:**
    
    1. Intercept the request.
        
    2. Retrieve the `#[Rule]` attribute on the current route (via `$request->getAttribute(Route::class)`).
        
    3. Call `SecureContainer::check(Rule)`.
        
    4. On failure (`SecurityException`) -> let the `ErrorHandlerMiddleware` turn it into a 403.
        

### 4.2 Automatic Wiring ✅

- **Action:** Add `SecurityMiddleware` to the default stack of `AbstractKernel`.
    
- **Critical order:** `ErrorHandler` > `Routing` > `Security` > `Controller`.
    

## 🧹 Phase 5: Release & DX

_The finishing touch._

### 5.1 Skeleton Update

- Add `waffle/log` and `waffle/event-dispatcher` to the skeleton's `composer.json`.
    
- Configure the default logger in `config/services.yaml` (if we implement service injection via YAML, otherwise via Factory).
    

### 5.2 Documentation

- Update the `how-to/security.md` section (currently theoretical) to confirm it works.
    
- Document how to create an `EventListener`.
    

## 📅 Suggested Sequencing

1. **Week 1:** Phase 1 (Hardening) + Phase 2 (Logger). _This is the most urgent._
    
2. **Week 2:** Phase 3 (Event Dispatcher).
    
3. **Week 3:** Phase 4 (Security Middleware).
    
4. **Week 4:** Integration, Tests & Release Alpha 5.
