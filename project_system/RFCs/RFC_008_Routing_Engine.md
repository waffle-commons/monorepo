---
title: "RFC-008: Routing Engine"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-008: Routing Engine

**Status:** Implemented (Alpha 4) **Components:** `waffle-commons/routing` **Author:** Core Architect **Tags:** attributes, dispatching

## 1. Summary

This RFC covers the Routing component. Waffle utilizes PHP 8 Attributes to map URLs to controller methods natively.

## 2. Motivation

Centralized routing files (like `routes.yaml`) create cognitive distance between the URL definition and the actual logic. Attribute-based routing keeps the context tightly coupled to the controller.

## 3. Technical Specifications

### 3.1 The `#[Route]` Attribute

Supports dynamic parameters, HTTP methods restriction, and naming.

```
#[Route(path: '/api/users/{id}', name: 'user_show', methods: ['GET'])]
```

### 3.2 Discovery & Caching

The `RouteDiscoverer` scans the controller directory defined in the configuration. To maintain sub-millisecond performance, routes are compiled into an optimized `RouteCache` file (PHP array). In Alpha 5/6, cache generation must be strictly protected against RCE (do not fallback to `/tmp` if the application cache directory is unavailable).

## 4. Contributor Guidelines

- **Strict Method Typing:** Always define allowed HTTP methods. Do not create catch-all routes.
    
- **Controller Purity:** Controllers should remain thin. Defer heavy logic to injected services.