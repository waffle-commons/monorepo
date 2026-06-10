---
title: "RFC-021: Universal Authentication Bridge (UAB)"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-021: Universal Authentication Bridge (UAB)

**Status:** Accepted (implementation target: Beta 3)

**Components:** `waffle-commons/contracts`, `waffle-commons/auth` (demo wiring in `workspace`)

**Author:** Lead DevSecOps & Principal Systems Architect

**Tags:** security, authentication, oauth2, oidc, jwt, hmac, api-key, psr-18

**Reference RFCs:** RFC-002 (Security & ABAC Model), RFC-011 (Data Integrity), RFC-013 (Caching System), RFC-017 (Advanced Security — §3.2 superseded by this RFC), RFC-018 (DX)

> **Revision note.** The first revision of this RFC described a single-purpose HMAC identity
> hand-off for the "EcoShield Gateway" product. EcoShield is a separate project and is **not**
> part of the waffle-commons ecosystem. This revision generalizes the design: the Universal
> Authentication Bridge is the framework's *entire* authentication layer, owned by the
> `waffle-commons/auth` component. The original gateway-assertion protocol is retained,
> de-branded, as one supported scheme among several (§4.3).

## 1. Summary

This RFC specifies the **Universal Authentication Bridge (UAB)**: a protocol-agnostic
authentication layer for Waffle applications, implemented in the dedicated
`waffle-commons/auth` component against contracts defined in
`Waffle\Commons\Contracts\Auth`.

The UAB lets a Waffle application **connect to popular authentication services without
technical debt**, in both directions:

- **Inbound** — authenticate incoming PSR-7 requests through interchangeable
  *authenticators*: OAuth 2.0 / OpenID Connect identity providers (Google, Microsoft,
  Keycloak, Auth0, …), JWT bearer tokens, HMAC-signed identity assertions, API keys, and
  HTTP Basic credentials. A successful authentication populates a request-scoped, resettable
  **SecurityContext** holding the verified **UserIdentity**.
- **Outbound** — attach credentials (signed identity assertions, Bearer tokens, API keys,
  Basic credentials) to outgoing PSR-18 requests through a host-gated *authenticated client*
  decorator, so Waffle services can call protected upstream services natively.

"Without technical debt" is a hard requirement: no provider-specific SDKs, no `mixed`
escape hatches, no baselines, no stateful sessions. One small contract surface, strict
PHP 8.5 types, ≥95% test coverage, and the FrankenPHP statelessness mandate apply to every
scheme.

## 2. Motivation & Problem Statement

### 2.1 Authentication vs. Authorization

RFC-002 gave Waffle a fail-closed **authorization** model (`security` component: global
security levels, `SecureContainer`, `#[Voter]`/`#[Rule]` ABAC, CSRF). What Waffle lacks is
**authentication**: nothing in the framework can establish *who* the caller is. The
`VoterInterface` contract already anticipates a `SecurityContext`; this RFC introduces it.

The boundary is strict:

| Concern | Component | RFC |
|---|---|---|
| Authentication — *who are you?* | `waffle-commons/auth` | **RFC-021 (this)** |
| Authorization — *may you do this?* | `waffle-commons/security` | RFC-002 |

### 2.2 The integration-debt problem

Connecting a PHP application to identity providers traditionally means importing large
vendor SDKs (each with its own HTTP stack, cache, and global state), or hand-rolling
fragile OAuth flows. Both options violate Waffle's Zero-Debt policy and the FrankenPHP
resident-worker constraints (no globals, no hidden state, bounded memory).

The UAB solves this with **one contract surface and native implementations**: every scheme
is an `AuthenticatorInterface` (inbound) and/or a `CredentialsProviderInterface` (outbound)
built only on PSR interfaces (`psr/http-*`, `psr/simple-cache`, `psr/log`) and
`ext-openssl` — no third-party packages.

### 2.3 Supersession of RFC-017 §3.2

RFC-017 planned an "OIDC / OAuth2 Client" inside a future `security-extra` component. That
concern is authentication and therefore moves here. RFC-017 keeps perimeter defense:
rate limiting and webhook payload-integrity verification.

## 3. Architecture

### 3.1 Contract surface (`Waffle\Commons\Contracts\Auth`)

```
UserIdentityInterface          The verified identity: subject, email, roles, claims.
SecurityContextInterface       Request-scoped identity holder. Extends ResettableInterface;
                               reset by the kernel/container between requests.
AuthenticatorInterface         Inbound scheme: supports(ServerRequest): bool,
                               authenticate(ServerRequest): UserIdentityInterface.
AuthenticationBridgeInterface  Orchestrator: runs registered authenticators in order,
                               populates the SecurityContext, returns the identity
                               (or null for anonymous requests).
CredentialsProviderInterface   Outbound scheme: supports(Request): bool,
                               apply(Request): Request (returns a request carrying credentials).
Assertion/                     Signed identity assertion contracts (§4.3).
Token/                         JWT validation + token-set + key-resolution contracts (§4.4).
Oauth/                         OAuth2/OIDC client, discovery, provider metadata (§4.5).
Exception/                     Fine-grained failure taxonomy (all extend AuthExceptionInterface).
```

