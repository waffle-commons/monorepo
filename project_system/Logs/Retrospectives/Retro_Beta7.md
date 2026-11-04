---
title: Retrospective Beta 7
date_created: 2026-11-02
date_updated: 2026-11-04
type: project
status: draft
tags:
  - project
  - retro
  - waffle
  - beta7
aliases: []
---
# ⏪ Retrospective: Waffle Beta 7 (The Production Surface)

**Date:** November 4, 2026 (written before the wave; its outcome is added on release day) **Author:** Leslie Petrimaux (maintainer)

## 1. The Goal

Beta 6 stopped and hardened. Beta 7 was the heaviest release of the train in the shortest window:
four new repositories (`queue`, `openapi`, `serializer`, `testing`) and the operational features an
API needs in production — rate limiting, outbound resilience, background jobs, probes, a graceful
drain, reversible migrations — plus the stretch tier (`[DXP-01]`, `[GATE-02]`) and every beta6
carry-over, all before the beta8 API freeze.

## 2. What Shipped

- **Four new components**, each scaffolded from `component-template`, contracts first: a Redis
  Streams queue with dead letters and a `queue:work` that drains on SIGTERM; OpenAPI 3.1 generation
  validated against the official schema; a compiled DTO serializer with a byte-identical interpreted
  fallback; an in-process kernel testing bridge.
- **NET:** a token-bucket limiter whose Redis store admits exactly 50 of 800 concurrent calls on a
  50-token bucket; timeout policies that make an infinite timeout impossible by construction;
  idempotency-aware retries; a circuit breaker with its state in Redis.
- **OPS:** fail-closed `/readyz` with per-check timeouts, a drain that lost 0 of 7 501 requests in a
  rolling restart under k6 on each of its two paths, and `db:rollback` / `db:status` /
  `make:migration` with a live round trip on four SQL engines.
- **The stretch tier:** dev profiler headers, and the EcoShield gateway's alpha built and checked on
  the local beta7 tree (its 0.2.0 release follows the wave).
- **All ten carry-overs**, and a benchmark rig hardened before it produced a single new number.
- Every roadmap item was accepted **on evidence** on 2026-10-31: tests, command output, archived runs.
- **The public face, checked before the tag** (2026-11-04). The skeleton's install command names the
  version, so it works. A Docker-only `create-project.sh` needs no PHP on the host, and a created
  project can be committed and cloned. `APP_SECRET` is the root secret the CSRF key derives from, and
  the CLI's migration commands reach the database. Mago checks the entry points, `guard` included.
  In `routing`, a worker that boots during a Redis outage serves `/healthz`; twelve component READMEs
  caught up with their beta7 features.

## 3. What Went Well

- **Full scope without compressing the freeze.** The mid-October checkpoint was met on 2026-10-17.
  On 2026-10-21 nothing was cut: the later rows moved by the same week instead of being compressed,
  so beta8 keeps its full window for the freeze.
- **Dogfooding found a bug no test had exercised.** Proxying through `http-client`, the EcoShield
  gateway got 400 from nginx on every POST and PUT: an unsized body went out chunked next to the
  caller's `Content-Length`. The `http-client` suite had been green with the defect in place.
- **Measuring the probes exposed a missing spec clause.** Timing `/readyz` (about 6 µs) led to
  testing it against a database that never answers: a lease hung past 15 s, because RFC-023 §3.2's
  per-check timeout had never been built for the pools. It was fixed the same day (connect 2 s, Redis
  read 1 s).
- **Live round trips caught what generated-SQL tests could not.** Every DDL migration failed on MySQL
  and MariaDB; only running the migrations against real servers showed it.
- **The acceptance check was allowed to find work.** It found live runs that existed only as roadmap
  prose, and a probe test that accepted either verdict. The runs were repeated and archived, and the
  test now asserts 503, the same day.
- **The bench refused its own bad data.** Two full runs were invalidated because the laptop was in use;
  both are kept. The published run was checked idle against the power log for its whole window, and
  one step that overlapped a Contacts sync is flagged instead of quoted.
- **The perimeter held.** Every contract landed before its consumers, no repository carries a Mago
  baseline, and `wfl igor` reports 0 KO.
