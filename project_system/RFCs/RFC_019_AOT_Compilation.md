# RFC-019: Ahead-of-Time (AOT) Compilation

**Status:** Horizon v2.0 **Components:** `waffle-commons/waffle` **Author:** Core Architect **Tags:** performance, aot, compiler, routing-tree

## 1. Summary

This RFC outlines the ultimate performance goal for Waffle: transforming runtime dynamic resolution into static, pre-compiled PHP code (AOT - Ahead of Time compilation).

## 2. Motivation

Although FrankenPHP's resident memory eliminates the boot phase per request, the initial "Cold Start" still relies on Reflection (for Dependency Injection) and sequential arrays (for Routing). To squeeze the absolute maximum performance out of PHP 8, we must compile these structures into raw PHP files.

## 3. Technical Specifications

### 3.1 Container Compilation

Instead of resolving dependencies via Reflection during `Kernel::configure()`, Waffle will introduce a build step (`waffle build`). This step parses all dependencies and generates a static `var/cache/CompiledContainer.php` file containing hardcoded `new ServiceA(new ServiceB())` calls.

### 3.2 Routing Tree Compiler

Transforming the flat routing array into a compiled Decision Tree (or optimized Regex chunks, similar to FastRoute) to ensure routing resolution is $O(1)$ or $O(\log n)$, regardless of the number of registered routes.

### 3.3 JIT Optimization Hints

Structuring the compiled code specifically to benefit from PHP's Just-In-Time (JIT) compiler (e.g., highly predictable type structures, minimizing polymorphic calls).

## 4. Contributor Guidelines

- **Transparency:** The transition to AOT must be completely transparent to the end-user. The API (`#[Route]`, Constructors) must not change.
    
- **Fallback Mechanism:** If the compiled files are missing or corrupt, the system MUST fallback safely to the dynamic (Reflection) resolution mode and log a warning.