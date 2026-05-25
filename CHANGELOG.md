# Changelog — Waffle Commons (monorepo)

All notable changes to the Waffle ecosystem are documented in this file. Components
are released in **lockstep**: a single umbrella tag fans out the same version to every
submodule (see `docs/reference/workflows/release-wave.md`).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — targeting `0.1.0-beta1`

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
