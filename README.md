<p align="center">
  <img src="https://github.com/waffle-commons/.github/blob/main/assets/logo.png" alt="Waffle Ecosystem Logo">
</p>

<h1 align="center">Waffle Commons — Monorepo</h1>

<p align="center"><strong>Strict, Secure, Fast.</strong> The umbrella repository for the Waffle Framework — a PHP 8.5 ecosystem of independent, PSR-compliant components tuned for FrankenPHP resident-worker mode.</p>

<p align="center">
  <a href="https://php.net/"><img src="https://img.shields.io/badge/php-8.5%2B-blue.svg" alt="PHP 8.5+"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="docs/"><img src="https://img.shields.io/badge/contributor%20docs-/docs-orange" alt="Contributor docs"></a>
  <a href="documentation/"><img src="https://img.shields.io/badge/framework%20docs-/documentation-orange" alt="Framework docs"></a>
</p>

---

> **Release:** `0.1.0-beta3` &nbsp;|&nbsp; [`CHANGELOG.md`](CHANGELOG.md)
> **Status:** beta software — production use requires an independent security audit.

## 🧠 Mission

Waffle exists to prove that PHP can ship a framework which is simultaneously:

- **Strict** — no `mixed`, no superglobals, no silent failures, no baseline files. PHP 8.5 Property Hooks, Asymmetric Visibility, typed constants, `final readonly` everywhere.
- **Secure** — fail-closed ABAC, stateless HMAC CSRF bound to a per-browser anonymous SID, SSRF allowlist on the outbound client, hardened HTTP headers by default.
- **Fast** — FrankenPHP-first; every component is stateless across requests so the resident worker can hold the assembled kernel in memory between calls.

The monorepo is the umbrella that holds 18 independent framework components, a project skeleton, a contributor workspace, a component scaffold template, the framework's user-facing documentation, and the project's official governance & roadmap ([`project_system/`](project_system/)). Each component is its own Git repository, released independently on Packagist; this umbrella is purely a development and integration convenience.

## 📦 What's inside

| Category | Component | Packagist | Purpose |
| :--- | :--- | :--- | :--- |
| **Foundation** | [`contracts`](contracts/) | `waffle-commons/contracts` | The only inter-component dependency. Interfaces, attributes, enums, typed constants, the lone concrete `RouteNotFoundException`. |
| | [`utils`](utils/) | `waffle-commons/utils` | Pure-function helpers. No I/O. |
| **Kernel & Runtime** | [`waffle`](waffle/) | `waffle-commons/waffle` | The framework facade — `AbstractKernel`, controller argument resolver, attribute dispatcher. |
| | [`runtime`](runtime/) | `waffle-commons/runtime` | `WaffleRuntime` — FrankenPHP worker loop with classic-SAPI fallback. |
| **HTTP** | [`http`](http/) | `waffle-commons/http` | PSR-7/17 implementation; `GlobalsFactory`, `ResponseEmitter`, trusted-host hardening. |
| | [`http-client`](http-client/) | `waffle-commons/http-client` | PSR-18 cURL client with SSRF protocol allowlist (HTTP/HTTPS only). |
| | [`routing`](routing/) | `waffle-commons/routing` | Attribute-driven router (`#[Route]`) with route-table cache. |
| | [`pipeline`](pipeline/) | `waffle-commons/pipeline` | PSR-15 middleware stack with stack-locking semantics. |
| **Security** | [`security`](security/) | `waffle-commons/security` | Fail-closed ABAC, `#[Voter]` / `#[PublicAccess]` attributes, stateless HMAC CSRF, `AnonymousSessionMiddleware`. |
| | [`auth`](auth/) | `waffle-commons/auth` | Universal Authentication Bridge (RFC-021): JWT, OAuth2/OIDC + PKCE, API key, Basic, `X-Wfl-Assert-User` gateway assertions — inbound and outbound, fail-closed. |
| **Data** | [`data`](data/) | `waffle-commons/data` | Universal Data & Persistence Layer (RFC-022): worker-safe PDO pool, SQR query AST + per-backend compilers, Firestore guardrails, 7 CRUD repository backends, migrations, `data:warmup`. |
| **DI & Config** | [`container`](container/) | `waffle-commons/container` | PSR-11 container with autowiring + `ResettableInterface` for worker-mode reset. |
| | [`config`](config/) | `waffle-commons/config` | Native YAML (`ext-yaml`) loader, `%env(VAR)%` interpolation, type-strict getters. |
| **Cross-cutting** | [`cache`](cache/) | `waffle-commons/cache` | PSR-6 + PSR-16, with `ArrayCache` / `FileCache` / `RedisCache` and stampede protection. |
| | [`event-dispatcher`](event-dispatcher/) | `waffle-commons/event-dispatcher` | PSR-14 dispatcher and listener provider; `#[AsEventListener]` discovery. |
| | [`log`](log/) | `waffle-commons/log` | PSR-3 `StreamLogger` (JSON) + `LogChannel` enum-style constants. |
| | [`error-handler`](error-handler/) | `waffle-commons/error-handler` | RFC 7807 JSON error renderer and PSR-15 middleware. |
| | [`console`](console/) | `waffle-commons/console` | Zero-magic CLI runtime, explicit command registration. |
| **Application** | [`skeleton`](skeleton/) | `waffle-commons/skeleton` | `composer create-project` template — FrankenPHP + Docker + sample controller. |
| | [`workspace`](workspace/) | (internal) | Contributor dev environment: Docker, path repositories, integration tests. |
| **Tooling** | [`component-template`](component-template/) | (internal) | Scaffold for a new component. Pinned tooling and CI. |
| | [`documentation`](documentation/) | (internal) | Framework user docs (Diátaxis). |

