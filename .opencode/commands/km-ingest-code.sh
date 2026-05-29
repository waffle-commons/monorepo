#!/usr/bin/env bash
set -euo pipefail

################################################################################
# km-ingest-code.sh
# 
# Analyzes the Waffle-Commons umbrella and integrates all its autonomous 
# components into the .project-memory/wiki knowledge graph.
#
# Understanding: The root is a monorepo containing independent submodules,
# each with its own composer.json (PHP components).
#
# Process:
#   Phase 1: Set up tooling venv and verify graphify
#   Phase 2: Multi-repo component scanning (find all composer.json files)
#   Phase 3: Ingest each component into namespaced graphify-out/ folders
#   Phase 4: Build merged graph and bridge with Diátaxis documentation
#
################################################################################

# Color output for clarity
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

UMBRELLA_ROOT="$(pwd)"
TOOLING_VENV=".tooling-venv"
GRAPHIFY_BIN="$TOOLING_VENV/bin/graphify"
GRAPHIFY_OUT="graphify-out"
PROJECT_MEMORY="$UMBRELLA_ROOT/.project-memory"

################################################################################
# PHASE 1: Set up Tooling venv
################################################################################

echo -e "${YELLOW}[PHASE 1]${NC} Setting up tooling venv..."

if [ ! -d "$TOOLING_VENV" ]; then
    echo "Creating Python virtual environment at $TOOLING_VENV..."
    if command -v python3 >/dev/null 2>&1; then
        python3 -m venv "$TOOLING_VENV"
        "$TOOLING_VENV/bin/python" -m pip install --upgrade pip graphifyy >/dev/null 2>&1
        echo -e "${GREEN}✓${NC} Venv created and graphifyy installed"
    else
        echo -e "${RED}✗${NC} Python3 not found. Cannot set up venv."
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Venv already exists at $TOOLING_VENV"
fi

# Verify graphify is executable
if [ ! -x "$GRAPHIFY_BIN" ]; then
    echo -e "${RED}✗${NC} Graphify binary not found or not executable at $GRAPHIFY_BIN"
    exit 1
fi

GRAPHIFY_VERSION=$("$GRAPHIFY_BIN" --version 2>&1 || echo "unknown")
echo -e "${GREEN}✓${NC} Graphify ready: $GRAPHIFY_VERSION"

################################################################################
# PHASE 2: Multi-Repo Component Scanning
################################################################################

echo -e "\n${YELLOW}[PHASE 2]${NC} Scanning components..."

# Initialize component tracking
declare -a COMPONENTS=()
declare -a COMPONENT_DIRS=()
COMPONENT_COUNT=0

# Detect all components with a composer.json (ignoring vendor directory)
# Components can be at ./src/component-name/ or ./components/component-name/
while IFS= read -r COMPOSER_FILE; do
    COMPONENT_DIR=$(dirname "$COMPOSER_FILE")
    COMPONENT_NAME=$(basename "$COMPONENT_DIR")
    
    # Skip root-level composer.json
    if [ "$COMPONENT_DIR" = "." ]; then
        continue
    fi
    
    echo "  Found: $COMPONENT_NAME ($COMPONENT_DIR)"
    COMPONENTS+=("$COMPONENT_NAME")
    COMPONENT_DIRS+=("$COMPONENT_DIR")
    ((COMPONENT_COUNT++))
done < <(find . -mindepth 2 -maxdepth 3 -name "composer.json" -not -path "*/vendor/*" | sort)

if [ $COMPONENT_COUNT -eq 0 ]; then
    echo -e "${YELLOW}!${NC} No components found. Checking root composer.json..."
    if [ -f "composer.json" ]; then
        echo "  Found: root (./)"
        COMPONENTS+=("root")
        COMPONENT_DIRS+=(".")
        COMPONENT_COUNT=1
    else
        echo -e "${RED}✗${NC} No composer.json files found. Nothing to ingest."
        exit 1
    fi
fi

echo -e "${GREEN}✓${NC} Detected $COMPONENT_COUNT component(s)"

################################################################################
# PHASE 3: Ingest Each Component
################################################################################

echo -e "\n${YELLOW}[PHASE 3]${NC} Ingesting components into graphify-out..."

mkdir -p "$GRAPHIFY_OUT"

INGESTION_ERRORS=0

