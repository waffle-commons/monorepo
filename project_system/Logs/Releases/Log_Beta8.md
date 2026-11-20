---
title: "Log Beta 8"
date_created: '2026-11-20'
date_updated: '2026-11-20'
type: project
status: active
tags:
  - waffle
  - beta8
  - project
  - milestone
  - release
aliases: []
---

# 🚀 Release Log: Waffle 0.1.0-beta8

> [!SUMMARY]
> Goal: **the API freeze.** Beta8 is the last feature release before v1. It settles the three beta5 spikes, freezes the public contracts (BC review, `BC-POLICY.md`, deprecations, the naming pass), soaks the deep changes for 72 h, re-audits the full security surface and completes the docs. After its tag, only bug fixes ship. Release: December 2026, not before ~8 December; the date is set at the audit's triage (`Roadmap_Beta8.md`, *Kickoff state & carry-overs*).
>
> **How this log is kept:** step by step from the kickoff, on the maintainer's request of 2026-11-20, because this release is the contract freeze. Each step records what ran, its evidence and its commits. Audit findings appear by ID, severity, component and size only until their fixes ship.

## 0. Journal

### 2026-11-20 — the kickoff

- **About 15:14 CET** (the first command after it ran at 15:14): the maintainer accepted the kickoff plan's day-0 recommendations and gave "proceed" for its first wave. The decisions and their reasons are in `Roadmap_Beta8.md`. The plan itself stays local (`project_system/Notes/beta8-kickoff/`, git-ignored).
- **Shortly before the cut** (15:57 CET), the maintainer: "You can start the beta8 step by step. Keep detailed tracks of this release, it must be bulletproof as it is the contract freeze."

### 2026-11-20 15:57 CET — day 0: the branch cut

- **Preconditions** (read-only, just before):
  - `submodule.recurse` is unset in the umbrella, in academy and in the global config, so switching the umbrella's branch leaves the submodules' checkouts alone. The umbrella has `push.recurseSubmodules=check`.
  - `wfl sync:status --fetch`: the umbrella and the 30 submodules on `main`, clean, +0/−0 against `origin/main`, every gitlink matching.
  - academy's three nested repositories, fetched and checked by hand, since `sync:status` does not list them: `labs` `5d07d3d`, `obsidian` `2aa4102` and `sandbox` `9576855`, each on `main`, clean, level with `origin/main`, its gitlink matching.
  - No `pre-release/*` ref anywhere, local or remote-tracking.
- **The cut:** the kickoff plan's command (its §2), run under `bash -eu`.
  - It checks all 33 repositories before touching any: each on `main`, clean, `main` equal to `origin/main`, and no `pre-release/0.1.0-beta8` branch, locally or (a check added at the cut) on `origin`.
  - It then creates the branch from local `main` in academy's `labs` and `sandbox`, then in the 30 submodules, and in the umbrella last.
  - Run 15:57:34–15:57:40 CET. Output: "checks: 33 repos passed", then "cut: 33 repos".
- **Verification** (read-only): in each repository the branch is checked out, its head equals `origin/main` and the recorded gitlink, and it has no upstream yet: 33 of 33. `wfl sync:status` shows every row on the branch. academy's `obsidian` stays on `main`: it joins only if beta8 edits it.
- **Nothing is pushed.** The first push follows the toolchain wave (kickoff decision D6).

**Starting points** (each branch's first commit, equal to `origin/main` at the cut):

| Repository | Commit |
|---|---|
| umbrella | `e1db37d` |
| `academy/labs` | `5d07d3d` |
| `academy/sandbox` | `9576855` |
| `component-template` | `928ba5d` |
| `documentation` | `4837c08` |
| `cache` | `6d7b0c7` |
| `config` | `d4e26cb` |
| `console` | `7b53eae` |
| `container` | `dd1900f` |
| `contracts` | `9a0f59b` |
| `error-handler` | `d2f6172` |
| `event-dispatcher` | `d2660fd` |
| `http` | `c0b280e` |
| `log` | `bd2240f` |
| `pipeline` | `165f72f` |
| `routing` | `343da8b` |
| `runtime` | `e76b70e` |
| `security` | `14b304d` |
| `skeleton` | `266e796` |
| `utils` | `20b7067` |
| `waffle` | `c0484e0` |
| `workspace` | `9de577c` |
| `http-client` | `98f28fe` |
| `auth` | `120f25b` |
| `data` | `62274ae` |
| `telemetry` | `d6c890b` |
| `telemetry-otel` | `c024e1e` |
| `async` | `b220e2b` |
| `academy` | `104a0ed` |
| `queue` | `0438de6` |
| `openapi` | `05a7ebc` |
| `serializer` | `dbd3ac1` |
| `testing` | `d3b58c0` |

### 2026-11-20 — the kickoff records (the plan's 0.4 and 0.5)

- **`Roadmap_Beta8.md`:** the kickoff state, the day-0 decisions with their reasons, and the seven carried items. Umbrella `d43b8b4`, the branch's first commit. The maintainer reviews it before any push.
  - Re-checked that day before writing it: `contracts/src` holds 195 PHP files in 35 namespaces; `mixed` on 26 lines in 17 files, the six named symbols included; zero TODO/FIXME; no deprecation marker in any component's `src`; both `[FRZ-02]` candidates still present; no `BC-POLICY.md`; 24 console command names, read from the source (the plan's reader had counted 25); `.igor-version` 0.10.1; TruffleHog v3.99.7; `async`'s coverage floor 100.00 %; no gate report under `async/`.
