# RFC-009: Configuration Management

**Status:** Implemented (Alpha 4) **Components:** `waffle-commons/config` **Author:** DevSecOps Lead **Tags:** yaml, libyaml, environment

## 1. Summary

This RFC standardizes how configuration is loaded and injected into the application using YAML files and environment variables.

## 2. Motivation

Configuration must be separated from code (12-Factor App methodology). Using YAML provides readability, while environment variable injection ensures secrets are kept out of version control.

## 3. Technical Specifications

### 3.1 Native YAML Parsing

Waffle mandates the use of the PECL `yaml` extension (`libyaml-dev`) via `yaml_parse_file()` instead of slow, userland parsers. This guarantees C-level performance during the boot phase.

### 3.2 Environment Injection

YAML files support `%env(VAR_NAME)%` syntax. The Config component parses these strings and replaces them with actual environment variables dynamically.

## 4. Contributor Guidelines

- **Type Safety:** Always use the strongly-typed getter methods (`getInt()`, `getString()`, `getBool()`) provided by the `ConfigInterface`. Avoid generic `get()` calls.
    
- **Default Values:** Provide sane defaults when retrieving configuration to prevent fatals if a non-critical key is missing.