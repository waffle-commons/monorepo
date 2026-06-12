---
name: aot-compilation
description: "[Beta5 / RFC-019 — NOT YET BUILT] Design build-time AOT compilation: CompiledContainer + Trie router preheat, reflection-free at runtime, snapshot-identical service graph"
compatibility: opencode
---

> **Status: planned (beta5 AXE 1, RFC-019). No code exists yet.** This skill is the operating
> procedure to follow when the work starts — do not claim these classes are present.

## What I do
I design the **Ahead-of-Time metadata compilation** that moves dependency-graph and route resolution
out of the request path into a CI/CD build phase, for sub-millisecond cold starts in dense containers.
Contracts-first, zero-baseline, benchmark-gated. See `[[contracts-first]]`, `[[benchmark-gate]]`.

## When to use
"compiled container", "AOT", "static router preheat", "remove runtime reflection", beta5 AOT-01/02.

## Mandates
- **AOT-01 — Compiled DI container:** a build-time compiler traverses the object graph, resolves typed
  constructor args/visibilities, and emits a native `CompiledContainer` that instantiates all
  non-synthetic services via direct constructor calls — **no runtime reflection**. The compiled graph
  must be **snapshot-identical** to the runtime container (snapshot test is the gate).
- **AOT-02 — Static router preheat:** parse `#[Route]` attributes at build time into a Trie lookup
  tree the worker loads instantly on boot — no directory scan, no runtime class parsing on the hot
  path. (Shares the metadata-parse phase with beta6 `[[api-surface]]` OpenAPI generation.)
- **Lives in monorepo tooling** (`bin/wfl` build command), emitting generated PHP into the app, not a
  new runtime dependency. The perimeter still holds (`mago guard`).

## Gate (benchmark-first)
Capture the runtime-reflection boot baseline **before** building the compiler; set the improvement
target against it. Then: compiled boot beats baseline, and the snapshot test proves graph identity.
Definition of done unchanged: `composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO.
