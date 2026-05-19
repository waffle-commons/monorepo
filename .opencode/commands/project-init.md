---
description: Initialize multi-repo project memory + Graphify Git Hooks
---

# /project-init

Initialize the project memory workflow. Because `waffle-commons` is a monorepo containing independent submodules, Git hooks must be installed into *each individual component's* `.git/hooks` directory.

## Step 1 — Setup Project Memory Directories at Root

```bash
mkdir -p .project-memory/project/{architecture,decisions,features,logs}
mkdir -p .project-memory/{permanent,references,graphify/project}
mkdir -p graphify-out scripts .opencode/commands
```

## Step 2 — Create Tooling Venv & Update Script

```bash
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
else
  echo "Python not found for tooling."
  exit 0
fi

if [ ! -d ".tooling-venv" ]; then
  "$PYTHON_BIN" -m venv .tooling-venv
fi

.tooling-venv/bin/python -m pip install --upgrade pip graphifyy
```

Create `scripts/update-project-graphify.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
GRAPHIFY_BIN=".tooling-venv/bin/graphify"
if [ ! -x "$GRAPHIFY_BIN" ]; then exit 0; fi

# In a multi-repo, Graphify must be run iteratively over components (handled by km-ingest-code).
# This script triggers that global ingestion.
if [ -x "./.opencode/commands/km-ingest-code.sh" ]; then
    ./.opencode/commands/km-ingest-code.sh
fi
```
`chmod +x scripts/update-project-graphify.sh`

## Step 3 — Multi-Repo Git Hook Installation

Find all nested `.git/` directories and inject the hooks locally so commits in *any* component trigger the global update.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Find all component directories that are independent Git repositories
for GIT_DIR in $(find . -mindepth 2 -maxdepth 3 -type d -name ".git"); do
  COMPONENT_DIR=$(dirname "$GIT_DIR")
  echo "Installing Graphify hooks in $COMPONENT_DIR..."
  
  HOOKS_PATH="$COMPONENT_DIR/.git/hooks"
  mkdir -p "$HOOKS_PATH"

  PRE_COMMIT="$HOOKS_PATH/pre-commit"
  
  if [ ! -f "$PRE_COMMIT" ]; then
    cat > "$PRE_COMMIT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  fi

  if ! grep -q "BEGIN PROJECT GRAPHIFY PRE-COMMIT HOOK" "$PRE_COMMIT"; then
    cat >> "$PRE_COMMIT" <<'EOF'

# BEGIN PROJECT GRAPHIFY PRE-COMMIT HOOK
# Go to the umbrella root to run the global update script
if [ -x "../../scripts/update-project-graphify.sh" ]; then
  (cd ../../ && ./scripts/update-project-graphify.sh)
fi
# END PROJECT GRAPHIFY PRE-COMMIT HOOK
EOF
  fi
  chmod +x "$PRE_COMMIT"

  for HOOK_NAME in post-checkout post-merge post-rewrite; do
    HOOK_FILE="$HOOKS_PATH/$HOOK_NAME"
    if [ ! -f "$HOOK_FILE" ]; then
      cat > "$HOOK_FILE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
    fi

    if ! grep -q "BEGIN PROJECT GRAPHIFY REFRESH HOOK" "$HOOK_FILE"; then
      cat >> "$HOOK_FILE" <<'EOF'

# BEGIN PROJECT GRAPHIFY REFRESH HOOK
if [ -x "../../scripts/update-project-graphify.sh" ]; then
  (cd ../../ && ./scripts/update-project-graphify.sh)
fi
# END PROJECT GRAPHIFY REFRESH HOOK
EOF
    fi
    chmod +x "$HOOK_FILE"
  done
done
```
