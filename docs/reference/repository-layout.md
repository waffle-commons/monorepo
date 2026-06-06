# Reference — Repository layout

> **Release:** `v0.1.0-beta2`.
> **Scope:** the umbrella's directory tree.

## Top-level directories

| Path | Type | Tracked? | Purpose |
| :--- | :--- | :--- | :--- |
| `.github/` | dir | yes | Umbrella GitHub config (issue/PR templates, `workflows/umbrella-ci.yml`, `workflows/release-wave.yml`). |
| `.github-private/` | submodule | yes | Private org config (mirror, not always present). |
| `.opencode/` | dir | yes | OpenCode IDE config + `skills/` AI prompt library. |
| `build/` | dir | gitignored | Output of `zip-project.sh` (audit archives, dated). |
| `auth/`, `cache/`, `config/`, `console/`, `container/`, `contracts/`, `data/`, `error-handler/`, `event-dispatcher/`, `http/`, `http-client/`, `log/`, `pipeline/`, `routing/`, `runtime/`, `security/`, `utils/`, `waffle/` | submodules | yes | The 18 framework components. Each is its own Git repo released on Packagist. |
| `component-template/` | submodule | yes | Scaffold for new components. Used via `configure-component.sh`. |
| `docs/` | dir | yes | Monorepo contributor documentation (this Diátaxis tree). |
| `documentation/` | submodule | yes | Framework user documentation (separate Diátaxis tree). |
| `graphify-out/` | dir | gitignored | Project Graphify generated graph artifacts. |
| `project_system/` | dir | gitignored | Working area for in-progress system-level artifacts. |
| `scripts/` | dir | yes | Git hook installer (`install-git-hooks.sh`) plus hook payloads in `scripts/hooks/` (`pre-commit-mago.sh`, `pre-push-sanity.sh`). |
| `skeleton/` | submodule | yes | `composer create-project` template (FrankenPHP + Docker + sample). |
| `tmp/` | dir | gitignored | Local scratch space. |
| `workspace/` | submodule | yes | Contributor dev environment: Docker, path repos, integration tests. |

## Top-level files

| File | Purpose |
| :--- | :--- |
| `README.md` | Repo landing page. |
| `CLAUDE.md` | Project conventions for human + AI contributors. See [claude-md reference](claude-md.md). |
| `CODEOWNERS` | GitHub review routing. See [codeowners reference](codeowners.md). |
| `LICENSE` | MIT. |
| `component-ruleset.json` | Canonical GitHub branch-protection ruleset shipped with this repo. See [component-ruleset reference](component-ruleset.md). |
| `opencode.json` | OpenCode IDE / project configuration. |
| `loop.sh` | Fan a command across every component. See [scripts/run-all reference](scripts/run-all.md). |
| `coverage.sh` | Read coverage HTML reports, enforce ≥95%. See [scripts/check-coverage reference](scripts/check-coverage.md). |
| `zip-project.sh` | Package the umbrella as a date-stamped zip in `build/`. See [scripts/zip-project reference](scripts/zip-project.md). |
| `bin/wfl` | Host-side developer CLI wrapping docker / mago / phpunit. See [scripts/wfl reference](scripts/wfl.md). |
| `scripts/install-git-hooks.sh` | Install pre-commit Mago + pre-push sanity hooks (and Project Graphify hooks) in every submodule. See [scripts/install-git-hooks reference](scripts/install-git-hooks.md). |
| `scripts/hooks/pre-commit-mago.sh` | Incremental Mago gate fired by `git commit`; targets only staged PHP files. |
| `scripts/hooks/pre-push-sanity.sh` | Full `composer mago` + `composer tests` gate fired by `git push` when the ref is ahead of remote. |
| `keystore.jks` | Java keystore used by signing tooling (rare; see your team's release docs). |
| `TODO.md` | Working notes. Not authoritative. |
| `.gitmodules` | The canonical list of submodule paths + remote URLs. 22 entries. |

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
