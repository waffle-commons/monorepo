---
description: Ingest the monorepo Waffle-Commons PHP codebase (composed of independent submodules) into the wiki knowledge graph
---

This command analyzes the Waffle-Commons umbrella and integrates all its autonomous components into the `.project-memory/wiki` knowledge graph. It understands that the root is a monorepo containing independent submodules, each with its own `composer.json`.

## Process

### Phase 1 — Set up Tooling venv
Check if `.tooling-venv/` exists at the umbrella root. If not, create it and install `graphify-code`.

### Phase 2 — Multi-Repo Component Scanning
Loop through all independent components containing a `composer.json` and ingest them collectively into the shared `graphify-out/` folder at the root.

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p graphify-out

# Detect all components with a composer.json (ignoring the vendor directory)
find . -mindepth 2 -maxdepth 3 -name "composer.json" -not -path "*/vendor/*" | while read -r COMPOSER_FILE; do
    COMPONENT_DIR=$(dirname "$COMPOSER_FILE")
    COMPONENT_NAME=$(basename "$COMPONENT_DIR")
    
    echo "Ingesting component: $COMPONENT_NAME"
    
    # Run graphify locally on the component, outputting to a namespaced graphify-out subfolder
    .tooling-venv/bin/graphify "$COMPONENT_DIR" \
        --output "graphify-out/$COMPONENT_NAME" \
        --no-viz
done
```

### Phase 3 & 4 — Build Merged Graph
Run the TypeScript mapping utilities to merge all the namespaced `graphify-out/$COMPONENT_NAME/graph.json` files into one unified knowledge graph representing the entire Waffle-Commons ecosystem, bridging code nodes with the Diátaxis documentation inside `waffle-commons/documentation/`.
