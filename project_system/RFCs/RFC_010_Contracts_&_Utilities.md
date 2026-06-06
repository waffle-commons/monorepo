# RFC-010: Contracts & Utilities

**Status:** Implemented, Strict Hardening in Alpha 6 **Components:** `waffle-commons/contracts`, `waffle-commons/utils` **Author:** Core Architect **Tags:** interfaces, mago-pure, reflection

## 1. Summary

This RFC defines the bedrock of the Waffle ecosystem. The `contracts` component contains all interfaces, and `utils` contains shared logic (like Reflection traits).

## 2. Motivation

To prevent circular dependencies and monolithic coupling, components must only depend on `waffle-commons/contracts`, never on each other's concrete implementations.

## 3. Technical Specifications

### 3.1 The Agnosticism Rule

No package (except `waffle` core) is allowed to `require` another concrete Waffle package in its `composer.json`. They must rely exclusively on the interfaces defined in `contracts`.

### 3.2 Alpha 6 "Zero Tolerance" (Mago Purity)

These foundational components must achieve an absolute 0-error rate in Mago static analysis without any baseline files.

- Types must be explicitly declared (no `mixed` unless absolutely necessary and documented).
    
- Cyclomatic complexity must remain low.
    

## 4. Contributor Guidelines

- **BC Breaks:** Modifying an interface in `contracts` is a Breaking Change and requires a minor version bump (e.g., 0.1 to 0.2). Do so with extreme caution.