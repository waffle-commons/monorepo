---
title: "Log Beta 6"
date_created: '2026-08-03'
date_updated: '2026-08-22'
type: project
status: archived
tags:
  - waffle
  - beta6
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle 0.1.0-beta6

> [!SUMMARY]
> Goal: **stop and harden.** No new components. Independent multi-engine security audits across all
> 21 decoupled components, zero-compromise remediation, a full Diátaxis documentation pass, and the
> first scientific benchmark converting the runtime performance claim into published, reproducible
> numbers ahead of API Platform Conference (Lille, September 17–18). Released: 2026-08-22.

## 1. Technical Changelog (What changed)

### Security — AXE 2 remediation (17/17 native fixes, zero suppressions)

| Area | Change | Component |
|---|---|---|
| Injection | Strict identifier allow-list + consistent quoting on read **and** write paths | `data` |
| Injection | Maker validates interpolated CLI tokens; `php -l` before atomic write | `console` |
| Deserialization | Route cache rehydrates with `allowed_classes` (defence-in-depth) | `console` |
| AuthN | `BasicAuthenticator` username-enumeration timing oracle closed (CWE-208) | `auth` |
| AuthN | HS* secrets gain the 32-byte floor, enforced at construction | `auth` |
| Audit | CSRF + auth failures logged on the SECURITY channel with client IP | `security`, `auth` |
| AuthZ | `#[PublicAccess]` restricted to `TARGET_METHOD` | `contracts` |
| AuthZ | `SubjectResolverInterface` — object-level rules, lazy, voter-gated, fail-closed | `contracts`, `security` |
| Output | Controller string returns escaped by default + `RawHtml` opt-out + stricter CSP | `waffle` |
| Input | Route parameters validated before casting (422 instead of silent coercion) | `waffle` |
| Filesystem | Upload moves contained via `Assert::within()` | `http` |
| Config | Malformed YAML fails boot closed instead of degrading to empty config | `config` |
| Runtime parity | Compiled container memoises only inlined services (single reset per request) | `console` |

### Templates — defects found by benchmarking the shipped image

- **No `pdo_pgsql` / `pdo_mysql` in the production image.** The template shipped database config,
  migrations, a connection pool and DB-backed demo routes that could never work in its own image.
- **`/greet` accepted only GET** while its own docblock documented `POST` with a JSON body.
- **`driver: mysql` with no such service** in `docker-compose.yml`; switched to pgsql + a
  `waffle-postgres` service.
- **Public demo routes lacked `#[PublicAccess]`** and returned 403 through the real pipeline.
- Added `GET /read/demo` (pooled read) and a `DB_POOL_SIZE` knob; extracted `ConnectionPoolFactory`.

### Documentation — AXE 3

Central `documentation/` is the canonical Diátaxis tree. `explanation/architecture.md` rewritten to
the real 21-component ecosystem; `performance.md` de-orphaned and now carrying the published
benchmark figures; duplicate `how-to/security.md` merged away; two tutorials added; **a `#[Rule]`
attribute documented across six pages that has never existed** removed corpus-wide. Link graph
verified: 331 links, zero broken, zero anchor mismatches. `async` received its first repository
documentation pack.

### Infrastructure

- `umbrella-ci`: dedicated `workspace` job (22-path scoped submodule init, academy excluded) and a
  **fail-closed `gate`** — it previously reported success when its own change-detector crashed.
- New `bench/` harness (BENCH-01…05) with a bootstrap-scripted, gitignored Symfony app.

## 2. Benchmark results (AXE 5)

Full method and raw data: `bench/BENCH-GATE-RESULT.md`.

| Gate | Verdict |
|---|---|
| BENCH-01 reproducible harness | ✅ PASS |
| BENCH-02 latency percentiles | ✅ PASS |
| BENCH-02 "5–10× RAM factor" | ⚠️ **not testable by that rig** — superseded by BENCH-05 |
| BENCH-03 soak ΔM | ✅ PASS |
| BENCH-04 pool starvation | ✅ PASS — 868 req/s at 8× oversubscription, p99.9 98 ms, zero errors |
| BENCH-05 memory vs concurrency | ✅ PASS — **claim reframed** |

**Headline (vs Symfony on php-fpm, on its most favourable dynamic pool):** 781.6 vs 100.5 req/s
(**7.8×**) at 8.7× lower p50; **memory grows 10.5× slower per concurrent request**.

**Deliberately not published:** a bare "5–10× less RAM". Measurement shows php-fpm uses *less* total
RAM below ~12 concurrent requests, crossing over at 12–16 and reaching 2.37× at 128. The slope is
the defensible claim.

## 3. Quality gates

- `wfl check:all --with-tests`: **23/23 components green** (Mago zero-output, PHPUnit green).
- `wfl igor`: **0 KO** ecosystem-wide.
- Coverage on the components changed this cycle: `console` 98.05 %, `security` 99.12 %.
- `compare-audit` clean; `boot-smoke` green on both template apps.
- **30-agent adversarial review: 0 blocking**, 5 important (all fixed), 1 finding refuted.

## 4. Known gaps carried forward

- **AXE 4 EcoShield-Gateway POC** — see `Roadmap_Beta7.md`.
- The A-vs-C benchmark compares Waffle's 12-middleware secured pipeline against a bare 2-bundle
  Symfony app; an equivalent-features engine is beta7 work.
- Pool ping-before-dispense doubles DB round trips — beta7 optimisation, identified here.

## 5. Release mechanics

Component branches `pre-release/0.1.0-beta6` → push → **merge into each repo's default branch
(fast-forward or merge commit, never a squash)** → re-pin the umbrella gitlinks → umbrella tag
`0.1.0-beta6` (no `v` prefix) → dry-run on the pushed tag → LIVE wave. The merge step is mandatory:
`release-wave.yml` refuses to tag any component whose gitlink SHA is not an ancestor of its default
branch, and a squash-merge orphans the branch tip and fails the whole wave. `composer update` is run
across submodules before each push and again after publication.
