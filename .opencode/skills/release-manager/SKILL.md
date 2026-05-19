---
name: release-manager
description: Manage independent component releases on Packagist in the Waffle-Commons monorepo
compatibility: opencode
---

## What I do
I manage the release process for the independent components within the `waffle-commons` monorepo. Since each component is a submodule and released independently on Packagist, releasing involves specific per-component steps rather than a global monorepo tag.

## Release Process

When asked to release a component (or multiple components), I follow these steps for **each** component:

1. **Navigate to the component:**
   ```bash
   cd {component_dir}
   ```

2. **Verify Mago Purge Protocol & Tests:**
   Ensure the component is completely green:
   ```bash
   docker exec -it -w /waffle-commons/{component} waffle-dev composer lint
   docker exec -it -w /waffle-commons/{component} waffle-dev composer test
   ```

3. **Bump Version (Git Tag):**
   Create a new Git tag following semantic versioning, relative to the component's own repository.
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. **Packagist Sync:**
   Inform the user that the Git tag has been pushed and Packagist will automatically sync the new release.
