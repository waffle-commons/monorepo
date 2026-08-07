---
title: "Waffle Ecosystem Roadmap: Release Train to v1.0 (Master)"
date_created: 2026-06-07
date_updated: 2026-08-05
type: project
status: 🏗️ wip
tags:
  - project
  - roadmap
  - waffle
  - release
aliases: []
---
# 🧇 WAFFLE-COMMONS — RELEASE TRAIN TO v1.0 (MASTER)

> **Status:** Active Master Plan — replaces the former `Roadmap_Cap_v1.md` (2026-01-20, deleted). The pre-v1 items of `Roadmap_Post_v1.md` have been absorbed into the train (see its absorption ledger).
> 
> **Post-BBL pivot (validated, July 2026):** stabilization, multi-engine security audits, Diátaxis documentation, the EcoShield-Gateway reverse-proxy POC, and scientific K6 benchmarking are pulled forward into **beta6**; the former beta6 production-surface work (OpenAPI, Serializer, Testing bridge, NET/QUEUE/OPS) shifts to **beta7**; and the API-freeze / consolidation release becomes **beta8**. The train is re-dated around the API Platform Conference (Lille · September 17–18, 2026).
> 
> **Vision:** A **full, production-ready PHP ecosystem** for building secured APIs on FrankenPHP, Docker, and Kubernetes. Philosophy unchanged: **"Strict, Secure, Fast."**
> 
> **Validation project:** **EcoShield-Gateway** (replaces Sentinel) — the Strangler-Fig API gateway POC (`Roadmap_EcoShield_Gateway.md`). A gateway is the perfect dogfooding target: it exercises proxying, resilience, rate limiting, auth, observability, and worker-mode endurance — exactly the surface v1 must prove.

## 🚆 THE RELEASE TRAIN

| Release | Target | Theme | Roadmap |
|---|---|---|---|
| `0.1.0-beta4` | Late June 2026 (shipped) | Security & Stability — RC-readiness groundwork | `Roadmap_Beta4.md` |
| `0.1.0-beta5` | July 8, 2026 (shipped) | Runtime Power — AOT, Pooling, Telemetry, WebAuthn | `Roadmap_Beta5.md` |
| `0.1.0-beta6` | **August 2, 2026** | **Stabilization & Audit** — multi-engine audits, Diátaxis docs, EcoShield POC, K6 benchmarking | `Roadmap_Beta6.md` |
| `0.1.0-beta7` | **September 5, 2026** | **Production Surface** — OpenAPI, Serializer, Testing bridge, NET/QUEUE/OPS | `Roadmap_Beta7.md` |
| `0.1.0-beta8` | **September 28, 2026** | **Consolidation & API Freeze** — last feature release | `Roadmap_Beta8.md` |
| `1.0.0-RC1` | **October 26, 2026** | Freeze certification + EcoShield-Gateway soak | `Roadmap_RC1.md` |
| `1.0.0-RC2` | contingency only | Critical blockers found in RC1 — never planned, only triggered | clause in `Roadmap_RC1.md` |
| `1.0.0` (Gold) | **December 23, 2026** | Launch | `Roadmap_v1_Gold.md` |

> **Version jump rationale:** the RC is tagged `1.0.0-RC1`, not `0.1.0-RC1`. SemVer pre-release ordering makes `0.1.0-RC1 < 0.1.0-beta4` ambiguous for Composer users, and the RC certifies the **v1 API**, so it must carry the v1 version. Branch naming follows the established scheme: `pre-release/0.1.0-beta6`, `pre-release/0.1.0-beta7`, `pre-release/0.1.0-beta8`, `pre-release/1.0.0-RC1`, then `release/1.0.0`.

## 🔬 GAP ANALYSIS — WHAT "FULL / PRODUCTION-READY" STILL REQUIRES

Inventory audit refreshed 2026-07-17 across the 26 live submodules (the beta5 additions — `async`, `telemetry`, `telemetry-otel` — are now live), cross-referenced with `Roadmap_Post_v1.md` (whose data/AOT/async/OIDC items have already been pulled forward and shipped):

