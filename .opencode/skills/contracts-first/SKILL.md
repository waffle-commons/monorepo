---
name: contracts-first
description: Sequence interfaces into waffle-commons/contracts before consumers, hold the mago guard perimeter (contracts + utils), and fix vendor-contracts skew
compatibility: opencode
---

## What I do
I enforce the non-negotiable cross-cutting rule of every Waffle roadmap: **a new interface lands in
`waffle-commons/contracts` before any component that consumes it.** I also keep the `mago guard`
dependency perimeter honest and resolve the **vendor-contracts skew** that otherwise makes a component
pass Mago but fail PHPUnit. See `[[mago-purge]]`, `[[worker-safety]]`.

## When to use
"add a new interface", "RFC says contracts-first", "`mago guard` perimeter violation", "tests fail but
mago is green", "which package does this abstraction belong in?", planning any multi-component feature.

## The perimeter (what a component may depend on)
- **`waffle-commons/contracts`** — interfaces, enums, attributes, exception markers. Always allowed.
- **`waffle-commons/utils`** — the shared foundation (Assert, primitives). Allowed; `utils` itself
  requires **only** `contracts`. Push reusable primitives down into `utils` rather than duplicating.
- **Nothing else.** Never import a sibling's concrete classes. `mago guard` rejects circular and
  illegal cross-component imports.

AGENTS.md's "contracts-only" is the ideal; `contracts + utils` is the operative rule.

## Sequencing protocol
1. **Model the interface in `contracts` first** — strict PHP 8.5, `declare(strict_types=1)`, typed
   everything, PSR shapes where relevant. If it mutates request-scoped state, it `extends
   ResettableInterface` (and the concrete must declare that **directly** — see `[[worker-safety]]`).
2. **Gate `contracts`** (`composer mago && composer tests`) — zero output.
3. **Then** build the consumer against the interface, never the concrete.
4. **New backends/drivers implement the contract**, not a new parallel abstraction (e.g. beta5
   `DBAL-01` builds on the shipped `ConnectionPoolInterface`).

## Vendor-contracts skew (the gotcha)
Each component vendors its own copy of `contracts`. After editing `contracts/src`, a consumer's
`vendor/waffle-commons/contracts/src` is **stale** — Mago may read the fresh source on disk and pass,
while PHPUnit autoloads the stale vendored copy and **fails** (mago-green ≠ phpunit-green). Before
gating a consumer, mirror fresh contracts in:
```bash
# from the umbrella root — see the contracts-sync agent
rsync -a --delete contracts/src/ {consumer}/vendor/waffle-commons/contracts/src/
docker exec -it -w /waffle-commons/{consumer} waffle-dev composer dump-autoload
```
- **workspace** vendor is a **symlink** (always fresh) — no rsync needed.
- **skeleton** and framework components vendor a **stale copy** — rsync + dump-autoload first.

Dispatch the **`contracts-sync`** subagent for this, or run **`wfl sync:contracts`** (the wrapper that
mirrors fresh `contracts/src` into every stale-copy consumer and dumps autoloaders). Then gate the consumer.

## Execution
```bash
docker exec -it -w /waffle-commons/contracts waffle-dev composer mago && \
docker exec -it -w /waffle-commons/contracts waffle-dev composer tests
# mirror into each consumer (or use contracts-sync), then gate the consumer
docker exec -it -w /waffle-commons/{consumer} waffle-dev composer guard   # perimeter holds
```