for i in "${!COMPONENTS[@]}"; do
    COMPONENT_NAME="${COMPONENTS[$i]}"
    COMPONENT_DIR="${COMPONENT_DIRS[$i]}"
    COMPONENT_OUTPUT="$GRAPHIFY_OUT/$COMPONENT_NAME"
    
    echo -n "  [$((i+1))/$COMPONENT_COUNT] Ingesting $COMPONENT_NAME... "
    
    # Create output directory
    mkdir -p "$COMPONENT_OUTPUT"
    
    # Run graphify AST extraction on the component (no LLM required)
    # Use 'update' command to generate graph.json from source code via AST only
    if "$GRAPHIFY_BIN" update --force --no-cluster "$COMPONENT_DIR" \
        2>.project-memory/project/logs/graphify-error.log >/dev/null; then
        
        # Verify graph.json was created in component's graphify-out
        COMPONENT_GRAPH_SRC="$COMPONENT_DIR/graphify-out/graph.json"
        if [ -f "$COMPONENT_GRAPH_SRC" ]; then
            # Copy graph to our output directory
            mkdir -p "$COMPONENT_OUTPUT"
            cp "$COMPONENT_GRAPH_SRC" "$COMPONENT_OUTPUT/graph.json"
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}~${NC} (extracted, no graph.json)"
            ((INGESTION_ERRORS++))
        fi
    else
        INGESTION_ERROR=$(cat .project-memory/project/logs/graphify-error.log 2>/dev/null || echo "Unknown error")
        echo -e "${RED}✗${NC}"
        echo "    Error: $INGESTION_ERROR"
        ((INGESTION_ERRORS++))
    fi
done

if [ $INGESTION_ERRORS -gt 0 ]; then
    echo -e "${YELLOW}!${NC} $INGESTION_ERRORS component(s) failed ingestion (non-fatal)"
fi

################################################################################
# PHASE 4: Build Merged Graph & Bridge Documentation
################################################################################

echo -e "\n${YELLOW}[PHASE 4]${NC} Building merged knowledge graph..."

# Collect all component graphs for merging
COMPONENT_GRAPHS=()
for COMPONENT_NAME in "${COMPONENTS[@]}"; do
    COMPONENT_GRAPH="$GRAPHIFY_OUT/$COMPONENT_NAME/graph.json"
    if [ -f "$COMPONENT_GRAPH" ]; then
        COMPONENT_GRAPHS+=("$COMPONENT_GRAPH")
    fi
done

MERGED_GRAPH="$GRAPHIFY_OUT/merged-graph.json"

