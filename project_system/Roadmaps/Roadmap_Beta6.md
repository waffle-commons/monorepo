---
title: "Waffle Ecosystem Roadmap: (Beta 6)"
date_created: 2026-07-17
date_updated: 2026-07-17
type: project
status: pending
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP 0.1.0-beta6

> **Status:** Pending Validation — Draft (validated post-BBL strategic pivot, July 2026)
> 
> **Target Release:** **August 2, 2026**
> 
> **Primary Theme:** **Deep Multi-Engine Security Audits · Documentation Modernization · EcoShield-Gateway POC · Scientific Telemetry Benchmarking (K6)**.
> 
> **Core Mandate:** Beta5 shipped the runtime power (AOT, connection pooling, telemetry, WebAuthn). Before the ecosystem grows another feature surface — the OpenAPI / Serializer / Testing-bridge components are now scheduled for beta7 — we **stop and harden**. The validated post-BBL pivot pulls stabilization and audit work forward into beta6: three independent AI-driven security audits across all 21 decoupled components, zero-compromise remediation, a full Diátaxis documentation pass, the first `ecoshield-gateway` reverse-proxy POC, and a scientific K6 benchmark that converts the "$5\text{–}10\times$ RAM vs PHP-FPM" claim into published, reproducible numbers. This is the release that earns trust — the conference-ready proof (API Platform Conference, Lille · September 17–18, 2026) that Waffle is not merely fast, but **audited, documented, and measured**.
> 
> **Commitment Tiers:** **Gate (blocks the tag) — AXE 1 (AUDIT) + AXE 2 (REMEDIATION): zero open findings.** · Committed — AXE 3 (DOCS), AXE 5 (BENCH) · High — AXE 4 (EcoShield POC).

## 🔬 AXE 1: DEEP MULTI-ENGINE SECURITY AUDIT WAVE

_Beta4 and beta5 each ran a single-engine audit (OWASP Top 10 + Modern-PHP). Beta6 raises the bar to **three independent audit engines**, cross-checked, across **all 21 decoupled components**. Different model families surface different classes of defect; agreement raises confidence, disagreement exposes blind spots. No single tool is trusted as ground truth._

| Pass | Engine | Primary lens | Deliverable |
|---|---|---|---|
| `[AUDIT-01]` | Claude Opus / Fable | OWASP Top 10 + PHP 8.5 modern-idiom + statelessness | `project_system/Audits/Beta6/audit-opus.md` |
| `[AUDIT-02]` | Google AI Studio | Injection / crypto / auth surface, independent model family | `project_system/Audits/Beta6/audit-aistudio.md` |
| `[AUDIT-03]` | Antigravity2 | Data-flow / taint / worker-safety, third independent family | `project_system/Audits/Beta6/audit-antigravity2.md` |
| `[AUDIT-04]` | Cross-engine triage | Dedupe, severity reconciliation, remediation scheduling | `project_system/Audits/Beta6/consolidated.md` |

### `[AUDIT-01]` Pass 1 — Claude Opus / Fable

- **Specification:**
    - Full OWASP Top 10 (2021) + Modern-PHP 8.5 review across all 21 decoupled components (the contracts-perimeter library set; the `component-template` scaffold, the `documentation` submodule, and the `skeleton`/`workspace`/`academy` apps sit outside this library-audit scope and are covered separately).
    - Severity-classified findings (CRITICAL / HIGH / MEDIUM / LOW) with `file:line` anchors and reproduction notes, mirroring the beta5 AXE 0 audit format.
    - Explicit statelessness pass: every stateful class re-checked against the FrankenPHP worker mandate (`wfl igor` semantics).

### `[AUDIT-02]` Pass 2 — Google AI Studio

- **Specification:**
    - Independent re-audit of the identical 21-component surface with a distinct model family, blind to Pass 1's findings until triage.
    - Focus lens: injection (A03), cryptographic failures (A02), and authentication/authorization (A01/A07) — the highest-blast-radius classes.
    - Same severity schema and anchoring discipline as `[AUDIT-01]`.

### `[AUDIT-03]` Pass 3 — Antigravity2

