# AGENTS.md — Waffle-Commons Central Brain

The single source of truth for **how any AI assistant must behave** in the `waffle-commons`
monorepo (PHP 8.5, FrankenPHP resident-worker, independent submodules each released to Packagist).
`/CLAUDE.md` is only a CLI router — operational standards live here.

> **Read order for every task:** this file → the matching `.opencode/skills/<skill>/SKILL.md`
> (see the Routing Table). When in doubt, start with `tech-lead`.

---

## 1. PHP 8.5 Strict Coding Standards (non-negotiable)

- **Strict types:** `declare(strict_types=1);` is the first statement of every PHP file.
- **No `mixed`:** forbidden without explicit architect approval — solve the type, never widen.
- **Typed constants:** `public const string FORMAT = 'json';`
- **Property Hooks for validation** (no legacy getters/setters):
  ```php
  public string $email {
      set(string $value) {
          if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
              throw new ValidationException('Invalid email');
          }
          $this->email = $value;
      }
  }
  ```
- **Asymmetric visibility + `readonly`** for DTOs:
  ```php
  readonly class UserDto {
      public function __construct(
          public private(set) string $id,
          public private(set) string $name,
      ) {}
  }
  ```
- **`#[\Override]`** on every method implementing/overriding an interface or parent.
- **Fail-secure errors:** never silence with `@`; never catch generic exceptions needlessly. Throw
  specific domain exceptions (`ValidationException`, `SecurityException`) — `ErrorHandlerMiddleware`
  transforms them.
- **Language:** all comments, identifiers, and emitted logs/exceptions in framework
  components are **English**. The **only** exceptions are the template-app
  directories — **`skeleton/`, `workspace/` AND `academy/`** (the last including its
  `docs/`, `labs/`, and `sandbox/` submodules) — where every comment, docblock,
  YAML/TOML/compose comment, and user-facing string is **French**. Code, namespaces,
  and contracts stay English even there (e.g. `Waffle\Academy\Labs\…`). Where an RFC
  requests French in a framework component (e.g. RFC-021 §6.3, RFC-022 §7.4), project
  policy is English outside those template dirs.

## 2. FrankenPHP Statelessness Mandate

Services must be **stateless and resettable** across requests (resident-memory worker mode):

- **No `$_SESSION`, no `session_start()`,** no native PHP session functions.
- **No superglobals** (`$_SERVER`, `$_GET`, `$_POST`, …) — use injected PSR-7
  `ServerRequestInterface` or `GlobalsFactory`.
- **No mutable static / singleton state** surviving a request; request-scoped services release on
  `$kernel->reset()` (implement `ResettableInterface` where applicable).
- **No `sys_get_temp_dir()`** or other ambient global state.

## 3. The Mago Purge Protocol (zero-baseline)

- **Clean = ZERO output:** `composer mago` is green only when it emits **no errors, no warnings, no
  info, and no help/notice messages**. A "warning" or "info" line is a failure, not an FYI — fix it.
- **Zero baselines:** `mago-*-baseline.toml` files are forbidden — scan for and delete them. We fix
  findings; we never suppress them.
- **Native solution first:** resolve every `analyze`/`lint`/`guard` finding with a proper PHP 8.5 type
  or refactor — not `@var` band-aids, ignore annotations, `mixed`, or baselines. (Inherent `mixed`
  from `json_decode` may use a single scoped `@var` narrowing — see the `mago-purge` skill.)
- **Guard perimeter (`mago guard`):** no circular dependencies, no illegal cross-component imports.
  **Every component depends ONLY on `waffle-commons/contracts`** — plus `waffle-commons/utils` (the
  shared foundation, which itself requires only `contracts`). Never a sibling's concrete classes; push
  reusable primitives down into `utils`.
- **Done = green:** `composer mago && composer tests` (PHPUnit 12.5, ≥95% coverage) pass for every
  modified component, in Docker, **and** `wfl igor` reports 0 KO (see §5).

## 4. Architecture & PSR

- **Monorepo of submodules** — each its own Git repo / Packagist release. The set grows each wave, so
  enumerate the live list with `scripts/list-components.sh` (parsed from `.gitmodules`) rather than a
  hardcoded count. Beta5 added `telemetry`, `telemetry-otel`, and the local `async` component:
  - **Framework:** `contracts`, `utils`, `waffle`, `runtime`, `pipeline`, `routing`, `http`,
    `http-client`, `security`, `auth`, `data`, `cache`, `container`, `config`, `console`, `log`,
    `event-dispatcher`, `error-handler`, `telemetry`, `telemetry-otel`, `async`.
  - **Template / docs:** `skeleton`, `workspace`, `academy`, `documentation`, `component-template`.
  - **Planned (beta6):** `queue`, `openapi`, `serializer`, `testing` — each scaffolded from
    `component-template` (see the `component-scaffold` skill).