### 3.2 Request lifecycle

```
                       +-----------------------------+
                       |        Client / Caller      |
                       +-----------------------------+
                                      |
                            HTTP Request (PSR-7)
                                      v
              +---------------------------------------------+
              |        AuthenticationMiddleware (PSR-15)    |
              |  AuthenticationBridge::authenticate(req)    |
              |   ├─ AssertionAuthenticator   (X-Wfl-…)     |
              |   ├─ JwtAuthenticator         (Bearer …)    |
              |   ├─ ApiKeyAuthenticator      (X-Api-Key)   |
              |   └─ BasicAuthenticator       (Basic …)     |
              +---------------------------------------------+
                 |  no credentials        |  credentials OK        | credentials INVALID
                 v                        v                        v
          anonymous pass-through   SecurityContext filled   AuthExceptionInterface
          (public routing rules,   + `_auth_identity`       (401/403) -> rendered by
           ABAC still applies)     request attribute        error-handler (RFC-006)
                                          |
                                          v
                          +-------------------------------+
                          |  Controllers / ABAC voters    |
                          |  (security component, RFC-002)|
                          +-------------------------------+
                                          |
                          outgoing call?  v
                          +-------------------------------+
                          |  AuthenticatedClient (PSR-18) |
                          |  CredentialsProvider.apply()  |--> upstream service
                          +-------------------------------+
```

Inbound rules:

1. **First match wins.** Authenticators are consulted in registration order; the first one
   whose `supports()` returns `true` performs `authenticate()`.
2. **Fail-closed.** If a supporting authenticator rejects the credentials, the exception
   propagates — there is no fallback to the next scheme and no silent anonymous downgrade.
3. **Anonymous is explicit.** If no authenticator supports the request, the bridge returns
   `null` and the request proceeds anonymously; route protection remains the job of the
   authorization layer (RFC-002) — public routes stay public, protected routes reject.

Outbound rules:

1. **Host-gated.** A `CredentialsProviderInterface` declares which outgoing requests it
   supports (typically by host allow-list). Credentials are never attached to unrelated
   hosts — preventing credential leakage.
2. **Never overwrite.** If the outgoing request already carries the target header, the
   decorator leaves it untouched.
3. **Transport-agnostic.** `AuthenticatedClient` decorates any PSR-18 client
   (`waffle-commons/http-client` remains pure transport and is not modified by this RFC).

## 4. Technical Specifications

### 4.1 Identity model & SecurityContext

`UserIdentityInterface` carries the minimal portable identity: `subject` (stable unique
identifier), optional verified `email`, `roles` (list of strings), and a typed `claims`
bag for scheme-specific extras (token claims, provider profile fields).

`SecurityContextInterface` is the **only mutable service** in the component. It is
request-scoped, implements `Waffle\Commons\Contracts\Service\ResettableInterface`, and is
wiped by `ContainerInterface::reset()` between requests (resident-worker safety). It also
records the **original client IP** (from `ServerRequestInterface::getServerParams()['REMOTE_ADDR']`),
which assertion signing requires (§4.3).

### 4.2 Fail-closed boot

Every scheme that requires a secret **refuses to construct** without one:

- The shared assertion secret is sourced from the `WAFFLE_AUTH_SECRET` environment variable
  (via the config component's `%env(WAFFLE_AUTH_SECRET)%` placeholder — never `getenv()` at
  runtime).
- Secrets shorter than **32 bytes** are rejected at construction time with a fatal
  configuration exception (`MissingSecretExceptionInterface`), aborting kernel boot.
  A misconfigured bridge can never degrade into an unauthenticated bypass.
- All secret constructor parameters are marked `#[\SensitiveParameter]`.

### 4.3 HMAC identity propagation (Trusted Gateway Assertion)

The de-branded successor of this RFC's first revision: a Waffle edge service (e.g. a
Strangler-Fig gateway) propagates the authenticated identity to a downstream application
(Symfony, Laravel, custom PHP, or another Waffle app) without re-authentication, via the
**`X-Wfl-Assert-User`** header.

**Format:** `base64url(canonical JSON payload) . hex(HMAC-SHA256)`

**Payload claims (compact wire keys):**

