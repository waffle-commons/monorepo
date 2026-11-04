---
title: "Waffle Ecosystem Roadmap: (Beta 7)"
date_created: 2026-06-07
date_updated: 2026-10-31
type: project
status: in-progress
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — PENDING ECOSYSTEM ROADMAP 0.1.0-beta7

> **Status:** In progress — kicked off in September 2026 (release branches 2026-09-25, tooling and scaffolds 2026-09-29; see *Kickoff state & carry-overs* below). Mid-October checkpoint met on 2026-10-17: no split (see *Capacity guard*). Full scope decided 2026-10-21: nothing is cut, tag targeted for 5 November 2026. Acceptance check 2026-10-31 (see *ACCEPTANCE CRITERIA*): every criterion passes, NET's since the concurrent-limiter test of that day. `[CARRY-02]` re-measured on 2026-11-01: the clean full run is recorded and, since 2026-11-02, published in `bench/BENCH-GATE-RESULT.md` (the two earlier runs are kept as invalidated series); the two `[API-01]` follow-ups were built and the two `[NET-01]` spec points settled the same day
> 
> **Target Release:** **November 2026** — tag targeted for 5 November (re-dated 2026-10-21 from October 2026; the first release after the API Platform Conference, Lille — September 17–18, 2026)
> 
> **Core Mandate:** Close every gap between "high-performance framework" and **full production-ready API ecosystem**: traffic protection, outbound resilience, background processing, Kubernetes operability, API tooling, and testability. This is the release where the missing components get built — beta8 then freezes, so anything not landed here is post-v1.
> 
> **Commitment Tiers:** Committed — AXE 1 (NET), AXE 2 (QUEUE contracts + driver), AXE 3 (OPS), AXE 5 (TEST) · High — AXE 4 (API) · Stretch — `[DXP-01]`, `[GATE-02]` (kept in scope on 2026-10-21, see below).
> 
> **Capacity guard (added 2026-09-08, amended 2026-10-06):** beta7 is the **heaviest release of the train in the shortest window** — four brand-new repositories (`queue`, `openapi`, `serializer`, `testing`, each needing repo creation, scaffolding, CI, a `RELEASE_INCLUDE` entry and a first Packagist publication) plus eleven items across five axes. Plan against the measured evidence, not the intent: umbrella-tag cadence has run beta3→beta4 in 7 days, →beta5 in 24, →beta6 in 62. Beta6 was code-complete on 2026-08-02/03 and tagged in September, but that ~5-week tail was the maintainer's time off, not verification, documentation or wave prep, so it is not a planning baseline. The 2026-09-29 kickoff leaves about four weeks of build before an end-of-October tag. **Therefore:** the stretch tier (`[DXP-01]`, `[GATE-02]`) is cut on first contact with the schedule, not renegotiated late; and unless `[API-01]`, `[API-02]` and `[TEST-01]` have code landed and green on their own gates by **mid-October** (`wfl dod` green on `openapi`, `serializer` and `testing` with tests and coverage switched on), split the release — NET + OPS + QUEUE tag as beta7 in October, API + TEST fold into the beta8 window — instead of letting beta7 slide into November. **The freeze date (beta8, November) is what is being protected here; beta7's scope is not.**
>
> *Amended 2026-10-06:* the beta6 tail was first read as release work ("roughly five weeks of verification, documentation and wave prep"); it was time off. The checkpoint first asked for the four new repositories to be "scaffolded and green on their own gates", which the empty scaffolds already met on 2026-09-29 (tests and coverage switch on with the first class), so it now checks the items' code.
>
> *Checkpoint 2026-10-17 — met, no split:* `wfl dod` PASS on `openapi` (98.71 %), `serializer` (98.94 %) and `testing` (100 %), igor 0 KO, and `wfl check:all --with-tests` 27/27. The maintainer decided not to split: API + TEST stay in beta7. The stretch tier stays cut.
>
> *Decision 2026-10-21 — full scope, tag on 5 November 2026:* the maintainer decided that beta7 cuts nothing: `[DXP-01]` and `[GATE-02]` stay in scope, which supersedes the "stretch tier is cut on first contact" rule above and the 2026-10-17 note. Reason: finishing the production surface completely in beta7 matters more than an October tag; the maintainer works on it full-time from 2026-10-21 to 2026-10-23, then verification, docs and wave prep run to the tag. Per the master roadmap corollary, the later rows moved by the same week on the same day: beta8 ~3 December, RC1 ~12 December, Gold late January 2027 (`Roadmap_v1_Master.md`).

## 🧰 KICKOFF STATE & CARRY-OVERS (2026-09-29)

### Where the release starts

- **Branches:** every repository (umbrella + 30 submodules) is on `pre-release/0.1.0-beta7`.
- **New components scaffolded** from `component-template` (namespace · package): `queue`
  (`Waffle\Commons\Queue`), `openapi` (`Waffle\Commons\OpenApi`), `serializer` (`Waffle\Commons\Serializer`),
  `testing` (`Waffle\Commons\Testing`). Each passes its Definition of Done on the empty scaffold (mago zero
  output, igor 0 KO; tests and coverage start with the first class), is in the `umbrella-ci` paths filter,
  and has its git hooks. **Maintainer actions still open:** commit the configured files and gitlinks,
  register the four packages on Packagist, set merge-commit-only + delete-branch-on-merge on the four
  repositories, add each one to `RELEASE_INCLUDE` when it ships code.
  - *Status 2026-10-29:* committed, and all four ship code, so they joined `RELEASE_INCLUDE` (27 paths).
    Still open, the maintainer's: Packagist (each package answers 404) and the repository settings
    (squash and rebase merges still allowed, delete-branch-on-merge off), both before the wave.
  - *Status 2026-10-31:* the repository settings are applied on the maintainer's request: merge commits only (squash
    and rebase off), delete-branch-on-merge on and `allow_update_branch` on: the merge settings now equal `contracts`'.
    Still open before the wave: Packagist (each package still answers 404).
  - *Status 2026-10-31, evening — done:* each repository's `main` still held the template's placeholder
    `composer.json`, which Packagist rejects. On the maintainer's request it was fast-forwarded to the scaffold commit
    (queue `1e3f1ab`, openapi `27ccf1e`, serializer `c22e519`, testing `77f8bf8`: no code, no tag; CI green), and the
    maintainer registered the four packages the same evening. Each answers 200 with `dev-main` (checked 2026-11-02);
    the first version, `0.1.0-beta7`, arrives with the wave. The method is now in the `component-scaffold` skill.
- **Toolchain baseline for the release** (the whole Dependabot backlog, applied in lockstep): mago 1.50,
  psalm 6.19, igor-php **0.9.7** (pinned by `.igor-version`, enforced in CI and in `wfl dod`), GitHub
  Actions checkout v7 / cache v6 / codecov v7 / paths-filter v4, TruffleHog pinned to a release instead
  of `main`, FrankenPHP **1.13.2** / PHP 8.5.12 (bumped from 1.12.7 / 8.5.11 on 2026-10-22: both are the
  2026-10-21 security releases for PHP2Shell, CVE-2026-109618 and CVE-2026-109619). PHPUnit 13 is a major and
  stays out of this release unless an item needs it. **`pcntl`** joined the development image, the
  skeleton `base` stage and the bench engine on 2026-09-30: the SIGTERM drain of `queue:work`
  (`[QUEUE-02]`, `[OPS-02]`) depends on it.
  - *Toolchain refresh 2026-11-02 (maintainer: every Composer dependency to its latest minor/patch, mago and
    igor shipped in beta7):* mago **^1.59**, igor-php **0.10.1** (`.igor-version` and every CI pin), psalm
    ^6.20, php-mock-phpunit ^2.16, PHPUnit 12.5.42, TruffleHog v3.99.7; every third-party lock entry
    refreshed, `waffle-commons/*` entries left for the release-day relock. academy `labs` and `sandbox` moved
    to `prefer-stable` (stable PHPUnit and mago instead of dev branches). Mago 1.59 fixes landed in `config`
    and `routing` tests, `RouteParser` and telemetry's `ArrayCache` double. Gates: 27 projects `wfl dod`
    PASS and `psalm --taint-analysis` clean; academy labs `composer verify` (answer key) OK, 54 tests.
    Majors stay out: PHPUnit 13.4 and Predis 3.7 go to beta8.
- **RFC homes (2026-09-30):** `[OPS-01]`/`[OPS-02]` are specified in **RFC-023** (Kubernetes Operability) and
  `[NET-02]`/`[NET-03]` in **RFC-024** (Outbound Resilience); `[OPS-03]` stays in RFC-014 and `[NET-01]` in
  RFC-017 §3.1. Each RFC lists the design questions to settle before its code lands.
- **Guard-rails added:** one canonical component CI workflow (`wfl ci:check` reports any drift), igor pin
  robust to the vendor cache, `wfl mcp:check` proving every MCP server with a real session, read-only
  `wfl sync:status`.

### Carried over — schedule these alongside the axes

