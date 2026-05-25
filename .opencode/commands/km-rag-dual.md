---
description: Dual-model RAG debate — two models challenge each other over retrieved wiki context, synthesized into a final plan
model_a: github-copilot/claude-sonnet-4.6
model_b: nim/nemotron-3-super
---

## What this does

Models used (defined in frontmatter above):
- **Agent A** — `model_a`
- **Agent B** — `model_b`
- **Synthesizer** — `model_a`

Runs a two-agent debate over retrieved wiki knowledge:
1. Retrieves relevant wiki pages for the query (same as `/km-rag`, using `.project-memory/wiki`)
2. Launches two parallel reasoning agents (`model_a` analytical, `model_b` lateral)
3. Each agent produces an answer **plus explicit pros/cons of their own reasoning**
4. A synthesis agent (`model_a`) reads both outputs, maps convergences and conflicts, and produces a final consolidated plan

## Steps

### Step 1 — RAG retrieval

Run the RAG query script:
```
npx tsx scripts/query-graph.ts "<argument>"
```

Capture the full output. This is the shared context block injected into both agents.

### Step 2 — Dual parallel debate

Launch **two Task subagents in parallel** (single message, two tool calls). Use the models defined in frontmatter: `model_a` for Agent A, `model_b` for Agent B.

**Agent A — `model_a` (analytical persona):**
> You are Agent A (`model_a`), an analytical, structured reasoner. You excel at breaking problems into components, finding gaps, and reasoning from evidence. Always identify yourself as "Agent A (`model_a`)" in your output header.
>
> Using the retrieved wiki context below, answer the user's query:
> `<argument>`
>
> Retrieved context:
> `<RAG output from Step 1>`
>
> Your output must have exactly these sections:
> **Agent A (`model_a`)**
> **Answer** — your direct response
> **Pros of this answer** — what this reasoning does well
> **Cons / blind spots** — what this reasoning might miss or get wrong
> **Confidence** — low / medium / high, with one-line justification

**Agent B — `model_b` (lateral persona):**
> You are Agent B (`model_b`), a lateral, pattern-matching reasoner. You excel at finding non-obvious connections, challenging assumptions, and surfacing what structured thinkers overlook. Always identify yourself as "Agent B (`model_b`)" in your output header.
>
> Using the retrieved wiki context below, answer the user's query:
> `<argument>`
>
> Retrieved context:
> `<RAG output from Step 1>`
>
> Your output must have exactly these sections:
> **Agent B (`model_b`)**
> **Answer** — your direct response
> **Pros of this answer** — what this reasoning does well
> **Cons / blind spots** — what this reasoning might miss or get wrong
> **Confidence** — low / medium / high, with one-line justification

### Step 3 — Synthesis

After both agents return, run a third Task subagent as synthesizer using `model_a`:

> You are a neutral moderator (`model_a`) synthesizing outputs from Agent A (`model_a`) and Agent B (`model_b`).
>
> Query: `<argument>`
>
> Agent A output (`model_a` — analytical):
> `<Agent A full output>`
>
> Agent B output (`model_b` — lateral):
> `<Agent B full output>`
>
> Produce a synthesis with these sections:
> **Synthesis (`model_a` moderator)**
> **Convergences** — points both models agree on (high confidence)
> **Conflicts** — where they disagree and why it matters
> **What Agent A missed that Agent B caught** — `model_b`'s unique contribution
> **What Agent B missed that Agent A caught** — `model_a`'s unique contribution
> **Final Plan** — the best consolidated answer, incorporating both perspectives, as a concrete actionable plan with numbered steps

### Step 4 — Present to user

Output **only** the synthesis result. Do not repeat the individual agent outputs verbatim — only reference them in the synthesis. Confirm which wiki pages were retrieved at the top (from `.project-memory/wiki`).

If no argument is provided, ask the user what topic to debate.
