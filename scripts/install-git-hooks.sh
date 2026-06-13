#!/usr/bin/env bash
# ============================================================================
# Waffle Git Hook Installer
# ============================================================================
# Robust, Git-native installer that wires up pre-commit and pre-push hooks
# in the monorepo root and inside every submodule's git hooks directory —
# EXCEPT the consumer-facing `component-template` scaffold, which must ship with
# no Git hooks so downstream projects stay entirely unburdened (DX-02).
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Resolve monorepo root (script lives at <umbrella>/scripts/install-git-hooks.sh)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MONOREPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$MONOREPO_ROOT"

# Ensure hook payloads are executable if they exist (idempotent, harmless if missing).
for h in scripts/hooks/pre-commit-mago.sh scripts/hooks/pre-push-sanity.sh; do
  if [ -f "$h" ] && [ ! -x "$h" ]; then
    chmod +x "$h"
  fi
done

# --- 1. INSTALL HOOKS AT UMBRELLA ROOT ---
echo -e "${CYAN}Installing Git hooks in the umbrella root repository...${NC}"
ROOT_GIT_DIR=$(git rev-parse --git-dir)
ROOT_HOOKS_DIR="$ROOT_GIT_DIR/hooks"
mkdir -p "$ROOT_HOOKS_DIR"

# Install pre-commit hook
PRE_COMMIT="$ROOT_HOOKS_DIR/pre-commit"
if [ ! -f "$PRE_COMMIT" ]; then
  echo -e "#!/usr/bin/env bash\nset -euo pipefail" > "$PRE_COMMIT"
fi
chmod +x "$PRE_COMMIT"

if ! grep -q "scripts/hooks/pre-commit-mago.sh" "$PRE_COMMIT"; then
  cat >> "$PRE_COMMIT" <<'EOF'

# BEGIN WAFFLE PRE-COMMIT HOOK
if [ -x "./scripts/hooks/pre-commit-mago.sh" ]; then
  ./scripts/hooks/pre-commit-mago.sh "$@"
fi
# END WAFFLE PRE-COMMIT HOOK
EOF
fi

# Install pre-push hook
PRE_PUSH="$ROOT_HOOKS_DIR/pre-push"
if [ ! -f "$PRE_PUSH" ]; then
  echo -e "#!/usr/bin/env bash\nset -euo pipefail" > "$PRE_PUSH"
fi
chmod +x "$PRE_PUSH"

if ! grep -q "scripts/hooks/pre-push-sanity.sh" "$PRE_PUSH"; then
  cat >> "$PRE_PUSH" <<'EOF'

# BEGIN WAFFLE PRE-PUSH HOOK
if [ -x "./scripts/hooks/pre-push-sanity.sh" ]; then
  ./scripts/hooks/pre-push-sanity.sh "$@"
fi
# END WAFFLE PRE-PUSH HOOK
EOF
fi

# --- 2. INSTALL HOOKS IN EVERY SUBMODULE ---
echo -e "\n${CYAN}Installing Git hooks in all submodules...${NC}"

# Find all submodule paths listed in git submodule status
submodules=$(git submodule status | awk '{print $2}')

for sub in $submodules; do
  if [ ! -d "$sub" ]; then
    continue
  fi

  # component-template is the scaffold consuming projects copy — it must stay
  # hook-free so downstream users inherit no engineering hooks (DX-02).
  if [ "$sub" = "component-template" ]; then
    echo "Skipping component-template (consumer scaffold stays hook-free)..."
    continue
  fi

  # Resolve submodule git directory using rev-parse inside submodule context
  relative_sub_git_dir=$(cd "$sub" && git rev-parse --git-dir)
  # Resolve to absolute path
  SUB_GIT_DIR=$(cd "$sub" && cd "$relative_sub_git_dir" && pwd)
  SUB_HOOKS_DIR="$SUB_GIT_DIR/hooks"
  mkdir -p "$SUB_HOOKS_DIR"
  
  echo "Installing Waffle and Graphify hooks in submodule: $sub..."
  
  # A. Install Waffle pre-commit hook
  SUB_PRE_COMMIT="$SUB_HOOKS_DIR/pre-commit"
  if [ ! -f "$SUB_PRE_COMMIT" ]; then
    echo -e "#!/usr/bin/env bash\nset -euo pipefail" > "$SUB_PRE_COMMIT"
  fi
  chmod +x "$SUB_PRE_COMMIT"
  
  if ! grep -q "scripts/hooks/pre-commit-mago.sh" "$SUB_PRE_COMMIT"; then
    cat >> "$SUB_PRE_COMMIT" <<'EOF'

