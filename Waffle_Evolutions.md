---
title: "Waffle Evolutions — Is waffle-commons the Future of PHP?"
type: article
author: Leslie Petrimaux
date: 2026-05-29
date_updated: 2026-07-08
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

> **Scope.** A deep, evidence-based analysis of the `waffle-commons` monorepo (release `0.1.0-beta5`, July 2026) against the question: *does this project represent the future of PHP?* — accepting the deliberate constraint that Waffle does **not** aim to replace Symfony or Laravel. **Method.** Direct reading of `AGENTS.md`, `CLAUDE.md`, both Diátaxis trees (`/docs` for contributors, `/documentation` for framework users), the 22 RFCs in `project_system/RFCs/`, the canonical middleware order in `AppKernelFactory`, and the live source of the load-bearing components (`AbstractKernel`, `WaffleRuntime`, `CsrfTokenManager`, `Router`, `MiddlewareStack`, `Client`, and the Beta-5 additions: `ContainerCompiler`/`RouteTrie` for AOT, `DeferredTaskRunner` for async, the PDO/Redis connection pools, and the contract-first `TracerInterface`).
>
> **Author position.** None — this document audits Waffle on its own terms, not Symfony's or Laravel's.

***

## TL;DR

`waffle-commons` is **not** "the future of PHP" if that phrase is read as *"the framework most PHP applications will run on in five years."* Symfony and  Laravel will continue to define mainstream PHP for the simple reason that they  own the ecosystems — the ORMs, the queue layers, the admin generators, the  mailers, the community. Waffle ships none of that, and the maintainers say so: the README opens with *"Strict, Secure, Fast"*, not *"replace your framework"*.

What Waffle *is* — and this is the load-bearing claim of this document — is **a working proof of five evolutions that PHP, as a language and as a runtime,  is currently undergoing**. Each evolution is real, each is happening  independently of Waffle, and each is something that Symfony and Laravel are  slower to adopt natively because they cannot afford to break their installed  base. Waffle ships these evolutions today, in 21 lockstep-released Packagist  packages, with `composer mago && composer tests` green at every commit and `wfl igor` worker-safety at 0 KO:

1. **PHP 8.5 as a strict, hookable, ergonomically-typed language** — Property  Hooks replacing external validators; Asymmetric Visibility replacing  getter/setter ceremony; typed constants replacing string-keyed magic; `final readonly` replacing builder-pattern DTOs.
2. **FrankenPHP resident-worker as the default deploy target** — no `$_SESSION`, no `session_start()`, no static singletons, no `sys_get_temp_dir()`, no per-request boot. The kernel boots once and stays  in memory; statelessness is enforced architecturally, not by convention.
3. **Zero-Debt static analysis as a baseline expectation** — the *Mago Purge  Protocol*: zero errors, zero warnings, zero notices, zero hints, zero  baseline files. Twin-ruled by ≥95% PHPUnit coverage. This is the kind of  discipline the Rust and Haskell ecosystems take for granted, ported to PHP  without compromise.
4. **AI-cognitive tooling as a first-class repository artifact** — `.opencode/skills/`, `AGENTS.md`, and `CLAUDE.md` are committed code, not  adjunct knowledge. The 29 named skills (`tech-lead`, `coding`, `mago-purge`, `security-audit`, `auth-bridge-audit`, `data-persistence`, `observability`, `aot-compilation`, `async-concurrency`, `reactive-broadcast`, `webauthn-passkeys`, …) and 14 subagents encode operating procedures that override generic AI  defaults at the project boundary.
5. **Component Agnosticism as a mechanical invariant** — every component  depends only on `waffle-commons/contracts`. Enforced by `mago guard`,  refused by CI. The result is 21 components, each individually composable  into someone else's framework, with no hidden coupling between them.

These five evolutions are the **Waffle thesis**. The Beta-5 wave (July 2026) is where the thesis stops being mostly about *correctness* and starts being about *runtime maturity*: it transitions Waffle from a high-performance HTTP runner toward an **event-driven, reactive, AOT-optimized application runtime** — shipping Ahead-of-Time compilation, Fiber finish-request task deferral, reactive `#[Broadcast]` write-hooks, memory-resident connection pooling, contract-first telemetry, and native WebAuthn passkeys, all under the same statelessness and Zero-Debt mandates. Whether you adopt Waffle or  not, the language and the runtime are moving in this direction; Symfony and  Laravel will continue to adapt; Waffle is simply the place where each evolution is already executed without compromise. In that narrow sense — Waffle as *evolutionary pressure*, not as displacement — yes, it is *a* future of PHP.

The rest of this document defends that claim with the evidence.

***

## 1. What Waffle Actually Is (the inventory, without marketing)

### 1.1 The umbrella shape

