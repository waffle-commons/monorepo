---
title: Retrospective Beta 5
date_created: 2026-07-08
date_updated: 2026-07-08
type: project
status: archived
tags:
  - project
  - retro
  - waffle
  - beta5
aliases: []
---
# ⏪ Retrospective: Waffle Beta 5 (Event-Driven, Reactive & AOT Runtime)

**Date:** July 8, 2026 **Author:** Lead Software & DevSecOps Architect

## 1. The Goal

Beta 4 made Waffle a credible Release-Candidate platform: fail-closed security, double-gated worker
safety, in-repo Academy. Beta 5 was the **expansion** wave — turn the high-performance HTTP runner into
an event-driven, reactive, Ahead-of-Time-optimized enterprise runtime — but only *after* a Gate-0
pre-release audit converted the last hardening backlog into shipped fixes. Three research spikes
(`ASYNC-01`, `REACTIVE-01`, `AUTH-01`) had to earn their place with prototypes and go/no-go evidence
before graduating into committed features, and three brand-new components had to enter the ecosystem
without breaching the `contracts` + `utils` dependency perimeter.

## 2. What Shipped

- **AXE 0 — Gate-0 hardening.** Context-aware ABAC voters via DI + a request-scoped `SecurityContext`
  (closing the IDOR capability gap with an evolved `decide()` contract), uploads moved off
  `sys_get_temp_dir()` into `php://temp`, 4xx detail masked by default, `composer audit` in the release
  path, plus the modernization backlog (`: never`, kernel constructor injection, SQL identifier
  allow-list, last `@` suppressions removed).
- **AXE 1–2 — AOT & Async.** A graph-identical `CompiledContainer` + `RouteTrie` behind `WAFFLE_AOT=1`
  with reflection fallback; the new `waffle-commons/async` Fiber finish-request deferred-task runner
  (bounded budget, per-task isolation, directly `Resettable`); and concurrent `http-client` promise
  fan-out over `curl_multi`.
- **AXE 3–4 — Reactive & Pooling.** The `#[Broadcast]` write-hook → request-scoped buffer →
  finish-request SSE flush path (no I/O in the hook); and memory-resident `PDO`/`Redis` connection pools
  (heal-on-lease) with a `TransactionIsolationMiddleware`.
- **AXE 5–6 — Telemetry & WebAuthn.** Contract-first tracing with a no-op default in `contracts`, the
  `telemetry-otel` bridge as the sole OTel-SDK importer, native DB-query spans, and the SDK-free
  `telemetry` component serving a fail-closed `/waffle-metrics`; plus stateless WebAuthn / passkeys in
  `auth` behind a single `webauthn-lib` adapter.

## 3. What Went Well

- **The perimeter survived a large expansion.** Six feature axes and three new components landed without
  a single core dependency on an SDK: OTel and `webauthn-lib` are each quarantined to one adapter that
  `mago guard` permits and nowhere else. Contracts-first sequencing meant every new interface
  (`TaskRunnerInterface`, `TracerInterface`, `PromiseInterface`, `WebAuthnVerifierInterface`, the pool
  and `CompiledContainer` interfaces, the context-aware `VoterInterface`) landed before its consumer.
- **Gate-0 before features.** Running the audit *first* meant the release couldn't ship its shiny new
  runtime on top of an unresolved HIGH finding. The context-free-voter gap was fixed at the contract
  level, so ownership/IDOR rules are now a framework capability rather than something every app re-invents.
- **Spikes stayed honest.** All three research spikes shipped, but on evidence: async carries a bounded
  budget and an explicit "move to a real queue" recommendation; the reactive path was Igor-audited across
  worker iterations; WebAuthn was validated end-to-end through a real CBOR/COSE/ES256 ceremony.
- **State kept off the heap.** The two features most likely to leak cross-request state were designed
  around it — `async`'s only state is its pending queue (reset directly), and `telemetry` puts metric
  counters in APCu shared memory, not the resettable worker heap. `wfl igor` stayed 0 KO throughout.

## 4. What To Improve

- **Onboarding a *new* component into the template-app vendors needs a checklist.** `async` shipped
  without a composer `version` and with a malformed `installed.json` dist entry in `skeleton`'s vendor —
  which crashed `composer install` with a null-download-type `TypeError` on release day. It was a
  five-minute fix, but it surfaced *at the tag*, not when the component was scaffolded. Lesson: a
  brand-new component isn't "done" until every template app can `composer install` it clean; add that to
  the `new-component` path.
- **Decide the ambiguous designs explicitly, and write them down.** `ARCH-01` (two authorization layers),
  `CPLX-04` (complexity ratchet threshold), `POLICY-05` (irreducible PSR-14 ignores), and `AUTH-01` (test
  -vector deviation) were all resolved as *recorded decisions* with rationale, not silent choices — but
  each was resolved late, during the completion pass. Surfacing "this is deliberately two things" earlier
  would save a reviewer the round-trip.
- **Complexity ratchet is a promise, not a fix.** `cyclomatic-complexity` is now enabled at threshold 50
  — just above the codebase's cohesive-design ceiling. It locks in a regression guard but explicitly
  defers the reduction work; future betas must actually tighten it, or the ratchet becomes a rubber stamp.

## 5. Conclusion

Beta 5 is the biggest single expansion of the framework's surface so far — AOT, async, reactive
broadcasting, connection pooling, distributed telemetry, and passkeys — and it landed all of it inside
the two invariants that make Waffle Waffle: the `contracts` + `utils` perimeter and the 0-KO
worker-safety gate. The security posture went *forward*, not sideways, because Gate-0 ran first. The
rough edges were operational (vendor onboarding) and organizational (late-but-recorded design
decisions), not architectural. Next: [Beta 6](../../Roadmaps/Roadmap_Beta6.md) — the production-surface
wave (queue, OpenAPI, serializer, testing bridge) toward RC1 and V1 Gold.
