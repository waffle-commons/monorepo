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
  modified component, in Docker, **and** `wfl igor` reports 0 KO (see §5). "Pass" means a clean
  `OK (…)` verdict: a run ending `OK, but …` (PHPUnit issues, skipped, incomplete or risky tests) is not
  green, even though PHPUnit exits 0 — `wfl dod` and `wfl check:all --with-tests` reject it
  (`scripts/phpunit-verdict.sh`).

## 4. Architecture & PSR

- **Monorepo of submodules** — each its own Git repo / Packagist release. The set grows each wave, so
  enumerate the live list with `scripts/list-components.sh` (parsed from `.gitmodules`) rather than a
  hardcoded count. Beta5 added `telemetry`, `telemetry-otel`, and the local `async` component:
  - **Framework:** `contracts`, `utils`, `waffle`, `runtime`, `pipeline`, `routing`, `http`,
    `http-client`, `security`, `auth`, `data`, `cache`, `container`, `config`, `console`, `log`,
    `event-dispatcher`, `error-handler`, `telemetry`, `telemetry-otel`, `async`.
  - **Template / docs:** `skeleton`, `workspace`, `academy`, `documentation`, `component-template`.
  - **Beta7 (scaffolded 2026-09-29, code lands this release):** `queue`, `openapi`, `serializer`,
    `testing` — each configured from `component-template` (see the `component-scaffold` skill); tests
    and coverage switch on with their first class. **Beta6** added no new packages —
    the `ecoshield-gateway` reverse-proxy POC lives in its own repository outside this monorepo
    (checked out at `contributions/ecoshield-gateway/`, gitignored here), is deliberately absent from
    the release wave, and is the v1 adoption dogfood — see the `ecoshield` skill.
- **PSR enforcement:** PSR-15 middleware, PSR-14 events, PSR-3 logging, PSR-7/17 HTTP messages &
  factories, PSR-18 HTTP client.
- **Contracts-first sequencing:** every new interface lands in `waffle-commons/contracts` **before**
  its consuming component; the `mago guard` perimeter is non-negotiable. See the `contracts-first`
  skill (and mind the vendor-contracts skew it documents).
- **Documentation (Diátaxis):** lives in `documentation/` — `tutorials/`, `how-to/`, `reference/`,
  `explanation/`. See the `diataxis-doc` skill.

## 5. Worker-Safety Gate (`wfl igor` — igor-php, pinned by `.igor-version`)

FrankenPHP keeps services resident, so state that leaks across requests is a bug. `wfl igor`
(`composer igor` per component) audits this and is part of the definition of done:

- **One auditor version everywhere.** `vendor/bin/igor-php` is a bootstrapper that downloads
  `releases/latest` unless told otherwise, so the version lives in `.igor-version` (currently 0.9.7):
  `igor.sh`, `wfl dod` and every CI workflow seed it and fail when the resolved binary differs.
  `wfl ci:check` catches a CI pin that drifts from the file.
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
| `0.1.0-beta4` | Security & stability (shipped) | `Roadmap_Beta4.md` |
| `0.1.0-beta5` | AOT · pooling · async · telemetry · WebAuthn (shipped) | `Roadmap_Beta5.md` |
| `0.1.0-beta6` | Stabilization & audit (shipped) — multi-engine audits · Diátaxis docs · EcoShield POC · K6 benchmarking | `Roadmap_Beta6.md` |
| `0.1.0-beta7` | **Production surface (current work)** — `queue` · `openapi` · `serializer` · `testing` · NET · OPS | `Roadmap_Beta7.md` |
| `0.1.0-beta8` | Consolidation & API freeze (last feature release) | `Roadmap_Beta8.md` |
| `1.0.0-RC1` → `1.0.0` | Freeze cert + EcoShield-Gateway soak → Gold | `Roadmap_RC1.md` / `Roadmap_v1_Gold.md` |

