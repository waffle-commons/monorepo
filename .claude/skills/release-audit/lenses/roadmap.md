# Roadmap rules (Phase 3)

Read by the `audit-triager`, and checked by the orchestrator before the proposal reaches the maintainer.

## The protocol's prompt (kept word for word)

> Based on your previous analysis, propose a **Roadmap** for the next release version. Categorize tasks into 3 groups:
> 1. **MUST HAVE (Security & Stability):** Critical fixes required before release.
> 2. **SHOULD HAVE (Modernization):** Refactoring to keep the framework competitive.
> 3. **COULD HAVE (Comfort):** Minor optimizations or missing documentation.

## MoSCoW
- **MUST:**
  - every confirmed or plausible security finding of severity LOW or higher;
  - every stability defect, such as an exception path that crashes a worker or a fail-open that was not
    deliberate.
- **SHOULD:** modernization items of MEDIUM or higher, and security INFO items worth a change.
- **COULD:** LOW and INFO modernization, and documentation.

## Proposal, by release phase
The phase is the one in the triager's prompt: AGENTS.md §5b and the status line of the current roadmap.

| Today | MUST | SHOULD | COULD |
|---|---|---|---|
| beta8, before its tag | `fix`, or `accept` when a fix is impossible before the tag (say why) | `fix` when `public-api: no`; `post-v1` when the fix changes a public signature after the BC review | `fix` when it is documentation (`[DOC-01]`); else `post-v1` |
| after the beta8 tag, RC1 | `fix` (bug and security fixes only; after the RC1 tag a critical defect means RC2, which restarts the soak) | `post-v1` | `post-v1` |
| 1.x minor | `fix` | `fix` with no BC break, else the next major | `fix` or `post-v1` |

A CRITICAL is never `post-v1`. A known, already-scheduled item, such as a roadmap item that covers it,
is proposed `post-v1` or `fix` with that item named in `notes`. It is never re-raised as new work.

## consolidated.md
The beta6 report layout, in this order:
1. `# Release audit · <version> (<run>)`, then **Methodology**:
   - units and agents, lenses, tools;
   - the manifest commit range;
   - the verification rule (blind, refute-first, majority, tie-break).
2. **Result:** `N CRITICAL, N HIGH, N MEDIUM, N LOW` across the confirmed and plausible findings, then
   how many candidates were refuted. Add **What held**: the controls that survived verification.
3. `## Security findings`, by severity. For each: `### <Severity> — <title> (<ID>)`, then *Where*,
   *Issue*, *Fix* and *Verification* (who confirmed it, what was tried).
4. `## Modern PHP review`: counts per lens, the highest-value items, the clean groups.
5. `## Regression check`: one row per regression item of the lenses, holds or regressed, with evidence.
6. `## Threat notes`: each dated note and what the run found about it.
7. `## Refuted candidates`: each, with the control that blocked it.
8. `## Roadmap`: MUST / SHOULD / COULD, the same as `roadmap-proposal.md`.

## roadmap-proposal.md
```markdown
# Roadmap proposal · <version> (<run>)
Phase today: <phase>. Rules: .claude/skills/release-audit/lenses/roadmap.md.

## MUST HAVE (Security & Stability)
1. <title> — <ID> — <S|M|L> — proposal: fix → <target release>
## SHOULD HAVE (Modernization)
1. …
## COULD HAVE (Comfort)
1. …
## Already scheduled (not proposed as new work)
- <ID>: covered by <roadmap item>
```
Size: S is under half a day, M is a day or two, L is more than that.