- **The skills the agents read (0.5):** umbrella `937fd0c`, written by one agent and reviewed diff by diff before the commit. `wfl ai:check` is clean: 35 skills, 22 agents, 26 script tests, 148 cockpit tests.
  - `tech-lead`: beta8 is the current phase, with the beta8 guard and the new dates. The beta7 row and its capacity guard are history.
  - `api-freeze`: 195 files in 35 namespaces; the console baseline is the 24 names the source declares.
  - `soak-endurance`: `MAX_REQUESTS` above the run's total (AGENTS.md §7), not per worker. Trap 8 is fixed in the umbrella rig (`34bfe84`), but not in the gateway's `perf-run.sh`. The breaker, limiter, probes and drain shipped in beta7, and `wfl rolling-restart` is the two-replica rig.
  - `benchmark-gate`: `[CARRY-01]` and `[CARRY-02]` are history, and the method rules they set now sit in its traps and protocol.
  - `roadmap-steward`: `[CARRY-01..10]`, this log kept from the kickoff on, and the train line.
  - **Drift noticed and left as it is, for `[DOC-02]`:**
    - `api-freeze` gives a spike no-go as "removal before RC1", without the `[FRZ-02]` deprecation step that `Roadmap_Beta8.md` now records; it also says "verified on PHP 8.5.11".
    - `benchmark-gate` quotes the beta6 figures (10.5×, crossover 12–16, 2.37× at 128) where the current series reads 12.5×, about 14 and 2.81×. It still triggers on `[CARRY-01]`, and it calls the four-engine rig "tri-engine", as `soak-endurance` does.
    - `roadmap-steward`'s schedule guards still read as if a January Gold were the plan.
  - **A rig gap for the harness work (`[X-PREREQ-INFRA]`):** `bench/scripts/run-bench.sh` defaults `MAX_REQUESTS` to 1 000 000, below the 1 080 001 requests of BENCH-03's 2 h soak. That holds per worker, but breaks the "above the run's total" rule.

### 2026-11-20 16:15 CET — the toolchain wave, 1.6: the igor-php 0.11.0 trial

- **Request:** the maintainer's "run the igor trial".
- **A defect in the plan's recipe, found before it ran:**
  - The bootstrapper (`vendor/bin/igor-php`, one identical file in every target) takes its version from the `IGOR_VERSION` environment variable, or else from the Composer-installed `igor-php/igor-php` (`v0.10.1` in every lock). It never reads the `.version` file that `igor.sh`, `wfl dod` and CI write.
  - `igor.sh` and `wfl dod` do not pass `IGOR_VERSION` into `docker exec`. The planned `IGOR_VERSION=0.11.0 igor.sh --docker -s` would have re-downloaded 0.10.1 and failed its version check on every target, measuring nothing. CI is unaffected: its step sets `IGOR_VERSION` in the environment.
  - Each version has its own folder (`resources/bin/<x-y-z>_linux_amd64/`), so the planned deletion of the binaries was not needed. Nothing was deleted, and 0.10.1's binaries, which `wfl dod` uses, are untouched.
- **The binary:** `igor-php_0.11.0_linux_amd64.tar.gz` from the v0.11.0 release (2026-11-14), downloaded into an empty folder.
  - Its SHA-256, `c799c028…66c5`, matches the release's `checksums.txt`. The release publishes no signature or build attestation.
  - The extracted binary (SHA-256 `c4775369…52dd`) was copied into each target's `resources/bin/0-11-0_linux_amd64/`, so the bootstrapper ran exactly that file and downloaded nothing.