- **Post-BBL pivot (2026-07):** stabilization/audit pulled forward into **beta6**; the former beta6
  production-surface shifted to **beta7**; the API freeze is now **beta8**. Train re-dated around the
  API Platform Conference (Lille, Sep 17–18 2026), then slipped one month on 2026-09-06: beta6
  **Sep 2026** (still pre-conference) · beta7 **Oct** · beta8 **Nov** · RC1 **Dec** · Gold **Jan 2027**.
- **Version stamps:** `0.1.0-betaN` — **no `v` prefix** (the tag gate rejects it). Fix the *current*
  stamp; never bulk-bump historical CHANGELOGs. See the `roadmap-steward` skill.
- **Release dates are month-precision:** `YYYY-MM`, never `YYYY-MM-DD` — a CHANGELOG heading reads
  `## [0.1.0-beta6] — 2026-09`; in prose (roadmaps, release logs) it is the month and year only
  ("September 2026"). Retro-dating shipped releases is not part of this: leave historical entries
  as written and stamp the current release in the new format.
- **Release mechanics (umbrella wave):** one `pre-release/<version>` branch per component → umbrella
  tag pushed to the remote → dispatch **dry-run on the pushed tag** (`ref:<tag>` must already exist) →
  LIVE wave. Per-component steps live in `release-manager`; the orchestration lives in `release-wave`.
- **What each phase allows** (binding guards from `Roadmap_v1_Master.md`):
  - **beta7 (build):** the `Roadmap_Beta7.md` items.
    - The stretch tier (`[DXP-01]`, `[GATE-02]`) is cut first.
    - If `queue`/`openapi`/`serializer`/`testing` are not green on their own gates by mid-October, the
      release splits: NET + OPS + QUEUE as beta7, API + TEST into the beta8 window.
    - The November freeze is what is protected, not beta7's scope.
  - **beta8 (freeze):** the tag *is* the feature freeze. The release holds the spike verdicts, the
    contracts BC review + `contracts/BC-POLICY.md`, deprecations, the naming pass, the 72 h soak, the
    final security re-audit and the docs. After the tag, bug fixes only; an item that slips leaves v1
    (`api-freeze` skill).
  - **RC1 (certification):** tagged `1.0.0-RC1` (never `0.1.0-RC1`) by ~5 December 2026 (`rc-certification`
    skill).
    - Zero features; the beta8 deprecations are removed.
    - A ≥4-week EcoShield soak that is never shortened.
    - RC2 only on a critical defect, and it restarts the soak clock.
    - Gold = zero code delta from the soaked RC.

## 6. Git & release safety (every agent, every runtime)

The human drives every git and GitHub write. An agent edits files; it does not publish them.

- **Never implied:** commit, push, tag, merge, rebase, reset, branch, stash, `git submodule update`,
  PR create/merge, release, workflow dispatch, repository or ruleset settings — each needs an
  explicit request **for that specific operation**. "Make the changes" means edit files, nothing more.
  A command listed *for the human to run* is not permission to run it.
- **Tags are live:** pushing a tag matching `N.N.N[-*]` fires the LIVE release wave to Packagist.
  Never create or push one incidentally, not even to "test" the workflow.
- **Released repos are artefacts:** once a wave ships, add nothing to a component's `main` unless that
  repo is named in the request. Report a sibling bug; don't fix it in passing.
- **Merges to `main` are merge commits, never squash:** the release wave requires every pinned gitlink
  to be an ancestor of the component's default branch; a squash orphans it and the wave exits 3.
- **Never "sync" with `git submodule update --remote`:** it detaches every submodule from its local
  `pre-release/*` branch. Use `wfl sync:status` (read-only).
- **Tooling enforces it:** the GitHub MCP server runs read-only, the Claude Code permission rules ask
  before every git/GitHub write and deny force-pushes; other runtimes must follow the same rule.

## 7. Evidence & measurement