- **Specification:**
    - Third independent pass emphasizing data-flow / taint tracking and cross-request worker-safety (state leakage between worker iterations, unpinned globals, mutable singletons).
    - Runs through the `.antigravitycli` toolchain already wired in the monorepo; findings normalized to the shared severity schema.

### `[AUDIT-04]` Cross-Engine Triage & Consolidation

- **Specification:**
    - Merge the three finding sets; dedupe by `file:line` + defect class; reconcile conflicting severities (highest wins unless demonstrably a false positive).
    - Produce a single consolidated ledger: every finding is either **scheduled for remediation (AXE 2)** or **formally risk-accepted** with written sign-off in `project_system/Audits/Beta6/consolidated.md`.
    - Agreement/disagreement matrix retained as an audit-quality signal (which engine caught what).

## 🛠️ AXE 2: ZERO-COMPROMISE REMEDIATION

_A finding surfaced is not a finding fixed. Every issue from the audit wave is resolved **natively** — no Mago baselines, no suppressions, no `@`-silencing, no `#[WorkerSafe]` escape hatch used to paper over genuinely mutable state. The Mago Purge Protocol applies: clean means **zero output**._

### `[FIX-01]` Native-First Remediation of Every Finding

- **Specification:**
    - Resolve every CRITICAL / HIGH / MEDIUM / LOW from `[AUDIT-04]` at the source — behaviour-correct fixes with regression tests, not silencing.
    - **Prohibited:** `mago` baselines, inline `@mago-ignore` / `@`-error-suppression, coverage exclusions, or reclassifying a real defect as "won't fix" without recorded sign-off.
    - Contracts-first sequencing where a fix touches an interface: the contract change lands in `waffle-commons/contracts` before its consumers; the `mago guard` perimeter stays non-negotiable.

### `[FIX-02]` Full Gate Re-Verification (Definition of Done)

- **Specification:**
    - Per modified component: `composer mago` (zero output — errors **and** warnings/info/help), `composer tests` ($\geq 95\%$ coverage), `wfl igor` **0 KO**.
    - Ecosystem-wide `wfl check:all` / `wfl dod` green; both template apps (`skeleton`, `workspace`) boot-smoke clean; `wfl compare-audit` (SEC-03 gate) shows no vendor skew.

## 📚 AXE 3: DOCUMENTATION MODERNIZATION (DIÁTAXIS)

_The documentation must be as trustworthy as the code. Beta6 brings the **entire** documentation surface — the in-repo per-component `docs/` trees and the central `documentation/` submodule — into strict Diátaxis compliance: four quadrants, each page in exactly one._

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

- **AUDIT:** three independent engine passes complete across all 21 decoupled components; findings consolidated and severity-reconciled in `project_system/Audits/Beta6/`; zero un-triaged findings.
- **REMEDIATION:** every finding fixed natively or formally risk-accepted with sign-off; **zero** Mago baselines/suppressions introduced; `composer mago` zero output, `composer tests` $\geq 95\%$ coverage, `wfl igor` **0 KO** on every modified component.
- **DOCS:** `documentation/` and every component `docs/` tree strictly Diátaxis-partitioned (Tutorials / How-To / Reference / Explanation); reference pages verified against the current public API.
- **ECOSHIELD:** the `ecoshield-gateway` POC proxies traffic on the FrankenPHP worker runtime with $8\,\text{KiB}$ streaming buffers, built only on public APIs, `wfl igor` **0 KO**.
- **BENCH:** the tri-engine K6 harness is reproducible; constant-load percentiles ($p_{50}$ / $p_{95}$ / $p_{99}$ / $p_{99.9}$) and the RAM factor are published; the soak proves $\Delta M = 0$ on both worker-mode engines; pool-starvation behaviour is characterized with zero connection leakage.
- **All items:** contracts-first sequencing on any interface change; `composer mago && composer tests` green, $\geq 95\%$ coverage, zero Mago baselines, `wfl igor` **0 KO**; the beta6 tag follows the release-wave mechanics (umbrella tag pushed → dry-run on the pushed tag → LIVE wave).
