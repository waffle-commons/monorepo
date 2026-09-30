---
title: "RFC-023: Kubernetes Operability (Health, Readiness & Graceful Shutdown)"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-023: Kubernetes Operability (Health, Readiness & Graceful Shutdown)

**Status:** In progress for `0.1.0-beta7` — health and readiness probes (`[OPS-01]`) and graceful shutdown & draining (`[OPS-02]`). The schema-migration workflow (`[OPS-03]`) stays in RFC-014. **Components:** `waffle-commons/contracts` (`Health\HealthCheckInterface`), `waffle-commons/runtime` (shutdown sequence), the probe owners (`waffle-commons/data`, `waffle-commons/cache`, `waffle-commons/queue`), and the component that hosts the probe middleware (open — §5) **Author:** Core Architect **Tags:** kubernetes, health, readiness, graceful-shutdown, frankenphp, worker-mode

**Reference RFCs:** RFC-001 (Core & Runtime), RFC-003 (HTTP & Middleware Pipeline), RFC-005 (Logging & Observability), RFC-014 (Data & Persistence — `[OPS-03]`), RFC-015 (Asynchronous Execution — queue consumers)

## 1. Summary

This RFC defines how a Waffle application tells an orchestrator whether it is alive and ready, and how it
stops without losing work. These are the table stakes behind "production-ready on Docker and Kubernetes":
a liveness endpoint, a readiness endpoint that aggregates the application's critical dependencies, and a
shutdown that drains in-flight requests before the process exits.

## 2. Motivation

- **No probe exists.** The only health logic today is the connection pools' internal heal-on-lease ping.
  Applications improvise their own endpoints — the EcoShield Gateway ships an application-level
  `/__ecoshield/health`.
- **Rolling restarts must lose nothing.** Without a drain, a pod replacement cuts in-flight requests.
  The beta7 acceptance criterion is zero lost requests during a rolling restart under load.
- **Worker mode changes the signal path.** Under FrankenPHP the PHP worker never receives SIGTERM:
  FrankenPHP (Go) handles the signal, stops accepting requests, lets the running ones finish, and the
  worker only learns about the shutdown when `frankenphp_handle_request()` returns `false`
  (`runtime/src/WaffleRuntime.php`). Any design that assumes a PHP signal handler in the worker is wrong.
- **The v1 launch kit depends on it.** Gold `[LAUNCH-02]` ships Kubernetes manifests wired to
  `/healthz`, `/readyz` and the graceful drain.

## 3. Technical Specifications

### 3.1 The health contract (contracts-first)

`Waffle\Commons\Contracts\Health\HealthCheckInterface` lands in `waffle-commons/contracts` before any
consumer. Proposed shape (final names are settled in the contracts change and frozen by beta8
`[FRZ-01]`):

```php
interface HealthCheckInterface
{
    /** Stable identifier used in the detailed report, e.g. "db.pool" or "redis". */
    public function name(): string;

    /** A failing critical check makes the instance not ready. */
    public function isCritical(): bool;

    /** Returns within its own timeout and never throws: a failure is reported, not raised. */
    public function check(): HealthResult;
}
```

`HealthResult` is a `final readonly` DTO: an up/down status plus a short detail string meant for the
private view only.

### 3.2 Endpoints (`[OPS-01]`)

- **`/healthz` — liveness.** Answers 200 while the worker can serve a request. It **never** checks a
  dependency: a database blip must not make the orchestrator restart every pod.
- **`/readyz` — readiness.** Runs the registered checks and answers 200 only when every critical check
  passes, 503 otherwise. **Fail-closed:** the application declares its required checks by name in
  configuration, and a declared name with no registered check reports not-ready.
- **Public bodies are minimal** — `{"status":"ok"}` or `{"status":"unavailable"}`. The per-check report
  is served only to loopback addresses or a bearer token, like `/waffle-metrics`: dependency topology is
  reconnaissance data.
