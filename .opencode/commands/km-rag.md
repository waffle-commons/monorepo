---
description: Retrieve relevant wiki context for a query using the knowledge graph
---

## What this does

Queries `.project-memory/graph-wiki.json` (the wiki knowledge graph) to find the most relevant wiki pages for the given topic, then injects the retrieved context into this conversation so subsequent tasks have the right background knowledge.

The RAG query also searches `graphify-out/graph.json` (the code knowledge graph) in parallel, so results may include both wiki articles and code nodes with their source context.

## Steps

1. Run the RAG query script with the user's argument as the query:
   ```
   npx tsx scripts/query-graph.ts "<argument>"
   ```
2. Read the output — it is a compact context block with matched wiki pages.
3. Use the retrieved context to inform your next actions. Do NOT repeat the full retrieved text back to the user — just confirm what was found and proceed with the task.

If no argument is provided, ask the user what topic they need context for.
