---
title: "Waffle Ecosystem Roadmap: (Beta 8)"
date_created: 2026-06-07
date_updated: 2026-11-05
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP 0.1.0-beta8

> **Status:** Pending Validation — Draft (scope partially determined by the beta5 spike outcomes and the beta7 retrospective)
> 
> **Target Release:** **December 2026** — tag targeted ~3 December (re-dated 2026-10-21 from November 2026: beta7 tags on 5 November and the freeze keeps its four weeks; see `Roadmap_v1_Master.md`) — **the last feature release before v1**. The tag of beta8 *is* the feature freeze.
> 
> **Core Mandate:** Resolve every open decision, soak every deep change, freeze the public API, and re-audit the final security surface. A beta exists to change things; after beta8, nothing changes except bug fixes.
> 
> **Commitment Tiers:** Everything in this roadmap is must-ship — by definition, anything that slips here slips out of v1 entirely (to the post-v1 backlog), not to RC1.

## 🔬 AXE 1: SPIKE RESOLUTION (BETA5 GO/NO-GO DEBT)

_The three beta5 research spikes get their final verdict. "Go" means landing the production implementation here with full gates; "no-go" means a formal cut to the post-v1 backlog, documented in the master roadmap's non-goals._

### `[SPK-01]` `[ASYNC-01]` Fiber-Based Deferred Task Runner — verdict

