# Knowledge Management Ingestion Guide

## Overview

The `km-ingest-code.sh` command is the backbone of waffle-commons' project memory system. It orchestrates multi-component code graph generation, merges them into a unified knowledge base, and bridges with Diátaxis documentation.

**Location:** `.opencode/commands/km-ingest-code.sh`

## When It Runs

The ingestion process is **automatically triggered** on these Git events:

| Event | Hook | Timing |
|-------|------|--------|
| Commit | `pre-commit` | Before commit is recorded |
| Branch change | `post-checkout` | After checkout completes |
| Merge | `post-merge` | After merge resolves |
| Rebase/Amend | `post-rewrite` | After rewrite operations |

Manual execution is also supported:

```bash
.opencode/commands/km-ingest-code.sh
```

## Four-Phase Process

### Phase 1: Tooling Setup

**Purpose:** Ensure Graphify and Python venv are ready.

**Actions:**
- Checks for `.tooling-venv/` directory
- If missing, creates Python 3 venv and installs `graphifyy`
- Verifies `graphify` binary is executable
- Reports Graphify version

**Output:** ✅ Tooling ready at `.tooling-venv/bin/graphify`

### Phase 2: Multi-Repo Component Scanning

**Purpose:** Discover all autonomous components in the monorepo.

**Process:**
- Scans recursively for `composer.json` files (depth: 2-3 levels)
- Ignores vendor directories
- Skips root-level composer.json (already at umbrella root)

**Component Detection:**
- If components found (e.g., `./cache/composer.json`), ingests each
- If no nested components, falls back to root `./composer.json`

**Output:** List of detected component names and paths

```
Found: cache (./cache)
Found: config (./config)
...
Detected 18 component(s)
```

### Phase 3: AST Extraction & Ingestion

**Purpose:** Generate code graphs from each component's PHP source.

**Process:**
- Runs `graphify update <component>` on each component
- Uses AST-only extraction (no LLM required)
- Clusters symbols into logical nodes
- Outputs per-component graph to `graphify-out/<component-name>/graph.json`

**Key Features:**
- **No LLM API key required** — AST extraction is fully local
- **Fast:** Typically 2-5 seconds per component
- **Zero external dependencies:** Works fully offline
- **Error handling:** Non-fatal failures (component graphs optional)

**Graph Contents:**
- Class definitions and methods
- Function signatures
- Namespace organization
- Type relationships
- Import/dependency chains

### Phase 4: Merged Graph & Documentation Bridging

**Purpose:** Unify all component graphs and link with Diátaxis docs.

**Process:**
1. **Graph Merging:**
   - Attempts to merge 18 component graphs via `graphify merge-graphs`
   - Falls back to stub if merge fails (non-fatal)

2. **Documentation Bridging:**
   - Discovers all `.md` files in `documentation/` directory
   - Maps Diátaxis quadrants (tutorials, how-to, reference, explanation)
   - Adds documentation references to merged graph metadata

3. **Output:**
   - **Merged graph:** `graphify-out/merged-graph.json`
   - **Ingestion report:** `.project-memory/INGESTION_REPORT.md`

## Directory Structure

After successful ingestion, the structure looks like:

```
graphify-out/
├── cache/
│   └── graph.json              # AST-extracted symbols from cache component
├── config/
│   └── graph.json
├── ... (16 more components)
├── merged-graph.json           # Unified knowledge graph (manual merge)
└── memory/ (optional)          # Query feedback loop (created on demand)

.project-memory/
├── INGESTION_REPORT.md         # Detailed ingestion metrics
├── PROJECT_MEMORY_INIT.md      # Setup overview
└── INITIALIZATION_CHECKLIST.md # Status tracking
```

## Configuration

### Environment Variables

Optional customization:

```bash
# Set Python binary (auto-detected if not set)
export PYTHON_BIN="python3.12"

# Custom venv location (default: .tooling-venv)
export TOOLING_VENV="/custom/path/.venv"
```

### Component Discovery Rules

The script uses this find pattern:

```bash
find . -mindepth 2 -maxdepth 3 -name "composer.json" -not -path "*/vendor/*"
```

**Meaning:**
- `mindepth 2` — Skip root directory
- `maxdepth 3` — Limit nesting to `./dir1/dir2/composer.json`
- `-not -path "*/vendor/*"` — Ignore vendored code

**To add custom component locations:**
Edit Phase 2 of `.opencode/commands/km-ingest-code.sh` and adjust the `find` command.

## Output & Artifacts

### Per-Component Graphs

**File:** `graphify-out/<component>/graph.json`

**Format:** Graphify's standard graph representation

