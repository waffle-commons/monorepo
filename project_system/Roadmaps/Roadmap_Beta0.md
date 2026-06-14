---
title: "Roadmap Beta 0 (Hardening, Interaction & Integrity)"
date_created: '2026-01-20'
date_updated: '2026-05-04'
type: project
status: active
tags:
  - project
  - roadmap
  - waffle
  - integrity
aliases: []
---
# 🗺️ Roadmap Beta 0: Strictness, Integrity & Hardening

**Status:** `Approved by the Architect` **Target:** `v0.1.0-beta0` **Theme:** "Zero Debt, Maximum Control"

> **The Architect's Strategic Vision:** Alpha 5 laid the foundations of observability. Beta 0 is the radical hardening phase. We will not build the _Sentinel_ project on foundations that tolerate static-analysis warnings or injection flaws. This iteration marks the full adoption of PHP 8.5 defensive paradigms.

## 🚨 Phase 0: Operation "Zero Tolerance" (Blocking Prerequisite)

_Before writing a single new line of functional code, the debt introduced in Alpha 5 must be purged._

- [ ] **Eradicate the Mago baseline:** Immediate removal of all `mago-analyzer-baseline.toml` and `mago-linter-baseline.toml` files in every component.
    
- [ ] **Strict resolution:** Manual correction of every Mago warning (missing typing, dead code, cyclomatic complexity).
    
- [ ] **Coverage Sanity:** Verify that all components maintain **≥ 95%** test coverage via PHPUnit 11+.
    

## 🛡️ Phase 1: HTTP Hardening & Anti-Poisoning (P0)

_The flaw identified in Alpha 5 regarding blind trust in `$_SERVER['HTTP_HOST']` must be plugged._

- [ ] **Trusted Hosts (waffle-commons/http):** Modify the `GlobalsFactory` or introduce an upstream request validator.
    
    - The framework must accept an array of `trusted_hosts` (regex or exact strings) via YAML configuration.
        
- [ ] **Fail-Fast Routing:**
    
    - If the incoming request's `Host` does not match the whitelist, the request must be rejected immediately (HTTP 400 Bad Request) by a very high-level middleware, potentially even before the `CoreRoutingMiddleware`.
        

## 📦 Phase 2: Data Integrity via PHP 8.5 (P1)

_Abandoning the classic heavyweight external-validator concept (Symfony-Validator style with `#[Assert]` attributes). We adopt a domain-oriented approach with state guaranteed valid by design._

- [ ] **Self-Validating Data Transfer Objects (DTOs):**
    
    - Waffle DTOs must be `readonly`.
        
    - **The implementation must use PHP 8.5 Property Hooks** to reject invalid data at the source.
        
    - Creation of a `ValidationException` (which the `ErrorHandlerMiddleware` will catch to return a clean RFC 7807).
        

_Example of the Waffle Standard:_

```
readonly class UserLoginDTO {
    public string $email {
        set(string $value) {
            if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                throw new ValidationException('Invalid email format.');
            }
            $this->email = $value;
        }
    }
}
```

- [ ] **ArgumentResolver Upgrade (waffle-commons/waffle):**
    
    - Enhance the `ControllerArgumentResolver` so it can instantiate these DTOs from the PSR-7 request body (decoded JSON), thereby naturally triggering the validation hooks.
        

## ⚙️ Phase 3: DevSecOps Tooling & Console (P2)

_A modern framework needs a CLI for maintenance and audit operations._

- [ ] **Waffle Console (waffle-commons/console):**
    
    - Creation of a lightweight component implementing `ConsoleApplicationInterface`.
        
    - Zero magic: strict dependency injection for commands.
        
- [ ] **Minimal Core Commands:**
    
    - `waffle cache:clear`: Safely clear the RouteCache.
        
    - `waffle route:list`: Display the routing table in text mode.
        
    - `waffle security:audit`: **Crucial.** A command that walks the controllers and displays the tree of access rules (`#[Rule]`) to ensure no sensitive route is accidentally exposed.
        

## 🧠 Phase 4: PSR-6/16 Cache System (RFC-013) - (P2.5)

_The framework needs a robust cache system compatible with FrankenPHP workers, indispensable for router performance and future security tokens (CSRF)._

- [ ] **`waffle-commons/cache` Implementation:**
    
    - Strict compliance with the PSR-6 (Cache Interfaces) and PSR-16 (Simple Cache) standards.
        
- [ ] **Cache Adapters:**
    
    - `ArrayCache`: In-memory, very fast, valid for the worker's lifetime.
        
    - `FileCache`: Persistent, with secure folder-permission handling (fixing the `/tmp` flaws).
        
    - `RedisCache`: Preparation for distributed state in production.
        
- [ ] **RouteCache Refactoring:**
    
    - Replace the native (include/require) logic of the existing `RouteCache` to use this new standardized component.
        

## 🚀 Phase 5: Codebase Modernization (P3)

_Global upgrade to the PHP 8.4/8.5 standards._

- [ ] **Typed Constants:**
    
    - Replace all class and interface constants with typed constants (e.g. `public const string EVENT_NAME = '...';`).
        
    - Applies especially to `LogChannel`, `Failsafe`, and event names.
        
- [ ] **Asymmetric Visibility:**
    
    - Walk the core classes (`Request`, `Response`, `Route`, etc.).
        
    - Replace private properties with simple getters by public properties with restricted mutation: `public private(set) string $method;`.
        
    - Remove the now-obsolete "getter" methods.
        

## 🔒 Phase 6: Mutative Security (CSRF) - (P4)

_Preparation for the Sentinel Back-Office._

- [ ] **CSRF Middleware (waffle-commons/security):**
    
    - Implementation of a synchronized-token mechanism.
        
    - **FrankenPHP constraint:** Blocking PHP sessions are forbidden. Favor a _stateless_ approach (e.g. Double Submit Cookie combined with a cryptographically signed token) or rely strictly on the `CacheInterface` (Redis) implementation built in Phase 4.
        

## 🛑 Definition of Done (DoD) Beta 0

1. **Mago Pure:** The `mago analyze` binary returns exit code `0` across the entire monorepo, without any baseline file.
    
2. **Coverage Maintained:** PHPUnit reports `Lines: 95.00%+` on each package (including the new `cache` component).
    
3. **Internal Security Audit Passed:** A request attempt with an undeclared `Host` returns a strict error.
    
    - An attempt to inject an invalid email into a DTO crashes at hydration (Exception intercepted).
        
4. **Cache Engine Operational:** The framework compiles and reads routes correctly via the new `waffle-commons/cache` component.
    
5. **Agnosticism Respected:** No reverse coupling was introduced. The Waffle component still depends only on `waffle-commons/contracts`.
