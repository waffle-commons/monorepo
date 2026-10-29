---
title: "RFC-023: Kubernetes Operability (Health, Readiness & Graceful Shutdown)"
type: rfc
tags:
  - rfc
  - waffle
aliases: []
---

# RFC-023: Kubernetes Operability (Health, Readiness & Graceful Shutdown)

**Status:** In progress for `0.1.0-beta7` — health and readiness probes (`[OPS-01]`) and graceful shutdown & draining (`[OPS-02]`). The schema-migration workflow (`[OPS-03]`) stays in RFC-014. **Components:** `waffle-commons/contracts` (`Health\HealthCheckInterface`), `waffle-commons/runtime` (shutdown sequence), the probe owners (`waffle-commons/data`, `waffle-commons/cache`, `waffle-commons/queue`), and `waffle-commons/pipeline`, which hosts the probe middleware (§5.2, decided 2026-10-17) **Author:** Core Architect **Tags:** kubernetes, health, readiness, graceful-shutdown, frankenphp, worker-mode

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
  `TrustedHostMiddleware` answers with 400. Decided (2026-10-17, §5.2): the probe middleware is
  mounted before it, as `MetricsMiddleware` already is in the skeleton.
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
  closed. Today nothing runs after the loop. *Decided 2026-10-17:* no explicit step is added. Deferred tasks
  and streams are already settled per request, and pooled connections are released per request and
  closed by PHP when the worker script ends; an explicit close would need a new contract (the pool
  contract has no `close()`, and the container cannot enumerate services by interface) for no
  observable gain before the freeze.
- **Readiness during termination.** The roadmap requires `/readyz` to report not-ready as soon as
  termination starts, so the orchestrator stops routing before the drain. PHP does not see the signal,
  so the pod's `preStop` hook flips it (decided 2026-10-17, §5.1): it creates the drain marker
  (`waffle.health.drain_marker`) and sleeps; while the marker exists `/readyz` answers 503 and PHP keeps
  serving every other request. SIGTERM follows, and Caddy's `grace_period` drains the in-flight requests.
  Where no `preStop` hook exists (Docker, Compose, ECS), Caddy flips it at SIGTERM instead (revised
  2026-10-22, §5.1): during `shutdown_delay` the skeleton Caddyfile answers `/readyz` with the public 503
  while PHP serves every other path, then the listeners close and `grace_period` drains.
