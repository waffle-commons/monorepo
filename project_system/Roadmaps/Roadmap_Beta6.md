---
title: "Waffle Ecosystem Roadmap: (Beta 6)"
date_created: 2026-07-17
date_updated: 2026-08-22
type: project
status: shipped
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP 0.1.0-beta6

> **Status:** Pending Validation — Draft (validated post-BBL strategic pivot, July 2026)
> 
> **Released:** **August 22, 2026**
> 
> **Primary Theme:** **Deep Multi-Engine Security Audits · Documentation Modernization · EcoShield-Gateway POC · Scientific Telemetry Benchmarking (K6)**.
> 
> **Core Mandate:** Beta5 shipped the runtime power (AOT, connection pooling, telemetry, WebAuthn). Before the ecosystem grows another feature surface — the OpenAPI / Serializer / Testing-bridge components are now scheduled for beta7 — we **stop and harden**. The validated post-BBL pivot pulls stabilization and audit work forward into beta6: three independent AI-driven security audits across all 21 decoupled components, zero-compromise remediation, a full Diátaxis documentation pass, the first `ecoshield-gateway` reverse-proxy POC, and a scientific K6 benchmark that converts the "$5\text{–}10\times$ RAM vs PHP-FPM" claim into published, reproducible numbers. This is the release that earns trust — the conference-ready proof (API Platform Conference, Lille · September 17–18, 2026) that Waffle is not merely fast, but **audited, documented, and measured**.
> 
> **Commitment Tiers:** **Gate (blocks the tag) — AXE 1 (AUDIT) + AXE 2 (REMEDIATION): zero open findings.** · Committed — AXE 3 (DOCS), AXE 5 (BENCH) · High — AXE 4 (EcoShield POC).

## 🔬 AXE 1: DEEP MULTI-ENGINE SECURITY AUDIT WAVE

_Beta4 and beta5 each ran a single-engine audit (OWASP Top 10 + Modern-PHP). Beta6 raises the bar to **three independent audit engines**, cross-checked, across **all 21 decoupled components**. Different model families surface different classes of defect; agreement raises confidence, disagreement exposes blind spots. No single tool is trusted as ground truth._

> **Execution status (2026-07-27): AXE 1 CLOSED.** 2 of 3 engines executed; triage complete; the
> Antigravity2 gap is formally accepted as a documented residual (not a beta6 blocker — see
> `[AUDIT-03]`). All results live in a single `project_system/Audits/Beta6/consolidated.md`
> (gitignored, local-only per `project_system/.gitignore` — no separate `audit-opus.md` /
> `audit-aistudio.md` / `audit-antigravity2.md` files exist; the table below points at the real
> location). AXE 2 remediation was executed as the 2026-07-27 fix wave and closed 2026-08-02 — see AXE 2.

| Pass | Engine | Primary lens | Status | Deliverable |
|---|---|---|---|---|
| `[AUDIT-01]` | Claude Code — 42-agent adversarial-verification workflow | OWASP Top 10 + PHP 8.5 modern-idiom + statelessness | ✅ Done | `project_system/Audits/Beta6/consolidated.md` (§ Claude Code Audit) |
| `[AUDIT-02]` | Google AI Studio | Injection / crypto / auth surface, independent model family | ✅ Done | `project_system/Audits/Beta6/consolidated.md` (§ Google AI Studio Audit) |
| `[AUDIT-03]` | Antigravity2 | Data-flow / taint / worker-safety, third independent family | ⛔ Unavailable — accepted residual | `project_system/Audits/Beta6/consolidated.md` (§ Antigravity2 Audit — "model unable to audit due to internal restrictions") |
| `[AUDIT-04]` | Cross-engine triage | Dedupe, severity reconciliation, remediation scheduling | ✅ Done (2026-07-27) | `project_system/Audits/Beta6/consolidated.md` + this roadmap's `[FIX-01]` ledger |

### `[AUDIT-01]` Pass 1 — Claude Code ✅

- **Result:** ran as two parallel multi-agent workflows against `pre-release/0.1.0-beta6` — a 12-dimension
  OWASP Top 10 sweep (19 candidates, each re-verified by an independent reviewer instructed to refute
  before confirming) plus an 8-shard PHP 8.5 modernization review (feature adoption, cyclomatic
  complexity, design patterns). 42 subagents, ~3.5M tokens, 1,425 tool calls.