- **One question found what every gate had passed.** On the eve of the tag, the maintainer asked
  whether the skeleton could be the public face of the ecosystem. Taking a newcomer's path (install
  from Packagist, commit, clone, install, migrate) found four defects that every gate had passed:
  - The README's install command failed for everyone: every release is a beta, and Composer looks for
    a stable one.
  - A created project could not be installed from a clone, because `scripts/` was gitignored.
  - `db:migrate` had never reached a database in a generated project since it shipped in
    `0.1.0-beta3`: the CLI built its configuration without the environment.
  - A worker that booted during a Redis outage died, `/healthz` included, since `0.1.0-beta0`.
- **The last-day fixes were measured like the rest.** Each came with the run that failed before it
  and passes after:
  - a throwaway PostgreSQL for the CLI;
  - a `git archive` of the skeleton for the newcomer's path (what Packagist serves, with
    `export-ignore` applied);
  - for the derived CSRF key, a known-answer vector checked against an independent RFC 5869
    implementation, and two mutants that the new tests kill.

## 4. What Went Badly (and the lesson)

- **A measured run shared the laptop with everything else.** The first CARRY-02 run overlapped
  documentation work, video playback and a lid close; the BENCH-02 re-run overlapped audio and a
  video. Both had to be thrown out, and a clean run cost another night. **Lesson: during a measured
  run nothing else runs on the host — no edits, no searches, no commits — and the power log is read
  before a run is accepted.**
- **A gate skipped the tests of a component that has them.** From 2026-09-30, `dod.sh` decided whether
  a component had PHP files with `find … | grep -q .` under `set -o pipefail`: `grep -q` exits on the
  first match, `find` dies of SIGPIPE, the pipeline fails, and the gate read "scaffold, tests N/A".
  `contracts` passed in six runs out of six without PHPUnit running, until the fix of 2026-10-09. CI was not
  affected (it uses `hashFiles`). **Lesson: a gate's "not applicable" branch needs its own test, and a
  pass that ran nothing is a failure.**
- **The new repositories could not be registered.** Their `main` still held the template's
  placeholder `composer.json` until 2026-10-31, so Packagist had nothing to read, five days before the
  tag. **Lesson: a new repository's `main` carries its configured `composer.json` from the scaffold on
  (now in `component-scaffold`).**
- **Digest pinning had a blind spot.** `composer:latest` survived twice in the skeleton because
  `images-pin.py` read only `FROM` and `image:` lines. **Lesson: an image reference is any line that
  pulls an image; `COPY --from=<image>` is one.**
- **Spec clauses shipped without a test that could fail.** The pools' per-check timeout (RFC-023 §3.2)
  was missing, and `ProbeEndpointsTest` accepted "200 or 503". **Lesson: each acceptance clause gets a
  test that fails when the clause is broken.**
- **Live evidence was written down as prose.** The breaker run, `wfl drain-check` and the queue runs
  lived only as roadmap text until the acceptance check asked for them. **Lesson: archive a live run's
  raw output when it runs.**
- **CI first ran on beta7 two days before the tag.** The umbrella CI ran on the beta7 branch for the
  first time on 2026-11-03, with the release PRs. It stopped at `composer install`: the workspace
  job checked out a hand-kept component list that missed `openapi`, `queue` and `serializer`. Each fix
  then uncovered a failure the previous one had hidden: a production-boot test that passed only
  against a local `.env`, then two POSTs that lease a database the job never started. The PHPUnit step
  that `[CARRY-06]` added to that job first ran on GitHub on 2026-11-04. **Lesson: push the release
  branches as soon as they exist, so CI is a gate from the first week; and accept a CI item on a CI
  run.**
- **The newcomer's path had no test.** The four defects of §3 survived several releases because every
  gate starts from a checked-out component, and none from what Packagist serves. **Lesson: before each
  tag, create a project from a `git archive` of the skeleton, commit and clone it, install it, boot it
  in production and run its CLI against a real database.**
- **Mago did not read the entry points.** `bin/waffle`, `public/index.php`, `config/preload.php` and
  `scripts/Setup.php` were outside the skeleton's Mago paths, and its `composer mago` did not run
  `guard`. 32 findings and 129 guard errors waited there, among them a `@var` over a `realpath()` that
  can return `false`. **Lesson: the analysed paths cover every PHP file a project ships, and
  `composer mago` runs the same four tools in every repository.**
- **A claim went one step past its measurement.** The workspace suite was recorded as passing "under
  CI conditions" when that run had only emptied the secrets. GitHub then showed 67 of 69, for want of
  a database. It was corrected the same morning, in the PR bodies and in the records. **Lesson: name a
  simulation by what it changed, not by what it imitates.**

