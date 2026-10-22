---
title: "RFC-001: Core Architecture & Runtime"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-001: Core Architecture & Runtime

**Status:** Implemented (Alpha 1-5), Hardening in Beta 0 · Amended 2026-10-22 (§5, `[CARRY-03]`) **Components:** `waffle-commons/waffle`, `waffle-commons/runtime` **Author:** Core Architect **Tags:** architecture, frankenphp, php-8.5, kernel

## 1. Summary

This RFC defines the fundamental architecture and request lifecycle of the Waffle Framework. It establishes the strict separation between the `Runtime` (handling the web server interface) and the `Kernel` (orchestrating application logic).

## 2. Motivation

Traditional PHP frameworks instantiate their core on every request. With the advent of **FrankenPHP** and the Worker model, Waffle must remain in Resident Memory to deliver sub-millisecond response times. The design must absolutely prevent memory leaks and strictly isolate the state of each HTTP request.

## 3. Technical Specifications

### 3.1 The WaffleRuntime

The `runtime` component serves as the entry point (`public/index.php`). Its responsibilities are:

- Detecting the execution context (standard PHP-FPM vs asynchronous `frankenphp_handle_request`).
    
- Managing the infinite request loop in Worker mode.
    
- Converting PHP superglobals into a PSR-7 `ServerRequestInterface` via the `GlobalsFactory`.
    
- Emitting the response via the `ResponseEmitter`.
    

### 3.2 The AbstractKernel

The Kernel is an orchestrator; it contains no direct business logic. It maintains the global application state using PHP 8.5 **Asymmetric Visibility** to guarantee external immutability:

```
abstract class AbstractKernel implements KernelInterface
{
    protected(set) ?System $system = null;
    protected(set) ?MiddlewareStackInterface $middlewareStack = null;
    // ...
}
```

**Standard Lifecycle (`Kernel::handle()`):**

1. Dispatch `RequestReceivedEvent`.
    
2. Process the request through the `MiddlewareStack`.
    
3. Dispatch `ResponseGeneratedEvent`.
    
4. Return the `ResponseInterface`.
    
5. Dispatch `TerminateEvent` (triggered after emission for heavy background tasks).
    

## 4. Contributor Guidelines

- **Framework Agnosticism:** The `Kernel` must never depend on a concrete HTTP implementation, only on PSR-7 contracts.
    
- **Strict Statefulness:** **NEVER** store request-specific or user-specific data in a Kernel property or a shared service (Singleton). Because the application runs in FrankenPHP, doing so will cause data leaks between different users.
    
- **PHP 8.5 Standards:** Any new Kernel property must utilize asymmetric visibility (`public private(set)` or `protected(set)`) instead of passive getter methods.

## 5. Amendment — State kept on purpose (`[CARRY-03]`, 2026-10-22)

**Decision (maintainer, 2026-10-22):** Waffle adds no second marker. `#[WorkerSafe(reason: …)]` is the
declared marker for state a resident service keeps on purpose, and `ResettableInterface` stays optional.

**Why it came up.** At the API Platform Conference (2026-09-17) the suggestion was to make
`ResettableInterface` optional for services that must keep state, as Symfony does. At runtime it already
is: `Container::reset()` resets only the services that implement it. The strictness lives in the tooling.
The dev-mode `ComplianceScanner` (`Container(strictComplianceScan: true)`, which the skeleton turns on in
`dev`) fails the boot on a shared, non-resettable service with a mutable property, and the `wfl igor` gate
fails CI; `#[WorkerSafe]` is the one way through both. That strictness is deliberate: state that outlives
a request must be declared and justified.

### 5.1 Where each kind of state goes

| State | How to hold it | Example |
|---|---|---|
| Request-scoped (per request, per user) | `implements ResettableInterface` **directly**, cleared in `reset()` | `SecurityContext`; the pool's pinned lease |
| Fixed after construction | `readonly` (or `public private(set)` on a hooked DTO); no marker | injected collaborators |
| Built at boot, frozen before the first request | `#[WorkerSafe]` on the property; the reason names the freeze point | container registrations frozen by `lock()`; the route trie built in `boot()` |
| A worker-lifetime cache of request-independent data | `#[WorkerSafe]` on the property; the reason says what bounds it | the router's compile-once pattern cache, bounded by the frozen route list |
| An object that is never resident | `#[WorkerSafe]` on the class or property; the reason names the lifecycle | CLI commands; test doubles; per-request value objects |
| A write through an injected service to its backend | method-level `#[WorkerSafe]` until igor stops flagging it (`[CARRY-05]`) | cache and telemetry stores |

### 5.2 Rules for `#[WorkerSafe]`

- The reason says why nothing request- or user-specific survives the request. "Per request" alone is not
  a reason, and every claim in it is checked against the code.
- A cache that survives requests is bounded by something fixed at boot and is never keyed by request
  data: a key derived from a request is both a leak and unbounded memory growth.
- User and request data are never kept; §4 stands unchanged.
- Review treats a new `#[WorkerSafe]` like a new public API: it needs its reason and a reviewer who
  checked it.

### 5.3 The marker's home

The attribute is `IgorPhp\IgorBundle\Attribute\WorkerSafe` from `igor-php/igor-php`, a dev dependency of
every component and template app (`.igor-version` pins the auditor). PHP loads an attribute's class only
when asked to instantiate it, so production installs never need the package; a component that uses the
attribute permits `IgorPhp\IgorBundle\Attribute\**` in its `mago guard` perimeter. No contracts symbol
is added, so the beta8 freeze has nothing new to review.

**Revisit after v1** if igor renames or moves the attribute, or if production code should stop importing
a dev tool's namespace. The route would then be a Waffle-owned attribute in `contracts`, honoured by the
`ComplianceScanner`, together with an upstream igor option listing extra attributes to treat as safe
(framework-agnostic, as the igor maintainer requires). An upstream proposal for igor-php — a distinct
attribute for state kept on purpose, so an audit can tell it from an auditor exception — was drafted on
2026-10-22 for its maintainer; if igor adopts it, the revisit starts from there.
