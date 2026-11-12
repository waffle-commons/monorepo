@AGENTS.md

# CLAUDE.md — waffle-commons (PHP 8.5 · FrankenPHP · monorepo of independent submodules)

> ⚡ The import above puts `AGENTS.md` (every standard, the architecture, agent behaviour) in context
> for every session. This file only adds the Claude Code specifics. Do not add standards here.

## Canonical commands (always in Docker — never run PHP on the host)

```bash
docker exec -w /waffle-commons/{component} waffle-dev {command}
```

No `-it`: the agent's shell has no terminal, and Docker refuses `-t` without one. Add `-it` only when
typing the command in a terminal; `wfl run|mago|test` choose for you.

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
> `wfl components`. **Set-up:** `wfl init` (fresh clone → working checkout, safe to re-run), `wfl doctor`
> (what is missing, with the fix). **Gates:** `wfl dod [comp]` (full definition-of-done gate),
> `wfl coverage [comp]` (clover %), `wfl flake-hunt <comp> [N]` (isolate a flaky test),
> `wfl sync:contracts [comp]` / `wfl sync:demos [app]` (vendor-skew fix), `wfl pre-release [comp]`,
> `wfl new-component <Name> <url>`, `wfl docker:reset`, `wfl mcp:check`, `wfl ai:check` (lints this
> Claude Code layer). **Release audit** (the `release-audit` skill drives it): `wfl audit:init|evidence|calibrate|status`,
> `wfl audit:claims` (blind verification), `wfl audit:check [--gate]`, `wfl audit:fixed`, `wfl audit:profile`
> (model and effort per role: `thorough|balanced|economy`, AGENTS.md §8); `wfl audit:sign`
> belongs to the maintainer alone. **Diagnostics / agent helpers:** `wfl coverage:gaps <comp>` (files under 95% +
> uncovered count), `wfl xref <Symbol> [--tests]` (fixed-string symbol search, vendor-excluded,
> sanity-checked), `wfl changed` (dirty submodules — commit prep), `wfl sync:status [--fetch]`
> (read-only branch/ahead/behind/gitlink report), `wfl ci:check` (CI, Dependabot and toolchain drift
> against `component-template`), `wfl rulesets:check`, `wfl boot-smoke <app>` (kernel boots without
> HTTP), `wfl wf-report <file>` (digest a workflow/agent JSON output). **Strictness & supply chain:**
> `wfl coverage:ratchet` (`.coverage-floors`: the DoD fails below a component's floor), `wfl mutation <comp>`
> (Infection, pinned in `.infection-version`; MSI vs `.mutation-floors`), `wfl sbom`, `wfl images:pin`,
> `wfl offline warm|check` (installs with the network off), `wfl local-only`, `wfl backup`
> (+ `backup:schedule`), `wfl ai:settings` (merge the hardened settings; the person runs it),
> `wfl ai:telemetry`. Run `wfl help` for the full surface.
>
> 🔌 **MCP:** postgres · mongo · redis · github, each through a pinned launcher in `scripts/mcp/`
> (`.mcp.json`, enabled by `.claude/settings.json`). GitHub and Mongo are read-only; database writes
> ask first. `wfl mcp:check` opens a real session with each one. See **[`/MCP.md`](./MCP.md)**.
>
> 🧩 **Plugins:** the repository marketplace (`.claude-plugin/marketplace.json`) loads `waffle-cockpit`
> (a mod: lines under the prompt — model, effort, context, cache, cost, limits, repo, PR, Waffle
> phase, local-only commits + backup age, background shells / monitors / subagents — plus `/dod <comp>`
> in a pane with no model turn, the `mcp__waffle-cockpit__dod|xref|coverage_gaps|dod_history` tools,
> a Bash guard, Edit/Write checks for new `mixed` and secrets, an instant Mago check after each PHP edit
> and a done-means-evidence reminder before a turn ends)
> and `mattpocock-skills` (vendored, pinned; `/mattpocock-skills:<name>`) once the folder is trusted.
>
> 🔒 **Git & release safety:** agents edit files; the human commits, pushes, tags, merges and releases —
> each only on an explicit request for that operation. See **`AGENTS.md` §6**.
>
> 🤖 **Skills & subagents:** `.claude/skills/` and `.claude/agents/`, Claude Code frontmatter only
> (`AGENTS.md` §8). An agent without a `name:` is never registered; `wfl ai:check` catches it.

## 🧭 Before planning or editing

1. **`AGENTS.md`** is already in context through the import above, and it is binding.
2. **Load the matching skill** (Claude Code lists them with their triggers). When unsure, `tech-lead`.
3. **`project_system/`** — the source of truth for project **direction**: `RFCs/` (RFC-001…024) and
   `Roadmaps/` (`Roadmap_Alpha5 → Roadmap_v1_Gold` and `Roadmap_Post_v1`, plus `Roadmap_v1_Master`). Consult it before
   planning roadmap work; see the `roadmap-steward` skill.
4. **The release phase** — beta7 build (shipped) → beta8 freeze (current) → RC1 certification. What each phase allows is in
   `AGENTS.md` §5b; `tech-lead` routes by phase.

Hard invariants: components depend **only** on `waffle-commons/contracts` (plus `waffle-commons/utils`,
which itself requires only contracts); zero Mago baselines and zero non-empty Mago output; stateless
and resettable across requests (`wfl igor` 0 KO).