The `waffle-commons` monorepo is an umbrella Git repository containing **26 submodules**: 21 framework components, a `skeleton` (app template), a `workspace` (live FrankenPHP dev app), an `academy` (itself a nested monorepo of three submodules — `obsidian` lessons, `labs` TDD exercises, and a `sandbox` worker app), a `component-template` (scaffold for new  components), and a `documentation` tree (framework user docs). Each submodule is its own independent Git repository, released  independently to Packagist on a coordinated release-wave cadence. The umbrella's  own purpose is to pin each at a specific SHA and ship cross-component tooling (`bin/wfl`, `igor.sh`, `scripts/install-git-hooks.sh`, `.opencode/`, `.github/workflows/`).

This shape is deliberate and documented in [`docs/explanation/why-monorepo-of-submodules.md`](docs/explanation/why-monorepo-of-submodules.md): true monorepos cannot publish to Packagist (no subpath publication); pure  poly-repos lose the coordinated "what versions go together" state. The  umbrella-with-submodules pattern keeps both Packagist independence and ecosystem  coherence.

### 1.2 The 21 framework components

| Layer        | Component(s)                                                   | Purpose                                                                                                                          |
|--------------|--------------------------------------------------------------- |----------------------------------------------------------------------------------------------------------------------------------|
| Foundation   | `contracts`, `utils`                                           | The only common-import packages. `contracts` ships interfaces + attributes + enums + typed constants; `utils` ships pure helpers.|
| Kernel       | `waffle`, `runtime`                                            | `AbstractKernel` + `WaffleRuntime` (FrankenPHP worker loop with classic-SAPI fallback).                                          |
| HTTP         | `http`, `http-client`, `routing`, `pipeline`                   | PSR-7/17/18, attribute-driven router with priority + catch-all, PSR-15 stack with lock-on-build semantics.                       |
| Security     | `security`                                                     | Fail-closed ABAC, `#[Voter]` / `#[PublicAccess]` attributes, stateless HMAC CSRF, fail-closed CORS, `AnonymousSessionMiddleware`. |
| Auth         | `auth`                                                         | Universal Authentication Bridge (RFC-021): JWT, OAuth2/OIDC + PKCE, HMAC gateway assertions, API key, HTTP Basic — fail-closed, stateless. |
| Persistence  | `data`                                                         | Universal Data & Persistence Layer (RFC-022): stateless SQR query AST, worker-safe connection pooling, 7 backends, immutable-VO CRUD mappers. |
| DI & Config  | `container`, `config`                                          | PSR-11 autowire container with `ResettableInterface`; native YAML (ext-yaml) loader with `%env(VAR)%` interpolation.             |
| Cross-cutting| `cache`, `event-dispatcher`, `log`, `error-handler`, `console` | PSR-6/16 + stampede protection; PSR-14; PSR-3; RFC 7807; zero-magic CLI runtime.                                                 |
| Concurrency  | `async`                                                        | **(Beta-5)** Fiber-based finish-request deferred task runner (RFC-015): bounded post-response work — mail, audit logs, webhooks — off the latency path. |
| Observability| `telemetry`, `telemetry-otel`                                  | **(Beta-5)** Contract-first observability (RFC-005): SDK-free Prometheus `/waffle-metrics` + stateless collectors; the opt-in OpenTelemetry tracing bridge (the sole OTel-SDK importer). |

Every one of these is **PSR-anchored**: PSR-3 (logging), PSR-6 (cache pool),  PSR-7 (HTTP messages), PSR-11 (container), PSR-14 (events), PSR-15 (middleware), PSR-16 (simple cache), PSR-17 (HTTP factories), PSR-18 (HTTP  client). The framework does not invent new abstractions for problems PSR  already solved.

### 1.3 The Beta-5 canonical pipeline

Every request through a Waffle app traverses this order, wired by `AppKernelFactory` (verbatim from `skeleton/src/Factory/AppKernelFactory.php`):

```text
ErrorHandler → Tracing → TrustedHost → CORS → AnonymousSession → Authentication → Routing → CSRF → Security → TransactionIsolation → SecureHeaders → Dispatcher
   RFC 7807    server span    Host     fail-closed   WAFFLE_SID     Universal Auth   attr/Trie  HMAC  context-aware   commit/rollback   defensive   controller
  on errors  + traceparent  allowlist  cross-origin + _anon_sid    Bridge (RFC-021) _classname + SID  ABAC (IDOR)  on write (DBAL)  headers       call
```

