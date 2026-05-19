# Knowledge Ingestion System — Complete Setup ✅

**Project:** waffle-commons (PHP 8.5 monorepo)  
**Date:** 2026-05-17  
**Status:** Fully Operational

## What Was Delivered

### 1. Automated Knowledge Ingestion Command ✅

**Script:** `.opencode/commands/km-ingest-code.sh`

A production-ready shell script that:
- **Discovers** 18 autonomous PHP components via `composer.json` scanning
- **Extracts** AST-based code graphs from each component (no LLM required)
- **Merges** component graphs into a unified knowledge base
- **Bridges** documentation with Diátaxis categories

### 2. Git Hook Integration ✅

**Hooks Installed:** `.git/hooks/`

| Hook | Trigger | Action |
|------|---------|--------|
| `pre-commit` | Before commit | Update knowledge graph |
| `post-checkout` | After branch switch | Refresh knowledge |
| `post-merge` | After merge | Sync graphs |
| `post-rewrite` | After rebase/amend | Update graphs |

**Result:** Knowledge graph updates automatically on every Git event.

### 3. Multi-Component Graph Extraction ✅

**Output:** `graphify-out/`

```
graphify-out/
├── cache/graph.json               # ✅ Extracted
├── component-template/graph.json  # ✅ Extracted
├── config/graph.json              # ✅ Extracted
├── console/graph.json             # ✅ Extracted
├── container/graph.json           # ✅ Extracted
├── contracts/graph.json           # ✅ Extracted
├── error-handler/graph.json       # ✅ Extracted
├── event-dispatcher/graph.json    # ✅ Extracted
├── http/graph.json                # ✅ Extracted
├── log/graph.json                 # ✅ Extracted
├── pipeline/graph.json            # ✅ Extracted
├── routing/graph.json             # ✅ Extracted
├── runtime/graph.json             # ✅ Extracted
├── security/graph.json            # ✅ Extracted
├── skeleton/graph.json            # ✅ Extracted
├── utils/graph.json               # ✅ Extracted
├── waffle/graph.json              # ✅ Extracted
├── workspace/graph.json           # ✅ Extracted
└── merged-graph.json              # ✅ Unified knowledge base
```

**Graph Contents:**
- Classes, interfaces, traits
- Methods, functions, properties
- Type relationships and dependencies
- Import chains across components
- Namespace organization

### 4. Documentation Bridge ✅

**Connection:** Merged graph ↔️ `documentation/` directory

The knowledge system indexes:
- Tutorials (learning-oriented guides)
- How-to guides (problem-solving patterns)
- Reference docs (API, attributes, PHP 8.5 features)
- Explanation (architectural understanding)

### 5. Project Memory Infrastructure ✅

**Location:** `.project-memory/`

```
.project-memory/
├── PROJECT_MEMORY_INIT.md              # Setup overview
├── INITIALIZATION_CHECKLIST.md         # Status tracker
├── INGESTION_REPORT.md                 # Latest run metrics
├── KM_INGEST_CODE_GUIDE.md            # This system's guide
├── KNOWLEDGE_INGESTION_SUMMARY.md      # You are here
├── project/
│   ├── architecture/                   # ADRs, diagrams
│   ├── decisions/                      # Design decisions
│   ├── features/                       # Feature specs
│   └── logs/                           # Development logs
├── permanent/                          # Long-term knowledge
├── references/                         # External links
└── graphify/
    └── project/                        # Graphify metadata
```

## Performance Metrics

**Last Ingestion Run:**

| Metric | Value |
|--------|-------|
| Components Scanned | 18 |
| Components Successfully Extracted | 18 |
| Failed Extractions | 0 |
| Graphs Generated | 18 |
| Merged Graph | ✅ Created |
| Documentation Files Indexed | 40+ |
| Total Execution Time | ~50s |
| Exit Code | 0 (Success) |

**Per-Component Performance:**
- Average extraction time: 2.7 seconds
- Smallest component: `contracts/` (~0.5s)
- Largest component: `waffle/` (~5s)

## Automatic Triggers

The knowledge graph updates **without manual intervention** on:

```bash
# Committed code changes
git commit -m "Add new feature"
# → Triggers pre-commit hook → Updates graphs

# Switched branches
git checkout main
# → Triggers post-checkout hook → Refreshes knowledge

# Merged pull requests
git merge feature/x
# → Triggers post-merge hook → Syncs graphs

# Rebased commits
git rebase -i HEAD~3
# → Triggers post-rewrite hook → Updates graphs
```

## How to Use the Knowledge System

### 1. Query the Knowledge Graph

```bash
# Find classes implementing a contract
.tooling-venv/bin/graphify query "classes implementing CacheInterface" \
  --graph graphify-out/merged-graph.json

# Find shortest path between two symbols
.tooling-venv/bin/graphify path "Request" "Response" \
  --graph graphify-out/merged-graph.json

# Explain a specific node
.tooling-venv/bin/graphify explain "Pipeline\MiddlewareDispatcher" \
  --graph graphify-out/merged-graph.json
```

### 2. Visualize Dependencies

```bash
# Generate tree view of code structure
.tooling-venv/bin/graphify tree \
  --graph graphify-out/merged-graph.json \
  --output graphify-out/dependency-tree.html

# Export call-flow diagram (Mermaid)
.tooling-venv/bin/graphify export callflow-html \
  --graph graphify-out/merged-graph.json
```

### 3. Manual Re-ingestion (if needed)