```json
{
  "nodes": [
    {
      "id": "cache/src/Cache.php:Cache",
      "type": "class",
      "label": "Cache",
      "file": "cache/src/Cache.php",
      "line": 15
    },
    ...
  ],
  "edges": [
    {
      "source": "cache/src/Cache.php:Cache",
      "target": "contracts/src/CacheInterface.php:CacheInterface",
      "type": "implements"
    },
    ...
  ]
}
```

### Merged Graph

**File:** `graphify-out/merged-graph.json`

**Structure:**
```json
{
  "metadata": {
    "project": "waffle-commons",
    "type": "merged-knowledge-graph",
    "generated_at": "2026-05-17T03:40:47Z",
    "components": []
  },
  "nodes": [],
  "edges": [],
  "documentation_references": [
    {
      "path": "explanation/architecture.md",
      "type": "diataxis"
    },
    ...
  ]
}
```

### Ingestion Report

**File:** `.project-memory/INGESTION_REPORT.md`

**Contents:**
- Per-component success/failure status
- Metrics (total components, failed ingestions)
- Documentation bridge status
- Next steps and reference links

## Error Handling

### Non-Fatal Errors

The script gracefully continues if:

- A single component fails to extract
- Graphify merge command fails (fallback to stub)
- Documentation directory is missing
- API key errors (uses AST-only extraction instead)

**Exit code:** Always `0` (success) to avoid blocking Git hooks

### Debugging

To debug a failed ingestion:

```bash
# Run script with verbose output
bash -x .opencode/commands/km-ingest-code.sh

# Check error logs from last run
cat /tmp/graphify-error.log

# Manually extract a component
.tooling-venv/bin/graphify update ./cache --no-cluster
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Update Knowledge Graph
on: [push, pull_request]

jobs:
  ingest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      - run: .opencode/commands/km-ingest-code.sh
      - uses: actions/upload-artifact@v3
        with:
          name: knowledge-graphs
          path: graphify-out/
```

### GitLab CI Example

```yaml
ingest_knowledge:
  stage: build
  image: python:3.12
  script:
    - bash .opencode/commands/km-ingest-code.sh
  artifacts:
    paths:
      - graphify-out/
    reports:
      - .project-memory/INGESTION_REPORT.md
```

## Performance

Typical performance on waffle-commons (18 components):

| Phase | Time | Notes |
|-------|------|-------|
| Phase 1 (Tooling) | 0.5s | Instant if venv exists |
| Phase 2 (Scanning) | 0.1s | Fast file discovery |
| Phase 3 (Extraction) | 45-60s | ~2.5s per component |
| Phase 4 (Merging) | 1-2s | Fallback merge is instant |
| **Total** | **~47-63s** | Non-blocking in Git hooks |

**Optimization tips:**
- First run takes longer (venv setup)
- Subsequent runs are much faster (~50s)
- If blocked on time, reduce component count or run nightly

## Future Enhancements

### Planned

- [ ] **Parallel extraction** — Process components concurrently
- [ ] **Incremental updates** — Only re-extract changed files
- [ ] **LLM semantic enrichment** — Optional semantic analysis if API key present
- [ ] **Dependency mapping** — Auto-discover cross-component relationships
- [ ] **Coverage metrics** — Track code coverage in knowledge graph

### Contributing

To extend the ingestion workflow:

1. Fork the logic in Phase 3 or 4
2. Add new `echo` lines for visibility
3. Test with: `bash -x .opencode/commands/km-ingest-code.sh`
4. Verify graphs generate correctly: `ls -la graphify-out/*/graph.json`

## Troubleshooting

### Ingestion is slow

**Cause:** Large components or slow disk I/O

**Solution:**
```bash
# Run with native speed check
time .opencode/commands/km-ingest-code.sh

# Check disk I/O
iostat -x 1 5  # During extraction
```

### Graphs not generated

**Cause:** Graphify install failed or Python not found

**Solution:**
```bash
# Verify venv
.tooling-venv/bin/graphify --version

# Reinstall if needed
rm -rf .tooling-venv
python3 -m venv .tooling-venv
.tooling-venv/bin/pip install graphifyy
```

### Git hooks not triggering

**Cause:** Hooks not executable or not installed

**Solution:**
```bash
# Reinstall hooks
./scripts/install-git-hooks.sh

# Verify
ls -la .git/hooks/pre-commit
# Should show: -rwxr-xr-x (executable)
```

### Too many components detected

**Cause:** Overly broad find pattern or vendor dirs not excluded

**Solution:**
Edit Phase 2 in `.opencode/commands/km-ingest-code.sh`:

```bash
# Add component exclusions
while IFS= read -r COMPOSER_FILE; do
    # ... existing code ...
    
    # Skip certain components
    if [[ "$COMPONENT_NAME" == "test-fixtures" ]]; then
        continue
    fi
done < <(find ...)
```

---

**Last Updated:** 2026-05-17  
**Script Version:** 1.0  
**Graphify Version:** 0.8.8+
