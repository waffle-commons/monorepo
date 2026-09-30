---
name: worker-safety
description: Make a component pass the FrankenPHP worker-mode state audit (wfl igor / igor-php pinned by .igor-version) — #[WorkerSafe], direct ResettableInterface, 0 KO
compatibility: opencode
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

## Execution (in Docker)
```bash
docker exec -it -w /waffle-commons/{component} waffle-dev composer igor   # per component: 0 KO required
wfl igor                                                                  # whole monorepo sweep
```
Done when the component (and the repo) reports **0 KO**. If a fix needs `#[WorkerSafe]`, also re-run
`composer guard` to confirm the perimeter permits the attribute namespace.
