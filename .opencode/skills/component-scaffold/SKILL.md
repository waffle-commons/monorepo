---
name: component-scaffold
description: Act as the Infrastructure Architect for creating new autonomous Waffle components
compatibility: opencode
---

## What I do
I create entirely new Waffle components (e.g., the beta6 `queue`, `openapi`, `serializer`, `testing`
packages) adhering to the monorepo architecture: independent git submodules, each released on
Packagist, PHP 8.5 strict. **The canonical starting point is the `component-template` submodule** —
never hand-roll the skeleton; copy and adapt it so every gate (`mago.toml`, CI, `composer.json`
scripts) is already wired.

## Scaffold Process
When asked to create a new component, execute in order:

1. **Seed from `component-template`:**
   ```bash
   cp -R component-template {component_name}          # brings mago.toml, composer scripts, src/, tests/
   cd {component_name} && rm -rf .git && git init     # fresh autonomous repo
   ```
2. **Rename & strip the perimeter:**
   - Set the package name (`waffle-commons/{component_name}`) and PSR-4 namespace in `composer.json`.
   - Depend **only** on `waffle-commons/contracts` (+ `waffle-commons/utils` if you need shared
     primitives — utils itself requires only contracts). Never require a sibling's concrete classes;
     `mago guard` enforces this perimeter.
   - **Contracts-first:** any interface the component implements lands in `contracts` **before** this
     package — see `[[contracts-first]]`.
3. **Verify the inherited gates pass empty:**
   ```bash
   docker exec -it -w /waffle-commons/{component_name} waffle-dev composer mago    # ZERO output
   docker exec -it -w /waffle-commons/{component_name} waffle-dev composer tests   # ≥95%
   docker exec -it -w /waffle-commons/{component_name} waffle-dev composer igor    # 0 KO
   ```
   The inherited `mago.toml` carries **no baselines** — keep it that way.
4. **Register as a submodule:** add it to the umbrella `.gitmodules` + `bin/wfl` component list once
   the remote exists.
5. **Release:** components tag as `X.Y.Z` — **no `v` prefix** — and ship via the umbrella wave, not a
   lone `git tag`. See `[[release-manager]]` and `[[release-wave]]`.
6. **Report:** confirm the new repo, the perimeter, and that all three gates pass on the empty scaffold.
