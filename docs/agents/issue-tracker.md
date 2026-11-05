# Issue tracker: local markdown (agent configuration)

> Read by the vendored `mattpocock-skills` plugin (`to-spec`, `to-tickets`, `code-review`-style
> flows). Written by hand instead of `/setup-matt-pocock-skills`. See `AGENTS.md` →
> "Third-party skills".

Specs and tickets that an agent drafts live as markdown files in `.scratch/`, which is gitignored.
They are working notes. **The plan of record is `project_system/Roadmaps/`**: work becomes committed
direction only when it is written there, through the `roadmap-steward` skill and with the
maintainer's approval.

**Never publish to GitHub Issues.** `gh issue create`, comments and labels are GitHub writes, and those
belong to the human (`AGENTS.md` §6).

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`.
- The spec is `.scratch/<feature-slug>/spec.md`.
- Tickets are one file each, `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` in
  dependency order (blockers first). Never one combined tickets file.
- A ticket's state is a `Status:` line near the top. The values are `ready-for-agent`,
  `ready-for-human`, `needs-info`, `in-progress` and `done`. There is no label system.
- A ticket's blockers are a `Blocked by: NN, NN` line near the top.
- When a ticket maps to a roadmap item, name it on a `Roadmap:` line (`Roadmap: [NET-01]`).
- Comments and history are appended under a `## Comments` heading at the bottom of the file.

## When a skill says "publish to the issue tracker"

Create the file under `.scratch/<feature-slug>/`, creating the directory if needed, and tell the user
its path. To promote a spec into committed direction, use `roadmap-steward`.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user normally passes the path or the ticket number.
