# Reference — `project_system/` (governance & roadmap)

> **Release:** `0.1.0-beta5`
> **Scope:** the `project_system/` directory — the project's authoritative governance, roadmap, and historical record.

`project_system/` is the **single source of truth for how the Waffle ecosystem is planned, decided, shipped, and reviewed.** It is read by maintainers and contributors alike.

> **⚠️ Authority — read this first.**
> `project_system/Roadmaps/` is the **official roadmap of the project**. If a plan is not written there, it is not committed direction.
> `project_system/RFCs/` holds the **authoritative design specifications** each component implements.
> Code, components, and pull requests are expected to **align with the current roadmap and the relevant RFC.** Significant new work should be reflected in (or proposed against) these documents *before* it lands.

## Layout

| Path | Tracked? | What it is |
| :--- | :--- | :--- |
| `RFCs/` | ✅ tracked | Design specifications, one per subsystem (`RFC_001`–`RFC_022`). The "why & what" behind every component. |
| `Roadmaps/` | ✅ tracked | The official, release-by-release roadmap (`Roadmap_<Release>.md`). **The binding plan of record.** |
| `Logs/Releases/` | ✅ tracked | Per-release change logs (`Log_<Release>.md`) — what actually shipped in each wave. |
| `Logs/Retrospectives/` | ✅ tracked | Per-release retrospectives (`Retro_<Release>.md`) — what went well / what to improve. |
| `Audits/` | 🔒 gitignored | Maintainers' private architectural audits. |
| `Notes/`, `TODOs/` | 🔒 gitignored | Private scratch space. |
| `*.pem` | 🔒 gitignored | Secrets — never committed. |

The private directories are declared in `project_system/.gitignore`; everything else is tracked and shared with all collaborators.

## The governance lifecycle

Work flows through these artifacts in order — this is the project's operating loop:

1. **RFC** (`RFCs/RFC_NNN_*.md`) — a subsystem is *specified before it is built*: the problem, the design, the contracts, the trade-offs.
2. **Roadmap** (`Roadmaps/Roadmap_<Release>.md`) — RFCs are sequenced into a release wave with an explicit **Definition of Done**. *This is the official roadmap.*
3. **Implementation** — components are built/changed to satisfy the roadmap's DoD, under the usual quality bar (`mago` zero-baseline · ≥95% coverage · `wfl igor` 0 KO).
4. **Release Log** (`Logs/Releases/Log_<Release>.md`) — when a wave ships, the changes are recorded.
5. **Retrospective** (`Logs/Retrospectives/Retro_<Release>.md`) — after the wave, wins and frictions are captured, feeding the *next* roadmap.

## Conventions

- **Naming:** `<Category>_<Token>.md` — `RFC_NNN_Title`, `Roadmap_<Release>`, `Log_<Release>`, `Retro_<Release>`. Release tokens are PascalCase: `Alpha5`, `Beta0`, `Beta4`, `Beta5`, `RC1`, `V1_Gold`, `V1_Master`, `Post_V1`.
- **Frontmatter:** every file begins with a YAML frontmatter block (`title`, `type`, `tags`, …).
- **Plain Markdown only:** standard relative Markdown links — **no** Obsidian `[[wikilinks]]`.
- **Release names:** the canonical line is `alpha3` → `alpha5` → **`beta0`** (which *superseded and replaced* the planned "alpha6") → `beta1` … `beta7` → `rc1` → `v1`. There is no standalone `alpha6` release.

## Where to look

| Question | Go to |
| :--- | :--- |
| *What's the plan / what's next?* | `Roadmaps/` — current: [`Roadmap_Beta5.md`](../../project_system/Roadmaps/Roadmap_Beta5.md) |
| *Why is component X designed this way?* | the matching [`RFCs/RFC_NNN_*.md`](../../project_system/RFCs/) |
| *What shipped in a release?* | [`Logs/Releases/Log_<Release>.md`](../../project_system/Logs/Releases/) |
| *What did we learn from a release?* | [`Logs/Retrospectives/Retro_<Release>.md`](../../project_system/Logs/Retrospectives/) |

## Related

- [Repository layout](repository-layout.md) — where `project_system/` sits in the tree.
- [The release cycle](../explanation/release-cycle.md) — how a roadmap wave becomes tagged releases, logs, and retrospectives.