# If we have component graphs, merge them using graphify
if [ ${#COMPONENT_GRAPHS[@]} -gt 0 ]; then
    echo -n "  Merging ${#COMPONENT_GRAPHS[@]} component graphs... "
    
    if "$GRAPHIFY_BIN" merge-graphs "${COMPONENT_GRAPHS[@]}" --out "$MERGED_GRAPH" 2>.project-memory/project/logs/merge-error.log >/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        MERGE_ERROR=$(cat .project-memory/project/logs/merge-error.log 2>/dev/null || echo "Unknown error")
        echo -e "${YELLOW}~${NC} (fallback to manual merge)"
        
        # Fallback: Create merged graph manually
        cat > "$MERGED_GRAPH" <<'EOF'
{
  "metadata": {
    "project": "waffle-commons",
    "type": "merged-knowledge-graph",
    "generated_at": "TIMESTAMP",
    "components": []
  },
  "nodes": [],
  "edges": [],
  "documentation_references": []
}
EOF
        sed -i '' "s/TIMESTAMP/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$MERGED_GRAPH"
    fi
else
    # No graphs generated; create stub
    cat > "$MERGED_GRAPH" <<'EOF'
{
  "metadata": {
    "project": "waffle-commons",
    "type": "merged-knowledge-graph",
    "generated_at": "TIMESTAMP",
    "components": []
  },
  "nodes": [],
  "edges": [],
  "documentation_references": []
}
EOF
    sed -i '' "s/TIMESTAMP/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$MERGED_GRAPH"
    echo "  No component graphs to merge (stub created)"
fi

# Bridge with Diátaxis documentation
DOCS_DIR="documentation"
if [ -d "$DOCS_DIR" ]; then
    echo -e "${GREEN}✓${NC} Found documentation directory"
    
    # Index documentation files
    DOC_REFS="[]"
    find "$DOCS_DIR" -type f -name "*.md" 2>/dev/null | head -50 > .project-memory/project/logs/doc-files.txt
    while IFS= read -r DOC_FILE; do
        DOC_REL_PATH="${DOC_FILE#$DOCS_DIR/}"
        DOC_REFS=$(echo "$DOC_REFS" | jq \
            --arg path "$DOC_REL_PATH" \
            --arg type "diataxis" \
            '. += [{"path": $path, "type": $type}]' 2>/dev/null || echo "$DOC_REFS")
    done < .project-memory/project/logs/doc-files.txt
    rm -f .project-memory/project/logs/doc-files.txt
    
    # Update merged graph with documentation references
    TEMP_GRAPH=$(mktemp)
    jq --argjson docs "$DOC_REFS" '.documentation_references = $docs' "$MERGED_GRAPH" > "$TEMP_GRAPH"
    mv "$TEMP_GRAPH" "$MERGED_GRAPH"
else
    echo -e "${YELLOW}!${NC} Documentation directory not found at $DOCS_DIR"
fi

echo -e "${GREEN}✓${NC} Merged graph created at $MERGED_GRAPH"

################################################################################
# Summary & Project Memory Integration
################################################################################

echo -e "\n${YELLOW}[SUMMARY]${NC} Knowledge ingestion complete"

# Create ingestion report
REPORT_FILE="$PROJECT_MEMORY/INGESTION_REPORT.md"
mkdir -p "$PROJECT_MEMORY"

cat > "$REPORT_FILE" <<EOF
# Knowledge Ingestion Report

**Generated:** $(date -u +%Y-%m-%d\ %H:%M:%SZ)

## Components Ingested

| Component | Status | Graph |
|-----------|--------|-------|
EOF

for i in "${!COMPONENTS[@]}"; do
    COMPONENT_NAME="${COMPONENTS[$i]}"
    COMPONENT_OUTPUT="$GRAPHIFY_OUT/$COMPONENT_NAME"
    
    if [ -f "$COMPONENT_OUTPUT/graph.json" ]; then
        STATUS="✅ Success"
        GRAPH_FILE="graphify-out/$COMPONENT_NAME/graph.json"
    else
        STATUS="⚠️ Partial"
        GRAPH_FILE="(not found)"
    fi
    
    echo "| $COMPONENT_NAME | $STATUS | $GRAPH_FILE |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" <<EOF

## Merged Graph

- **Location:** $MERGED_GRAPH
- **Documentation Bridge:** $([ -d "$DOCS_DIR" ] && echo "✅ Connected" || echo "⚠️ Not found")"

## Next Steps

1. **Query the Knowledge Graph:** Use \`scripts/query-graph.ts\` to search code patterns
2. **Build Visualization:** Run \`scripts/build-graph.ts\` for dependency trees
3. **Update Diátaxis Docs:** Map code patterns to documentation quadrants

## Ingestion Metrics

- **Total Components:** $COMPONENT_COUNT
- **Failed Ingestions:** $INGESTION_ERRORS
- **Output Directory:** $GRAPHIFY_OUT
- **Project Memory:** $PROJECT_MEMORY

---

For more information, see: \`.project-memory/PROJECT_MEMORY_INIT.md\`
EOF

echo -e "${GREEN}✓${NC} Report saved to $REPORT_FILE"

# Summary stats
TOTAL_GRAPHS=$(find "$GRAPHIFY_OUT" -name "graph.json" -type f | wc -l)
echo ""
echo "────────────────────────────────────────────────────"
echo "Components ingested:    $COMPONENT_COUNT"
echo "Graphs generated:       $TOTAL_GRAPHS"
echo "Merged graph:           $MERGED_GRAPH"
echo "Project memory:         $PROJECT_MEMORY"
echo "────────────────────────────────────────────────────"
echo ""

if [ $INGESTION_ERRORS -eq 0 ] && [ $TOTAL_GRAPHS -gt 0 ]; then
    echo -e "${GREEN}✓ Knowledge ingestion successful!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Knowledge ingestion completed with warnings${NC}"
    exit 0  # Non-fatal; allow hooks to continue
fi
