---
title: "Waffle Ecosystem Roadmap: (Beta 8)"
date_created: 2026-06-07
date_updated: 2026-11-20
type: project
status: active
tags:
  - project
  - roadmap
  - waffle
aliases: []
---
# 🧇 WAFFLE-COMMONS — ECOSYSTEM ROADMAP 0.1.0-beta8

> **Status:** Current — kicked off on 2026-11-20: the release branches were cut that day and the day-0 decisions recorded (see *Kickoff state & carry-overs* below). The scope is the five axes plus seven carried items, partly set by the beta5 spike outcomes and the beta7 retrospective.
> 
> **Target Release:** **December 2026** — not before ~8 December (decided 2026-11-20, see the kickoff decisions; it was ~3 December). The date itself is set at the audit's triage, about 26–28 November; planning assumes the central case, about 21 December. Earlier re-dated on 2026-10-21 from November 2026: beta7 tagged on 5 November and the freeze keeps its four weeks (see `Roadmap_v1_Master.md`). **The last feature release before v1**: the tag of beta8 *is* the feature freeze.
> 
> **Core Mandate:** Resolve every open decision, soak every deep change, freeze the public API, and re-audit the final security surface. A beta exists to change things; after beta8, nothing changes except bug fixes.
> 
> **Commitment Tiers:** Everything in this roadmap is must-ship — by definition, anything that slips here slips out of v1 entirely (to the post-v1 backlog), not to RC1.

## 🧰 KICKOFF STATE & CARRY-OVERS (2026-11-20)

### Where the release starts