- **The `Host` check must not reject probes.** Kubelet probes carry the pod IP as `Host`, which
  `TrustedHostMiddleware` answers with 400. Recommended: mount the probe middleware before it, as
  `MetricsMiddleware` already is in the skeleton; the alternative is to allow-list the probe hosts.
- **Cost:** orchestrators call these every few seconds. Handlers are constant-time and allocation-light.
  Each check has its own timeout, shorter than the probe's `timeoutSeconds`, so a hung dependency yields
  not-ready instead of a hung probe. Pool-backed checks **lease** a connection (heal-on-lease already
  pings) instead of opening one. No result is cached in worker memory.

### 3.3 Probes shipped by components

| Component | Probe | Critical by default |
|---|---|---|
| `data` | relational pool and Redis pool: lease + heal-on-lease ping | yes, when the app configures the pool |
| `cache` | Redis-backed cache reachability | configurable |
| `queue` | Redis Streams driver reachability (once `[QUEUE-02]` lands) | yes, for consumers |
| application | anything else it depends on (disk, upstreams) | application's choice |

### 3.4 Graceful shutdown and draining (`[OPS-02]`)

- **Worker mode.** On SIGTERM, FrankenPHP stops accepting new requests and lets the in-flight ones finish
  within Caddy's `grace_period`; each worker's `frankenphp_handle_request()` then returns `false` and
  `WaffleRuntime::loop()` exits. After the loop, the runtime runs an explicit shutdown sequence: deferred
  tasks are already flushed per request on `TerminateEvent`; pooled connections are closed; streams are
  closed. Today nothing runs after the loop.
- **Readiness during termination.** The roadmap requires `/readyz` to report not-ready as soon as
  termination starts, so the orchestrator stops routing before the drain. PHP does not see the signal,
  so the mechanism is an open question (§5.1).
- **Kubernetes sizing:** `terminationGracePeriodSeconds` must exceed the `preStop` delay plus Caddy's
  `grace_period`, or the kubelet kills the pod mid-drain.
- **CLI consumers** (`bin/waffle queue:work`) are ordinary CLI processes and do receive SIGTERM. They
  drain through `pcntl` — installed in the development and production images since 2026-09-30:
  `pcntl_async_signals(true)`, a handler that sets a stop flag, then finish and acknowledge the in-flight
  message and exit before the grace period ends.

## 4. Contributor Guidelines

- **Stateless:** no health state, drain flag or cached result lives in a worker property; `wfl igor` stays
  at 0 KO.
- **Fail closed:** an unknown or missing critical dependency means not ready.
- **Liveness never checks dependencies.**
- **Probes never throw;** every failure becomes a `HealthResult`.
- **No topology in public responses.**

## 5. Open Questions (decide before the code lands)

1. **Readiness flip on termination.** Options: (a) a `preStop` hook flips a drain flag on a shared volume
   that `/readyz` reads — APCu cannot carry it, because a CLI process has its own APCu; (b) rely on
   Kubernetes removing terminating pods from Service endpoints, plus a `preStop` sleep while that
   propagates; (c) Caddy's `grace_period` alone.
2. **Home of the probe middleware** — `waffle-commons/pipeline` hosts the infrastructure middlewares
   (`TrustedHostMiddleware`, `SecureHeadersMiddleware`) — and its position relative to the `Host` check.
3. **Final names** of the contract and the configuration keys (frozen at beta8).
4. **Whether `HealthResult` carries a latency** that `/waffle-metrics` could export, or stays binary.

## 6. Acceptance Criteria (`Roadmap_Beta7.md`)

- `/readyz` flips on dependency failure and on SIGTERM.
- A rolling restart under k6 load loses zero in-flight requests (≥2 replicas behind a load balancer).
- Standard gates: `composer mago` zero output, `composer tests` ≥95 % coverage, `wfl igor` 0 KO.
