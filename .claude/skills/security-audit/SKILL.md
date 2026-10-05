---
name: security-audit
description: "Security audit of one component: statelessness, fail-closed ABAC, SSRF, CSRF, CORS, traversal, SEC-03"
when_to_use: >-
  Auditing a component's security, #[PublicAccess] or #[Voter] reviews, SSRF (SEC-02), timing-safe
  comparisons (SEC-03, wfl compare-audit), CORS, path traversal, superglobals or sessions in worker
  mode, the beta8 final re-audit [AUD-01].
argument-hint: "[component]"
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
- **SSRF mitigation — default-on (SEC-02, RFC-017/021):** the native `http-client` `Client` ships
  with `SsrfGuard` wired by default (not opt-in). Every outbound call runs **resolve → validate →
  pin**: resolve the host (IPv4 **and** IPv6/AAAA), reject private/loopback/link-local/reserved CIDRs,
  then pin the vetted IP via `CURLOPT_RESOLVE` (closes the DNS-rebind TOCTOU window); redirects are not
  auto-followed. Trusted internal hosts bypass **only** via the explicit allow-list (exact host or
  CIDR), sourced from `waffle.security.ssrf.allowed_hosts` — everything else stays fail-closed.
- **Timing-safe comparisons (SEC-03):** secret/token/HMAC/signature/CSRF comparisons use
  `hash_equals()` — never `===`/`!==`/`==`. Enforced by the `wfl compare-audit` gate (a
  `token_get_all` scanner that flags naive identity checks on sensitive-named operands, with qualifier
  demotion so `keyId`/`tokenType` don't false-positive). Run it over the security-sensitive surface.

## Execution (always in Docker)
```bash
# Static gates (analysis & guard are security-relevant: types, dead allow-paths, perimeter)
docker exec -it -w /waffle-commons/{component} waffle-dev composer analyzer
docker exec -it -w /waffle-commons/{component} waffle-dev composer guard
# Hunt forbidden stateful/superglobal patterns in source
docker exec -it -w /waffle-commons/{component} waffle-dev grep -rnE '\$_SESSION|\$_GET|\$_POST|\$_SERVER|session_start|sys_get_temp_dir' src
# SEC-03 timing-safe comparison gate (naive === / !== on secret/token/hmac sites)
wfl compare-audit {component}
```
Produce a graded report: Statelessness · Superglobal purge · Fail-closed ABAC · DTO safety ·
Crypto/SSRF. For the Universal Authentication Bridge specifically, defer to `auth-bridge-audit`.

## Final-surface re-audit (beta8 `[AUD-01]`) — RC1 inherits zero open criticals
Re-run the complete audit against the **final** surface.

**Regression of every earlier fix:** beta4 SEC-01..05, the beta5 AXE0 hardening, and the 17 beta6
`[FIX-01]` items (the table in `Roadmap_Beta6.md`).

**Surface added since the beta6 audit:**

| Surface | What to try to break |
|---|---|
| Rate limiter `[NET-01]` | key spoofing through `X-Forwarded-For`, or every client sharing one key behind a proxy; non-atomic storage (over-admission); key cardinality as a memory DoS on the store; the fail mode while Redis is down; `RateLimit-*` / `Retry-After` leaking internals |
| Resilient client + breaker `[NET-02/03]` | SSRF re-validation on every retry; retries of non-idempotent methods; unbounded total time across attempts; breaker state shared across tenants that should be isolated |
| Queue payloads `[QUEUE-*]` | `unserialize()`, or a class name taken from the payload; envelope tampering (attempts, available-at); dead-letter content exposure; trace-context header injection |
| Health endpoints `[OPS-01]` | dependency topology in public bodies; probes as a DoS amplifier (a DB query per hit); placement before `TrustedHostMiddleware` without an equivalent check |
| OpenAPI / Swagger dev routes `[API-01]` | reachable in production; third-party scripts without a CSP decision; internal routes in the spec |
| Serializer `[API-02]` | hydration that bypasses a `set` hook; depth or size bombs; mass assignment |
| `/waffle-metrics`, connection pooling, WebAuthn | re-check under the final wiring |
| EcoShield proxy path | header smuggling; hop-by-hop handling, including `Connection`-named fields; request smuggling (CL/TE ambiguity); `Host` / `X-Forwarded-*` trust; cache confidentiality (no shared caching of `Authorization` or `Cookie` responses); egress pinning. The gateway's perimeter campaign (280 assertions) is the regression baseline (`[[ecoshield]]`) |

**Method (the beta6 precedent):** more than one independent engine; every candidate re-verified by a
reviewer told to refute before confirming; one consolidated triage ledger (dedupe, reconcile severity,
adjudicate disagreements with code evidence).

**Disposition:** every finding is fixed in beta8 or formally **risk-accepted with sign-off** in the
report (who, when, why, residual risk). The report goes under `project_system/Audits/Beta8/`. `Audits/`
is gitignored, so the archive is local: say where it lives in `Roadmap_Beta8.md`.

Dispatch the `security-auditor` agent per component, `auth-bridge-audit` and the `webauthn-auditor`
agent for `auth`.