- **The method:** the audit `igor.sh` runs (`vendor/bin/igor-php .` from each target's root, with its own `igor.json`), in `waffle-dev` only, with `docker exec -e IGOR_VERSION=<v>`. First a 0.10.1 baseline, then 0.11.0.
  - Before each audit, `--version` had to print exactly `igor-php version <v>`: 54 of 54 did.
  - 27 targets: the 28 that declare igor-php, minus `component-template`, which has no `vendor/` (as with 0.10.1).
  - Run 16:15–16:18 CET: 0.10.1 in 2 min 3 s, 0.11.0 in 48 s.
- **The result: identical in all 27 targets.**
  - Both versions: 657 service files, 652 OK, 0 KO, 5 WARN (`cache` 1, `config` 1, `http-client` 1, `http` 2; WARN passes). Every audit exited 0.
  - The only text that changed is the hint printed with those WARNs, reworded in 0.11.0. Its new rules (`StaleDependency`, #116) raise nothing.
- **Raw evidence** (local, git-ignored): `project_system/Audits/Beta8/igor-0.11.0-trial/`, with `RESULT.md`, `summary.tsv` and the 54 logs.
- **Next:** the maintainer's decision (D7): adopt 0.11.0, with every pin moving in one sweep inside 1.1 and 1.3, or keep 0.10.1 for beta8.

### 2026-11-20 16:25–16:45 CET — the toolchain wave, 1.1: one CI sweep

- **Decisions** (the maintainer, about 16:25): adopt igor-php 0.11.0 (D7), and fix `igor.sh` and `wfl dod` so they pass `IGOR_VERSION` into Docker.
- **The change,** made once in `component-template`:
  - **TruffleHog v3.100.0, with the action's `version:` input.** The action runs the image `ghcr.io/trufflesecurity/trufflehog:<version>`, `latest` by default, so pinning the action alone would not pin the scanner. The `3.100.0` tag was checked to exist.
  - **igor-php 0.11.0, pinned for the whole igor job.** Only the step that checked the version had the variable. The step that ran the audit fell back to `composer.lock`, so CI audited with the lock's version. `umbrella-ci` had the same gap.
  - **S-B1-02 (MEDIUM, M):** its fix, per its ticket.
  - Every action stays at the commit its current major tag points to, so nothing changes in behaviour. The exact version is in a comment.
- **Propagation:**
  - 23 libraries were byte-identical to the template's committed workflow. Each was checked first, then copied byte for byte.
  - `telemetry` and `telemetry-otel` carry their own extension and ini lines, so the same scripted transform ran on their own files.
  - The umbrella's three workflows followed.
  - All 29 workflows parse as YAML. CI first runs on the draft PRs after the first push (D6).
- **The regression check** (D9's terms): new `wfl ci:check` rules, for S-B1-02 and for TruffleHog's version input.
  - On the unchanged workflows: 873 findings across 30 files.
  - With the version input still missing, the TruffleHog rule fired on its own.
  - After the change: no drift.
- **`igor.sh` and `wfl dod`:**
  - Both pass `IGOR_VERSION` into `docker exec`. `igor.sh` now matches the banner as a whole line, and both remedy messages name the versioned folder. AGENTS.md §5 was corrected.
  - `/bin/bash -n` (3.2.57) passes on both.
  - `igor.sh --docker -s` at 0.11.0, while the lock still says 0.10.1: 27 OK, 0 ERROR (the 28th, `component-template`, is the usual exempt scaffold).
  - An `IGOR_VERSION=0.10.1` override is still honoured. `wfl dod utils` passes, with its igor step at 0.11.0.
- **Commits** (local):
  - The 26 component repos, one identical change each: `component-template` `a96efd4`, `cache` `4ee5faf`, `config` `8212728`, `console` `6c997ed`, `container` `072e42b`, `contracts` `ae9590f`, `error-handler` `99f3178`, `event-dispatcher` `098b54a`, `http` `022e77a`, `log` `a45041a`, `pipeline` `6026716`, `routing` `8dfaa94`, `runtime` `6afa5e4`, `security` `1341689`, `utils` `8ad6d85`, `waffle` `24bb378`, `http-client` `f396a38`, `auth` `d488804`, `data` `6c17373`, `telemetry` `0720dea`, `telemetry-otel` `4b2f47d`, `async` `77b54e4`, `queue` `52ad36b`, `openapi` `6b9ce50`, `serializer` `36f86df`, `testing` `9caa429`.
  - Umbrella: `6f0a4f9` (the tooling) and `62a106b` (the 26 gitlinks, each checked against its repo's HEAD).
- **Evidence** (local, git-ignored): `project_system/Audits/Beta8/wave1-ci-sweep/`.
- **Still to do for S-B1-02:**
  - The maintainer's repository-settings part, after each repo's release PR (D9).
  - `wfl dod queue` in the 1.3 sweep, then its fix-check.

## 1. Technical changelog (what changed)

_Filled as the items land._

## 2. Soak and benchmark results

_`[STAB-01]` and `[GATE-03]`, each with its environment and method._

## 3. Quality gates

_The exit-gate run, point by point._

## 4. Known gaps carried forward

_Filled at the exit-gate run._

## 5. Release mechanics

_The release-day order, the dry run and the wave._
