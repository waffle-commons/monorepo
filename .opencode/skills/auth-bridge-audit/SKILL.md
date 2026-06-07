---
name: auth-bridge-audit
description: Security auditor for the Universal Authentication Bridge (RFC-021) — JWT/OAuth2-OIDC/HMAC-assertion/API-key schemes, fail-closed, stateless
compatibility: opencode
---

## What I do
I audit the **Universal Authentication Bridge (UAB)** (RFC-021): Waffle's entire
authentication layer in **`waffle-commons/auth`** (contracts under
`Waffle\Commons\Contracts\Auth`, entry contract
`Waffle\Commons\Contracts\Auth\AuthenticationBridgeInterface`). Inbound: JWT bearer,
OAuth2/OIDC, HMAC identity assertions, API key, HTTP Basic. Outbound: the host-gated
`AuthenticatedClient` PSR-18 decorator and its `CredentialsProviderInterface` providers.
Authorization (ABAC/voters/CSRF) is **not** my scope — that is `security` (RFC-002).

## When to use
"Audit/review the auth bridge", "RFC-021", "check the assertion / HMAC / TTL / IP-binding /
replay", "audit JWT validation / OAuth flow / PKCE / JWKS", "review outbound credentials".

## Audit Checklist (zero-tolerance)

### Cross-cutting
- **Constant-time:** every MAC/secret comparison uses `hash_equals()` — never `==`/`===`.
- **Fail-closed boot:** schemes requiring a secret refuse to construct when
  `WAFFLE_AUTH_SECRET` is missing or <32 bytes (fatal config exception, no anonymous bypass).
  Secrets are `#[\SensitiveParameter]`, sourced via `%env(...)%` config — never runtime `getenv()`.
- **Fail-closed runtime:** a supporting authenticator that rejects credentials throws
  (401/403 via error-handler); no fallback to the next scheme, no silent anonymous downgrade.
- **Stateless:** the request-scoped `SecurityContext` is the only mutable service and
  implements `ResettableInterface`; caches are injected PSR-16; no `$_SESSION`, no
  superglobals, no static state. `igor-php` must be green.

### HMAC identity assertion (§4.3 — Gateway Assertion Protocol)
- Format `base64url(canonical JSON payload) . hex(HMAC-SHA256)` over the **encoded** payload
  with the shared secret; compact claims `usr`, `eml`, `rol`, `ten`, `iat`, `exp`, `iph`;
  header **`X-Wfl-Assert-User`**.
- Temporal: `exp` in the future, `iat` not in the future, AND `exp − iat ≤ 5s` (no window
  widening) ⇒ else `ExpiredAssertionException`/`InvalidAssertionException` (403).
- Single-character tamper ⇒ `SignatureVerificationException` (403).
- **IP-binding:** `iph = hex(HMAC-SHA256(client IP, secret))` — the verifier recomputes over
  ITS observed client IP and `hash_equals()`-compares ⇒ else `ClientIpHijackingException`
  (403). The raw IP never travels.
- No identity in the `SecurityContext` ⇒ **no header emitted** on outbound requests.

### JWT bearer (§4.4)
- Explicit algorithm **allow-list**; `alg: none` rejected unconditionally; key type checked
  against algorithm (no HS/RS confusion). Signature verified **before** claims are read.
- `exp`/`nbf` (bounded leeway), mandatory expected `iss` + `aud`.
- JWKS: fetched via PSR-18, selected by `kid`, cached via PSR-16 with bounded TTL.

### OAuth2 / OIDC (§4.5)
- Authorization Code **always with PKCE S256** (no `plain`); `state` verified constant-time
  before token exchange; `nonce` checked in the ID token (validated through the JWT subsystem).
- Transaction state (state/nonce/verifier) in a short-TTL **signed cookie** — never a session.

### Outbound (§4.7)
- `AuthenticatedClient` providers are **host-gated** (`supports()`); credentials never leak
  to unrelated hosts; existing headers are never overwritten; `http-client` stays untouched.

## Execution (in Docker)
```bash
docker exec -w /waffle-commons/auth waffle-dev composer mago
docker exec -w /waffle-commons/auth waffle-dev composer tests
docker exec -w /waffle-commons/auth waffle-dev composer igor
docker exec -w /waffle-commons/contracts waffle-dev composer mago
```
Verify RFC-021 §6: tampered / expired / IP-mismatched assertions ⇒ **403**; tampered /
`none` / wrong-issuer JWTs ⇒ **401**; missing secret ⇒ fatal boot; coverage ≥95%.

> **Language note:** the bridge lives in framework components — all comments, logs, and
> exceptions are **English** (French only in the `skeleton/` and `workspace/` template apps).
