# Changelog — Waffle Commons (monorepo)

All notable changes to the Waffle ecosystem are documented in this file. Components
are released in **lockstep**: a single umbrella tag fans out the same version to every
submodule (see `docs/reference/workflows/release-wave.md`).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-beta5] — 2026-06-26

**Theme: event-driven, reactive & AOT-optimized enterprise runtime (Roadmap_Beta5).**

Three new components join the ecosystem — `async` (Fiber finish-request deferral),
`telemetry` (SDK-free Prometheus metrics) and `telemetry-otel` (the OpenTelemetry
bridge) — alongside contract-first distributed tracing, ahead-of-time container
compilation, reactive write-hook broadcasting, memory-resident connection pooling,
WebAuthn/passkeys, and a Gate-0 security-hardening pass. Every addition stays inside
the "contracts + utils only" perimeter and the `wfl igor` 0-KO worker-safety gate.

### Added
- **`async` (NEW component)** — Fiber-based finish-request deferred-task runner
  (ASYNC-01 / RFC-015): `DeferredTaskRunner` implements the new contract
  `Async\TaskRunnerInterface`; tasks deferred during a request via `defer()` run
  after the response is flushed (before the worker takes its next request), each
  inside its own native `Fiber` isolation boundary so a thrown task — or a throwing
  destructor on an abandoned, still-suspended task — is caught and logged without
  aborting its siblings. A bounded per-request budget (`DEFAULT_BUDGET = 64`) raises
  `DeferralBudgetExceededException` past the limit and `InvalidBudgetException` for a
  budget below 1. The pending queue is the only state, so the runner implements
  `ResettableInterface` directly. See [`async/CHANGELOG.md`](async/CHANGELOG.md).
- **`telemetry` (NEW component)** — SDK-free worker metrics + Prometheus exposition
  (OBS-02 / RFC-005): a `MetricsRegistry` (counters / gauges / histograms) backed by
  an `ApcuMetricStore` that keeps all metric state in APCu shared memory rather than
  the resettable worker heap (falling back to the contract `NullMetricsRegistry` when
  APCu is absent); stateless `Memory` / `Gc` / `PoolUtilization` collectors; a
  `PrometheusExporter`; and a fail-closed `MetricsMiddleware` serving `/waffle-metrics`
  — 404 unless a bearer token or allow-listed client IP matches. Adds a
  `TracingMiddleware` (per-request server span, inbound W3C `traceparent` extraction)
  and `MeteredCache` / `TracingRepositoryDecorator` decorators, all defaulting to the
  contract no-ops so they install unconditionally. See [`telemetry/CHANGELOG.md`](telemetry/CHANGELOG.md).
- **`telemetry-otel` (NEW component)** — OpenTelemetry SDK bridge (OBS-01 / RFC-005):
  `OtelTracer` / `OtelSpan` / `OtelSpanContext` adapt the OpenTelemetry PHP SDK to the
  contract-first `Telemetry\TracerInterface` / `SpanInterface` / `SpanContextInterface`,
  with a `W3CTraceContextPropagator` injecting/extracting `traceparent` + `tracestate`
  for cross-service distributed tracing and an `OtelTracerFactory` that isolates every
  `OpenTelemetry\SDK\*` symbol here. It is the **only** Waffle package permitted to
  require `open-telemetry/*` — `mago guard` allows the SDK in this adapter and nowhere
  else, keeping the SDK out of core. See [`telemetry-otel/CHANGELOG.md`](telemetry-otel/CHANGELOG.md).
- **`contracts`** — the Beta-5 surface: the `Async`, `Reactive` (`#[Broadcast]`,
  `MutationRecord`, buffer/transport markers), `Telemetry` (tracer + metrics
  interfaces, enums, and no-op defaults — `NullTracer` / `NullSpan` /
  `NullMetricsRegistry`), WebAuthn (`WebAuthnVerifierInterface` and friends),
  `Container\CompiledContainerInterface`, generalized connection-pool interfaces
  (relational + Redis), and the concurrent HTTP-client `PromiseInterface`.
  `Security\VoterInterface::decide()` now takes a `SecurityContextInterface` and an
  optional `$subject`. See [`contracts/CHANGELOG.md`](contracts/CHANGELOG.md).
- **AOT compilation (AXE 1 / RFC-019)** — `console`'s `ContainerCompiler` +
  `container:compile` command emit a graph-identical compiled container; `routing`
  gains a `RouteTrie` for reflection-free route resolution; `waffle`'s
  `CompiledContainerLoader` takes the fast path only when `WAFFLE_AOT=1` and a
  compiled artifact exists, falling back to reflection otherwise. See
  [`console/CHANGELOG.md`](console/CHANGELOG.md), [`routing/CHANGELOG.md`](routing/CHANGELOG.md)
  and [`waffle/CHANGELOG.md`](waffle/CHANGELOG.md).
- **Reactive broadcasting (AXE 3 / RFC-018)** — `waffle` adds the `#[Broadcast]`
  write-hook path: a request-scoped `RequestBroadcastBuffer` accumulates mutations
  (no I/O in the hook) and a `BroadcastFlushListener` flushes them over the
  `SseBroadcastTransport` at finish-request. See [`waffle/CHANGELOG.md`](waffle/CHANGELOG.md).
- **Connection pooling (AXE 4)** — `data` adds a memory-resident `RedisConnectionPool`
  (alongside the hardened `PDOConnectionPool`) and a `TransactionIsolationMiddleware`
  that pins a request to a single pooled connection for transaction affinity, against
  the generalized contract pool interfaces. See [`data/CHANGELOG.md`](data/CHANGELOG.md).