```bash
# Re-run knowledge ingestion anytime
.opencode/commands/km-ingest-code.sh

# Re-extract a specific component
.tooling-venv/bin/graphify update ./cache
```

### 4. Integrate with AI Tools

Install Graphify into your AI environment:

```bash
# For Claude (Claude Code)
.tooling-venv/bin/graphify claude install

# For Cursor
.tooling-venv/bin/graphify cursor install

# For VS Code Copilot
.tooling-venv/bin/graphify vscode install
```

This gives your AI assistant direct access to the code graph.

## Key Features

✅ **Zero LLM Cost** — AST-only extraction requires no API keys

✅ **Fully Offline** — Runs completely locally, no external services

✅ **Multi-Component** — Handles all 18 waffle-commons components

✅ **Automatic Updates** — Triggers on every Git event

✅ **Non-Blocking** — Doesn't fail commits if ingestion has issues

✅ **Fast** — ~50s for full monorepo extraction

✅ **Monorepo-Ready** — Supports future component independence

✅ **Documentation Bridging** — Connects code to Diátaxis docs

## Architecture

```
.git/hooks/pre-commit, post-checkout, post-merge, post-rewrite
         ↓
    ./scripts/update-project-graphify.sh
         ↓
    .opencode/commands/km-ingest-code.sh
         ├─ Phase 1: Setup Tooling venv
         ├─ Phase 2: Scan Components (find composer.json)
         ├─ Phase 3: Extract Code Graphs (graphify update)
         └─ Phase 4: Merge & Bridge Documentation
         ↓
    graphify-out/
    ├── cache/graph.json
    ├── config/graph.json
    ├── ... (16 more components)
    └── merged-graph.json
         ↓
    .project-memory/
    └── INGESTION_REPORT.md
```

## Next Steps

1. **Populate Project Memory**
   - Add architectural ADRs to `.project-memory/project/architecture/`
   - Create feature specs in `.project-memory/project/features/`
   - Log development progress in `.project-memory/project/logs/`

2. **Query Knowledge Graphs**
   - Use Graphify CLI to explore code relationships
   - Map cross-component dependencies
   - Identify architectural patterns

3. **Extend Documentation**
   - Add new Diátaxis docs to `documentation/`
   - Tag documentation with code nodes they reference
   - Build a living knowledge base

4. **Monitor Ingestion**
   - Check `.project-memory/INGESTION_REPORT.md` after commits
   - Validate `graphify-out/merged-graph.json` structure
   - Alert on ingestion failures (currently non-fatal)

5. **CI/CD Integration** (Optional)
   - Configure GitHub Actions to run ingestion on push
   - Store knowledge graphs as CI artifacts
   - Report ingestion metrics in workflow summaries

## Files Created

| File | Purpose | Status |
|------|---------|--------|
| `.opencode/commands/km-ingest-code.sh` | Main ingestion script | ✅ 4-phase pipeline |
| `.git/hooks/pre-commit` | Git hook (commit) | ✅ Installed |
| `.git/hooks/post-checkout` | Git hook (branch) | ✅ Installed |
| `.git/hooks/post-merge` | Git hook (merge) | ✅ Installed |
| `.git/hooks/post-rewrite` | Git hook (rebase) | ✅ Installed |
| `scripts/update-project-graphify.sh` | Hook orchestrator | ✅ Created |
| `scripts/install-git-hooks.sh` | Multi-repo hook installer | ✅ Created |
| `.tooling-venv/` | Python venv | ✅ Created |
| `.project-memory/` | Project memory system | ✅ Created |
| `graphify-out/` | Generated knowledge graphs | ✅ Created |

## Verification

Run this to verify everything is working:

```bash
# Check hooks are installed
ls -la .git/hooks/pre-commit .git/hooks/post-*

# Verify Graphify is ready
.tooling-venv/bin/graphify --version

# Check generated graphs
find graphify-out -name "graph.json" | wc -l
# Should output: 19 (18 components + merged)

# View latest ingestion report
cat .project-memory/INGESTION_REPORT.md
```

## Troubleshooting

**Ingestion not triggering on commit?**
```bash
# Check hook is executable
chmod +x .git/hooks/pre-commit

# Test manually
.opencode/commands/km-ingest-code.sh
```

**Graphs not generating?**
```bash
# Verify Graphify
.tooling-venv/bin/graphify --version

# Reinstall if needed
rm -rf .tooling-venv
python3 -m venv .tooling-venv
.tooling-venv/bin/pip install graphifyy
```

**Need detailed documentation?**
```bash
# Read full guide
cat .project-memory/KM_INGEST_CODE_GUIDE.md
```

---

## Summary

Your waffle-commons project now has a **complete, automated knowledge management system**. Every commit, merge, and branch change triggers intelligent code graph extraction and documentation bridging — no manual effort required.

The knowledge graphs are ready for:
- AI-assisted code understanding
- Dependency analysis
- Documentation generation
- Architectural pattern discovery
- Cross-component relationship mapping

**Status:** ✅ Production Ready

---

**Last Updated:** 2026-05-17  
**System Version:** 1.0  
**Graphify Version:** 0.8.8  
**Components:** 18/18 ✅

For detailed information, see:
- `.project-memory/KM_INGEST_CODE_GUIDE.md` — Full reference guide
- `.project-memory/INGESTION_REPORT.md` — Latest metrics
- `.opencode/commands/km-ingest-code.sh` — Source code
