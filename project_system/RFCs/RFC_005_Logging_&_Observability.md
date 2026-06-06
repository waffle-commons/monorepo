# RFC-005: Logging & Observability

**Status:** Implemented (Alpha 5) **Components:** `waffle-commons/log` **Author:** DevSecOps Lead **Tags:** psr-3, json, cloud-native, docker

## 1. Summary

This RFC defines how Waffle applications log data. Waffle is designed for Cloud-Native environments (Docker, Kubernetes) and mandates structured logging over traditional text files.

## 2. Motivation

In distributed systems, grep-ing text files is obsolete. Logs must be structured (JSON) and emitted to standard streams so they can be easily parsed by orchestrators and tools like Datadog, ELK, or CloudWatch.

## 3. Technical Specifications

### 3.1 StreamLogger

The `StreamLogger` component is a lightweight PSR-3 implementation. Monolog is intentionally excluded to minimize dependency bloat.

- **Format:** Strict JSON.
    
- **Destination:** `php://stdout` (Info, Notice, Access logs) and `php://stderr` (Warning, Error, Critical).
    

### 3.2 Contextual Injection

Every log entry must support contextual arrays to inject metadata (e.g., Request ID, User ID) without polluting the main message string.

## 4. Contributor Guidelines

- **No Concatenation:** Never concatenate variables into the log message string. Always use the `$context` array.
    
    - _Invalid:_ `$logger->info("User $id logged in");`
        
    - _Mandatory:_ `$logger->info("User logged in", ['user_id' => $id]);`
        
- **Exceptions:** Always pass the exception object in the context array under the `exception` key.