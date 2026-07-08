---
name: aot-compilation
description: "[Beta5 / RFC-019 — SHIPPED] AOT compilation operating procedure: ContainerCompiler (graph-identical CompiledContainer) + RouteTrie preheat, reflection-free hot path behind WAFFLE_AOT=1 with reflection fallback"
compatibility: opencode
---

## What I do
I maintain the **shipped** Ahead-of-Time metadata compilation (RFC-019, beta5 AXE 1): the build-time
compiler that moves dependency-graph and route resolution out of the request path so dense containers
get sub-millisecond cold starts. Contracts-first, zero-baseline, benchmark-gated. See
`[[contracts-first]]`, `[[benchmark-gate]]`, `[[worker-safety]]`.

## When to use
"compiled container", "AOT", "static router preheat", "remove runtime reflection", "regenerate the
AOT artifact", AOT-01/02/03/04.

## Shipped surface (read these before touching anything)
- **`contracts/src/Container/CompiledContainerInterface.php`** — marker interface
  (`extends ContainerInterface`). The drop-in contract: the kernel falls back to the reflection
  container when no compiled artifact loads.
- **`console/src/Compiler/ContainerCompiler.php`** (AOT-01) — the compiler. It reads the booted,
  locked runtime container's private `definitions` map by reflection (so the component stays
  contracts-only, never importing concrete `Waffle\Commons\Container\Container`) and **emits a
  generated class that COMPOSES the runtime container** as a `readonly` property. `has()`/`set()`
  delegate verbatim; only *inlinable* definitions (class-string concretes whose constructor it can
  fully resolve) get hardcoded `new \FQCN(...)` wiring — closures and pre-built objects fall through
  to `$this->runtime->get($id)`. Source is hand-assembled as strings (no `nikic/php-parser`, which
  would breach the perimeter).
- **`routing/src/Trie/RouteTrie.php`** (AOT-02/03) — segment-keyed lookup tree (`build()` from the
  priority-sorted route list; `toArray()`/`fromArray()` round-trip via `serialize()` + base64).
- **`console/src/Command/ContainerCompileCommand.php`** — `waffle container:compile [<artifact-path>]`
  (default `var/cache/CompiledContainer.php`).
- **`console/src/Command/RouteCompileCommand.php`** — `waffle route:compile [<artifact-path>]`
  (default `var/cache/routes.trie.php`); takes an OPTIONAL app-wired trie-builder closure, else
  serialises the route list and lets the router rebuild the trie at boot (mandatory fallback).
- **`waffle/src/Factory/CompiledContainerLoader.php`** — the kernel fast-path loader.

## Invariants that MUST hold (regression guards)
- **Graph identity (AOT-01):** the compiled graph is **snapshot-identical** to the runtime
  container — same concrete classes, same constructor wiring; only the *resolution mechanism* changes
  (static calls vs reflection). The snapshot test is the gate. `ContainerCompiler::emitArgument()` /
  `emitUnionArgument()` mirror `Waffle\Commons\Container\Autowire::resolveDependencies()` byte for
  byte — including the **nullable-dependency** branch (`$this->has($id) ? $this->get($id) : null`,
  because Autowire returns null for an unregistered nullable dep) and the **union** branch (a
  `has()`-guarded right-to-left ternary chain so the FIRST registered member wins). Do not "simplify"
  these to eager `get()` calls — that diverges from the runtime null/throw behaviour.
- **No new cross-request state:** the generated `get()` keeps only a per-request `$instances` memo
  (cleared each request, exactly like the runtime container's `$instances`). `reset()` cascades
  `ResettableInterface::reset()` over the memoised inlined services AND delegates to the composed
  runtime container's `reset()`. `wfl igor` must stay 0 KO.
- **Priority parity (AOT-02):** `RouteTrie` does NOT hardcode "static beats dynamic". Each route is
  tagged with its index in the priority-sorted list; lookup collects ALL path-matching candidates
  from every branch (static/dynamic/catch-all) then `usort`s by build-time order, so the trie's
  winner is identical to the sequential `Router`. 405 handling and HEAD/OPTIONS are ported verbatim.
- **Root catch-all (AOT-03):** a root-mounted `/{path:.*}` must match `/`. The trie evaluates the
  catch-all at EVERY node including when the path is exhausted (`collectCatchAll` on the terminal
  branch), matching the sequential matcher's `#^/(?P<path>.*)$#`.
- **Fast-path + fallback (AOT-04):** `CompiledContainerLoader::load()` returns the compiled container
  ONLY when `WAFFLE_AOT=1` (`1`/`true`/`on`/`yes`) AND the artifact exists AND defines the expected
  class AND it implements `CompiledContainerInterface` AND construction does not throw. ANY miss logs
  a warning and returns the runtime container unchanged — the default (no env var) keeps dev on the
  reflection path. There is **no fingerprint**: a successful load emits a prominent warning that the
  operator MUST regenerate with `bin/waffle container:compile` after ANY code change, since a stale
  artifact silently serves an outdated graph.

## Regenerate after any code change
```bash
docker exec -it -w /waffle-commons/{app} waffle-dev bin/waffle container:compile   # → var/cache/CompiledContainer.php
docker exec -it -w /waffle-commons/{app} waffle-dev bin/waffle route:compile        # → var/cache/routes.trie.php
```
Enable the fast path with `WAFFLE_AOT=1` in the worker environment; unset it (default) for dev.

## Gate (benchmark-first)
Capture the runtime-reflection boot baseline, set the improvement target against it, then prove:
compiled boot beats baseline AND the snapshot test proves graph identity (`[[benchmark-gate]]`).
Definition of done unchanged: `composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO
(`wfl dod` runs the full gate per component).
