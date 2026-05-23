# Explanation

> Understanding-oriented. *Why* the monorepo is structured the way it is. Context, trade-offs, history.

If you want a recipe, read [how-to](../how-to/). If you want a signature, read [reference](../reference/). This quadrant is for the long-form rationale you read once and refer back to when a design feels surprising.

## Pages

- [**Why a monorepo of submodules?**](why-monorepo-of-submodules.md) — the strategic choice and what it costs.
- [**The Component Agnosticism rule**](component-agnosticism.md) — why every component depends only on `contracts`.
- [**The Mago Purge Protocol**](mago-purge-protocol.md) — Zero-Debt static analysis as a release gate.
- [**Docker-first development**](docker-first-development.md) — why native PHP on the host is unsupported.
- [**The release cycle**](release-cycle.md) — semver, beta tags, Packagist publication, submodule pointer bumps.

## How to read these

Explanation pages can be skipped on first read. When a rule feels arbitrary ("why can't `security` just import a class from `routing`?") come back and read the relevant page. Each one is self-contained.
