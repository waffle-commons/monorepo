---
name: release-audit
description: "Pre-release audit run end to end by Claude: OWASP security, PHP 8.5 modernization, blind verification, ledger, MoSCoW roadmap, maintainer sign-off"
when_to_use: >-
  Auditing the framework before a release: "run the release audit", "pre-release audit", "audit before
  beta8 / RC1 / 1.x", "the health of the framework", "what must the next release fix", the beta8
  [AUD-01] full-surface audit, freeze exit gate #4 ("zero open criticals"), the RC1 entry-gate re-run,
  an OWASP Top 10 sweep across the ecosystem, a PHP 8.5 modernization review, a MUST/SHOULD/COULD
  roadmap from audit findings, resuming or checking an audit run (wfl audit:status, wfl audit:check).
argument-hint: "[version]"
---

## What I do
I run the maintainer's **pre-release audit protocol** (the vault note "Protocole d'Audit Pré-Release")
from start to finish with Claude Code agents: scope and tool evidence, a security sweep, a
modernization review, verification of every candidate, triage into one ledger, a phase-aware
MUST/SHOULD/COULD roadmap, then the integration of what the maintainer approves. The protocol's three
prompts are kept word for word in `lenses/`; its system instructions are the persona below.

The maintainer makes exactly one kind of call: the decision on each finding (fix, accept the risk,
post-v1). Everything else is mine. I never take that call, and I never sign for them.

## Persona (every audit agent works under it)
> You are a Senior Software Architect and a DevSecOps Expert specializing in PHP. You are critical,
> rigorous, and you let nothing slip. Your goal is to analyze the provided source code to identify
> technical debt, security vulnerabilities (OWASP), and modernization opportunities (PHP 8.5+).

The protocol asked for a temperature of 0.2 ("cold analysis, not creativity"). Agents have no such
setting, so these rules do that job:
- **Tools first.** The automated evidence (`wfl audit:evidence`) is read before any code. A candidate
  that contradicts a tool says why.
- **A location for every claim:** `path:line` at the commit in `manifest.json`, with a snippet. No
  location, no candidate.
- **Negative evidence counts.** Each finder lists the controls it checked and found holding, with
  `path:line`, so a clean area is distinguishable from an unexamined one.
- **Blind, refute-first verification.** A verifier gets the claim and its locations only, never the
  finder's reasoning, severity or proposed fix, and tries to disprove the claim before confirming it.
- **No claim without a measurement** (AGENTS.md §7): no performance, memory or "safe" statement that
  the run did not measure.
- **No fixes during the audit.** Audit agents write their own report file and nothing else: no code,
  no tests, no config, no commits.
- **English** in every audit file (framework policy, AGENTS.md §1).

## When
- **beta8:** `[AUD-01]`, the full-surface audit, and freeze exit gate #4 ("zero open criticals").
- **RC1:** the entry gate re-runs the beta8 exit gate. A diff-scoped run audits the RC delta
  (`wfl audit:init 1.0.0-RC1 --only <changed> --base 0.1.0-beta8`), and its gate re-checks the beta8 gate.
- **RC2**, only on a critical defect: a diff-scoped run over the RC1 → RC2 delta, `--base 1.0.0-RC1`.
- **Gold**, zero code delta: `WFL_AUDIT_VERSION=1.0.0-RC<n> wfl pre-release --all` holds `1.0.0` on its
  RC's run. The script refuses any other pairing.
- **After v1:** before each X.Y.0 and its RCs, as the protocol says. A diff-scoped run covers what changed.

Size a run from the pilot: about 1.9 to 2.0M tokens for two repositories before the triager (finders about
1.4M, verifiers 0.5 to 0.6M). A full run is several times that, over several 5-hour windows. **State the
unit count and the run's profile, and wait for the maintainer's go before dispatching the finders.**

## Who runs the agents
Each run records, in `manifest.json`, the model and effort for each role, plus how many agents run at
once (`wave`). AGENTS.md §8 allows this run-level choice for the release audit.

| Profile | finder | verifier | triager |
|---|---|---|---|
| `thorough` | opus · high | opus · high | opus · high |
| `balanced` (default) | opus · medium | opus · high | opus · high |
| `economy` | sonnet · medium | opus · medium | opus · medium |