- Land (with the load-test report's throughput budget enforced) or cut. If cut, the documented alternative is `waffle-commons/queue` (beta7) for everything beyond trivial deferral.
    

### `[SPK-02]` `[REACTIVE-01]` Reactive Write-Hook Observers — verdict

- Land (enqueue-only hooks + middleware flush, Igor-clean) or cut. If cut, SSE/Mercure remains available through explicit event dispatch.
    

### `[SPK-03]` `[AUTH-01]` WebAuthn / Passkeys — verdict

- Land (contracts + `web-auth/webauthn-lib` adapter, W3C test vectors green, security-audit gate passed) or cut to post-v1. **A half-implemented authentication scheme does not ship in a v1.**
    

## 🧊 AXE 2: API FREEZE (THE CENTRAL DELIVERABLE)

### `[FRZ-01]` Contracts BC Review

- **Specification:**
    
    - Exhaustive review of every interface, DTO, enum, and attribute in `waffle-commons/contracts` — each one is either confirmed (frozen for all of v1.x under strict SemVer) or fixed **now**.
        
    - Checklist per symbol: final naming, parameter/return types explicit (beta4 `[ARCH-01]` bar), no leaked implementation details, PHPDoc contract semantics (preconditions, failure modes) complete.
        
    - Produce `contracts/BC-POLICY.md`: what is covered by the BC promise (interfaces, DTO shapes) and what is not (internal classes, `@internal` markers).
        

### `[FRZ-02]` Deprecation Sweep

- **Specification:**
    
    - Everything superseded during the beta series gets `#[Deprecated]` now and **removed in RC1** — v1.0 ships zero deprecated symbols.
        
    - Cross-component grep for usages; skeleton/workspace/Academy templates updated to the final APIs.
        
    - *Candidates recorded 2026-10-22:* `http-client`'s `Client::CONNECT_TIMEOUT_MS` and `Client::TIMEOUT_MS`, which the client no longer reads since `[NET-02]` (`TimeoutPolicy::DEFAULT_CONNECT_MS` / `DEFAULT_TOTAL_MS` replaced them).
        

### `[FRZ-03]` Naming & Convention Consistency Pass

- **Specification:**
    
    - One sweep across all components: namespace conventions (`Waffle\Commons\*` / `Waffle\Commons\Contracts\*`), exception hierarchies, config key naming, console command naming (`domain:action`), error response shapes.
        
    - Inconsistencies found after v1 are permanent — this is the last cheap moment.
        

## 🧯 AXE 3: SOAK & STABILIZATION

### `[STAB-01]` Deep-Change Soak Fixes

- **Specification:**
    
    - Dedicated bake time for the invasive beta5/beta7 machinery under sustained load: AOT compiled-vs-runtime container parity (snapshot diffs on real apps), DBAL pool exhaustion/reconnect edge cases, queue worker endurance, breaker/limiter behavior under chaos testing.
        
    - 72h continuous k6 soak on the workspace demo apps + EcoShield-Gateway: zero memory drift (Igor), zero connection leakage, zero 5xx not injected by the chaos scenario.
        

### `[GATE-03]` EcoShield-Gateway Beta + FinOps Benchmark

- **Specification:**
    
    - Take EcoShield-Gateway to **beta** on beta8 (from the beta7 alpha, `[GATE-02]`) and run the FinOps benchmark in its own repository: k6 $\geq 1000$ rps, Scenario A (direct legacy PHP-FPM) vs Scenario B (gateway) — RAM ceiling, latency, breaking point.
        
    - The benchmark report is a v1 launch asset **and** the empirical proof for success indicator #2 (memory-growth slope + measured RAM factor + crossover point, per the beta6 `[BENCH-05]` reframing — never a bare "$5\text{–}10\times$").
        

## 🔐 AXE 4: FINAL SECURITY RE-AUDIT

### `[AUD-01]` Full-Surface Audit

- **Specification:**
    
    - Re-run the complete audit (the one that produced the beta4 findings) against the **final** surface: everything beta4 fixed (regression check) plus the new beta5/beta6/beta7 attack surface — `/waffle-metrics`, connection pooling, rate limiter storage, queue payload handling, OpenAPI/Swagger dev routes, health endpoints, WebAuthn (if landed), the gateway proxy path (header smuggling, hop-by-hop handling, request smuggling).
        
    - Every finding is fixed in beta8 or formally risk-accepted with sign-off in the audit report. RC1 inherits zero open criticals.

    - *Decision 2026-11-05, the method:* the `release-audit` skill runs the audit end to end with Claude Code (`/release-audit 0.1.0-beta8`). It replaces the zipped payload sent to Google AI Studio and beta6's rule of "more than one independent engine" (the maintainer: "You will handle everything"). Independence now comes from:
        - tool evidence read before any code (`wfl audit:evidence`: Mago metrics, Psalm taint, `composer audit`, igor, SEC-03);
        - one finder per lens: the OWASP Top 10:2025 categories, worker-state leaks, timing-safe comparisons, and the repository's AI layer against OWASP's Top 10 for Agentic Applications 2026;
        - blind, refute-first verifiers and majority verdicts with a tie-break;
        - a calibration on known beta6 defects.

      The sweep includes dated threat notes: PHP2Shell (CVE-2026-109618, CVE-2026-109619), CVE-2026-115560 and the Symfony security releases of 2026-11-04.

    - *Sign-off:* the decision on each finding (fix, accept the risk, post-v1) is the maintainer's, recorded in the cockpit's `/audit` pane or with `wfl audit:sign`. Claude never records one.
        - The run lives in `project_system/Audits/Beta8/release-audit/` (gitignored, local only).
        - `wfl audit:check 0.1.0-beta8 --gate` is the evidence for exit gate #4, and `wfl pre-release --all` holds the tag on it.

    - *Pilot run, 2026-11-06 (`queue` + `serializer`, profile `balanced`):* 42 candidates, 40 confirmed and 2 plausible by blind verification, none refuted, merged into 31 findings (0 CRITICAL, 0 HIGH, 5 MEDIUM, 25 LOW, 1 INFO). The maintainer decided all 31 as *fix in beta8* in `/audit` on 2026-11-06. Archive: `project_system/Audits/Beta8/pilot/` (local, gitignored); one ticket each in `.scratch/release-audit-0.1.0-beta8/issues/`. A calibration on the pre-fix code of three beta6 `[FIX-01]` items raised 3 of the 4 known defects, and all three fixes still hold. The full-surface run (every other repository, the gateway, the AG lens) is still to come.

        | # | Finding | Severity | What | Where | Size |
        |---|---|---|---|---|---|
        | 1 | `M-api-async-01` | MEDIUM | Compiled and interpreted encoders disagree on list elements an application-built DTO holds | `serializer/src/Compiler/NormalizerCompiler.php` | M |
        | 2 | `S-B1-02` | MEDIUM | Component CI runs third-party code by mutable reference: actions by tag, the igor binary unverified | `queue/.github/workflows/main.yml` | M |
        | 3 | `S-B2-01` | MEDIUM | A delivery that kills its worker is redelivered forever and never dead-lettered | `queue/src/RedisStreams/RedisStreamsQueue.php` | M |
        | 4 | `S-B2-04` | MEDIUM | Reclaim drops the XAUTOCLAIM cursor, so ten stuck deliveries starve every later reclaim | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 5 | `S-B3-02` | MEDIUM | Unreadable queue entries are set aside with no log, metric or reason | `queue/src/RedisStreams/RedisStreamsQueue.php` | M |
        | 6 | `M-api-async-03` | LOW | Request-body parameters lack #[\SensitiveParameter]: a rejected body's password stays in the serializer's frames | `serializer/src/Serializer.php` | S |
        | 7 | `M-api-async-04` | LOW | JsonCodec's limits are a docblock only: depth 0 fails at the first request with a ValueError | `serializer/src/Json/JsonCodec.php` | S |
        | 8 | `M-api-async-05` | LOW | EnvelopeCodec::milliseconds() is 1000 ms off before the epoch | `queue/src/Envelope/EnvelopeCodec.php` | S |
        | 9 | `M-api-async-06` | LOW | NormalizerCompiler and ShapeNormalizer each fuse the encode and decode halves | `serializer/src/Compiler/NormalizerCompiler.php` | L |
        | 10 | `M-api-async-07` | LOW | RedisStreamsQueue fuses the dispatcher and the consumer; the telemetry pair serves dispatch() alone | `queue/src/RedisStreams/RedisStreamsQueue.php` | M |
        | 11 | `M-api-async-09` | LOW | "Is a #[Dto]" is decided three ways: one #[Dto] enum aborts serializer:compile | `serializer/src/Command/CompileCommand.php` | S |
        | 12 | `M-api-async-10` | LOW | The temp-then-rename writer is hand-rolled again, without DX-01's unpredictable name or the clean-up | `serializer/src/Command/CompileCommand.php` | M |
        | 13 | `M-api-async-13` | LOW | Multi-key writes are atomic in release() only | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 14 | `M-api-async-14` | LOW | The Redis lease sequence is written out seven times, its helpers copied verbatim | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 15 | `S-B1-01` | LOW | The serializer writes every public property, and its docs model a password hash going out | `serializer/src/Normalizer/ShapeNormalizer.php` | S |
        | 16 | `S-B1-03` | LOW | A received envelope is trusted beyond its field types: its queue, attempts and id are never bound | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 17 | `S-B1-04` | LOW | Any InvalidArgumentException from a DTO constructor reaches the production 422 body, past LEAK-03 | `serializer/src/Normalizer/Payload.php` | S |
        | 18 | `S-B1-05` | LOW | The AOT normalizer loader executes every PHP file in its directory, not only the generated ones | `serializer/src/Normalizer/CompiledNormalizerLoader.php` | S |
        | 19 | `S-B1-06` | LOW | Queue names share keys with the dead-letter store and with other queues' internals | `queue/src/RedisStreams/RedisFailedMessageStore.php` | S |
        | 20 | `S-B1-07` | LOW | `php: ^8.5` admits the PHP releases PHP2Shell affects | `queue/composer.json` | S |
        | 21 | `S-B1-08` | LOW | No private route for vulnerability reports in queue and serializer | `queue/SECURITY.md` | S |
        | 22 | `S-B2-02` | LOW | Queue envelopes carry no integrity check | `queue/src/Envelope/EnvelopeCodec.php` | M |
        | 23 | `S-B2-03` | LOW | The interpreted normalizer reflects on the DTO again for every nested value | `serializer/src/Normalizer/ShapeNormalizer.php` | S |
        | 24 | `S-B2-05` | LOW | An entry without an envelope field is neither settled nor set aside | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 25 | `S-B2-07` | LOW | Dispatch accepts payloads every worker refuses, and they are set aside silently | `queue/src/Envelope/EnvelopeCodec.php` | S |
        | 26 | `S-B2-09` | LOW | Dead letters and set-aside entries are kept in full, forever | `queue/src/RedisStreams/RedisFailedMessageStore.php` | M |
        | 27 | `S-B2-10` | LOW | serializer:compile embeds its --namespace option unchecked and skips the Maker's code-generation safeguards | `serializer/src/Command/CompileCommand.php` | S |
        | 28 | `S-B3-04` | LOW | Settling ignores XACK's count, so a delivery already settled elsewhere is re-queued | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 29 | `S-B3-05` | LOW | A RedisException raised while leasing escapes the queue unmapped | `queue/src/RedisStreams/RedisStreamsQueue.php` | S |
        | 30 | `S-B3-07` | LOW | The queue readiness probe has no timeout of its own | `queue/src/Health/StreamsHealthCheck.php` | S |
        | 31 | `M-api-async-15` | INFO | The compiler names its own classes as strings | `serializer/src/Compiler/NormalizerCompiler.php` | S |
        

## 📚 AXE 5: DOCUMENTATION & ONBOARDING COMPLETION

### `[DOC-01]` Diátaxis Completion

- **Specification:**
    
    - `documentation/` (tutorials / how-to / reference / explanation) covers every component at v1 API state — including the four beta7 newcomers.
        
    - Reference pages generated/verified against frozen contracts; upgrade guide "beta series → 1.0" drafted.
        

### `[DOC-02]` RFC & Internal Doc Reconciliation

- **Specification:**
    
    - Pending rewrites land: RFC-021 universal-auth reframing (RFC/skill/AGENTS), `Roadmap_Post_v1.md` refreshed to remove absorbed items, Academy labs aligned with final APIs.
        

## ✅ ACCEPTANCE CRITERIA — FREEZE EXIT GATE

Beta8 tags only when **all** of the following hold; this checklist is re-verified as RC1's entry gate:

1. Zero open spike decisions; post-v1 backlog updated with every cut.
2. `contracts/` BC review 100% complete; `BC-POLICY.md` published; zero TODO/FIXME in contracts.
3. 72h soak: zero memory drift, zero leaked connections/transactions, zero un-injected 5xx.
4. Security audit: zero open criticals; report archived in `project_system/` (`[AUD-01]`: `wfl audit:check 0.1.0-beta8 --gate` passes).
5. EcoShield-Gateway benchmark report produced; RAM factor documented.
6. Docs complete for all components; Academy labs green against beta8.
7. Standard gates everywhere: `composer mago && composer tests`, $\geq 95\%$ coverage, zero baselines, `wfl igor` 0 KO.
