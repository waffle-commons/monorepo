---
name: worker-safety
description: "Make a component pass the FrankenPHP worker-state audit (wfl igor, 0 KO)"
when_to_use: >-
  wfl igor is red / KO, "Mutation of state in ...", "is this class worker-safe?",
  ResettableInterface or #[WorkerSafe] questions, reviewing a stateful service before a release,
  long-running consumers (queue:work).
argument-hint: "[component]"
---

## What I do
I keep `waffle-commons` components safe for FrankenPHP **resident-worker** mode, where a process
serves many requests and any state that survives a request is a leak. I run the `wfl igor` audit
(`igor-php`, the version pinned in `.igor-version`) and apply the remediation taxonomy until a component
reports **0 KO**. This is part of
every component's definition of done — see `[[mago-purge]]`, `[[contracts-first]]`.

## When to use
"`wfl igor` is red / KO", "Mutation of state in …", "is this class worker-safe?", "do I need
`ResettableInterface` / `#[WorkerSafe]`?", reviewing a stateful service before release.

## The grading (only KO fails)
`igor-php` walks each class that mutates instance state and grades it:
- **KO (Dangerous State):** `Mutation of state '<prop>' in <method>()` — **fails the gate**.
- **WARN:** flagged but **passes** — do not chase WARNs to zero.
- **OK:** clean.

`wfl igor` runs `igor.sh` across all components (root). Per component: `composer igor`
(`vendor/bin/igor-php .`). This is **separate** from `security:audit` (ABAC/CSRF) — don't conflate.

## Remediation taxonomy (pick the narrowest honest fix)
1. **Direct `ResettableInterface` + `reset()`** — for genuine request-scoped state that must clear
   between requests (caches, the request-scoped `SecurityContext`, a `ConnectionTracker`). **CRITICAL:
   the `implements` must be DIRECT** — igor does a *shallow* scan, so
   `implements FooInterface` where `FooInterface extends ResettableInterface` is **NOT** enough. Write
   `implements FooInterface, ResettableInterface` explicitly. (Mago does not flag the redundant
   interface.)
2. **Constructor-`readonly`** — if the property never legitimately changes after construction, make it
   `readonly` (or `public private(set)` for hooked DTOs). No mutation ⇒ no KO.
3. **Inline / no field** — if the "state" is really a local, compute it in-method instead of storing it.
4. **`#[WorkerSafe]`** (`IgorPhp\IgorBundle\Attribute\WorkerSafe`) — on a property or class that is an
   *audited, intentional* exception (e.g. a memoized immutable lookup). Adding it requires the
   component's `mago.toml` guard perimeter to permit `IgorPhp\IgorBundle\Attribute\**`, or `mago guard`
   will reject the import.

> igor-php 0.7 replaced the old `// @igor-ignore` comments with the `#[WorkerSafe]` attribute. A
> `composer update` can revert vendored unreleased deps — if a fix "disappears", re-mirror the source
> and re-run.

## igor-php 0.9.x — detector families and where `#[WorkerSafe]` must go
The 0.9 line (pinned since beta7 kickoff: 0.9.7) added detectors; the first sweep raised 50 findings in
12 components, **all adjudicated in code** (see `Roadmap_Beta7` `[CARRY-05]`). Any finding — even
`[INFO]` — grades its file KO.

| Finding | Usual verdict | Where the attribute works |
|---|---|---|
| "Mutation detected on an injected dependency (`$this->cache`)" | write *through* a service to its backend (PSR-16 store, Redis/Firestore client, metric store) — not worker memory | **method** only (a property-level attribute on the promoted param is ignored) |
| "…on a local reference to a shared service (`$span`, `$cursor`, `$builder`)" | per-call object from a factory, ended/discarded in the call | **method** |
| "Usage of `__destruct()`" | per-request value object (`Stream`), or a lifecycle fallback whose worker path is `reset()` (`CachePool`) / an unbuffered handle closed at shutdown (`StreamLogger`) | **method** (on `__destruct`) |
| "Usage of PHP Superglobal" | only `GlobalsFactory` (the sanctioned boundary) may read them at call time; a front controller must use the env registry instead — **fix it, don't annotate** | **method** |
| "Property 'x' is mutated but not reset in reset()" | write-through on a `readonly` dependency | **property** |

The `reason` must state *why* nothing survives the request — "per request" alone is not a reason.
Verify every claim you write (e.g. "ended in finally") against the code before annotating.

## Long-running consumers (beta7 `queue:work`)
A queue worker is a resident process like the HTTP worker, with messages instead of requests:
- reset the container's resettable services after **every** message, in a `finally`;
- recycle on a max-messages or memory ceiling;
- audit its classes with igor like any worker code.

The one-shot console commands' `#[WorkerSafe]` reason ("CLI-only: constructed per `bin/waffle`
invocation …") is valid for them and **false** for `queue:work` — never copy it there.

Rate-limiter and circuit-breaker state belongs in shared storage (`[[resilience-net]]`). In worker
memory it is both a leak and a correctness bug, because each worker would count separately.

## "Keeps state on purpose" (`[CARRY-03]`, decided 2026-10-22 — RFC-001 §5)
`ResettableInterface` stays optional at runtime (`Container::reset()` resets only Resettable services, as
Symfony does), and v1 has no second marker: `#[WorkerSafe(reason: …)]` is how a resident service declares
state it keeps on purpose. RFC-001 §5 says where each kind of state goes — request-scoped → a direct
`ResettableInterface`; built at boot and frozen, or a bounded request-independent cache → `#[WorkerSafe]`
on the property; never-resident objects → on the class — and the rules: the reason says why nothing
request- or user-specific survives, a surviving cache is bounded by something fixed at boot and never
keyed by request data, user data is never kept.

Do not add a Waffle-owned attribute before v1. A distinct `#[KeepsState]` is proposed to igor-php
upstream instead (the issue is the maintainer's call). Note that igor matches `WorkerSafe` by short name,
whatever the namespace, while the `ComplianceScanner` matches igor's class by its full name.

## Upstreaming a detector fix (`[CARRY-05]`)
igor 0.9.x flags writes *through* an injected service (`$this->cache->set(…)`) as a mutation.
1. Adjudicate each case in code: fix it, or add a method-level `#[WorkerSafe]` with a verified reason.
2. Propose the detector fix in the fork at `contributions/igor-php` (origin = the fork, upstream =
   `igor-php/igor-php`). The maintainer requires the Go core, tests and comments to stay
   framework-agnostic: only Symfony may be named, fixtures use `App\`, and Waffle appears only in the
   README bridges table.
3. Verify with `go build ./... && go test ./...` plus an empty `grep -rin waffle --include='*.go'`.

Opening the PR is the maintainer's action.

## Execution (in Docker)
```bash
docker exec -w /waffle-commons/{component} waffle-dev composer igor   # per component: 0 KO required
wfl igor                                                                  # whole monorepo sweep
```
Done when the component (and the repo) reports **0 KO**. If a fix needs `#[WorkerSafe]`, also re-run
`composer guard` to confirm the perimeter permits the attribute namespace.
