---
title: "RFC-003: HTTP & Middleware Pipeline"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-003: HTTP & Middleware Pipeline

**Status:** Implemented (Alpha 4) **Components:** `waffle-commons/pipeline`, `waffle-commons/http` **Author:** Core Architect **Tags:** psr-15, psr-7, http, routing

## 1. Summary

This RFC standardizes the HTTP request flow. Waffle strictly relies on PSR-15 (Middleware) and PSR-7/17 (HTTP Message/Factories) to process requests and responses.

## 2. Motivation

A strict middleware pipeline allows developers to intercept, modify, or reject requests securely without altering the core routing logic. Adhering to PSR standards guarantees compatibility with third-party observability and security tools.

## 3. Technical Specifications

### 3.1 The Middleware Stack

Pre-controller processing is a strict FIFO (First-In, First-Out) queue of PSR-15 middlewares. **Mandatory Canonical Order:**

1. `ErrorHandlerMiddleware` (Must wrap everything to catch fatal errors).
    
2. `RoutingMiddleware` (Determines the target route).
    
3. `SecurityMiddleware` (Applies `#[Voter]` checks).
    
4. `ControllerDispatcher` (The final handler executing the business logic).
    

### 3.2 Host Header Validation (Beta 0 P0)

To prevent Cache Poisoning and Host Header Injection, the `GlobalsFactory` (or an early middleware) must implement a strict `trusted_hosts` whitelist. If the `Host` header is unmatched, the request is immediately dropped (HTTP 400).

## 4. Contributor Guidelines

- **Immutability:** PSR-7 requests and responses are immutable. Always use `->withHeader()` and capture the returned instance.
    
- **No Direct Output:** Never use `echo`, `print`, or `die()` inside a middleware. Always manipulate and return a `ResponseInterface`.