- **Kubernetes sizing:** `terminationGracePeriodSeconds` must exceed the `preStop` sleep plus Caddy's
  `grace_period`, or the kubelet kills the pod mid-drain. Elsewhere the orchestrator's stop timeout
  (Docker's `stop_grace_period`, 10 s by default) must exceed `shutdown_delay` plus `grace_period`.
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

## 5. Open Questions (decided 2026-10-17)

1. **Readiness flip on termination.** Options: (a) a `preStop` hook flips a drain flag on a shared volume
   that `/readyz` reads — APCu cannot carry it, because a CLI process has its own APCu; (b) rely on
   Kubernetes removing terminating pods from Service endpoints, plus a `preStop` sleep while that
   propagates; (c) Caddy's `grace_period` alone.

   **Decision (2026-10-17, revised the same day): option (a), a drain marker.** The pod's `preStop` hook
   runs `touch /tmp/waffle-draining && sleep 5` in the container itself, so no shared volume is needed for
   a single-container pod. While the marker (`waffle.health.drain_marker`) exists, `/readyz` answers 503
   without running any probe, and PHP keeps serving every other request. SIGTERM then follows, Caddy
   closes its listeners, and `grace_period` drains what is in flight. Sizing:
   `terminationGracePeriodSeconds` > `preStop` sleep + `grace_period`. **Evidence (FrankenPHP 1.12.7,
   worker mode, 2026-10-17):** `/readyz` 503 while other paths answered 200; after SIGTERM a 2-second
   request in flight completed with 200 and the process exited 0 with no error.
   **Superseded (on FrankenPHP 1.12.7):** the first decision of the day, Caddy's global `shutdown_delay`
   with a 503 on `/readyz` while `{http.shutting_down}`, flips readiness but FrankenPHP stops at SIGTERM,
   so every PHP request during the delay got a 500 ("FrankenPHP is not running"), in classic and in worker
   mode alike. Without a `preStop` hook (plain Docker), readiness does not flip; the `grace_period` drain
   still holds.

   **Revised 2026-10-22: option (a), plus Caddy's `shutdown_delay` where no `preStop` hook exists.**
   FrankenPHP 1.13.1 keeps PHP running until Caddy has stopped
   ([php/frankenphp#2645](https://github.com/php/frankenphp/pull/2645)), and the runtime moved to 1.13.2 the
   same day for PHP2Shell. The skeleton Caddyfile now sets `shutdown_delay {$CADDY_SHUTDOWN_DELAY:0s}` and
   answers `/readyz` itself with the public 503 (`{"status":"unavailable"}`) while `{http.shutting_down}`.
   The default stays `0s`, because under Kubernetes the `preStop` marker has already flipped readiness and
   a delay would only lengthen every termination; `docker-compose.prod.yml` sets `5s` and
   `stop_grace_period: 35s`. This lifts the plain-Docker limit above, and it makes "`/readyz` flips on
   SIGTERM" (§6) literally true where no hook runs. **Evidence (2026-10-22, the same harness on both
   versions, worker and classic mode, 6 s delay):** every PHP request during the delay got 200 on
   FrankenPHP 1.13.2 and 500 on 1.12.7; a 3-second request in flight completed with 200 and the process
   exited 0 on both. `scripts/drain-check.sh` (`wfl drain-check [image]`) runs the shipped Caddyfile on a
   given image and checks both paths: all 9 checks pass on 1.13.2, 3 fail on 1.12.7. Re-run it on every
   FrankenPHP bump.
2. **Home of the probe middleware** — `waffle-commons/pipeline` hosts the infrastructure middlewares
   (`TrustedHostMiddleware`, `SecureHeadersMiddleware`) — and its position relative to the `Host` check.

   **Decision (2026-10-17):** `waffle-commons/pipeline`, mounted before `TrustedHostMiddleware`, as
   `MetricsMiddleware` is in the skeleton. **Why:** kubelet probes carry the pod IP as `Host`; mounting
   first keeps the probes clear of the host check without allow-listing pod IPs.
3. **Final names** of the contract and the configuration keys (frozen at beta8).

   **Decision (2026-10-17):** keep §3.1's names — `Contracts\Health\HealthCheckInterface` (`name()`,
   `isCritical()`, `check()`) and the `Contracts\Health\HealthResult` DTO. The application declares its
   required checks under `waffle.health.required` (a list of check names); the detailed report follows
   the access rule of `/waffle-metrics` (loopback or bearer token). Frozen at beta8 `[FRZ-01]`.
4. **Whether `HealthResult` carries a latency** that `/waffle-metrics` could export, or stays binary.

   **Decision (2026-10-17): binary.** `HealthResult` carries the status and the private detail only. The
   probe middleware times every check itself and exports the durations to `/waffle-metrics`. **Why:**
   nothing extra to freeze in the contract, and a duration measured by the runner cannot be misreported
   by a check.

## 6. Acceptance Criteria (`Roadmap_Beta7.md`)

- `/readyz` flips on dependency failure and on SIGTERM.
- A rolling restart under k6 load loses zero in-flight requests (≥2 replicas behind a load balancer).
  *Met 2026-10-29 on both drain paths with `wfl rolling-restart` (0 of 7 501 requests lost each; the
  SIGTERM-only control lost 20). Evidence and limits: `Roadmap_Beta7.md` `[OPS-02]`.*
- Standard gates: `composer mago` zero output, `composer tests` ≥95 % coverage, `wfl igor` 0 KO.
