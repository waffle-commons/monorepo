---
description: Synchronize all Waffle components (Git submodules) to their latest state
---

# /sync-components

Because `waffle-commons` is a monorepo containing independent submodules, you must run this command to ensure all components are synchronized with their respective remotes.

## Execution

Run the following command at the root of the project:

```bash
git submodule update --init --recursive --remote
```

This will pull the latest commits for all components, ensuring you are working with the most up-to-date codebase across the monorepo.
