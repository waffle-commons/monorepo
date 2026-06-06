# RFC-001: Core Architecture & Runtime

**Status:** Implemented (Alpha 1-5), Hardening in Alpha 6 **Components:** `waffle-commons/waffle`, `waffle-commons/runtime` **Author:** Core Architect **Tags:** architecture, frankenphp, php-8.5, kernel

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