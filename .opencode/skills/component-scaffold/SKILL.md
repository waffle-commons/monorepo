---
name: component-scaffold
description: Act as the Infrastructure Architect for creating new autonomous Waffle components
compatibility: opencode
---

## What I do
I create entirely new Waffle components (e.g., `waffle-commons/cache`) adhering to the monorepo architecture with independent submodules (each released on Packagist) and PHP 8.5 standards.

## Scaffold Process
When asked to create a new component, you must execute the following steps in order:

1. **Initialize Autonomous Git Repo & Submodule:**
   ```bash
   mkdir -p {component_name}
   cd {component_name}
   git init
   # The component should later be added as a submodule to the root monorepo
   ```
2. **Generate `composer.json`:**
   Create a strict `composer.json` that depends **ONLY** on `waffle-commons/contracts`. Do not require concrete components.
3. **Scaffold Architecture:**
   ```bash
   mkdir -p src tests
   ```
4. **Enforce PHP 8.5 Standards:**
   - Every `.php` file must start with `declare(strict_types=1);`.
   - Create a strict `mago.toml` file at the root of the component (with baselines disabled).
5. **Report:**
   Output a summary confirming the initialization of the independent Git repository and the strict typing baseline.
