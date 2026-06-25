# Reference — `.opencode/skills/`

> **Release:** `0.1.0-beta5`.
> **Scope:** `<umbrella>/.opencode/skills/`.
> **Purpose:** the project-specific AI prompt library. Each subdirectory contains a single `SKILL.md` that an AI assistant must consult before performing a matching task.

## Routing directive (binding)

`AGENTS.md` carries this directive (with `CLAUDE.md` as the thin CLI router that redirects to it): *if the user's request matches a specialised skill, the assistant MUST read the corresponding `SKILL.md` before planning or acting.* These prompts encode component-specific operating procedures that override generic AI defaults. The always-current source is the **Skills Routing Table** in `AGENTS.md`; this page mirrors it.

## Available skills

**29 skills**, grouped by intent. Each lives at `.opencode/skills/<name>/SKILL.md`.

### Core workflow

| Skill | Trigger |
| :--- | :--- |
| **tech-lead** | Entry point for non-trivial / multi-skill / ambiguous work; sequences coding → test → review. |
| **coding** | Implement a feature or bug fix across the components. |
| **refactoring** | "Refactor / clean up / restructure" — needs a green test baseline first. |
| **test** | Add/improve PHPUnit 12.5 tests; target ≥95% coverage. |
| **code-review** | "Review my changes" / pre-merge sanity (per-component diff). |
| **maker-scaffold** | Scaffold a controller, DTO, middleware, voter, command, HTTP client, or event pair via Waffle Maker (RFC-020). |

### Quality gates & worker-mode

| Skill | Trigger |
| :--- | :--- |
| **mago-purge** | Fix Mago findings to ZERO output; eradicate baselines; harden types (native-first). |
| **worker-safety** | `wfl igor` is KO; `#[WorkerSafe]` / direct `ResettableInterface`; reset-per-request leaks. |
| **contracts-first** | New interface sequencing; `mago guard` perimeter (contracts + utils); vendor-contracts skew. |
| **benchmark-gate** | Benchmark-gated items (GC churn, memory curve, AOT/pool/telemetry overhead) → `…-GATE-RESULT.md`. |

### Security

| Skill | Trigger |
| :--- | :--- |
| **security-audit** | Statelessness, fail-closed ABAC, SSRF (SEC-02), CORS, traversal, `#[PublicAccess]`, SEC-03 compare-audit. |
| **auth-bridge-audit** | Universal Authentication Bridge (RFC-021, `auth`): JWT, OAuth2/OIDC, HMAC assertions, API keys. |
| **webauthn-passkeys** | WebAuthn / passkeys (RFC-021 AUTH-01, `auth`): `WebAuthnLibAdapter` (sole `webauthn-lib` importer), stateless authenticator with app-provided challenge store, configurable UV, fail-closed. |

### Data & persistence

| Skill | Trigger |
| :--- | :--- |
| **data-persistence** | Universal Data & Persistence Layer (RFC-022): SQR, stateless pools, Firestore paths, atomic flat-file, CRUD mappers. |

### Docs, scaffolding & release

| Skill | Trigger |
| :--- | :--- |
| **diataxis-doc** | "Write/document" → Diátaxis docs with exact PHP 8.5 signatures + version stamps. |
| **component-scaffold** | "Create a new component / bootstrap a package" from `component-template`. |
| **release-manager** | Per-component release steps within the umbrella wave (Packagist). |
| **release-wave** | Orchestrate a full multi-component umbrella release (tag → dry-run → LIVE). |
| **demo-app-wiring** | Wire a shipped feature into `skeleton` / `workspace` / `academy` (vendor skew, French, routes). |
| **roadmap-steward** | Maintain `project_system/` RFCs & Roadmaps as the direction source of truth. |

### Beta5 — shipped capability skills (live operating procedures, code exists)

