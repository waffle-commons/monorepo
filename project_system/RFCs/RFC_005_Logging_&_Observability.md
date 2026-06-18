---
title: "RFC-005: Logging & Observability"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-005: Logging & Observability

**Status:** Implemented — logging (Alpha 5); telemetry & metrics (Beta 5 / `0.1.0-beta5`) **Components:** `waffle-commons/log`, `waffle-commons/telemetry`, `waffle-commons/telemetry-otel` **Author:** DevSecOps Lead **Tags:** psr-3, json, cloud-native, docker, opentelemetry, prometheus, w3c-trace-context

## 1. Summary

This RFC defines how Waffle applications log data. Waffle is designed for Cloud-Native environments (Docker, Kubernetes) and mandates structured logging over traditional text files.

## 2. Motivation

In distributed systems, grep-ing text files is obsolete. Logs must be structured (JSON) and emitted to standard streams so they can be easily parsed by orchestrators and tools like Datadog, ELK, or CloudWatch.

## 3. Technical Specifications

### 3.1 StreamLogger

The `StreamLogger` component is a lightweight PSR-3 implementation. Monolog is intentionally excluded to minimize dependency bloat.

- **Format:** Strict JSON.
    
- **Destination:** `php://stdout` (Info, Notice, Access logs) and `php://stderr` (Warning, Error, Critical).
    

### 3.2 Contextual Injection

Every log entry must support contextual arrays to inject metadata (e.g., Request ID, User ID) without polluting the main message string.

## 4. Contributor Guidelines

- **No Concatenation:** Never concatenate variables into the log message string. Always use the `$context` array.
    
    - _Invalid:_ `$logger->info("User $id logged in");`
        
    - _Mandatory:_ `$logger->info("User logged in", ['user_id' => $id]);`
        
- **Exceptions:** Always pass the exception object in the context array under the `exception` key.

## 5. Telemetry & Metrics (Beta 5 — AXE 5)

Beta 5 extends observability from *logs* to *distributed traces* and *scrape-able worker metrics*, turning
long-running FrankenPHP workers into a production-grade, observable runtime. Two hard constraints shape the
design: the **dependency perimeter** (core may depend only on `contracts`, never on a vendor SDK) and
**worker statelessness** (`wfl igor` must stay 0 KO — cross-request counters may never accumulate on the
resettable worker heap).

### 5.1 Contract surface (`contracts/src/Telemetry/`)

Everything is **contracts-first**, with zero-overhead no-op defaults shipped in `contracts` so core components
need no extra dependency.

- **Tracing:** `TracerInterface` (`startSpan()`, `currentContext()`), `SpanInterface`
  (`setAttribute()`, `recordException()`, `setStatus()`, `context()`, `end()`), `SpanContextInterface`
  (`traceId()`, `spanId()`, `traceFlags()`, `traceState()`, `toTraceparent()`), `TextMapPropagatorInterface`
  (`inject()`, `extract()`); enums `SpanKind`, `SpanStatus`; no-ops `NullTracer`, `NullSpan`,
  `NullSpanContext`, `NullTextMapPropagator`.
- **Metrics:** `Metrics/MetricsRegistryInterface` (`increment()` monotonic counter, `observe()` histogram, `gauge()`),
  `Metrics/MetricsCollectorInterface` (`collect(): iterable<MetricSample>`, sampled at scrape time),
  `Metrics/MetricSample` (value object), `Metrics/PoolStatsInterface` (`activeLeases()`, `idle()`,
  `capacity()` — implemented by the AXE 4 pooler; reports zeros until then), enum `Metrics/Enum/MetricType`,
  no-op `Metrics/NullMetricsRegistry`.

### 5.2 Perimeter rule (non-negotiable)

Core components (`routing`, `security`, `waffle`, `http-client`, repositories…) emit **through the contract**
with a default of `new NullTracer()` / `NullMetricsRegistry` → effectively zero overhead when telemetry is not
wired. The OpenTelemetry SDK is **never** allowed in core; it is isolated in `waffle-commons/telemetry-otel`,
the only package whose `mago guard` perimeter permits `OpenTelemetry\**`. The SDK-free
`waffle-commons/telemetry` (perimeter = `contracts` + `utils`) provides the exporter, middleware, collectors,
decorators and the APCu registry.

### 5.3 APCu counter model (statelessness)

Cross-request counters/histograms live in **APCu shared memory** (`#[WorkerSafe]`), *off* the resettable
worker heap — this is what keeps `wfl igor` at 0 KO. Live gauges (memory, GC, DB-pool utilisation) are
**sampled at scrape time** by stateless collectors, never accumulated. When APCu is unavailable the registry
**falls back to `NullMetricsRegistry`**: `/waffle-metrics` still serves the sampled gauges, only the counters
go quiet. (Operational note: enable `apcu` + `apc.enable_cli=1` in the runtime image and in CI, or
APCu-backed metrics — and their test coverage — silently disappear.)

### 5.4 `/waffle-metrics` endpoint security (fail-closed)

The Prometheus endpoint is served by `MetricsMiddleware` in the strict Prometheus text exposition format
(`Content-Type: text/plain; version=0.0.4`). It is **fail-closed**: a request is served **only** when its
client IP is in the configured allow-list (default loopback `127.0.0.1` / `::1`) **or** it presents the
configured bearer token. Any other request receives a **404** — the endpoint's very existence is masked,
consistent with Waffle's AXE 0 endpoint-masking posture. It must never be exposed openly.

### 5.5 Distributed tracing (W3C Trace Context)

Trace propagation uses the W3C `traceparent` / `tracestate` headers. Inbound, `TracingMiddleware` opens a
`SpanKind::Server` root span (extracting any upstream parent); outbound, `http-client` injects the current
context via `TextMapPropagatorInterface::inject()` before the request leaves the worker. `telemetry-otel`
reuses OpenTelemetry's own W3C propagator rather than hand-rolling one, so a Waffle service participates
transparently in a multi-service trace.

## 6. Contributor Guidelines (Telemetry)

- **Instrument through the contract, never the SDK.** Inject `TracerInterface`/`MetricsRegistryInterface`,
  defaulting to the no-ops, so a component stays inside the `contracts`-only perimeter and pays ~0 overhead
  until telemetry is wired.
- **Never hold counters on the instance.** State that must survive a request belongs in the shared store
  (APCu), not on a `final readonly` middleware/collector field — otherwise the worker is no longer resettable.
- **Spans are `try { … } finally { $span->end(); }`.** Always end a span; set an error status and
  `recordException()` on the failure path.
- **Never ship `/waffle-metrics` open.** Keep the allow-list / bearer-token guard; default to loopback-only.