## 5. Scope Decisions (recorded, not silent)

- **2026-10-21 — full scope.** The stretch tier (`[DXP-01]`, `[GATE-02]`) stayed in; the tag moved from
  October to November, and beta8, RC1 and Gold moved by the same week.
- **2026-10-17 — `[OPS-03]` dialect matrix.** The live round trip runs on PostgreSQL, MySQL, MariaDB and
  SQLite; SQL Server and Oracle get SQL-generation tests, since the dev image has no driver for them.
- **`[QUEUE-03]` — mail is a contract only** (`MailerInterface`): a mail is a queue message, and no
  transport ships in the framework.
- **`[CARRY-03]` — `ResettableInterface` stays optional.** State kept on purpose is declared with
  `#[WorkerSafe(reason: …)]` (RFC-001 §5), following the API Platform Conference feedback.
- **`[CARRY-04]` — the perimeter of `testing` and `openapi`** was decided on 2026-10-07: a PSR-20 clock,
  `KernelInterface::$container`, no route seam.
- **The database-path gap is published as measured, not explained.** Waffle is 0.3–0.4 ms slower than
  Symfony doing the same per-request work; the cause is a beta8 question, and the number is quoted
  with it.
- **2026-11-02 — beta7 ships igor-php 0.10.1**, which does not carry the detector fix (its PR is
  upstream), so the 27 method-level annotations stay.
- **2026-11-04 — a Docker-only installer ships in beta7.** `create-project.sh` runs Composer in its
  pinned image as the calling user, so the README's "Docker required, PHP optional" holds.
- **2026-11-04 — Mago on the skeleton's entry points ships in beta7**, deferred to beta8 earlier the
  same day.
- **2026-11-04 — `APP_SECRET` becomes the root secret.** The CSRF key derives from it (HKDF-SHA256)
  unless `WAFFLE_CSRF_SECRET` is set. `WAFFLE_AUTH_SECRET` stays explicit, since other services share
  it. This is new behaviour, so it belongs to the build phase, not to the freeze.
- **2026-11-04 — the workspace CI job starts PostgreSQL**, so its PHPUnit step runs the whole suite:
  69 tests on GitHub.

## 6. Carried into Beta 8

- Explain, then close or document, the database-path gap against Engine D.
- A ceiling for `RetryPolicy`'s back-off cap and budget.
- Waffle's own endurance claim: the 72-hour soak `[STAB-01]`. The beta7 soaks covered the Symfony
  engines C and D, 2 h each.
- `[GATE-02]` → the gateway's 0.2.0 on the released beta7, then the FinOps benchmark `[GATE-03]`.
- `[CARRY-05]` upstream: the igor-php detector fix, then the pin moves and 27 annotations collapse.
- The toolchain majors (PHPUnit 13.4, Predis 3.7), decided before the freeze; the minor/patch refresh
  (mago 1.59, igor-php 0.10.1, psalm 6.20) shipped in beta7 on 2026-11-02. The `mixed` still in
  `contracts`, for the BC review.
- What the pre-tag audit left:
  - Mago on the workspace's entry points.
  - A skeleton job in the umbrella CI.
  - The two tutorials, still on `0.1.0-beta6` (`[DOC-01]`).
  - `@internal` on the beta7 classes that no public signature exposes (`[FRZ-01]`).
  - French for the skeleton's `.env.example`, `.gitignore` and README (AGENTS.md §1).
- The development container's FrankenPHP crashes on a watcher reboot (`zend_mm_heap corrupted`,
  2026-10-10 and again 2026-11-04, when it took a gate run down with it): reproduce it, then report it
  upstream.

## 7. Verdict

Beta 7 delivered what its roadmap promised, in full and on evidence: four new components, the NET and
OPS surface, the stretch tier and every carry-over, without taking a day from the freeze. Its weak
point was not the code but the distance between the gates and the people who will use it. CI first
ran two days before the tag, and the path a newcomer takes had never been tested. Both were closed
before the tag: the workspace's CI job runs its whole suite on GitHub, and the skeleton was created,
committed, cloned and booted from what Packagist serves. Beta 8 starts from a release whose public
face has been tried, not assumed.

*Release day: the wave's outcome (component tags, Packagist, the umbrella gate after the relock) is
added after the tag.*
