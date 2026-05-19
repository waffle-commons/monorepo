#!/usr/bin/env bash
# /km-rag — Knowledge base RAG retrieval across wiki + code graphs
#
# Usage:  /km-rag "your query here"
#
# Queries both:
#   - wiki/graph.json (manual knowledge curation)
#   - graphify-out/graph.json (code structure analysis)
#
# Outputs ranked context for LLM injection.

set -euo pipefail

QUERY="${*}"

if [ -z "$QUERY" ]; then
  echo "Usage: /km-rag \"your query\""
  exit 1
fi

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Verify graphs exist
WIKI_GRAPH="$SCRIPT_DIR/wiki/graph.json"
GRAPHIFY_GRAPH="$SCRIPT_DIR/graphify-out/graph.json"

if [ ! -f "$WIKI_GRAPH" ] && [ ! -f "$GRAPHIFY_GRAPH" ]; then
  echo "Error: No graphs found."
  echo "  Expected: $WIKI_GRAPH (wiki knowledge)"
  echo "  Expected: $GRAPHIFY_GRAPH (code structure)"
  echo ""
  echo "Run '/project-init' to initialize, or 'npm run build:graph' and './scripts/update-project-graphify.sh'"
  exit 1
fi

# Run query against merged graphs
npx tsx "$SCRIPT_DIR/scripts/query-graph.ts" "$QUERY"
