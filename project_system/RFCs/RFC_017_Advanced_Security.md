# RFC-017: Advanced Security & Edge Protection

**Status:** Planned for v1.x (Post-v1.0) **Components:** `waffle-commons/security-extra` **Author:** DevSecOps Lead **Tags:** rate-limiting, oauth2, oidc, hmac

## 1. Summary

While `waffle-commons/security` handles internal ABAC, this RFC introduces `security-extra` for perimeter defense, volumetric attack prevention, and modern identity federation.

## 2. Motivation

Enterprise APIs (like Sentinel) require defense mechanisms against brute-force attacks and must integrate with standard Identity Providers (IdP).

## 3. Technical Specifications

### 3.1 Rate Limiter

Implementation of the "Token Bucket" algorithm via PSR-15 Middleware.

- Configurable limits per IP address, user ID, or API token.
    
- Storage must rely on `waffle-commons/cache` (Redis) to synchronize limits across multiple containers.
    

### 3.2 OIDC / OAuth2 Client — SUPERSEDED by RFC-021

> **Moved.** Authenticating users via external providers (Keycloak, Auth0, Google, …) is an
> *authentication* concern and now lives in the **Universal Authentication Bridge**
> (RFC-021, `waffle-commons/auth`): native OAuth2/OIDC client with PKCE, discovery, JWKS,
> and JWT validation. This RFC retains only perimeter defense (rate limiting, §3.1) and
> webhook payload integrity (§3.3).

### 3.3 HMAC Signatures

A utility class and middleware to cryptographically verify incoming Webhooks (e.g., from Stripe, GitHub) to ensure payload integrity and authenticity.

## 4. Contributor Guidelines

- **Fail Closed:** If the Rate Limiter storage backend goes down, the default behavior should be configurable (either block all traffic to protect the DB, or fail-open to preserve availability).
    
- **Constant Time Checks:** All cryptographic verifications (like HMAC) MUST use `hash_equals()` to prevent timing attacks.