# RFC-015: Asynchronous Execution & Parallelism

**Status:** Planned for v1.x (Post-v1.0) **Components:** `waffle-commons/async` **Author:** Core Architect **Tags:** fibers, frankenphp, mercure, async

## 1. Summary

This RFC details how Waffle will handle non-blocking operations and background tasks, fully exploiting PHP 8.1+ Fibers and FrankenPHP's native capabilities.

## 2. Motivation

Waiting for third-party APIs or heavy I/O operations blocks the worker. True performance requires asynchronous execution.

## 3. Technical Specifications

### 3.1 Fiber Integration

The component will provide a high-level abstraction over PHP Fibers, allowing developers to execute multiple HTTP outgoing requests or DB queries concurrently without writing complex callback hell.

### 3.2 Task Runner

A built-in mechanism to dispatch tasks to a background thread or a separate worker pool, avoiding the immediate need for complex message brokers (like RabbitMQ) for simple background jobs (e.g., sending emails).

### 3.3 Mercure Hub Wrapper

Seamless integration with the Mercure Hub (which is embedded natively in FrankenPHP) to allow real-time Server-Sent Events (SSE) push notifications out-of-the-box.

## 4. Contributor Guidelines

- **State Isolation:** Fibers run in the same memory space. Be extremely cautious about modifying global or shared state within an asynchronous block.
    
- **Timeout Management:** Every async operation MUST have a strict timeout to prevent zombie fibers from permanently hanging a worker.