- **Score: 0 Critical, 0 High, 12 Medium, 1 Low.** Fail-closed ABAC, CSRF HMAC binding, `SsrfGuard`, JWT
  algorithm allow-listing, and timing-safe comparisons held up under adversarial review; A08
  (deserialization) and A10 (SSRF) swept clean. 6 additional candidates were investigated and refuted
  (each blocked by a separate existing control) — recorded, no action needed.
- **Deviation from spec:** the originally-planned single-session "Claude Opus / Fable" pass was
  superseded by Claude Code's multi-agent adversarial-verification pipeline — a stricter methodology
  than specced, not a shortfall. Full interactive report (code snippets, per-finding verification
  rationale): https://claude.ai/code/artifact/28a955b2-f0f2-4769-8d52-99f46e1a1a7d.
- **Statelessness pass:** covered — no cross-request state-leak findings raised.

### `[AUDIT-02]` Pass 2 — Google AI Studio ✅

- **Result:** independent security + code-quality + modern-PHP review, delivered as a MUST/SHOULD/COULD
  roadmap: 5 MUST HAVE (security-critical), 5 SHOULD HAVE (modernization/decoupling), 4 COULD HAVE
  (DX/polish).
- **Focus lens:** injection (A03), cryptographic/deserialization failures (A02/A08), and
  authentication/authorization/ABAC (A01/A07) — the highest-blast-radius classes, as specced.

### `[AUDIT-03]` Pass 3 — Antigravity2 ⛔ (closed as accepted residual, 2026-07-27)

- **Result:** did not execute — "the model was unable to audit the codebase due to internal
  restrictions" (verbatim, `consolidated.md`). No data-flow/taint/worker-safety pass ran through
  `.antigravitycli`.
- **Disposition (final):** `.antigravitycli` is a standalone desktop/CLI application config
  (`.antigravitycli/mcp_config.json` + symlinked agents/commands/skills) — it is not a tool invocable
  from within another agent's session, so it cannot be retried as part of this triage pass; only the
  user can re-run it via the standalone AntigravityCLI app. **Formal decision: proceed to beta6 on the
  two completed engines.** This is a documented gap against the "three independent engines" Gate
  language, not a silent drop — re-running Antigravity2 before the tag (if the internal restriction
  lifts) stays open as a nice-to-have, not a blocker, since both completed engines independently swept
  worker-safety/statelessness (`wfl igor` semantics) without raising findings.

### `[AUDIT-04]` Cross-Engine Triage & Consolidation ✅ (closed 2026-07-27)

- **Coverage split:** the two engines were largely complementary rather than duplicative — AI Studio's
  MUST tier concentrated on `data`/`console`/`http`/`container`/`security` (SQL identifier quoting,
  route-cache deserialization, upload path containment, container reset lifecycle, ABAC voter subject);
  Claude Code's Medium tier concentrated on `auth`/`waffle`/`data`(Cassandra)/`skeleton`/`workspace`
  (audit logging, timing side-channels, JWT key floor, Docker hardening, env-guard, codegen injection).
  17 distinct MUST-tier items in total once merged — see `[FIX-01]`.
