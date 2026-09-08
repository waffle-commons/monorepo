---
title: Retrospective Beta 6
date_created: 2026-08-03
date_updated: 2026-08-22
type: project
status: archived
tags:
  - project
  - retro
  - waffle
  - beta6
aliases: []
---
# ⏪ Retrospective: Waffle Beta 6 (Stabilisation, Audit & Measurement)

**Date:** August 3, 2026 **Author:** Lead Software & DevSecOps Architect

## 1. The Goal

Beta 5 shipped the runtime power — AOT, connection pooling, telemetry, WebAuthn. Beta 6 was
deliberately **not** a feature wave: stop, audit across independent engines, remediate without
compromise, bring the whole documentation surface into strict Diátaxis, and turn the
"$5\text{–}10\times$ RAM vs PHP-FPM" assertion into a measured, reproducible number ahead of the
API Platform Conference in Lille.

## 2. What Shipped

- **AXE 1 — Audit.** Two of three planned engines executed (Claude Code's 42-agent
  adversarial-verification pipeline; Google AI Studio). The third, Antigravity2, was formally
  accepted as a documented residual rather than silently dropped. Cross-engine triage resolved the
  single direct disagreement with code-level evidence.
- **AXE 2 — Remediation.** All 17 gate-blocking findings fixed natively, zero Mago baselines or
  suppressions. Two residuals closed this cycle: AOT container reset parity, and lazy voter-gated
  subject resolution making object-level (anti-IDOR) rules expressible at runtime.
- **AXE 3 — Documentation.** `documentation/` verified quadrant-partitioned; the architecture page
  rewritten from Beta-1/2-era content to the real 21-component ecosystem; two tutorials added; a
  duplicate how-to merged; every reference page verified symbol-by-symbol. Link graph: 331 links,
  zero broken.
- **AXE 5 — Benchmark.** A tri-engine k6 harness and five gate results, published in
  `bench/BENCH-GATE-RESULT.md`.
- **AXE 4 — EcoShield POC.** See §5.

## 3. What Went Well

- **The audit's own record was wrong, and checking caught it.** `Roadmap_Beta6.md` stated AXE 2 had
  not started. Verifying all 17 findings against live code showed 15 were already fixed and
  committed on 27 July. Trusting the document would have meant re-implementing finished work; the
  cost of verification was one parallel read pass.
- **Adversarial review with a refute-first bias.** 30 agents produced 0 blocking findings and 5
  important ones. One finding was *refuted* — a reviewer claimed a deleted regression test had been
  removed on a false premise; verification showed the deletion was correct. A review that can only
  add work is not a review.
- **Benchmarking the shipped artifact found bugs unit tests structurally cannot.** Nine defects
  surfaced, two of them user-facing since beta5: the production Docker image shipped **no
  PostgreSQL or MySQL PDO driver** (every database route in the template was impossible), and
  `/greet` accepted only GET while its own documentation described a POST. Controller tests passed
  throughout, because they invoke controllers directly and bypass the pipeline and the image.
- **Refusing to publish a number we could not defend.** See §4.

## 4. What Went Badly (and the lesson)

- **The benchmark harness was designed so it could not answer its own question.** Engine B was
  pinned to `pm.static, max_children=16` and every engine capped at `mem_limit: 1g` — so PHP-FPM's
  memory was constant by construction and the dependent variable was truncated. Pinning CPU is
  fairness; pinning the quantity under measurement is a category error. Worse, the error ran in
  *both* directions: it flattered FPM on memory and punished it on latency (16 children queueing in
  the listen backlog), which is why the result looked internally coherent while being wrong twice.
  **Lesson: never constrain the variable you are measuring — and when a result looks coherent,
  check whether two errors are cancelling.**
- **Two agents building one harness in parallel chose incompatible id schemes.** k6 derived
  `md5(n)`; the seed used `md5('bench-user-' || n)`. Every database read was a miss. It was
  *invisible* on Waffle, which answers a miss with `200 {"found":false}`, and loud on Symfony,
  which returns 404 — so the naive reading was "Symfony is broken" when all three engines were
  measuring nothing. **Lesson: when two engines disagree, suspect the harness before the engine;
  and a contract shared by parallel workers must be written down before either starts.**
- **A stale container silently invalidated a fix.** Bind-mounted config is read once at worker
  boot and does not change compose's config hash, so `up -d` reused a container holding the old
  configuration — making an already-correct fix look broken. `--force-recreate` is now
  unconditional, which also buys cold-start hygiene between runs.
- **The aggregate median was published before the per-rate view.** An aggregate over a ladder that
  includes saturated steps is meaningless. It was corrected within the same session, but it should
  never have been quoted.

## 5. Scope Decisions (recorded, not silent)

- **`[DOC-02]` renegotiated.** Authoring 21 per-component `docs/` trees (~80–120 h) would duplicate
  a central tree that already carries a Reference page per component. Decision: central
  `documentation/` is canonical; each component README links into it. The missing repository doc
  packs were closed — `async` had shipped beta5 with no README at all.
- **The "5–10× RAM" claim is not published in that form.** Measurement shows php-fpm uses *less*
  total RAM below ~12 concurrent requests, crossing over around 12–16 and reaching 2.37× at 128.
  The defensible claim is the growth *slope*: memory grows **10.5× slower per concurrent request**.
  A headline refutable from a laptop is worse than no headline.
- **`[BENCH-03]` soak.** Run at full length (3 h per worker engine) after an initial 30-minute pass
  bounded leak detection at only ~10 MB/h.

## 6. Carried into Beta 7

- Make pool ping-before-dispense skippable within a freshness window — identified by this benchmark
  as the doubled DB round trip behind Waffle's earlier saturation knee.
- An **equivalent-features Symfony engine** (security bundle + CSRF + transaction subscriber). Today
  the comparison is Waffle's 12-middleware secured pipeline against a bare 2-bundle app; that is a
  legitimate "out of the box" comparison but must not be read as framework overhead.
- `Constant::ATTR_PARAMS` promotion, AOT compiled-memo runtime write-through, a PHPUnit step for the
  workspace CI job.

## 7. Verdict

Beta 6 did what a stabilisation release should: it made the project **less** confident about one of
its own marketing claims and **more** confident about everything it can now prove. The audit
remediation is complete and independently reviewed; the documentation describes the code that
exists rather than the code that once did; and the performance story is a set of reproducible
numbers with their caveats attached, rather than a slogan.