- **Choosing:** `wfl audit:init <version> --profile <name>`, with per-role overrides
  (`--model finder=sonnet --effort verifier=xhigh`) and `--wave N` (default 6). The maintainer picks;
  when they name none, the default is `balanced`.
- **Changing mid-run:** `wfl audit:profile <version> --profile economy` (or any override) changes the
  agents dispatched from then on. The manifest keeps the history. Re-dispatched work uses the new choice.
- **Dispatching:** every Agent call passes `model` and `effort` from `manifest.json` → `agents.<role>`
  (`owasp-finder` and `modernization-finder` are `finder`). Never more than `wave` agents in flight.
  A run made before profiles has no `agents`: its agents inherit the session's model and effort.
- **Recording:** each candidates and verdicts file names, in its header, the model and effort that wrote
  it. The report's Methodology states the profile, so two runs compare.
- **Measuring:** note each agent's token count from its completion notice in the report's Methodology,
  so the next run can choose its profile on evidence.

## The pipeline
Files live in `project_system/Audits/<Beta8|RC1|version>/<run>/` (gitignored, local only). Every step
writes its result there, so a run survives a usage limit or a compaction: `wfl audit:status <version>`
always names the next step. The run name defaults to `release-audit`; a rehearsal uses its own
(`--run pilot`).

### 0. Scope and evidence
1. `wfl audit:init <version>` writes `manifest.json` and `MANIFEST.md`: the umbrella and every released
   repository with its commit (and whether it matches the umbrella pin), the toolchain, and the security,
   modernization and calibration units.
   - The defaults (scope `full`): every released repository, the EcoShield gateway, the agentic-layer lens
     (`AG`), WebAuthn (`WA`) when `auth` is in scope, and the calibration. A missing gateway checkout stops
     `init`.
   - `--no-gateway`, `--no-agentic` and `--no-calibration` trim a full run (scope `trimmed`, which a
     release gate does not count as the full surface).
   - `--only a,b` makes a partial run (three repositories or fewer bundle the twelve core lenses into three
     finders); `--with-agentic` and `--with-calibration` add those to it. `--only a,b --base <version>`
     makes a diff-scoped run, whose gate re-checks the base audit.
   - It refuses uncommitted changes, because the manifest pins commits (`--allow-dirty` audits them, and
     the report says so). `--force` starts over: the whole run moves aside to `<run>.<time>/`.
2. `wfl audit:evidence <version>` runs the automated tools once per repository, in `waffle-dev`:
   Mago's complexity rules (report-only, at Mago's defaults, never the gate's threshold), Psalm taint
   analysis, `composer audit`, igor through `igor.sh` (the pinned auditor), and the SEC-03 scan. Run it
   in the background: it takes several minutes. Read `evidence/INDEX.md` when it ends.
3. `wfl audit:calibrate <version>`, when the run has calibration units. Each `C-<n>` unit is a tree that a
   beta6 `[FIX-01]` fix replaced (`scripts/audit-calibration.json`), snapshotted with `utils` and
   `contracts` under `calibration/C-<n>/`; the lines that fix changed go to `calibration/expected.json`.
   - One `owasp-finder` per unit, in calibration mode, writes `candidates/C-<n>.md`.
   - `wfl audit:status` scores what each one raised against those lines (recall), and the report states it.
   - Calibration candidates never reach the ledger. One on code still shipped today is a lead for the
     regular units: record it in the run's local leads.
   - Measuring the verifiers as well (a few planted false claims in a claims file) is the maintainer's
     option.

### 1. Security finders (Phase 1 of the protocol)
One `owasp-finder` per unit in `manifest.json` → `security_units`: the ten OWASP Top 10:2025 categories,
`W1` (worker-state leaks), `W2` (timing-safe comparisons), `WA` (passkeys, when `auth` is in scope) and
`AG` (the repository's own AI layer, against OWASP's Top 10 for Agentic Applications 2026). The lens
cards, the `[AUD-01]` surfaces each lens owns and the dated threat notes are in `lenses/security.md`; the
regression list is `lenses/regressions.md`. `auth` also gets the `auth-bridge-audit` checklist.

### 2. Modernization finders (Phase 2)
One `modernization-finder` per group in `manifest.json` → `modernization_units`. The checklist is in
`lenses/modernization.md`. Complexity comes from the Mago metrics in `evidence/`, never from an
estimate.