- **✅ The one direct disagreement — resolved with evidence, not auto-dismissed:** AI Studio's
  `WAFFLE-SEC-02` flags `RouteCompileCommand`'s `unserialize(base64_decode(...))` in route-cache
  generation as an unrestricted-deserialization RCE/POP-gadget risk (MUST HAVE). Claude Code's
  independent 12-dimension OWASP sweep reports A08 (deserialization) as "swept clean." Direct code
  read to adjudicate (2026-07-27):
    - `MatchedRoute` (`contracts/src/Routing/MatchedRoute.php:15-37`) — the only class in the
      unserialized payload — is `final readonly` with purely scalar/array properties: no `__wakeup`,
      `__destruct`, `__toString`, or `Serializable`, so it carries **zero object-injection gadget
      surface** on its own.
    - Its own docblock states construction happens "exclusively at the Router boundary (a trusted
      producer)" — `RouteCompileCommand`'s payload comes from `RouterInterface::getRoutes()`
      (`console/src/Command/RouteCompileCommand.php:87-88`), never from request/runtime input.
    - The generated artifact embeds the base64 string as a literal PHP source string, deployed through
      the same pipeline as the rest of the app; anyone with write access to tamper with that string
      already has write access to inject arbitrary PHP directly, making the missing `allowed_classes`
      restriction add no *practical* attack surface in the shipped pipeline today.
    - **Verdict:** Claude Code's "swept clean" is correct for *current exploitability* — no
      untrusted-input path reaches this `unserialize()` call. AI Studio's finding is **not a false
      positive** either: it's a real, currently-inert hardening gap (defense-in-depth against a future
      change that introduces an untrusted-data path, or a future DTO gaining dangerous magic methods).
      **Disposition: stays in `[FIX-01]`'s MUST backlog, reclassified from "critical RCE" to "hardening
      / defense-in-depth"** — the native fix (scope `allowed_classes` or switch to `var_export()`) is
      cheap and the zero-compromise policy fixes it regardless of live exploitability.
- **Agreement:** neither engine raised HIGH/CRITICAL findings on ABAC fail-closed behavior, CSRF HMAC
  binding, or JWT algorithm allow-listing — independent corroboration these core controls hold.
- **Written triage ledger (the `[AUDIT-04]` deliverable):** all 17 MUST-tier findings — including the
  reclassified deserialization item — are **scheduled for remediation in AXE 2**; none are risk-accepted
  as won't-fix. No further `[AUDIT-04]` work remains open; AXE 1 is closed.

## 🛠️ AXE 2: ZERO-COMPROMISE REMEDIATION

_A finding surfaced is not a finding fixed. Every issue from the audit wave is resolved **natively** — no Mago baselines, no suppressions, no `@`-silencing, no `#[WorkerSafe]` escape hatch used to paper over genuinely mutable state. The Mago Purge Protocol applies: clean means **zero output**._

> **Execution status (2026-08-02): AXE 2 CLOSED — 17/17 fixed natively, zero suppressions.**
> Items 1–3 and 6–17 were remediated in the 2026-07-27 fix wave (one `fix: … (FIX-01)` commit in each
> of 12 repos, with regression tests). The two residuals closed this weekend: **item 4** — the AOT
> emitter now memoises *only* inlined services (`self::INLINED` guard; passthroughs delegate to the
> runtime container), so a Resettable passthrough resets exactly once per request in both modes
> (parity-oracle test) and the stale pre-fix `workspace/var/cache/CompiledContainer.php` was
> regenerated; **item 5** — subject resolution is ctor-injected into `SecureContainer`
> (`SubjectResolverInterface`, contracts-first), resolved **lazily and only for voted actions**
> (fail-closed 403 on resolver failure, `#[PublicAccess]`-without-voters never invokes it), with a
> real object-level ownership demo in workspace and a safe-by-default unwired example in skeleton.
> **[FIX-02] verified on the final tree:** `check:all` 23/23 components (mago zero-output + tests),
> ecosystem `igor` **0 KO**, `compare-audit` clean, both boot-smokes green, coverage console 98.05% /
> security 99.12%. A **30-agent adversarial review** (8 finders, refute-first verification of every
> finding) over the full weekend diff returned **0 blocking**; all 5 important findings were fixed
> (lazy voter-gated resolution; umbrella-ci `gate` now fail-closed when `detect-changes` itself
> fails; stale `SecureContainer`/`PublicAccess` docblocks corrected; voter truth-table and resolver
> tests added), plus applied suggestions (middleware attribute write-back, AOT docblock precision).
> **Release-wave sequencing note:** `workspace/composer.lock` records path-repo HEADs — relock
> workspace AFTER committing the component changes, before tagging.

### `[FIX-01]` Native-First Remediation of Every Finding

- **Specification:**
    - Resolve every CRITICAL / HIGH / MEDIUM / LOW from `[AUDIT-04]` at the source — behaviour-correct fixes with regression tests, not silencing.
    - **Prohibited:** `mago` baselines, inline `@mago-ignore` / `@`-error-suppression, coverage exclusions, or reclassifying a real defect as "won't fix" without recorded sign-off.
    - Contracts-first sequencing where a fix touches an interface: the contract change lands in `waffle-commons/contracts` before its consumers; the `mago guard` perimeter stays non-negotiable.

