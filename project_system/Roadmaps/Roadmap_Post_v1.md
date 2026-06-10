---
title: "Waffle Framework - Post-v1.0 Backlog (Vision 2027+)"
date_created: '2026-04-13'
date_updated: '2026-06-07'
type: roadmap
status: draft
tags:
  - waffle
  - future
  - r&d
  - ecosystem
aliases: []
---

# 🔮 Waffle Framework: Post-v1.0 Backlog

> **Post-v1.0 era philosophy: "From Kernel to Ecosystem."**
> Once the core is frozen (beta7) and shipped (`1.0.0` Gold, April 2027), we build the satellites needed to compete with the giants (Symfony/Laravel) on microservice use cases — without ever sacrificing performance.
> 
> **Refreshed 2026-06-07:** the original 2026-04-13 draft predates RFC-021/022 and the v1 release train (`Roadmap_v1_Master.md`). Most of its content was absorbed into pre-v1 releases — the ledger below keeps the traceability; the backlog that follows is what genuinely remains post-v1.

## 📒 ABSORPTION LEDGER (original items → where they went)

| Original item (Apr 2026) | Status | Landed in |
|---|---|---|
| Lightweight DBAL, repository pattern, connection pool | ✅ Shipped | RFC-022 (`data/`) + beta5 `[DBAL-01/02]` |
| Migration manager (CLI, versioned schemas) | 🚆 Scheduled | beta6 `[OPS-03]` |
| Fiber integration / task runner | 🧪 Spike | beta5 `[ASYNC-01]` (verdict at beta7) + `queue` component (beta6) |
| Mercure hub wrapper (real-time push) | 🧪 Spike | beta5 `[REACTIVE-01]` (verdict at beta7) |
| OpenAPI attributes, auto-discovery, Swagger UI | 🚆 Scheduled | beta6 `[API-01]` |
| Rate limiter (token bucket) | 🚆 Scheduled | beta6 `[NET-01]` |
| OIDC / OAuth2 client | ✅ Shipped | RFC-021 (`auth/`) |
| HMAC webhook signature validation | ✅ Shipped | RFC-021 (`auth/` UAB assertions) |
| Waffle Maker scaffolding | ✅ Shipped | RFC-020 + beta4 `[DX-01]` |
| Profiler (dev headers) | 🚆 Scheduled | beta6 `[DXP-01]` (stretch) |
| Testing bridge (kernel test case) | 🚆 Scheduled | beta6 `[TEST-01]` |
| AOT container & router compilation | 🚆 Scheduled | beta5 `[AOT-01/02]` |
| JIT optimization hints | 🔮 Still post-v1 | backlog §3 below |

## 🗃️ THE POST-v1 BACKLOG

### 1. Deferred by design (beta6 scoping decisions)

- **Mailer transports** (SMTP / API adapters) — the `MailerInterface` contract ships in beta6 `[QUEUE-03]`; transports are 1.x.
    
- **Additional queue drivers** — AMQP/RabbitMQ, SQS, database driver, beyond the Redis Streams reference driver.
    
- **Additional serialization formats / content negotiation** — XML, MessagePack, beyond the committed JSON.
    

### 2. Spike rejects (placeholder — finalized by the beta7 verdicts `[SPK-01..03]`)

- Whatever beta7 cuts among `[ASYNC-01]` (fiber deferral), `[REACTIVE-01]` (write-hook broadcasting), and `[AUTH-01]` (WebAuthn/passkeys) lands here, with its spike report attached as the starting point.
    

### 3. New candidates (never in the v1 train)

- **Task scheduler component** — cron-style orchestration (`schedule:run`) built on `console/` + `queue/`.
    
- **GraphQL serving layer** — `data/` already compiles GraphQL queries (RFC-022); the inbound endpoint layer is the missing half.
    
- **i18n error catalogs** for API responses (English-only at v1, per the master non-goals).
    
- **WebSockets beyond Mercure/SSE.**
    
- **JIT optimization hints** (from the original v2.0 horizon) — marginal versus the AOT gains already shipped; needs a benchmark case first.
    
- **Web profiler UI** — headers ship in beta6; visual tooling is 1.x.
    

### 4. Ecosystem & business

- **EcoShield-Gateway productization** — evolving the "Audit & Rescue" POC (`Roadmap_EcoShield_Gateway.md`) into a maintained commercial offering.
    
- **LTS execution & 1.x cadence** — policy defined at Gold (`[GOLD-02]`); execution lives here.
    

## 📊 PRIORITY MATRIX (Impact vs Effort) — to re-rank after the beta7 verdicts

| Feature | Priority | Complexity | EcoShield-Gateway justification |
| :--- | :--- | :--- | :--- |
| Queue drivers (AMQP/SQS) | 🔥 High | Medium | Gateway deployments meet existing broker infrastructure |
| Task scheduler | 🟡 Medium | Low | Recurring audits/reports in the "Audit & Rescue" offer |
| Mailer transports | 🟡 Medium | Low | Incident notifications |
| GraphQL serving | 🔵 Low | High | Not gateway-relevant; API-product relevant |
| i18n catalogs | 🔵 Low | Medium | Client-facing error policies |
| JIT hints | 🔵 Low | High | Marginal vs shipped AOT gains |

## 📝 NOTE FOR STAFF ENGINEERS

This backlog demonstrates that:

- **The core stays small.** None of this lands in `waffle-commons/waffle`; everything is a separate package behind a `contracts/` interface.
    
- **The architecture is extensible.** The middleware system, the container, and the guard perimeter let all of this bolt on without touching the frozen v1 API.
    
- **The vision is industrial.** Operational table stakes (rate limiting, queues, probes, observability, docs) were promoted *into* v1 by the release train — this backlog is growth, not survival.
