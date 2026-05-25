#!/usr/bin/env bash
set -euo pipefail
GRAPHIFY_BIN=".tooling-venv/bin/graphify"
if [ ! -x "$GRAPHIFY_BIN" ]; then exit 0; fi

# In a multi-repo, Graphify must be run iteratively over components (handled by km-ingest-code).
# This script triggers that global ingestion.
if [ -x "./.opencode/commands/km-ingest-code.sh" ]; then
    ./.opencode/commands/km-ingest-code.sh --force
fi
