# Explanation — The Component Agnosticism rule

> **Diátaxis quadrant:** Explanation.
> **Release:** `v0.1.0-beta2`.

## The rule, in one sentence

**Every component depends only on `waffle-commons/contracts`** (and on declared third-party PSR interface packages). Never on another component's concrete classes.

This is the single load-bearing invariant of the ecosystem. Everything else follows from it.

## What it means in practice

`security` cannot import `Waffle\Commons\Routing\Router`. It can import `Waffle\Commons\Contracts\Routing\RouterInterface`. The concrete implementation is wired in by the application (`AppKernelFactory`); the component itself talks to the abstraction.

```php
// ❌ Forbidden — security imports a concrete from routing
use Waffle\Commons\Routing\Router;

// ✅ Allowed — security imports the contract
use Waffle\Commons\Contracts\Routing\RouterInterface;
```

`mago guard`, configured per component in `mago.toml`, refuses any PR that violates this rule.

## Why this rule, specifically?

Three reasons, in increasing order of importance.

### 1. Independent releasability

If `security` requires `routing`'s concrete class, then `composer require waffle-commons/security` drags in `waffle-commons/routing` whether the consumer wants it or not. Real consumers of `security` (for example, an app that wants ABAC but has its own router) would be forced into a router they didn't choose.

Contract-only dependencies mean `security` requires `contracts` plus PSR interfaces, period. Consumers wire whatever concrete `RouterInterface` they want.

### 2. Decoupled evolution

If `security` reads `Router::$routes` directly, then any time `routing` reshapes its internal data structures, `security` breaks. With contracts only, the surface that can break is the *contract* — and contracts changes are deliberate, visible, ecosystem-wide events (see the Beta-1 `CsrfTokenManagerInterface` change for an example).

### 3. Testability

`security`'s tests mock `RouterInterface`. They never instantiate `Router`. The test suite never depends on `routing`'s tests passing. Mocking via the interface keeps the test surface tiny and the failures localised.

## What `contracts` actually contains

A short list of allowed kinds:

- **Interfaces** (`*Interface`).
- **Marker attributes** (`#[Route]`, `#[Voter]`, `#[PublicAccess]`, `#[RequiresCsrfToken]`).
- **Enums** (`Enum\Failsafe`, `Enum\ExitCode`, `Enum\Verbosity`).
- **Typed constants** (`Constant\Constant`, `Cache\Constant`, `Security\Csrf\Constant`).
- **Exception interfaces** (`*ExceptionInterface`).
- **A single concrete exception** — `Waffle\Commons\Contracts\Routing\Exception\RouteNotFoundException` (added in Beta-1 — see [contracts.md](../../documentation/reference/contracts.md)).

That last one is a deliberate exception to the "interfaces only" rule. `CoreRoutingMiddleware` (in `pipeline`) needs to *throw* a `RouteNotFoundException`, and the only places it could live (a sibling component) would re-create the contracts dependency loop. Hoisting one concrete exception into `contracts` is the smallest possible violation; it pays for itself by letting every component throw and catch the same class.

## What goes where

| Item | Lives in | Why |
| :--- | :--- | :--- |
| `RouterInterface` | `contracts` | Contract. |
| `Router` (the concrete) | `routing` | Implementation. |
| `#[Route]` attribute | `routing` | Tightly coupled to `Router`'s discovery logic. Could be argued either way, lives in `routing` for historical reasons. |
| `#[Voter]` attribute | `contracts` | Implementation-agnostic — `SecureContainer` reads it via reflection without caring who declares it. |
| `RouteNotFoundExceptionInterface` | `contracts` | Catchable across components. |
| `RouteNotFoundException` (concrete) | `contracts` (Beta-1) | Throwable from `pipeline` without `pipeline → routing` coupling. |

If you're proposing a new symbol and unsure where it belongs: if **only one component** would ever instantiate it, put it in that component. If **multiple components** need to read or instantiate it, put the interface in `contracts` and the concrete in whichever component "owns" the implementation.

## When the rule bites you

Common moments:

- You want `pipeline` to inspect a route's `#[Route]` attribute, but `#[Route]` lives in `routing`. Solution: define a `RouteAttributeInterface` (or similar) in `contracts`, have `routing`'s attribute implement it.
- You need to throw a typed exception across components. Solution: declare the interface in `contracts`; either implement the concrete in the throwing component, or hoist it into `contracts` like `RouteNotFoundException`.
- You want to share a Value Object across components. Solution: declare the value object in `contracts` if multiple components produce/consume it, or in the producing component if only one does.

## When the rule must bend

The `utils` package is widely consumed and contains pure functions. Most components depend on `waffle-commons/utils` as a path-repo sibling. This is permitted because `utils`:

- contains no I/O,
- has no inter-component dependencies of its own,
- is functionally analogous to the standard library.

If a new helper is general-purpose enough to belong in `utils`, propose its addition there. If it's specific to one component, put it in that component.

## Related

- [Why a monorepo of submodules?](why-monorepo-of-submodules.md) — the higher-level rationale this rule serves.
- [Repository layout](../reference/repository-layout.md) — how `mago guard` is configured per component.
- [The Mago Purge Protocol](mago-purge-protocol.md) — how the rule is mechanically enforced.