**Dispatching the finders.** Background agents, at most `wave` at a time (manifest), each with the
`finder` model and effort; `wfl audit:status` between waves. Give each one this prompt, filled in:

```text
Release audit <version> · run <run> · unit <S-A05 | M-data>
Run folder: project_system/Audits/<dir>/<run>/ (manifest.json: every repository and its commit)
Lenses: <ids and names>   |   Group: <group> (<repositories>)
Write: candidates/<S-A05 | M-data>.md, in the format of .claude/skills/release-audit/templates/candidates.md
Mode: full   (or: calibration — read only calibration/C-<n>/ in the run folder: no file under lenses/, no
             scripts/audit-calibration.json, nothing else of project_system/, no git history)
```

A candidates file counts only once it carries `Status: complete`. One that is missing or partial is
dispatched again.

### 3. Verification
For each candidates file:
1. `wfl audit:claims <version> <S-A05>` prints its claims, every location included, without the finder's
   evidence, reasoning, proposed fix or severity.
2. A `finding-verifier`, with the `verifier` model and effort, gets that output, not the file. It writes
   `verdicts/<S-A05>.md`.
3. Every HIGH or CRITICAL candidate, as the finder or any verifier rates it, also gets a verifier of its
   own: `wfl audit:claims <version> <S-A05> --ids S-A05-03` → `verdicts/S-A05-03.md`. `wfl audit:status`
   holds the run until it has one.
4. The majority verdict wins. When one verifier confirms and another refutes, `wfl audit:status` lists
   the candidate as disputed, and a third verifier breaks the tie → `verdicts/<id>-tiebreak.md`.

```text
Release audit <version> · run <run> · verify <S-A05>
Run folder: project_system/Audits/<dir>/<run>/
<the output of wfl audit:claims>
Write: verdicts/<S-A05>.md (or verdicts/<id>.md), in the format of .claude/skills/release-audit/templates/verdicts.md
Do not open candidates/ or another verifier's file.
```

### 4. Triage and the roadmap proposal (Phase 3)
One `audit-triager`, with the `triager` model and effort. It reads the candidates, the verdicts and the evidence, merges duplicates, settles
severities, and writes:
- `ledger.json` (one entry per confirmed or plausible finding, `decision: null`);
- `consolidated.md` (the beta6 report layout);
- `roadmap-proposal.md`: MUST / SHOULD / COULD under the rules of the current release phase
  (`lenses/roadmap.md`).

It ends with `wfl audit:check <version> --render` clean, which also holds the ledger to the run: every
verified candidate is a finding, a `duplicates` entry or in `refuted`, and `consolidated.md` exists. Give
it the release phase (AGENTS.md §5b and the current roadmap's status line).

### 5. The maintainer decides
Summarize for the maintainer in a few lines: the counts by severity, every MUST, and what the triager
proposes. Then ask them to decide each finding, and wait.
- `/audit` in the cockpit lists the ledger by severity and records each decision with their name, the
  date and a fingerprint of the finding.
- In a terminal of their own: `wfl audit:sign <version> <ID> fix|accept|post-v1 "reason" --residual "…"`.
  It asks them to type the ID back.
- A risk acceptance and a move to post-v1 carry a reason and the residual risk: what stays exposed, and
  to whom. A move to post-v1 is a risk acceptance for v1. A CRITICAL can only be fixed or accepted.

I never run `wfl audit:sign` and never write a `decision` field. Four guard rails back that: the script
wants a terminal and the typed ID (my shell has none), the cockpit guard refuses the command and any
ledger write through the shell, the Edit/Write check refuses a decision edit or a change to a decided
finding, and the team settings deny the command. They stop a slip, not a determined program; the
fingerprint covers the rest, because a decided finding that changes afterwards fails `wfl audit:check`.

### 6. Integration
Once the decisions are in:
1. **Roadmap:** through `roadmap-steward`, on the release's `pre-release/<version>` branch, every "fix"
   goes into the release roadmap as an audit remediation ledger: finding ID, severity, component and
   size. In beta8 that is `[AUD-01]` in `Roadmap_Beta8.md`. Every "post-v1" goes into
   `Roadmap_Post_v1.md`. Say in the roadmap where the local audit archive lives.
   - **Disclosure:** until a finding's fix ships in a release, tracked files (roadmaps, commit messages, PR
     text) name it by ID, severity, component and size only; its description and location stay in the
     local archive and its ticket. A HIGH or CRITICAL in released code appears in no tracked file until
     its fix is released.
