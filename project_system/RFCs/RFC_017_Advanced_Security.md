---
title: "RFC-017: Advanced Security & Edge Protection"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-017: Advanced Security & Edge Protection

**Status:** In progress — rate limiting (§3.1, `[NET-01]`) for `0.1.0-beta7`; outbound resilience (`[NET-02]` client policies, `[NET-03]` circuit breaker) is specified in RFC-024, which shares the limiter's state-storage family; OAuth2/OIDC moved to RFC-021; webhook HMAC (§3.3) not yet scheduled **Components:** `waffle-commons/security` (the Beta 7 roadmap places the limiter in `security/` as a middleware instead of a separate `security-extra` package) **Author:** DevSecOps Lead **Tags:** rate-limiting, oauth2, oidc, hmac

## 1. Summary

While `waffle-commons/security` handles internal ABAC, this RFC introduces `security-extra` for perimeter defense, volumetric attack prevention, and modern identity federation.

## 2. Motivation

Enterprise APIs (like the EcoShield-Gateway dogfood) require defense mechanisms against brute-force attacks and must integrate with standard Identity Providers (IdP).

## 3. Technical Specifications

### 3.1 Rate Limiter

Implementation of the "Token Bucket" algorithm via PSR-15 Middleware.

- Configurable limits per IP address, user ID, or API token.
    
- State lives behind `LimiterStateStorageInterface` (atomic operations, in `contracts`), shared with the RFC-024 circuit breaker; its Redis implementation lives in `waffle-commons/data`, over the pooled Redis connection, to synchronize limits across containers. *Amended 2026-10-17:* this line first read "must rely on `waffle-commons/cache` (Redis)"; `cache` reaches Redis through predis, outside the framework's connection pool, and PSR-16 `get`/`set` cannot be atomic, so concurrent workers would over-admit (RFC-024 §5.1).
    

### 3.2 OIDC / OAuth2 Client — SUPERSEDED by RFC-021

> **Moved.** Authenticating users via external providers (Keycloak, Auth0, Google, …) is an
> *authentication* concern and now lives in the **Universal Authentication Bridge**
> (RFC-021, `waffle-commons/auth`): native OAuth2/OIDC client with PKCE, discovery, JWKS,
> and JWT validation. This RFC retains only perimeter defense (rate limiting, §3.1) and
> webhook payload integrity (§3.3).

### 3.3 HMAC Signatures

A utility class and middleware to cryptographically verify incoming Webhooks (e.g., from Stripe, GitHub) to ensure payload integrity and authenticity.

## 4. Contributor Guidelines

- **Fail Closed:** If the Rate Limiter storage backend goes down, the default behavior should be configurable (either block all traffic to protect the DB, or fail-open to preserve availability). *Decided 2026-10-17:* each limiter takes `on_storage_failure: open|closed`, default `open` with a warning log and a metric; `closed` is recommended on authentication endpoints, where the limiter is the brute-force defence. Authentication and authorization stay fail-closed whatever this setting says.
    
- **Constant Time Checks:** All cryptographic verifications (like HMAC) MUST use `hash_equals()` to prevent timing attacks.