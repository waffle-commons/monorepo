---
name: demo-app-wiring
description: "Wire a shipped feature into skeleton / workspace / academy (vendor skew, French, per-app conventions)"
when_to_use: >-
  "Wire X into skeleton/workspace", making a demo app use a new middleware or service, registering a
  listener in an AppKernelFactory, "the workspace doesn't pick up my contracts change" (wfl
  sync:demos), French template-app text.
---

## What I do
I take a feature that already shipped in a framework component and wire it into the **template apps**
so it is demonstrable and tested end-to-end: `skeleton` (the published starter), `workspace` (the live
FrankenPHP dev app), and `academy` (the onboarding labs/sandbox). This is the last mile after
`[[coding]]`/`[[contracts-first]]`.

## When to use
"wire X into skeleton/workspace", "make the demo app use the new middleware/service", "register the
listener in the kernel factory", "the workspace doesn't pick up my contracts change".

## Vendor model (the critical difference)
- **workspace** — `vendor/waffle-commons/*` are **symlinks** to the live component dirs. Always fresh;
  edit a component and workspace sees it immediately. No sync step.
- **skeleton** — `vendor/waffle-commons/*` are **stale copies**. After changing a component you must
  refresh skeleton's vendor before its gate is meaningful:
  ```bash
  rsync -a --delete {component}/src/ skeleton/vendor/waffle-commons/{component}/src/
  docker exec -w /waffle-commons/skeleton waffle-dev composer dump-autoload
  ```
  (Same skew that `[[contracts-first]]` documents; dispatch the `contracts-sync` agent for contracts.)
- **academy** — nested submodules (`obsidian`/`labs`/`sandbox`) using the workspace path-repo pattern;
  gate with `wfl academy:test`.

## Wiring conventions (per app `AppKernelFactory`)
- **Order matters:** build the `Client` (and other config-dependent services) **after** `$config` so
  config-sourced settings (e.g. `waffle.security.ssrf.allowed_hosts`) are available.
- **Dev-only features** key off `$env === Constant::ENV_DEV` (e.g. the DIAG connection tracker +
  `OrphanedConnectionListener`, strict container compliance scan). Prod path constructs `null` →
  `?->` no-ops → zero cost.
- **Register shared services** on the container; subscribe listeners on the right lifecycle event
  (`TerminateEvent` for teardown checks). Thread cross-cutting services (tracker, etc.) through the
  builder methods (`registerDataServices`, `buildCache`, `buildConnectionPool`, `new StreamFactory(...)`).
- **Routes & security:** follow each app's existing route table and middleware stack; CORS is wired
  **fail-closed**; `#[PublicAccess]` is the only opt-out of ABAC.
- **Config:** add keys under the existing `config/app.yaml` security/section with **French** comments.

## Beta7 wiring targets
- **`/healthz` + `/readyz`:** mount them before `TrustedHostMiddleware`, as `MetricsMiddleware` already
  is — kubelet probes carry the pod IP as `Host` (`[[k8s-ops]]`).
- **Rate limiter:** in the security part of the stack, keyed as the app decides; document the
  single-worker in-memory fallback (`[[resilience-net]]`).
- **OpenAPI route:** dev only, 404 in production (`[[api-surface]]`).
- **Testing bridge:** the Academy labs and the gateway are its first consumers (`[[testing-bridge]]`).
- **Carried from `[CARRY-09]`:** a production-image smoke test (build + one request) in CI, and hot
  reload for the skeleton's dev compose, which now inherits worker mode (code changes need a container
  restart).

## Language policy
`skeleton`, `workspace`, and `academy` (incl. academy's `docs/`/`labs/`/`sandbox/`) are **French** for
every comment, docblock, YAML/TOML/compose comment, and user-facing string. Code, namespaces, and
contracts stay **English** even there.

## Execution (in Docker)
```bash
# refresh skeleton's stale vendor copies + re-wire the demo apps after a feature lands
wfl sync:demos
# after wiring, gate each touched app
docker exec -w /waffle-commons/skeleton  waffle-dev composer mago && \
docker exec -w /waffle-commons/skeleton  waffle-dev composer tests
docker exec -w /waffle-commons/workspace waffle-dev composer mago && \
docker exec -w /waffle-commons/workspace waffle-dev composer tests
wfl academy:test
```
> **Flakiness note:** `workspace` `mago analyze` can hit Docker/macOS file-share EMFILE/ENOENT
> (`Too many open files`) — that's the file mount, not a code regression. Restart `waffle-dev` and
> re-run, or use **`wfl flake-hunt`** to re-run the gate and confirm the failure is mount flakiness
> (not a real regression) before chasing it.