| Claim | Type | Meaning |
|---|---|---|
| `usr` | string | Unique user (subject) identifier |
| `eml` | string\|null | User email address (valid format when present) |
| `rol` | list<string> | ABAC authorization roles |
| `ten` | string\|null | Tenant/organisation id for multi-tenant routing |
| `iat` | int | Generation timestamp (Unix seconds) |
| `exp` | int | Expiry timestamp — MUST satisfy `exp ≤ iat + 5` |
| `iph` | string | `hex(HMAC-SHA256(client IP, WAFFLE_AUTH_SECRET))` — keyed IP-binding hash; the raw address never travels |

**Generation algorithm (sender side — `AuthBridgeSigner`):**

1. Extract the active identity and client IP from the `SecurityContext`. No active
   identity ⇒ no header (anonymous proxying).
2. Build the claims: `iat = now`, `exp = iat + 5`,
   `iph = hash_hmac('sha256', $clientIp, $secret)`.
3. Serialize to canonical JSON; encode as unpadded Base64-URL.
4. Compute `hash_hmac('sha256', $encodedPayload, $secret)` (hex output).
5. Assemble `"{encodedPayload}.{hexSignature}"` and inject it as `X-Wfl-Assert-User`
   on the outgoing PSR-18 request (via `AssertionCredentialsProvider`, §4.7).

**Validation algorithm (receiver side — `AuthBridgeVerifier`):**

1. Header absent ⇒ the request is anonymous; standard public routing rules apply.
2. Split on the single `.`; structural failure ⇒ reject
   (`InvalidAssertionException`, 403).
3. Recompute the HMAC over the received encoded payload with the local copy of the
   secret; compare using **`hash_equals()`** (constant-time; `==`/`===` on MACs is
   forbidden). Mismatch ⇒ `SignatureVerificationException` (403).
4. Decode the payload; reject when `exp` is past, when `iat` is in the future, or when
   `exp − iat` exceeds the strict TTL — **5 seconds** —
   ⇒ `ExpiredAssertionException` / `InvalidAssertionException` (403, anti-replay and
   anti-window-widening).
5. **IP binding:** recompute `hash_hmac('sha256', $observedClientIp, $secret)` and
   compare with the signed `iph` via `hash_equals()`; mismatch ⇒
   `ClientIpHijackingException` (403).
6. On success, hydrate the identity into the receiver's security context
   (`GatewayAssertionMiddleware` / `AssertionAuthenticator` for Waffle receivers;
   ~40 lines of plain PHP for legacy receivers — the workspace demo ships a reference
   implementation).

### 4.4 JWT bearer validation

Validates `Authorization: Bearer <jwt>` tokens issued by popular IdPs (Auth0, Keycloak,
Firebase, Google, Microsoft, …) natively:

- **Algorithms:** `HS256` (`hash_hmac`) and `RS256` (`openssl_verify` with
  `OPENSSL_ALGO_SHA256`). The validator takes an explicit **algorithm allow-list**;
  `alg: none` and any algorithm outside the allow-list are rejected unconditionally.
  Key material is type-checked against the algorithm (no HS/RS confusion attacks).
- **Claims:** `exp` and `nbf` enforced with a configurable leeway (default 0); expected
  `iss` and `aud` are mandatory configuration; signature is verified before any claim is
  read.
- **Key resolution:** `StaticKeyResolver` (configured shared secret / PEM public key) or
  `JwksKeyResolver` — fetches the provider's JWKS document over PSR-18, selects by `kid`,
  converts RSA JWKs (`n`, `e`) to PEM via a native DER builder, and caches the document in
  an injected PSR-16 cache (RFC-013) with a bounded TTL.
- **Identity mapping:** configurable claim paths map `sub`/`email`/roles claims into the
  `UserIdentityInterface`.

### 4.5 OAuth 2.0 / OpenID Connect

A native, stateless OAuth2/OIDC relying-party engine:

- **Grants:** Authorization Code with **PKCE (S256 only)** for user login;
  **Client Credentials** for service-to-service tokens.
- **Discovery:** `OidcDiscovery` resolves `/.well-known/openid-configuration` into a
  `ProviderMetadataInterface` (authorization/token/JWKS/userinfo endpoints, issuer) and
  caches it (PSR-16).
- **Stateless transaction:** `state`, `nonce`, and the PKCE verifier are carried in a
  short-TTL (≤10 min) **HMAC-signed cookie** (same codec discipline as §4.3) — never in
  `$_SESSION`. The callback verifies `state` (constant-time) before any token exchange.
  Strict single-use of `state`/`nonce` additionally uses the injected cache as a replay
  guard when one is wired; without a cache the TTL bounds the replay window (documented).
- **ID token validation:** delegated to the JWT subsystem (§4.4) with `iss`, `aud`,
  `exp`, and `nonce` checks against provider metadata.
- **Presets:** `ProviderPreset` ships endpoint metadata + claim mappings for **Google**,
  **Microsoft** (OIDC), and **GitHub** (OAuth2-only: identity is resolved through its
  userinfo API since GitHub issues no ID token). Any other OIDC provider works through
  discovery without a preset.
