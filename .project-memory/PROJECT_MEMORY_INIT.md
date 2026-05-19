# Project Memory Workflow — waffle-commons

**Initialized:** 2026-05-17  
**Version:** 1.0

## Overview

The project memory workflow is now active for waffle-commons. This system supports multi-repo Git hooks, Graphify-based knowledge management, and persistent project state tracking.

## Directory Structure

```
.project-memory/
├── project/
│   ├── architecture/      # Architectural decisions and diagrams
│   ├── decisions/         # ADRs and design decisions
│   ├── features/          # Feature specifications and status
│   └── logs/              # Development logs and milestones
├── permanent/             # Permanent knowledge base
├── references/            # External references and links
└── graphify/
    └── project/           # Graphify ingested code graphs
```

## Tooling

### Graphify

- **Location:** `.tooling-venv/bin/graphify`
- **Purpose:** Static code graph generation and knowledge ingestion
- **Update Script:** `scripts/update-project-graphify.sh`

The Graphify venv includes language parsers for:
- PHP (primary)
- TypeScript, JavaScript, Python, Go, Rust, C#, Java
- And 12+ additional languages

### Git Hooks

Installed at `.git/hooks/`:

1. **pre-commit** — Triggers Graphify update before commits
2. **post-checkout** — Refreshes knowledge after branch changes
3. **post-merge** — Updates graphs after merges
4. **post-rewrite** — Syncs after rebases/amends

Each hook gracefully exits if Graphify is unavailable.

## Multi-Repo Readiness

The `scripts/install-git-hooks.sh` script is designed to handle future component independence:

- Scans for nested `.git` directories (components)
- Installs hooks into each component's `.git/hooks`
- Hooks navigate back to root and trigger global graph updates

**Current Status:** waffle-commons is a single monorepo. When components become independent Git submodules, re-run:

```bash
./scripts/install-git-hooks.sh
```

This will automatically detect and configure all component repositories.

## Usage

### Manual Graph Update

```bash
./scripts/update-project-graphify.sh
```

### Automatic Updates (on commits/merges/checkouts)

Git hooks are now active. Graph updates trigger automatically on:
- `git commit` (pre-commit)
- `git checkout` (post-checkout)
- `git merge` (post-merge)
- `git rebase` / `git commit --amend` (post-rewrite)

### Knowledge Ingestion

To ingest code into the knowledge graph, create:

```bash
.opencode/commands/km-ingest-code.sh
```

This command will be invoked by Git hooks. Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

GRAPHIFY_BIN=".tooling-venv/bin/graphify"
GRAPH_DIR="graphify-out/project"

mkdir -p "$GRAPH_DIR"

# Ingest all PHP components
for component in src/*/; do
  echo "Ingesting $component..."
  "$GRAPHIFY_BIN" ingest --lang=php "$component" -o "$GRAPH_DIR/$(basename "$component").json"
done
```

## Next Steps

1. **Populate Project Memory:** Add architectural decisions to `.project-memory/project/`
2. **Create km-ingest-code.sh:** Implement the knowledge ingestion command for your components
3. **Review Git Hooks:** Customize hooks if additional actions are needed
4. **Monitor Graphify Output:** Check `graphify-out/` for generated knowledge graphs

## Support

For issues or feature requests:  
https://github.com/anomalyco/opencode

---

**Status:** ✅ Project memory workflow initialized successfully.