A claim is only as good as its measurement, whether it sits in a roadmap, a README, a conference slide
or a commercial offer.

- **Acceptance means evidence.** A roadmap item is done when its acceptance criteria are shown by
  tests, command output or reports (the `acceptance-verifier` agent), not when its code exists.
- **Measure the production image.** Give baselines the capacity their curve assumes, pin
  `MAX_REQUESTS` above the run's total, and record the environment with every run.
- **A leak is a positive slope, published with its 95 % bound** over a settled window.
  - Memory claims are slope + crossover, never a flat factor.
  - Keep invalidated series, and never overwrite a run.
- **A laptop cannot measure capacity or hold a multi-day soak.** Say so instead of publishing.
- **Commercial texts (EcoShield) stay measurable:** no warranty wording, no invented or unmeasured
  claim.

Procedures: the `benchmark-gate`, `soak-endurance` and `ecoshield` skills.

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

**Beta7 — production surface (in progress: procedures staged ahead of the code, "not built yet" until it lands)**

| Skill | Trigger / Use when… | Roadmap |
|-------|---------------------|---------|
| `resilience-net` | Rate limiter (atomic, shared storage), client timeout/retry policies, circuit breaker. | beta7 NET (RFC-017 §3.1 for NET-01 · RFC-024 for NET-02/03) |
| `queue-worker` | Background processing (`queue` component, Redis Streams, `queue:work`, SIGTERM drain). | beta7 QUEUE (RFC-015) |
| `k8s-ops` | `/healthz` + `/readyz`, graceful drain, migrations on the existing `db:migrate`. | beta7 OPS (RFC-023 for OPS-01/02 · RFC-014 for OPS-03) |
| `api-surface` | OpenAPI generation + DTO serializer / content negotiation. | beta7 API (RFC-016) |
| `testing-bridge` | `WaffleTestCase` in-process kernel + test doubles. | beta7 TEST (RFC-018 §3.3) |

**Beta8 freeze → RC1 certification**

| Skill | Trigger / Use when… | Roadmap |
|-------|---------------------|---------|
| `api-freeze` | Spike verdicts, contracts BC review + `BC-POLICY.md`, deprecations, naming pass, the freeze exit gate, "is this allowed after the freeze?". | beta8 AXE 1–2 |
| `soak-endurance` | 72 h soak, ≥4-week soak, memory drift, chaos injection, "is this soak valid?". | beta8 STAB-01 · RC1 RC-04 |
| `rc-certification` | `1.0.0-RC1`: exit-gate re-run, deprecation removal, packaging pass, RC2 clause, Gold entry gate. | RC1 |

**Dogfood — the v1 adoption criterion**

| Skill | Trigger / Use when… | Roadmap |
|-------|---------------------|---------|
| `ecoshield` | The standalone `ecoshield-gateway` repo: alpha on NET, FinOps benchmark, RC soak, French docs, measurable claims. | beta7 GATE-02 · beta8 GATE-03 · RC1 RC-04/05 |

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
**Beta7 → RC1 additions:**
- **`acceptance-verifier`** — a roadmap item's or release gate's acceptance criteria → evidence →
  PASS / FAIL / UNVERIFIED.
- **`soak-analyst`** — slope ± 95 % bound, settled-baseline, recycle and instrument checks on a
  memory series.
- **`chaos-runner`** — one fault injected into a bench/soak stack under load, reaction checked; never
  `waffle-dev`.
- **`bc-reviewer`** — one contracts namespace against the freeze checklist, plus a usage map.

**Frontmatter (every runtime reads the same files):** `name` (= the file name), `description`,
`mode: subagent`, `hidden: true`.
- Claude Code registers an agent by its `name`; without it the agent does not load.
- opencode names the agent from its file and accepts the extra key.
- Never add `model:` or `tools:` — the runtimes use incompatible formats. State tool limits (read-only,
  no git writes) in the body instead.
