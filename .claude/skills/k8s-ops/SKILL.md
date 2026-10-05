---
name: k8s-ops
description: "Kubernetes operability: /healthz + /readyz, graceful drain, db:migrate workflow (beta7 OPS, not built yet)"
when_to_use: >-
  Health or readiness probes, /healthz, /readyz, HealthCheckInterface, graceful shutdown, SIGTERM,
  draining, rolling restarts, migrations and rollback on db:migrate, [OPS-01..03], RFC-023, RFC-014.
---

> **Status (2026-09-30): committed beta7 scope.** `[OPS-03]` extends code that already exists
> (RFC-014). `[OPS-01]` and `[OPS-02]` start from zero; **RFC-023** specifies them and lists the design
> questions to settle before their code lands.

## What I do
I make "production-ready on Docker/K8s" true: liveness and readiness probes, a shutdown that loses no
request, and a versioned migration workflow. See `[[contracts-first]]`, `[[queue-worker]]`,
`[[data-persistence]]`, `[[worker-safety]]`, `[[security-audit]]`.

## When to use
"health / readiness probe", "/healthz", "/readyz", "graceful shutdown / SIGTERM / drain", "rolling
restart", "migrations / rollback", beta7 OPS.

## What exists to build on (verified 2026-09-30)
- **The worker loop** (`runtime/src/WaffleRuntime.php`) runs each request in a handler whose `finally`
  calls `$kernel->reset()` and closes the message streams. The worker learns about shutdown **only**
  when `frankenphp_handle_request()` returns `false` (`WaffleRuntime::loop()`), and nothing runs after
  the loop. Worker mode is read from `FRANKENPHP_WORKER`, or settled by the first call on FrankenPHP
  versions that do not export it.
  In worker mode PHP does not receive SIGTERM — FrankenPHP/Caddy does. (`pcntl` is installed in the dev
  and prod images since 2026-09-30, but only CLI processes such as `queue:work` can use it.)
- **Middleware order precedent:** in `skeleton/src/Factory/AppKernelFactory.php`, `MetricsMiddleware` is
  added before `TrustedHostMiddleware` (lines 339-355), so `/waffle-metrics` answers whatever the
  `Host` header says.
- **Migrations:** `console` `db:migrate` (`MigrateCommand`) runs `data/src/Migration/MigrationRunner.php`
  (`Data\Migration\MigrationRunnerInterface` in contracts).
  - It applies forward-only `*.sql` files in lexicographic version order, each in its own transaction.
  - It records them in the `waffle_migrations(version, applied_at)` ledger.
  - It has no rollback, no status and no generator.
  - `data` knows six SQL dialects (MySQL, MariaDB, SQLite, MSSQL, PostgreSQL, Oracle); the dev image
    has only `pdo_mysql`, `pdo_pgsql` and `pdo_sqlite`.

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

- **Open design decision: how `/readyz` flips "immediately on SIGTERM"** when PHP never sees the
  signal. Options to weigh:
  - a `preStop` hook that flips a shared drain flag — a file on a shared volume works, APCu does not
    (it is per process, so a CLI command cannot flip the worker's APCu);
  - relying on K8s removing terminating pods from Service endpoints, plus a `preStop` sleep while that
    propagates;
  - FrankenPHP/Caddy's own `grace_period`.
  Record the decision in an RFC or the roadmap before coding.
- After the loop exits, add the explicit shutdown steps (close the pools); today the process simply ends.
- Queue workers drain through `pcntl`: `[[queue-worker]]`.

### `[OPS-03]` Migration maturity
Extend `db:migrate`; never replace `MigrationRunner`. Add down scripts (a paired-file convention),
rollback of the last N versions, status (applied vs pending), and `make:migration` in the Maker
(`[[maker-scaffold]]`).

- **Naming is open.** The roadmap lists `migrate`, `migrate:rollback`, `migrate:status` and
  `make:migration`, but the shipped command is `db:migrate` and `[FRZ-03]` wants `domain:action`. Decide
  once (e.g. `db:migrate`, `db:rollback`, `db:status`) and keep it.
- **DDL is not transactional everywhere.** PostgreSQL, SQLite and MSSQL roll DDL back; MySQL, MariaDB
  and Oracle commit it implicitly, so a failed migration there leaves partial DDL. A round-trip test must
  account for that.
- **Dialect matrix.** "Round-trip on every supported SQL dialect" is testable today only for MySQL,
  MariaDB (through `pdo_mysql`), PostgreSQL and SQLite. MSSQL and Oracle need drivers and services, or a
  recorded scope change — the maintainer's call.
- NoSQL backends are schema-less and out of scope.

## Gate
- `/readyz` flips on dependency failure and on SIGTERM.
- A rolling restart under k6 load loses **zero** in-flight requests. That needs ≥2 replicas behind a
  load balancer (`[[soak-endurance]]`).
- Migrate + rollback round-trip on each dialect in the agreed matrix.
- DoD: `wfl dod` for each touched component (contracts, runtime, the probe owners, data, console).
  Verify with `acceptance-verifier` (scope `OPS`).
