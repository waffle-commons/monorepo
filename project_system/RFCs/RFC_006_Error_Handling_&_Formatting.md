# RFC-006: Error Handling & Formatting

**Status:** Implemented (Alpha 4) **Components:** `waffle-commons/error-handler` **Author:** Core Architect **Tags:** rfc-7807, exceptions, middleware

## 1. Summary

This RFC specifies how exceptions and fatals are intercepted and presented to the client. Waffle standardizes error responses using the IETF RFC 7807 specification (Problem Details for HTTP APIs).

## 2. Motivation

APIs require predictable error formats. Throwing an exception should not result in a blank page or a raw HTML stack trace, but rather a structured JSON payload that front-end applications can easily parse.

## 3. Technical Specifications

### 3.1 ErrorHandlerMiddleware

This middleware sits at the very top of the stack. It uses a global `try/catch(\Throwable $e)` block to intercept any failure that occurs during routing, security checks, or controller execution.

### 3.2 JsonErrorRenderer

Converts exceptions into a PSR-7 Response containing a JSON payload compliant with RFC 7807.

- **Debug Mode (`app.debug = true`):** Includes file paths, line numbers, and stack traces.
    
- **Production Mode:** Strips sensitive data, returning only the status code and a generic message.
    

## 4. Contributor Guidelines

- **Custom Exceptions:** Create domain-specific exceptions extending `WaffleException` to map specific error scenarios to appropriate HTTP status codes (e.g., 404 for `NotFoundException`).
    
- **No Suppressions:** Do not use the `@` operator to suppress errors. Let them bubble up to the `ErrorHandlerMiddleware`.