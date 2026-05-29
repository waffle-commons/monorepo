---
name: auth-bridge-audit
description: Security auditor for the Universal Authentication Bridge (RFC-021) — HMAC assertions, 5s TTL, IP-binding, fail-closed
compatibility: opencode
---

## What I do
I audit the **Universal Authentication Bridge (UAB)** (RFC-021), which lets the EcoShield Gateway
(Waffle/FrankenPHP) propagate a signed identity to legacy monoliths via the `X-EcoShield-Assert-User`
header. Scope: `waffle-commons/security` + `waffle-commons/http-client` (contract:
`Waffle\Commons\Contracts\Security\AuthBridge\AuthenticationBridgeInterface`).

## When to use
"Audit/review the auth bridge", "RFC-021", "check the assertion / HMAC / TTL / IP-binding / replay".

## Audit Checklist (zero-tolerance)
- **Signed assertion format:** `base64url(JSON payload) . hex(HMAC)`. Payload carries `sub`, `email`,
  `roles`, `iat`, `ip`. Signature = **HMAC-SHA256** (`hash_hmac`) over the base64url payload using the
  shared secret `ECOSHIELD_AUTH_SECRET`.
- **Constant-time verification:** comparison uses `hash_equals()` — **never** `==`/`===` on the MAC
  (side-channel timing). A single-character mutation must yield HTTP **403**.
- **Temporal validation (anti-replay):** reject when `now - iat` exceeds the strict TTL — **5s
  default**. Expired ⇒ 403.
- **IP-binding:** the request's remote IP must match the signed `ip`; mismatch ⇒ 403.
- **Fail-closed boot:** if `ECOSHIELD_AUTH_SECRET` is missing on either side, the bridge **refuses to
  initialize** (fatal config exception) — never a silent anonymous bypass.
- **Stateless propagation:** assertion built from the thread-safe `SecurityContext`; no `$_SESSION`,
  no cross-request state; injection happens only on the outgoing PSR-18 request.
- **Decoupled ABAC:** the gateway evaluates `#[Rule]`/`#[Voter]` locally (fail-closed) without
  querying the legacy system; the downstream network path stays isolated.

## Execution (in Docker)
```bash
docker exec -it -w /waffle-commons/security waffle-dev composer mago
docker exec -it -w /waffle-commons/security waffle-dev composer tests
docker exec -it -w /waffle-commons/http-client waffle-dev composer mago
```
Verify (RFC-021 §6): every proxied request with an active session carries the signed header; any
tampered, expired, or IP-mismatched assertion ⇒ immediate **403**.

> **Localization note:** RFC-021 §6.3 requests **French** for the bridge's logs/exceptions, but
> project policy is **English everywhere except the `skeleton` component**. The bridge lives in
> `security` / `http-client`, so its comments, logs, and exceptions are **English**.
