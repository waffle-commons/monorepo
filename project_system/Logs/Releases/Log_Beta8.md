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

- **About 15:10 CET:** the maintainer accepted the kickoff plan's day-0 recommendations and gave "proceed" for its first wave. The decisions and their reasons are in `Roadmap_Beta8.md`. The plan itself stays local (`project_system/Notes/beta8-kickoff/`, git-ignored).
- **About 15:50 CET**, the maintainer: "You can start the beta8 step by step. Keep detailed tracks of this release, it must be bulletproof as it is the contract freeze."

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
- **The skills the agents read (0.5):** in progress.

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
