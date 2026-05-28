---
name: security-audit
description: Act as the DevSecOps agent ensuring PHP 8.5 zero-tolerance security policies, ABAC, and statelessness
compatibility: opencode
---

## What I do
I audit `waffle-commons` components for security compliance under the strict zero-tolerance policies
required for FrankenPHP worker mode. Each component is its own Git repo, so audits run per-component.

## Audit Checklist
- **Statelessness (FrankenPHP):** zero `$_SESSION`, native session functions, `sys_get_temp_dir()`,
  or mutable static/singleton state. Services are resettable across requests.
- **Superglobal purge:** no direct `$_GET`/`$_POST`/`$_SERVER`; everything flows through an injected
  PSR-7 `ServerRequestInterface` or `GlobalsFactory`.
- **Fail-closed ABAC (RFC-002):** access is denied by default. `#[Voter]` policies and `decide()`
  default to `false`. Public endpoints are opt-in **only** via the explicit `#[PublicAccess]`
  attribute (`Waffle\Commons\Contracts\Security\Attribute\PublicAccess`). No implicit allow paths.
- **DTO safety:** every DTO validates through PHP 8.5 Property Hooks (`set(...)`) and is `readonly`,
  preventing mass-assignment / invalid-state instantiation.
- **Crypto & assertions (RFC-021 hardening):**
  - **Constant-time HMAC:** signature/MAC checks use `hash_equals()` — never `==`/`===` on secrets.
  - **HMAC-SHA256** over canonical payloads with a configured shared secret; **fail-closed** when the
    secret is absent (refuse to boot, never bypass).
  - **Temporal validation:** reject assertions/tokens older than the strict TTL (UAB default 5s).
  - **IP-binding:** the signed client IP must match the request's remote IP.
- **SSRF mitigation (RFC-017/021):** outbound PSR-18 calls validate/allow-list target hosts; no
  user-controlled URL reaches the network unchecked; block internal/metadata IP ranges.

## Execution (always in Docker)
```bash
# Static gates (analysis & guard are security-relevant: types, dead allow-paths, perimeter)
docker exec -it -w /waffle-commons/{component} waffle-dev composer analyzer
docker exec -it -w /waffle-commons/{component} waffle-dev composer guard
# Hunt forbidden stateful/superglobal patterns in source
docker exec -it -w /waffle-commons/{component} waffle-dev grep -rnE '\$_SESSION|\$_GET|\$_POST|\$_SERVER|session_start|sys_get_temp_dir' src
```
Produce a graded report: Statelessness · Superglobal purge · Fail-closed ABAC · DTO safety ·
Crypto/SSRF. For the Universal Authentication Bridge specifically, defer to `auth-bridge-audit`.
