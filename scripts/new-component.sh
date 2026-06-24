#!/usr/bin/env bash
# =============================================================================
# scripts/new-component.sh — scaffold a brand-new autonomous Waffle component.
#
# Orchestrates the full bootstrap from the component-template:
#   1. derive the lowercase submodule path from the PascalCase name
#   2. git submodule add <git-url> <path>
#   3. seed it from component-template (the template ships configure-component.sh)
#   4. run configure-component.sh <PascalName> to stamp the placeholders
#   5. composer install inside the dev container
#   6. run the Definition of Done (scripts/dod.sh) and print next steps
#
# The submodule's remote must already exist (empty is fine). Nothing is
# committed — you review and commit the .gitmodules + gitlink yourself.
#
# Usage:   scripts/new-component.sh <PascalName> <git-url>
#          scripts/new-component.sh RateLimiter git@github.com:waffle-commons/rate-limiter.git
# Exit:    0 on success, 1 on error.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"
TEMPLATE="$REPO_ROOT/component-template"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_BLD=""; C_DIM=""; C_RST=""
fi
info() { printf '%s→ %s%s\n' "$C_CYA" "$*" "$C_RST"; }
ok()   { printf '%s✓ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s! %s%s\n' "$C_YEL" "$*" "$C_RST" >&2; }
die()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; exit 1; }

PASCAL="${1:-}"
GIT_URL="${2:-}"
[ -n "$PASCAL" ] && [ -n "$GIT_URL" ] || die "usage: scripts/new-component.sh <PascalName> <git-url>"

# Validate PascalCase (must start uppercase, alphanumerics only).
case "$PASCAL" in
  [A-Z]*) : ;;
  *) die "ComponentName must be PascalCase, e.g. RateLimiter (got '$PASCAL')" ;;
esac
[[ "$PASCAL" =~ ^[A-Za-z0-9]+$ ]] || die "ComponentName must be alphanumeric PascalCase (got '$PASCAL')"

# Derive the lowercase, kebab-cased submodule path: RateLimiter → rate-limiter.
KEBAB="$(printf '%s' "$PASCAL" \
  | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g; s/([A-Z]+)([A-Z][a-z])/\1-\2/g' \
  | tr '[:upper:]' '[:lower:]')"

DEST="$REPO_ROOT/$KEBAB"
info "new component: ${C_BLD}$PASCAL${C_RST}${C_CYA} → path '${KEBAB}' ← $GIT_URL"

[ -d "$TEMPLATE" ] || die "component-template not found at $TEMPLATE (is the submodule checked out?)"
[ -x "$TEMPLATE/configure-component.sh" ] || die "component-template/configure-component.sh missing or not executable"
if "$REPO_ROOT/scripts/list-components.sh" | grep -qx "$KEBAB"; then
  die "component '$KEBAB' already registered in .gitmodules"
fi
[ -e "$DEST" ] && die "destination already exists: $DEST"

# --- 1+2. register the submodule -----------------------------------------
info "git submodule add $GIT_URL $KEBAB…"
git -C "$REPO_ROOT" submodule add "$GIT_URL" "$KEBAB" \
  || die "git submodule add failed (does the remote exist and is it reachable?)"

# --- 3. seed from the template (preserve the freshly-created .git link) ---
info "seeding '$KEBAB' from component-template…"
# Copy template contents (excluding its VCS metadata) into the new submodule.
rsync -a --exclude='.git' --exclude='.git/' --exclude='vendor/' "$TEMPLATE/" "$DEST/" \
  || die "failed to seed from component-template"

# --- 4. stamp the placeholders -------------------------------------------
info "configure-component.sh $PASCAL…"
( cd "$DEST" && ./configure-component.sh "$PASCAL" ) \
  || die "configure-component.sh failed"

# --- 5. composer install (in container) ----------------------------------
if [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || printf 'absent')" = "running" ]; then
  info "composer install (in $CONTAINER)…"
  docker exec -w "/waffle-commons/$KEBAB" "$CONTAINER" composer install --no-interaction \
    || warn "composer install failed — fix dependencies, then run: wfl dod $KEBAB"
else
  warn "container '$CONTAINER' not running — skipped composer install (run: wfl up)"
fi

# --- 6. Definition of Done ------------------------------------------------
info "running Definition of Done…"
dod_ok=1
"$REPO_ROOT/scripts/dod.sh" "$KEBAB" || dod_ok=0

printf '%s%s────────────────────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
ok "component '$KEBAB' scaffolded"
cat <<EOF
${C_DIM}Next steps:${C_RST}
  1. Edit ${KEBAB}/composer.json — set name 'waffle-commons/${KEBAB}', description, autoload.
  2. Keep the dependency perimeter: depend ONLY on waffle-commons/contracts (and utils).
  3. Add your contracts to waffle-commons/contracts first (contracts-first).
  4. Re-run the gate:  wfl dod ${KEBAB}
  5. Review & commit the umbrella change:  git add .gitmodules ${KEBAB} && git commit
EOF

[ "$dod_ok" -eq 1 ] || warn "DoD not yet green for '$KEBAB' — expected for a fresh scaffold; iterate then re-run 'wfl dod $KEBAB'"
exit 0