2. **Tickets:** one `.scratch/release-audit-<version>/issues/NN-<slug>.md` per fix, in the format of
   `docs/agents/issue-tracker.md`, with `Roadmap: [AUD-01]` and `Finding: <ID>` lines. Never GitHub
   issues unless the maintainer asks for them.
3. **Ledger:** set each fix's `roadmap` and `ticket` fields in `ledger.json` (never its `decision`),
   then `wfl audit:check <version> --render`.
4. **Report page:** ask the maintainer, then publish `consolidated.md` as a private Artifact page, as
   beta6 did, and give them the link.
5. Commit the roadmap changes only when the person has asked for commits (a standing commit-as-you-go
   request counts), never the gitignored audit folder.

### 7. Closure
The fixes go through the normal loop (`tech-lead`: `coding` → `test` → `code-review`), each citing its
finding ID. For each fixed finding:
1. A `finding-verifier` in fix-check mode receives the claim, its locations and the fix commit, and
   writes `verdicts/fix-<ID>.md`: `### FIX <ID> · HOLDS` (or `FAILS`) and `- fix: <repo>@<commit>`.
2. On HOLDS: `wfl audit:fixed <version> <ID> <repo>@<commit>`. It refuses a commit that does not come
   after the audited one, or that the fix-check does not name.

The release is clear when `wfl audit:check <version> --gate` passes:
- every run of the release is complete and reconciled: finders, two verdicts on a HIGH or CRITICAL, no
  tie left, every verified candidate accounted for, the calibration;
- every finding is decided, in this run and in the release's other runs (a pilot's decisions count);
- every "fix" is fix-checked and in what its repository releases (the umbrella pin);
- the surface is covered: every released repository under every core lens, the gateway, `AG`, `WA` for
  `auth`, with the audited commits inside the release. A diff-scoped run re-checks its base audit instead.

That is the evidence for beta8 exit gate #4. `wfl pre-release --all` holds beta8, later betas and every
X.Y.0 and its RCs on it (`scripts/release-audit.py required`); a patch release is exempt. The hold is
local: `Audits/` never leaves this checkout, so CI cannot run it.

## Release-phase rules
The triager applies them (`lenses/roadmap.md`) and I check them before presenting the proposal.

| Today | MUST | SHOULD | COULD |
|---|---|---|---|
| beta8, before its tag | fix in beta8, or a signed acceptance | in beta8; a public-API change goes through the BC review (`[FRZ-01]`, `[FRZ-03]`) | `[DOC-01]` when it is documentation, else post-v1 |
| after the beta8 tag, RC1 | bug and security fixes only; after the RC1 tag a critical defect means RC2 (`rc-certification`) | post-v1 (a public signature waits for the next major) | post-v1 |
| 1.x minor | fix in the release | the release, with no BC break | the release or later |

## Cost knobs
- The profile (above): the finders carry most of the cost, so `economy` or a lower finder effort saves
  the most. Keep the verifiers strong: they decide what the maintainer sees.
- `--wave N` paces a run to the usage limit; a run that stops resumes where it left off.
- `--only <repositories>` for a partial run.
- A diff-scoped run (RC1, RC2, 1.x): `--only` the repositories that changed since the last audited tag,
  `--base` that audit, and name the changed files in each finder's prompt (`git -C <repo> diff --stat
  <tag>`) so it reads those first. The regression list still applies in full.
- Small scopes bundle the security lenses (three finders instead of twelve).
- A rehearsal runs as `--run pilot` and never touches the release's own run.

## Formats
- `templates/candidates.md` and `templates/verdicts.md`: the headings `wfl audit:*` parses (`S-`, `M-` and
  calibration `C-` ids). Keep the ` · ` separators and the `Status: complete` line: `wfl audit:status`
  reports a heading under `## Candidates` that misses them.
- `templates/ledger.example.json`: every ledger field. Decisions are written only by `wfl audit:sign`.

## Related
- `security-audit`: the per-component checklist and the beta8 `[AUD-01]` surface map.
- `roadmap-steward`: writing the approved items into the roadmap.
- `tech-lead`: the fix loop; `api-freeze` and `rc-certification`: what each phase allows.
- `worker-safety`, `auth-bridge-audit`, `webauthn-passkeys`: depth for their lenses.