| Capability | Current state | Closed by |
|---|---|---|
| Security hardening (SSRF, CSRF binding, CORS, traversal, timing) | beta4 scope | beta4 |
| AOT container/router, DB pooling, OTel/Prometheus, WebAuthn | beta5 scope | beta5 (shipped) |
| **Multi-engine security re-audit + zero-compromise remediation** | ⚠️ single-engine audits only (beta4/beta5) | **beta6** `[AUDIT-*]` / `[FIX-*]` |
| **Diátaxis documentation modernization** (full surface) | ⚠️ partial / uneven coverage | **beta6** `[DOC-01..03]` |
| **Scientific K6 benchmarking** (worker vs PHP-FPM, RAM factor) | ❌ claim asserted, never measured | **beta6** `[BENCH-*]` |
| **EcoShield-Gateway reverse-proxy POC** ($8\,\text{KiB}$ streaming) | ❌ absent | **beta6** `[GATE-01]` |
| Async deferral / reactive broadcast / WebAuthn | beta5 research spikes | beta8 (confirm or cut) |
| **Rate limiting / throttling** | ❌ absent (zero code) | **beta7** `[NET-01]` |
| **Resilient HTTP client** (timeout policy, retry/backoff, circuit breaker) | ❌ `http-client` is a single `Client.php` | **beta7** `[NET-02/03]` |
| **Background processing** (queue contracts + driver + worker) | ❌ absent; beta5 `[ASYNC-01]` explicitly disclaims this role | **beta7** `[QUEUE-*]` |
| **Health/readiness probes + graceful drain** (K8s) | ❌ only internal pool heal-on-lease | **beta7** `[OPS-01/02]` |
| **Schema migrations maturity** | ⚠️ `data/src/Migration/MigrationRunner.php` exists; no CLI, no versioned workflow | **beta7** `[OPS-03]` |
| **OpenAPI generation** from `#[Route]` + DTOs | ❌ absent | **beta7** `[API-01]` |
| **DTO serializer / content negotiation** | ⚠️ ad-hoc JSON in `http/`; `data/` Hydrator is DB-only | **beta7** `[API-02]` |
| **Testing bridge** (kernel test case, request simulation) | ❌ absent | **beta7** `[TEST-01]` |
| Dev profiler headers | ❌ absent | beta7 `[DXP-01]` |
| API freeze pass on `contracts/`, security re-audit, docs completion | not yet schedulable | **beta8** |
| Real-world validation under production-like load | n/a | **EcoShield-Gateway** POC (beta6) → alpha (beta7) → beta (beta8) → soak (RC1) |

## 🚫 EXPLICIT NON-GOALS FOR v1 (post-v1 backlog)

- **Templating engine** — API-first framework; no HTML rendering layer.
- **Translation / i18n** — API errors ship in English; userland concern.
- **Full ORM** (Doctrine-style unit-of-work) — `data/` repositories + mappers are the v1 answer.
- **Mailer transport** — `MailerInterface` contract only (beta7 decision `[QUEUE-03]`); SMTP/API adapters are post-v1.
- **WebSockets beyond Mercure/SSE** — covered only if `[REACTIVE-01]` spike is a go.
- **Admin / web UI of any kind.**

## 📊 v1.0 SUCCESS INDICATORS (revised)

1. **Stability:** $\geq 95\%$ coverage on all components; 100% on the critical path (`contracts`, `security`, `auth`, `http`); zero Mago baselines; `wfl igor` 0 KO.
2. **Performance:** <10ms p99 "hello world" in production worker mode; memory-growth slope ~10× lower per concurrent request vs PHP-FPM, with the measured total-RAM factor and crossover point published (EcoShield-Gateway FinOps benchmark, k6 $\geq 1000$ rps). *The former bare "$5\text{–}10\times$ RAM" indicator was reframed by beta6 `[BENCH-05]`: measured false below ~12 concurrent requests (0.87×), crossover at 12–16, 2.37× at 128 — the slope is the defensible claim.*
3. **Security:** zero known critical vulnerabilities on the **final** surface (re-audited in beta8, certified in RC1).
4. **Adoption:** **EcoShield-Gateway running the full Strangler-Fig scenario on RC1 for $\geq 4$ weeks** without critical incident (replaces the former Sentinel criterion).
5. **Completeness:** every capability row in the gap table above closed or explicitly moved to the non-goals list.

## 🧭 CROSS-CUTTING RULES (apply to every release of the train)

- **Contracts-first sequencing:** every new interface lands in `waffle-commons/contracts` before its consuming component; `mago guard` perimeter is non-negotiable.
- **Branching:** one `pre-release/<version>` branch per component per release (all components ship together: composer constraints, README, CHANGELOG). Delete the previous release's branches once the new ones are cut.
- **Release mechanics:** umbrella tag pushed → dispatch dry-run on the pushed tag → LIVE wave.
- **Definition of done per component:** `composer mago && composer tests` green, $\geq 95\%$ coverage.
- **New components planned:** `queue`, `openapi`, `serializer`, `testing` (beta7) — monorepo grows from 26 to 30 submodules; repo-creation overhead is budgeted in the beta7 window. Beta6 added the `ecoshield-gateway` app-level POC (a dogfooding application, not a contracts-perimeter library) — tracked as a plain directory until its own repository exists, and deliberately excluded from the release wave.
