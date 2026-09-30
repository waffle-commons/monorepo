# Reference — Repository layout

> **Release:** `0.1.0-beta6`.
> **Scope:** the umbrella's directory tree.

## Top-level directories

| Path | Type | Tracked? | Purpose |
| :--- | :--- | :--- | :--- |
| `.github/` | dir | yes | Umbrella GitHub config (issue/PR templates, `workflows/umbrella-ci.yml`, `workflows/release-wave.yml`). |
| `.github-private/` | submodule | yes | Private org config (mirror, not always present). |
| `.opencode/` | dir | yes | OpenCode IDE config + `skills/` AI prompt library. |
| `build/` | dir | gitignored | Output of `zip-project.sh` (audit archives, dated). |
| `async/`, `auth/`, `cache/`, `config/`, `console/`, `container/`, `contracts/`, `data/`, `error-handler/`, `event-dispatcher/`, `http/`, `http-client/`, `log/`, `pipeline/`, `routing/`, `runtime/`, `security/`, `telemetry/`, `telemetry-otel/`, `utils/`, `waffle/` | submodules | yes | The 21 framework components. Each is its own Git repo released on Packagist. |
| `queue/`, `openapi/`, `serializer/`, `testing/` | submodules | yes | The four beta7 components (scaffolded at the beta7 kickoff; code lands during the release). |
| `component-template/` | submodule | yes | Scaffold for new components (`configure-component.sh`); its CI workflow is the canonical copy every component carries. |
| `docs/` | dir | yes | Monorepo contributor documentation (this Diátaxis tree). |
| `documentation/` | submodule | yes | Framework user documentation (separate Diátaxis tree). |
| `graphify-out/` | dir | gitignored | Project Graphify generated graph artifacts. |
| `project_system/` | dir | partly tracked | **Official project governance & roadmap.** Tracked & shared: `RFCs/`, `Roadmaps/`, `Logs/Releases/`, `Logs/Retrospectives/`. Gitignored (maintainers' private): `Audits/`, `Notes/`, `TODOs/`, `*.pem`. See the [project-system reference](project-system.md). |
| `scripts/` | dir | yes | The scripts behind `wfl` (gates, reports, drift checks), the git hook installer (`install-git-hooks.sh`) with its payloads in `scripts/hooks/`, and the MCP launchers in `scripts/mcp/`. |
| `skeleton/` | submodule | yes | `composer create-project` template (FrankenPHP + Docker + sample). |
| `tmp/` | dir | gitignored | Local scratch space. |
| `workspace/` | submodule | yes | Contributor dev environment: Docker, path repos, integration tests. |
| `academy/` | submodule | yes | Hands-on onboarding — a nested monorepo of `obsidian/` (50 lessons across 5 levels), `labs/` (50 TDD exercises + answer keys), and `sandbox/` (a FrankenPHP worker app). |

## Top-level files

| File | Purpose |
| :--- | :--- |
| `README.md` | Repo landing page. |
| `CLAUDE.md` | Project conventions for human + AI contributors. See [claude-md reference](claude-md.md). |
| `CODEOWNERS` | GitHub review routing. See [codeowners reference](codeowners.md). |
| `LICENSE` | MIT. |
| `component-ruleset.json` | Canonical GitHub branch-protection ruleset shipped with this repo. See [component-ruleset reference](component-ruleset.md). |
| `opencode.json` | OpenCode IDE / project configuration. |
| `loop.sh` | Fan a command across every component. See [Run checks across components](../how-to/run-checks-across-components.md). |
| `coverage.sh` | Read coverage HTML reports, enforce ≥95%. See [Check coverage across components](../how-to/check-coverage-across-components.md). |
| `zip-project.sh` | Package the umbrella as a date-stamped zip in `build/`. |
| `bin/wfl` | Host-side developer CLI wrapping docker / mago / phpunit. |
| `scripts/install-git-hooks.sh` | Install pre-commit Mago + pre-push sanity hooks (and Project Graphify hooks) in every submodule. See [Install Git hooks](../how-to/install-git-hooks.md). |
| `scripts/hooks/pre-commit-mago.sh` | Incremental Mago gate fired by `git commit`; targets only staged PHP files. |
| `scripts/hooks/pre-push-sanity.sh` | Full `composer mago` + `composer tests` gate fired by `git push` when the ref is ahead of remote. |
| `scripts/mcp/*.sh` | Pinned launchers for the MCP servers (postgres, mongo, redis, github, filesystem), shared by Claude Code, opencode and AntigravityCLI. See [`MCP.md`](../../MCP.md). |
| `.igor-version` | The single igor-php auditor version, read by `igor.sh`, `wfl dod` and `wfl ci:check`. |
| `keystore.jks` | Java keystore used by signing tooling (rare; see your team's release docs). |
| `TODO.md` | Working notes. Not authoritative. |
| `.gitmodules` | The canonical list of submodule paths + remote URLs (one entry per submodule, including `academy`); `scripts/list-components.sh` parses it. |

## Per-submodule layout

Every framework component follows the same shape. Take `security` as the example:

```
security/
├── README.md            ← short component overview + release highlights
├── CHANGELOG.md         ← per-component Keep-a-Changelog (Beta-2 wave)
├── LICENSE.md           ← MIT
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── SECURITY.md
├── composer.json        ← Packagist manifest, "require waffle-commons/contracts"
├── mago.toml            ← Mago config: formatter / linter / analyzer / guard rules
├── igor.json            ← Igor-PHP memory-neutrality config (resident-state components only)
├── phpunit.xml          ← PHPUnit 12 config
├── src/                 ← production code
├── tests/               ← PHPUnit test suite
├── vendor/              ← gitignored
└── var/                 ← gitignored
    └── data/
        └── phpunit-coverage/
            └── index.html  ← coverage report (read by coverage.sh)
```

The framework-side `composer.json` of every component declares **at most**:

- the PSR interface packages it implements (`psr/http-server-middleware`, `psr/log`, …);
- `waffle-commons/contracts: self.version`;
- and, very rarely, a sibling component via a path repository (`utils-local` for cross-package helpers — `utils` is the only sibling commonly path-repo'd because it's a pure-function helper package, e.g. the stateless `Assert` validation & cleansing layer the `skeleton`/`workspace` demos consume).

If a `composer.json` requires a concrete waffle-commons sibling outside `contracts`/`utils`, that is a [Component Agnosticism rule](../explanation/component-agnosticism.md) violation and `mago guard` will fail.

## Related

- [Why a monorepo of submodules?](../explanation/why-monorepo-of-submodules.md) — why this shape.
- [Docker environment](docker-environment.md) — how the dev container mounts this tree.
- [The Component Agnosticism rule](../explanation/component-agnosticism.md) — what `mago guard` enforces.