- **Branches:** `pre-release/0.1.0-beta8` was cut on 2026-11-20 at 15:57 CET in 33 repositories: the umbrella, the 30 submodules, and academy's `labs` and `sandbox` (academy's `obsidian` joins only if beta8 edits it). Each branch starts at its repository's `origin/main`, every gitlink matching; `Log_Beta8.md` lists the 33 starting commits. Nothing is pushed yet (see the decisions below).
- **The starting tree:** umbrella `e1db37d`. Everything had reached `main` through merge commits, CI green: the release-audit tooling (monorepo#12), the workspace's dev stack (workspace#19, #20), waffle-cockpit 0.6.2 and the scripts' fallback fix (monorepo#13 to #15), and the sandbox's Mago alignment (sandbox#3, academy#4, monorepo#16). The weekly fresh-install run is green on `b555697` (run 44703671002); the next scheduled one is on 2026-11-23.
- **Code work:** none yet in the components since the beta7 tag. The pilot's 31 findings are open (see `[AUD-01]`).
- **Toolchain at the cut:** beta7's, as refreshed on 2026-11-02 (`Roadmap_Beta7.md`): igor-php 0.10.1 (`.igor-version`), TruffleHog v3.99.7 in `component-template`. The updates are decided under `[X-TOOLCHAIN]`.
- **Dependabot (the maintainer's rule, 2026-11-20):** every Dependabot PR is closed with a comment, and its update is resolved in the `pre-release/0.1.0-beta8` branches; none is merged into `main`. 28 PRs and `testing#6` were closed on 2026-11-20.
- **Measurement:** no dedicated host or load generator exists yet, and the workspace has a dev image only. A laptop measures no capacity and holds no multi-day soak (AGENTS.md §7): see `[X-PREREQ-INFRA]`.
- **Release log:** `Log_Beta8.md` is kept step by step from the kickoff on, instead of being written on release day. The maintainer asked for detailed tracks of this release, the contract freeze (2026-11-20).

### Decisions at the kickoff (2026-11-20)

The maintainer accepted the kickoff plan's day-0 recommendations. The plan stays local (`project_system/Notes/beta8-kickoff/`, git-ignored) because it schedules unfixed findings; its decision numbers are given for reference. Still open, each before the step it gates: D10 (tests and tooling after the tag, by the triage), D11 (the spike verdicts' evidence), D12 (the `[FRZ-01]` calls, among them the `[X-RETRY-CEILING]` values), D13 (the RC1 SLOs, by the triage) and D15 (the wave's dry-run order).

- **The tag date (D2): not before about 8 December 2026.**
  - Why: the work needs about 50–110 five-hour agent windows (central ~72) against about 25–38 before 3 December. The 72 h soak had to start by 30 November to end before 3 December, and no machine exists for it. Exit gate #5 had no path before the tag (D1).
  - The date itself is set at the audit's triage (about 26–28 November) and recorded in one umbrella commit: here, in the `Roadmap_v1_Master.md` train table and in AGENTS.md §5b, which keeps "~3 Dec" until then.
  - Planning assumes the central case, a tag about 21 December. Per the master roadmap's corollary, RC1 and Gold move by the same amount (central case: RC1 about 30 December, Gold about mid-February 2027), and the ≥ 4-week RC1 soak runs through January.
- **Exit gate #5 (D1): a gateway production image built from the local beta8 tree.**
  - The conflict: the gateway's production image installs releases from `composer.lock`, so it cannot build on an unpublished beta8, and every published number must come from a production image.
  - The decision: a production-image variant that installs a clean export of the recorded beta8 commit set and records the umbrella SHA, documented in the gateway's `CONTRIBUTING.md` and the `ecoshield` skill. GATE-03 and the gateway half of STAB-01 then run on production images before the tag. After the wave the gateway is re-locked on Packagist, and a short confirmation run precedes its 0.3.0 tag.
  - The fallback, if the build path does not work by the soak's shakedown: a dated amendment of exit point #5, and of `[STAB-01]` for the gateway stack, accepting a not-for-publication report measured on the frozen pre-release code. The publishable numbers then come from a re-check on Packagist before the RC1 tag, on a host other than RC-04's.
- **The gateway's 0.3.0 (D3):** the scope is decided.
  - 0.3.0: the `/healthz` and `/readyz` probes, the drain, metrics (adding a telemetry package), a per-step warm-up in the ladder, the one-circuit-per-origin watch, the build path above, its pins aligned with beta8, an `[Unreleased]` section and the stale docs.
  - With it: its bench and harness off the laptop, its share of `[STAB-01]`, and `[GATE-03]`.
  - Development starts on the pre-release through the development overlay, as 0.2.0 did on the local beta7 tree. The gateway is a released artefact: its work starts when the maintainer asks for its branch.
- **Measurement machines (D4):** two dedicated hosts and a separate generator, never the laptop (`[X-PREREQ-INFRA]`).
  - Host 1 runs STAB-01, then RC-04.
  - Host 2 runs GATE-03's subjects, any SPK-01 re-measure and later RC-05, which never shares the soak host.
  - Generator G drives host 2 from another machine: the gateway's method requires a separate generator for any throughput figure.
  - Transfers to the machines go by digest or `git bundle` over a private channel, on the maintainer's request.
- **Soak method (D5):**
  - The workspace soaks on its own production image. A skeleton fallback would lose `queue` and `serializer`, and with them the queue-worker endurance.
  - The production compose runs with two recorded overrides: `MAX_REQUESTS` above the run's total, and the limiter's thresholds above the offered rate. The rate is 300 rps per stack.
  - The leak evidence: the pool gauges, the client counts and the fd counts, plus `ConnectionTracker` through a soak-only toggle.
  - GATE-03's Scenario B reports the soak's 60/30/10 mix, plus `dbread` against `legacydb` for continuity with 0.1.1. The gateway gets more than 2 vCPU.
- **Pushes (D6):**
  - The first push follows the toolchain wave and carries only its commits (`queue` and `serializer` stay local), so draft PRs can prove the new CI.
  - Every later commit stays local until about two working days before the tag: a public branch would show every fix diff.
  - The umbrella's `main` is frozen from the cut. The one exception is a newcomer-path fix after a failed fresh-install run, merged into the branch on request.
- **The toolchain (D7):** `[X-TOOLCHAIN]` below. **The audit (D8, D9):** `[AUD-01]` below. **The carried items (D14):** the seven below.

### Carried over — schedule these alongside the axes

Seven items the roadmap did not hold, from `Retro_Beta7.md` §6 and `Log_Beta7.md` §4, or found at the kickoff:

- **`[X-RETRY-CEILING]` A ceiling for `RetryPolicy`'s back-off cap and retry budget** (`Retro_Beta7.md` §6; S; before the tag).
  - `RetryPolicy` rejects a back-off cap and a retry budget above a documented ceiling, as it already does below its floor. Tests and RFC-024 are updated.
  - Also decide whether retrying an upstream 429 is intended (a report-only `[GATE-02]` observation).
  - Depends on `http-client`, contracts first if the policy contract changes, and `[FRZ-01]`. The ceiling values are the maintainer's (D12).
- **`[X-DB-PATH-GAP]` The database-path gap against Engine D** (`Retro_Beta7.md` §6; M).
  - A benchmark-gate record explains the gap the beta7 `[CARRY-02]` run showed: 0.3–0.4 ms at the median at 50–100 rps, p99 up to 0.8 ms. It is measured on the production image with run-unique series. The gap is then closed by an internal change or documented as a known gap.
  - Beta8 documents it. The diagnosis runs on host 2 only if a slot is free while STAB-01 and GATE-03 are not using it.
- **`[X-TOOLCHAIN]` Toolchain decisions before the freeze** (`Retro_Beta7.md` §6, `[CARRY-05]`; decided 2026-11-20).
  - Predis `^3.7.1` in `cache` before the freeze, with the `breaking` label and an upgrade-guide line: apps that pin predis ^2 will conflict. It is the deferred major, not a security fix.
  - PHPUnit 12.5.45 for v1. `testing` requires `^12.5`; 13.4 waits for a 1.x minor that widens it to `^12.5 || ^13.4`, together with the test rewrites.
  - psalm 6.20.13. 6.21.0 came out on 2026-11-20, and its changelog touches monorepo autoloading.
  - TruffleHog v3.100.0, with the action's `version:` input, in every workflow.
  - igor-php: 0.11.0 is measured in Docker first. The maintainer then adopts it, or keeps 0.10.1 for beta8, from the figures; every pin moves together (`wfl ci:check` clean). Every `igor.json` gets `Psr\` back among its safe namespaces.
  - Dependabot: the rule above.
- **`[X-PREREQ-INFRA]` Measurement machines and the 72 h harness** (found at the kickoff; a prerequisite of STAB-01, GATE-03 and RC-04; the maintainer provisions them).
  - Host 1: 16 dedicated vCPU, 32 GB RAM, 250 GB SSD. Both stacks on disjoint CPU sets, each with its own k6 on cores of its own. Booked through the RC1 soak, always on at the RC1 tag, with incident response staffed over the holidays.
  - Host 2: 12 dedicated vCPU, 32 GB RAM, 100 GB SSD. Generator G: 4 dedicated vCPU, 8 GB RAM, on host 2's private network.
  - All three: Linux x86_64, Docker Engine with compose v2, cgroup v2, one pinned k6 version, dedicated CPUs with SMT siblings kept in the same set, and synchronised clocks.
  - The 72 h tooling: result rotation, periodic analysis, alerting, and a shakedown run of several hours. A production image for the workspace. `MAX_REQUESTS` pinned and recorded.
- **`[X-WAVE]` Beta8 release mechanics** (M).
  - The branches: cut on 2026-11-20 (above).
  - CHANGELOG headings `## [0.1.0-beta8] — 2026-12`. `Log_Beta8.md` is kept from the kickoff on, and `Retro_Beta8.md` follows.
  - `wfl pre-release --all` READY, the audit gate included.
  - The dry-run order (D15): a tag push always runs LIVE, so as wired, a dry run on the pushed tag cannot come before LIVE.
  - The umbrella tag only on the maintainer's request, with the cockpit's `releaseTag` set to `0.1.0-beta8`. Merge commits only.
- **`[X-DEMO-HYGIENE]` Leftovers from the 2026-11-04 pre-tag audit and release day** (`Log_Beta7.md` §4; M in all; which may land after the tag is decided at the triage, D10).
  - Mago on the workspace entry points (`bin/waffle`, `public/index.php`, `config/preload.php`).
  - A skeleton job in the umbrella CI matrix.
  - French for the skeleton's `.env.example` and `.gitignore` comments and its README (AGENTS.md §1).
  - `config/preload.php` no longer picks the framework's classes by a `/waffle-commons/` substring.
  - `create-project.sh`'s last message names `APP_SECRET` and `WAFFLE_AUTH_SECRET`.
  - The skeleton's dev compose no longer fixes container names and host ports.
  - A created project's tests no longer print JSON log lines.
  - `data`'s codecov/patch: 93.81 % against a 94.76 % base.
  - Reproduce, then report upstream, the dev container's `zend_mm_heap` crash on a watcher reboot.
- **`[X-RC1-SLO]` The RC1 soak's SLOs** (S). The maintainer's numbers, recorded in `Roadmap_RC1.md` before the RC1 tag: p99 latency per route class, an error budget (the share of 5xx outside the injection windows), and zero criticals. They are proposed before any STAB-01 data exists, so that they stay a test and not a fit: by the triage, before the soak's shakedown (D13).

## 🔬 AXE 1: SPIKE RESOLUTION (BETA5 GO/NO-GO DEBT)

_The three beta5 research spikes get their final verdict. "Go" means landing the production implementation here with full gates; "no-go" means a formal cut to the post-v1 backlog, documented in the master roadmap's non-goals._

_Kickoff note 2026-11-20: the three spikes' code shipped in beta5, so each verdict is a verdict on shipped code. A go keeps it under the full Definition of Done. A no-go deprecates it in `[FRZ-02]` before the tag and removes it in RC1 (`[RC-02]`), with a `Roadmap_Post_v1.md` §2 row and a master non-goal._

### `[SPK-01]` `[ASYNC-01]` Fiber-Based Deferred Task Runner — verdict

- Land (with the load-test report's throughput budget enforced) or cut. If cut, the documented alternative is `waffle-commons/queue` (beta7) for everything beyond trivial deferral.
- *Kickoff state 2026-11-20:* no gate report exists under `async/` (checked that day).
  - The verdict cites the beta5 spike report if it meets the benchmark-gate method, or re-measures.
  - A throughput budget is a throughput figure, so a re-measure runs on host 2, driven from G, and never on the laptop.
  - A go keeps `async` at its full Definition of Done: coverage floor 100.00 %, igor 0 KO.
    

### `[SPK-02]` `[REACTIVE-01]` Reactive Write-Hook Observers — verdict

- Land (enqueue-only hooks + middleware flush, Igor-clean) or cut. If cut, SSE/Mercure remains available through explicit event dispatch.
- *Kickoff state 2026-11-20:* a go must also settle `Reactive\MutationRecord::$value`, which contracts type as `mixed`, under `[FRZ-01]`.
    

### `[SPK-03]` `[AUTH-01]` WebAuthn / Passkeys — verdict

- Land (contracts + `web-auth/webauthn-lib` adapter, W3C test vectors green, security-audit gate passed) or cut to post-v1. **A half-implemented authentication scheme does not ship in a v1.**
- *Kickoff state 2026-11-20:* beta5 accepted a deviation: a self-signing fixture runs the full ceremony instead of the literal FIDO conformance vectors (`Roadmap_Beta5.md`).
  - The verdict either re-accepts that deviation in writing, or adds the literal vectors, which is test-only work.
  - It comes after `[AUD-01]` has covered `auth` and its findings are decided.
    

## 🧊 AXE 2: API FREEZE (THE CENTRAL DELIVERABLE)

### `[FRZ-01]` Contracts BC Review

- **Specification:**
    
    - Exhaustive review of every interface, DTO, enum, and attribute in `waffle-commons/contracts` — each one is either confirmed (frozen for all of v1.x under strict SemVer) or fixed **now**.
        
    - Checklist per symbol: final naming, parameter/return types explicit (beta4 `[ARCH-01]` bar), no leaked implementation details, PHPDoc contract semantics (preconditions, failure modes) complete.
        
    - Produce `contracts/BC-POLICY.md`: what is covered by the BC promise (interfaces, DTO shapes) and what is not (internal classes, `@internal` markers).

    - *Kickoff state 2026-11-20 (counted that day):* `contracts/src` holds 195 PHP files in 35 top-level namespaces.
        - 26 lines in 17 files carry `mixed`, each to be resolved or justified. Among them: `ContainerInterface::get` (PSR-11), `VoterInterface::decide`, `SubjectResolverInterface::resolve`, `ViolationInterface::getInvalidValue`, `StampedeProtectionInterface::compute` and `Reactive\MutationRecord::$value`.
        - Also in scope: whether to mark `@internal` the beta7 classes that no public signature exposes (`Log_Beta7.md` §4).
        - `BC-POLICY.md` does not exist yet. Zero TODO/FIXME already holds.
        - Fixes ripple to the consumers in the same wave: `wfl sync:contracts`, then each consumer's gates.
        

### `[FRZ-02]` Deprecation Sweep

- **Specification:**
    
    - Everything superseded during the beta series gets `#[Deprecated]` now and **removed in RC1** — v1.0 ships zero deprecated symbols.
        
    - Cross-component grep for usages; skeleton/workspace/Academy templates updated to the final APIs.
        
    - *Candidates recorded 2026-10-22:* `http-client`'s `Client::CONNECT_TIMEOUT_MS` and `Client::TIMEOUT_MS`, which the client no longer reads since `[NET-02]` (`TimeoutPolicy::DEFAULT_CONNECT_MS` / `DEFAULT_TOTAL_MS` replaced them).

    - *Kickoff state 2026-11-20:* no component's `src` carries a deprecation marker yet, and the two candidates above are still unmarked.
        - The forms: the native `#[\Deprecated(message, since: '0.1.0-beta8')]` on methods, constants, functions and enum cases; a `@deprecated` docblock on classes, interfaces, enums and properties, where the attribute is fatal.
        - Each one is listed in the CHANGELOG and `BC-POLICY.md`, and its callers move (`wfl xref <Symbol> --tests`).
        

### `[FRZ-03]` Naming & Convention Consistency Pass

- **Specification:**
    
    - One sweep across all components: namespace conventions (`Waffle\Commons\*` / `Waffle\Commons\Contracts\*`), exception hierarchies, config key naming, console command naming (`domain:action`), error response shapes.
        
    - Inconsistencies found after v1 are permanent — this is the last cheap moment.

    - *Kickoff state 2026-11-20:* the console baseline holds 24 command names, counted in the source that day: `cache:clear`, `container:compile`, `data:warmup`, `db:migrate`, `db:rollback`, `db:status`, `igor:audit`, `make:{command,controller,dto,entity,event-pair,http-client,middleware,migration,repository,voter}`, `openapi:generate`, `queue:work`, `route:compile`, `route:list`, `security:audit`, `security:compare-audit` and `serializer:compile`. The exception sweep checks that every thrown exception implements a contracts exception interface.
        

## 🧯 AXE 3: SOAK & STABILIZATION

### `[STAB-01]` Deep-Change Soak Fixes

- **Specification:**
    
    - Dedicated bake time for the invasive beta5/beta7 machinery under sustained load: AOT compiled-vs-runtime container parity (snapshot diffs on real apps), DBAL pool exhaustion/reconnect edge cases, queue worker endurance, breaker/limiter behavior under chaos testing.
        
    - 72h continuous k6 soak on the workspace demo apps + EcoShield-Gateway: zero memory drift (Igor), zero connection leakage, zero 5xx not injected by the chaos scenario.

    - *Kickoff decisions 2026-11-20 (D4, D5):* production images only, on host 1, both stacks on disjoint CPU sets with their own k6; the method is in the kickoff decisions above.
        - The run starts once the code that changes runtime behaviour has landed (the FRZ ripples, the pilot's and the audit's fixes), after a shakedown of 6–12 h. A run before that may not cover the tagged tree.
        - Prerequisites: `[X-PREREQ-INFRA]`.
        

### `[GATE-03]` EcoShield-Gateway Beta + FinOps Benchmark

- **Specification:**
    
    - Take EcoShield-Gateway to **beta** on beta8 (from the beta7 alpha, `[GATE-02]`) and run the FinOps benchmark in its own repository: k6 $\geq 1000$ rps, Scenario A (direct legacy PHP-FPM) vs Scenario B (gateway) — RAM ceiling, latency, breaking point.
        
    - The benchmark report is a v1 launch asset **and** the empirical proof for success indicator #2 (memory-growth slope + measured RAM factor + crossover point, per the beta6 `[BENCH-05]` reframing — never a bare "$5\text{–}10\times$").

    - *Kickoff state 2026-11-20:* GATE-03 closes the open `[GATE-02]` items: the OPS-01/02 probes and drain, metrics, and a per-step warm-up in the ladder.
        - The gateway's 0.3.0 is tagged after the framework wave by design, since its releases install from Packagist. Exit gate #5 is met before the tag on a production-image variant built from the local beta8 tree (kickoff decision D1).
        - The benchmark runs on host 2, driven from generator G. `BENCHMARK_RESULTS.md` is in French and records both machines.
        

## 🔐 AXE 4: FINAL SECURITY RE-AUDIT

### `[AUD-01]` Full-Surface Audit

- **Specification:**
    
    - Re-run the complete audit (the one that produced the beta4 findings) against the **final** surface: everything beta4 fixed (regression check) plus the new beta5/beta6/beta7 attack surface — `/waffle-metrics`, connection pooling, rate limiter storage, queue payload handling, OpenAPI/Swagger dev routes, health endpoints, WebAuthn (shipped in beta5), the gateway proxy path (header smuggling, hop-by-hop handling, request smuggling).
        
    - Every finding is fixed in beta8 or formally risk-accepted with sign-off in the audit report. RC1 inherits zero open criticals.

    - *Decision 2026-11-05, the method:* the `release-audit` skill runs the audit end to end with Claude Code (`/release-audit 0.1.0-beta8`). It replaces the zipped payload sent to Google AI Studio and beta6's rule of "more than one independent engine" (the maintainer: "You will handle everything"). Independence now comes from:
        - tool evidence read before any code (`wfl audit:evidence`: Mago metrics, Psalm taint, `composer audit`, igor, SEC-03);
        - one finder per lens: the OWASP Top 10:2025 categories, worker-state leaks, timing-safe comparisons, and the repository's AI layer against OWASP's Top 10 for Agentic Applications 2026;
        - blind, refute-first verifiers, two on every HIGH or CRITICAL, majority verdicts and a third on a tie;
        - a calibration on known beta6 defects (`wfl audit:calibrate`).

      The sweep includes dated threat notes: PHP2Shell (CVE-2026-109618, CVE-2026-109619), CVE-2026-115560 and the Symfony security releases of 2026-11-04.

    - *Sign-off:* the decision on each finding (fix, accept the risk, post-v1) is the maintainer's, recorded in the cockpit's `/audit` pane or with `wfl audit:sign` in their own terminal. Claude never records one (guard rails back that: the `release-audit` skill). A risk acceptance and a move to post-v1 carry a reason and the residual risk; a move to post-v1 is a risk acceptance for v1.
        - The run lives in `project_system/Audits/Beta8/release-audit/` (gitignored, local only).
        - `wfl audit:check 0.1.0-beta8 --gate` is the evidence for exit gate #4: every run of beta8 complete and reconciled, every finding decided, every fix fix-checked and released, the surface covered. `wfl pre-release --all` holds the tag on it.

    - *Pilot run, set up on 2026-11-05 and decided on 2026-11-06 (`queue` + `serializer`):* the security finders ran under the session's own settings, the rest under profile `balanced`. 42 candidates, 40 confirmed and 2 plausible by blind verification, none refuted, merged into 31 findings (0 CRITICAL, 0 HIGH, 5 MEDIUM, 25 LOW, 1 INFO). The maintainer decided all 31 as *fix in beta8* in `/audit` on 2026-11-06. Archive: `project_system/Audits/Beta8/pilot/` (local, gitignored); one ticket each in `.scratch/release-audit-0.1.0-beta8/issues/`, which keeps each finding's description and location until its fix ships. A hand-run calibration on the pre-fix code of three beta6 `[FIX-01]` items, made before the calibration step existed and kept outside that archive, raised 3 of the 4 known defects, and all three fixes still hold. The beta8 gate reads the pilot's run as well: its 31 fixes must be fix-checked and released before the tag. The full-surface run covers every other repository, the gateway, the AG and WA lenses and the calibration step.

        | # | Finding | Severity | Component | Size |
        |---|---|---|---|---|
        | 1 | `M-api-async-01` | MEDIUM | `serializer` | M |
        | 2 | `S-B1-02` | MEDIUM | `queue` | M |
        | 3 | `S-B2-01` | MEDIUM | `queue` | M |
        | 4 | `S-B2-04` | MEDIUM | `queue` | S |
        | 5 | `S-B3-02` | MEDIUM | `queue` | M |
        | 6 | `M-api-async-03` | LOW | `serializer` | S |
        | 7 | `M-api-async-04` | LOW | `serializer` | S |
        | 8 | `M-api-async-05` | LOW | `queue` | S |
        | 9 | `M-api-async-06` | LOW | `serializer` | L |
        | 10 | `M-api-async-07` | LOW | `queue` | M |
        | 11 | `M-api-async-09` | LOW | `serializer` | S |
        | 12 | `M-api-async-10` | LOW | `serializer` | M |
        | 13 | `M-api-async-13` | LOW | `queue` | S |
        | 14 | `M-api-async-14` | LOW | `queue` | S |
        | 15 | `S-B1-01` | LOW | `serializer` | S |
        | 16 | `S-B1-03` | LOW | `queue` | S |
        | 17 | `S-B1-04` | LOW | `serializer` | S |
        | 18 | `S-B1-05` | LOW | `serializer` | S |
        | 19 | `S-B1-06` | LOW | `queue` | S |
        | 20 | `S-B1-07` | LOW | `queue` | S |
        | 21 | `S-B1-08` | LOW | `queue` | S |
        | 22 | `S-B2-02` | LOW | `queue` | M |
        | 23 | `S-B2-03` | LOW | `serializer` | S |
        | 24 | `S-B2-05` | LOW | `queue` | S |
        | 25 | `S-B2-07` | LOW | `queue` | S |
        | 26 | `S-B2-09` | LOW | `queue` | M |
        | 27 | `S-B2-10` | LOW | `serializer` | S |
        | 28 | `S-B3-04` | LOW | `queue` | S |
        | 29 | `S-B3-05` | LOW | `queue` | S |
        | 30 | `S-B3-07` | LOW | `queue` | S |
        | 31 | `M-api-async-15` | INFO | `serializer` | S |

    - *Kickoff state 2026-11-20:* none of the pilot's 31 fixes has landed, and the full-surface run has not started.
        - **The full-surface run (D8):** `--only` 24 repositories plus the gateway, with the AG, WA and calibration units: 26 finders, 23 or more verifiers and one triager. It runs on the economy profile with the verifiers and the triager at high effort (`--profile economy --effort verifier=high,triager=high`). It starts after the toolchain wave, whose updates the evidence step reads.
        - **The delta run (D8):** `--run delta` then covers what changes after the full run starts. RC1's diff run starts at its own commits.
        - **The pilot (D9):** four refactor-only COULDs are to be re-signed by the maintainer as post-v1, each with its reason and residual risk, and each becomes a `Roadmap_Post_v1.md` row: `M-api-async-06` (L), `-07` (M), `-14` (S) and `-15` (S). `M-api-async-10` is kept as a whole. The new `wfl ci:check` rules count as the checks that fail on the parent commit for `S-B1-02`, `-07` and `-08`.
        

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