- **`[CARRY-01]` Pool ping-before-dispense within a freshness window** (Retro_Beta6 §6): the benchmark traced
  Waffle's early saturation knee to the doubled DB round trip. Make the ping skippable when the
  connection was verified recently; keep the fail-safe for stale ones. Contracts-first if the pool
  contract changes.
  - *Status 2026-10-22 — done, gate passed (data `3f7612e`, skeleton `7926665`, documentation `6af2531`):*
    - `PDOConnectionPool(pingFreshnessMs)`, default 0: no probe within that many ms of a proof of life
      (a connection or an answered probe; a returned lease is not one, the pool never sees caller
      errors). `ConnectionPoolHealthCheck` asks `isAlive()` itself. The skeleton passes
      `DB_PING_FRESHNESS_MS`, default 500. The pool contract is unchanged, so nothing went to contracts.
    - Gate (`data/benchmarks/CARRY-01-GATE-RESULT.md`, thresholds fixed before the comparison):
      transactions per pooled read 4.21 → 2.12 and per POST 3.15 → 1.07; `dbread` knee 1200 → 1500 and
      ≥ 1600 rps in two interleaved repeats; dead connections caught (a worst-case kill fails reads for
      286 ms at W = 500, none at W = 0). One laptop, a relative measurement. The beta6 knee (400 rps) no
      longer reproduces: the unchanged code already held 1200 rps on today's rig.
    - Not in scope, noted: `exec()` would make the remaining probes one round trip instead of two (all
      drivers; SQL Server and Oracle unverifiable here); the Redis pool still probes every lease (no
      Redis in the bench).
