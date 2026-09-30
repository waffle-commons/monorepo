---
name: api-surface
description: "[Beta7 AXE 4 — IN PROGRESS, scaffolded, no code yet] API tooling: waffle-commons/openapi (openapi:generate from #[Route] + DTOs, [API-01]) and waffle-commons/serializer (compiled per-DTO normalizers + Accept negotiation, [API-02]); RFC-016"
compatibility: opencode
---

> **Status (2026-09-30):** `openapi` (`Waffle\Commons\OpenApi`) and `serializer`
> (`Waffle\Commons\Serializer`) are scaffolded and pass their DoD in scaffold mode; neither has `src/`
> yet. **Tier: High, not Committed.** Under the beta7 capacity guard, API and TEST are what fold into
> the beta8 window if the new repositories are not green by mid-October (`[[roadmap-steward]]`).

## What I do
I design the API-surface tooling that turns typed routes and DTOs into a spec, and that owns the HTTP
JSON boundary. Both are reflection-free at runtime, in line with the AOT philosophy. See
`[[contracts-first]]`, `[[aot-compilation]]`, `[[maker-scaffold]]`, `[[security-audit]]`.

## When to use
"OpenAPI / Swagger", "generate the API spec", "serialize or hydrate a DTO", "content negotiation",
beta7 API-01/02.

## Perimeter first (`[CARRY-04]` — decide before the first class)
`openapi:generate` must read route and DTO metadata **without importing a sibling's concrete classes**.

- **What contracts offers today:** `Routing\RouterInterface` (`getRoutes(): array`),
  `Routing\MatchedRoute` (a `final readonly` value object of scalars and arrays), and the `#[Route]`
  attribute in `Routing\Attribute\Route`.
- **What is missing:** a route-metadata seam that exposes each route's controller class and method, so
  the generator can reflect on the signature at build time. Put it in contracts first, or record the
  exception explicitly. Build-time reflection is fine; runtime stays reflection-free.
- **Where the command lives is also open:** in `console` (the shipped perimeter: commands depend on
  contracts, concretes are wired in `bin/waffle`, as `queue:work` will be), or in the `openapi` package
  itself.

## Mandates
### `[API-01]` OpenAPI
Generate `openapi.json` (OAS **3.1**) from `#[Route]` attributes and typed controller signatures and
DTOs, with zero manual YAML.

- A build-time `openapi:generate` command, sharing the AOT metadata phase (`[[aot-compilation]]`) where
  possible.
- Optional `#[OA\*]`-style overrides. Without any attribute the spec is still valid, only terse.
- The dev-only spec and Swagger UI route is **fail-closed in production** (404 outside dev, the
  `/waffle-metrics` pattern). It ships no third-party CDN script without an explicit CSP decision. It is
  on the beta8 audit list.

### `[API-02]` Serializer
A scoped DTO ↔ JSON normalizer — request hydration and response serialization — that honours property
hooks and asymmetric visibility. It is **not** a general-purpose serializer.

- **Per-DTO normalizers compiled at build time** (the AOT philosophy), reflection-free at runtime. The
  generated code must pass mago like hand-written code.
- **Hydration goes through the constructor and `set` hooks** so validation runs
  (`ValidationException` → 422), never through a raw write that bypasses a hook. Input depth and size
  are bounded.
- **`Accept` negotiation middleware:** JSON is committed, other formats are post-v1. Nothing
  acceptable → 406; `*/*` → JSON.
- `data/`'s Hydrator stays database-only; this component owns the HTTP boundary. Error shapes follow the
  existing error-handler rendering, and `[FRZ-03]` reviews them.

## Gate
- `openapi.json` **validates against the OAS 3.1 schema** in a test. Pick a JSON Schema 2020-12 validator
  as a `require-dev` dependency; the perimeter is unaffected.
- The serializer round-trips every DTO shape in the matrix — hooks, asymmetric visibility, nested DTOs,
  arrays — and rejects the invalid cases.
- DoD: `wfl dod openapi` and `wfl dod serializer`, plus contracts and console if touched. Verify with
  `acceptance-verifier` (scope `API`).
