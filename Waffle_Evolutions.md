---
title: "Waffle Evolutions — Is waffle-commons the Future of PHP?"
type: article
author: Leslie Petrimaux
date: 2026-05-29
date_updated: 2026-10-31
status: beta
tags:
  - php
  - architecture
  - monorepo
  - static-analysis
  - frankenphp
  - ai-tooling
---

# Waffle Evolutions — Is `waffle-commons` the Future of PHP?

> **Scope.** A deep, evidence-based analysis of the `waffle-commons` monorepo (release `0.1.0-beta7`, November 2026; refreshed on the pre-release tree on 31 October 2026, ahead of the tag) against the question: *does this project represent the future of PHP?* — accepting the deliberate constraint that Waffle does **not** aim to replace Symfony or Laravel. **Method.** Direct reading of `AGENTS.md`, `CLAUDE.md`, both Diátaxis trees (`/docs` for contributors, `/documentation` for framework users), the 24 RFCs in `project_system/RFCs/`, the release roadmaps and logs in `project_system/`, the canonical middleware order in `AppKernelFactory`, the benchmark rig in `bench/`, and the live source of the load-bearing components (`AbstractKernel`, `WaffleRuntime`, `CsrfTokenManager`, `Router`, `MiddlewareStack`, `Client`, and the Beta-5 additions: `ContainerCompiler`/`RouteTrie` for AOT, `DeferredTaskRunner` for async, the PDO/Redis connection pools, and the contract-first `TracerInterface`). For Beta-6 and Beta-7 the refresh also relies on the evidence each roadmap item records: tests, command output and archived runs (Appendix B).
>
> **Author position.** None — this document audits Waffle on its own terms, not Symfony's or Laravel's.

***

## TL;DR

`waffle-commons` is **not** "the future of PHP" if that phrase is read as *"the framework most PHP applications will run on in five years."* Symfony and  Laravel will continue to define mainstream PHP for the simple reason that they  own the ecosystems — the ORMs, the queue layers, the admin generators, the  mailers, the community. Waffle ships none of that, and the maintainers say so: the README opens with *"Strict, Secure, Fast"*, not *"replace your framework"*.

What Waffle *is* — and this is the load-bearing claim of this document — is **a working proof of five evolutions that PHP, as a language and as a runtime,  is currently undergoing**. Each evolution is real, each is happening  independently of Waffle, and each is something that Symfony and Laravel are  slower to adopt natively because they cannot afford to break their installed  base. Waffle ships these evolutions today, in 25 framework packages released in lockstep on Packagist (the four newest, `queue`, `openapi`, `serializer` and `testing`, publish their first version with the Beta-7 wave), with `composer mago && composer tests` green at every commit and `wfl igor` worker-safety at 0 KO:

1. **PHP 8.5 as a strict, hookable, ergonomically-typed language** — Property  Hooks replacing external validators; Asymmetric Visibility replacing  getter/setter ceremony; typed constants replacing string-keyed magic; `final readonly` replacing builder-pattern DTOs.
2. **FrankenPHP resident-worker as the default deploy target** — no `$_SESSION`, no `session_start()`, no static singletons, no `sys_get_temp_dir()`, no per-request boot. The kernel boots once and stays  in memory; statelessness is enforced architecturally, not by convention.
3. **Zero-Debt static analysis as a baseline expectation** — the *Mago Purge  Protocol*: zero errors, zero warnings, zero notices, zero hints, zero  baseline files. Twin-ruled by ≥95% PHPUnit coverage. This is the kind of  discipline the Rust and Haskell ecosystems take for granted, ported to PHP  without compromise.
4. **AI-cognitive tooling as a first-class repository artifact** — `AGENTS.md`, `CLAUDE.md`, `.claude/skills/` and `.claude/agents/` are committed code, not adjunct knowledge. The 34 named skills (`tech-lead`, `coding`, `mago-purge`, `security-audit`, `resilience-net`, `queue-worker`, `k8s-ops`, `api-freeze`, `soak-endurance`, …) and 18 subagents encode operating procedures that override generic AI defaults at the project boundary, and a project plugin enforces part of them at the tool boundary: it refuses a release-tag push the maintainer has not authorized, flags a new `mixed` as it is written, and runs Mago after every PHP edit.
5. **Component Agnosticism as a mechanical invariant** — every component  depends only on `waffle-commons/contracts`. Enforced by `mago guard`,  refused by CI. The result is 25 components, each individually composable  into someone else's framework, with no hidden coupling between them.

These five evolutions are the **Waffle thesis**. The Beta-5 wave (July 2026) is where the thesis stops being mostly about *correctness* and starts being about *runtime maturity*: it transitions Waffle from a high-performance HTTP runner toward an **event-driven, reactive, AOT-optimized application runtime** — shipping Ahead-of-Time compilation, Fiber finish-request task deferral, reactive `#[Broadcast]` write-hooks, memory-resident connection pooling, contract-first telemetry, and native WebAuthn passkeys, all under the same statelessness and Zero-Debt mandates. Beta-6 (September 2026) stopped to harden: independent multi-engine security audits of every component, a full documentation pass, and the first reproducible benchmark. Beta-7 (November 2026) closes the gap between a fast framework and a production API ecosystem: background jobs, a generated OpenAPI 3.1 description, compiled DTO serialization, an in-process testing bridge, rate limiting, outbound timeouts, retries and circuit breaking, orchestrator probes, a graceful drain and reversible migrations. What stands between it and 1.0 is mostly consolidation and certification: the beta8 API freeze, then a release candidate that must hold a production-like soak of at least four weeks. Whether you adopt Waffle or not, the language and the runtime are moving in this direction; Symfony and  Laravel will continue to adapt; Waffle is simply the place where each evolution is already executed without compromise. In that narrow sense — Waffle as *evolutionary pressure*, not as displacement — yes, it is *a* future of PHP.

The rest of this document defends that claim with the evidence.

***

## 1. What Waffle Actually Is (the inventory, without marketing)

### 1.1 The umbrella shape

The `waffle-commons` monorepo is an umbrella Git repository containing **30 submodules**: 25 framework components, a `skeleton` (app template), a `workspace` (live FrankenPHP dev app), an `academy` (itself a nested monorepo of three submodules — `obsidian` lessons, `labs` TDD exercises, and a `sandbox` worker app), a `component-template` (scaffold for new  components), and a `documentation` tree (framework user docs). Each submodule is its own independent Git repository, released  independently to Packagist on a coordinated release-wave cadence. The umbrella's own purpose is to pin each at a specific SHA and ship cross-component tooling (`bin/wfl`, `igor.sh`, `scripts/install-git-hooks.sh`, `.claude/`, `.github/workflows/`, the `bench/` rig); its `project_system/` holds the project's direction: the RFCs, the per-release roadmaps, and the release logs and retrospectives.

This shape is deliberate and documented in [`docs/explanation/why-monorepo-of-submodules.md`](docs/explanation/why-monorepo-of-submodules.md): true monorepos cannot publish to Packagist (no subpath publication); pure  poly-repos lose the coordinated "what versions go together" state. The  umbrella-with-submodules pattern keeps both Packagist independence and ecosystem  coherence.

### 1.2 The 25 framework components

| Layer        | Component(s)                                                   | Purpose                                                                                                                          |
|--------------|--------------------------------------------------------------- |----------------------------------------------------------------------------------------------------------------------------------|
| Foundation   | `contracts`, `utils`                                           | The only common-import packages. `contracts` ships interfaces + attributes + enums + typed constants; `utils` ships pure helpers.|
| Kernel       | `waffle`, `runtime`                                            | `AbstractKernel` + `WaffleRuntime` (FrankenPHP worker loop with classic-SAPI fallback).                                          |
| HTTP         | `http`, `http-client`, `routing`, `pipeline`                   | PSR-7/17/18, attribute-driven router with priority + catch-all, PSR-15 stack with lock-on-build semantics. **(Beta-7)** The client gains mandatory timeouts, bounded idempotency-aware retries and a circuit breaker (RFC-024); `pipeline` serves the `/healthz` and `/readyz` orchestrator probes (RFC-023).                       |
| Security     | `security`                                                     | Fail-closed ABAC, `#[Voter]` / `#[PublicAccess]` attributes, stateless HMAC CSRF, fail-closed CORS, `AnonymousSessionMiddleware`. **(Beta-7)** A token-bucket rate limiter: `RateLimit-*` headers, `429` + `Retry-After` (RFC-017 §3.1). |
| Auth         | `auth`                                                         | Universal Authentication Bridge (RFC-021): JWT, OAuth2/OIDC + PKCE, HMAC gateway assertions, API key, HTTP Basic — fail-closed, stateless. |
| Persistence  | `data`                                                         | Universal Data & Persistence Layer (RFC-022): stateless SQR query AST, worker-safe connection pooling, 7 backends, immutable-VO CRUD mappers. **(Beta-7)** Reversible migrations (`db:rollback`, `db:status`, `make:migration`) and the atomic Redis stores behind the rate limiter and the circuit breaker. |
| DI & Config  | `container`, `config`                                          | PSR-11 autowire container with `ResettableInterface`; native YAML (ext-yaml) loader with `%env(VAR)%` interpolation.             |
| Cross-cutting| `cache`, `event-dispatcher`, `log`, `error-handler`, `console` | PSR-6/16 + stampede protection; PSR-14; PSR-3; RFC 7807; zero-magic CLI runtime.                                                 |
| Concurrency  | `async`                                                        | **(Beta-5)** Fiber-based finish-request deferred task runner (RFC-015): bounded post-response work — mail, audit logs, webhooks — off the latency path. |
| Background jobs | `queue`                                                     | **(Beta-7)** Redis Streams queue with bounded retries and a dead-letter store; `console`'s `queue:work` consumes it and drains on SIGTERM. Mail is a contract only: a mail is a queue message. |
| API surface  | `openapi`, `serializer`                                        | **(Beta-7)** OpenAPI 3.1 generated from `#[Route]` and typed DTOs (`openapi:generate`, plus a debug-only `/_docs`); compiled, reflection-free DTO normalizers and JSON content negotiation (RFC-016). |
| Testing      | `testing`                                                      | **(Beta-7)** `WaffleTestCase` sends PSR-7 requests through the real pipeline in-process; doubles for the clock, the queue, the mailer, the HTTP client and the rate-limiter store. A `require-dev` package. |
| Observability| `telemetry`, `telemetry-otel`                                  | **(Beta-5)** Contract-first observability (RFC-005): SDK-free Prometheus `/waffle-metrics` + stateless collectors; the opt-in OpenTelemetry tracing bridge (the sole OTel-SDK importer). **(Beta-7)** Dev-only profiler headers: `X-Waffle-Time`, `X-Waffle-Memory`, `X-Waffle-Queries`, `Server-Timing`. |