- **`[CARRY-02]` Benchmark harness hardening** (before any new public number): run-unique result file
  names (a re-run must never overwrite a series); Engine C on symfony/runtime 7.4's native
  `FrankenPhpWorkerRunner` with `FRANKENPHP_LOOP_MAX=1000000` and no `APP_RUNTIME` override (its
  500-request default invalidated the beta6 soak comparison); Engine C in the memory test; an
  equivalent-features Symfony engine (security + CSRF + transaction subscriber) next to the bare one;
  host hardware recorded with every run; least-squares slopes published with their uncertainty.
  - *Status 2026-10-22 — rig done; re-measurement open (umbrella `34bfe84`, `4561370`, `5d2679a`):*
    - Done: run-unique result files (run id on the summary, RSS and new host files, and a run refuses to
      overwrite a series), a host record per run (host, Docker VM, engine limits, commit), and soak slopes
      with their 95 % bound in `report.sh` (`34bfe84`; checked on a synthetic +10 MB/h soak: +10.01 ± 0.10).
      Engine C on the native runner with `FRANKENPHP_LOOP_MAX=1000000` and no `APP_RUNTIME`, the bridge
      package removed, and `engine-c-mem` as BENCH-05's third leg (`4561370`). Engine D, the
      equivalent-features engine (A's per-request work in Symfony: trusted hosts, CORS, firewall,
      per-action authorisation, stateless CSRF, headers, one transaction per unsafe request; no
      telemetry, as decided), with `engine-d-mem` and `scripts/check-features.sh` (`5d2679a`).
    - Evidence: a probe on the rebuilt image sent 3 000 requests twice; the workers restarted 5 times at a
      loop max of 500 and never at 1 000 000. The first runs of the new harness passed: the Engine C smoke
      (every check, run `20261022T115850Z`) and a 3 × 30 s `engine-c-mem` memscale (run
      `20261022T120027Z`), each with its host record. `check-features.sh` passed on A, C and D (A and D
      answer 400 to an untrusted host and 401 to a junk token and send the three headers; commits for
      200 `POST /greet`: A 603, D 207, C 4), and the A and D smokes and a short D-mem memscale finished
      with no failed request. These are harness checks, not published numbers.
    - Found on the way: Compose read the tmpfs `mode: 1777` as decimal (octal 3361), so Engine A could
      not boot on beta7 (fixed in the rig, and in `skeleton/docker-compose.prod.yml`, which had the same
      four lines: skeleton `a50dea2`). A's `/greet` costs three commits, the transaction plus the pool's liveness `SELECT 1`
      (`[CARRY-01]`'s subject).
    - Open: the re-measurement on the new rig (FrankenPHP 1.13.2): BENCH-02 for A, C and D, BENCH-03 for
      C and D, and BENCH-05 for all four legs.
    - *Scheduled 2026-10-31:* the re-measurement runs on the night of 2026-10-31 on an idle laptop (the
      maintainer's decision), and its results are analysed and recorded before the tag. The bench images
      were pinned by digest that day (umbrella `ef92b0a`): k6 2.3.0, the same build as the earlier runs,
      and Engine B on `php:8.5.12-fpm`, the PHP of engines A, C and D, instead of the floating `php:8.5-fpm`.
    - *Status 2026-11-01 — first run; superseded the same day (see below), not publishable as a whole:*
      - Run `carry02-20261031T164459Z` (16:45–23:11 UTC, `bench/scripts/run-carry02.sh --stop-others`): 20 runs,
        all exit 0, no failed request except Engine B's memscale (1.4 %, a saturated FPM). Host: i7-9750H, a
        12 vCPU / 13.6 GiB Docker VM; every engine at 2 CPUs and 1 GiB (6 GiB for BENCH-05); FrankenPHP 1.13.2 /
        PHP 8.5.12 with 4 workers in A, C and D, `MAX_REQUESTS` / `FRANKENPHP_LOOP_MAX` 1 000 000; k6 2.3.0 on the
        host. Archive (local): `project_system/Audits/Beta7/bench/carry02-20261031T164459Z/` — raw k6 JSON, RSS
        CSVs, host records and `REPORT.md`.
      - **BENCH-03 (machine thought idle — it was not, see below):** C and D at 150 rps for 2 h, 1 080 001 requests each, about 270 000 per
        worker (no recycle possible), RSS sampled every 6 s with no gap. Slope over the settled window: C
        −0.46 ± 0.11 MB/h, D −0.74 ± 0.14 MB/h (n = 1 057; 95 % bound, understated by autocorrelation); ΔM −2.2 and
        −3.5 MB: PASS. No growth above those rates over 2 h — not a multi-hour claim. p99 4.1 and 4.6 ms, 0 errors.
      - **BENCH-05 (machine thought idle — it was not), RSS by concurrency** (dbread, 8 → 128 VUs, 2 min each): A 70.3 → 86.1 MiB,
        B (FPM, dynamic pool) 60.9 → 245.1, C 76.2 → 92.4, D 78.3 → 94.6. Slope per concurrent request: A
        +0.124, B +1.514, C +0.128, D +0.139 MiB. B/A: 0.87× at 8, 1.06× at 16, 2.85× at 128; the fitted lines
        cross at about 14 concurrent requests. FPM's memory grows 12.2× faster than Waffle's (beta6: 10.5×, 2.37×
        at 128, crossover 12–16 — a new series, on FrankenPHP 1.13.2 and `php:8.5.12-fpm`). At equal features
        (A vs D), A uses 6–9 MiB less at every step, its p99 at 128 VUs is 101 ms against 139, and the
        closed-model run reached 1 633 req/s against 1 372: one laptop, the generator on the same host, so a
        relative comparison, not a capacity figure.
      - **BENCH-02 — not publishable as run.** It overlapped light host activity (documentation work on the
        same laptop, 16:55–18:12 UTC, commits at 17:05, 17:11, 17:50, 18:03 and 18:09). Every engine held every
        rate (50–800 rps) with 0 errors and the medians agree, but the tails do not: dbread at 800 rps gave a
        p99 of 9.6 ms (A) and 12.4 ms (C) during the activity and 3.2 ms (D) once the machine was idle, although
        D does strictly more work than C; A's p99.9 at 200 rps (dbread 22.1 ms, dbwrite 18.0 ms) fell in the
        same window. The series is kept, invalidated for its tails.
      - *Re-run of BENCH-02 alone, 2026-11-01 00:05–01:42 UTC* (`run-carry02.sh --only=bench02`, umbrella
        `a68727a`; archive `project_system/Audits/Beta7/bench/carry02-20261101T000522Z/`): it confirms that the
        first run's BENCH-02 tails came from the work on the laptop (dbread at 800 rps: p99 3.9 / 3.1 / 3.2 ms for
        A / C / D, against 9.6 / 12.4 / 3.2), but the laptop was in use again: the power log shows audio over
        engine C's json run (00:45–00:47 UTC) and a video over engine D's (01:17–01:20 UTC: p99 120.7 ms at
        400 rps).
      - *Superseded 2026-11-01:* the power log (`pmset -g log`) also shows video playback through the first run's
        BENCH-05 and soaks, and a lid close with a brief sleep at 18:52 UTC (during `engine-c-mem`). Neither run
        was on an idle machine: both are kept as invalidated series and nothing from them is published. Open: the
        full chain again (`run-carry02.sh --stop-others`, about 7 h 30) on a laptop left untouched — no media, lid
        open, the pending macOS update postponed — checked against the power log for the whole window before the
        analysis; then the maintainer decides what `bench/BENCH-GATE-RESULT.md` publishes.
    - *Status 2026-11-01 — the clean run, recorded:* `carry02-20261101T015247Z`, 01:52–08:19 UTC, the full chain,
      20 runs, all exit 0. Archive: `project_system/Audits/Beta7/bench/carry02-20261101T015247Z/`, with the power
      log of the window (`pmset-window.log`).
      - **Idle check (`pmset -g log`):** no user input (only the periodic 15-minute summaries), no media playback,
        no lid close, no sleep, no update. Background only: two short system sounds (03:06 and 04:40 UTC, during
        D's json run and C's soak) and three Contacts syncs. One sync ran 02:18:11–02:19:47 UTC, over 95 s of A's
        dbread step at 800 rps: that step (p99 61.3 ms, p99.9 149.4) is flagged and not published.
      - **BENCH-02** (A / C / D, constant arrival rate, 2 min per step; every rate held, 0 errors):
        - json — parity: p50 2.1 / 2.2 / 2.3 ms at 50 rps, 0.8 / 0.8 / 0.9 at 800; p99 1.7 / 1.8 / 2.0 at 800.
        - database — A is slower: dbread p50 3.4 / 2.9 / 3.0 ms at 50 rps and 1.4 / 1.1 / 1.2 at 400; dbwrite 3.8 /
          3.2 / 3.4 at 50 rps and 1.8 / 1.3 / 1.5 at 800; A's p99 up to 0.8 ms above D's. Cause not investigated.
        - memory — A's RSS is 7.7–10 MiB below D's at every rate (dbwrite at 800 rps: 123.0 against 131.8 MiB).
      - **BENCH-05** (dbread, 8 → 128 VUs): slope per concurrent request A +0.118, B (FPM) +1.478, C +0.113, D
        +0.121 MiB — FPM's memory grows 12.5× faster than Waffle's; B/A 0.87× at 8, 1.04× at 16, 2.81× at 128;
        crossover at about 14 concurrent requests. Under this closed-loop saturation on 2 CPUs the throughput is A
        1 676, C 2 029, D 1 825 req/s (B 118.5, 1.16 % errors): A is 8 % below D, consistent with its slower
        database path, while using less memory (85.4 against 92.0 MiB at 128 VUs). The first run's ranking, with A
        highest, came from the disturbed laptop and does not hold.
      - **BENCH-03** (150 rps × 2 h, about 270 000 requests per worker, no recycle, 6 s sampling with no gap): C
        +0.15 ± 0.11 MiB/h with ΔM −1.0 MiB, D −1.00 ± 0.12 MiB/h with ΔM −3.7 MiB: PASS — flat within the instrument
        over 2 h, not a multi-hour claim. p99 3.2 and 3.5 ms, 0 errors.
      - Limits: one laptop (i7-9750H), the k6 generator on the same host, 2 CPUs per engine: relative comparisons,
        not capacity figures. The two earlier runs stay archived as invalidated series.
      - *Published 2026-11-02 (the maintainer's decision):* `bench/BENCH-GATE-RESULT.md` now opens with the Beta7
        series — method, environment, the three benchmarks, what the run does not establish, how to quote it, the
        invalidated series — and reproduces `report.sh`'s tables; the Beta6 record follows unchanged, marked as not
        current. Memory figures are MiB (`report.sh` labels them MB but divides by 1 024²).
      - Still open, neither blocking the tag: a re-run of A's dbread (about 11 min) to replace the flagged step, and
        the database-path gap between A and D, a beta8 performance question.
- **`[CARRY-03]` "Keeps state on purpose" design note** (API Platform Conference feedback, 2026-09-17):
  runtime reset is already opt-in (`Container::reset()` resets only Resettable services); the strictness
  lives in the dev-mode `ComplianceScanner` and the igor gate, with `#[WorkerSafe]` as the only escape
  hatch. Decide — as an RFC-001 amendment, not code — whether a first-class "intentional state" marker
  is needed and how it differs from `#[WorkerSafe]`.
  - *Status 2026-10-22 — decided (RFC-001 §5):* no second marker for v1. `#[WorkerSafe(reason: …)]` is the
    declared marker for state kept on purpose, and `ResettableInterface` stays optional (runtime reset is
    already opt-in, as in Symfony; the strictness stays in the dev `ComplianceScanner` and the igor gate).
    §5 adds where each kind of state goes and the rules for the attribute; no contracts symbol for the
    freeze. The `#[KeepsState]` idea goes upstream instead: an igor-php issue (French, for its maintainer
    first) is drafted in `project_system/Notes/`, not posted.
- **`[CARRY-04]` Perimeter design for `testing` and `openapi` — decided 2026-10-07:** `WaffleTestCase` must
  boot a kernel and `openapi:generate` must read route and DTO metadata without importing a sibling's
  concrete classes. The kickoff expected three new seams. A single contracts change covers it (the clock
  requirement and one property), with no recorded exception:
  - **Routes: no new seam.** `RouterInterface::getRoutes()` already returns `MatchedRoute` objects that carry
    the controller class and method, the path, the HTTP methods, the name and the argument types.
    `route:list`, `route:compile` and `security:audit` already consume it, and `security:audit` reflects on
    the controller method at build time: the pattern `openapi:generate` follows.
  - **Clock: PSR-20.** `psr/clock` joins the nine PSR packages contracts already requires. A system clock
    lives in `utils`, a frozen, advanceable clock in `testing`. New beta7 code (`[NET-01]`, `[NET-03]`,
    `[QUEUE-02]`) takes the clock by injection from its first class. The components that read the time
    directly today (auth, security, cache, telemetry, log) can move over later. Whether the limiter or the
    breaker also needs a monotonic reading is settled in RFC-024 §5.
  - **Kernel and doubles: the container on the kernel contract.** `KernelInterface` declares
    `public ContainerInterface $container { get; }`, the property `AbstractKernel` already exposes. There is
    no kernel-factory contract: `WaffleTestCase` gets the kernel from an abstract `createKernel()` that the
    app implements, and swaps its doubles in between `boot()` and `configure()`, before the container
    locks. Accepted limit: a double reaches what the container resolves (controllers and their
    dependencies), not a collaborator that an app factory builds up front. The app factories also register
    `ServerRequestFactoryInterface`, so a test builds its requests without importing `http`.
  - **`openapi:generate` lives in `openapi`**, as a `Console\CommandInterface` implementation registered in
    `bin/waffle` like the console commands. `console` needs no generator contract.
  - **DTO shape: one build-time reader in `utils`** (constructor parameters in, readable properties out,
    hooks, asymmetric visibility, nested DTOs). The serializer's normalizer compiler and the OpenAPI schema
    builder share it, so the spec matches what the serializer accepts and emits.
  - **PHPUnit:** `testing` requires `phpunit/phpunit` ^12.5, and its guard permits `PHPUnit\**` in one
    sub-namespace only, so the kernel client and the doubles stay free of PHPUnit.
  - **Rejected:** a kernel-factory contract with test overrides (a test-only parameter in a contract that
    beta8 freezes); a generator contract so that `console` can host the command; `openapi` reflecting DTOs
    on its own (the spec would drift from the serializer); a Waffle-specific clock interface (non-standard,
    so PSR-20 libraries would need an adapter).
- **`[CARRY-05]` igor 0.9.x write-through false positives:** 0.9.x flags writes *through* an injected
  service (`$this->cache->set(…)`) as "mutation on an injected dependency". Each case in this release is
  adjudicated in code (fixed or `#[WorkerSafe]` with its reason); propose the detector fix upstream in
  the igor-php fork.
  - *Status 2026-10-22 — adjudication done; the detector fix waits for its upstream PR:*
    - `wfl igor` audits 28 targets with 0 KO. The only warning is the `component-template` scaffold, skipped
      because it does not install igor. Every 0.9.7 finding carries a method-level `#[WorkerSafe]` with a
      verified reason: 78 in all, 27 of them for write-through in `cache`, `data` and `telemetry`.
    - Root cause: igor records a property-level `#[WorkerSafe]` (promoted parameters included), and its
      direct-write and `reset()` checks honour it. The injected-dependency rule never read it, although the
      README says such a property's mutations are ignored. So each method writing through the dependency
      needed its own attribute.
    - Fix: in the fork (`contributions/igor-php`), branch `fix/worker-safe-injected-dependency`, commit
      `3655cbd`, on upstream `main`. The rule skips calls through a `#[WorkerSafe]` property. Fixture, visitor
      test and README are updated. `make docker-ci` passes, and the Go sources never name Waffle. The same
      fixture reports 4 findings on `main` and 2 with the fix.
    - Open: pushing the branch and opening the PR are the maintainer's. Once a release carries the fix and
      the pin moves, the 27 method-level annotations become one per dependency. Upstream is at 0.10.1;
      whether to bump from 0.9.7 before the freeze is a separate decision.
  - *Decision 2026-11-02 — beta7 ships with igor-php 0.10.1:* the maintainer asked for the auditor bump in
    this release. 0.10.1 does **not** carry the fork fix (`3655cbd` is not an ancestor of `v0.10.1`), so the
    27 method-level annotations stay; the upstream PR is still the maintainer's. 0.10.0 widened the
    process-state rule (upstream #85: `chdir`, `umask`, `mb_internal_encoding`, `bcscale`,
    `set_error_handler`, `register_shutdown_function`, `gc_disable`, `header`, `http_response_code`,
    `session_*` called during a request); `wfl igor` with 0.10.1 still reports 0 KO on every target.
- **`[CARRY-06]` Small follow-ups** (Retro_Beta6 §6): `Constant::ATTR_PARAMS` promotion, AOT compiled-memo
  runtime write-through, a PHPUnit step in the workspace CI job.
  - *Status 2026-10-22 — done:*
    - `contracts` names the route-params attribute `Constant::ATTR_PARAMS` (`'_params'`, pinned by a test).
      `CoreRoutingMiddleware` sets it, and `ControllerDispatcher` and the skeleton's subject resolver read it.
    - The compiled container builds its inlined services through the new `Container::memoise()`, so every
      path shares one instance and `reset()` resets it once. Beta-6's "one instance per memo" constraint is
      gone. `memoise()` only memoises ids the container can resolve, so it never adds one after `lock()`.
      The compiler refuses a runtime class without `memoise()`.
    - The workspace CI job runs PHPUnit against a Redis service on the dev compose's pinned image.
    - Evidence: `wfl dod` PASS on contracts, pipeline, waffle, skeleton, container, console and workspace.
      The new compiler tests fail against the previous compiler. A smoke against the real runtime container
      shows one shared instance and one reset per `reset()`. Only its first GitHub run will prove the CI step.
- **`[CARRY-07]` Workspace coverage policy — decided 2026-09-30:** the workspace demo app's coverage
  (54.40 %) is reported, not gated, in `scripts/dod.sh` as well — the same demo-app policy as `umbrella-ci`.
  It still has to pass mago, tests and igor; everything released (skeleton included) keeps the 95 % bar.
- **`[CARRY-08]` Skeleton OPcache preload — fixed 2026-09-30:**
  `config/preload.php` ran `opcache_compile_file()` over `vendor/waffle-commons` in directory order, which
  compiles without linking dependencies: 70 "Can't preload unlinked class" warnings at every PHP start, and
  those classes were not preloaded. The fix loads the framework classes through the Composer
  loader (`class_exists`), so parents and interfaces link first: 0 warnings, 470 → 503 preloaded classes,
  200/200 worker-mode requests served. The builder stage now runs `composer dump-autoload` before enabling
  preload (a file read during preload stays pinned for the whole process, so Composer read a stale map).
  Re-measure before quoting the beta6 benchmark again (it ran this image). Also open: the builder copies
  `composer.lock`, gitignored since beta6, so a `docker build` from a fresh clone fails at that `COPY`.
- **`[CARRY-09]` The stock skeleton production image could not serve a request — fixed 2026-09-30:**
  the skeleton Caddyfile's `frankenphp` block had no `{$FRANKENPHP_CONFIG}`, so
  the Dockerfile's `FRANKENPHP_CONFIG="worker ./public/index.php"` was ignored and requests ran in classic mode,
  where `WaffleRuntime::loop()` still called `frankenphp_handle_request()` (it only checked that the function
  exists) and FrankenPHP threw — HTTP 500 on every request, in the prod image and in the skeleton's dev compose.
  Fix: the Caddyfile interpolates `{$FRANKENPHP_CONFIG}` (as FrankenPHP's official one does), and the runtime
  detects worker mode through the `FRANKENPHP_WORKER` process variable (set only for worker scripts, readable
  at boot and in every request), handling exactly one request otherwise. Verified on the rebuilt prod image:
  stock config 200×50 in worker mode; classic mode 200×50 with the fix, 500×50 without it. Still to do: a
  production-image smoke test (build + request) in CI, and hot reload for the skeleton's dev compose (it now
  inherits worker mode, so code changes need a container restart).
  **Follow-up 2026-09-30:** FrankenPHP 1.12.2 does not export `FRANKENPHP_WORKER`, so the flag-only detection
  put every 1.12.2 worker in a restart loop, each one serving a bogus boot-time request (seen live on
  `waffle-downstream`). When the flag is absent, the runtime now lets the first `frankenphp_handle_request()`
  call settle the mode — in classic mode FrankenPHP refuses with a `RuntimeException` before touching the
  handler. Verified on real FrankenPHP 1.12.2 and 1.12.7, in worker and classic mode.
- **`[CARRY-10]` Framework defects surfaced by the EcoShield Gateway — fixed 2026-09-30:**
  - `error-handler`: `ErrorHandlerMiddleware` logged every exception at `critical` with a full stack
    trace, client errors included, so any client could grow the log at will and alerting on `critical`
    was meaningless. It now renders first and logs by the rendered status: 5xx at `critical` with the
    trace, 4xx at `notice` without it; a renderer failure still logs the original fault.
  - `http`: `GlobalsFactory` emitted `mkdir(): File exists` whenever workers booting together raced to
    create the upload root. The creation now runs under a scoped error handler (no `@`), and the
    `is_dir()` re-check still throws when the directory really cannot be created.
  - Both are covered by regression tests (the `mkdir` one fails when the fix is reverted); `wfl dod` passes
    on both components. The gateway itself moved to the beta7 toolchain the same day (mago 1.50, igor
    0.9.7 pinned in its CI) — its own repository, its own CHANGELOG.

## 🛡️ AXE 1: TRAFFIC PROTECTION & OUTBOUND RESILIENCE

_An API ecosystem that cannot defend its inbound edge or survive flaky upstreams is not production-ready. These are also hard prerequisites for EcoShield-Gateway._

### `[NET-01]` Token-Bucket Rate Limiter Middleware

- **Specification:**
    
    - Introduce `Waffle\Commons\Contracts\RateLimit\RateLimiterInterface` + `LimiterStateStorageInterface` in contracts (contracts-first).
        
    - Implement a Token Bucket limiter as a `security/` middleware, keyed by IP, authenticated subject (`UserIdentityInterface`), or API token.
        
    - Storage backends behind `LimiterStateStorageInterface` (atomic operations, in contracts), shared with `[NET-03]`: the Redis implementation lives in `data` over its connection pool (multi-worker correctness); an in-memory fallback is documented as single-worker only. *Amended 2026-10-17:* this bullet first read "through the existing cache contracts"; PSR-16 `get`/`set` cannot be atomic, so concurrent workers would over-admit and fail the NET acceptance criterion (RFC-024 §5.1, RFC-017 §3.1).
        
    - Storage unavailable (*decided 2026-10-17*): each limiter takes `on_storage_failure: open|closed`, default `open` with a warning log and a metric; `closed` is recommended on authentication endpoints. Authentication and authorization stay fail-closed regardless (RFC-017 §4).
        
    - Emit standard `RateLimit-*` response headers and a fail-closed `429` with `Retry-After`.
        
    - **Statelessness compliance:** limiter state lives exclusively in the storage backend, never in worker memory; `wfl igor` must stay 0 KO.
        
    - *Status 2026-10-31 — acceptance evidence:* the Redis store (`data`'s `RedisLimiterStateStorage`) refills and takes in one Lua script on the Redis clock. `RedisLimiterConcurrencyTest` (data `ea371a3`) starts 8 PHP processes, each on its own connection, that wait for one shared instant and make 800 calls on a 50-token bucket: exactly 50 are allowed, in 4 runs out of 4. The same harness on a deliberately non-atomic read-then-write store admitted 299, 225 and 243, so the test catches a racy store (archive: `project_system/Audits/Beta7/net-limiter-concurrency/`). Two spec points are not built; recording them as scope changes or building them is the maintainer's call: the in-memory store "documented as single-worker only" (the contract has one implementation, Redis), and a key per API token (an API key is limited through the subject of the identity it authenticates).
        
    - *Decision 2026-10-31 (the maintainer):* the in-memory store ships as `testing`'s `InMemoryLimiterStateStorage` (testing `6920331`): the Redis store's arithmetic on an injected clock, a single-process test double and never a production store, since worker memory would break the stateless mandate. API keys stay limited through the subject of the identity they authenticate; no per-token key is added.
        

### `[NET-02]` HTTP Client Resilience Policies

- **RFC:** RFC-024 §3.1 (outbound resilience policy); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Extend `waffle-commons/http-client` with declarative per-request policies: connect/total timeout (mandatory defaults — no infinite timeouts anywhere), bounded retry with exponential backoff + jitter, and idempotency awareness (never auto-retry non-idempotent methods unless explicitly opted in).
        
    - Policies are immutable DTOs; configuration lives in config, not code.
        
    - Compose with the beta4 `[SEC-02]` SSRF guardrail (resolve → validate → pin runs on every retry attempt).
        
    - *Status 2026-10-17:* landed — contracts `TimeoutPolicy`/`RetryPolicy`, `Client::withTimeouts()`, `RetryingClient`; the concurrent path is not yet covered (RFC-024 §3.3).
        
    - *Status 2026-10-21:* the concurrent path is covered (RFC-024 §3.3). `RetryingClient` and `CircuitBreakerClient` settle batches through http-client's `SettlingClientInterface`: retries in waves, the breaker checked for every request before any is sent, promises deferred to the decorator. The workspace wires both clients from the `waffle.http_client.resilience.*` / `.breaker.*` keys (leaf names in RFC-024 §5.3), with the breaker state in Redis; live, the fan-out and proxy calls record their outcomes on their origins' circuits. Still open for `[NET-02]`/`[NET-03]`: the skeleton wiring (it has no Redis pool factory yet).
        
    - *Fault injection, 2026-10-21 (workspace stack: multi-worker FrankenPHP, shared Redis, policy 50 % / 10 calls / 60 s / 30 s cool-down / 1 trial):* `waffle-downstream` stopped under the fan-out route. The first failing request opened the circuit. While open, requests failed fast (503 in 11–23 ms, no call sent). After the cool-down, the trial with the upstream still down re-opened it; with the upstream back, the trial closed it. `/waffle-metrics` counted transitions to open 2, half_open 2, closed 1. The first run exposed a defect: since beta5 every transport failure read as `RequestException`, so it was never retried or counted. The fix is http-client 975881b, which drains the multi handle's completion messages.
        
    - *Status 2026-10-22:* the skeleton is wired too, which closes the open point above. `App\Factory\RateLimitFactory` mounts the `[NET-01]` limiter right after authentication, and `App\Factory\HttpClientFactory` wraps both outbound clients in `RetryingClient(CircuitBreakerClient(…))`, the authenticated one becoming `AuthenticatedSettlingClient`. Both run on a phpredis pool (`App\Factory\RedisPoolFactory`) and read their Redis from a `redis_dsn` key (RFC-024 §5.3, added that day). The template's dev compose gains a `waffle-redis` service, which also fixes a boot failure found on the way: the default Redis cache had no server, so the kernel never booted in dev. Evidence: `wfl dod skeleton` PASS (coverage 97.03 %, floor 96.58 %). On the skeleton's own dev stack, `/readyz` answered 200 with the cache probe up and the first request carried `RateLimit-Limit: 120`. The 122nd request of the minute got 429 with `Retry-After: 1`, and `/healthz` still answered 200 while throttled.
        

### `[NET-03]` Circuit Breaker

- **RFC:** RFC-024 §3.2–3.3 (circuit breaker, composition with retries); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Implement a circuit breaker (closed/open/half-open) wrapping outbound calls, with failure-rate thresholds and cool-down windows.
        
    - State storage through the same `LimiterStateStorageInterface` family as `[NET-01]` — shared across workers via Redis, never in-process.
        
    - Expose breaker state transitions as events (kernel lifecycle hooks from beta4 `[ARCH-04]`) and as metrics on `/waffle-metrics` (beta5 `[OBS-02]`).
        

## 📨 AXE 2: BACKGROUND PROCESSING (NEW COMPONENT `waffle-commons/queue`)

_Beta5 `[ASYNC-01]` is finish-request deferral and explicitly **not** background processing. Production APIs need real job dispatch. Scope is deliberately minimal: contracts + one solid driver + a worker — not a Symfony Messenger clone._

### `[QUEUE-01]` Queue Contracts

- **Specification:**
    
    - `Waffle\Commons\Contracts\Queue\`: `MessageInterface`, `QueueDispatcherInterface`, `QueueConsumerInterface`, `FailedMessageStoreInterface`.
        
    - Messages are strictly-typed, serializable DTOs (no closures, no object graphs); envelope carries id, attempts, available-at, and trace context (W3C propagation from beta5 `[OBS-01]`).
        
    - *Status 2026-10-31 — done:* `Waffle\Commons\Contracts\Queue\` holds the four interfaces and the `Envelope` (id, attempts, available-at, W3C trace context), committed before their consumers (contracts `2681186`, 2026-10-09). `queue`'s `EnvelopeCodec` decodes through the serializer and a class allowlist built from the handlers, never `unserialize()`. The dispatcher records the current trace context, and each message continues the trace that dispatched it.
        

### `[QUEUE-02]` Redis Streams Driver + Console Worker

- **Specification:**
    
    - One reference driver on Redis Streams (consumer groups give ack/retry semantics for free); additional drivers are post-v1.
        
    - `bin/waffle queue:work` console command (lives in `console/`, depends only on contracts per the established perimeter): bounded retries, dead-letter via `FailedMessageStoreInterface`, graceful SIGTERM drain (ties into `[OPS-02]`).
        
    - Worker is itself a long-running FrankenPHP-style process: must pass the Igor statelessness audit between messages.
        
    - *Status 2026-10-31 — done:* `queue` ships the Redis Streams queue and its dead-letter store, and `console` ships `queue:work` on contracts only, wired in the workspace `bin/waffle`. Retries are bounded, with a back-off that doubles per attempt; the last failure goes to the dead letter with its full envelope; the container is reset after each message; SIGTERM or SIGINT lets the message in flight finish, then the worker exits 0. Evidence: `RedisStreamsQueueTest::testAMessageSurvivesAWorkerCrash` and `RedisFailedMessageStoreTest` against real Redis (the crash is simulated in one process: a receive without an ack, reclaimed by another consumer), and `QueueWorkCommandTest` with real signals (`posix_kill`) and a scripted consumer. Not archived: the 2026-10-10 end-to-end runs with real processes (SIGKILL reclaim, SIGTERM drain, dead letter). The component CI workflow (the template's) starts no Redis service, so on GitHub the Redis-backed tests of `queue` and `data` are skipped; the local gate runs them against `waffle-redis`. Both points were closed the same day (see *ACCEPTANCE CRITERIA*): a live `queue:work` run is archived, and CI starts Redis.
        

### `[QUEUE-03]` Mailer Scoping Decision

- **Specification:**
    
    - Ship `Waffle\Commons\Contracts\Mailer\MailerInterface` + message DTO **contract only**; transactional mail is dispatched as a queue message.
        
    - SMTP/API transport adapters are explicitly **post-v1** (non-goal in the master roadmap); userland may bind any PSR-compatible mailer to the interface meanwhile.
        
    - *Status 2026-10-31 — done:* `Waffle\Commons\Contracts\Mailer\MailerInterface` and the `Email` message, a `MessageInterface` so that a mail is dispatched as a queue message, are contract only. The two implementations are a demo and a double: the workspace's `LogMailer` behind its `EmailHandler`, and `testing`'s `MailerSpy`.
        

## ☸️ AXE 3: KUBERNETES OPERABILITY

_"Production-ready on Docker/K8s" is the founding vision — these are the table stakes that don't exist yet._

### `[OPS-01]` Health & Readiness Endpoints

- **RFC:** RFC-023 §3.1–3.3 (health contract, endpoints, component probes); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Lightweight middleware exposing `/healthz` (liveness: process responsive) and `/readyz` (readiness: aggregated `HealthCheckInterface` probes — DB pool, Redis, queue driver, disk).
        
    - `Waffle\Commons\Contracts\Health\HealthCheckInterface` in contracts; components ship their own probes; fail-closed: an unregistered critical dependency means not-ready.
        
    - Constant-time, allocation-light handlers — these are hit every few seconds by orchestrators.
        

### `[OPS-02]` Graceful Shutdown & Connection Draining

- **RFC:** RFC-023 §3.4 (worker-mode signal path, shutdown sequence, CLI consumers); its open questions were decided on 2026-10-17 (§5).

- **Specification:**
    
    - Handle SIGTERM in the runtime: stop accepting work, flush deferred tasks (beta5 `[ASYNC-01]` if landed), return pooled connections (beta5 `[DBAL-01]`), close streams, then exit within the configurable grace period.
        
    - `/readyz` flips to not-ready immediately on SIGTERM so K8s stops routing before the drain (through the `preStop` drain marker, RFC-023 §5.1 — revised 2026-10-17 after Caddy's `shutdown_delay` proved to stop FrankenPHP 1.12.7 at SIGTERM). No explicit post-loop pool close (RFC-023 §3.4, decided 2026-10-17).
        
    - *Decision 2026-10-22:* the skeleton adds Caddy's `shutdown_delay` as a second path for runtimes without a `preStop` hook (Docker, Compose, ECS): `CADDY_SHUTDOWN_DELAY` (default `0s`, `5s` in `docker-compose.prod.yml` with `stop_grace_period: 35s`), during which Caddy answers `/readyz` with the public 503 while PHP serves the rest. Reason: on FrankenPHP 1.13.2, adopted that day for PHP2Shell, PHP keeps serving through the delay (200, where 1.12.7 answered 500, same harness), so the 2026-10-17 objection no longer holds. Evidence: `wfl drain-check` passes all 9 checks on 1.13.2 and fails 3 on 1.12.7 (RFC-023 §5.1).

    - *Acceptance 2026-10-29 — a rolling restart under k6 load loses zero requests, on both paths (`wfl rolling-restart`):*
      - Rig: two replicas of Engine A (the skeleton's production image built from this tree, FrankenPHP 1.13.2 on PHP 8.5.12, 4 workers each, the skeleton's Caddyfile as shipped) behind a Caddy load balancer that polls `/readyz` every second and never retries, as a Kubernetes Service does not. k6 runs natively at 100 rps for 75 s over the five bench workloads (reads, a validated POST, pooled DB reads and writes) while each replica in turn is drained, sent SIGTERM, restarted and waited for.
      - `--path=marker` (the `preStop` drain marker, then a 5 s sleep): 7 501 requests, 0 failed. `--path=delay` (`CADDY_SHUTDOWN_DELAY=5s`): 7 501 requests, 0 failed. Each replica exited 0, was ready again within 0.8 s of its restart, and received no request for 6.0 s, starting 0.3 s (marker) or 0.6 s (delay) after its drain began.
      - Control, `--path=none` (SIGTERM alone): 20 of 7 501 requests failed, all `502` from the load balancer within the second after each SIGTERM (connection refused, then the stopped container's name gone). So the check does detect lost requests.
      - Limits: one laptop (i7-9750H, Docker Desktop), Compose with a load balancer standing in for kube-proxy and the endpoints controller, two replicas, 100 rps; a correctness check, not a capacity figure. Runs `20261029T070208Z` (marker), `20261029T070334Z` (delay) and `20261029T070504Z` (control), with the earlier marker run `20261029T065924Z` (also 0 failed) and the first attempt `20261029T064905Z` (the load balancer's port was taken; no load ran). Archived locally in `project_system/Audits/Beta7/bench/rolling-restart/`.
        

### `[OPS-03]` Schema Migration Workflow Maturity

- **Specification:**
    
    - Build on the existing `data/src/Migration/MigrationRunner.php` — do not rewrite it.
        
    - Add versioned migration files, a ledger table, and console commands: `db:migrate` (it already exists — extend it), `db:rollback`, `db:status`, `make:migration` (Maker conventions from RFC-020). *Amended 2026-10-17:* the names first read `migrate`, `migrate:rollback`, `migrate:status`; `bin/waffle db:migrate` already ships, so the family keeps its `db:` prefix.
        
    - SQL dialects already supported by `data/` only; NoSQL backends are schema-less and out of scope. *Scope change 2026-10-17:* the live migrate/rollback round trip runs on PostgreSQL, SQLite, MySQL and MariaDB (the images carry `pdo_pgsql`, `pdo_sqlite` and `pdo_mysql`; MySQL and MariaDB need their own containers); SQL Server and Oracle are covered by SQL-generation tests only, because no image carries `pdo_sqlsrv` or `pdo_oci`. Their live round trip moved to `Roadmap_Post_v1.md`.
        
    - *Status 2026-10-21:* landed. `MigrationRunner::rollback()` and `status()` work through `V.down.sql` scripts and a per-dialect ledger (contracts `MigrationState`, `Enum\MigrationStatus`). `console` gains `db:status`, `db:rollback [--steps=N]` and `make:migration`, wired into the skeleton and the workspace. A script with no SQL statement is refused, never logged, so an unedited scaffold cannot be recorded as applied. Found on the way: every DDL migration failed on MySQL and MariaDB (implicit commit, then PHP 8's `commit()` threw); fixed. Evidence: the live round trip passes on PostgreSQL, MySQL 8.4 and MariaDB 11.4 (`MigrationRoundTripTest`, against the workspace `waffle-mysql`/`waffle-mariadb` services) and on SQLite (`MigrationRunnerTest`); `MigrationLedgerTest` covers the SQL Server and Oracle ledger SQL; the full CLI cycle (make → refuse unedited → migrate → status → rollback 2 steps) ran on PostgreSQL through the workspace `bin/waffle`; `wfl dod` PASS on data, console, skeleton and workspace.
        

## 📜 AXE 4: API SURFACE TOOLING

### `[API-01]` OpenAPI Generation (NEW COMPONENT `waffle-commons/openapi`)

- **Specification:**
    
    - Generate `openapi.json` from existing `#[Route]` attributes and typed controller signatures/DTOs — zero manual YAML.
        
    - Build-time console command (`openapi:generate`) sharing the beta5 `[AOT-02]` metadata-parsing phase where possible; optional dev-only route serving the spec + Swagger UI.
        
    - Optional `#[OA\*]`-style attributes for response/description overrides; absence of attributes still yields a valid (if terse) spec.
        
    - *Status 2026-10-31:* `openapi:generate` (`GenerateCommand`, registered in the workspace `bin/waffle`) builds the document from `RouterInterface::getRoutes()` and the `utils` DTO shape reader, so the spec matches what the serializer accepts and emits. `OpenApiGeneratorTest` validates the output against the official OpenAPI 3.1 JSON Schema, stored verbatim with its hash and checked with opis's compliant validator, and checks that the schema rejects invalid documents; a document without routes is empty but valid. `wfl dod openapi` PASS (98.70 %).
        
    - *Decision 2026-10-31:* the two spec points the acceptance check found unbuilt, the dev-only route serving the spec with Swagger UI and the `#[OA\*]` override attributes, are built before the tag (the maintainer, keeping the 2026-10-21 full scope). The attributes land in `contracts` first, since they freeze at beta8.
        
    - *Status 2026-10-31 — done:* contracts `3f59e0f` (`OpenApi\Attribute\Operation`, `Response`, `Property`); openapi `ed1a705` and `437dca7` (`AttributeReader`, `Exception\InvalidAttributeException`, and `Middleware\ApiDocsMiddleware`: `GET /_docs` serves Swagger UI 5.33.3 from jsDelivr pinned by SRI under its own CSP, `GET /_docs/openapi.json` the live document); skeleton `a51fa21` and workspace `59ed360` mount it in debug mode only, and the skeleton's `bin/waffle` gains `openapi:generate` (openapi in `require-dev`). The documented fixture document and the real documents of both apps (16 and 17 paths) validate against the official OpenAPI 3.1 schema. `wfl dod` PASS on contracts (100 %), openapi (99.06 %), skeleton (96.95 %) and workspace.
        

### `[API-02]` DTO Serializer & Content Negotiation (NEW COMPONENT `waffle-commons/serializer`)

- **Specification:**
    
    - Scoped normalizer for strictly-typed DTOs ↔ JSON (request hydration + response serialization) honoring PHP 8.5 property hooks and asymmetric visibility — **not** a general-purpose serializer.
        
    - **AOT alignment:** normalizers are compilable per-DTO classes generated at build time (same philosophy as beta5 `[AOT-01]`), reflection-free at runtime.
        
    - `Accept`-header content negotiation middleware (JSON committed; others post-v1).
        
    - `data/`'s Hydrator remains DB-only; this component owns the HTTP boundary.
        
    - *Status 2026-10-31 — done:* compiled per-DTO normalizers (`serializer:compile`, pinned by golden files) load on the `WAFFLE_AOT=1` fast path with no reflection; without the flag the interpreted normalizer reflects, the same fallback as AOT. `ContentNegotiationMiddleware` negotiates JSON on `Accept`. `RoundTripTest` runs 16 shapes through both normalizers (hooks and asymmetric visibility, a computed property, nested DTOs, a tree through itself and through a list, every list element kind, a null list, defaults, nulls), and the compiled output must match the interpreted one byte for byte. `data`'s Hydrator is used only inside `data/`. `wfl dod serializer` PASS (98.93 %).
        

## 🧪 AXE 5: TESTABILITY (NEW COMPONENT `waffle-commons/testing`)

### `[TEST-01]` Kernel Testing Bridge

- **Specification:**
    
    - `WaffleTestCase`: boots the kernel in-process, dispatches simulated PSR-7 requests through the real pipeline (no web server), returns typed responses for assertion.
        
    - Test doubles for time, queue (`InMemoryQueue` asserting dispatched messages), mailer contract, and HTTP client (record/replay).
        
    - Dev-only component (`require-dev` in userland); EcoShield-Gateway and Academy labs are the first consumers.
        
    - *Status 2026-10-31 — done:* `WaffleTestCase` gets the app's kernel from `createKernel()`, swaps its doubles in between `boot()` and `configure()`, and sends PSR-7 requests through the real pipeline; the workspace's `KernelBridgeTest` runs it on the real `AppKernelFactory`. The doubles: `FrozenClock` (`advance()`), `InMemoryQueue` (`dispatched()`), `MailerSpy` (`sent()`) and `ReplayClient`, which records the requests it gets and replays queued answers (it does not record real upstream responses). Only `WaffleTestCase` imports PHPUnit, held there by the component's guard rule (CARRY-04). The README installs it with `composer require --dev`. `wfl dod testing` PASS (100 %). The first consumers named above adopt it once it is on Packagist.
        

### `[DXP-01]` Dev Profiler Headers (stretch — in scope, 2026-10-21)

- **Specification:**
    
    - Dev-mode middleware emitting `X-Waffle-Time`, `X-Waffle-Memory`, `X-Waffle-Queries` headers; no web toolbar (API-first).
- *Status 2026-10-22 — done (telemetry, skeleton, documentation; decisions: count traced queries, add `Server-Timing`):*
  `Telemetry\Middleware\ProfilerHeadersMiddleware` (the three headers plus `Server-Timing: app;dur=…`) and
  `Telemetry\Profiler\QueryCountingTracer` (counts the data layer's `waffle.db.query` spans, resettable per
  request). The skeleton's `ProfilerFactory` adds both only when `$debug` is true, which production refuses, and puts
  the headers first in the stack. No contracts change. `X-Waffle-Queries` cannot see raw PDO on a pooled
  connection (the demo controllers report 0). Gates: `wfl dod telemetry` and `wfl dod skeleton` PASS; not yet seen
  on a running dev app.
- *Seen live 2026-10-31:* the skeleton, served by FrankenPHP 1.13.2 in worker mode with `APP_DEBUG=true`, answered
  `GET /` 200 with `X-Waffle-Time`, `X-Waffle-Memory`, `X-Waffle-Queries: 0` and `Server-Timing`; a 400 from the
  trusted-host check carried them too, since the middleware comes first; with `APP_DEBUG=false` the same request
  carried none (archive: `project_system/Audits/Beta7/dxp-01-live/`).
        

## 🛡️ AXE 6: ECOSHIELD-GATEWAY ALPHA (DOGFOODING — stretch, in scope 2026-10-21)

### `[GATE-02]` Gateway Lab Bootstrap

- **Specification:**
    
    - Grow the beta6 reverse-proxy POC (`Roadmap_Beta6.md` `[GATE-01]`) to **alpha** on beta7, in the gateway's own repository: legacy monolith lab + Waffle proxy app (catch-all `ProxyController` over the resilient client `[NET-02/03]`, strangler route served natively with cache + rate limiter `[NET-01]`).
        
    - Built **exclusively on public Waffle APIs** — any private-API reach-through is a framework design bug to fix, not to work around.
        
    - *Decision 2026-10-22:* the gateway's runtime bump rides with this item. Its Dockerfile still builds on FrankenPHP 1.12.2 (no digest), exposed to PHP2Shell (CVE-2026-109618, CVE-2026-109619); moving it to beta7 moves it to FrankenPHP 1.13.2 or later with a digest pin. The maintainer chose to do it then rather than as a separate change.

    - *Status 2026-10-22 — built and checked on the local beta7 tree; `0.2.0` waits for the beta7 wave.* Gateway branch `alpha/beta7` (7 local commits), http-client `41abcd9`, documentation `fdc4abd`. Decisions that day: build now on local beta7, limiter on all traffic, lab as an override, OPS and metrics in GATE-03.
      - **Built:** `^0.1.0-beta7` through a local-only Composer override (`bin/framework-local.sh`); the lock moves to Packagist after the wave. The catch-all proxy runs over `RetryingClient(CircuitBreakerClient(Client))`: bounded timeouts, retries for idempotent methods only (the gateway never replays a POST or PATCH, whatever the configuration says), circuit state in Redis, 503 when the circuit is open. The strangled route `/api/users/{id}` sits behind the Shield. The NET-01 limiter covers all traffic: 600 requests a minute per client IP, read behind `TRUSTED_PROXIES`, fail-open. FrankenPHP 1.13.2 / PHP 8.5.12, and every image is pinned by digest. The lab (`docker-compose.lab.yml`) puts the gateway in front of the Symfony 5.4 legacy, now tracked and installed from its lock. Public APIs only.
      - **Evidence** (lab checks, not published numbers):
        - Gates: mago zero output, 85 tests OK, 99.50 % lines, igor 0.9.7 15/15 OK.
        - Limiter: 700 requests from one client in 1.3 s gave 612 × 200 and 88 × 429, nothing admitted beyond the bucket.
        - Breaker: with PHP-FPM stopped, the circuit opened on the tenth call (nine of them failures), then refused in about 5 ms without calling the legacy; a trial after the cool-down failed while the legacy was down and closed it once the legacy was back.
        - Retries, after the framing fix (nginx then answers 502, a retryable status, to every method): a GET and a PUT with a body made 3 attempts each, a POST exactly 1. The 429 carries `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` and `Retry-After`.
        - PostgreSQL stopped: a cached read still answered 200, an uncached one 503, never cached.
        - Redis stopped: every route answered 200 (Shield bypass, breaker closed, limiter open, each with a warning), and the cache recovered without a restart.
        - Perimeter: k6 280/280. The raw-socket probes give the same verdicts as 0.1.1: one response each, no desync, and a double `Content-Length` refused by Caddy. The CL.TE status differs because the upstream is now the Symfony legacy.
        - Every body-carrying method (JSON, form, chunked, 1 MiB) reaches the Symfony legacy.
      - **Found by the dogfood, fixed:**
        - http-client: an unsized body (`php://input`) went out chunked next to the caller's `Content-Length`. nginx answered 400 to every proxied POST and PUT, on beta6 as on beta7, and the wire capture shows both headers. `41abcd9` honours the declared length and drops the caller's framing headers whenever libcurl frames an upload; a test fails against the old client.
        - Gateway: every proxied GET carried an empty chunked body and an `Expect: 100-continue` handshake, so the 0.1.1 proxied figures include that cost.
        - Gateway: the Shield turned a Redis outage into 500s.
      - **Report only:**
        - http's `GlobalsFactory` leaves a parsed JSON POST body at its end (the gateway rewinds).
        - The breaker counts every 5xx on one circuit per origin. In front of one monolith that is one circuit for every proxied route; to watch in GATE-03.
        - `RetryPolicy` retries an upstream 429.
        - libcurl still sends `Expect: 100-continue` on chunked uploads.
      - **Open:**
        - After the wave: the Packagist lock, the gates on Packagist, the production image on beta7, and the CHANGELOG stamp `[0.2.0] — 2026-11`. Push, PR, the `0.2.0` tag and Packagist are the maintainer's.
        - GATE-03: OPS-01/02, metrics, and the ladder's per-step warm-up.
        

## ✅ ACCEPTANCE CRITERIA

- **NET:** limiter correct under concurrent multi-worker load (no over-admission beyond bucket size); breaker opens/half-opens per thresholds in fault-injection tests; zero infinite timeouts possible by construction.
- **QUEUE:** message survives worker crash (Redis Streams pending-list reclaim); failed messages land in the dead-letter store with full envelope; `queue:work` drains cleanly on SIGTERM.
- **OPS:** `/readyz` flips on dependency failure and on SIGTERM; rolling-restart under k6 load loses zero in-flight requests; `db:migrate` + `db:rollback` round-trip live on PostgreSQL, SQLite, MySQL and MariaDB, with SQL-generation tests for SQL Server and Oracle (*scope change 2026-10-17*, see `[OPS-03]`).
- **API:** generated `openapi.json` validates against the OpenAPI 3.1 schema; serializer round-trips every DTO shape in the test matrix (hooks, asymmetric visibility, nested DTOs, arrays).
- **All items:** `composer mago && composer tests` green, $\geq 95\%$ coverage, zero Mago baselines, `wfl igor` 0 KO; contracts-first sequencing; new submodules (`queue`, `openapi`, `serializer`, `testing`) scaffolded from `component-template`.

*Acceptance check 2026-10-31* (two read-only `acceptance-verifier` runs with targeted tests in `waffle-dev`; gate figures from the 2026-10-29 `wfl pre-release --all` READY run, plus `wfl dod` PASS that day on `skeleton`, `workspace` and `data` after their changes):
- **NET:** pass. The concurrency criterion was unverified until `RedisLimiterConcurrencyTest` that day (see `[NET-01]`). The breaker opens and half-opens per its thresholds in `RedisCircuitStateStorageTest` (real Redis) and `CircuitBreakerClientTest`, and `TimeoutPolicy` refuses any value below 1 ms or above its ceilings. The two `[NET-01]` spec points were settled the same day (see `[NET-01]`).
- **QUEUE:** pass (see the statuses under AXE 2).
- **OPS:** pass. The rolling-restart archive matches the figures under `[OPS-02]`; `/readyz` flips on a failed or unregistered critical probe and on the drain marker; the migration round trip passed again on PostgreSQL, MySQL and MariaDB. Unmeasured: the "constant-time, allocation-light" handlers.
- **API:** pass on both criteria; the two `[API-01]` spec points were built the same day (see `[API-01]`).
- **All items:** pass. No Mago baseline in any repository; each contract landed before its consumers; the four new components were configured from `component-template`.
- Recorded, not blocking: several live runs exist only as roadmap text (the 2026-10-21 breaker run and its `/waffle-metrics` counts, `wfl drain-check`, the gateway lab, the 2026-10-10 queue runs); the skeleton's `ProbeEndpointsTest` accepts either readiness verdict; `RetryPolicy` bounds its back-off cap and budget from below only, so a ceiling is a beta8 question.
- *Closed the same day (the maintainer chose all four follow-ups):*
  - Live runs re-run and archived under `project_system/Audits/Beta7/`: `wfl drain-check` passes 9/9 on FrankenPHP 1.13.2; the breaker fault injection on the workspace gives open 2, half_open 2, closed 1, as on 2026-10-21; the workspace's own `queue:work` consumes 3 messages from Redis and exits 0 on SIGTERM with nothing pending, archived next to the testdox of the real-Redis and real-signal suites (crash reclaim, dead letter).
  - `ProbeEndpointsTest` asserts 503 on an unreachable required pool (skeleton `279000e`), and `RateLimiterTest` the outage warning (security `6a0e3eb`).
  - Component CI starts Redis, so the `data` and `queue` Redis suites stop skipping on GitHub (umbrella `cd3b79e`, all 26 workflows, `ci:check` no drift; proven at the first push).
  - Coverage floors ratcheted to the day's figures (umbrella `e016e9b`).
  - Still open: the gateway lab run (its own repository), the unmeasured "constant-time, allocation-light" probe handlers, and `RetryPolicy`'s ceiling (beta8).
  - *Later that day:* the probe handlers were measured (`/healthz` about 5 µs whatever the probe count; `/readyz` about 6 µs plus 1.1 µs per probe; nothing retained over 100 000 calls), which showed RFC-023 §3.2's per-check timeout was missing for the pools: a lease against a database that never answers hung past 15 s. Fixed with the maintainer's go-ahead: `waffle.database.connect_timeout` (2 s) as `PDO::ATTR_TIMEOUT`, a 1 s phpredis read timeout (not on the queue worker's blocking pool), and `timeoutSeconds: 3` in the Kubernetes how-to (skeleton `69e6873`, workspace `12b2a75`, documentation `bfd22c4`, RFC-023 §3.2). The cache's Predis client followed (cache `d217546`: 1 s to connect and to read unless the DSN sets them).
  - *Gateway lab, end to end (NET-01):* 32 concurrent clients sent 1 800 requests from one IP to the lab gateway (16 FrankenPHP workers, 600 / 60 s per IP): 632 admitted, 1 168 refused with 429, nothing else, in 3.27 s. The bound was 600 + 10 × 3.27 = 632.7, so nothing was admitted beyond the bucket and its refill (`project_system/Audits/Beta7/gateway-lab-limiter/`). Still open: `RetryPolicy`'s ceiling (beta8).

*Pre-tag audit 2026-11-04* (the maintainer asked whether the documentation matched the code and whether the `skeleton` could be the public face of the ecosystem; live tests from Packagist in throwaway `composer:2.10.3` and `waffle-commons:workspace` containers, not archived):
- **Fixed in `routing`** (`4782964`): `Router::boot()` read and wrote its route cache unguarded, so with Redis unreachable every worker that booted or recycled (the skeleton recycles every 500 requests) died on `CacheBackendUnavailableException`, `/healthz` included. An unreachable backend is now a miss (RFC-013 §4). Live, a fresh beta7 skeleton with no Redis answers `/healthz` `{"status":"ok"}` and `/readyz` `{"status":"unavailable"}`. Present since `0.1.0-beta0`, so not a beta7 regression. `wfl dod routing` PASS.
- **Fixed in `skeleton`** (`c75a477`, `125113a`):
  - The documented `composer create-project waffle-commons/skeleton my-app` failed for everyone: every release is a beta, and Composer offers stable ones unless a version is named. The docs now name the version, in seven places across five repositories.
  - A generated project could not be committed and cloned: its inherited `.gitignore` ignored `scripts/`, so a teammate's `composer install` failed on `Scripts\Setup`, and `composer.lock`, whose hash also went stale when Composer rewrote `self.version`.
  - Only `APP_SECRET`, which nothing read, was generated: `WAFFLE_CSRF_SECRET` and `WAFFLE_AUTH_SECRET` kept the public placeholder. Production refused it, as it should, and development drew a secret per worker. The production compose required both (since the `APP_SECRET` decision below: `APP_SECRET` and `WAFFLE_AUTH_SECRET`).
  - The README's "clone the repository" fallback installed `dev-main`, or failed in a Docker build, and the skeleton's own `CHANGELOG`, `CONTRIBUTING` and `SECURITY` shipped into every project (now `export-ignore`).
  - Tested end to end from a `git archive` of the skeleton: create, commit, clone, install, with the generated secrets and a valid lock.
- **Fixed in `skeleton`** (`708aecc`): `bin/waffle` built its `Config` without the environment registry, and `Config` has not read `getenv()` since Beta-1, so every `%env(...)%` resolved to `null`. `db:migrate`, `db:status` and `db:rollback`, which the README documents, failed with "Failed to establish a database connection" in every project, and `cache:clear` tried `redis://localhost:6379`. Measured against throwaway `postgres:17-alpine` and `redis:7-alpine`: the old CLI fails against a database that answers `SELECT 1`; the new one runs status, migrate, status, rollback, status (exit 0 each), and clears `waffle:cache:*` only.
- **Decision (maintainer, 2026-11-04): Mago on the skeleton's entry points ships in beta7**, deferred to beta8 earlier the same day. `scripts/`, `public/`, `config/` and `bin/waffle` joined the Mago paths: 31 analyzer findings and 1 formatter finding fixed, none suppressed, and the 129 guard errors the new paths raised (the global namespace of the entry points and `Scripts\` had no perimeter rule) answered by two rules. The skeleton's `composer mago` now runs `mago guard`, as the components' does. Reason: the skeleton is the code every new project starts from. Evidence (skeleton `0f56aed`): `wfl dod skeleton` PASS, the archive test, `public/index.php` booted in dev and production, `bin/waffle list`; a production class map preloads the same 578 symbols, with no log line.
- **Decision (maintainer, 2026-11-04): `APP_SECRET` becomes the application's root secret in beta7.** The CSRF key is `WAFFLE_CSRF_SECRET` when it is set, otherwise 32 bytes of HKDF-SHA256 over `APP_SECRET` (`waffle.secret`, context `waffle-commons/csrf/v1`), in the skeleton's and the workspace's new `SecretFactory`. Production refuses to boot with a `WAFFLE_CSRF_SECRET` under 32 bytes, or with neither it nor an `APP_SECRET` of 32 bytes. `WAFFLE_AUTH_SECRET` stays explicit and required, because the other services of the bridge (the gateway, the workspace's legacy monolith) share it. The production compose requires `APP_SECRET` and `WAFFLE_AUTH_SECRET`; `create-project` generates both and leaves `WAFFLE_CSRF_SECRET` empty; `wfl csrf-init` signs with the derived key. Reason: `APP_SECRET` was generated and read by nothing, and development drew a CSRF key per worker, so a token one worker issued failed on another; one root gives every worker and every replica the same key. New behaviour, so it belongs to this build phase, not to the beta8 freeze. Evidence (skeleton `8ec7d50`, workspace `921507c`, documentation `2d02e9f`):
  - 14 tests per application: a known-answer vector, checked against an independent RFC 5869 implementation, the precedence, two workers accepting each other's tokens, and every fail-closed path. Two mutants, `APP_SECRET` ignored and a changed context, are killed.
  - A production boot of the skeleton: `APP_SECRET` and `WAFFLE_AUTH_SECRET` alone serve `/healthz`. A 31-byte `APP_SECRET`, no secret, a 20-byte `WAFFLE_CSRF_SECRET` and a missing `WAFFLE_AUTH_SECRET` each refuse with their own message. A project created from the archive boots in production on its generated `.env` alone.
  - `docker compose config` names each missing secret.
  - `wfl csrf-init` tokens validate against the application's key, derived or explicit.
- **Fixed in `workspace`** (`921507c`): the production-boot case of `AppKernelFactoryTest` brought no secrets and passed only against a local `.env`. With the secrets emptied in the process environment (CI has no `.env`) it was the one failure out of 55 tests, hidden because the CI job failed earlier, at `composer install` (`9da385d`). It now sets its secrets: 69 tests pass locally with the secrets emptied. On GitHub (run 41815639942) the job now reaches PHPUnit and passes 67 of 69; the two `KernelBridgeTest` POSTs to `/register` answer 500, because `TransactionIsolationMiddleware` leases a database connection and the job starts no database. Open.
- **Decision (maintainer, 2026-11-04): a Docker-only installer ships in beta7.** The skeleton's `create-project.sh` runs `composer create-project` in the pinned Composer image as the calling user, so the README's "Docker required, PHP optional" holds. Reason: the documented install needed PHP 8.5 with `ext-redis` and `ext-yaml` on the host. Tested on macOS's bash 3.2 against Packagist, with its argument and precondition checks; shellcheck clean.
- **Documentation:** 12 component READMEs updated. 11 gained the beta7 feature they did not mention, and three (`security`, `contracts`, `console`) dropped a `#[Rule]` attribute that has never existed; the `contracts` table listed 22 of its 35 namespaces. `reference/utils.md` documents `DtoShapeReader`, the shape value objects and `SystemClock`, `reference/queue.md` `MailerExceptionInterface`, and `reference/cache.md` `REDIS_TIMEOUT` (documentation `ce121b1`).
- **Umbrella CI** (`9da385d`, `51309eb`): the workspace job checked out a hand-kept component list that missed `openapi`, `queue` and `serializer`, and `wfl ai:check` required two gitignored paths.
- **Deferred to beta8:** the two tutorials, written for `0.1.0-beta6`, refreshed to the beta7 skeleton (`[DOC-01]`); Mago on the workspace's entry points (`bin/waffle`, `public/index.php`, `config/preload.php`), which its paths leave out as the skeleton's did; the skeleton in the umbrella CI matrix, where it has no job (its gates are local: `wfl dod skeleton`); `config/preload.php` targets the framework by a `/waffle-commons/` substring, which a project path can contain too (harmless in the image, where the project lives in `/app`); `@internal` on the beta7 classes that no public signature exposes (`[FRZ-01]`); French for the comments of the skeleton's `.env.example` and `.gitignore` and for its README, which are English (AGENTS.md §1). RFC-016, RFC-018, RFC-023 and RFC-024 still read "In progress": their status moves on release day.