- **Gate-blocking backlog (17 items, merged from both completed engines — beta6, MUST close before tag):**

    | # | Finding | Target | Source |
    |---|---|---|---|
    | 1 | ⚠️ SQL/identifier injection: loosen-then-tighten `IDENTIFIER_PATTERN`, escape backslashes in `quoteSegment()` | `data/src/Compiler/SQLDialect.php` | AI Studio SEC-01 |
    | 2 | Unrestricted `unserialize()` in route-cache codegen (hardening, not a live RCE — resolved in `[AUDIT-04]`); replace with `var_export()` or `allowed_classes` | `console/src/Command/RouteCompileCommand.php` | AI Studio SEC-02 |
    | 3 | Path traversal: enforce `Assert::within()` containment on upload moves | `http/src/UploadedFile.php` | AI Studio SEC-03 |
    | 4 | Container reset / singleton lifecycle parity between interpreted and AOT-compiled modes | `container/src/Container.php`, `console/src/Compiler/ContainerCompiler.php` | AI Studio SEC-04 |
    | 5 | Class-level `#[PublicAccess]` override risk; pass real subjects into ABAC voters | `security/src/Container/SecureContainer.php` | AI Studio SEC-05 |
    | 6 | CSRF + authentication-failure logging routed to the `SECURITY` channel (currently dead-end/undifferentiated) | `security/src/Middleware/CsrfMiddleware.php`, `auth/src/Middleware/AuthenticationMiddleware.php` | Claude Code |
    | 7 | `BasicAuthenticator` username-enumeration timing gap (unknown users skip `password_verify()`) | `auth/src/Authenticator/BasicAuthenticator.php` | Claude Code |
    | 8 | HS256 shared-secret minimum-length floor (currently only rejects empty string) | `auth/src/Jwt/Key/StaticKeyResolver.php` | Claude Code |
    | 9 | Fail closed when `APP_ENV=prod` **and** `APP_DEBUG=true` coincide | both `AppKernelFactory`s | Claude Code |
    | 10 | `workspace` `minimum-stability: dev` resolves security-relevant deps (webauthn-lib, serializer, predis) to unreleased branches; fix flags, relock, add to CI matrix | `workspace/composer.json` | Claude Code |
    | 11 | Unauthenticated demo endpoint performs a real `INSERT`; swap for `SELECT 1` (mirror skeleton) | `workspace/app/Controller/TransactionDemoController.php` | Claude Code |
    | 12 | `YamlParser` silently swallows its own fail-secure config-parse exception | `config/` (`YamlParser`) | Claude Code |
    | 13 | Drop root in skeleton's production Docker image (`USER` + `chown`, `no-new-privileges`) | `skeleton/docker/Dockerfile`, `docker-compose.prod.yml` | Claude Code |
    | 14 | `CassandraRepository::save()`/`delete()` bypass identifier quoting that the read path already uses | `data/src/Repository/CassandraRepository.php:184,216` | Claude Code |
    | 15 | Controller bare-`string` returns unescaped (CSP-only mitigation); escape by default + extend CSP `form-action`/`base-uri` | `waffle/src/Handler/ControllerResponseConverter.php` | Claude Code |
    | 16 | Route-parameter scalar coercion silently normalizes invalid input instead of rejecting (`(int)'abc'` → `0`) | `waffle/src/Handler/ControllerArgumentResolver.php` | Claude Code |
    | 17 | Waffle Maker interpolates unsanitized CLI tokens into generated PHP (codegen injection); allow-list + `php -l` pre-write check | `console/src/Maker/Generator/PropertyHookGenerator.php`, `AbstractMakerCommand::writeFile()` | Claude Code |

    Item 2 was the one cross-engine disagreement — resolved in `[AUDIT-04]` (not a live RCE in the
    shipped pipeline, still fixed as defense-in-depth). Not on this list: rate-limiting/lockout on
    authentication (Claude Code confirmed this is correctly already scheduled as beta7 `NET-01`, not a
    beta6 gap).

