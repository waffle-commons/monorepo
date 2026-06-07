# Changelog — Waffle Commons (monorepo)

All notable changes to the Waffle ecosystem are documented in this file. Components
are released in **lockstep**: a single umbrella tag fans out the same version to every
submodule (see `docs/reference/workflows/release-wave.md`).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-beta3] — 2026-06-07

**Theme: identity federation & stateless persistence (RFC-021 / RFC-022).**

Two new components join the ecosystem — `auth` (the Universal Authentication
Bridge) and `data` (the Universal Data & Persistence Layer) — alongside the
Igor-PHP memory-leak audit tooling, OPcache warmup, the persistence makers, and
a reset-chain hardening pass across the resident-worker surface.

### Added
- **`auth` (NEW component)** — Universal Authentication Bridge (RFC-021): four
  inbound schemes (`X-Wfl-Assert-User` gateway assertions, Bearer JWT
  RS256/HS256, API key, HTTP Basic), stateless OAuth2/OIDC with PKCE (S256),
  five outbound credential providers behind a PSR-18 decorator, constant-time
  HMAC verification with IP binding and a 5-second assertion window, and
  fail-closed boot on a missing/short `WAFFLE_AUTH_SECRET`.
  See [`auth/CHANGELOG.md`](auth/CHANGELOG.md).
- **`data` (NEW component)** — Universal Data & Persistence Layer (RFC-022):
  worker-safe `PDOConnectionPool` (ping-before-dispense, transaction rollback on
  reset), the SQR query AST with compilers for every SQL dialect
  (MySQL/MariaDB/SQLite/MSSQL/PostgreSQL/Oracle) plus Firestore, MongoDB,
  Cassandra, key-value and GraphQL backends, the three Firestore guardrails
  (strict paths, in-memory evaluation, auth gate), full CRUD on all seven
  repository backends, property-hook hydration, the migrations runner and the
  `data:warmup` artifact engine. See [`data/CHANGELOG.md`](data/CHANGELOG.md).
- **`contracts`** — the RFC-021/022 surface: assertion signer/verifier
  contracts, SQR enums + predicate/repository interfaces, data exception
  markers, `Data\Warmup\DataWarmerInterface`, `Runtime\AuditRunnerInterface`
  and `Core\TerminableInterface`. See [`contracts/CHANGELOG.md`](contracts/CHANGELOG.md).
- **`console`** — `igor:audit` (monorepo memory-leak audit through `runtime`'s
  `ProcessAuditRunner`), `data:warmup` (OPcache pre-compilation of SQR trees)
  and the `make:entity` / `make:repository` persistence makers (RFC-020).
  See [`console/CHANGELOG.md`](console/CHANGELOG.md).
- **Igor-PHP audit tooling** — the root `igor.sh` dynamic scanner (+
  `scripts/igor.sh` shim), per-component `igor.json` configuration across all
  15 stateful packages (now including `event-dispatcher`), and the
  `composer igor` script convention.

### Changed
- **`security`** — authentication concerns decoupled into `auth` (RFC-021);
  the component keeps ABAC voters, `#[PublicAccess]`, the stateless HMAC CSRF
  manager and `SecureContainer` (which now forwards `reset()`). The upgrade
  path is documented in [`security/CHANGELOG.md`](security/CHANGELOG.md).
- **Reset-chain hardening** — `cache`'s `ArrayCache` + `CachePool` implement
  `ResettableInterface` (store cleared, deferred writes flushed-then-dropped);
  `container` memoizes built instances so the reset loop reaches every
  resettable service; `security`'s `SecureContainer` forwards `reset()`;
  `waffle`'s kernel drains resettable loggers and implements
  `TerminableInterface`; `http` message internals refactored.
- **`skeleton`** — ships the UAB out of the box: `waffle-commons/auth`
  requirement, French-commented authentication wiring and demo routes
  (`POST /auth/demo-token`, `GET /api/me`), `data:warmup` CLI wiring, and the
  migration to the canonical `contracts` `Route` attribute.
- **CI/CD & tooling** — `auth` and `data` joined the release-wave
  `RELEASE_INCLUDE` allowlist and the umbrella-ci change matrix (which gained
  full `composer mago` parity: `fmt --check` + `guard`); their component
  pipelines now trigger on push/PR; `zip-project.sh`, `coverage.sh` and
  `loop.sh` cover all 18 libraries.

## [0.1.0-beta2.1] — 2026-05-30

**Patch: umbrella housekeeping.**

### Changed
- Component submodule pointers refreshed post-wave and re-tagged in lockstep —
  no component source changes; every package carries the same content as
  `0.1.0-beta2`. Discord badge added to the monorepo README.

## [0.1.0-beta2] — 2026-05-29

**Theme: HTTP correctness, developer experience, and cognitive tooling.**

