---
name: observability
description: "[Beta5 / RFC-005 — NOT YET BUILT] Contract-first telemetry: TracerInterface + OTel bridge component, Prometheus /waffle-metrics; SDKs never in core"
compatibility: opencode
---

> **Status: planned (beta5 AXE 5, RFC-005). No code exists yet.** This is the procedure for when the
> work starts.

## What I do
I design **enterprise telemetry** for worker mode while keeping the core perimeter clean — vendor SDKs
never enter the framework packages. See `[[contracts-first]]` (the perimeter rule is the whole point),
`[[benchmark-gate]]`.

## When to use
"OpenTelemetry / OTel", "distributed tracing", "Prometheus / Datadog", "/waffle-metrics", beta5 OBS.

## Mandates
- **OBS-01 — OTel tracing (perimeter rule):** core components must **not** depend on the OTel SDK
  (`mago guard` would reject it). Introduce `Waffle\Contracts\Telemetry\TracerInterface` (+ span/context
  abstractions) in `contracts`, with a **no-op default**. Ship the SDK bridge as its own component
  `waffle-commons/telemetry-otel` implementing the contract. Emit spans through the contract inside
  routing resolution, ABAC voter evaluation, DB query execution, and response converters. Propagate
  **W3C Trace Context** headers on outgoing HTTP calls.
- **OBS-02 — Prometheus `/waffle-metrics`:** a secure, lightweight diagnostics middleware exporting
  memory peaks, GC cycle frequency, avg request time, DB-pool utilization, cache hit ratios — formatted
  for Prometheus/Datadog scraping.

## Gate
W3C trace context propagated end-to-end across two services; `/waffle-metrics` scrape overhead **< 5ms**
(`[[benchmark-gate]]`). The no-op default must add ~zero overhead when no SDK is bound. DoD unchanged:
`composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO; the metrics middleware is stateless
(counters live in the export adapter, not worker memory).
