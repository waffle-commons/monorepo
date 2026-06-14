---
name: k8s-ops
description: "[Beta6 / RFC-014 — NOT YET BUILT] Kubernetes operability: /healthz + /readyz probes (HealthCheckInterface), graceful SIGTERM drain, schema-migration workflow maturity on MigrationRunner"
compatibility: opencode
---

> **Status: planned (beta6 AXE 3, RFC-014). No code exists yet** (except the existing
> `data/src/Migration/MigrationRunner.php`, which OPS-03 **builds on, not rewrites**).

## What I do
I design the table-stakes that make "production-ready on Docker/K8s" real: liveness/readiness probes,
clean shutdown, and a versioned migration workflow. See `[[contracts-first]]`, `[[queue-worker]]`,
`[[worker-safety]]`.

## When to use
"health / readiness probe", "/healthz / /readyz", "graceful shutdown / SIGTERM / drain", "migrations
/ migrate:rollback", beta6 OPS.

## Mandates
- **OPS-01 — Health & readiness:** lightweight middleware exposing `/healthz` (liveness: process
  responsive) and `/readyz` (readiness: aggregated `HealthCheckInterface` probes — DB pool, Redis,
  queue driver, disk). `Waffle\Contracts\Health\HealthCheckInterface` in `contracts`; components ship
  their own probes; **fail-closed** — an unregistered critical dependency means not-ready. Handlers are
  constant-time and allocation-light (hit every few seconds by orchestrators).
- **OPS-02 — Graceful shutdown & draining:** handle SIGTERM in the runtime — stop accepting work,
  flush deferred tasks (`[[async-concurrency]]` if landed), return pooled connections (beta5 DBAL),
  close streams, exit within the configurable grace period. **`/readyz` flips to not-ready immediately
  on SIGTERM** so K8s stops routing before the drain.
- **OPS-03 — Migration workflow maturity:** build on `data/src/Migration/MigrationRunner.php` — add
  versioned migration files, a ledger table, and console commands `migrate`, `migrate:rollback`,
  `migrate:status`, `make:migration` (Maker conventions, `[[maker-scaffold]]`). SQL dialects already
  supported by `data/` only; NoSQL is schema-less, out of scope.

## Gate
`/readyz` flips on dependency failure and on SIGTERM; a rolling restart under k6 load loses **zero
in-flight requests**; `migrate` + `migrate:rollback` round-trip on every supported SQL dialect. DoD:
`composer mago` zero output, `composer tests` ≥95%, `wfl igor` 0 KO.
