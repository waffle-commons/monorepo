---
name: k8s-ops
description: "Kubernetes operability: /healthz + /readyz probes, graceful drain, db:migrate/rollback/status (beta7 OPS, RFC-023)"
when_to_use: >-
  Health or readiness probes, /healthz, /readyz, HealthCheckInterface, graceful shutdown, SIGTERM,
  draining, rolling restarts, migrations and rollback on db:migrate, [OPS-01..03], RFC-023, RFC-014.
---

> **Status (2026-10-31): built and accepted (beta7 `[OPS-01..03]`).** **RFC-023** specifies `[OPS-01]` and
> `[OPS-02]`, with the decisions of 2026-10-17 in §5; `[OPS-03]` stays in RFC-014. Evidence: `Roadmap_Beta7.md`
> AXE 3 and its acceptance check. A rolling restart under k6 lost 0 of 7 501 requests on each drain path, where
> the SIGTERM-only control lost 20. `wfl drain-check` passes 9/9 on FrankenPHP 1.13.2, and migrate + rollback
> ran live on PostgreSQL, MySQL 8.4, MariaDB 11.4 and SQLite. Archives: `project_system/Audits/Beta7/`.

## What I do
I make "production-ready on Docker/K8s" true: liveness and readiness probes, a shutdown that loses no
request, and a versioned migration workflow. See `[[contracts-first]]`, `[[queue-worker]]`,
`[[data-persistence]]`, `[[worker-safety]]`, `[[security-audit]]`.

## When to use
"health / readiness probe", "/healthz", "/readyz", "graceful shutdown / SIGTERM / drain", "rolling
restart", "migrations / rollback", beta7 OPS.

## What exists (2026-10-31)
- **The worker loop** (`runtime/src/WaffleRuntime.php`) runs each request in a handler whose `finally`
  calls `$kernel->reset()` and closes the message streams. The worker learns about shutdown **only**
  when `frankenphp_handle_request()` returns `false` (`WaffleRuntime::loop()`), and nothing runs after
  the loop. Worker mode is read from `FRANKENPHP_WORKER`, or settled by the first call on FrankenPHP
  versions that do not export it.
  In worker mode PHP does not receive SIGTERM — FrankenPHP/Caddy does. (`pcntl` is installed in the dev
  and prod images since 2026-09-30, but only CLI processes such as `queue:work` can use it.)
- **Probes (`[OPS-01]`):** contracts `Health\HealthCheckInterface`; `pipeline`'s `Middleware\ProbeMiddleware`
  serves `/healthz` and `/readyz`. The skeleton's `AppKernelFactory` mounts it after `MetricsMiddleware` and
  before `TracingMiddleware` and `TrustedHostMiddleware`, so a probe opens no span and the kubelet's pod-IP
  `Host` gets through. Shipped probes: `data`'s `ConnectionPoolHealthCheck`, `cache`'s `CacheHealthCheck` and
  `queue`'s `StreamsHealthCheck`.
- **Per-check timeouts (RFC-023 §3.2, 2026-10-31):** `waffle.database.connect_timeout` (`DB_CONNECT_TIMEOUT`,
  default 2 s) as `PDO::ATTR_TIMEOUT`; a 1 s phpredis read timeout, never on the queue worker's blocking pool;
  Predis 1 s to connect and to read unless the DSN sets them; `timeoutSeconds: 3` in the Kubernetes how-to. A
  database that never answers now yields not-ready in 2 s, where a lease used to hang past 15 s.
- **Measured probe cost:** `/healthz` about 5 µs whatever the number of probes; `/readyz` about 6 µs plus
  1.1 µs per probe; nothing retained over 100 000 calls.
- **Drain (`[OPS-02]`):** `/readyz` flips through the `preStop` drain marker on Kubernetes (RFC-023 §5.1), or
  during Caddy's `shutdown_delay` elsewhere (`CADDY_SHUTDOWN_DELAY`, default `0s`; `5s` with
  `stop_grace_period: 35s` in the skeleton's `docker-compose.prod.yml`). Tools: `wfl drain-check` and
  `wfl rolling-restart --path=marker|delay|none`.
- **Migrations (`[OPS-03]`):** `console` `db:migrate` (`MigrateCommand`) runs
  `data/src/Migration/MigrationRunner.php` (`Data\Migration\MigrationRunnerInterface` in contracts). Its
  `rollback()` and `status()` work through `V.down.sql` scripts and a per-dialect ledger (contracts
  `MigrationState`, `Enum\MigrationStatus`). `console` adds `db:status`, `db:rollback [--steps=N]` and
  `make:migration`, wired into the skeleton and the workspace. A script with no SQL statement is refused, so
  an unedited scaffold cannot be recorded as applied. `data` knows six SQL dialects; the dev image has only
  `pdo_mysql`, `pdo_pgsql` and `pdo_sqlite`.