# BEGIN WAFFLE PRE-COMMIT HOOK
if [ -x "../scripts/hooks/pre-commit-mago.sh" ]; then
  (cd .. && ./scripts/hooks/pre-commit-mago.sh "$@")
fi
# END WAFFLE PRE-COMMIT HOOK
EOF
  fi
  
  # B. Install Graphify hooks (existing hooks)
  if ! grep -q "BEGIN PROJECT GRAPHIFY PRE-COMMIT HOOK" "$SUB_PRE_COMMIT"; then
    cat >> "$SUB_PRE_COMMIT" <<'EOF'

# BEGIN PROJECT GRAPHIFY PRE-COMMIT HOOK
# Go to the umbrella root to run the global update script
CUR_DIR="$(pwd)"
while [ "$CUR_DIR" != "/" ]; do
  if [ -x "$CUR_DIR/scripts/update-project-graphify.sh" ]; then
    (cd "$CUR_DIR" && ./scripts/update-project-graphify.sh)
    break
  fi
  CUR_DIR="$(dirname "$CUR_DIR")"
done
# END PROJECT GRAPHIFY PRE-COMMIT HOOK
EOF
  fi
  
  # C. Install Waffle pre-push hook
  SUB_PRE_PUSH="$SUB_HOOKS_DIR/pre-push"
  if [ ! -f "$SUB_PRE_PUSH" ]; then
    echo -e "#!/usr/bin/env bash\nset -euo pipefail" > "$SUB_PRE_PUSH"
  fi
  chmod +x "$SUB_PRE_PUSH"
  
  if ! grep -q "scripts/hooks/pre-push-sanity.sh" "$SUB_PRE_PUSH"; then
    cat >> "$SUB_PRE_PUSH" <<'EOF'

# BEGIN WAFFLE PRE-PUSH HOOK
if [ -x "../scripts/hooks/pre-push-sanity.sh" ]; then
  (cd .. && ./scripts/hooks/pre-push-sanity.sh "$@")
fi
# END WAFFLE PRE-PUSH HOOK
EOF
  fi
  
  # D. Install Graphify post hooks (existing hooks)
  for HOOK_NAME in post-checkout post-merge post-rewrite; do
    SUB_HOOK_FILE="$SUB_HOOKS_DIR/$HOOK_NAME"
    if [ ! -f "$SUB_HOOK_FILE" ]; then
      echo -e "#!/usr/bin/env bash\nset -euo pipefail" > "$SUB_HOOK_FILE"
    fi
    chmod +x "$SUB_HOOK_FILE"
    
    if ! grep -q "BEGIN PROJECT GRAPHIFY REFRESH HOOK" "$SUB_HOOK_FILE"; then
      cat >> "$SUB_HOOK_FILE" <<'EOF'

# BEGIN PROJECT GRAPHIFY REFRESH HOOK
CUR_DIR="$(pwd)"
while [ "$CUR_DIR" != "/" ]; do
  if [ -x "$CUR_DIR/scripts/update-project-graphify.sh" ]; then
    (cd "$CUR_DIR" && ./scripts/update-project-graphify.sh)
    break
  fi
  CUR_DIR="$(dirname "$CUR_DIR")"
done
# END PROJECT GRAPHIFY REFRESH HOOK
EOF
    fi
  done
done

echo -e "\n${GREEN}✓ All Waffle and Graphify Git hooks successfully wired up!${NC}"