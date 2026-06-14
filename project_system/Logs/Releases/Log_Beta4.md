---
title: "Log Beta 4"
date_created: '2026-06-13'
date_updated: '2026-06-13'
type: project
status: archived
tags:
  - waffle
  - beta4
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle v0.1.0-beta4

> [!SUMMARY]
> Goal: Release-Candidate readiness — close the framework-audit security gaps (AXE 1), harden
> worker-mode architecture & diagnostics (AXE 2–3), polish the developer experience (AXE 4), and
> integrate the in-repo Academy (AXE 5). Target: late June 2026 (J-5 before the Attineos BBL talk).

## 1. Technical Changelog (What changed)

### 🔴 AXE 1 — Core Security Patches

- **SEC-01** Session fixation & tossing: `AnonymousSessionMiddleware` rotates the `WAFFLE_SID` cookie
  on authentication (forcing `HttpOnly` / `Secure` / `SameSite=Lax`); `CsrfTokenManager` folds the
  authenticated `subject` **and** session id into the HMAC payload, so a token minted while anonymous
  becomes mathematically invalid the moment the session authenticates.
- **SEC-02** Internal SSRF: the native `http-client` `SsrfGuard` resolves the target host → validates
  it against private/loopback/reserved CIDRs (RFC 1918/4193/6598, link-local, multicast, via
  `Assert::isPublicIp`) → **pins the validated IP with `CURLOPT_RESOLVE`** (anti-rebinding), with
  automatic redirect-following disabled. **Default-on**, with a config allow-list for trusted internal
  backends.
- **SEC-03** Timing-attack sweep: `hash_equals()` confirmed across `auth` (`JwtValidator`,
  `ApiKeyAuthenticator`, `BasicAuthenticator`, `AuthBridgeVerifier`) and `security`
  (`CsrfTokenManager`); a new `security:compare-audit` / `wfl compare-audit` scanner bans naive
  `===`/`!==` on sensitive call sites going forward.
- **SEC-04** Fail-closed CORS (net-new): `CorsMiddleware` + immutable `CorsPolicy`. An empty
  allow-list rejects every cross-origin request; `*` is banned for credentialed policies (rejected at
  construction). Documented in the new [Configure CORS](../../../documentation/how-to/configure-cors.md) how-to.
- **SEC-05** Path traversal: `Assert::safePath()` / `Assert::within()` reject `../`, `..\`, and
  null-byte sequences; secure-upload guidance added to the controller-hardening guide.

### 🟡 AXE 2 — Architecture & Stability

- **STB-01** Stream fd lifecycle: idempotent `close()` / `detach()` on `Stream`, no double-free, no
  dangling handles.
- **STB-02** Buffer-pool recycling **deferred** on benchmark evidence: `http/benchmarks/STB-02-GATE-RESULT.md`
  shows acyclic PSR-7 objects produce no material GC pressure; pooling would reintroduce cross-request
  mutable state for zero benefit. Statelessness preserved.
- **ARCH-01..06** Explicit return types everywhere; constructor-injected Router (`CoreRoutingMiddleware`);
  explicit hooked-property visibility (`public private(set)`); typed kernel lifecycle events
  (`RequestReceived` / `ResponseGenerated` / `Terminate`); interface-based controller dispatch via the
  new contract `ResponseFactoryAwareInterface`; standalone, independently-tested `UploadedFilesNormalizer`.

### 📊 AXE 3 — Worker-Mode Diagnostics

- **DIAG-01** `wfl igor` retained as a 0-KO non-regression gate (shipped in beta3).
- **DIAG-02** Boot-time `ComplianceScanner` (dev mode): a shared/singleton service holding mutable
  state without `ResettableInterface` or `#[WorkerSafe]` halts the container with an architectural
  exception.
- **DIAG-03** `ConnectionTracker` + `OrphanedConnectionListener` warn (on `TerminateEvent`) when a PDO
  / Redis / stream handle opened during a request is never released.

### 🛠️ AXE 4 — Developer Experience

- **DX-01** `bin/wfl` (contributor) vs `bin/waffle` (userland) separation; `wfl check:all` parallelizes
  the mago gates (`--with-tests` opt-in); `wfl monorepo:sync` aligns sibling dependency versions;
  maker stubs emit pristine PHP 8.5.
- **DX-02** Non-intrusive git hooks: staged-only pre-commit mago lint, pre-push tests/coverage;
  installed across the monorepo + submodules but **never** `component-template`.
- **DX-03** FrankenPHP hot-reload watch list; Starship prompt surfacing PHP memory, OPcache status, and
  git branch in the dev container.
- **DX-04** `mb_trim()` migration across utils/Assert, DTO property hooks, input normalizers, **and the
  maker generator** (so scaffolded DTOs are multi-byte-correct by default).
- **DX-05** Mockable `ValidatorInterface` (contracts) + `AssertValidator` (utils), wired into both
  template apps.

### 🏗️ AXE 5 — Academy

- **ACAD-01** `/academy` at the root (no root `composer.json`) with `labs` (path-repo TDD testbed),
  `sandbox` (FrankenPHP worker app), and `obsidian` (Markdown guides across 5 levels).
- **ACAD-02** `wfl academy:test` grading engine renders a visual terminal progress card; companion
  `academy:solve` / `reset` / `verify` / `serve` commands round out the loop.

## 2. Quality Gate (Exit Criteria)

- [x] **Agnosticism:** `mago guard` perimeter clean — components depend only on `contracts` (+ `utils`).
- [x] **Mago purity:** `fmt` + `lint` + `analyze` + `guard` exit `0` with zero baselines across touched
  components (`console`, `data`, `http`, `skeleton`, `workspace`, `academy/labs`).
- [x] **Tests green:** `console` 117/117, `data` 366/366, `http` 197/197, `academy/labs` 53/53 — all
  pass with ≥95% coverage.
- [x] **Worker safety:** `wfl igor` → **SUCCESS, 0 KO / 0 ERROR** (14 components OK; the lone WARN is
  the un-audited `component-template` scaffold).
- [x] **DX-04 sweep verified closed:** no bare whitespace `trim()` remains in any DTO, input
  normalizer, or maker-generated code.

## 3. Release

- [ ] Pre-release branch `pre-release/0.1.0-beta4` ready; pending commit of the conformance-audit
  fixes (DX-04 generator/demo DTOs, CORS how-to) into their submodules + superproject gitlink bumps.
- [ ] Umbrella tag → **0.1.0-beta4** (no `v` prefix) pushed to remote → dispatch dry-run on the pushed
  tag → LIVE release wave.

## 4. Post-Mortem & Next Steps

- **Win:** every framework-audit security gap deferred from Beta 3 is now closed **fail-closed**, and
  worker-mode safety is double-gated — runtime (`igor`) *and* boot-time (`ComplianceScanner`).
- **Caught in audit:** the `mb_trim` sweep had initially missed the maker generator, which seeded bare
  `trim()` into every scaffolded DTO; the pre-release conformance pass closed it at the root.
- **Known deviation:** the pre-commit `<150ms` target is met by native mago but not through
  `docker exec` (~1–3s in practice) — accepted as an environment cost for beta4.
- **Next step:** [Roadmap Beta 5](../../Roadmaps/Roadmap_Beta5.md) — async/concurrency, observability,
  and AOT-compilation research spikes.