> **Component-agnosticism rule.** Components depend **only** on `waffle-commons/contracts`. Never on each other's concrete classes. This rule is enforced by `mago guard` on every PR and is the single load-bearing invariant of the ecosystem.

## 🚦 Two-tree documentation

Documentation is split by audience, deliberately.

| Audience | Tree | Contents |
| :--- | :--- | :--- |
| **You're building an app on Waffle** | [`/documentation`](documentation/) | Framework usage. Tutorials (write a controller), how-tos (secure a controller, configure routing), reference (every component's public surface), explanation (architecture, lifecycle, CSRF design). |
| **You're contributing to Waffle itself** | [`/docs`](docs/) | Monorepo usage. Tutorials (set up the workspace), how-tos (add a component, release a version), reference (`loop.sh`, Docker container, `CLAUDE.md`), explanation (why submodules, the Mago Purge Protocol). |

If you're not sure which tree to read: are you `composer require`-ing Waffle? → `/documentation`. Are you `git clone`-ing this repo? → `/docs`.

## 🗺️ Roadmap & governance

The project's **official roadmap and design record live in [`project_system/`](project_system/)** — the binding plan of record for the whole ecosystem:

| Area | Path | What it is |
| :--- | :--- | :--- |
| **Roadmap** | [`project_system/Roadmaps/`](project_system/Roadmaps/) | The official, release-by-release plan (current: [`Roadmap_Beta4.md`](project_system/Roadmaps/Roadmap_Beta4.md)). **If it isn't written here, it isn't committed direction.** |
| **RFCs** | [`project_system/RFCs/`](project_system/RFCs/) | Authoritative design specifications (`RFC-001` … `RFC-022`) — the "why & what" behind every component. |
| **Release logs** | [`project_system/Logs/Releases/`](project_system/Logs/Releases/) | What shipped in each wave (`Log_<Release>.md`). |
| **Retrospectives** | [`project_system/Logs/Retrospectives/`](project_system/Logs/Retrospectives/) | What went well / what to improve, per release. |

New work should **align with the current roadmap and the relevant RFC before it lands.** Full reference: [`docs/reference/project-system.md`](docs/reference/project-system.md).

## 🚀 Quick start — building an app on Waffle

```bash
composer create-project waffle-commons/skeleton my-app
cd my-app
docker compose up -d
curl -k https://localhost/
```

See [`documentation/tutorials/quick-start.md`](documentation/tutorials/quick-start.md) for the full walkthrough.

## 🛠️ Quick start — contributing to Waffle

```bash
git clone --recurse-submodules git@github.com:waffle-commons/monorepo.git waffle-commons
cd waffle-commons/workspace
docker compose up -d        # spins up the `waffle-dev` container
docker exec -it -w /waffle-commons waffle-dev bash
```

Then inside the container, work on any component:

```bash
docker exec -it -w /waffle-commons/security waffle-dev composer mago
docker exec -it -w /waffle-commons/security waffle-dev composer tests
```

Or fan a command out across **all** components:

```bash
./loop.sh composer mago
./coverage.sh
```

See [`docs/tutorials/setup-your-monorepo-workspace.md`](docs/tutorials/setup-your-monorepo-workspace.md) for the full setup walkthrough.

## 🏗️ Pipeline at a glance (Beta-3)

Every request through a Waffle application traverses this canonical PSR-15 middleware order:

```
ErrorHandler → TrustedHost → AnonymousSession → Authentication → Routing → CSRF → Security → SecureHeaders → Dispatcher
```

