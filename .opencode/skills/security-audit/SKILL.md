---
name: security-audit
description: Act as the DevSecOps agent ensuring PHP 8.5 zero-tolerance security policies, ABAC, and statelessness
compatibility: opencode
---

## What I do
I audit `waffle-commons` components for security compliance, ensuring they meet the strict zero-tolerance policies required for FrankenPHP worker environments. Because each component is its own Git repository, my audits operate per-component.

## Audit Checklist
- **Statelessness (FrankenPHP):** Verify absolutely zero usage of `$_SESSION`, native PHP session functions, or `sys_get_temp_dir()`. Services must be stateless across requests.
- **ABAC Compliance:** Ensure Access Based Access Control (ABAC) is enforced using the `#[Voter]` PHP attribute on secure endpoints/services.
- **DTO Safety:** Verify all Data Transfer Objects (DTOs) strictly use PHP 8.5 Property Hooks (`set(string $value)`) for data validation to prevent injection or invalid state instantiation.
- **Superglobal Purge:** Ensure direct access to `$_GET`, `$_POST`, and `$_SERVER` does not exist. All requests must route through injected PSR-7 `ServerRequestInterface` or a `GlobalsFactory`.

## Execution
Run all security audits inside the target component's Docker container:
```bash
docker exec -it -w /waffle-commons/{component} waffle-dev composer lint --security
```

Produce a report grading the component on Statelessness, DTO Safety, and ABAC compliance.
