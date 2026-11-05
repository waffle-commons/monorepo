---
name: contracts-first
description: "Land interfaces in contracts before consumers, hold the mago guard perimeter, fix vendor-contracts skew"
when_to_use: >-
  Adding a new interface, an RFC that says contracts-first, a mago guard perimeter violation, "tests
  fail but mago is green" (vendor-contracts skew, wfl sync:contracts), deciding which package an
  abstraction belongs in, planning any multi-component feature.
---

## What I do
I enforce the non-negotiable cross-cutting rule of every Waffle roadmap: **a new interface lands in
`waffle-commons/contracts` before any component that consumes it.** I also keep the `mago guard`
dependency perimeter honest and resolve the **vendor-contracts skew** that otherwise makes a component
pass Mago but fail PHPUnit. See `[[mago-purge]]`, `[[worker-safety]]`.

## When to use
"add a new interface", "RFC says contracts-first", "`mago guard` perimeter violation", "tests fail but
mago is green", "which package does this abstraction belong in?", planning any multi-component feature.

## The perimeter (what a component may depend on)
- **`waffle-commons/contracts`** — interfaces, enums, attributes, exception markers. Always allowed.
- **`waffle-commons/utils`** — the shared foundation (Assert, primitives). Allowed; `utils` itself
  requires **only** `contracts`. Push reusable primitives down into `utils` rather than duplicating.
- **Nothing else.** Never import a sibling's concrete classes. `mago guard` rejects circular and
  illegal cross-component imports.

AGENTS.md's "contracts-only" is the ideal; `contracts + utils` is the operative rule.

## Sequencing protocol
1. **Model the interface in `contracts` first** — strict PHP 8.5, `declare(strict_types=1)`, typed
   everything, PSR shapes where relevant. If it mutates request-scoped state, it `extends
   ResettableInterface` (and the concrete must declare that **directly** — see `[[worker-safety]]`).
2. **Gate `contracts`** (`composer mago && composer tests`) — zero output.
3. **Then** build the consumer against the interface, never the concrete.
4. **New backends/drivers implement the contract**, not a new parallel abstraction (e.g. beta5
   `DBAL-01` builds on the shipped `ConnectionPoolInterface`).

## Beta7 — the seams that land first
Planned in the roadmap:
- `RateLimit\` — `RateLimiterInterface` and `LimiterStateStorageInterface`, with an **atomic**
  check-and-consume (`[[resilience-net]]`).
- `Queue\` — `MessageInterface`, `QueueDispatcherInterface`, `QueueConsumerInterface` and
  `FailedMessageStoreInterface` (`[[queue-worker]]`).
- `Mailer\` — `MailerInterface` and a message DTO; contract only.
- `Health\` — `HealthCheckInterface` (`[[k8s-ops]]`; proposed shape in RFC-023 §3.1).
- The resilience policy, breaker and shared state-storage contracts (`[[resilience-net]]`; RFC-024).

`[CARRY-04]`, decided 2026-10-07 (the record is in `Roadmap_Beta7.md`):
- **Routes for `openapi`:** no new seam. `RouterInterface::getRoutes()` already returns `MatchedRoute`
  with the controller class, method and argument types (`[[api-surface]]`).
- **Clock:** PSR-20. `psr/clock` joins the contracts requirements. The system clock lives in `utils`,
  the frozen clock in `testing` (`[[testing-bridge]]`). New beta7 code takes it by injection.
- **Kernel for `testing`:** `KernelInterface` declares `public ContainerInterface $container { get; }`.
  There is no kernel-factory contract.
- **DTO shape:** a build-time reader in `utils`, shared by `serializer` and `openapi`. No contract.

Surfaced at kickoff, still to decide:
- a trusted-proxy client-IP resolver, for IP-keyed limiting;
- the circuit-breaker transition event type, so listeners elsewhere never import `http-client`'s
  concrete classes.

## Freeze mode (from the beta8 tag)
The beta8 tag freezes `contracts` as the v1 API (`[[api-freeze]]`):
- After the tag, a contracts change is a bug fix or nothing: no new public symbol, no signature change,
  no rename.
- Superseded symbols are deprecated in beta8 and removed in RC1.
- `contracts/BC-POLICY.md` says what the promise covers.
- Zero TODO/FIXME in contracts is part of the exit gate.

A contracts change you want after the freeze is a post-v1 (1.1) item.

## Vendor-contracts skew (the gotcha)
Each component vendors its own copy of `contracts`. After editing `contracts/src`, a consumer's
`vendor/waffle-commons/contracts/src` is **stale** — Mago may read the fresh source on disk and pass,
while PHPUnit autoloads the stale vendored copy and **fails** (mago-green ≠ phpunit-green). Before
gating a consumer, mirror fresh contracts in:
```bash
# from the umbrella root — see the contracts-sync agent
rsync -a --delete contracts/src/ {consumer}/vendor/waffle-commons/contracts/src/
docker exec -w /waffle-commons/{consumer} waffle-dev composer dump-autoload
```
- **workspace** vendor is a **symlink** (always fresh) — no rsync needed.
- **skeleton** and framework components vendor a **stale copy** — rsync + dump-autoload first.

Dispatch the **`contracts-sync`** subagent for this, or run **`wfl sync:contracts`** (the wrapper that
mirrors fresh `contracts/src` into every stale-copy consumer and dumps autoloaders). Then gate the consumer.

## Execution
```bash
docker exec -w /waffle-commons/contracts waffle-dev composer mago && \
docker exec -w /waffle-commons/contracts waffle-dev composer tests
# mirror into each consumer (or use contracts-sync), then gate the consumer
docker exec -w /waffle-commons/{consumer} waffle-dev composer guard   # perimeter holds
```
