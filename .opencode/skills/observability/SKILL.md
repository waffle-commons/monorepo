---
name: observability
description: "[Beta5 / RFC-005 — SHIPPED] Contract-first telemetry: TracerInterface no-op default in contracts, OTel bridge in telemetry-otel, Prometheus /waffle-metrics in telemetry, native DB query spans — SDK never in core"
compatibility: opencode
---

## What I do
I maintain the **shipped** enterprise-telemetry layer (RFC-005, beta5 AXE 5) for worker mode while
keeping the core perimeter clean — vendor SDKs never enter the framework packages. See
`[[contracts-first]]` (the perimeter rule is the whole point), `[[benchmark-gate]]`, `[[worker-safety]]`.

## When to use
"OpenTelemetry / OTel", "distributed tracing", "Prometheus / Datadog", "/waffle-metrics", "DB query
span", OBS-01/02.

## Shipped surface (read these before touching anything)
- **`contracts/src/Telemetry/`** — `TracerInterface` (+ `SpanInterface`, `SpanContextInterface`,
  `TextMapPropagatorInterface`, `Enum/SpanKind`, `Enum/SpanStatus`) with **no-op defaults**
  (`NullTracer`, `NullSpan`, `NullSpanContext`, `NullTextMapPropagator`). Plus
  `contracts/src/Telemetry/Metrics/` (`MetricsCollectorInterface`, `MetricSample`,
  `MetricsRegistryInterface`/`NullMetricsRegistry`, `PoolStatsInterface`, `Enum/MetricType`).
- **`telemetry/`** — the first-party, SDK-free metrics + tracing-glue component:
  `Exporter/PrometheusExporter` (text exposition v0.0.4), `Middleware/MetricsMiddleware` (serves
  `/waffle-metrics`), `Middleware/TracingMiddleware`, `Collector/{Gc,Memory,PoolUtilization}Collector`,
  `Metric/{MetricsRegistry,ApcuMetricStore}`, `Repository/TracingRepositoryDecorator`, `Cache/MeteredCache`.
- **`telemetry-otel/`** — the OTel SDK bridge: `Trace/OtelTracer` (+ `OtelSpan`, `OtelSpanContext`),
  `Propagation/W3CTraceContextPropagator`, `Factory/OtelTracerFactory`. **This is the ONLY component
  that imports the OpenTelemetry SDK.**
- **`data/src/Telemetry/QueryTracer.php`** — opens/closes the `waffle.db.query` CLIENT span so every
  repository call appears in traces natively (no optional decorator). Defaults to `NullTracer`.

## Invariants that MUST hold (regression guards)
- **Perimeter rule (OBS-01) — the whole point:** framework core depends ONLY on
  `Waffle\Commons\Contracts\Telemetry\*`. The OpenTelemetry SDK (`OpenTelemetry\**`) lives EXCLUSIVELY
  in `telemetry-otel`; `mago guard` rejects it anywhere else. Never add the SDK to a core component to
  "make tracing work" — wire the bridge instead.
- **No-op by default = ~zero overhead:** `NullTracer::startSpan()` returns a `NullSpan` and
  `currentContext()` is always null, so tracing is free until the bridge is bound. Anything that takes
  a `TracerInterface` MUST default to `new NullTracer()` (see `QueryTracer`, `http-client/Client`).
- **Native DB spans:** `QueryTracer` is `final readonly`, holds no state, and a repository wraps the
  operation itself (`open()` → `try` / `catch fail()` / `finally end()`) so the throwing call stays in
  the method body (strict `check-throws` satisfied without an undocumented closure boundary). The
  tracer is attached via a **wither** (`withTracer(...)`), not a constructor param, on all 7 repos.
- **W3C trace context propagation:** outgoing HTTP calls inject `traceparent`/`tracestate` —
  `http-client/Client` calls `propagator->inject($tracer->currentContext(), $carrier)` per request;
  `OtelTracer::startSpan()` can continue a remote trace via `createFromRemoteParent`. Inbound
  extraction + outbound injection must stay end-to-end across two services.
- **`/waffle-metrics` is fail-closed (OBS-02):** `MetricsMiddleware` (PATH = `/waffle-metrics`)
  answers ONLY when the request presents the configured bearer token (`hash_equals`) or comes from an
  allow-listed `REMOTE_ADDR`; otherwise it returns **404** (the endpoint's existence is never revealed,
  mirroring AXE 0 LEAK-03). Every other path passes straight through. It is stateless — counters live
  in the export store (`ApcuMetricStore`), not worker memory. `PrometheusExporter` emits
  `# HELP`/`# TYPE` once per metric name.

## Gate
W3C trace context propagated end-to-end across two services; `/waffle-metrics` scrape overhead
**< 5ms** (`[[benchmark-gate]]`); the no-op default adds ~zero overhead when no SDK is bound; the
metrics middleware is stateless. Definition of done unchanged: `composer mago` zero output (incl. the
guard perimeter check that keeps the SDK out of core), `composer tests` ≥95%, `wfl igor` 0 KO
(`wfl dod` runs the full per-component gate).
