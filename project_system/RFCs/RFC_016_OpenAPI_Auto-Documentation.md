# RFC-016: OpenAPI & Auto-Documentation

**Status:** Planned for v1.x (Post-v1.0) **Components:** `waffle-commons/openapi` **Author:** DevSecOps Lead **Tags:** swagger, openapi, documentation, dx

## 1. Summary

This RFC specifies the automated generation of API documentation based on the OpenAPI (Swagger) standard, directly derived from the codebase.

## 2. Motivation

Writing YAML/JSON OpenAPI specs manually is error-prone and quickly becomes desynchronized with the actual code. Since Waffle already utilizes Attributes for routing (`#[Route]`) and DTOs with Property Hooks for validation, the framework holds all the necessary metadata to generate accurate documentation automatically.

## 3. Technical Specifications

### 3.1 Auto-Discovery

The component will hook into the `RouteDiscoverer`. It will parse:

- `#[Route]` for paths and HTTP methods.
    
- Controller method signatures for response types.
    
- DTO structures for request payloads.
    

### 3.2 Specific Attributes

Introduction of `#[OA\Get]`, `#[OA\Post]`, `#[OA\Response]` attributes for cases where reflection is not enough to infer the exact API contract.

### 3.3 Swagger UI Integration

A development-only controller that serves the generated `openapi.json` alongside a compiled Swagger UI interface for immediate API testing.

## 4. Contributor Guidelines

- **Zero Runtime Overhead:** The OpenAPI generation must either be compiled into a static file during the build process (`waffle openapi:build`) or restricted to a `dev` environment. It must not run on production requests.