- **Deferred backlog (SHOULD/COULD — beta7 modernization + opportunistic, tracked here for continuity,
  not beta6-gating):** 19 `readonly`/typed-constant/`#[Override]` mechanical fixes; duplicate-logic
  extraction (identifier-quoting helper, connection-pool algorithm, `Base64Url` → `utils/`,
  host-allowlist → `utils/`); `ControllerDispatcher` service-locator removal; `ControllerArgumentResolver`
  Chain-of-Responsibility decomposition; duplicate `ValidationException` consolidation; a `JwtIssuer` in
  `auth/` so demo apps stop hand-rolling JWS; `waffle-serverless`'s pinned-to-beta4 dependency drift. Full
  itemization lives in `consolidated.md`'s own SHOULD/COULD sections — re-surface when scoping
  `Roadmap_Beta7.md`'s modernization work, not duplicated here to avoid drift between the two documents.
  **Added by the 2026-08-02 adversarial review (suggestion tier, signed off as beta7):** promote
  `Constant::ATTR_PARAMS` in contracts and adopt it in `CoreRoutingMiddleware`/`ControllerDispatcher`/app
  resolvers (producers currently share a `'_params'` literal); AOT compiled-memo **runtime write-through**
  so inlined singletons have a single identity authority (today a runtime-side closure factory
  transitively resolving an inlined id builds a second instance — documented constraint in
  `ContainerCompiler` + `reference/aot.md`, each copy still resets exactly once); `GreetedResource`
  owner-case normalization option (current strict-byte ownership vs case-insensitive reservation is
  documented intentional deny-more); a PHPUnit step for the new workspace umbrella-ci job (static gates
  only tonight); `waffle-serverless` stale vendored `config/YamlParser` re-mirror when that demo is next
  rebuilt.