Twelve middleware, every one of them PSR-15-compliant, every one of them  stateless across requests, every one of them locked-in at boot time so the  order cannot mutate under load. (Beta-5 added the `Tracing` stage — the OpenTelemetry/Prometheus server span, no-op until a tracer is wired (RFC-005) — and the `TransactionIsolation` stage, which wraps write requests in a DB transaction and rolls back on any uncaught error (RFC-022/DBAL); Beta-4 added the fail-closed `CORS` stage (SEC-04); the `Authentication` stage landed with the Beta-3 `auth` component.) Beyond the request pipeline, Beta-5 adds **finish-request** work that runs after the response is emitted and before the worker takes its next request: deferred tasks (`async`) and reactive `#[Broadcast]` SSE flushes, both fired on the `TerminateEvent`.

### 1.4 The release cadence

Components release in **lockstep waves**: each `0.1.0-betaN` is a coherent set of  tags across every component, advancing along the release train (`beta1 → beta2 → beta3 → beta4 → beta5 → … → 1.0`). Tags carry **no `v` prefix** — the tag-format gate rejects it. The `self.version` Composer trick (`waffle-commons/contracts: self.version` in  each component's `composer.json`) means a user installing `waffle-commons/security@0.1.0-beta5` automatically gets `waffle-commons/contracts@0.1.0-beta5`. The trade-off is documented and accepted: consumers cannot  mix-and-match versions within a wave. This is the **coordinated waves over  fine-grained interop** trade.

### 1.5 The Docker-first constraint

Every command in the docs is gated on `docker exec -it -w /waffle-commons/<component> waffle-dev <command>`. Native PHP on the host is intentionally untested. The reason is given in [`docs/explanation/docker-first-development.md`](docs/explanation/docker-first-development.md): PHP 8.5 + `ext-yaml` (PECL) + FrankenPHP + Xdebug in a reproducible image is cheaper to maintain than asking every contributor to install all four correctly. The `waffle-dev` container is the source of truth.

This is also why Waffle is **honest about what it is**: a framework you run inside FrankenPHP, in a container, with worker mode on. Run it under classic PHP-FPM and you still get a working app — but the design choices stop paying for themselves.

### 1.6 What is *not* in Waffle, by design

- **No ORM.** No Doctrine, no Eloquent equivalent. The closest thing is the **shipped** `waffle-commons/data` component (RFC-022, Universal Data & Persistence Layer, landed in Beta-3), and even that explicitly rejects Active Record and Identity Map patterns in favor of stateless Semantic Query Representation trees.
- **No view layer.** No Twig, no Blade. Controllers return PSR-7 responses; JSON is the assumed interchange.
- **No native validation library.** Validation lives inside PHP 8.5 Property Hooks on `#[Dto]`-tagged constructor parameters. `ControllerArgumentResolver` hydrates the DTO from the parsed body; Property Hook failures surface as RFC 7807 `422` via `ValidationException`. (Beta-4 adds an injectable, mockable `ValidatorInterface` wrapping the static `Assert` facade for userland services, but the framework's own validation logic still lives in Property Hooks.)
- **No facades, no static helpers, no global container.** Every dependency is passed by constructor or resolved through the PSR-11 container under a specific interface key.
- **No `$_SESSION`, no `session_start()`.** Session state is, by mandate, exclusively the per-browser `WAFFLE_SID` cookie issued by `AnonymousSessionMiddleware` — an opaque, anonymous identifier, never a server-side session store.
- **No mass-assignment surface.** The DTO is `final readonly`; the argument resolver pre-checks each parsed body value against the DTO constructor's declared parameter type *before* construction, so a native `\TypeError` can never propagate from a hook.
- **No fail-open default anywhere.** Missing voter → 403. Missing CSRF token → 403. Missing trusted-host config → boot refused in prod. Missing CSRF secret in prod → boot refused. Missing route → 404 (typed, not 500). Method not allowed → 405 (typed, with `Allow` header).

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

The analytical point is that the five levels map almost one-to-one onto the five evolutions defended in §2 (L1 → §2.1, L2 → §2.2, L3 → §2.5 in practice, L4 → fail-closed security, L5 → worker-safety + the Zero-Debt protocol of §2.3, which the labs *enforce* on every solution). Where §2.4 argues that Waffle ships its operating procedures **for AI** as committed code (`.opencode/skills/`), the academy is the **human-cognitive counterpart**: operating procedures for *people*, shipped as committed, test-gated, versioned curriculum that releases in the same wave. Both encode the same thesis; one is read by an assistant, the other is learned by hand.

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

**Why this is an evolution.** PHP's traditional execution model — boot, serve one request, die — is what most of the language's libraries are written for. Forcing every existing library to be worker-safe is a multi-year migration. Waffle does not migrate; it starts fresh, on the worker-safe contract, and refuses to ship anything that violates it. The result is a framework whose sub-millisecond response time is not aspirational; it is the natural consequence of the architecture.

Symfony 7 *can* run under FrankenPHP worker mode (and does, increasingly). Laravel Octane offers similar functionality. But both must paper over decades of stateful libraries, third-party bundles, and ORM connection lifecycles written before the worker model existed. Waffle ships zero such legacy.

**Beta-5 deepens this evolution from *survival* to *exploitation*.** Once a framework is genuinely worker-resident, the resident process is an asset to exploit, not merely a constraint to respect — and Beta-5 cashes that in. **Ahead-of-Time compilation** (RFC-019) compiles the DI graph into a `CompiledContainer` and the `#[Route]` table into a `RouteTrie`, both loaded at worker boot behind `WAFFLE_AOT=1` with a transparent reflection fallback, removing runtime reflection from the hot path; a snapshot test proves the compiled service graph identical to the runtime one. **Fiber-based finish-request deferral** (RFC-015, the new `async` component) runs short post-response work — mail, audit writes, webhooks — after the response is flushed but before the worker takes its next request, under a bounded budget that explicitly refuses to masquerade as a real queue. **Memory-resident connection pooling** (RFC-022 / DBAL) borrows a PDO or Redis handle at request start and returns it at request end, healing severed connections on lease (`SELECT 1` / ping before dispense), with a transaction-isolation middleware that rolls back on any uncaught error so no lock leaks between worker iterations. None of these make sense under classic boot-per-request PHP; every one of them is a dividend of having committed to the worker model *first* — and the same `wfl igor` 0-KO audit that polices statelessness polices them too.

### 2.3 Zero-Debt static analysis as a baseline expectation

The *Mago Purge Protocol* (`docs/explanation/mago-purge-protocol.md`) is unusually severe for the PHP world:

> Every component, on every commit, must pass: `mago fmt --check`, `mago lint`, `mago analyze`, `mago guard` with **zero errors, zero warnings, zero notices, zero hints**, and **no baseline files**.

The "no baseline files" clause is the key. Mago supports `mago-*-baseline.toml` files that snapshot existing issues so a project can adopt the tool gradually; Waffle forbids them outright. The reasoning is the same as the zero-warning policy: *a baseline file is institutional permission to leave issues unfixed*. If a finding genuinely cannot be addressed, the right fix is a narrowly-scoped `[analyzer.ignore]` entry in the component's `mago.toml`, with a code comment pointing at the issue — a documented, reviewable, narrow exception, not a swallow-everything snapshot.

The twin rule, enforced by `coverage.sh`, is **≥95% PHPUnit coverage** on every component. Together they form what the project calls the "Zero-Debt" guarantee.

There is a specific architectural payoff: `mago guard` is configured per component in `mago.toml` to enforce the **Component Agnosticism rule** (every component imports only from `waffle-commons/contracts` and declared PSR packages). The dependency perimeter is enforced mechanically. A PR that adds `use Waffle\Commons\Routing\Router;` inside `security/src/` fails CI before it can be reviewed.

**Why this is an evolution.** Threshold-based gates teach contributors that warnings are background noise; within a year you have 200 of them and one new genuinely-important one nobody can find. Zero-warning policy makes every new warning *visible* — it breaks the build the instant it lands. The cost is paid once: scrubbing the existing codebase to zero. Then it amortizes across every future PR.

This level of discipline is unusual in PHP — Symfony and Laravel both have internal quality bars, but neither makes "zero of everything" a public contract. Waffle treats it as the entry condition for the ecosystem. The same discipline is normal in Rust (`cargo clippy -D warnings`) and Haskell (`-Werror`); Waffle ports the expectation to PHP without compromise.

### 2.4 AI-cognitive tooling as a first-class repository artifact

This is the most unusual feature of the Waffle umbrella. Open the repo and you find:

- **`AGENTS.md`** — the central operating spec for *any* AI assistant. Defines the PHP 8.5 coding standards, the FrankenPHP statelessness mandate, the Mago Purge Protocol, the language policy (English for framework, French for `skeleton/` and `workspace/` template apps), and the Skills Routing Table.
- **`CLAUDE.md`** — a thin CLI router that redirects to `AGENTS.md` and the skill files. Does not duplicate standards.
- **`.opencode/skills/`** — **29 specialized skill prompts**, each in its own `SKILL.md`, grouped by intent (the full Routing Table lives in `AGENTS.md`):
  - **Core workflow:** `tech-lead` (the orchestrator entry point), `coding`, `refactoring`, `test`, `code-review`, `maker-scaffold` (RFC-020 — controllers, DTOs, middleware, voters, commands, HTTP clients, event pairs).
  - **Quality gates & worker-mode:** `mago-purge` (Zero Baseline enforcement), `worker-safety` (`wfl igor` remediation), `contracts-first` (interface sequencing + `mago guard` perimeter), `benchmark-gate` (GC/memory/AOT/pool gates).
  - **Security:** `security-audit` (statelessness, ABAC, SSRF, CORS, traversal, `#[PublicAccess]`), `auth-bridge-audit` (RFC-021 — JWT, OAuth2/OIDC, HMAC assertions, API keys; fail-closed, stateless).
  - **Data & persistence:** `data-persistence` (RFC-022 — SQR, stateless pools, Firestore paths, atomic flat-file, CRUD mappers).
  - **Docs, scaffolding & release:** `diataxis-doc`, `component-scaffold`, `release-manager`, `release-wave`, `demo-app-wiring`, `roadmap-steward`.
  - **Runtime maturity (Beta-5 — now shipped):** `aot-compilation` (RFC-019), `async-concurrency` (RFC-015), `observability` (RFC-005), `reactive-broadcast` (RFC-018), `webauthn-passkeys` (RFC-021 / AUTH-01) — these five were the "not yet built" roadmap-forward skills of the Beta-4 reading and are now backed by shipped components.
  - **Roadmap-forward** (operating procedures staged *ahead* of the code, each still flagged "not yet built"): `resilience-net`, `queue-worker`, `api-surface`, `k8s-ops`, `testing-bridge` (beta6).
- **`.opencode/agents/`** — **14 focused subagents** (`mode: subagent`) the skills dispatch as single-component workers: `coding-worker`, `coding-integrator`, `docgen-worker`, `gate-runner` (runs `composer mago && composer tests` + `composer igor`), `mago-fixer`, `test-author`, `worker-safety-auditor`, `security-auditor`, `contracts-sync`, and the Beta-5 additions `aot-verifier`, `benchmark-runner`, `demo-wiring-worker`, `flake-hunter`, `webauthn-auditor`.

Each skill encodes operating procedures that override generic AI defaults. The routing directive in `CLAUDE.md` is binding: *"if the user's request matches a specialised skill, the assistant MUST read the corresponding `SKILL.md` before planning or acting."*

The `tech-lead` skill's "Orchestration protocol" reads like a software engineering manager's playbook:

> 1. **Triage:** Decide whether the task requires `coding`, `refactoring`, or `test` skills. For anything touching `project_system/` direction, consult `roadmap-steward` first.
> 2. **Plan before acting:** Identify which of the 23 submodule components are affected. Sequence contracts-first (`contracts-first` skill) — any new interface lands in `waffle-commons/contracts` before its consumer. Verify dependencies only point to `contracts` (+ `utils`).
> 3. **Execute:** Load `coding` or `refactoring`. Ensure strict PHP 8.5 types, Property Hooks, and stateless design for FrankenPHP (`worker-safety` skill).
> 4. **Test:** Load `test`. Ensure PHPUnit 12.5 coverage is >=95%.
> 5. **Review:** Load `code-review`. Verify PSR compliance, zero-output Mago, and `wfl igor` 0 KO.

Crucially, **the umbrella also ships per-RFC AI skills**. RFC-020 (Waffle Maker) ships `maker-scaffold`. RFC-021 (Universal Authentication Bridge) ships `auth-bridge-audit`. RFC-022 (Universal Data & Persistence Layer) ships `data-persistence`. These are not generic prompts; they encode the specific security boundaries, cryptographic protocols, and architectural patterns of their RFCs.

**Why this is an evolution.** Frameworks have always shipped human documentation. Most projects in 2026 *also* generate AI-friendly summaries out-of-band. Waffle treats AI operating procedures as **committed code**, versioned alongside the framework, releasable in lockstep, and reviewable as PRs. The result is that an AI assistant working in this repository has access to the same project knowledge a senior engineer would — encoded as `SKILL.md` files, not as folklore.

This is genuinely novel. It is also fragile: a stale `SKILL.md` is worse than none, because it confidently misleads. The umbrella addresses that by requiring `@waffle-commons/waffle-core` review on every skill change (see `CODEOWNERS`) and by treating skills as part of the release wave.

**Caveat for honesty.** The "AI-cognitive tooling as a first-class artifact" evolution is one Waffle is *betting on*, not one the broader PHP ecosystem has collectively adopted. Whether this becomes industry practice depends on whether AI-driven development sustains, and whether `.opencode/`-style skill repositories become recognized as a documentation genre. Today they are unusual; tomorrow they may be expected. Waffle is positioning early.

### 2.5 Component Agnosticism as a mechanical invariant

The repo's component layout enforces a single rule with surprising rigor: **every component depends only on `waffle-commons/contracts`** (plus declared PSR packages and, as a special case, `waffle-commons/utils` for pure-function helpers — `utils` itself has zero inter-component dependencies).

`security` cannot import `Waffle\Commons\Routing\Router`. It can import `Waffle\Commons\Contracts\Routing\RouterInterface`. The concrete implementation is wired in by the application (`AppKernelFactory`); the component itself talks to the abstraction. `mago guard`, configured per component in `mago.toml`, refuses any PR that violates this rule.

This is documented in [`docs/explanation/component-agnosticism.md`](docs/explanation/component-agnosticism.md) with three reasons:

1. **Independent releasability.** If `security` required `routing`'s concrete class, then `composer require waffle-commons/security` would drag in `routing` whether you wanted it or not. Real consumers of `security` (for example, an app that wants ABAC but has its own router) would be forced into a router they didn't choose.
2. **Decoupled evolution.** With contracts only, the surface that can break is the *contract* — a deliberate, visible, ecosystem-wide event. Beta-1 changed `CsrfTokenManagerInterface::issue/validate/refresh` to accept a `$sessionId` argument; that single change cascaded through the wave and was documented in the contracts CHANGELOG.
3. **Testability.** `security`'s tests mock `RouterInterface`. They never instantiate `Router`. The test suite never depends on `routing`'s tests passing.

The rule has one deliberate exception: `RouteNotFoundException` is concrete and lives in `contracts`, because `CoreRoutingMiddleware` (in `pipeline`) needs to *throw* it, and the only alternative places (a sibling component) would re-create the dependency loop. Hoisting one concrete exception into `contracts` is the smallest possible violation; it pays for itself by letting every component throw and catch the same class. Beta-2 extends this exception to `MethodNotAllowedException` for the same reason (typed `405` handling end- to-end).

**Why this is an evolution.** Most frameworks declare independence as aspiration. Waffle declares it as **a build-time CI gate**. A graph of 21 components, each releasable independently to Packagist, each individually composable into someone else's framework — that's a genuinely different shape from a Symfony bundle ecosystem or a Laravel package collection. Symfony bundles depend on the kernel; Laravel packages tend to depend on Illuminate. Waffle components depend on nothing concrete from each other, ever, by construction.

The trade-off: every shared symbol must justify its existence in `contracts`. Adding to `contracts` is an ecosystem-wide event. This is friction, and it is the right kind of friction.

***

## 3. What Waffle Deliberately Doesn't Try To Be

A clear-eyed picture of any framework requires being explicit about what it *isn't*. Waffle is unusually clear about its non-goals.

### 3.1 It is not a Symfony replacement

Symfony's value proposition includes Twig, Doctrine, the Form component, the Messenger system, the Mailer, the Security bundle's firewall ladder, Maker bundle, Symfony Console (with autoload-aware commands), the Validator, Notifier, Translator, Workflow, and a 20-year ecosystem of bundles. Waffle ships **none** of those. Its `console` component is intentionally "zero-magic" — commands are registered explicitly, not auto-discovered from random bundles. There is no Twig analog. There is no Doctrine analog: `waffle-commons/data` (RFC-022) *has* shipped — it landed in the Beta-3 wave and gained worker-resident PDO/Redis connection pooling + transaction-isolation middleware in Beta-5 — but it is a stateless query/persistence layer that explicitly rejects Active Record and Identity Map, not an ORM.

If you're building a CMS, a B2B SaaS with role-based admin, an internal tool that needs forms-and-views, Symfony is the answer. Waffle would force you to build half a framework on top.

### 3.2 It is not a Laravel replacement

Laravel ships Eloquent (an Active Record ORM), Blade (a templating engine), the facade DSL (statically-callable singletons), broadcasting, queues with Horizon, Scout, Cashier, Telescope, Nova/Filament admin generators, and *ergonomics* — the perception that any common task is one expressive line of PHP. Waffle ships none of that, and its statelessness mandate is philosophically *incompatible* with facades (which rely on globally-resolved singletons).

If you want to ship a SaaS in two weeks with batteries-included tooling, Laravel is the answer. Waffle would force you to assemble the batteries yourself.

### 3.3 It is not a stable, production-recommended framework yet

`README.md` is explicit: *"beta software — production use requires an independent security audit."* The `documentation/README.md` adds a prominent warning. Beta-1 made one breaking change at the contracts surface (`CsrfTokenManagerInterface` gained a `$sessionId` parameter); Beta-2 is purely additive (the typed `405`/`OPTIONS`/`Allow` HTTP-correctness wave). The trajectory is clearly toward 1.0, but the project is not there yet.

### 3.4 It is not a one-person-can-maintain-all-of-it framework

The release wave is documented as essentially mechanical (`./loop.sh composer mago && ./loop.sh composer tests && ./coverage.sh && tag each component in topological order → bump umbrella submodule pointers → tag the umbrella → `release-wave.yml` fans out`), but it still touches 21 components. One contributor running the full wave is feasible; one contributor running the *entire* ecosystem long-term is not. Waffle needs an organization, and at beta its CODEOWNERS is `@waffle-commons/waffle-core` — a team identifier, not an individual.

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
  |  (Ultra-fast local validation)        |       |   of Signed Assertion Headers      |
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

- New traffic, modern endpoints, security-sensitive paths → handled by Waffle directly. Fail-closed ABAC, stateless HMAC CSRF, RFC 7807 errors, sub- millisecond response times in resident worker mode.
- Legacy paths → proxied through the streaming PSR-18 HTTP client, with an HMAC-signed `X-Wfl-Assert-User` header injected so the legacy monolith can hydrate a virtual user session without re-authenticating. 5-second TTL, IP-bound, constant-time `hash_equals()` verification, fail-closed on missing secret.
- Over time, legacy paths are reimplemented as Waffle controllers and removed from the catch-all route. The legacy monolith shrinks; Waffle grows; the public API is preserved end-to-end.

This is the canonical Strangler-Fig migration, executed in PHP, with the new piece being the **strict, secure, fast** piece. Symfony and Laravel are the legacy in this story not because they are bad — they are excellent — but because they predate the FrankenPHP-native, statelessness-mandated, Zero-Debt era. They will continue to evolve; Octane and FrankenPHP integration in Symfony are good evidence of that. But neither can ship the worker-native contract as foundationally as a from-scratch design can.

Where Waffle fits:

- **The edge.** API gateways, identity proxies, rate limiters, fail-closed policy enforcement points, signing relays, audit collectors.
- **High-throughput JSON APIs.** Sub-millisecond per-request budgets, bounded memory, no boot overhead.
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

Waffle has 21 framework components plus skeleton, workspace, academy, template, and documentation. Symfony has 50+ bundles, hundreds of community packages, and a 20-year compounding flywheel. Laravel has Cashier, Scout, Horizon, Telescope, Sanctum, Passport, Nova, Filament, Octane, and an order-of-magnitude bigger community-package marketplace.

For Waffle to succeed in any market beyond the edge/gateway niche, it needs either (a) deeper batteries — the RFC-022 data layer and the RFC-021 auth bridge (incl. OAuth2/OIDC, and now WebAuthn passkeys) have *shipped*, and the Beta-5 wave added RFC-015 async, RFC-005 observability (the `telemetry` Prometheus endpoint + the `telemetry-otel` OpenTelemetry bridge), RFC-019 AOT compilation, RFC-018 reactive broadcast, and the RFC-022 connection-pooling / transaction-isolation layer; what remains roadmap-forward is RFC-016 OpenAPI auto-doc + serializer, RFC-017 rate limiter / circuit breaker, the RFC-015-boundary queue/worker, and the RFC-012 testing bridge (all beta6) — or (b) explicit interoperability with Symfony/Laravel components where the use case allows. Both paths are slow.

### 5.2 The single-author signal

`composer.json` files across the components list a single author: Leslie Petrimaux. The git log of the umbrella reflects coordinated multi-component commits from one engineer. The CODEOWNERS team is `@waffle-commons/waffle- core`, but at the time of this analysis the public footprint suggests a small core.

This is normal for a beta-stage framework; Symfony and Laravel both started similarly. But it is a risk to flag: ecosystem velocity scales with contributor count, and the very strictness of the Mago Purge Protocol raises the bar to participation. A new contributor cannot land "good-enough" code; the gate is zero-everything.

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

### 5.6 The AI-tooling-as-code bet

Section 2.4 above identified `.opencode/skills/` as one of Waffle's evolutionary contributions. But this is a bet on a future where AI-assisted development is the dominant mode of contribution to PHP frameworks. If that future arrives, Waffle is well-positioned. If it does not — if AI tooling remains an external adjunct — then committing 27 skill files to a release becomes overhead without payoff.

The hedge: even in a future without AI, `AGENTS.md` is excellent human documentation, and the skill files double as engineering playbooks. The bet is asymmetric; the downside is small.

### 5.7 The pre-1.0 contract surface

Beta-1 broke one contracts interface (`CsrfTokenManagerInterface`). Beta-2 relocated the `Route` attribute from `routing` to `contracts`. These breaks are documented and small, but the project is explicit that interfaces *can* break until 1.0. A consumer adopting Waffle pre-1.0 must accept some churn.

After 1.0, the contracts surface stabilizes — but until then, integrators should pin to a specific beta wave and budget for upgrade work.

***

## 6. The Verdict

Is `waffle-commons` the future of PHP?

**Not in the sense of "the framework most PHP applications will use in 2030."** That seat is taken by Symfony for enterprise PHP and Laravel for product PHP, and there is no realistic path by which either is displaced by a stricter, narrower framework that explicitly disclaims their use cases. The maintainers do not even try to make that pitch.

**But yes, in the sense of "the framework that embodies the evolutions PHP itself is undergoing."** Specifically:

- **PHP 8.5 as a strict, hookable language.** Property Hooks + Asymmetric Visibility + typed constants + `final readonly` are language features that most existing libraries have not yet absorbed. Waffle is what a codebase looks like when those features are the default, not the exception. As more PHP code is written this way — and it will be, because the features are there — Waffle will look less like an outlier and more like the leading edge.
- **FrankenPHP-native resident workers as the default deploy target.** Symfony and Laravel both increasingly support worker mode, but they do not *mandate* it; their libraries must remain compatible with classic SAPI. Waffle mandates it, and the design choices that follow (stateless services, `ResettableInterface`, memory-bounded streaming, no superglobals, no `$_SESSION`) are what the language has been waiting for. Resident-worker PHP is genuinely the future deploy target; Waffle is what an entire codebase optimized for it looks like.
- **Zero-Debt static analysis as a baseline.** Rust, Haskell, Kotlin, and Swift treat zero warnings as table stakes. PHP has historically been more forgiving. Waffle ports the strict expectation to PHP without compromise. As the broader PHP ecosystem matures toward stricter typing — PHPStan and Psalm adoption are both growing fast — Waffle's stance becomes the baseline, not the outlier.
- **AI-cognitive tooling as committed code.** This is a more speculative bet, but a plausible one. As AI-assisted development becomes routine, projects that ship explicit operating procedures for AI assistants will produce more consistent contributions than those that don't. Waffle's `.opencode/skills/` layer is an early, well-thought-out instance of what the practice will eventually look like across the ecosystem.
- **Component Agnosticism as a mechanical invariant.** Symfony bundles are loosely coupled to the kernel; Laravel packages are loosely coupled to Illuminate. Waffle components are tightly coupled to `contracts` and to nothing else, enforced by `mago guard`. This is a different architectural shape — one that allows individual components to be lifted into other frameworks, used independently, and evolved on their own cadence. It is not the dominant shape today, but it is what every "the components are the framework" pitch (Symfony Components, Illuminate Components) has aimed at for years. Waffle delivers it without the residual coupling.

The honest framing is this: **Waffle is not a destination; it is a direction. It is the most coherent executed example of where strict, secure, fast PHP is going, packaged in a single repository, with mechanical enforcement of the choices that direction requires.** Symfony and Laravel will continue to lead mass-market PHP; they will adopt some of these evolutions on their own schedules, constrained by their installed bases. Waffle will continue to lead the strict edge: the gateway in front of the monolith, the proxy that signs HMAC assertions, the rate limiter that fails closed, the audit collector that streams 8 KiB chunks under a worker that never blocks.

In that sense — Waffle as **evolutionary pressure** on the rest of the PHP ecosystem, not as displacement — yes, `waffle-commons` is part of the future of PHP. Whether you adopt it, or whether you adopt the pieces of it that suit your context, the direction is correct: PHP is becoming stricter, PHP is becoming worker-native, PHP is becoming zero-debt-by-default, PHP is becoming AI-tool-aware, PHP is becoming component-agnostic.

Symfony and Laravel will get there too, on different timelines. Waffle is already there, in a single, lockstep-released, beta-quality, twenty-one-component proof — and, with the `academy`, it ships those five evolutions as a teachable, test-gated curriculum, so the direction is not merely demonstrated but transmissible. The Beta-5 wave is the inflection where the proof stops being only about *strictness* and starts being about *runtime maturity*: AOT compilation, Fiber finish-request concurrency, reactive write-hook broadcasting, memory-resident pooling, contract-first telemetry, and native passkeys — the high-performance HTTP runner has become an event-driven, reactive, AOT-optimized application runtime, without surrendering a single line of the statelessness or Zero-Debt mandate.

That is not "the future of PHP." That is **a future of PHP**, demonstrated. And it is enough.

***

## Appendix A — How to read this document

If you are evaluating Waffle for a specific use case:

| Use case                                       | Read first                                                                                  |
|------------------------------------------------|---------------------------------------------------------------------------------------------|
| "Should I migrate my Symfony app to Waffle?"   | §3.1, §3.5, §4 (the answer is almost certainly **no** — coexist instead)                    |
| "Should I build a new SaaS in Waffle?"         | §3.2, §4 (the answer is **probably not** unless the SaaS is API-only and edge-shaped)       |
| "Should I build an API gateway in Waffle?"     | §2.2, §4 (the answer is **yes**)                                                            |
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

Where this document quotes Waffle's source or documentation, the quotes are verbatim from the listed files at the `0.1.0-beta5` release.