- **WebAuthn / passkeys (AXE 6 / AUTH-01)** — `auth` ships registration and
  authentication ceremonies behind the new contract `WebAuthnVerifierInterface`, with
  the `webauthn-lib` import isolated to a single stateless adapter (app-provided
  challenge store, fail-closed). See [`auth/CHANGELOG.md`](auth/CHANGELOG.md).
- **Native DB tracing (OBS-01)** — every `data` repository emits `waffle.db.query`
  spans through the contract `TracerInterface`, defaulting to the no-op tracer so
  tracing is zero-cost until the OTel bridge is wired. `http-client`, `routing`,
  `security` and `waffle` likewise thread spans through their hot paths. See
  [`data/CHANGELOG.md`](data/CHANGELOG.md).
- **Concurrent HTTP client (AXE 2)** — `http-client` adds promise-based fan-out
  (`ConcurrentClientInterface` / `PromiseInterface`) for parallel outbound requests
  over the existing non-blocking `curl_multi` core. See [`http-client/CHANGELOG.md`](http-client/CHANGELOG.md).

### Changed
- **Context-aware ABAC (AUTHZ-01)** — voters now receive a request-scoped
  `SecurityContext` (authenticated identity, roles, client IP) via DI, so ownership /
  IDOR rules can be expressed; `security`'s `SecureContainer` resolves request-aware
  voters and forwards the context. The previous parameter-less `decide()` is replaced
  by `decide(SecurityContextInterface $ctx, mixed $subject = null)`. See
  [`security/CHANGELOG.md`](security/CHANGELOG.md).
- **Kernel constructor injection (ARCH-03)** — `AbstractKernel` now requires all
  collaborators through its constructor (no `set*()` setters / `validateState()`); the
  event dispatcher remains a boot-time `#[WorkerSafe]` setter. See
  [`waffle/CHANGELOG.md`](waffle/CHANGELOG.md).
- **`: never` return types (MODERN-02)** — fail-only helpers across `waffle`, `http`,
  `data` and `telemetry` adopt the `never` return type for always-throwing paths.
- **Cyclomatic-complexity lint (CPLX-04)** — the `cyclomatic-complexity` linter is
  enabled repo-wide with a `threshold = 50` ratchet across every component `mago.toml`.

### Security
- **AXE 0 Gate-0 hardening** — `error-handler` masks 4xx client-error detail by default
  so a `403`/`404` cannot leak controller FQCN/method in production (LEAK-03);
  `http`'s stream-backed `UploadedFile` keeps content in `php://temp` and never writes
  to the shared system temp dir, honouring the statelessness mandate (STATE-02); `data`
  applies a NUL/control-character identifier allow-list alongside quote-escaping on
  every SQL identifier (HARDEN-03); `config` and others drop the last analyzer
  suppressions natively rather than via baseline (POLICY-05).

### Dependencies
- **CI** — `umbrella-ci` runs `composer audit` per component as a dependency-vulnerability
  gate (DEP-04); `async`, `telemetry` and `telemetry-otel` join the `release-wave`
  `RELEASE_INCLUDE` allowlist and the change matrix.
- `telemetry-otel` requires `open-telemetry/*`; `auth` requires `web-auth/webauthn-lib`
  — each isolated to a single adapter and permitted by `mago guard` only there.

## [0.1.0-beta4] — 2026-06-13

**Theme: security hardening & worker-mode stability — RC-readiness groundwork (Roadmap_Beta4).**

### Added
- **Core security (AXE 1):** session-fixation rotation + cryptographic CSRF binding (SEC-01); **default-on** SSRF resolve→validate→pin with IPv6 resolution + internal allowlist (SEC-02); the `security:compare-audit` / `wfl compare-audit` timing-safety gate (SEC-03); fail-closed CORS (SEC-04); path-traversal guards on file transfers (SEC-05).
- **Worker-mode diagnostics (AXE 3):** a dev-only boot-time state-reset compliance scanner (DIAG-02) and an orphaned-connection tracer for PDO/Redis/streams (DIAG-03).
- **Developer experience (AXE 4):** `wfl check:all` + `wfl monorepo:sync`, native `mb_trim()` migration (DX-04), and an injectable, mockable `ValidatorInterface` (DX-05).
- **Academy:** the Waffle Academy onboarding monorepo — 5 levels × 10 lessons (50 Obsidian lessons), 50 executable-spec TDD labs with an answer-key tree (`wfl academy:solve` / `academy:reset` / `academy:verify`), and a FrankenPHP `sandbox` worker app — held to the same `mago` + `guard --perimeter` + PHPUnit bar and `wfl igor` 0-KO gate. Driven via `wfl academy:test` / `academy:serve`.

### Changed
- **Architecture & stability (AXE 2):** typed kernel lifecycle events (ARCH-04), interface-based response conversion (ARCH-05), a standalone uploaded-files normalizer (ARCH-06), and stream-resource ownership (STB-01). STB-02 buffer pooling stays deferred behind its benchmark gate.
- Ecosystem-wide worker-safety migration to igor-php 0.7 (`#[WorkerSafe]`); `wfl igor` remains a 0-KO definition-of-done gate.
- **Perimeter hardening:** `runtime` now depends only on `contracts` (new `Http\GlobalsFactoryInterface`; `http` concretes injected at the app layer), restoring the "contracts + utils only" invariant across every framework component. The full DX-04 `mb_trim()` sweep was completed across the remaining framework `src/` (config, utils, runtime, http-client, data, console).

### Notes
- The Beta-4 surface — framework, tooling, and the `academy` (lessons, labs, and sandbox) — is release-ready. STB-02 buffer pooling is the sole deferred item, held behind its benchmark gate.

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
