---
description: Report the sync state of the umbrella and every component (read-only — never moves a branch)
---

# /sync-components

`waffle-commons` is an umbrella of independent submodules, each on its own
`pre-release/<version>` branch while a release is in progress. Those branches are
often **local only**, so this command is a **read-only report**. It never
updates, checks out or pulls anything.

## Execution

Run at the root of the project:

```bash
wfl sync:status --fetch
```

For every repo it prints the current branch, uncommitted files, commits ahead of and
behind `origin/main` (and the branch's own upstream, if any), and whether the umbrella
gitlink still matches the submodule `HEAD`. `--fetch` refreshes the remote-tracking
refs (`refs/remotes/*`) first; drop it to report from the last fetch.

## What NOT to run

**Never run `git submodule update --remote`** (with or without `--init --recursive`) as a
"sync". It checks out each remote default branch in a detached HEAD, abandons the local
`pre-release/*` branches, dirties every gitlink in the umbrella, and `--recursive` tries
to clone the private `academy` sub-repos.

Moving a branch, pulling, or bumping a gitlink is a git write. It happens only when the
human asks for that specific operation (see `AGENTS.md` → "Git & release safety").