The framework-component surface received a single cohesive feature in this wave —
typed `405 Method Not Allowed` + `OPTIONS` preflight auto-answer + `HEAD ⇒ GET`
fallback + deterministic `Allow` header — landed across four components in lockstep.
The remaining twelve components are pure dependency bumps. The monorepo's
**developer tooling** (`bin/wfl`, AI skills routing) and the **template apps**
(`skeleton`, `workspace`) saw the bulk of the activity.

### Added (HTTP correctness wave)
- **`contracts`** — `Waffle\Commons\Contracts\Routing\Exception\MethodNotAllowedException`
  (concrete `final` class) + `MethodNotAllowedExceptionInterface` marker, carrying the
  allowed-methods list. `Waffle\Commons\Contracts\Routing\Constant` HTTP-method string
  constants (`METHOD_GET` … `METHOD_OPTIONS`). `Waffle\Commons\Contracts\Exception\WaffleExceptionInterface`
  base marker. `Route` attribute relocated here from `routing` and gained an
  `array $methods = ['GET']` parameter for filtering and overloading; constructor
  arguments reordered so `$path` precedes `$methods`. See [`contracts/CHANGELOG.md`](contracts/CHANGELOG.md).
- **`routing`** — HTTP method filtering and route overloading (multiple actions may
  share a path provided their methods don't intersect); `HEAD ⇒ GET` fallback
  (RFC 7231 §4.3.2); method-name canonicalisation + de-duplication at discovery;
  worker-safe PCRE pattern cache; deterministic `Allow` header generation (merged,
  `HEAD`/`OPTIONS`-augmented, de-duplicated, alphabetically sorted). The old
  `Waffle\Commons\Routing\Attribute\Route` was removed — the canonical attribute now
  lives in `contracts`. See [`routing/CHANGELOG.md`](routing/CHANGELOG.md).
- **`pipeline`** — `CoreRoutingMiddleware` now accepts an optional PSR-17
  `ResponseFactoryInterface`; when wired, an `OPTIONS` request to a known path is
  answered with `204 No Content` + `Allow` header without dispatching to a
  controller. The middleware's catch block was extended to surface
  `MethodNotAllowedExceptionInterface` to `ErrorHandlerMiddleware`. See [`pipeline/CHANGELOG.md`](pipeline/CHANGELOG.md).
- **`error-handler`** — `JsonErrorRenderer::determineStatusCode()` maps
  `MethodNotAllowedExceptionInterface` to HTTP `405`; `render()` injects the
  `Allow` header from `getAllowedMethods()` when non-empty (omitted otherwise to
  avoid malformed headers). See [`error-handler/CHANGELOG.md`](error-handler/CHANGELOG.md).

### Added (tooling and ergonomics)
- **`/AGENTS.md`** — new monorepo "central brain": single source of truth for
  AI-assistant behaviour (coding standards, statelessness mandate, Mago Purge
  Protocol, skills routing table). `CLAUDE.md` slimmed to a thin CLI router that
  redirects to AGENTS.md.
- **`bin/wfl`** — host-side developer CLI grew by ~298 lines: per-component
  linking, security commands, dry-run plumbing, integration with the Graphify
  scripts.
- **`.opencode/skills/`** — three new skill prompts: `auth-bridge-audit`
  (RFC-021 HMAC perimeter), `data-persistence` (RFC-022 SQR / Firestore),
  `maker-scaffold` (RFC-020 zero-debt code generation). Existing `mago-purge`,
  `security-audit`, `diataxis-doc` prompts were rewritten for cognitive-prompt
  clarity.
- **`release-wave` workflow** — hardened with `--dry-run`, `EXCLUDE_SUBMODULES`
  controls, and improved pre-commit Mago/PHPUnit hooks.
- **Per-component `CHANGELOG.md`** — every of the sixteen framework components now
  ships a Keep-a-Changelog file (Beta-2 forward; Beta-1 anchor points back here).

### Changed (template applications)
- **`skeleton` + `workspace`** — `AppKernelFactory` decoupling (terminal handler
  trio is now registered as container closure definitions, resolved through the
  kernel's standard PSR-11 seam; no more procedural `new ControllerDispatcher(...)`).
  Native DTO validation now throws `Waffle\Exception\ValidationException` (implements
  `ValidationExceptionInterface`, triggers RFC 7807 `422`) with French error messages.
- **Language policy** — French is now mandatory in BOTH `skeleton/` AND
  `workspace/` (template applications): every comment, docblock, YAML/TOML/compose
  comment, and user-facing string in those two directories is French. English
  remains mandatory in every framework component. Documented in `AGENTS.md`.

### Dependency-only releases
- `cache`, `config`, `console`, `container`, `event-dispatcher`, `http`,
  `http-client`, `log`, `runtime`, `security`, `utils`, `waffle`: lockstep
  version bump only — no behavioural changes since Beta-1, `composer.lock`
  refreshed.

### Migration notes
- **No API breaking changes** at the framework-component PHP surface. Application
  code targeting Beta-1 compiles against Beta-2 unchanged.
- **The `Route` attribute relocated** from `Waffle\Commons\Routing\Attribute\Route`
  to `Waffle\Commons\Contracts\Routing\Attribute\Route`. Existing apps that imported
  the old namespace need to update their `use` statement. The skeleton + workspace
  templates were already updated.
- **DTO validation strings** that previously threw `InvalidArgumentException` from
  Property Hooks should switch to `Waffle\Exception\ValidationException` to surface
  as RFC 7807 `422` rather than fall through to the default `500`.
- The new `405` / `Allow` / `OPTIONS` behaviour is **opt-in** at the pipeline level:
  pass a `ResponseFactoryInterface` to `CoreRoutingMiddleware` to enable
  `OPTIONS` auto-answering. Without it, `MethodNotAllowedException` still surfaces
  as a proper `405` with `Allow` header via `JsonErrorRenderer` — only the
  preflight short-circuit requires the factory.

## [0.1.0-beta1]

**Theme: "EcoShield" remediation — worker-native security, decoupling, and outbound proxying.**

### Security (Phase 0 hotfixes)
- **`cache`** — eliminated the insecure-deserialization RCE vector (OWASP A08): `FileCache`/`RedisCache` now serialize with JSON instead of native `unserialize`. Files written `0600`, directories `0700`, atomic temp-file + rename, no `/tmp` fallback.
- **`config`** — removed all process-environment mutation (`putenv()` / `$_ENV` / `$_SERVER`). `DotEnv::load()` returns a read-only map injected into `Config`; resolves the FrankenPHP worker-mode thread-safety hazard.

### Changed (Phase 1 — architectural modernization)
- **`waffle`** — `AbstractKernel::handle()` resolves the terminal handler from the container under `RequestHandlerInterface`; the hard-coded `new ControllerDispatcher(...)` is gone (idempotent, `has()`-gated default).
- **`utils`** — `ReflectionTrait` removed and decomposed into `ClassParser`, `AttributeReader`, `ReflectionInspector` (single-responsibility `final readonly` services).
- **`container`** — `get()` short-circuits on `has()` (no control-flow-by-exception); core services locked from override after boot.

### Added (Phase 2 & 3)
- **`http-client`** — **new component.** PSR-18 client for outbound proxying: non-blocking `curl_multi` transfer, bidirectional 8 KiB streaming (request body via `CURLOPT_READFUNCTION`/`UPLOAD`, response via `CURLOPT_WRITEFUNCTION`), SEC-03 SSRF protocol allowlist, hardcoded 1s/10s timeouts.
- **`routing`** — `priority` on `#[Route]` + catch-all support; `matchRequest()` returns a typed `MatchedRoute` DTO; descending-priority sort at boot; bounded (`^…$`) match regex.
- **`waffle`** — native DTO validation: `#[Dto]` parameters hydrate from the parsed body, PHP 8.5 property hooks run their assertions, and failures surface as a unified `ValidationException` → RFC 7807 `422` (no external validation package).
- **`security`** — fail-closed ABAC (deny without `#[Voter]` unless `#[PublicAccess]`); stateless HMAC CSRF bound to a per-browser session id via `AnonymousSessionMiddleware`.
- **`pipeline`** — `SecureHeadersMiddleware` (`X-Content-Type-Options`, `X-Frame-Options`, CSP); `CoreRoutingMiddleware` raises `RouteNotFoundException` so misses render as `404` not `500`.

### Tooling / infrastructure
- Added the `release-wave` workflow (umbrella tag → per-component tags + GitHub pre-releases) and `umbrella-ci` (incremental per-component matrix with a ≥95% coverage gate).
- Added the Waffle developer CLI and Git hooks; comprehensive monorepo `docs/` (Diátaxis).

### Release hygiene
- Removed the hard-coded `version` field from every component `composer.json` so the git tag is authoritative and `self.version` cross-component constraints resolve to `0.1.0-beta1`.
- Every component `phpunit.xml` now emits a Clover report so the `umbrella-ci` coverage gate can read it.

## Prior releases

- **`0.1.0-beta0`** — "Zero-Debt" milestone: completion of the Mago Purge Protocol across all components (0 static-analysis errors, no baseline files, >95% coverage). New `cache` (PSR-6/16) and `console` components.
- **`0.1.0-alpha6`** — Contracts freeze; DTO validation groundwork (`ValidationExceptionInterface`).
- **`0.1.0-alpha5`** — Observability & integration: `log` (PSR-3 `StreamLogger`), `event-dispatcher` (PSR-14), attribute-based `security` middleware.
- **`0.1.0-alpha4`** — Security & hardening: native YAML `config`, PSR-15 `pipeline`, RFC 7807 `error-handler`.
- **`0.1.0-alpha1`–`alpha3`** — Initial scaffolding of the core, container, HTTP, and runtime components.
