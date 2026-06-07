# RFC-007: Dependency Injection Container

**Status:** Implemented (Alpha 1-5) **Components:** `waffle-commons/container` **Author:** Core Architect **Tags:** psr-11, autowiring, reflection

## 1. Summary

This RFC defines the Dependency Injection (DI) mechanism. Waffle provides a strict PSR-11 container with automatic resolution (Autowiring) capabilities via PHP Reflection.

## 2. Motivation

Modern frameworks rely on DI to invert control and ensure code is highly testable. Waffle's container aims to be zero-configuration for standard classes while supporting explicit factories for complex instantiations.

## 3. Technical Specifications

### 3.1 Autowiring Logic

When `$container->get(MyService::class)` is called:

1. Checks cache for an existing instance.
    
2. Checks for Circular Dependencies (throws exception if detected).
    
3. Uses Reflection to inspect the constructor.
    
4. Recursively instantiates type-hinted dependencies.
    

### 3.2 Integration with Security

The base Container is wrapped by the `SecureContainer` (RFC-002). Dependencies injected into controllers are audited before being passed to the constructor.

## 4. Contributor Guidelines

- **Interface Segregation:** Always type-hint interfaces in constructors (e.g., `LoggerInterface`), not concrete implementations (`StreamLogger`), to allow seamless swapping.
    
- **Primitive Types:** If a constructor requires primitive types (`string`, `int`), they must either have a default value or be explicitly registered via a factory. The autowirer cannot guess primitives.