- **PSR enforcement:** PSR-15 middleware, PSR-14 events, PSR-3 logging, PSR-7/17 HTTP messages &
  factories, PSR-18 HTTP client.
- **Contracts-first sequencing:** every new interface lands in `waffle-commons/contracts` **before**
  its consuming component; the `mago guard` perimeter is non-negotiable. See the `contracts-first`
  skill (and mind the vendor-contracts skew it documents).
- **Documentation (Diátaxis):** lives in `documentation/` — `tutorials/`, `how-to/`, `reference/`,
  `explanation/`. See the `diataxis-doc` skill.

## 5. Worker-Safety Gate (`wfl igor` — igor-php 0.7)

FrankenPHP keeps services resident, so state that leaks across requests is a bug. `wfl igor`
(`composer igor` per component) audits this and is part of the definition of done:

- **0 KO required.** igor grades each stateful class **KO** / **WARN** / OK — **only KO fails the
  gate** ("Mutation of state '<prop>' in <method>()"); WARN passes.
- **`#[WorkerSafe]`** (`IgorPhp\IgorBundle\Attribute\WorkerSafe`) marks a property/class as an
  audited, intentional exception. Adding it requires the component's `mago.toml` guard to permit
  `IgorPhp\IgorBundle\Attribute\**`.
- **Resettable must be DIRECT.** A class that mutates per-request state passes only if it **directly**
  declares `implements ResettableInterface` in its class clause — igor does a *shallow* scan, so
  inheriting it transitively through a parent interface does **not** satisfy the gate.
- **Remediation taxonomy** (per the `worker-safety` skill): direct `ResettableInterface` + `reset()`
  · ctor-`readonly` · inline (no field) · `#[WorkerSafe]`. Never paper over a real leak.

---

## 5b. Release train & source of truth

`project_system/` (RFCs + Roadmaps) is the **direction** source of truth — consult it, don't invent.

| Release | Theme | Roadmap |
|---|---|---|
| `0.1.0-beta4` | Security & stability (current work) | `Roadmap_Beta4.md` |
| `0.1.0-beta5` | AOT · pooling · async · telemetry (+spikes) | `Roadmap_Beta5.md` |
| `0.1.0-beta6` | Production surface — `queue` · `openapi` · `serializer` · `testing` · NET · OPS | `Roadmap_Beta6.md` |
| `0.1.0-beta7` | Consolidation & API freeze | `Roadmap_Beta7.md` |
| `1.0.0-RC1` → `1.0.0` | Freeze cert + EcoShield-Gateway soak → Gold | `Roadmap_RC1.md` / `Roadmap_V1_Gold.md` |

- **Version stamps:** `0.1.0-betaN` — **no `v` prefix** (the tag gate rejects it). Fix the *current*
  stamp; never bulk-bump historical CHANGELOGs. See the `roadmap-steward` skill.
- **Release mechanics (umbrella wave):** one `pre-release/<version>` branch per component → umbrella
  tag pushed to the remote → dispatch **dry-run on the pushed tag** (`ref:<tag>` must already exist) →
  LIVE wave. Per-component steps live in `release-manager`; the orchestration lives in `release-wave`.

## 🧠 Specialized AI Skills — Routing Table

**SELF-DIRECTIVE:** if a request matches a skill below, **READ that `SKILL.md` BEFORE planning or
acting**. These files carry component-specific operating procedures that override general defaults.
When unsure, default to **`tech-lead`** (it orchestrates the others). All skill files live under
`.opencode/skills/<name>/SKILL.md`.

**Core workflow**

| Skill | Trigger / Use when… |
|-------|---------------------|
| `tech-lead` | Entry point for non-trivial / multi-skill / ambiguous work; sequences coding→test→review. |
| `coding` | Implement a feature or bug fix across the components. |
| `refactoring` | "Refactor / clean up / restructure" — needs a green test baseline first. |
| `test` | Add/improve PHPUnit 12.5 tests; target ≥95% coverage. |
| `code-review` | "Review my changes" / pre-merge sanity (per-component diff). |
| `maker-scaffold` | "Scaffold / make a controller, DTO, middleware, voter, command, HTTP client, event pair" via Waffle Maker (RFC-020). |

**Quality gates & worker-mode**

| Skill | Trigger / Use when… |
|-------|---------------------|
| `mago-purge` | Fix Mago findings to ZERO output; eradicate baselines; harden types (native-first). |
| `worker-safety` | `wfl igor` is KO; `#[WorkerSafe]` / direct `ResettableInterface`; reset-per-request leaks. |
| `contracts-first` | New interface sequencing; `mago guard` perimeter (contracts + utils); vendor-contracts skew. |
| `benchmark-gate` | Benchmark-gated items (GC churn, memory curve, AOT/pool/telemetry overhead) → `…-GATE-RESULT.md`. |