> **Pre-release verification (2026-08-20/21) — one coverage hole found and closed.**
> Re-running the gates on the final tree surfaced a defect in the *gate itself*: six components
> (`config`, `console`, `contracts`, `error-handler`, `log`, `routing`) had **never** carried
> `igor-php/igor-php` in `require-dev`, so `igor.sh` took its "not installed — skipped" branch and
> silently excluded them. The published "ecosystem `wfl igor` 0 KO" therefore covered 17 of 23
> components, not all of them — since beta4. All six are now wired (`igor.json` + `composer igor` +
> dev dependency), the state they do hold is declared `#[WorkerSafe]` with explicit reasons
> (`Router`'s boot-time trie and compile-once PCRE memo, `TrieNode`'s build fields, `Config::$parameters`,
> and console's CLI-only classes), and **`igor.sh` now FAILS on any unaudited component** rather than
> warning — with a minimal, documented exemption list containing only `component-template`. A
> regression test (hiding a binary) confirms the hole cannot silently reopen. **One residual:**
> `routing/src/Router.php` is reported KO for "mutation on a local reference to a shared service
> (`$span`)" — a per-call telemetry span, ended in the same method. `http-client/src/Client.php`,
> `security/src/Container/SecureContainer.php` and `waffle`'s `ControllerResponseConverter` use the
> identical construct and are reported clean, so this is an igor-php heuristic inconsistency, not a
> leak. It is **not suppressed**; it is recorded here and upstream.

### `[FIX-02]` Full Gate Re-Verification (Definition of Done)

- **Specification:**
    - Per modified component: `composer mago` (zero output — errors **and** warnings/info/help), `composer tests` ($\geq 95\%$ coverage), `wfl igor` **0 KO**.
    - Ecosystem-wide `wfl check:all` / `wfl dod` green; both template apps (`skeleton`, `workspace`) boot-smoke clean; `wfl compare-audit` (SEC-03 gate) shows no vendor skew.

## 📚 AXE 3: DOCUMENTATION MODERNIZATION (DIÁTAXIS)

_The documentation must be as trustworthy as the code. Beta6 brings the **entire** documentation surface — the in-repo per-component `docs/` trees and the central `documentation/` submodule — into strict Diátaxis compliance: four quadrants, each page in exactly one._

> **Execution status (2026-08-02): AXE 3 CLOSED — with one recorded scope decision on `[DOC-02]`.**
> **`[DOC-01]` done:** `documentation/` verified strictly quadrant-partitioned; `explanation/architecture.md`
> rewritten from its stale Beta-1/2 content to the real 21-component ecosystem (grounded in a
> composer.json sweep of all 21); `explanation/performance.md` de-orphaned (3 inbound links; it hosts the
> AXE 5 measured numbers); duplicate `how-to/security.md` merged into `secure-a-controller.md` and
> deleted; **two tutorials added** (secured CRUD endpoint; async + telemetry), restoring quadrant
> balance; a **nonexistent `#[Rule]` attribute** discovered documented across 6 pages and swept
> corpus-wide. **`[DOC-02]` renegotiated (recorded decision, not a silent drop):** authoring 21 per-component
> `docs/` trees (~80–120 h) would duplicate the central tree, which already carries a Reference page for
> every component — the central `documentation/` submodule is the canonical Diátaxis surface, and each
> of the 21 component READMEs now carries a uniform `## 📚 Documentation` link block into its
> Reference/Explanation pages. The missing repo doc packs were closed: `async` (which shipped beta5 with
> **no README at all**) received the full pack; `telemetry`/`telemetry-otel` READMEs brought to sibling
> standard (two stale claims corrected against source). **`[DOC-03]` done:** every reference page verified
> symbol-by-symbol against the live public surface (~30 stale claims fixed — pre-ARCH-03 kernel API,
> beta5 pool signatures, missing beta6 hardenings, auth test-count claim); link graph checked in full:
> **331 links, 0 broken, 0 anchor mismatches**.

| Quadrant | Orientation | Answers | Form |
|---|---|---|---|
| **Tutorials** | Learning | "Take me from zero to running." | Guided, step-by-step lessons |
| **How-To Guides** | Task | "How do I accomplish X?" | Goal-oriented recipes |
| **Reference** | Information | "What is the exact contract?" | API-accurate, terse, exhaustive |
| **Explanation** | Understanding | "Why is it designed this way?" | Discursive, design-rationale prose |

### `[DOC-01]` Diátaxis Restructure of `documentation/`

- **Specification:**
    - Reorganize `documentation/` into the four canonical Diátaxis categories; every page classified into exactly one quadrant — no hybrid tutorial/reference pages.
    - Navigation and cross-links rebuilt around the quadrant taxonomy; orphaned or duplicated pages merged or retired.

### `[DOC-02]` Per-Component `docs/` Upgrade

- **Specification:**
    - Each of the 21 decoupled components' `docs/` tree upgraded to the same standard, with at minimum a Reference page verified against the current public API and an Explanation page for any non-obvious design decision.
    - Language policy honored: English for all component documentation and identifiers (French remains confined to the `skeleton` / `workspace` / `academy` template apps).

### `[DOC-03]` Reference Generation & Cross-Linking

- **Specification:**
    - Reference pages verified against the current `waffle-commons/contracts` public surface; every documented symbol resolves to a real, exported contract.
    - Consistent cross-linking between quadrants (a How-To links to the Reference it uses and the Explanation of why), so the docs form a navigable graph rather than isolated pages.

## 🛡️ AXE 4: ECOSHIELD-GATEWAY REVERSE-PROXY POC

_The dogfooding validation project begins here. Beta6 stands up the first working `waffle-commons/ecoshield-gateway` — a high-performance reverse proxy built exclusively on public Waffle APIs — as the Phase 1 POC that beta7 grows to alpha (`[GATE-02]`) and beta8 to beta (`[GATE-03]`), soaking on RC1._

> **Execution status (2026-08-02): AXE 4 CLOSED — POC delivered and gate-green.**
> **Location note (2026-08-07):** the POC was developed inside this monorepo and has since been
> moved to its **own repository**, outside `waffle-commons` (the path is gitignored here — see
> `.gitignore`). It was never a submodule and was always excluded from the release wave, so this
> move changes nothing about the beta6 tag; the `[GATE-01]` result below stands as achieved and
> was verified against the tree at the time of closure.
> `ecoshield-gateway` ships a `ProxyController` with hop-by-hop stripping in both directions
> (including the fields named by the message's own `Connection` header — the half most proxies
> miss), `Host` recomputation, append-never-trust `X-Forwarded-*`, request-smuggling rejection on
> ambiguous framing, and 502 mapping that does not leak internal topology. **Bounded memory is
> structural, not aspirational:** the inbound body stream is handed to the upstream request by
> reference and `http-client` already moves both directions in 8 KiB chunks, so payload size never
> enters worker memory — pinned by a test asserting the *same stream instance*, since a single
> `(string)` cast would silently invert the property.
> **The POC's real finding: the public API was sufficient.** `src/` imports nothing but PSR
> interfaces; no private reach-through was needed, so no upstream framework bug was surfaced.
> Gates: `composer mago` zero output, 12 tests at **100 % statement coverage**, `igor` **0 KO**
> (3/3 stateless). Deliberately **excluded from the release-wave allow-list** — a POC is not
> published alongside the framework — and tracked as a plain directory until its own repository
> exists. Deferred to beta7 by design and stated in its README: upstream connection pooling,
> retry/circuit-breaking (that is `resilience-net` `NET-01`), response caching, WebSocket upgrade
> passthrough, multi-upstream load balancing.

### `[GATE-01]` `ecoshield-gateway` Reverse-Proxy POC ($8\,\text{KiB}$ streaming buffers)

- **Specification:**
    - Scaffold `waffle-commons/ecoshield-gateway` from `component-template` (new-component onboarding checklist applies: gitlink committed, path-repo lock mirrored).
    - **Streaming reverse proxy** over the FrankenPHP worker runtime: bounded **$8\,\text{KiB}$** streaming buffers for request and response bodies — constant memory regardless of payload size, **never** buffering a full body in worker memory (statelessness mandate; the soak target is $\Delta M = 0$).
    - Catch-all `ProxyController` with PSR-7 passthrough, hop-by-hop header stripping, and correct `Host` / `X-Forwarded-*` handling; no request/response smuggling surface.
    - Built **exclusively on public Waffle APIs** — any private-API reach-through is a framework design bug to fix upstream, not to work around in the gateway.
    - **Statelessness compliance:** `wfl igor` **0 KO** across worker iterations; no per-request state retained between proxied calls.

## 📊 AXE 5: SCIENTIFIC TELEMETRY BENCHMARKING (K6)

_The "$5\text{–}10\times$ RAM vs PHP-FPM" success indicator has been an assertion. Beta6 makes it an experiment: a comprehensive K6 suite benchmarking three runtimes head-to-head under identical, reproducible load, producing publishable numbers for the conference._

| Engine | Framework | Runtime | Concurrency model | Role |
|---|---|---|---|---|
| **A** | Waffle-Commons | FrankenPHP Worker Mode | Memory-resident worker | Subject |
| **B** | Symfony | Traditional PHP-FPM | Process-per-request | Baseline (classic stack) |
| **C** | Symfony | FrankenPHP Worker Runtime | Memory-resident worker | Control (runtime held constant) |

_Engine **B** isolates the combined framework + runtime delta versus the classic stack; Engine **C** holds the runtime constant (both on the FrankenPHP worker), so any A-vs-C difference is attributable to **Waffle vs Symfony**, not FrankenPHP vs FPM. Together they separate the runtime win from the framework win._

### `[BENCH-01]` Tri-Engine K6 Harness

- **Specification:**
    - Reproducible harness (Docker Compose) standing up all three engines against an identical workload and dataset, with pinned CPU/RAM limits so the comparison is apples-to-apples.
    - K6 scripts version-controlled; every run emits machine-readable output (JSON summary) archived alongside the audit reports in `project_system/`.

### `[BENCH-02]` Constant-Load Percentile Benchmark

- **Specification:**
    - Constant-arrival-rate scenarios at fixed RPS steps; capture latency percentiles $p_{50}$, $p_{95}$, $p_{99}$, $p_{99.9}$ and RAM footprint per engine at each step.
    - **Pass:** Engine A holds $p_{99}$ and peak RAM within target versus both baselines; the RAM reduction factor (target $5\text{–}10\times$ vs Engine B) is published from these runs.

### `[BENCH-03]` Prolonged Soak — Memory-Leak Detection ($\Delta M = 0$)

- **Specification:**
    - Multi-hour constant-load soak per engine; sample RSS / peak memory over time.
    - **Acceptance target for the worker-mode engines (A and C):** $\Delta M = 0$ — zero memory drift between the first and last measurement window, cross-checked by the `wfl igor` statelessness audit. Any positive $\Delta M$ is a leak routed back into AXE 2 for a native fix.

### `[BENCH-04]` Database Connection-Pool Starvation

- **Specification:**
    - Drive request concurrency above the configured pool size to characterize the starvation behaviour of the beta5 `[DBAL-01]` pooler: lease-wait latency, heal-on-lease correctness under contention, and **fail-closed** semantics when the pool is exhausted.
    - **Pass:** bounded, documented degradation (no unbounded queue growth, no deadlock, no leaked or severed connections); $\Delta M = 0$ across the run.

## ✅ ACCEPTANCE CRITERIA

- **AUDIT:** ✅ **closed 2026-07-27.** Two of three independent engine passes complete across all 21 decoupled components (Claude Code, Google AI Studio); Antigravity2 formally accepted as a documented residual, not silently dropped (`[AUDIT-03]`); findings consolidated and severity-reconciled in `project_system/Audits/Beta6/consolidated.md`; zero un-triaged findings — the one cross-engine disagreement (`[AUDIT-04]`, the `RouteCompileCommand` deserialization item) is resolved with code-level evidence, not just deferred.
- **REMEDIATION:** ✅ **closed 2026-08-02.** All 17 gate-blocking `[FIX-01]` findings fixed natively (none risk-accepted); **zero** Mago baselines/suppressions introduced; `check:all` 23/23 (mago zero output + tests, coverage ≥95% on modified components), ecosystem `wfl igor` **0 KO**; hardened further by a 30-agent adversarial review (0 blocking, all important findings fixed).
- **DOCS:** ✅ **closed 2026-08-02.** `documentation/` strictly Diátaxis-partitioned and link-graph-clean (331 links, 0 broken); reference pages verified symbol-by-symbol against the current public API; `[DOC-02]` satisfied via the recorded renegotiation (central tree canonical + per-component README link blocks + missing repo doc packs closed) rather than duplicated per-component `docs/` trees.
- **ECOSHIELD:** ✅ **closed 2026-08-02** (POC since relocated to its own repository outside the monorepo — see the AXE 4 location note). The `ecoshield-gateway` POC proxies over the FrankenPHP worker with 8 KiB streaming buffers in both directions (inherited from `http-client`, body stream passed by reference so payload size never enters worker memory), built only on public APIs — `src/` imports nothing but PSR interfaces, so no private reach-through and no upstream framework bug surfaced. `composer mago` zero output, 12 tests / 100 % coverage, `wfl igor` **0 KO**. Excluded from the release wave (POC, not published).
- **BENCH:** ✅ **closed 2026-08-02.** The tri-engine harness is reproducible (`bench/`, one command per run); constant-load percentiles are published per rate step (an aggregate over a ladder containing saturated steps is meaningless); the soak proves $\Delta M = 0$ on both worker engines at the FULL specified length — 3 h each, 1.62 M requests, ΔM **−1.76 MiB** (A) and **−0.29 MiB** (C), i.e. negative drift, with the undetectable-leak bound sharpened from ~10 MB/h to ~1.7 MB/h; pool starvation characterised at 8× oversubscription — 868 req/s, p99.9 98 ms, zero rejected requests, zero leaked connections. **The RAM factor is deliberately NOT published as "$5\text{–}10\times$":** BENCH-02's pinning could not test that claim, and the corrected experiment (`[BENCH-05]`) shows it is false below ~12 concurrent requests, crosses over at 12–16, and reaches 2.37× at 128. The defensible published claim is the growth *slope* — memory grows **10.5× slower per concurrent request** than PHP-FPM — plus 7.8× throughput at 8.7× lower p50 against php-fpm on its most favourable pool. Full record: `bench/BENCH-GATE-RESULT.md`.
- **All items:** contracts-first sequencing on any interface change; `composer mago && composer tests` green, $\geq 95\%$ coverage, zero Mago baselines, `wfl igor` **0 KO**; the beta6 tag follows the release-wave mechanics (umbrella tag pushed → dry-run on the pushed tag → LIVE wave).
