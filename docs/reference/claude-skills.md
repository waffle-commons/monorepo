# Reference — Claude Code skills, subagents and plugins

> **Release:** `0.1.0-beta7`.
> **Scope:** `<umbrella>/.claude/skills/`, `<umbrella>/.claude/agents/`, `<umbrella>/.claude/plugins/`,
> `<umbrella>/.claude-plugin/marketplace.json`.
> **Purpose:** the project's Claude Code operating layer: which skill covers which work, which subagent
> the skills dispatch, and the plugins every clone loads.

## How it loads

- `CLAUDE.md` imports `AGENTS.md`, so the standards are in context in every session.
- Claude Code lists every skill in `.claude/skills/` by its `description` and `when_to_use`. `AGENTS.md`
  §8 is binding: **when a request matches a skill, load it before planning or acting**. When unsure,
  start with **`tech-lead`**.
- Subagents in `.claude/agents/` are offered to Claude by their `description` ("Use when/after …").
- The two repository plugins load from the repository marketplace once the folder is trusted; no
  install step. `/plugin` lists them.

## Skills (34)

### Core workflow

| Skill | Use when… |
| :--- | :--- |
| **tech-lead** | Non-trivial, multi-skill, multi-component or ambiguous work; what the release phase allows; sequences coding → test → review → acceptance. |
| **coding** | Implement a feature or bug fix in a component. |
| **refactoring** | "Refactor / clean up / restructure", from a green baseline. |
| **test** | Add or improve PHPUnit 12.5 tests; ≥95% coverage; a clean `OK (…)` verdict. |
| **code-review** | "Review my changes": two axes, standards and spec (the roadmap item's acceptance criteria). |
| **maker-scaffold** | Scaffold a controller, DTO, middleware, voter, command, HTTP client or event pair with Waffle Maker (RFC-020). |
| **sync-components** | Read-only sync report of the umbrella and every submodule (`wfl sync:status`). |

### Quality gates & worker mode

| Skill | Use when… |
| :--- | :--- |
| **mago-purge** | Mago is not at zero output; a baseline exists; types to harden, native-first. |
| **worker-safety** | `wfl igor` is KO; `#[WorkerSafe]`, direct `ResettableInterface`, reset-per-request leaks. |
| **contracts-first** | A new interface; the `mago guard` perimeter (contracts + utils); vendor-contracts skew. |
| **benchmark-gate** | A benchmark-gated item → `…-GATE-RESULT.md`; any number the project publishes. |

### Security

| Skill | Use when… |
| :--- | :--- |
| **security-audit** | Statelessness, fail-closed ABAC, SSRF (SEC-02), CSRF, CORS, traversal, `#[PublicAccess]`, SEC-03 compare-audit. |
| **auth-bridge-audit** | The Universal Authentication Bridge (RFC-021, `auth`): JWT, OAuth2/OIDC, HMAC assertions, API keys. |
| **webauthn-passkeys** | WebAuthn / passkeys (AUTH-01, `auth`): sole lib adapter, stateless authenticator, configurable UV. |

### Data & persistence

| Skill | Use when… |
| :--- | :--- |
| **data-persistence** | The Universal Data & Persistence Layer (RFC-022): SQR, CRUD mappers, pools, Firestore paths, flat-file. |

### Docs, scaffolding & release

| Skill | Use when… |
| :--- | :--- |
| **diataxis-doc** | Write or update Diátaxis docs with exact PHP 8.5 signatures and version stamps. |
| **component-scaffold** | Create a new component from `component-template` and wire the umbrella, GitHub and Packagist. |
| **release-manager** | Per-component release steps inside the umbrella wave. |
| **release-wave** | Orchestrate the umbrella release (tag → dry-run → LIVE). |
| **demo-app-wiring** | Wire a shipped feature into `skeleton` / `workspace` / `academy`. |
| **roadmap-steward** | Maintain `project_system/` RFCs and Roadmaps, the direction source of truth. |

### Beta5 — shipped capabilities

| Skill | Use when… | Source |
| :--- | :--- | :--- |
| **aot-compilation** | The compiled container + RouteTrie preheat; `WAFFLE_AOT=1` fast path and reflection fallback. | RFC-019 |
| **async-concurrency** | Fiber finish-request deferral (`async`); concurrent HTTP-client fan-out. | RFC-015 |
| **observability** | `TracerInterface`, the OTel bridge (`telemetry-otel`), Prometheus `/waffle-metrics` (`telemetry`). | RFC-005 |
| **reactive-broadcast** | `#[Broadcast]` write-hooks → request buffer → finish-request SSE flush. | RFC-018 |

### Beta7 — production surface (procedures staged ahead of the code)

| Skill | Use when… | Roadmap |
| :--- | :--- | :--- |
| **resilience-net** | Rate limiter, client timeout/retry policies, circuit breaker. | NET (RFC-017 §3.1, RFC-024) |
| **queue-worker** | Background jobs in `queue`: Redis Streams, `queue:work`, SIGTERM drain. | QUEUE (RFC-015) |
| **k8s-ops** | `/healthz` + `/readyz`, graceful drain, migrations on `db:migrate`. | OPS (RFC-023, RFC-014) |
| **api-surface** | OpenAPI generation; DTO serializer and content negotiation. | API (RFC-016) |
| **testing-bridge** | `WaffleTestCase` in-process kernel + test doubles. | TEST (RFC-018 §3.3) |

### Beta8 freeze → RC1 certification

| Skill | Use when… |
| :--- | :--- |
| **api-freeze** | Spike verdicts, contracts BC review + `BC-POLICY.md`, deprecations, naming pass, the freeze exit gate. |
| **soak-endurance** | The 72 h soak, the ≥4-week EcoShield soak, memory drift, chaos injection. |
| **rc-certification** | `1.0.0-RC1`: exit-gate re-run, deprecation removal, packaging, RC2 rule, Gold gate. |

### Dogfood — the v1 adoption criterion

| Skill | Use when… |
| :--- | :--- |
| **ecoshield** | The standalone `ecoshield-gateway` repository: alpha, FinOps benchmark, RC soak, French docs. |

## Subagents (18)

| Agent | Preloads | Tools | Model |
| :--- | :--- | :--- | :--- |
| `acceptance-verifier` | roadmap-steward | read-only | session |
| `aot-verifier` | aot-compilation | read-only | session |
| `bc-reviewer` | api-freeze, contracts-first | read-only | session |
| `flake-hunter` | test | read-only | session |
| `gate-runner` | — | read-only | sonnet, low effort |
| `benchmark-runner` | benchmark-gate | writes its report, no Edit | session |
| `chaos-runner` | soak-endurance | writes its report, no Edit | session |
| `soak-analyst` | soak-endurance | writes its report, no Edit | session |
| `coding-worker` | coding | all | session |
| `coding-integrator` | coding | all | session |
| `contracts-sync` | contracts-first | all | sonnet, low effort |
| `demo-wiring-worker` | demo-app-wiring | all | session |
| `docgen-worker` | diataxis-doc | all | session |
| `mago-fixer` | mago-purge | all | session |
| `security-auditor` | security-audit | all (minimal fixes) | session |
| `test-author` | test | all | session |
| `webauthn-auditor` | webauthn-passkeys, auth-bridge-audit | all (minimal fixes) | session |
| `worker-safety-auditor` | worker-safety | all | session |

"Read-only" is `disallowedTools: Write, Edit, NotebookEdit`; "no Edit" is `Edit, NotebookEdit`. Bash
can still write, so the limits are guard rails, not a sandbox: each body keeps its own rule.

## Plugins (repository marketplace)

| Plugin | What it adds |
| :--- | :--- |
| **waffle-cockpit** | A mod: the status band above the prompt (phase, branch, `waffle-dev`, dirty repos, igor pin), `/dod <comp…>` / `/dod --changed` in a pane with no model turn, `/cockpit`, and a Bash guard (host-side PHP, `submodule update --remote`, release-tag pushes). See [`.claude/plugins/waffle-cockpit/README.md`](../../.claude/plugins/waffle-cockpit/README.md). |
| **mattpocock-skills** | 20 of Matt Pocock's engineering skills, vendored at a pinned commit: `/mattpocock-skills:grill-me`, `tdd`, `diagnosing-bugs`, `handoff`, `to-spec`, `to-tickets`, `writing-for-agents`, … Their configuration is [`docs/agents/`](../agents/); what is excluded and why is in its `VENDORED.md`; `AGENTS.md` §9 has the precedence rule. |

## File shapes

A skill (`.claude/skills/<name>/SKILL.md`):

```markdown
---
name: <name, equal to the directory>
description: "<what it does, under ~120 characters; 'not built yet' while its code does not exist>"
when_to_use: >-
  <the phrases, roadmap ids and components that should trigger it>
argument-hint: "[component]"   # when it works on one component
---

## What I do
…
```

A subagent (`.claude/agents/<name>.md`):

```markdown
---
name: <name, equal to the file name>
description: "Use when/after … — <what it does and returns>."
skills:
  - <the skill whose procedure it follows>
disallowedTools: Write, Edit, NotebookEdit   # read-only; `Edit, NotebookEdit` for a report writer
---

You are …
```

Permissions belong in `.claude/settings.json`, not in a skill's `allowed-tools`.

## Adding a skill or a subagent

1. Create the file in the shape above.
2. Add its row to this page (and to the agent table, for a subagent).
3. Run `wfl ai:check`: frontmatter, references, tool policy, `claude plugin validate --strict`.
4. Open an umbrella PR — review by `@waffle-commons/waffle-core` per CODEOWNERS.

## Don't bypass skills silently

If you find yourself ignoring a skill ("I know better than this prompt"), the skill needs updating, not
bypassing. Propose the change and update its `SKILL.md` through review.

## Related

- [`AGENTS.md` reference](agents-md.md) — the standards, including §8 (this layer) and §9 (third-party skills).
- [`CLAUDE.md` reference](claude-md.md) — imports `AGENTS.md` and adds the Claude Code specifics.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — what `mago-purge` operationalises.
- [Add a new component](../how-to/add-a-new-component.md) — uses the `component-scaffold` skill.
