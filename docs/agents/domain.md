# Domain docs (agent configuration)

> Read by the vendored `mattpocock-skills` plugin (`tdd`, `diagnosing-bugs`, `domain-modeling`,
> `grill-with-docs`, `improve-codebase-architecture`, …). Written by hand instead of
> `/setup-matt-pocock-skills`. See `AGENTS.md` → "Third-party skills".

## Before exploring, read these

- **`GLOSSARY.md`** at the repository root, when it exists: the project's domain vocabulary
  (worker-safe, resettable, perimeter, wave, gitlink, skew, SQR, gate, soak, …). It is created
  lazily by `/domain-modeling` the first time a term is settled; do not create it up front and do not
  flag its absence.
- **`AGENTS.md`**: the binding engineering standards.
- **`project_system/RFCs/`**: the design records. In this repository they play the role of ADRs.
  Read the RFCs that touch the area you are working in.
- **`project_system/Roadmaps/`**: what is committed for which release, with acceptance criteria.

## Decisions: RFCs instead of ADRs

- **Never create an ADR file or an ADR directory.** A decision is recorded by amending an RFC or a
  roadmap through the `roadmap-steward` skill, with the maintainer's approval.
- When your output contradicts an RFC, say so explicitly rather than overriding it silently:

  > _Contradicts RFC-022 §4 (stateless repositories), but worth reopening because…_

- `project_system/Audits/`, `Notes/` and `TODOs/` are gitignored working areas, not decisions.

## Use the glossary's vocabulary

When your output names a domain concept (a ticket title, a refactor proposal, a hypothesis, a test
name), use the term as `GLOSSARY.md` defines it. If the term you need is missing, either you are
inventing language the project does not use (reconsider), or there is a real gap (note it for
`/domain-modeling`).

## Layout

Single context: one `GLOSSARY.md` at the root. Components are not separate glossary contexts; a
component-specific term goes in the root glossary with the component named.