| Skill | Trigger | Source |
| :--- | :--- | :--- |
| **aot-compilation** | Build-time compiled container + router-trie preheat; `WAFFLE_AOT=1` fast-path + reflection fallback. | beta5 (RFC-019) |
| **async-concurrency** | Fiber finish-request deferral (`async`); concurrent HTTP-client promise fan-out. | beta5 (RFC-015) |
| **observability** | Contract-first `TracerInterface` + OTel bridge (`telemetry-otel`); Prometheus `/waffle-metrics` (`telemetry`). | beta5 (RFC-005) |
| **reactive-broadcast** | `#[Broadcast]` write-hooks → request-scoped buffer → finish-request SSE flush; no I/O in the hook. | beta5 (RFC-018) |

### Roadmap-forward (operating procedures staged *ahead* of the code — flagged "not yet built")

| Skill | Trigger | Roadmap |
| :--- | :--- | :--- |
| **resilience-net** | Rate limiter, retry/backoff, circuit breaker. | beta6 (RFC-017) |
| **queue-worker** | Background processing (`queue` component, Redis Streams). | beta6 (RFC-015) |
| **api-surface** | OpenAPI generation + DTO serializer / content negotiation. | beta6 (RFC-016) |
| **k8s-ops** | Health/readiness probes, graceful drain, migration maturity. | beta6 (RFC-014) |
| **testing-bridge** | `WaffleTestCase` in-process kernel + test doubles. | beta6 (RFC-012) |

## Subagents (`.opencode/agents/<name>.md`, `mode: subagent`)

Skills dispatch **14 focused single-component workers**: `coding-worker`, `coding-integrator`, `docgen-worker`, `gate-runner` (run `composer mago && composer tests` + `composer igor`), `mago-fixer` (purge to zero output), `test-author` (PHPUnit 12.5 ≥95%), `worker-safety-auditor` (`wfl igor` remediation + DBAL-pool reset/affinity audit), `security-auditor` (security checklist + SSE-injection + WebAuthn checks), and `contracts-sync` (mirror fresh `contracts/src` into a consumer `vendor/`). **Beta5 additions:** `benchmark-runner` (baseline → load → `…-GATE-RESULT.md`), `flake-hunter` (loop phpunit, isolate the flaky testcase from JUnit), `demo-wiring-worker` (wire one shipped feature into one app), `aot-verifier` (`container:compile` / `route:compile` + graph-identity snapshot + `WAFFLE_AOT` fast-path/fallback), and `webauthn-auditor` (passkey UV / challenge-binding / sign-counter clone-detection / statelessness audit).

## How a skill is loaded

The AI assistant invocation conventionally:

1. Reads `CLAUDE.md` (the thin router) → `AGENTS.md` (the standards) first.
2. Determines if the user's task matches a skill from the routing table above.
3. Reads the corresponding `SKILL.md` **before** planning or editing files.
4. Defers to that skill's operating procedure for the duration of the task.

When in doubt about which skill applies, the assistant should default to **`tech-lead`** — which orchestrates the others.

## SKILL.md file shape

Every skill follows the same structure:

```markdown
---
name: <skill-name>
description: <one-line trigger description>
compatibility: opencode
---

## What I do
<scope and role>

## Workflow / Protocol
<step-by-step procedure>

## Definition of done
<checklist the skill must satisfy>
```

The frontmatter is read by OpenCode (and similar tools) to surface the skill in the assistant's tool list.

## Adding a new skill

1. Create `.opencode/skills/<name>/SKILL.md`.
2. Add a row to the **Skills Routing Table** in `AGENTS.md` (the `🧠 Specialized AI Skills` section).
3. Add a row to this reference page.
4. Open an umbrella PR — review by `@waffle-commons/waffle-core` per CODEOWNERS.

## Don't bypass skills silently

If you find yourself ignoring a skill ("I know better than this prompt"), that's a signal the skill needs updating, not bypassing. Open an issue against the umbrella, propose the change, and update `SKILL.md` through review.

## Related

- [`CLAUDE.md` reference](claude-md.md) — the file that routes to these skills.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — what `mago-purge` operationalises.
- [Add a new component](../how-to/add-a-new-component.md) — uses the `component-scaffold` skill.