Every one of these is **PSR-anchored**: PSR-3 (logging), PSR-6 (cache pool),  PSR-7 (HTTP messages), PSR-11 (container), PSR-14 (events), PSR-15 (middleware), PSR-16 (simple cache), PSR-17 (HTTP factories), PSR-18 (HTTP client), and, in the Beta-7 testing bridge, PSR-20 (clock). The framework does not invent new abstractions for problems PSR  already solved.

### 1.3 The Beta-7 canonical pipeline

Every request through a Waffle app traverses this order, wired by `AppKernelFactory` (from `skeleton/src/Factory/AppKernelFactory.php` on the Beta-7 tree):

```text
ErrorHandler → Metrics → Probes → Tracing → TrustedHost → CORS → AnonymousSession → Authentication → RateLimit → Routing → CSRF → Security → TransactionIsolation → SecureHeaders → Dispatcher
```

| #  | Stage                  | What it does                                                                                                   |
|----|------------------------|----------------------------------------------------------------------------------------------------------------|
| 1  | `ErrorHandler`         | RFC 7807 problem response for any uncaught error                                                               |
| 2  | `Metrics`              | `/waffle-metrics` (Prometheus), answered to loopback or a bearer token only                                    |
| 3  | `Probes`               | `/healthz` (liveness) and `/readyz` (readiness); before `Tracing`, so a probe hit every few seconds opens no span; before `TrustedHost`, because a kubelet probe carries the pod IP as `Host` |
| 4  | `Tracing`              | server span + W3C `traceparent` (RFC-005)                                                                      |
| 5  | `TrustedHost`          | `Host` allowlist                                                                                               |
| 6  | `CORS`                 | fail-closed cross-origin policy                                                                                |
| 7  | `AnonymousSession`     | the opaque `WAFFLE_SID` cookie                                                                                 |
| 8  | `Authentication`       | the Universal Authentication Bridge (RFC-021)                                                                  |
| 9  | `RateLimit`            | token bucket per authenticated subject, per client IP otherwise; `429` + `Retry-After`                         |
| 10 | `Routing`              | attribute router / `RouteTrie`; sets `_classname`                                                              |
| 11 | `CSRF`                 | stateless HMAC token bound to the SID                                                                          |
| 12 | `Security`             | context-aware ABAC, object-level (IDOR)                                                                        |
| 13 | `TransactionIsolation` | one transaction per write request: commit, or rollback on any uncaught error                                   |
| 14 | `SecureHeaders`        | defensive response headers                                                                                     |
| 15 | `Dispatcher`           | the controller call                                                                                            |

Fourteen middleware in front of the controller dispatch, every one of them PSR-15-compliant, every one of them stateless across requests, every one of them locked-in at boot time so the order cannot mutate under load. Beta-7 added two stages: the orchestrator probes (RFC-023) and the rate limiter (RFC-017 §3.1), which an application can switch off. (`Metrics` has been there since Beta-5; the earlier reading of this document left it out of the diagram. Beta-5 also added the `Tracing` stage — the OpenTelemetry/Prometheus server span, no-op until a tracer is wired (RFC-005) — and the `TransactionIsolation` stage (RFC-022/DBAL); Beta-4 added the fail-closed `CORS` stage (SEC-04); the `Authentication` stage landed with the Beta-3 `auth` component.) In debug mode only, which a production kernel refuses, two more stages appear: the profiler headers in front of everything, and the Swagger UI at `/_docs` just before routing.

Beyond the request pipeline, Beta-5 added **finish-request** work that runs after the response is emitted and before the worker takes its next request: deferred tasks (`async`) and reactive `#[Broadcast]` SSE flushes, both fired on the `TerminateEvent`. Beta-7 adds the work that does not belong in a request at all: `queue:work`, a separate long-running consumer that resets the container after each message and, on SIGTERM, finishes the message in flight before it exits.

### 1.4 The release cadence

