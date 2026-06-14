---
title: "Roadmap Waffle Core: Evolutions for EcoShield (Beta 1)"
date_created: 2026-02-12
date_updated: 2026-05-16
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# ⚙️ Roadmap Waffle Core: Remediation & Proxying (Beta 1)

**Target:** `v0.1.0-beta1` **Theme:** Worker-Native Security, Decoupling and Asynchronous Proxying.

> **Context:** The post-Beta 0 audit revealed critical flaws (Insecure Deserialization, environment leakage via `putenv`) and architectural debt (tight Kernel coupling, reflection abuse). Before we can calmly turn Waffle into an "API Gateway" (the EcoShield project), **the absolute priority is to patch these vulnerabilities** to guarantee complete process isolation under FrankenPHP.

## 🚨 Phase 0: DevSecOps Hotfixes (Critical & Blocking)

_These items must be handled immediately. They represent a risk of RCE and of inter-request data leakage._

- [x] **Securing the Cache (waffle-commons/cache):**
    
    - **Flaw:** RCE via Insecure Deserialization (`unserialize` with `allowed_classes => true`).
        
    - **Action:** Replace with `json_encode()` / `json_decode()`. If native serialization is required, enforce `allowed_classes => false` or strictly validate the allowed classes.
        
- [x] **Thread-Safety & Isolation (waffle-commons/config):**
    
    - **Flaw:** Mutability of the global environment via `putenv()` in `DotEnv.php` (fatal in Worker mode).
        
    - **Action:** Remove `putenv()`. The `.env` parser must populate a read-only configuration registry injected into the Container, without altering the PHP process state.
        

## 🏗️ Phase 1: Architectural Modernization (Technical Debt)

_Code cleanup to reach the true PHP 8.5 standards._

- [x] **Kernel Decoupling (waffle-commons/waffle):**
    
    - **Defect:** Hard-coded instantiation (`new ControllerDispatcher(...)`) in `AbstractKernel::handle()`.
        
    - **Action:** Register the `ControllerDispatcher` in the Container and retrieve it via the `RequestHandlerInterface` interface.
        
- [x] **Eradication of the `ReflectionTrait`:**
    
    - **Defect:** Abuse of traits for reflection in the argument resolver and the dispatcher.
        
    - **Action:** Refactor toward a **Strategy** pattern or extract the reflection logic into dedicated services (Single Responsibility Principle).
        
- [x] **Container Optimization & Immutability:**
    
    - Modify the Container to use `has()` before `get()` to avoid the performance overhead of throwing exceptions (control flow via exceptions).
        
    - Make `RedisCache`, `FileCache`, `RouteDiscoverer` and `RouteParser` strict `final readonly class`es.
        
- [x] **Refactoring of `GlobalsFactory`:**
    
    - Break up the nested superglobal-parsing logic to reduce cyclomatic complexity.
        

## 📦 Phase 2: The HTTP Client Component (Proxy Engine)

_Waffle handles inbound HTTP (`http`), but needs a client to emit outbound requests (PSR-18) for the EcoShield project._

- [x] **Scaffold the `waffle-commons/http-client` component:**
    
    - Strict implementation of the PSR-18 standard (`Psr\Http\Client\ClientInterface`).
        
    - **FrankenPHP optimization:** The client must use non-blocking requests (cURL multi or native PHP 8.5 async) so it does not freeze the worker while the legacy monolith processes the request.
        
    - **Streaming:** Support stream transfer (`StreamInterface`) to proxy large payloads without saturating RAM.
        

## 🔀 Phase 3: Routing & Flow Validation

_Final preparations for Waffle to become a robust, self-validating Gateway._

- [ ] **Routing Evolution (Catch-All):**
    
    - Add support for "Low Priority" routes (a `priority` parameter in the `#[Route]` attribute) to intercept unhandled traffic toward the legacy.
        
- [ ] **Scaffold the `waffle-commons/validation` component:**
    
    - Implement an agnostic validator based on PHP 8.5 _Property Hooks_.
        
    - Integration with the `ControllerArgumentResolver` to auto-validate injected DTOs (avoiding the Mass Assignment flaws flagged in the audit).
        
- [ ] **XSS Mitigation:**
    
    - Add a default escaping mechanism or a strict header in the `ControllerResponseConverter` when it returns raw character strings (text/html).
        

## 🛑 Definition of Done (DoD) Beta 1

1. **Zero OWASP Vulnerabilities:** The code no longer contains any unfiltered `unserialize()` call nor any `putenv()`.
    
2. **Inverted Coupling:** `AbstractKernel` no longer performs any `new` on business classes (100% injected by the container).
    
3. **Functional Proxy:** The HTTP client can forward a multipart/chunked request without memory leaks or blocking the FrankenPHP thread.
    
4. **Mago Purity Maintained:** 0 static-analysis errors and 100% green PHPUnit tests across the entire monorepo.
