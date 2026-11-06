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
- **Blind, refute-first verification.** A verifier gets the claim and the location only, never the
  finder's reasoning, severity or proposed fix, and tries to disprove the claim before confirming it.
- **No claim without a measurement** (AGENTS.md §7): no performance, memory or "safe" statement that
  the run did not measure.
- **No fixes during the audit.** Audit agents write their own report file and nothing else: no code,
  no tests, no config, no commits.
- **English** in every audit file (framework policy, AGENTS.md §1).

## When
- **beta8:** `[AUD-01]`, the full-surface audit, and freeze exit gate #4 ("zero open criticals").
- **RC1:** the entry gate re-runs the beta8 exit gate. Re-check the beta8 ledger with
  `wfl audit:check 0.1.0-beta8 --gate`, then audit the RC1 delta (a diff-scoped run, below).
- **After v1:** before each release, as the protocol says. A diff-scoped run covers what changed.

A full run is about 40 to 50 subagents, the size of the beta6 Claude pass (42 agents, about 3.5M
tokens). **State the count and the run's profile, and wait for the maintainer's go before dispatching
the finders.**

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
   repository with its commit (and whether it matches the umbrella pin), the toolchain, the security
   finders and the modernization groups.
   - The defaults: all released repositories, the EcoShield gateway, and the agentic-layer lens.
   - `--only a,b` makes a partial run (three repositories or fewer bundle the twelve security lenses
     into three finders). `--no-gateway` and `--no-agentic` trim a full run; `--with-agentic` adds the
     agentic lens to a partial one.
   - It refuses uncommitted changes, because the manifest pins commits.
2. `wfl audit:evidence <version>` runs the automated tools once per repository, in `waffle-dev`:
   Mago's complexity rules (report-only, at Mago's defaults, never the gate's threshold), Psalm taint
   analysis, `composer audit`, igor through `igor.sh` (the pinned auditor), and the SEC-03 scan. Run it
   in the background: it takes several minutes. Read `evidence/INDEX.md` when it ends.

