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

### 2026-11-20 16:46–17:23 CET — the toolchain wave, 1.2 and 1.3: S-B1-07 and the relock pass

- **S-B1-07 (LOW, S):** its fix, per its ticket, in two halves.
  - **The CI half** (16:50): one step in the build job of the 26 component workflows, made in `component-template` and copied as in 1.1, and in `umbrella-ci`. Commits: queue `1bdb076`, serializer `92d8a5e` and the 24 other component repos; umbrella `534b183`.
  - **The composer.json half:** in the relock pass below, contracts first (`5121389`).
  - **The regression check:** a new `wfl ci:check` rule. On the unchanged files it reports 57 findings (30 composer.json, 27 workflows); after the CI half, 30; after the relock, no drift.
- **The relock pass (1.3):**
  - PHPUnit 12.5.45, psalm 6.20.13 and igor-php `^0.11.0` in every repo that uses them, and `cacheResult` out of the 29 `phpunit.xml` files (the PHPUnit 12.5 default; 13.4.8 deprecates it).
  - One local commit per dependency per repo: 140 commits.
  - psalm is held at 6.20.13 with Composer's `--with`: `^6.20` alone would take 6.21.0, which D7 set aside.
  - Every update runs with `--no-scripts`, because skeleton's post-update hook runs its create-project setup.
  - **Before each commit:** the target version is locked, no `waffle-commons/*` entry moves, and only the expected files change. A step that failed any check was not committed.
  - **The guards stopped four repos at their first step, and none of them was a defect:**
    - skeleton's lock is git-ignored, so its updates stay local and only `composer.json` and `phpunit.xml` are committed.
    - workspace, academy/labs and academy/sandbox take `waffle-commons/*` from path repositories, whose path reference moves with every lock write; their versions and sources did not move. Each was finished under a guard that allows exactly that.
  - **Times:** 37 s for contracts (the test run), 940 s for the other 29 repos, 65 s for the follow-up. The median per step: PHPUnit 11 s, psalm 15 s, igor 7 s.
- **The first measured DoD sweep:** `wfl dod` on the 25 libraries, skeleton and workspace.
  - 27 of 27 PASS, in 365 s (9 to 28 s each). skeleton and workspace passed again after their relock.
  - A full sweep costs about 6 minutes, so gating every repo after each fix is cheap. The plan's binding constraints stay the agent windows, the machines and the 72 h clock, and P1–P2 keep their dates on that basis.
- **After the relock:**
  - `wfl ci:check`: no drift. `igor.sh`: 27 OK.
  - academy labs' answer key, `composer verify`: OK (54 tests, 122 assertions) on PHPUnit 12.5.45. The sandbox's `composer mago` is clean.
  - `wfl academy:test` exits 2: it is the students' TDD suite, failing until the labs are solved.