**Security**

| Skill | Trigger / Use when… |
|-------|---------------------|
| `security-audit` | Statelessness, fail-closed ABAC, SSRF (SEC-02), CORS, traversal, `#[PublicAccess]`, SEC-03 compare-audit. |
| `auth-bridge-audit` | Universal Authentication Bridge (RFC-021, `auth`): JWT, OAuth2/OIDC, HMAC assertions, API keys. |
| `webauthn-passkeys` | WebAuthn / passkeys (RFC-021 AUTH-01, `auth`): `WebAuthnLibAdapter` (sole lib importer), stateless authenticator, app-provided challenge store, configurable UV, fail-closed. |

**Data & persistence**

| Skill | Trigger / Use when… |
|-------|---------------------|
| `data-persistence` | Universal Data & Persistence Layer (RFC-022): SQR, CRUD mappers, atomic flat-file, Firestore paths, and the shipped DBAL pooling (generalized pool contract, PDO/Redis pools, request-scoped connection affinity, `TransactionIsolationMiddleware`). |

**Docs, scaffolding & release**

| Skill | Trigger / Use when… |
|-------|---------------------|
| `diataxis-doc` | "Write/document" → Diátaxis docs with exact PHP 8.5 signatures + version stamps. |
| `component-scaffold` | "Create a new component / bootstrap a package" from `component-template`. |
| `release-manager` | Per-component release steps within the umbrella wave (Packagist). |
| `release-wave` | Orchestrate a full multi-component umbrella release (tag → dry-run → LIVE). |
| `demo-app-wiring` | Wire a shipped feature into `skeleton` / `workspace` / `academy` (vendor skew, French, routes). |
| `roadmap-steward` | Maintain `project_system/` RFCs & Roadmaps as the direction source of truth. |

**Beta5 — shipped capability skills (live operating procedures, code exists)**

| Skill | Trigger / Use when… | Source |
|-------|---------------------|--------|
| `aot-compilation` | AOT build: graph-identical compiled container + router-trie preheat; `WAFFLE_AOT=1` fast-path + reflection fallback. | beta5 AOT (RFC-019) |
| `async-concurrency` | Fiber finish-request deferral (`async`) + concurrent HTTP-client fan-out (`ConcurrentClientInterface`). | beta5 ASYNC (RFC-015) |
| `observability` | Contract-first `TracerInterface` + OTel bridge (`telemetry-otel`) + Prometheus `/waffle-metrics` (`telemetry`). | beta5 OBS (RFC-005) |
| `reactive-broadcast` | `#[Broadcast]` write-hooks → request-scoped buffer → finish-request SSE flush; no I/O in the hook. | beta5 REACTIVE (RFC-018) |

**Roadmap-forward (operating procedures staged ahead of the code — flagged "not yet built")**

| Skill | Trigger / Use when… | Roadmap |
|-------|---------------------|---------|
| `resilience-net` | Rate limiter, retry/backoff, circuit breaker. | beta6 NET (RFC-017) |
| `queue-worker` | Background processing (`queue` component, Redis Streams). | beta6 QUEUE (RFC-015) |
| `api-surface` | OpenAPI generation + DTO serializer / content negotiation. | beta6 API (RFC-016) |
| `k8s-ops` | Health/readiness probes, graceful drain, migration maturity. | beta6 OPS (RFC-014) |
| `testing-bridge` | `WaffleTestCase` in-process kernel + test doubles. | beta6 TEST (RFC-012) |

## 🤖 Subagents (`.opencode/agents/<name>.md`, `mode: subagent`)

Skills dispatch focused single-component workers. Available: `coding-worker`, `coding-integrator`,
`docgen-worker`, **`gate-runner`** (run `composer mago && composer tests` + `composer igor`, report
green/red), **`mago-fixer`** (purge to zero output), **`test-author`** (PHPUnit 12.5 ≥95%),
**`worker-safety-auditor`** (`wfl igor` remediation + DBAL-pool reset/affinity audit), **`security-auditor`**
(security checklist + SSE-injection + WebAuthn checks), **`contracts-sync`** (mirror fresh `contracts/src`
into a consumer `vendor/`; see `wfl sync:contracts`).
**Beta5 additions:** **`benchmark-runner`** (baseline → load → `…-GATE-RESULT.md`), **`flake-hunter`** (loop
phpunit, isolate the flaky testcase from JUnit; knows the leading-zero-keypair class), **`demo-wiring-worker`**
(wire one shipped feature into one app — workspace symlink / skeleton rsync), **`aot-verifier`**
(`container:compile`/`route:compile` + graph-identity snapshot + `WAFFLE_AOT` fast-path/fallback),
**`webauthn-auditor`** (passkey UV / challenge-binding / sign-counter clone-detection / statelessness audit).
