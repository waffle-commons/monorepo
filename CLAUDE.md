# CLAUDE.md — waffle-commons (PHP 8.5 · FrankenPHP · monorepo of independent submodules)

> ⚡ Thin CLI router. **All** standards, architecture, and agent behaviour live in
> **[`/AGENTS.md`](./AGENTS.md)** and **`.opencode/skills/<skill>/SKILL.md`**. Do not add standards here.

## Canonical commands (always in Docker — never run PHP on the host)

```bash
docker exec -it -w /waffle-commons/{component} waffle-dev {command}
```

| Intent | `{command}` |
|--------|-------------|
| Format | `composer formatter` (`vendor/bin/mago fmt`) |
| Lint | `composer linter` (`vendor/bin/mago lint`) |
| Analyze | `composer analyzer` (`vendor/bin/mago analyze`) |
| Guard (dependency perimeter) | `composer guard` (`vendor/bin/mago guard`) |
| All static gates | `composer mago` (fmt + lint + analyze + guard) |
| Tests (PHPUnit 12.5, ≥95% coverage) | `composer tests` |
| Worker-safety audit (`wfl igor`) | `composer igor` (`vendor/bin/igor-php .`) |

**`mago` is clean only at ZERO output** — zero errors **and** zero warnings, info, and help/notice
messages. Native-first fixes; never a baseline or suppression.

**Definition of done (per modified component):** `composer mago && composer tests` both green, and
`wfl igor` reports **0 KO**.

> 🛠 **Internal CLI:** `wfl <cmd>` wraps the Docker calls — `wfl mago [comp]`, `wfl test [comp] [--filter=…]`,
> `wfl igor`, `wfl compare-audit [comp…]` (SEC-03 gate), `wfl academy:test`, `wfl link/unlink`,
> `wfl components`. **Beta5 automation:** `wfl dod [comp]` (full definition-of-done gate),
> `wfl coverage [comp]` (clover %), `wfl flake-hunt <comp> [N]` (isolate a flaky test),
> `wfl sync:contracts [comp]` / `wfl sync:demos [app]` (vendor-skew fix), `wfl pre-release [comp]`,
> `wfl new-component <Name> <url>`, `wfl docker:reset`, `wfl mcp:check`. **Diagnostics / agent helpers:**
> `wfl coverage:gaps <comp>` (files under 95% + uncovered count), `wfl xref <Symbol> [--tests]`
> (fixed-string symbol search, vendor-excluded, sanity-checked), `wfl changed` (dirty submodules — commit
> prep), `wfl boot-smoke <app>` (kernel boots without HTTP), `wfl wf-report <file>` (digest a workflow/agent
> JSON output). Run `wfl help` for the full surface.
>
> 🔌 **MCP:** five servers (filesystem · postgres · mongo · redis · github) are declared for Claude Code
> (`.mcp.json`), opencode (`opencode.json`), and AntigravityCLI (`.antigravitycli/mcp_config.json`). Secrets
> are env-var refs; run `wfl mcp:check` for prerequisites. See **[`/MCP.md`](./MCP.md)**.

## 🧭 Redirection directive (NON-NEGOTIABLE)

Before planning or editing **anything**, READ:

1. **[`/AGENTS.md`](./AGENTS.md)** — PHP 8.5 strict standards, FrankenPHP statelessness mandate,
   the Mago Purge Protocol, and the **Skills Routing Table** (intent → skill).
2. The matching **`.opencode/skills/<skill>/SKILL.md`** for the task. When unsure, start with `tech-lead`.
3. **`project_system/`** — the source of truth for project **direction**: `RFCs/` (RFC-001…022) and
   `Roadmaps/` (`Roadmap_Beta4 → Roadmap_V1_Gold`, plus `Roadmap_V1_Master`). Consult it before
   planning roadmap work; see the `roadmap-steward` skill.

Hard invariants: components depend **only** on `waffle-commons/contracts` (plus `waffle-commons/utils`,
which itself requires only contracts); zero Mago baselines and zero non-empty Mago output; stateless
and resettable across requests (`wfl igor` 0 KO).