| Stage | Role |
| :--- | :--- |
| **ErrorHandler** | RFC 7807 problem-details on any thrown error. |
| **TrustedHost** | Host-header allowlist (anti-poisoning). |
| **AnonymousSession** | Mints / propagates the per-browser `WAFFLE_SID` (`_anon_sid`). |
| **Authentication** | Universal Auth Bridge — verifies credentials, publishes `_auth_identity` (fail-closed). |
| **Routing** | Resolves the route, publishes `_classname` / `_method`. |
| **CSRF** | Stateless HMAC double-submit, bound to the per-browser SID. |
| **Security** | Fail-closed ABAC (`#[Voter]` / `#[PublicAccess]`). |
| **SecureHeaders** | Hardened security headers on the response. |
| **Dispatcher** | Invokes the controller. |

Each stage is a standalone PSR-15 middleware; the order is wired by `AppKernelFactory` in the [`skeleton`](skeleton/) component. The middleware stack locks on first request (no mutation under load) and is FrankenPHP-safe.

## 🧹 Quality bar

Every component on every PR:

- `vendor/bin/mago fmt`, `vendor/bin/mago lint`, `vendor/bin/mago analyze`, `vendor/bin/mago guard` — **zero errors, zero warnings, zero notices, zero baseline files**;
- `vendor/bin/phpunit` — **≥95% coverage** on modified code (enforced by [`coverage.sh`](coverage.sh));
- Strict PHP 8.5: `declare(strict_types=1)`, no `mixed`, typed constants, Property Hooks for DTO validation, Asymmetric Visibility for safe mutation;
- All work performed inside Docker (`waffle-dev`); native PHP on the host machine is intentionally untested.

These rules are formalised in [`CLAUDE.md`](CLAUDE.md) and enforced by per-component `mago.toml` plus the `pull_request` ruleset in [`component-ruleset.json`](component-ruleset.json).

## 🧭 Repository layout

```
waffle-commons/
├── README.md              ← you are here
├── CLAUDE.md              ← project conventions / AI assistant instructions
├── LICENSE
├── CODEOWNERS             ← @waffle-commons/waffle-core
├── component-ruleset.json ← GitHub branch protection ruleset (the canonical version)
├── opencode.json          ← OpenCode IDE config
├── loop.sh             ← fan a command out across every component
├── coverage.sh      ← read PHPUnit coverage reports, enforce ≥95%
├── zip-project.sh         ← package the umbrella for distribution
├── bin/wfl                ← unified host-side developer CLI (docker / mago / phpunit wrapper)
├── scripts/               ← hook installer + hook payloads (pre-commit-mago, pre-push-sanity)
├── docs/                  ← MONOREPO contributor documentation (Diátaxis)
├── documentation/         ← FRAMEWORK user documentation (Diátaxis, submodule)
├── project_system/        ← OFFICIAL governance: RFCs, roadmaps, release logs & retrospectives
├── component-template/    ← scaffold for new components (submodule)
├── skeleton/              ← composer create-project template (submodule)
├── workspace/             ← contributor dev environment (submodule)
└── <component>/           ← one git submodule per framework component
```

A more detailed map lives at [`docs/reference/repository-layout.md`](docs/reference/repository-layout.md).

## 🤖 Working with AI assistants

The repo ships an `.opencode/skills/` directory with specialised AI prompts (`tech-lead`, `coding`, `refactoring`, `test`, `code-review`, `mago-purge`, `security-audit`, `component-scaffold`, `diataxis-doc`). When you ask an AI to perform a task that matches one of these skills, the assistant is expected to read the corresponding `SKILL.md` before acting — see [`CLAUDE.md`](CLAUDE.md#-specialized-ai-skills-routing-directive) for the routing directive. Reference covers [`docs/reference/opencode-skills.md`](docs/reference/opencode-skills.md).

## 🤝 Contributing

We welcome contributors. Start with:

1. [`docs/tutorials/setup-your-monorepo-workspace.md`](docs/tutorials/setup-your-monorepo-workspace.md) — clone, Docker, first build.
2. [`docs/tutorials/make-your-first-cross-component-change.md`](docs/tutorials/make-your-first-cross-component-change.md) — submodule mechanics in practice.
3. [`docs/how-to/`](docs/how-to/) — task-specific recipes (add a component, run checks, release).
4. [`docs/explanation/`](docs/explanation/) — the *why* behind the monorepo design.

Pull requests must:

- Target the specific submodule's repository (not this umbrella) for code changes;
- Pass `composer mago` and `composer tests` in every modified component;
- Carry at least one `@waffle-commons/waffle-core` review approval;
- Include relevant Diátaxis doc updates (in `/documentation` for framework changes, `/docs` for monorepo changes).

***

> [![Discord](https://img.shields.io/discord/755288001592033391?color=7289da&label=discord&logo=discord&style=for-the-badge)](https://discord.gg/eKgywnfXr2)<br />
> *Join the core team and contributors on Discord to shape the future of cloud-native PHP.*

***

## 📄 License

MIT — see [LICENSE](LICENSE).
