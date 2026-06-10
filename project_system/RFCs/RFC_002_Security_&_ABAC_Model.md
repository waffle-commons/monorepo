---
title: "RFC-002: Security & ABAC Model"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-002: Security & ABAC Model

**Status:** Implemented (Alpha 5), Hardening in Beta 0 **Components:** `waffle-commons/security` **Author:** DevSecOps Lead **Tags:** security, abac, container, middleware

## 1. Summary

This RFC outlines Waffle's defense-in-depth mechanism. Unlike traditional approaches where security is optional and manually applied per controller, Waffle enforces a **Global Security Level (1 to 10)** at the root level via the Dependency Injection Container.

## 2. Motivation

Security audits (e.g., RCE flaws related to `sys_get_temp_dir()`) prove that "opt-in" security fails. Developers forget to secure specific routes. Waffle adopts a "Fail Secure" and "Secure by Default" philosophy.

## 3. Technical Specifications

### 3.1 Global Security Level

Defined in `app.yaml` (`waffle.security.level`).

- **Level 1:** Verifies basic instantiation integrity.
    
- **Level 10 (Paranoid):** Audits memory integrity, return types, and prevents unauthorized object mutation.
    

### 3.2 The SecureContainer (The Guardian)

The core of the system is a PSR-11 Decorator: the `SecureContainer`. Every time the framework requests an object (service or controller), the `SecureContainer` intercepts the request, instantiates the object, and passes it to the `Security` component for analysis based on the global level. If the audit fails, a `SecurityException` is thrown before the object is ever used.

### 3.3 SecurityMiddleware & Attributes

For Attribute-Based Access Control (ABAC):

- The `SecurityMiddleware` sits upstream of the controller.
    
- It reads the `#[Voter(name: MyVoter::class)]` attribute on the controller/method.
    
- It executes the `VoterInterface` implementation. If `decide()` returns `false`, a unified HTTP 403 error is generated.
    

## 4. Contributor Guidelines

- **No Manual Instantiation:** Never bypass the `SecureContainer` by manually using the `new` keyword for business logic classes within an HTTP flow.
    
- **Stateless Voters:** `Voter` classes must be async-safe (no shared internal state).
    
- **Exceptions:** Always throw `Waffle\Commons\Security\Exception\SecurityException` for violations. Never use generic `\Exception`.