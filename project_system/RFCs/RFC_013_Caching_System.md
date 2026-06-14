---
title: "RFC-013: Caching System & PSR-6/16"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-013: Caching System & PSR-6/16

**Status:** Planned for Beta 0 / Beta 1 **Components:** `waffle-commons/cache` **Author:** Core Architect **Tags:** psr-6, psr-16, caching, performance

## 1. Summary

This RFC introduces the caching mechanism for Waffle, adhering to standard PSR-6 (Cache Interfaces) and PSR-16 (Simple Cache).

## 2. Motivation

High-performance frameworks rely heavily on caching for route definitions, container configurations, and business data. Given Waffle's FrankenPHP worker mode, the caching layer must be concurrent-safe and capable of leveraging memory efficiently without causing leaks across requests.

## 3. Technical Specifications

### 3.1 Implementations

The component will provide multiple adapters:

- **ArrayCache (Memory):** Extremely fast, valid only for the lifespan of the worker.
    
- **FileCache:** Persistent across restarts, strictly requiring secure directory permissions (Fixing the `/tmp` RCE vulnerability identified in earlier alphas).
    
- **RedisCache:** The primary target for production deployments (Sentinel), allowing distributed state.
    

### 3.2 Framework Integration

- The `RouteCache` will be refactored to utilize this component instead of raw `include/require` logic.
    
- Security tokens (e.g., CSRF implementation) will rely on the `CacheInterface` for stateless validation across workers.
    

## 4. Contributor Guidelines

- **Atomic Operations:** Caching mechanisms must be atomic. Avoid race conditions when multiple workers attempt to warm up the cache simultaneously (implement Cache Stampede protection).
    
- **Graceful Degradation:** If the cache backend (e.g., Redis) is unavailable, the application should throw a specific infrastructure exception, or fallback gracefully depending on the data criticality.