- **Gitlinks:** academy `c5dc1e9` (labs `4231519`, sandbox `52a375b`); umbrella `b0515f4` (29 gitlinks, each equal to its repo's HEAD).
- **Evidence** (local, git-ignored): `project_system/Audits/Beta8/wave1-relock/`, with every step's time and commit, every composer run and DoD log, and the scripts as run.
- **Next:**
  - 1.4 (S-B1-08), with the maintainer's review of the new `SECURITY.md`; 1.5 (Predis); 1.7 (`Psr\` in `igor.json`).
  - Then the fix-checks of S-B1-02, -07 and -08.

### 2026-11-20 17:25–17:34 CET — the toolchain wave, 1.7 and 1.5

- **1.7, `Psr\` back among igor's safe namespaces:**
  - igor's defaults are `Symfony\`, `Doctrine\`, `Psr\`, `Twig\`, `ApiPlatform\` and `IgorPhp\IgorBundle\` (igor 0.11.0's README). Every Waffle `igor.json` sets `safe_namespaces`, which replaces that list, so `Psr\` was gone. It is back in all 28; contracts had an empty list.
  - auth retires the three PSR-16 method marks that `Psr\` covers: `OidcDiscovery::discover`, `ClientCredentialsProvider::accessToken` and `JwksKeyResolver::keys`.
  - **Checked in two steps:** with the marks removed and `Psr\` absent, igor reports 3 KO ("Mutation detected on an injected dependency"); with `Psr\` restored, 0 KO. `wfl dod auth`: PASS (coverage 99.54 %, its floor).
  - **Commits:** auth `4bcb6ae` (igor.json) and `0990c34` (the marks), 27 `igor.json` commits, umbrella `b25e145`. `igor.sh`: 27 OK.
  - **Noticed:** auth's pre-commit hook printed "no staged PHP files" for a commit that staged three PHP files, so the hook seems not to see PHP staged inside a submodule. Mago was proven clean on the same tree by `wfl dod auth`. To examine with the tooling items (5.10).
- **1.5, Predis `^3.7.1` in cache:**
  - The deferred major (D7), not a security fix. `composer.json` and the lock change, and only Predis moves: v2.4.1 → v3.7.1.
  - The container's `composer show` listed 3.7.0 as the newest, from stale cached metadata. Packagist and GitHub both have 3.7.1 (released 2026-11-03), and the update took it.
  - **Checked:** `wfl dod cache` PASS (coverage 95.57 %, floor 95.52 %).
    - cache's unit tests run on a Predis stub, so `RedisCache` was also exercised through `CacheFactory`, on Predis 3.7.1, against the dev Redis.
    - 9 of 9 checks passed: SET, GET, EXISTS, SETEX, MGET, DEL, SCAN and expiry.
  - **workspace** was relocked through cache, its path repository: Predis 3.7.1, with the path references refreshed. `wfl dod workspace`: PASS.
  - **For the release PR:** the `breaking` label, and a line in the upgrade guide (`[DOC-01]`, not written yet), since apps that pin predis ^2 will conflict. skeleton relocks on release day, because it resolves cache from Packagist; the gateway relocks at its re-lock.
  - **Commits:** cache `1c13a27`, workspace `0adbec1`, umbrella `f7faac7`.
- **Evidence** (local, git-ignored): `project_system/Audits/Beta8/wave1-igor-psr/` and `wave1-predis/`.
- **Left in Wave 1:**
  - 1.4 (S-B1-08): its `SECURITY.md` text is with the maintainer.
  - The `## [Unreleased]` CHANGELOG entries in every repo. The legend asks each repo's first beta8 commit to open one; Wave 1's commits did not, so one pass adds them.
  - The fix-checks of S-B1-02, -07 and -08.
  - The first push, on the maintainer's word (D6).

### 2026-11-20 17:45–17:57 CET — the toolchain wave, 1.4 (S-B1-08) and the CHANGELOG pass

- **1.4, S-B1-08 (LOW, S):** its fix, per its ticket. The maintainer reviewed the text in the vault and approved it ("go with your recommendations").
  - **One policy for every Waffle package,** written in `component-template` and copied byte for byte to the 25 libraries.
    - waffle's own longer policy is replaced; its private list, its 48-hour acknowledgement and its six-month rule carry over.
    - skeleton gets the French version (AGENTS.md §1), without the section on CI checks, since skeleton has no CI of its own yet.
  - **A correction to the recommendation the maintainer accepted:** projects created from skeleton never inherited its `SECURITY.md`. `skeleton/.gitattributes` already marks it `export-ignore`, with `CONTRIBUTING.md`, `CHANGELOG.md` and `create-project.sh`. The planned placeholder in `create-project.sh` would have fixed nothing, so it was not made.
  - **The regression check:** a new `wfl ci:check` rule. On the unchanged files it reports 8 findings (component-template, waffle and skeleton); after the change, no drift.
  - **Commits:** 26 policy commits (queue `addfc5c`, serializer `43671c7`, waffle `3544cd9`) and skeleton `7f7dc6a`; umbrella `a81e186` (the rule) and `d2ee226` (27 gitlinks).
  - **The maintainer's part:** private vulnerability reporting in every public repository (D9, by 2026-11-23). The API shows it still off in queue and serializer, so S-B1-08's fix-check waits for it.
  - **Not covered:** the umbrella, workspace, academy and documentation have no `SECURITY.md`. An organisation-level policy, in the organisation's `.github` repository, would cover them; that is the maintainer's call.
- **The CHANGELOG pass:**
  - The legend asks each repo's first beta8 commit to open `## [Unreleased]`, and Wave 1's commits did not. One pass added the section to the 25 libraries and skeleton. `component-template`'s CHANGELOG is the new-component starter and stays as it is.
  - Security lines name S-B1-02, -07 and -08 by ID, severity and component. cache's Predis line is marked breaking, and auth's lists the retired marks.
  - **Commits:** 26 (queue `7d39ae5`), umbrella `c358130`.
- **The fix-checks of S-B1-02 and S-B1-07** run from 17:58: for each finding, one `finding-verifier` writes the official verdict, and an independent read-only skeptic tries to refute the fix.

### 2026-11-20 17:58–18:02 CET — the fix-checks of S-B1-07 and S-B1-02

- A workflow of four agents, two per finding: the official `finding-verifier` (Opus, high effort) writes the verdict file, and an independent read-only skeptic tries to refute the fix. It took 3 min 36 s.
- **S-B1-07 (LOW, S): HOLDS**, by both agents. Recorded: `wfl audit:fixed 0.1.0-beta8 S-B1-07 queue@0e5e675 --run pilot`, so the pilot ledger has 1 of 31 fixed.
- **S-B1-02 (MEDIUM, M): contested.** The official verifier answers HOLDS; the skeptic answers that one part of the finding's scope is still open. The detail stays in the local evidence. S-B1-02 is not recorded until the maintainer decides.
- **S-B1-08** waits for private vulnerability reporting, which is part of its fix (D9).
- **Evidence** (local, git-ignored): `project_system/Audits/Beta8/wave1-fix-checks/`, and the verdict files in `project_system/Audits/Beta8/pilot/verdicts/`.

### 2026-11-20 18:03–18:10 CET — S-B1-02 (MEDIUM, M): its fix completed, then checked again

- The maintainer took the recommendation: "go with your recommendation for S-B1-02".
- **The second part of the fix,** made in component-template and copied as before: queue `6c63c43`, serializer `d4b7a82` and the 24 other component repos.
- **Umbrella:** `9de2a0a` (the tightened `wfl ci:check` rules; umbrella-ci and fresh-install follow) and `6fa85a8` (26 gitlinks).
- **The regression check:** the tightened rules report 292 findings on the workflows as they were before this part, and no drift after it. All 29 workflows parse as YAML.
- **The fix-check runs again,** with both agents, on `queue@6c63c43`.
- **Evidence** (local, git-ignored): `project_system/Audits/Beta8/wave1-s-b1-02-part2/`.

### 2026-11-20 18:10–18:14 CET — S-B1-02 checked again: HOLDS

- **Both agents answer HOLDS** on `queue@6c63c43`, so S-B1-02 (MEDIUM, M) is recorded: `wfl audit:fixed 0.1.0-beta8 S-B1-02 queue@6c63c43… --run pilot`. The pilot ledger has 2 of 31 fixed (S-B1-02, S-B1-07).
- **Residual notes** that do not decide the verdict are kept in the local evidence for the maintainer: two downloads that pinned actions make at run time, and three blind spots of the new rules, none of which affects today's workflows.
- **Wave 1 is complete,** except S-B1-08's fix-check, which waits for private vulnerability reporting. Next comes the first push, on the maintainer's word (D6).

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