## Mandates
### `[OPS-01]` Health and readiness
`Waffle\Commons\Contracts\Health\HealthCheckInterface` lands in contracts first, and components ship
their own probes (DB pool, Redis, queue driver, disk).

- **`/readyz`** aggregates the probes **fail-closed**: an unregistered critical dependency means not
  ready.
- **`/healthz`** is liveness only (the process responds). It never checks a dependency, or one database
  blip restarts every pod.
- **Probe `Host` trap.** Kubelet probes carry the pod IP as `Host`, and `TrustedHostMiddleware` answers
  400. Mount the endpoints before it (the `MetricsMiddleware` precedent) or allow-list the probe hosts.
  A Docker `HEALTHCHECK` without a trusted `Host` fails the same way.
- **Timeouts:** each check has its own timeout, shorter than the probe's `timeoutSeconds`, so a hung
  dependency yields not-ready instead of a hung probe.
- **Cost:** probes run every few seconds, so keep them constant-time and allocation-light — lease from
  the pool (heal-on-lease already pings) rather than open connections.
- **Minimal public body** (`{"status":"ok"}`, or 503). Per-check detail goes only to loopback or a bearer
  token, like `/waffle-metrics`: dependency topology is reconnaissance data, and the probes are on the
  beta8 audit list.

### `[OPS-02]` Graceful shutdown
Stop accepting work, let in-flight requests finish, flush deferred tasks (already run per request on
`TerminateEvent`), return pooled connections, close streams, and exit within the grace period.

- **How `/readyz` flips "immediately on SIGTERM" when PHP never sees the signal — decided 2026-10-17,
  revised 2026-10-22: two paths.** A `preStop` hook sets the drain marker that flips `/readyz` (RFC-023
  §5.1). Caddy's `shutdown_delay` was first rejected because it stopped FrankenPHP 1.12.7 at SIGTERM. On
  1.13.2, adopted for PHP2Shell, PHP keeps serving through the delay, so `shutdown_delay` became the second
  path, for runtimes without a `preStop` hook (Docker, Compose, ECS). Any FrankenPHP bump re-runs
  `wfl drain-check` (9/9 on 1.13.2, 3 failures on 1.12.7). APCu still cannot carry the flag: it is per
  process, so a CLI command cannot flip the worker's APCu.
- **No explicit post-loop pool close** (decided 2026-10-17, RFC-023 §3.4): the process ends after the loop.
- Queue workers drain through `pcntl`: `[[queue-worker]]`.

### `[OPS-03]` Migration maturity
Extend `db:migrate`; never replace `MigrationRunner`. Add down scripts (a paired-file convention),
rollback of the last N versions, status (applied vs pending), and `make:migration` in the Maker
(`[[maker-scaffold]]`).

- **Naming — decided 2026-10-17:** the family keeps the `db:` prefix of the shipped `db:migrate`:
  `db:rollback`, `db:status`, plus `make:migration` (`[FRZ-03]` wants `domain:action`).
- **DDL is not transactional everywhere.** PostgreSQL, SQLite and MSSQL roll DDL back; MySQL, MariaDB
  and Oracle commit it implicitly, so a failed migration there leaves partial DDL. A round-trip test must
  account for that. Beta7 fixed the consequence found on the way: every DDL migration failed on MySQL and
  MariaDB (the implicit commit, then PHP 8's `commit()` threw).
- **Dialect matrix — scope change 2026-10-17:** the live round trip runs on PostgreSQL, SQLite, MySQL and
  MariaDB (`MigrationRoundTripTest`, `MigrationRunnerTest`); SQL Server and Oracle are covered by
  SQL-generation tests (`MigrationLedgerTest`), because no image carries `pdo_sqlsrv` or `pdo_oci`. Their live
  round trip moved to `Roadmap_Post_v1.md`.
- NoSQL backends are schema-less and out of scope.

## Gate
- `/readyz` flips on dependency failure and on SIGTERM.
- A rolling restart under k6 load loses **zero** in-flight requests. That needs ≥2 replicas behind a
  load balancer (`[[soak-endurance]]`).
- Migrate + rollback round-trip on each dialect in the agreed matrix.
- DoD: `wfl dod` for each touched component (contracts, runtime, the probe owners, data, console).
  Verify with `acceptance-verifier` (scope `OPS`).
- **Met:** the rolling restart on 2026-10-29 (`wfl rolling-restart`, archived); the `/readyz` flips and the
  migration round trip were re-checked in the acceptance check of 2026-10-31.
