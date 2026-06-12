---
name: api-surface
description: "[Beta6 / RFC-016 — NOT YET BUILT] API tooling: new waffle-commons/openapi (openapi:generate from #[Route]/DTOs) + waffle-commons/serializer (per-DTO compiled normalizers, content negotiation)"
compatibility: opencode
---

> **Status: planned (beta6 AXE 4). Two new components: `openapi`, `serializer`. No code exists yet.**

## What I do
I design the API-surface tooling that turns typed routes + DTOs into a spec and handles the HTTP
JSON boundary — both reflection-free at runtime, aligned with the AOT philosophy. See
`[[contracts-first]]`, `[[component-scaffold]]`, `[[aot-compilation]]`, `[[maker-scaffold]]`.

## When to use
"OpenAPI / swagger", "generate the API spec", "serialize/deserialize DTO ↔ JSON", "content
negotiation", beta6 API-01/02.

## Mandates
- **API-01 — OpenAPI (`waffle-commons/openapi`):** generate `openapi.json` from existing `#[Route]`
  attributes + typed controller signatures/DTOs — **zero manual YAML**. Build-time
  `openapi:generate` console command sharing the AOT metadata-parse phase (`[[aot-compilation]]`);
  optional dev-only route serving the spec + Swagger UI. Optional `#[OA\*]`-style overrides; absence
  still yields a valid (terse) spec.
- **API-02 — DTO serializer (`waffle-commons/serializer`):** a **scoped** normalizer for strictly-typed
  DTOs ↔ JSON (request hydration + response serialization) honoring PHP 8.5 property hooks and
  asymmetric visibility — **not** a general-purpose serializer. **Per-DTO normalizers are compiled at
  build time** (same philosophy as AOT-01), reflection-free at runtime. `Accept`-header content
  negotiation middleware (JSON committed; others post-v1). `data/`'s Hydrator stays DB-only — this
  component owns the **HTTP** boundary.

## Gate
Generated `openapi.json` validates against the **OpenAPI 3.1** schema; the serializer round-trips every
DTO shape in the test matrix (hooks, asymmetric visibility, nested DTOs, arrays). New components
scaffolded from `component-template`. DoD: `composer mago` zero output, `composer tests` ≥95%, `wfl
igor` 0 KO.