- The component ships the engine; applications wire the login/callback **routes**
  (the framework does not impose URLs).

### 4.6 API key & HTTP Basic

- `ApiKeyAuthenticator` — reads a configurable header (default `X-Api-Key`) and matches it
  against configured key→identity pairs using `hash_equals()`.
- `BasicAuthenticator` — parses `Authorization: Basic`, validates against configured users
  with `password_verify()` (hashed) or `hash_equals()` (opaque tokens). Plain-text password
  storage is forbidden.

### 4.7 Outbound authenticated client

`AuthenticatedClient` (PSR-18 decorator, `final readonly`):

```
sendRequest(req):
    for provider in providers:
        if provider.supports(req): req = provider.apply(req)
    return inner.sendRequest(req)
```

Shipped providers: `AssertionCredentialsProvider` (§4.3 sender side),
`BearerCredentialsProvider` (static or token-set backed), `ClientCredentialsProvider`
(acquires/caches/refreshes a client-credentials token via §4.5),
`ApiKeyCredentialsProvider`, `BasicCredentialsProvider`.

## 5. Security Mandates & Risk Mitigation

1. **Constant-time everywhere.** Every MAC/signature/secret comparison uses
   `hash_equals()`.
2. **Anti-replay.** Assertions: 5s TTL + IP binding. OAuth: `state`/`nonce` signed,
   TTL-bounded, cache-backed single-use when available. JWT: `exp`/`nbf` enforced.
3. **Fail-closed.** Missing/short secrets abort boot (§4.2); invalid credentials throw —
   never downgrade to anonymous; unknown JWT algorithms reject.
4. **Statelessness (FrankenPHP mandate).** No `$_SESSION`, no superglobals, no static
   mutable state. The `SecurityContext` is the single mutable holder and implements
   `ResettableInterface`; caches are injected PSR-16 services. `igor-php` must report
   zero state-mutation errors.
5. **Network isolation.** Assertion-protected downstream links (§4.3) should run on an
   isolated, non-exposed network; the assertion protocol is defense-in-depth, not a
   substitute for transport security.
6. **No technical debt.** No third-party auth SDKs; no `mixed` (except the documented
   `json_decode` boundary); no Mago baselines; ≥95% coverage; English-only identifiers,
   comments, and log/exception messages in framework components.

## 6. Definition of Done (Beta 3)

The UAB is certified once all of the following hold:

1. **Contracts.** `Waffle\Commons\Contracts\Auth` ships the surface of §3.1; every
   component dependency still points only at `contracts`.
2. **Assertion scheme.** Outgoing requests sent through an `AuthenticatedClient` configured
   with the assertion provider automatically carry a valid `X-Wfl-Assert-User` header
   whenever the `SecurityContext` holds an identity — and no header otherwise. Any
   assertion modified by a single character, expired beyond the 5s TTL, or presented from
   a mismatched IP is rejected with HTTP **403** by the receiver.
3. **JWT scheme.** Tokens with a tampered signature, `alg: none`, a non-allow-listed
   algorithm, wrong `iss`/`aud`, or expired `exp` are rejected with HTTP **401**; valid
   HS256 and RS256 tokens (static key and JWKS paths) authenticate.
4. **OAuth/OIDC scheme.** Authorization URLs carry PKCE S256 + `state` + `nonce`; the
   callback rejects mismatched `state`; the code exchange and client-credentials grants
   produce token sets; ID tokens are validated including `nonce`.
5. **Simple schemes.** API-key and Basic authenticators accept configured credentials and
   reject everything else, in constant time.
6. **Fail-closed boot.** Booting any secret-requiring scheme without `WAFFLE_AUTH_SECRET`
   (or with <32 bytes) raises a fatal configuration exception.
7. **Quality gates.** For `contracts` and `auth`: `composer mago` (fmt + lint + analyze +
   guard, zero baselines) and `composer tests` (≥95% coverage) pass in Docker, and
   `igor-php` reports **zero errors**.
8. **Demo.** The `workspace` template app demonstrates: a JWT-protected route, an API-key
   route, and the assertion-asserted proxy to the legacy demo backend (which verifies the
   assertion and returns 403 on tamper/expiry/IP mismatch). All EcoShield-era naming is
   removed from the ecosystem.

## 7. Out of Scope / Future Work

- SAML and WS-Federation bridges.
- Refresh-token *persistence* (will ride the RFC-022 repository layer once it ships).
- Rate limiting and webhook payload-integrity verification (remain RFC-017).
- Live conformance suites against hosted IdPs (covered by mocked PSR-18 exchanges here).
- Session-cookie login state for browser apps (a future `auth-session` RFC may build on
  the SecurityContext + cache primitives introduced here).