### 1. Security finders (Phase 1 of the protocol)
One `owasp-finder` per unit in `manifest.json` → `security_units`: the ten OWASP Top 10:2025 categories,
`W1` (worker-state leaks), `W2` (timing-safe comparisons) and `AG` (the repository's own AI layer,
against OWASP's Top 10 for Agentic Applications 2026). The lens cards, the regression list and the
dated threat notes are in `lenses/security.md`. `auth` also gets the `auth-bridge-audit` checklist and,
for passkeys, the `webauthn-auditor` agent.

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
Mode: full   (or: calibration — read only <directory>; skip the regression list and project_system/)
```

A candidates file counts only once it carries `Status: complete`. One that is missing or partial is
dispatched again.

### 3. Verification
For each candidates file:
1. `wfl audit:claims <version> <S-A05>` prints its claims without the finder's evidence, reasoning,
   proposed fix or severity.
2. A `finding-verifier`, with the `verifier` model and effort, gets that output, not the file. It writes
   `verdicts/<S-A05>.md`.
3. Every HIGH or CRITICAL candidate also gets a verifier of its own:
   `wfl audit:claims <version> <S-A05> --ids S-A05-03` → `verdicts/S-A05-03.md`.
4. The majority verdict wins. When one verifier confirms and another refutes, `wfl audit:status` lists
   the candidate as disputed and a third verifier breaks the tie.

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

It ends with `wfl audit:check <version> --render` clean. Give it the release phase (AGENTS.md §5b and
the current roadmap's status line).

### 5. The maintainer decides
Summarize for the maintainer in a few lines: the counts by severity, every MUST, and what the triager
proposes. Then ask them to decide each finding, and wait.
- `/audit` in the cockpit lists the ledger by severity and records each decision with their name and
  the date.
- In a terminal of their own: `wfl audit:sign <version> <ID> fix|accept|post-v1 "reason"`.
- A risk acceptance and a move to post-v1 carry a reason. A CRITICAL can only be fixed or accepted.

I never run `wfl audit:sign` and never write a `decision` field. The script refuses an AI agent's call,
the cockpit guard refuses the command and the ledger edit, and the team settings deny it.

### 6. Integration
Once the decisions are in:
1. **Roadmap:** through `roadmap-steward`, every "fix" goes into the release roadmap as an audit
   remediation ledger (the shape of beta6's `[FIX-01]` table: finding ID, finding, target file). In
   beta8 that is `[AUD-01]` in `Roadmap_Beta8.md`. Every "post-v1" goes into `Roadmap_Post_v1.md`. Say in
   the roadmap where the local audit archive lives.
2. **Tickets:** one `.scratch/release-audit-<version>/issues/NN-<slug>.md` per fix, in the format of
   `docs/agents/issue-tracker.md`, with `Roadmap: [AUD-01]` and `Finding: <ID>` lines. Never GitHub
   issues unless the maintainer asks for them.
3. **Ledger:** set each fix's `roadmap` and `ticket` fields in `ledger.json` (never its `decision`),
   then `wfl audit:check <version> --render`.
4. **Report page:** publish `consolidated.md` as a private Artifact page, as beta6 did, and give the
   maintainer the link.
5. Commit the roadmap changes locally (commit-as-you-go), never the gitignored audit folder.

### 7. Closure
The fixes go through the normal loop (`tech-lead`: `coding` → `test` → `code-review`), each citing its
finding ID. For each fixed finding:
1. A `finding-verifier` in fix-check mode receives the claim and the fix commit, and writes
   `verdicts/fix-<ID>.md` (`HOLDS` or `FAILS`).
2. On HOLDS: `wfl audit:fixed <version> <ID> <repo>@<commit>`.

The release is clear when `wfl audit:check <version> --gate` passes: every finding decided, every "fix"
landed and re-verified, no CRITICAL deferred. That is the evidence for beta8 exit gate #4, and
`wfl pre-release` checks it for beta8 and every later release.

## Release-phase rules
The triager applies them (`lenses/roadmap.md`) and I check them before presenting the proposal.

| Today | MUST | SHOULD | COULD |
|---|---|---|---|
| beta8, before its tag | fix in beta8, or a signed acceptance | in beta8 if it changes no public API, else post-v1 | `[DOC-01]` when it is documentation, else post-v1 |
| after the beta8 tag, RC1 | bug and security fixes only; after the RC1 tag a critical defect means RC2 (`rc-certification`) | post-v1 | post-v1 |
| 1.x minor | fix in the release | the release, with no BC break | the release or later |

## Cost knobs
- The profile (above): the finders carry most of the cost, so `economy` or a lower finder effort saves
  the most. Keep the verifiers strong: they decide what the maintainer sees.
- `--wave N` paces a run to the usage limit; a run that stops resumes where it left off.
- `--only <repositories>` for a partial run.
- A diff-scoped run (RC1, 1.x): `--only` the repositories that changed since the last audited tag, and
  name the changed files in each finder's prompt (`git -C <repo> diff --stat <tag>`) so it reads those
  first. The regression list still applies in full.
- Small scopes bundle the security lenses (three finders instead of twelve).
- A rehearsal runs as `--run pilot` and never touches the release's own run.

## Formats
- `templates/candidates.md` and `templates/verdicts.md`: the headings `wfl audit:*` parses. Keep the
  ` · ` separators and the `Status: complete` line.
- `templates/ledger.example.json`: every ledger field. Decisions are written only by `wfl audit:sign`.

## Related
- `security-audit`: the per-component checklist and the beta8 `[AUD-01]` surface map.
- `roadmap-steward`: writing the approved items into the roadmap.
- `tech-lead`: the fix loop; `api-freeze` and `rc-certification`: what each phase allows.
- `worker-safety`, `auth-bridge-audit`, `webauthn-passkeys`: depth for their lenses.
