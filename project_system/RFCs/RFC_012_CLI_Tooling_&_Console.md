---
title: "RFC-012: CLI Tooling & Console"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-012: CLI Tooling & Console

**Status:** Planned for Beta 0 **Components:** `waffle-commons/console` **Author:** DevSecOps Lead **Tags:** cli, dx, security-audit

## 1. Summary

This RFC specifies the creation of a Command Line Interface (CLI) application for Waffle, providing essential DevSecOps tools for cache management and security auditing.

## 2. Motivation

A modern framework requires developer tools. However, to maintain the "Micro-Component" philosophy, the console must remain extremely lightweight, relying on strict Dependency Injection without "magic" auto-discovery that slows down execution.

## 3. Technical Specifications

### 3.1 Architecture

The component will provide a `ConsoleApplicationInterface`. Commands are registered explicitly during the CLI bootstrap phase.

### 3.2 Core Commands

The framework will ship with three essential commands:

- `waffle cache:clear`: Safely flushes the `RouteCache` and any other pre-compiled data.
    
- `waffle route:list`: Prints the compiled routing table.
    
- `waffle security:audit`: **(Critical)** Parses all controllers and outputs the ABAC rules (`#[Rule]` / `#[Voter]`) applied to each route. This guarantees that no sensitive endpoints are accidentally exposed without protection.
    

## 4. Contributor Guidelines

- **Output:** CLI commands must use standard output streams (`stdout` for success, `stderr` for errors) and return appropriate exit codes (`0` for success, `>0` for failure) for CI/CD compatibility.
    
- **Dependencies:** Commands must receive their dependencies via the constructor from the DI Container. No static container access allowed.