Components release in **lockstep waves**: each `0.1.0-betaN` is a coherent set of  tags across every component, advancing along the release train (`beta1 → … → beta5 → beta6 → beta7 → beta8 → 1.0.0-RC1 → 1.0.0`). Beta-6 shipped in September 2026 and Beta-7 ships in November 2026; beta8, in December 2026, is the API freeze; `1.0.0-RC1` follows in December 2026, and Gold is targeted for late January 2027. Tags carry **no `v` prefix** — the tag-format gate rejects it. The `self.version` Composer trick (`waffle-commons/contracts: self.version` in  each component's `composer.json`) means a user installing `waffle-commons/security@0.1.0-beta7` automatically gets `waffle-commons/contracts@0.1.0-beta7`. The trade-off is documented and accepted: consumers cannot  mix-and-match versions within a wave. This is the **coordinated waves over  fine-grained interop** trade. The wave itself is fail-closed: each component's release branch reaches its `main` through a merge commit (a squash would orphan the commit the umbrella pins, and the wave would then refuse to tag anything), only an allowlist of repositories is released, and pushing the umbrella tag *is* the trigger of the live release, so it is never pushed to test.

### 1.5 The Docker-first constraint

Every command in the docs is gated on `docker exec -w /waffle-commons/<component> waffle-dev <command>`, which the `wfl` CLI wraps. Native PHP on the host is intentionally untested. The reason is given in [`docs/explanation/docker-first-development.md`](docs/explanation/docker-first-development.md): PHP 8.5 + `ext-yaml` (PECL) + FrankenPHP + Xdebug in a reproducible image is cheaper to maintain than asking every contributor to install all four correctly. Since October 2026 the image runs FrankenPHP 1.13.2 on PHP 8.5.12, the security releases for the PHP2Shell CVEs, and `wfl images:pin` keeps the Docker images the project depends on pinned by digest. The `waffle-dev` container is the source of truth.

This is also why Waffle is **honest about what it is**: a framework you run inside FrankenPHP, in a container, with worker mode on. Run it under classic PHP-FPM and you still get a working app — but the design choices stop paying for themselves.

### 1.6 What is *not* in Waffle, by design

- **No ORM.** No Doctrine, no Eloquent equivalent. The closest thing is the **shipped** `waffle-commons/data` component (RFC-022, Universal Data & Persistence Layer, landed in Beta-3), and even that explicitly rejects Active Record and Identity Map patterns in favor of stateless Semantic Query Representation trees.
- **No view layer.** No Twig, no Blade. Controllers return PSR-7 responses; JSON is the assumed interchange.
- **No general-purpose serializer.** `serializer` (Beta-7) maps strictly-typed DTOs to and from JSON at the HTTP boundary, and nothing else; other formats are post-v1, and `data`'s hydrator stays inside the persistence layer.
- **No message-bus framework.** `queue` (Beta-7) is contracts, one driver (Redis Streams) and a worker — deliberately not a Symfony Messenger clone; other drivers are post-v1. Mail is a contract only (`MailerInterface`): a mail is dispatched as a queue message, and SMTP or API transports are post-v1.
- **No native validation library.** Validation lives inside PHP 8.5 Property Hooks on `#[Dto]`-tagged constructor parameters. `ControllerArgumentResolver` hydrates the DTO from the parsed body; Property Hook failures surface as RFC 7807 `422` via `ValidationException`. (Beta-4 adds an injectable, mockable `ValidatorInterface` wrapping the static `Assert` facade for userland services, but the framework's own validation logic still lives in Property Hooks.)
- **No facades, no static helpers, no global container.** Every dependency is passed by constructor or resolved through the PSR-11 container under a specific interface key.
- **No `$_SESSION`, no `session_start()`.** Session state is, by mandate, exclusively the per-browser `WAFFLE_SID` cookie issued by `AnonymousSessionMiddleware` — an opaque, anonymous identifier, never a server-side session store.
- **No mass-assignment surface.** The DTO is `final readonly`; the argument resolver pre-checks each parsed body value against the DTO constructor's declared parameter type *before* construction, so a native `\TypeError` can never propagate from a hook.
- **No fail-open default in authentication or authorization.** Missing voter → 403. Missing CSRF token → 403. Missing trusted-host config → boot refused in prod. Missing CSRF secret in prod → boot refused. Missing route → 404 (typed, not 500). Method not allowed → 405 (typed, with `Allow` header). Unregistered critical dependency → not ready. The one deliberate exception concerns availability, not access: when the rate limiter's Redis is unreachable, the limiter admits traffic with a warning and a metric (`on_storage_failure: open`), because a limiter outage should not take the API down. `closed` is the recommended setting on authentication endpoints, and authentication and authorization stay fail-closed regardless.

These omissions are not deficiencies; they are choices that follow from the five evolutions defended below.

### 1.7 The academy — the five evolutions as a teachable curriculum

New in the Beta-4 timeframe, and absent from earlier readings of this document, is the `academy` submodule — *itself* a nested monorepo of three independent submodules plus its own Diátaxis `docs/` tree:

- **`obsidian/`** — the lessons. A five-level progression — **Rookie → Sentinel → Ranger → Guardian → Master** — of **10 lessons each, 50 in total**. Each lesson is short, cross-linked to its neighbours, and closes with a TDD challenge. The level themes track the framework's own architecture almost exactly:
  - **L1 · Rookie** — PHP 8.5 foundations: strict types, `readonly` immutability, Property Hooks (read *and* write), asymmetric visibility, typed constants & enums, union/intersection types, constructor promotion, the Mago linter, the ecosystem runner.
  - **L2 · Sentinel** — the FrankenPHP resident lifecycle & PSR-15: worker vs FPM, the middleware stack, state pollution & singletons, `ResettableInterface`, memory leaks, GC tuning, request/response mutations, hot-reload DX, RFC 7807 errors.
  - **L3 · Ranger** — DI & attribute routing: the explicit container, `#[Route]`, dynamic URI parsing, `#[Dto]` hydration, argument resolvers, domain decoupling, PSR-14 events, stoppable events, PHPUnit 12, the 95 % coverage goal.
  - **L4 · Guardian** — security & fail-closed ABAC: the fail-closed philosophy, ABAC, voters, dynamic subject evaluation, timing-attack resistance, session-fixation/cookie rotation, double-submit CSRF, *cryptographic* CSRF binding, SSRF mitigations, safe paths & traversals.
  - **L5 · Master** — observability, pooling & ops: the `igor-php` leak detector, static verification, dangling sockets, connection pooling in worker mode, failsafe transaction isolation, Docker-first orchestration, CI/CD wave release, AOT compilation, OpenTelemetry tracing, the Prometheus metrics endpoint.
- **`labs/`** — the executable specifications. **50 PHPUnit 12 tests already ship**, one per lesson, each deliberately **red** until the student writes the target class in `src/`. An answer-key tree (`solutions/`) and a `wfl academy:solve` / `academy:reset` toggle let a stuck learner load and then clear a reference solution (`src/Lesson*/` is `.gitignore`-d so a loaded answer can never be committed). Crucially, `wfl academy:verify` proves every solution green through the **same gate the framework holds itself to** — `mago fmt --check` + `lint` + `analyze` + `guard --perimeter` + PHPUnit — then restores a blank `src/`. The labs declare only `contracts` + `security` + `utils` (symlinked path repos), so even the teaching sandbox lives inside the Component Agnosticism perimeter.
- **`sandbox/`** — a *live* FrankenPHP worker app, not a toy: a `PlaygroundController` with `Greeting`/`Mood` DTOs (virtual property, `public private(set)`, typed enum), a PSR-14 `PlaygroundVisited` event + listener, a `CorrelationIdMiddleware`, a `RookieVoter`, `#[PublicAccess]`, its own `AppKernelFactory`, and an `igor.json` — so the onboarding playground is held to the same statelessness mandate (`wfl igor`) as production code. Served via `wfl academy:serve`.

The whole academy obeys the project language policy (`AGENTS.md` §1): **pedagogy 100 % French, code/identifiers/contracts 100 % English** (`Waffle\Academy\Labs\…`) — the same split used in `skeleton/` and `workspace/`.

The analytical point is that the five levels map almost one-to-one onto the five evolutions defended in §2 (L1 → §2.1, L2 → §2.2, L3 → §2.5 in practice, L4 → fail-closed security, L5 → worker-safety + the Zero-Debt protocol of §2.3, which the labs *enforce* on every solution). Where §2.4 argues that Waffle ships its operating procedures **for AI** as committed code (`.claude/skills/`), the academy is the **human-cognitive counterpart**: operating procedures for *people*, shipped as committed, test-gated, versioned curriculum that releases in the same wave. Both encode the same thesis; one is read by an assistant, the other is learned by hand.

***

## 2. The Five Evolutions Waffle Embodies

This is the core of the analysis. Each evolution is a thesis about where PHP is going. Each is something Waffle ships today, in production-quality code, at the cost of being less general-purpose than Symfony or Laravel. The argument is not that these evolutions are *Waffle inventions* — they are not. The argument is that Waffle is **the most coherent executed example** of each one, in a single repository, with mechanical enforcement.

### 2.1 PHP 8.5 as a strict, hookable, ergonomically-typed language

PHP 8.5 adds two surface features whose implications most of the ecosystem has not yet absorbed:

1. **Property Hooks** — `public string $email { set(string $value) { … } }`, running validation inside the property mutation itself, not in a deferred visitor.
2. **Asymmetric Visibility** — `public private(set) string $name`, giving external read access without permitting external mutation, without writing a getter.

Combined with `final readonly`, typed constants (`public const string FORMAT = 'json';`), `#[\Override]`, and the long-standing constructor property promotion, the result is a language with **value-object ergonomics competitive with Kotlin or Swift, executing under FrankenPHP**.

Waffle's coding rule (`AGENTS.md` §1) bans `mixed` outright, forbids `@` silencing, mandates `#[\Override]` on every interface implementation, and mandates Property Hooks for validation rather than legacy getter/setter ceremony. The skeleton's quick-start lesson is, literally:

```php
#[Dto]
final class HelloInput
{
    public function __construct(
        public private(set) string $name {
            set(string $value) {
                $clean = trim($value);
                if ($clean === '' || preg_match('/^\p{L}+$/u', $clean) !== 1) {
                    throw new ValidationException(
                        message: 'Field "name" must be a non-empty, alphabetic string.',
                        field: 'name',
                    );
                }
                $this->name = $clean;
            }
        },
    ) {}
}
```

A controller method then asks for `HelloInput` by type, and the `ControllerArgumentResolver` does the rest: hydrate from the parsed body, run the hooks during construction, unify any thrown `ValidationException` to RFC 7807 `422` with a field-level `field` payload.

**Why this is an evolution, not a feature.** External validators (Symfony Validator, Laravel's `Validator` facade) inherently allow a window of *temporary invalid state*: the DTO is instantiated, *then* validated, *then* either accepted or rejected. Property Hooks close that window — the object cannot physically exist with invalid state because the hook throws inside the constructor. This is the same guarantee Rust gives you for free with constructors that return `Result<T, E>`; PHP 8.5 + Property Hooks delivers it without a new language. RFC-011 (Data Integrity & DTOs) is explicit about this: *"we guarantee that a DTO cannot physically be instantiated with invalid data."*

The evolution is not Property Hooks. The evolution is the **realization** that once Property Hooks exist, every external validator becomes a workaround for a missing language feature. Waffle has internalized that realization and built the rest of the framework around it.

**Beta-5 extends Property Hooks from *validation* to *reactivity*.** The new `#[Broadcast(channel:)]` attribute (RFC-018) sits on a PHP 8.5 **write** hook (`set`): mutating the property records a `MutationRecord` into a request-scoped buffer — the hook itself performs *no* I/O — and a finish-request listener flushes that buffer over Server-Sent Events after the response cycle. It is the same language feature as the validation hook above, pointed at a different problem: state changes become observable without an ORM event system or an external message bus, and (because hooked properties cannot be `readonly` in 8.5) the pattern is scoped precisely to mutable `final class … public private(set)` DTOs, never the `final readonly` value objects. Where the validation hook proves an object *cannot physically exist invalid*, the broadcast hook proves a mutation *cannot go unobserved* — both guarantees carried by the language, not bolted on beside it.

**Beta-7 makes the same typed DTO the single description of an API's boundary.** The constructor shape that the validation hooks guard is read once, by `utils`' DTO shape reader, and serves three consumers. `serializer` compiles a reflection-free normalizer per DTO at build time (`serializer:compile`, loaded on the `WAFFLE_AOT=1` fast path, with an interpreted fallback); its round-trip test runs 16 shapes — hooks and asymmetric visibility, nested DTOs, a tree through itself and through a list — through both normalizers and requires byte-identical output. `openapi:generate` builds the OpenAPI 3.1 document from the routes and the same shapes, so the specification describes exactly what the serializer accepts and emits; the documents generated from both template apps validate against the official OpenAPI 3.1 JSON Schema. Optional `#[Operation]`, `#[Response]` and `#[Property]` attributes refine the document; without them it is terse but still valid. One type, declared once: it validates the input, shapes the output and documents both.

### 2.2 FrankenPHP resident-worker as the default deploy target

`AGENTS.md` §2 is titled *"FrankenPHP Statelessness Mandate"* and reads, in full:

> Services must be **stateless and resettable** across requests (resident-memory worker mode):
>
> - **No `$_SESSION`, no `session_start()`,** no native PHP session functions.
> - **No superglobals** (`$_SERVER`, `$_GET`, `$_POST`, …) — use injected PSR-7 `ServerRequestInterface` or `GlobalsFactory`.
> - **No mutable static / singleton state** surviving a request; request-scoped services release on `$kernel->reset()` (implement `ResettableInterface` where applicable).
> - **No `sys_get_temp_dir()`** or other ambient global state.

This is not a recommendation. It is the operating contract of every component. The kernel `reset()`s the container between worker requests; the `MiddlewareStack` locks on first request and refuses mutation; the `AbstractKernel` reads `APP_ENV` via `getenv()` without `putenv()`-ing anything back (because mutating the global env from one request would taint the next); the `CsrfTokenManager` holds zero instance state between requests because the HMAC is recomputed from arguments every time.

Look at the HTTP client's design for the lengths Waffle goes to in service of this mandate. From the performance documentation:

- A single `\CurlHandle` + `\CurlMultiHandle` held for the worker's lifetime, reused via `curl_reset()` on every `sendRequest()`. libcurl's DNS cache and keep-alive pool stay warm.
- Non-blocking transfer via `curl_multi_select()` — the worker parks on a socket wait instead of busy-spinning a CPU or blocking inside `curl_exec()`. A slow upstream can no longer pin a worker beyond the 10s hard ceiling.
- Bounded memory both directions: 8 KiB chunks in (`CURLOPT_WRITEFUNCTION`), 8 KiB chunks out (`CURLOPT_READFUNCTION` + `CURLOPT_UPLOAD`). Proxying a multi-gigabyte payload costs one 8 KiB buffer.

The net effect is a **fixed, predictable per-worker memory ceiling regardless of payload size**, and workers that are never held hostage by a slow backend. That is what "resident-worker as the default" actually requires; it is not enough to merely *boot* under FrankenPHP. Every piece of plumbing has to be re-engineered for memory-boundedness.

**Why this is an evolution.** PHP's traditional execution model — boot, serve one request, die — is what most of the language's libraries are written for. Forcing every existing library to be worker-safe is a multi-year migration. Waffle does not migrate; it starts fresh, on the worker-safe contract, and refuses to ship anything that violates it. The result is a framework that pays no per-request boot. How much faster that makes it is a measurement, not a consequence to assume: §5.8 says what the benchmark rig measures, and what it cannot.

Symfony 7 *can* run under FrankenPHP worker mode (and does, increasingly). Laravel Octane offers similar functionality. But both must paper over decades of stateful libraries, third-party bundles, and ORM connection lifecycles written before the worker model existed. Waffle ships zero such legacy.

**Beta-5 deepens this evolution from *survival* to *exploitation*.** Once a framework is genuinely worker-resident, the resident process is an asset to exploit, not merely a constraint to respect — and Beta-5 cashes that in. **Ahead-of-Time compilation** (RFC-019) compiles the DI graph into a `CompiledContainer` and the `#[Route]` table into a `RouteTrie`, both loaded at worker boot behind `WAFFLE_AOT=1` with a transparent reflection fallback, removing runtime reflection from the hot path; a snapshot test proves the compiled service graph identical to the runtime one. **Fiber-based finish-request deferral** (RFC-015, the new `async` component) runs short post-response work — mail, audit writes, webhooks — after the response is flushed but before the worker takes its next request, under a bounded budget that explicitly refuses to masquerade as a real queue. **Memory-resident connection pooling** (RFC-022 / DBAL) borrows a PDO or Redis handle at request start and returns it at request end, healing severed connections on lease (`SELECT 1` / ping before dispense), with a transaction-isolation middleware that rolls back on any uncaught error so no lock leaks between worker iterations. None of these make sense under classic boot-per-request PHP; every one of them is a dividend of having committed to the worker model *first* — and the same `wfl igor` 0-KO audit that polices statelessness polices them too.

**Beta-7 carries the worker model into operations.** A resident worker has to tell an orchestrator when it can serve, and leave without dropping what it is serving. `/healthz` answers liveness only and never touches a dependency, so a database blip cannot restart every pod. `/readyz` aggregates the components' `HealthCheckInterface` probes and fails closed on an unregistered critical one; its public body stays minimal, and the per-check detail answers only loopback or a bearer token, like `/waffle-metrics`. Each check has its own timeout (2 s to connect to the database, 1 s to read from Redis), so a database that never answers now yields not-ready in 2 s, where a pool lease used to hang past 15 s. The handlers were measured: about 5 µs for `/healthz` whatever the number of probes, about 6 µs plus 1.1 µs per probe for `/readyz`, nothing retained over 100 000 calls. On shutdown, `/readyz` flips before the drain, through a `preStop` marker on Kubernetes or Caddy's `shutdown_delay` elsewhere. Two replicas behind a load balancer that polls `/readyz`, restarted one after the other under k6 at 100 requests per second, served 7 501 requests with 0 failures on each path, where the control run with SIGTERM alone lost 20: a correctness check on one laptop, not a capacity figure.

The same discipline reaches the new long-running process. `queue:work` resets the container after each message, passes the same `wfl igor` audit, and on SIGTERM finishes the message in flight before it exits; a message whose worker crashed is reclaimed from the Redis Streams pending list by another consumer. State that several workers must share — the rate limiter's buckets, the circuit breaker's circuits — lives in Redis, never in worker memory, and the limiter's refill-and-take is one Lua script on the Redis clock. Eight processes making 800 calls on a 50-token bucket were admitted exactly 50 times, in four runs out of four, where a deliberately non-atomic store admitted 299, 225 and 243. The worker stays stateless; the state it needs is explicit, shared and atomic.

The mandate also gained a precise escape hatch after outside review at the API Platform Conference (September 2026). Runtime reset stays opt-in, as in Symfony: `ResettableInterface` is optional, state kept on purpose is declared with `#[WorkerSafe(reason: …)]`, and the strictness lives in the dev-mode compliance scanner and the `wfl igor` gate rather than in an interface every service must implement (RFC-001 §5).

### 2.3 Zero-Debt static analysis as a baseline expectation

The *Mago Purge Protocol* (`docs/explanation/mago-purge-protocol.md`) is unusually severe for the PHP world:

> Every component, on every commit, must pass: `mago fmt --check`, `mago lint`, `mago analyze`, `mago guard` with **zero errors, zero warnings, zero notices, zero hints**, and **no baseline files**.

The "no baseline files" clause is the key. Mago supports `mago-*-baseline.toml` files that snapshot existing issues so a project can adopt the tool gradually; Waffle forbids them outright. The reasoning is the same as the zero-warning policy: *a baseline file is institutional permission to leave issues unfixed*. If a finding genuinely cannot be addressed, the right fix is a narrowly-scoped `[analyzer.ignore]` entry in the component's `mago.toml`, with a code comment pointing at the issue — a documented, reviewable, narrow exception, not a swallow-everything snapshot.

The twin rule, enforced by `coverage.sh`, is **≥95% PHPUnit coverage** on every component. Together they form what the project calls the "Zero-Debt" guarantee.

There is a specific architectural payoff: `mago guard` is configured per component in `mago.toml` to enforce the **Component Agnosticism rule** (every component imports only from `waffle-commons/contracts` and declared PSR packages). The dependency perimeter is enforced mechanically. A PR that adds `use Waffle\Commons\Routing\Router;` inside `security/src/` fails CI before it can be reviewed.

**Why this is an evolution.** Threshold-based gates teach contributors that warnings are background noise; within a year you have 200 of them and one new genuinely-important one nobody can find. Zero-warning policy makes every new warning *visible* — it breaks the build the instant it lands. The cost is paid once: scrubbing the existing codebase to zero. Then it amortizes across every future PR.

This level of discipline is unusual in PHP — Symfony and Laravel both have internal quality bars, but neither makes "zero of everything" a public contract. Waffle treats it as the entry condition for the ecosystem. The same discipline is normal in Rust (`cargo clippy -D warnings`) and Haskell (`-Werror`); Waffle ports the expectation to PHP without compromise.

**Since Beta-5 the bar has moved from code to claims.** The gate itself got stricter. A PHPUnit run that ends `OK, but…` (skipped, incomplete or risky tests, PHPUnit issues) is not green, even though PHPUnit exits 0. Each component has a coverage floor that only ratchets up, and mutation testing has floors of its own. The worker-safety auditor is pinned to one version everywhere, and CI fails when the resolved binary differs. Every component's CI also scans for secrets and builds a CycloneDX SBOM.

Then the same zero tolerance reached what the project says about itself. A roadmap item is done when its acceptance criteria are shown by tests, command output or reports, not when its code exists: a read-only verifier agent grades each criterion PASS, FAIL or UNVERIFIED. On 31 October 2026 it found two unbuilt `[API-01]` spec points and one unverified `[NET-01]` criterion, and all three were closed before the tag. A published number carries its method, its environment and its uncertainty: memory is reported as a slope with its 95 % bound over a settled window, never as a flat factor; a benchmark run never overwrites an earlier series, and an invalidated series is kept and marked. The EcoShield gateway withdrew its own "~80 % RAM" headline under that rule (§4).

### 2.4 AI-cognitive tooling as a first-class repository artifact

This is the most unusual feature of the Waffle umbrella. Open the repo and you find:

- **`AGENTS.md`** — the central operating spec for *any* AI assistant, and binding: the PHP 8.5 coding standards, the FrankenPHP statelessness mandate, the Mago Purge Protocol, the worker-safety gate, the language policy (English for the framework, French for the `skeleton/`, `workspace/` and `academy/` template apps), the release train and what each phase allows, the git and release safety rules, and the evidence rules.
- **`CLAUDE.md`** — imports `AGENTS.md` into every session (`@AGENTS.md`) and adds only the Claude Code specifics: the canonical Docker commands, the `wfl` CLI, the MCP servers, the plugins. It does not duplicate standards.
- **`.claude/skills/`** — **34 skills**, each a `SKILL.md` whose frontmatter (`name`, `description`, `when_to_use`) tells the assistant when to load it; the catalogue is `docs/reference/claude-skills.md`. Grouped by intent:
  - **Core workflow:** `tech-lead` (the phase-aware entry point), `coding`, `refactoring`, `test`, `code-review`, `maker-scaffold` (RFC-020 — controllers, DTOs, middleware, voters, commands, HTTP clients, event pairs).
  - **Quality gates & worker mode:** `mago-purge` (Zero Baseline enforcement), `worker-safety` (`wfl igor` remediation), `contracts-first` (interface sequencing + `mago guard` perimeter), `benchmark-gate`, `soak-endurance` (slopes with their 95 % bound).
  - **Security:** `security-audit` (statelessness, ABAC, SSRF, CORS, traversal, `#[PublicAccess]`), `auth-bridge-audit` (RFC-021 — JWT, OAuth2/OIDC, HMAC assertions, API keys; fail-closed, stateless), `webauthn-passkeys`.
  - **Data & persistence:** `data-persistence` (RFC-022 — SQR, stateless pools, Firestore paths, atomic flat-file, CRUD mappers).
  - **Runtime maturity (Beta-5):** `aot-compilation` (RFC-019), `async-concurrency` (RFC-015), `observability` (RFC-005), `reactive-broadcast` (RFC-018).
  - **Production surface (Beta-7):** `resilience-net` (RFC-017, RFC-024), `queue-worker`, `api-surface` (RFC-016), `k8s-ops` (RFC-023), `testing-bridge` — staged ahead of their code in the Beta-5 reading, now backed by shipped components.
  - **Docs, scaffolding & release:** `diataxis-doc`, `component-scaffold`, `release-manager`, `release-wave`, `demo-app-wiring`, `roadmap-steward`, `sync-components`.
  - **The road to 1.0:** `api-freeze` (beta8), `rc-certification` (RC1), `ecoshield` (the dogfood gateway whose soak decides v1 adoption).
- **`.claude/agents/`** — **18 subagents** the skills dispatch for single-component work: the 14 of the Beta-5 reading (`coding-worker`, `coding-integrator`, `docgen-worker`, `gate-runner`, `mago-fixer`, `test-author`, `worker-safety-auditor`, `security-auditor`, `contracts-sync`, `aot-verifier`, `benchmark-runner`, `demo-wiring-worker`, `flake-hunter`, `webauthn-auditor`) plus `acceptance-verifier`, `bc-reviewer`, `chaos-runner` and `soak-analyst`. A read-only agent is denied the write tools in its own definition.
- **Plugins and servers** — a project plugin, `waffle-cockpit`, shows the session state under the prompt (model, context, cost, repository, release phase, unpushed commits) and enforces rules at the tool boundary: a Bash guard on git and release operations, a check for a new `mixed` or a secret on every edit, a Mago run after every PHP edit, and a reminder that "done" needs evidence. A vendored, pinned set of third-party skills runs under `AGENTS.md`, which wins any conflict. Four MCP servers (PostgreSQL, MongoDB, Redis, GitHub) start from pinned launchers; GitHub and MongoDB are read-only, and database writes ask first.

Each skill encodes operating procedures that override generic AI defaults. The routing rule in `AGENTS.md` §8 is binding: *"When a request matches a skill, load it before planning or acting: it holds the operating procedure for that area and overrides general defaults."*

The `tech-lead` skill's "Orchestration protocol" reads like a software engineering manager's playbook:

> 1. **Triage:** decide whether the task needs `coding`, `refactoring` or `test`, plus the capability skill for the roadmap item. For anything touching `project_system/` direction, consult `roadmap-steward` first.
> 2. **Plan before acting:** identify the affected submodules. Sequence contracts-first (`contracts-first`): any new interface lands in `waffle-commons/contracts` before its consumer, and dependencies point only to `contracts` (+ `utils`). Large multi-repo work gets an Action Plan first, and file edits wait for the maintainer's "proceed".
> 3. **Execute:** load `coding` or `refactoring`. Strict PHP 8.5 types, Property Hooks, stateless design for FrankenPHP (`worker-safety`).
> 4. **Test:** load `test`. PHPUnit 12.5 coverage ≥95 %.
> 5. **Review:** load `code-review`. PSR compliance, zero-output Mago, `wfl igor` 0 KO, and no public-API change after the freeze.
> 6. **Accept:** for a roadmap item, dispatch the `acceptance-verifier` agent on the item's acceptance criteria. Code that passes its unit tests but not the roadmap criterion is not done.

Crucially, **the umbrella also ships per-RFC AI skills**. RFC-020 (Waffle Maker) ships `maker-scaffold`. RFC-021 (Universal Authentication Bridge) ships `auth-bridge-audit`. RFC-022 (Universal Data & Persistence Layer) ships `data-persistence`. Beta-7's RFC-023 (Kubernetes Operability) and RFC-024 (Outbound Resilience) ship `k8s-ops` and `resilience-net`. These are not generic prompts; they encode the specific security boundaries, cryptographic protocols, and architectural patterns of their RFCs.

**Why this is an evolution.** Frameworks have always shipped human documentation. Most projects in 2026 *also* generate AI-friendly summaries out-of-band. Waffle treats AI operating procedures as **committed code**, versioned alongside the framework, releasable in lockstep, and reviewable as PRs. The result is that an AI assistant working in this repository has access to the same project knowledge a senior engineer would — encoded as `SKILL.md` files, not as folklore.

This is genuinely novel. It is also fragile: a stale `SKILL.md` is worse than none, because it confidently misleads. The umbrella answers in three ways. Skills change through the same commits as the code and ship with the release wave. `wfl ai:check` lints the whole layer, locally and in CI: a subagent without a `name:` is never registered, so the check refuses it. And the rules that matter most are not left to a skill at all: the plugin and the team permission rules refuse a forced push, a squash merge, a `v`-prefixed tag, or a release tag the maintainer has not set, whatever the assistant was told.

**Caveat for honesty.** The "AI-cognitive tooling as a first-class artifact" evolution is one Waffle is *betting on*, not one the broader PHP ecosystem has collectively adopted. Whether this becomes industry practice depends on whether AI-driven development sustains, and whether `.claude/`-style skill repositories become recognized as a documentation genre. Today they are unusual; tomorrow they may be expected. Waffle is positioning early, and since October 2026 on a single assistant (§5.6).

### 2.5 Component Agnosticism as a mechanical invariant

The repo's component layout enforces a single rule with surprising rigor: **every component depends only on `waffle-commons/contracts`** (plus declared PSR packages and, as a special case, `waffle-commons/utils` for pure-function helpers — `utils` itself has zero inter-component dependencies).

`security` cannot import `Waffle\Commons\Routing\Router`. It can import `Waffle\Commons\Contracts\Routing\RouterInterface`. The concrete implementation is wired in by the application (`AppKernelFactory`); the component itself talks to the abstraction. `mago guard`, configured per component in `mago.toml`, refuses any PR that violates this rule.

This is documented in [`docs/explanation/component-agnosticism.md`](docs/explanation/component-agnosticism.md) with three reasons:

1. **Independent releasability.** If `security` required `routing`'s concrete class, then `composer require waffle-commons/security` would drag in `routing` whether you wanted it or not. Real consumers of `security` (for example, an app that wants ABAC but has its own router) would be forced into a router they didn't choose.
2. **Decoupled evolution.** With contracts only, the surface that can break is the *contract* — a deliberate, visible, ecosystem-wide event. Beta-1 changed `CsrfTokenManagerInterface::issue/validate/refresh` to accept a `$sessionId` argument; that single change cascaded through the wave and was documented in the contracts CHANGELOG.
3. **Testability.** `security`'s tests mock `RouterInterface`. They never instantiate `Router`. The test suite never depends on `routing`'s tests passing.

The rule has one deliberate exception: `RouteNotFoundException` is concrete and lives in `contracts`, because `CoreRoutingMiddleware` (in `pipeline`) needs to *throw* it, and the only alternative places (a sibling component) would re-create the dependency loop. Hoisting one concrete exception into `contracts` is the smallest possible violation; it pays for itself by letting every component throw and catch the same class. Beta-2 extends this exception to `MethodNotAllowedException` for the same reason (typed `405` handling end- to-end).

**Why this is an evolution.** Most frameworks declare independence as aspiration. Waffle declares it as **a build-time CI gate**. A graph of 25 components, each releasable independently to Packagist, each individually composable into someone else's framework — that's a genuinely different shape from a Symfony bundle ecosystem or a Laravel package collection. Symfony bundles depend on the kernel; Laravel packages tend to depend on Illuminate. Waffle components depend on nothing concrete from each other, ever, by construction.

The trade-off: every shared symbol must justify its existence in `contracts`. Adding to `contracts` is an ecosystem-wide event. This is friction, and it is the right kind of friction.

Beta-7 put the rule under load with four new components. Every new interface — queue messages and their envelope, health checks, rate-limit storage, timeout and retry policies, migration state, the OpenAPI attributes, the mailer — landed in `contracts` before its first consumer. The single sanctioned third-party exception is `testing`: `WaffleTestCase` extends PHPUnit's `TestCase`, so the component's own guard permits PHPUnit's namespace, and only that class imports it. And `queue:work` lives in `console` on contracts alone; the application's `bin/waffle` wires the Redis concretes in.

***

## 3. What Waffle Deliberately Doesn't Try To Be

A clear-eyed picture of any framework requires being explicit about what it *isn't*. Waffle is unusually clear about its non-goals.

### 3.1 It is not a Symfony replacement

Symfony's value proposition includes Twig, Doctrine, the Form component, the Messenger system, the Mailer, the Security bundle's firewall ladder, Maker bundle, Symfony Console (with autoload-aware commands), the Validator, Notifier, Translator, Workflow, and a 20-year ecosystem of bundles. Waffle ships narrow counterparts for a few of them and **none** of the rest: a zero-magic `console`, Waffle Maker (RFC-020) for scaffolding, validation through Property Hooks instead of a Validator, and since Beta-7 a minimal `queue` (contracts, one Redis Streams driver and a worker, not a Messenger clone) with a mailer *contract* but no transport. Its `console` component is intentionally "zero-magic" — commands are registered explicitly, not auto-discovered from random bundles. There is no Twig analog. There is no Doctrine analog: `waffle-commons/data` (RFC-022) *has* shipped — it landed in the Beta-3 wave and gained worker-resident PDO/Redis connection pooling + transaction-isolation middleware in Beta-5 and reversible migrations in Beta-7 — but it is a stateless query/persistence layer that explicitly rejects Active Record and Identity Map, not an ORM.

If you're building a CMS, a B2B SaaS with role-based admin, an internal tool that needs forms-and-views, Symfony is the answer. Waffle would force you to build half a framework on top.

### 3.2 It is not a Laravel replacement

Laravel ships Eloquent (an Active Record ORM), Blade (a templating engine), the facade DSL (statically-callable singletons), broadcasting, queues with Horizon, Scout, Cashier, Telescope, Nova/Filament admin generators, and *ergonomics* — the perception that any common task is one expressive line of PHP. Waffle has narrow equivalents for two of them — broadcasting, as Server-Sent Events fired from write hooks (Beta-5), and a minimal Redis Streams queue with no Horizon-style dashboard (Beta-7) — and none of the rest, and its statelessness mandate is philosophically *incompatible* with facades (which rely on globally-resolved singletons).

If you want to ship a SaaS in two weeks with batteries-included tooling, Laravel is the answer. Waffle would force you to assemble the batteries yourself.

### 3.3 It is not a stable, production-recommended framework yet

`README.md` is explicit: *"beta software — production use requires an independent security audit."* The `documentation/README.md` adds a prominent warning. Beta-7 delivers the production *surface* — probes, drain, migrations, rate limiting, outbound resilience, background jobs — not production *certification*, and the remaining path is spelled out in advance. beta8 (December 2026) is the API freeze: a symbol-by-symbol backward-compatibility review of `contracts` against a written policy (`contracts/BC-POLICY.md`), the deprecations, a naming pass, a 72-hour soak and a final security re-audit; after its tag, only bug fixes ship. `1.0.0-RC1` (December 2026) adds no feature, removes the beta8 deprecations and must hold a soak of at least four weeks on the EcoShield gateway (§4); a critical defect means an RC2 and restarts the soak clock. Gold, targeted for late January 2027, is the soaked RC with zero code delta. The trajectory is clearly toward 1.0, but the project is not there yet.

### 3.4 It is not a one-person-can-maintain-all-of-it framework

The release wave is documented as essentially mechanical (`./loop.sh composer mago && ./loop.sh composer tests && ./coverage.sh && tag each component in topological order → bump umbrella submodule pointers → tag the umbrella → `release-wave.yml` fans out`), but it still touches 25 framework components and the template apps. One contributor running the full wave is feasible; one contributor running the *entire* ecosystem long-term is not. Waffle needs an organization, and at beta its CODEOWNERS is `@waffle-commons/waffle-core` — a team identifier, not an individual. In practice Beta-7 was built by one maintainer working with the AI operating layer of §2.4: that is the project's answer to scale so far, and a bet in its own right (§5.6).

This is not a critique of the design; it is a structural fact. The umbrella exists *because* the project is too big for a single repository to be ergonomic, and the submodule shape buys explicit per-component velocity. But it does mean evaluating Waffle as "the future of PHP" includes evaluating whether its organizational shape will scale.

### 3.5 It is not a mass-market framework

Mass-market PHP frameworks adopt forgiving defaults: validation that warns rather than aborts, route configuration that has sensible fallbacks, security that opts in. Waffle does the opposite: fail-closed everything, deny by default, 403 on a missing voter. This is a deliberate **opinionated bias toward correctness over ergonomics**, and it is correct for security-critical and edge-of-network deployments. It would be wrong for an internal admin tool where developers genuinely need looser controls during exploration.

You do not pick Waffle because it is forgiving. You pick it because forgiving is not what you need.

***

## 4. Where Waffle Fits in a Symfony/Laravel World

If Waffle isn't displacing Symfony or Laravel, what *is* its role? The RFCs and the existing code answer this with unusual specificity: **Waffle is designed to live at the edge, in front of and alongside legacy PHP monoliths, as the Strangler-Fig migration substrate.**

The pattern has a name in the documentation: the **Waffle edge gateway**. The HTTP client's performance section calls it out:

> An edge gateway proxies traffic to slower upstreams (e.g. a legacy monolith). Doing that inside a resident worker *without* leaking memory or pinning threads is a FinOps concern: wasted RAM and workers blocked on a slow backend both cost money at scale.

The routing component documents the gateway pattern with code:

```php
// Edge-gateway forward: a multi-segment catch-all that ONLY matches when no
// higher-priority route claimed the URI. `{forwarded:.*}` spans every remaining
// segment, and the negative priority guarantees it sits at the tail of the table.
#[Route(path: '/', name: 'gateway', priority: -1000)]
final class GatewayController
{
    #[Route(path: '{forwarded:.*}', name: 'fallback')]
    public function forward(string $forwarded): ResponseInterface { /* proxy to legacy monolith */ }
}
```

And RFC-021 (Universal Authentication Bridge) makes the coexistence pattern explicit — its HMAC identity-propagation scheme lets

> a Waffle edge service (e.g. a Strangler-Fig gateway) propagate the authenticated identity to a downstream application (Symfony, Laravel, custom PHP, or another Waffle app) without re-authentication, via the `X-Wfl-Assert-User` header.

The architecture works like this:

```text
                               +----------------------------+
                               |       Client Browser       |
                               +----------------------------+
                                             |
                                     HTTP Request (Cookie)
                                             v
                       +--------------------------------------------+
                       |            WAFFLE EDGE GATEWAY             |
                       |       (Waffle Core - FrankenPHP)           |
                       +--------------------------------------------+
                         /                                        \
              [Intercepted Route]                           [Proxied Route]
                       /                                            \
  +---------------------------------------+       +------------------------------------+
  |      SecureContainer & ABAC           |       |    HMAC Signing & Injection        |
  |  (in-process, no network hop)         |       |   of Signed Assertion Headers      |
  +---------------------------------------+       +------------------------------------+
                       |                                             |
                 API Processing                                 PSR-18 Call
                       |                                             v
                Direct Response                     +------------------------------------+
                       |                           |          LEGACY MONOLITH           |
                       v                           |        (Symfony / PHP-FPM)         |
                    Client                         +------------------------------------+
```

The mechanics:

- New traffic, modern endpoints, security-sensitive paths → handled by Waffle directly. Fail-closed ABAC, stateless HMAC CSRF, RFC 7807 errors, no per-request boot in resident worker mode.
- Legacy paths → proxied through the streaming PSR-18 HTTP client — since Beta-7 under bounded timeouts, retries for idempotent methods only and a circuit breaker — with an HMAC-signed `X-Wfl-Assert-User` header injected so the legacy monolith can hydrate a virtual user session without re-authenticating. 5-second TTL, IP-bound, constant-time `hash_equals()` verification, fail-closed on missing secret.
- Over time, legacy paths are reimplemented as Waffle controllers and removed from the catch-all route. The legacy monolith shrinks; Waffle grows; the public API is preserved end-to-end.

This is the canonical Strangler-Fig migration, executed in PHP, with the new piece being the **strict, secure, fast** piece. Symfony and Laravel are the legacy in this story not because they are bad — they are excellent — but because they predate the FrankenPHP-native, statelessness-mandated, Zero-Debt era. They will continue to evolve; Octane and FrankenPHP integration in Symfony are good evidence of that. But neither can ship the worker-native contract as foundationally as a from-scratch design can.

**The pattern is no longer only documented: it has a dogfood.** EcoShield Gateway — a FinOps API gateway in its own repository and on Packagist (`0.1.0`, the proof of concept, then `0.1.1`, a measurement correction) — runs this scenario in front of a real Symfony 5.4 monolith, on public Waffle APIs only: a private reach-through would count as a framework design bug, fixed in the framework. Its alpha, built on Beta-7 and published as `0.2.0` after the wave, serves the strangled route natively behind a PSR-16 "shield" cache and proxies everything else over the resilient client: bounded timeouts, retries for idempotent methods only (it never replays a POST or a PATCH, whatever the configuration says), circuit state in Redis, and the rate limiter on all traffic. Its lab results are correctness checks, not published performance numbers: 32 concurrent clients sending 1 800 requests from one IP against a 600-per-minute bucket got 632 admitted and 1 168 refused with `429`, within the bucket plus its refill (632.7); with Redis stopped, every route still answered, each degraded path logging a warning.

Dogfooding paid for itself at once. The gateway found that the HTTP client sent an unsized body chunked next to the caller's `Content-Length`, so nginx answered `400` to every proxied POST and PUT, on Beta-6 as on Beta-7; the fix landed in the framework's `http-client`, not as a workaround in the gateway. The gateway also applies the measurement rule to itself: it withdrew its "~80 % RAM" headline, because a memory claim is a slope and a crossover, never a flat percentage. Its next steps are the FinOps benchmark of the beta8 window and, on RC1, the soak of at least four weeks that decides v1 adoption.

Where Waffle fits:

- **The edge.** API gateways, identity proxies, rate limiters, fail-closed policy enforcement points, signing relays, audit collectors.
- **High-throughput JSON APIs.** Tight per-request budgets, bounded memory, no boot overhead; since Beta-7, an OpenAPI 3.1 description generated from the code, and background jobs for the work that does not belong in a request.
- **Strangler-Fig migrations.** Sitting in front of a Symfony or Laravel monolith, slowly absorbing endpoints.
- **Microservices with strict typing.** Cases where a Symfony bundle would drag in too much, and a poly-repo of bespoke micro-frameworks would be too loose.

Where Waffle does not fit:

- Apps where validation logic genuinely needs to be loose and forgiving.
- Apps that lean heavily on a templating engine.
- Apps with deep ORM requirements.
- Apps where the team is small and a batteries-included framework gets you to ship in two weeks.

The narrow positioning is the strength. Waffle does not try to be everything; it tries to be the right thing in the right place.

***

## 5. Risks, Open Questions, and Honest Limits

A "future of PHP" claim requires interrogating the risks. Here are the real ones, in roughly decreasing importance.

### 5.1 Ecosystem mass

Waffle has 25 framework components plus skeleton, workspace, academy, template, and documentation. Symfony has 50+ bundles, hundreds of community packages, and a 20-year compounding flywheel. Laravel has Cashier, Scout, Horizon, Telescope, Sanctum, Passport, Nova, Filament, Octane, and an order-of-magnitude bigger community-package marketplace.

For Waffle to succeed in any market beyond the edge/gateway niche, it needs either (a) deeper batteries — the RFC-022 data layer and the RFC-021 auth bridge (incl. OAuth2/OIDC, and now WebAuthn passkeys) have *shipped*, and the Beta-5 wave added RFC-015 async, RFC-005 observability (the `telemetry` Prometheus endpoint + the `telemetry-otel` OpenTelemetry bridge), RFC-019 AOT compilation, RFC-018 reactive broadcast, and the RFC-022 connection-pooling / transaction-isolation layer; Beta-7 then adds the production surface — RFC-016 OpenAPI generation and the DTO serializer, the RFC-017 rate limiter, RFC-024 outbound resilience, the queue and its worker, the testing bridge, and RFC-023's probes and drain. beta8 then freezes the feature set for v1: other queue drivers, mail transports, serialization formats and the live SQL Server and Oracle migration round trip are post-v1 — or (b) explicit interoperability with Symfony/Laravel components where the use case allows. Both paths are slow.

### 5.2 The single-author signal

`composer.json` files across the components list a single author: Leslie Petrimaux. The git log of the umbrella reflects coordinated multi-component commits from one engineer. The CODEOWNERS team is `@waffle-commons/waffle- core`, but at the time of this analysis the public footprint suggests a small core.

This is normal for a beta-stage framework; Symfony and Laravel both started similarly. But it is a risk to flag: ecosystem velocity scales with contributor count, and the very strictness of the Mago Purge Protocol raises the bar to participation. A new contributor cannot land "good-enough" code; the gate is zero-everything. The schedule shows the same constraint, recorded rather than hidden: the train slipped one month on 2026-09-06, and on 2026-10-21 beta7 moved from October to November 2026 to keep its full scope, every later release moving by the same week instead of being compressed.

### 5.3 Learning curve

To contribute productively, a developer must internalize:

- PHP 8.5 Property Hooks, Asymmetric Visibility, typed constants, `final readonly`.
- FrankenPHP worker mode, statelessness mandate, `ResettableInterface`.
- The Mago Purge Protocol, including the `mago.toml` perimeter syntax.
- The Component Agnosticism rule — when to add to `contracts`, when to keep in a component.
- PSR-3/6/7/11/14/15/16/17/18 — all of them.
- The Diátaxis documentation framework — and the discipline of placing each doc in the right quadrant.
- The release-wave choreography (signed tags, topological order, umbrella pointer bumps).

This is a steep ramp. The contributor docs (`/docs`) are genuinely good, and the `tech-lead` skill encodes the orchestration playbook for AI assistants, but the human ramp is still measured in days, not hours. Symfony and Laravel both have on-ramps measured in hours.

The Beta-4 wave's direct answer to this risk is the `academy` submodule (§1.7): a five-level, 50-lesson curriculum whose levels track the five evolutions almost one-to-one, each lesson closing with a TDD challenge whose PHPUnit test ships *red* and is graded by the same Zero-Debt gate (`mago` + `guard --perimeter` + ≥95 % coverage) the framework holds itself to. It does not flatten the ramp to hours — internalizing the statelessness mandate and the Component Agnosticism rule still takes practice — but it converts the ramp from tribal knowledge into a structured, self-paced, executable path, with an answer key one command away. The honest caveat: the umbrella `CHANGELOG` lists the academy content as the *last* finishing item of the Beta-4 wave, so it is the newest and least battle-tested surface in the repository.

### 5.4 The "I will use it for everything" pressure

Once a developer has internalized Waffle's worldview, the temptation to apply it everywhere is real. This is the wrong move. Waffle is excellent for strict, secure, fast edges. It is not the right tool for "I need to ship a CRUD admin in three days." The framework cannot prevent itself from being misapplied; the documentation can only nudge.

### 5.5 The bet on FrankenPHP

Waffle ties itself tightly to FrankenPHP. If FrankenPHP fails to maintain momentum (which today seems unlikely, but is non-zero), Waffle's reason for existence shrinks: a stateless framework with no worker runtime is just a strict framework. The runtime component has a classic-SAPI fallback, but the performance story collapses without resident workers.

This risk is shared with Octane (which bets on Swoole/RoadRunner/FrankenPHP) and is well-managed today. But it is real.

The coupling is also concrete at the version level. On 2026-10-22 the stack moved to FrankenPHP 1.13.2 on PHP 8.5.12, the security releases for the PHP2Shell CVEs, and the graceful drain behaved differently: during Caddy's `shutdown_delay`, 1.13.2 keeps PHP serving where 1.12.7 answered `500`, so the drain check passes 9 of 9 on the new version and fails 3 on the old one. Every runtime bump is a re-verification, not a version string.

### 5.6 The AI-tooling-as-code bet

Section 2.4 above identified the `.claude/` layer as one of Waffle's evolutionary contributions. But this is a bet on a future where AI-assisted development is the dominant mode of contribution to PHP frameworks. If that future arrives, Waffle is well-positioned. If it does not — if AI tooling remains an external adjunct — then committing 34 skills and 18 subagents to a release becomes overhead without payoff. Since 2026-10-05 the bet is also concentrated: the operating layer moved from an OpenCode layout (`.opencode/`) to Claude Code alone, and its enforcement — the plugin, the permission rules, the MCP launchers — works in that one tool.

The hedge: even in a future without AI, or with another assistant, `AGENTS.md` is excellent human documentation in plain Markdown, and the skill files double as engineering playbooks. The bet is asymmetric; the downside is small.

### 5.7 The pre-1.0 contract surface

Beta-1 broke one contracts interface (`CsrfTokenManagerInterface`). Beta-2 relocated the `Route` attribute from `routing` to `contracts`. These breaks are documented and small, but the project is explicit that interfaces *can* break until 1.0. A consumer adopting Waffle pre-1.0 must accept some churn.

The window now has an end date: the beta8 tag (December 2026) is the freeze. Before it, beta8 reviews every `contracts` symbol against a written policy (`contracts/BC-POLICY.md`), deprecates what will not survive and runs a naming pass, including over what Beta-7 added (queue messages and their envelope, health checks, rate-limit storage, timeout and retry policies, migration state, the OpenAPI attributes, the mailer). After the beta8 tag only bug fixes ship, and RC1 removes the deprecations. After 1.0, the contracts surface stabilizes — but until then, integrators should pin to a specific beta wave and budget for upgrade work.

### 5.8 What a laptop can and cannot measure

Waffle's performance case rests on a reproducible K6 rig (`bench/`) that isolates one variable per comparison: the Waffle skeleton's production image in FrankenPHP worker mode (Engine A), an idiomatic Symfony API on PHP-FPM behind nginx (B), the same Symfony app in FrankenPHP worker mode (C), and that app doing Engine A's per-request security work (D). A against C isolates the framework (though A also runs its secured pipeline), B against C the runtime, and A against D the framework at equal features. Published numbers live in `bench/BENCH-GATE-RESULT.md`, each with its method; the Beta-6 results there were measured on FrankenPHP 1.12.2, and the rig now pins 1.13.2, so the next run starts a new series.

The rig has corrected itself more than once, which is the point of publishing the method with the numbers. Beta-7 hardened it before any new public number: a run can no longer overwrite a series, every run records its host, soak slopes come with their 95 % bound, and Engine C now runs Symfony's native FrankenPHP worker runner with its loop limit raised, because the 500-request default had recycled the workers and invalidated the Beta-6 soak comparison. The rig also found a real cost in Waffle: the pool's liveness ping doubled the database round trips. A freshness window halved the transactions per pooled read (4.21 → 2.12) and moved the `dbread` saturation knee from 1 200 to 1 500 requests per second on the same rig; the Beta-6 knee itself (400 requests per second) no longer reproduces even with the old code, a reminder that a number belongs to its rig.

The project's rule (`AGENTS.md` §7) is blunt: *"A laptop cannot measure capacity or hold a multi-day soak. Say so instead of publishing."* The rig runs on one laptop, so it publishes relative comparisons, latency with its rate and concurrency, and memory slopes — not capacity figures. The Beta-7 re-measurement on the hardened rig runs before the tag; the 72-hour soak of beta8 and the four-week EcoShield soak of RC1 are the sustained runs that will turn the runtime claims into durable evidence.

***

## 6. The Verdict

Is `waffle-commons` the future of PHP?

**Not in the sense of "the framework most PHP applications will use in 2030."** That seat is taken by Symfony for enterprise PHP and Laravel for product PHP, and there is no realistic path by which either is displaced by a stricter, narrower framework that explicitly disclaims their use cases. The maintainers do not even try to make that pitch.

**But yes, in the sense of "the framework that embodies the evolutions PHP itself is undergoing."** Specifically:

- **PHP 8.5 as a strict, hookable language.** Property Hooks + Asymmetric Visibility + typed constants + `final readonly` are language features that most existing libraries have not yet absorbed. Waffle is what a codebase looks like when those features are the default, not the exception. As more PHP code is written this way — and it will be, because the features are there — Waffle will look less like an outlier and more like the leading edge.
- **FrankenPHP-native resident workers as the default deploy target.** Symfony and Laravel both increasingly support worker mode, but they do not *mandate* it; their libraries must remain compatible with classic SAPI. Waffle mandates it, and the design choices that follow (stateless services, `ResettableInterface`, memory-bounded streaming, no superglobals, no `$_SESSION`) are what the language has been waiting for. Resident-worker PHP is genuinely the future deploy target; Waffle is what an entire codebase optimized for it looks like.
- **Zero-Debt static analysis as a baseline.** Rust, Haskell, Kotlin, and Swift treat zero warnings as table stakes. PHP has historically been more forgiving. Waffle ports the strict expectation to PHP without compromise. As the broader PHP ecosystem matures toward stricter typing — PHPStan and Psalm adoption are both growing fast — Waffle's stance becomes the baseline, not the outlier.
- **AI-cognitive tooling as committed code.** This is a more speculative bet, but a plausible one. As AI-assisted development becomes routine, projects that ship explicit operating procedures for AI assistants will produce more consistent contributions than those that don't. Waffle's `.claude/` layer — skills and subagents, plus a plugin and permission rules that enforce what matters most at the tool boundary — is an early, well-thought-out instance of what the practice will eventually look like across the ecosystem.
- **Component Agnosticism as a mechanical invariant.** Symfony bundles are loosely coupled to the kernel; Laravel packages are loosely coupled to Illuminate. Waffle components are tightly coupled to `contracts` and to nothing else, enforced by `mago guard`. This is a different architectural shape — one that allows individual components to be lifted into other frameworks, used independently, and evolved on their own cadence. It is not the dominant shape today, but it is what every "the components are the framework" pitch (Symfony Components, Illuminate Components) has aimed at for years. Waffle delivers it without the residual coupling.

The honest framing is this: **Waffle is not a destination; it is a direction. It is the most coherent executed example of where strict, secure, fast PHP is going, packaged in a single repository, with mechanical enforcement of the choices that direction requires.** Symfony and Laravel will continue to lead mass-market PHP; they will adopt some of these evolutions on their own schedules, constrained by their installed bases. Waffle will continue to lead the strict edge: the gateway in front of the monolith, the proxy that signs HMAC assertions, the rate limiter that fails closed, the audit collector that streams 8 KiB chunks under a worker that never blocks.

In that sense — Waffle as **evolutionary pressure** on the rest of the PHP ecosystem, not as displacement — yes, `waffle-commons` is part of the future of PHP. Whether you adopt it, or whether you adopt the pieces of it that suit your context, the direction is correct: PHP is becoming stricter, PHP is becoming worker-native, PHP is becoming zero-debt-by-default, PHP is becoming AI-tool-aware, PHP is becoming component-agnostic.

Symfony and Laravel will get there too, on different timelines. Waffle is already there, in a single, lockstep-released, beta-quality, twenty-five-component proof — and, with the `academy`, it ships those five evolutions as a teachable, test-gated curriculum, so the direction is not merely demonstrated but transmissible. The Beta-5 wave is the inflection where the proof stops being only about *strictness* and starts being about *runtime maturity*: AOT compilation, Fiber finish-request concurrency, reactive write-hook broadcasting, memory-resident pooling, contract-first telemetry, and native passkeys — the high-performance HTTP runner has become an event-driven, reactive, AOT-optimized application runtime, without surrendering a single line of the statelessness or Zero-Debt mandate. Beta-7 completes the other half: the production surface an operator asks for — probes, drain, migrations, rate limits, timeouts, retries, circuit breakers, background jobs, an API description — built under the same mandates and accepted on evidence. What separates it from 1.0 is now mostly consolidation and certification: a freeze, a soak, and a release candidate that must not change.

That is not "the future of PHP." That is **a future of PHP**, demonstrated. And it is enough.

***

## Appendix A — How to read this document

If you are evaluating Waffle for a specific use case:

| Use case                                       | Read first                                                                                  |
|------------------------------------------------|---------------------------------------------------------------------------------------------|
| "Should I migrate my Symfony app to Waffle?"   | §3.1, §3.5, §4 (the answer is almost certainly **no** — coexist instead)                    |
| "Should I build a new SaaS in Waffle?"         | §3.2, §4 (the answer is **probably not** unless the SaaS is API-only and edge-shaped)       |
| "Should I build an API gateway in Waffle?"     | §2.2, §4 (the answer is **yes**; EcoShield Gateway is the worked example)                   |
| "Can I run it in production today?"            | §3.3, §5.8 (the answer is **not yet**: Beta-7 delivers the production surface, RC1 the certification, and production use still requires your own security audit) |
| "Does it do jobs, API docs and kernel tests?"  | §1.2, §2.1, §2.2 (the answer is **yes, deliberately minimal**: one queue driver, OpenAPI 3.1 from your types, an in-process kernel test bridge) |
| "Should I learn this framework as a PHP dev?"  | §2.1, §2.2, §5.3 (the answer is **yes for the language ideas, slowly for the framework**)   |
| "Will Waffle be alive in five years?"          | §5.2, §5.5, §5.6 (the answer is **probably, with caveats**)                                 |
| "What about Symfony/Laravel?"                  | §4 (they will continue to lead mainstream PHP; Waffle will lead the strict edge)            |

## Appendix B — Sources consulted

This document was assembled by direct reading of, at minimum:

- `AGENTS.md`, `CLAUDE.md`, `README.md`, `CHANGELOG.md` (umbrella)
- `docs/README.md` and all five `docs/explanation/*.md` files
- `docs/reference/repository-layout.md`, `docs/reference/docker-environment.md`, `docs/reference/component-ruleset.md`, `docs/reference/opencode-skills.md`, `docs/reference/workflows/release-wave.md`
- `documentation/README.md` and `documentation/explanation/*.md` (architecture, lifecycle, performance, fail-closed ABAC, signed CSRF)
- `documentation/reference/index.md`, `contracts.md`, `core.md`, `runtime.md`, `security.md`, `routing.md`, `pipeline.md`, `http.md`, `http-client.md`
- `documentation/tutorials/quick-start.md`, `documentation/how-to/secure-a-controller.md`
- `contracts/composer.json`, `waffle/composer.json`, `security/composer.json`, `skeleton/composer.json`
- `waffle/src/Kernel.php`, `waffle/src/Abstract/AbstractKernel.php`
- `runtime/src/WaffleRuntime.php`
- `security/src/Security.php`, `security/src/Csrf/CsrfTokenManager.php`
- `pipeline/src/MiddlewareStack.php`
- `routing/src/Router.php`
- `skeleton/README.md`, `skeleton/src/Kernel.php`, `skeleton/src/Factory/AppKernelFactory.php`, `skeleton/public/index.php`, `skeleton/docker/Dockerfile`
- `workspace/README.md`
- `AGENTS.md` §1–§5b (coding standards, statelessness mandate, Mago Purge Protocol, worker-safety gate, Skills Routing Table), `.opencode/skills/tech-lead/SKILL.md`, and the `.opencode/skills/` + `.opencode/agents/` inventory (29 skills, 14 subagents)
- The full `academy` monorepo: `academy/README.md`, `academy/obsidian/index.md` and the 50 lessons across `Level_1_Rookie` → `Level_5_Master`; `academy/labs/README.md` + `composer.json` (the 50 executable-spec tests, the `solve`/`unsolve`/`verify` scripts) and a sample lab test; `academy/sandbox/` (`PlaygroundController`, DTOs, PSR-14 event/listener, `CorrelationIdMiddleware`, `RookieVoter`, `igor.json`); `academy/docs/` (Diátaxis); and the `wfl academy:*` command surface (`bin/wfl`)
- The **Beta-5** components and their `documentation/` pages: `async/src/DeferredTaskRunner.php`; `telemetry/` (`MetricsRegistry`, `MetricsMiddleware`, the memory/GC/pool collectors, `PrometheusExporter`) and `telemetry-otel/` (`OtelTracer`, `W3CTraceContextPropagator`); `container`'s `ContainerCompiler` + `routing`'s `RouteTrie` (AOT, `WAFFLE_AOT=1`); `data`'s `PDOConnectionPool`/`RedisConnectionPool` + `TransactionIsolationMiddleware`; `auth`'s `WebAuthnLibAdapter`; and the reactive `#[Broadcast]` buffer + finish-request flush in `waffle` — together with the matching `documentation/explanation`, `reference`, and `how-to` pages authored in the Beta-5 wave
- `project_system/RFCs/RFC_001` (Core & Runtime), `RFC_002` (Security & ABAC), `RFC_003` (HTTP & Middlewares), `RFC_005` (Logging & Observability), `RFC_011` (Data Integrity & DTOs), `RFC_013` (Caching System), `RFC_015` (Asynchronous Execution), `RFC_016` (OpenAPI), `RFC_017` (Advanced Security), `RFC_018` (DX & Tooling), `RFC_019` (AOT Compilation), `RFC_020` (Waffle Maker), `RFC_021` (Universal Auth Bridge), `RFC_022` (Universal Data & Persistence Layer)

The Beta-7 refresh (31 October 2026, on the pre-release tree ahead of the `0.1.0-beta7` tag) additionally read:

- `AGENTS.md` §1–§9 (in particular §5b, the release train; §6, git and release safety; §7, evidence and measurement) and `CLAUDE.md`
- the `.claude/` inventory as linted by `wfl ai:check` (34 skills, 18 subagents, 2 plugins), and the `tech-lead`, `ecoshield`, `k8s-ops`, `component-scaffold` and `release-wave` skills
- `project_system/Roadmaps/Roadmap_Beta7.md` — every item's recorded status and evidence, and the acceptance check of 31 October 2026 — and `project_system/Logs/Releases/Log_Beta6.md`
- `project_system/RFCs/RFC_023_Kubernetes_Operability.md`
- `skeleton/src/Factory/AppKernelFactory.php` (the Beta-7 middleware order)
- `bench/README.md` (the engine matrix and its comparisons)
- `README.md` (umbrella)

Quotes from the Beta-5 reading are verbatim from the files listed for it, at the `0.1.0-beta5` release; the Beta-7 facts and quotes come from the files above as they stood on 31 October 2026.
