# RFC-014: Data & Persistence Layer

**Status:** Planned for v1.x (Post-v1.0) **Components:** `waffle-commons/data` **Author:** Lead Engineer **Tags:** dbal, database, persistence, worker-safe

## 1. Summary

This RFC outlines the database abstraction layer for Waffle. It consciously rejects heavy ORMs (like Doctrine) in favor of a lightweight, highly typed Data Base Abstraction Layer (DBAL) optimized for PHP 8.5.

## 2. Motivation

Complex ORMs introduce significant overhead and memory management challenges in long-running worker processes (Memory Leaks, "MySQL server has gone away" errors). Waffle needs a native, fast abstraction that maps SQL results directly to strongly-typed DTOs.

## 3. Technical Specifications

### 3.1 Lightweight DBAL

A thin wrapper around `PDO` or `mysqli`.

- Queries will return instances of PHP 8.5 `readonly` DTOs, not associative arrays.
    
- Automatic hydration utilizing Property Hooks for validation upon retrieval.
    

### 3.2 Connection Pool Wrapper

Crucial for FrankenPHP: The component must manage database connections intelligently, pinging the server before query execution in long-running workers and reconnecting seamlessly if the connection was dropped.

### 3.3 Repository Pattern

Enforcement of the Repository pattern via interfaces. Business logic will never execute raw SQL directly but will rely on `UserRepositoryInterface` implementations.

## 4. Contributor Guidelines

- **No Lazy Loading:** To prevent N+1 query problems and unexpected database calls during serialization, the DBAL will not support lazy loading of relations.
    
- **Explicit Migrations:** Database schemas must be versioned. The component should provide a simple API for writing SQL migrations.