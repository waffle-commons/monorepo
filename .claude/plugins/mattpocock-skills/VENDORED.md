# Vendored: mattpocock/skills

| | |
|---|---|
| Upstream | <https://github.com/mattpocock/skills> |
| Commit | `24fe0ef7737efae15c87225755e9f6f5965e4888` |
| Upstream version | `1.3.1` (2026-10-04) |
| License | MIT, see [`LICENSE`](LICENSE) |
| Refresh | `scripts/claude/vendor-mattpocock.sh <sha>`, then review the diff |

Files are copied verbatim, except the Codex-only `agents/openai.yaml` descriptors, which are
dropped. The manifest lists only the kept skills, so Claude Code loads nothing else.

## Kept (20)

- `engineering/ask-matt`
- `engineering/codebase-design`
- `engineering/diagnosing-bugs`
- `engineering/domain-modeling`
- `engineering/grill-with-docs`
- `engineering/improve-codebase-architecture`
- `engineering/pr`
- `engineering/research`
- `engineering/retro`
- `engineering/tdd`
- `engineering/to-spec`
- `engineering/to-tickets`
- `engineering/wizard`
- `productivity/grill-me`
- `productivity/grilling`
- `productivity/handoff`
- `productivity/teach`
- `productivity/to-questionnaire`
- `productivity/wait-what`
- `productivity/writing-for-agents`

## Excluded, and why

- `implement`: ends with "Commit your work to the current branch". Commits are the human's
  (`AGENTS.md` §6).
- `implement-spec`: creates an integration branch, worktrees and merges, and opens draft PRs. It
  also does not fit a monorepo of submodules.
- `triage` and `wayfinder`: post comments, labels and maps on the issue tracker, and research
  branches.
- `prototype`: commits the prototype to a throwaway branch.
- `setup-matt-pocock-skills`: writes an "Agent skills" block into CLAUDE.md. The configuration it
  produces is written by hand instead: `docs/agents/` and `AGENTS.md` → "Third-party skills".
- `code-review`: clashes with the project's own `code-review` skill, which carries its two-axis
  idea (standards and spec).

`AGENTS.md` §6 overrides any step of a kept skill that would commit, branch, push, open a PR or
publish an issue: Claude stops and asks.
