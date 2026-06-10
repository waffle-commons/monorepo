---
title: "Log Beta 1"
date_created: '2026-05-25'
date_updated: '2026-05-25'
type: project
status: archived
tags:
  - waffle
  - beta1
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-beta1

> [!SUMMARY]
> Goal: Worker-native security remediation, architectural decoupling, and the outbound **proxy engine** (PSR-18) required to turn Waffle into the EcoShield API gateway.

## 1. Technical Changelog (What changed)

### 🚨 DevSecOps Hotfixes (Critical)

- **Cache RCE closed:** removed insecure `unserialize()` (with `allowed_classes => true`) in `waffle-commons/cache`; switched to `json_encode()`/`json_decode()`.
    
- **Worker isolation:** removed `putenv()` from `DotEnv` (fatal in worker mode); the `.env` parser now populates a read-only configuration registry injected into the container, never mutating PHP process state.
    

### 🏗️ Architectural Modernization

- **Kernel decoupling:** `AbstractKernel` no longer `new`s business classes; the terminal handler is resolved from the container via `RequestHandlerInterface`.
    
- **`ReflectionTrait` eradicated:** reflection logic extracted into dedicated services (Single Responsibility).
    
- Container uses `has()` before `get()` (no control-flow-by-exception); `RedisCache`, `FileCache`, `RouteDiscoverer`, `RouteParser` made strict `final readonly class`es; `GlobalsFactory` parsing de-nested.
    

### 📦 New Component — `waffle-commons/http-client` (PSR-18)

- Strict `Psr\Http\Client\ClientInterface` implementation tuned for FrankenPHP: non-blocking cURL-multi transfer (the worker parks on `curl_multi_select()` instead of busy-waiting), bounded-memory streaming of request and response bodies (`StreamInterface`) so large multipart/chunked payloads are proxied without saturating RAM.
    

## 2. Quality Gate (Exit Criteria)

- [x] **Zero OWASP:** no unfiltered `unserialize()`, no `putenv()`.
    
- [x] **Inverted coupling:** `AbstractKernel` performs no `new` on business classes.
    
- [x] **Functional proxy:** multipart/chunked forwarding with no memory leak or worker blocking.
    
- [x] **Mago purity:** 0 analysis errors, PHPUnit green across the monorepo.
    

## 3. Release

- [x] Umbrella tag → **v0.1.0-beta1** (lockstep).
    

## 4. Post-Mortem & Next Steps

- **Win:** the framework can now both receive and emit HTTP; the proxy foundation for EcoShield is in place.
    
- **Frictions surfaced:** the release workflow stumbled on Git submodule bounds, the skeleton shipped a tightly coupled kernel, and the router lacked strict HTTP-verb restriction — all carried into the Beta 2 backlog.
    
- **Next step:** [Roadmap Beta 2](../../Roadmaps/Roadmap_Beta2.md) — robust REST routing, CI/CD industrialization, and developer experience.
