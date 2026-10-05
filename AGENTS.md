# AGENTS.md — Waffle-Commons Central Brain

The single source of truth for **how any AI assistant must behave** in the `waffle-commons`
monorepo (PHP 8.5, FrankenPHP resident-worker, independent submodules each released to Packagist).
Claude Code is the supported assistant: `CLAUDE.md` imports this file into every session and adds the
Claude Code specifics. Standards live here, nowhere else.

> **For every task:** this file (always in context) → the matching skill in `.claude/skills/` (§8).
> When in doubt, start with `tech-lead`.

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

- **Monorepo of submodules**, each its own Git repo and Packagist release. Enumerate the live list
  with `scripts/list-components.sh` (parsed from `.gitmodules`), never a hardcoded count.
  - **Framework:** `contracts`, `utils`, `waffle`, `runtime`, `pipeline`, `routing`, `http`,
    `http-client`, `security`, `auth`, `data`, `cache`, `container`, `config`, `console`, `log`,
    `event-dispatcher`, `error-handler`, `telemetry`, `telemetry-otel`, `async`. Beta7 adds `queue`,
    `openapi`, `serializer`, `testing`: scaffolded from `component-template` (`component-scaffold`
    skill), their code lands this release, tests and coverage switch on with their first class.
  - **Template / docs:** `skeleton`, `workspace`, `academy`, `documentation`, `component-template`.
  - The `ecoshield-gateway` POC is its own repository (`contributions/ecoshield-gateway/`, gitignored
    here), outside the release wave: the v1 adoption dogfood (`ecoshield` skill).
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

- **Dates:** beta6 **Sep 2026** · beta7 **Oct** · beta8 **Nov** · RC1 **Dec** · Gold **Jan 2027** (the
  post-BBL pivot of 2026-07 pulled the audit into beta6; the train slipped one month on 2026-09-06).
- **Version stamps:** `0.1.0-betaN` — **no `v` prefix** (the tag gate rejects it). Fix the *current*
  stamp; never bulk-bump historical CHANGELOGs. See the `roadmap-steward` skill.
- **Release dates are month-precision:** `YYYY-MM`, never `YYYY-MM-DD` — a CHANGELOG heading reads
  `## [0.1.0-beta6] — 2026-09`; in prose (roadmaps, release logs) it is the month and year only
  ("September 2026"). Never retro-date shipped releases: stamp the current one in this format.
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
- **Tooling enforces it:** the GitHub MCP server runs read-only; the team permission rules in
  `.claude/settings.json` ask before every git/GitHub write and deny force-pushes, history rewrites,
  host-side PHP and `git submodule update --remote`; the `waffle-cockpit` guard also refuses pushing
  or creating a release tag.
- **Third-party skills follow this section too** (§9): when one says to commit, branch, push, open a
  PR or publish an issue, stop and ask.

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

## 8. Skills, subagents and plugins (Claude Code)

- **Skills** live in `.claude/skills/<name>/SKILL.md`. Claude Code lists each one by its `description`
  and `when_to_use`. **When a request matches a skill, load it before planning or acting**: it holds
  the operating procedure for that area and overrides general defaults. When unsure, start with
  **`tech-lead`**: it knows the release phase and sequences `coding` → `test` → `code-review` →
  acceptance. The full catalogue, by area and phase, is
  [`docs/reference/claude-skills.md`](docs/reference/claude-skills.md).
- **Subagents** live in `.claude/agents/<name>.md` and do the single-component work the skills
  dispatch: gates, Mago, tests, worker safety, security, audits, benchmarks, soak analysis, BC review.
- **Frontmatter rules** (`wfl ai:check` enforces them, locally and in CI):
  - a skill: `name` = its directory; a short `description` (what it does, plus "not built yet" while
    its code does not exist); the trigger phrases in `when_to_use`; `argument-hint` when it works on
    one component;
  - a subagent: `name` = its file name (Claude Code does not register an agent without it); a
    `description` that starts with "Use …"; the skill it follows preloaded with `skills:`; tool limits
    that match its contract (`disallowedTools: Write, Edit, NotebookEdit` when read-only, `Edit,
    NotebookEdit` when it only writes a report); `model` only for mechanical runners;
  - permissions belong in `.claude/settings.json`, never in a skill's `allowed-tools`.
- **Plugins** come from the repository marketplace (`.claude-plugin/marketplace.json`) and load for
  every clone once the folder is trusted: `waffle-cockpit` (a mod: the status band, `/dod` in a pane,
  the Bash guard) and `mattpocock-skills` (§9).

## 9. Third-party skills (`mattpocock-skills`)

A pinned, curated copy of github.com/mattpocock/skills lives in `.claude/plugins/mattpocock-skills/`.
Its `VENDORED.md` names the commit, what is kept and why the rest is excluded; refresh it with
`scripts/claude/vendor-mattpocock.sh <sha>` and review the diff. The skills run as
`/mattpocock-skills:<name>`: `grill-me`, `grill-with-docs`, `tdd`, `diagnosing-bugs`, `handoff`,
`to-spec`, `to-tickets`, `writing-for-agents`, `wizard`, …

- Their configuration is written by hand, not by `/setup-matt-pocock-skills`. The issue tracker is
  local markdown in `.scratch/` ([`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)); the
  domain docs are a root `GLOSSARY.md` plus the RFCs ([`docs/agents/domain.md`](docs/agents/domain.md)).
- **This file wins.** A third-party step that would commit, branch, push, open a PR, publish an issue
  or create an ADR stops and asks (§6). `project_system/` stays the source of truth for direction.
