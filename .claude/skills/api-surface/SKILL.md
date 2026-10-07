---
name: api-surface
description: "OpenAPI generation + DTO serializer and content negotiation (beta7 API-01/02; scaffolded, no src yet)"
when_to_use: >-
  OpenAPI or Swagger, openapi:generate from #[Route] + DTOs, generating the API spec, serializing or
  hydrating a DTO, compiled normalizers, Accept / content negotiation, the openapi and serializer
  components, [API-01]/[API-02], RFC-016.
---

> **Status (2026-09-30):** `openapi` (`Waffle\Commons\OpenApi`) and `serializer`
> (`Waffle\Commons\Serializer`) are scaffolded and pass their DoD in scaffold mode; neither has `src/`
> yet. **Tier: High, not Committed.** Under the beta7 capacity guard, API and TEST fold into the beta8
> window unless `[API-01]`, `[API-02]` and `[TEST-01]` have code landed and green on their own gates by
> mid-October (`[[roadmap-steward]]`).

## What I do
I design the API-surface tooling that turns typed routes and DTOs into a spec, and that owns the HTTP
JSON boundary. Both are reflection-free at runtime, in line with the AOT philosophy. See
`[[contracts-first]]`, `[[aot-compilation]]`, `[[maker-scaffold]]`, `[[security-audit]]`.

## When to use
"OpenAPI / Swagger", "generate the API spec", "serialize or hydrate a DTO", "content negotiation",
beta7 API-01/02.

## Perimeter (`[CARRY-04]`, decided 2026-10-07)
`openapi:generate` reads route and DTO metadata **without importing a sibling's concrete classes**. The
record is in `Roadmap_Beta7.md`.

- **Routes come from the existing contract.** `RouterInterface::getRoutes()` returns `list<MatchedRoute>`,
  and each `MatchedRoute` carries the controller `className` and `method`, the `path`, the HTTP `methods`,
  the `name` and the `arguments` (parameter name → type). `route:list`, `route:compile` and
  `security:audit` already consume it. `security:audit` reflects on the controller method at build time,
  the pattern the generator follows. Build-time reflection is fine; runtime stays reflection-free.
- **The command lives in `openapi`.** Its class implements `Console\CommandInterface` and is registered in
  `bin/waffle` next to the console commands, with the booted router. `console` gets no generator
  contract.
- **The DTO shape comes from one reader in `utils`:** a build-time reader (constructor parameters in,
  readable properties out, hooks, asymmetric visibility, nested DTOs), shared with the serializer's
  normalizer compiler so the spec matches what the serializer accepts and emits. `openapi` and
  `serializer` both require `utils` and permit it in their `mago.toml` guard.

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
- DoD: `wfl dod openapi` and `wfl dod serializer`, plus contracts and utils if touched. Verify with
  `acceptance-verifier` (scope `API`).
