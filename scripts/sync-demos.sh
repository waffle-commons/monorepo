#!/usr/bin/env bash
# =============================================================================
# scripts/sync-demos.sh — refresh the template apps' vendored framework copies.
#
# The template apps vendor the framework two different ways:
#   • workspace — vendors every waffle-commons/* as a SYMLINK into the sibling
#                 component, so its vendor tree is ALWAYS fresh. Nothing to do;
#                 we just note it.
#   • skeleton  — vendors a real (copied) snapshot under
#                 skeleton/vendor/waffle-commons/<comp>/src, which goes stale as
#                 framework src evolves. For each vendored waffle-commons dep we
#                 rsync the fresh <comp>/src over it, then refresh the autoloader.
#
# 'composer dump-autoload' runs inside the dev container (waffle-dev) so the
# generated classmap matches the container's PHP, and only if it is running.
#
# Usage:   scripts/sync-demos.sh [workspace|skeleton|--all]
#          (no arg ⇒ --all)
# Exit:    0 on success, 1 on error.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_DIM=""; C_RST=""
fi
info() { printf '%s→ %s%s\n' "$C_CYA" "$*" "$C_RST"; }
ok()   { printf '%s✓ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s! %s%s\n' "$C_YEL" "$*" "$C_RST" >&2; }
die()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; exit 1; }

command -v rsync >/dev/null 2>&1 || die "rsync not found on host"

_container_running() {
  [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || printf 'absent')" = "running" ]
}

# workspace is symlinked → always fresh; just report it.
_sync_workspace() {
  [ -d "$REPO_ROOT/workspace" ] || { warn "skip workspace (directory missing)"; return 0; }
  info "workspace vendors waffle-commons/* via symlink — already fresh (no copy needed)"
}

# skeleton vendors a real snapshot → rsync fresh <comp>/src over each dep.
_sync_skeleton() {
  local vroot="$REPO_ROOT/skeleton/vendor/waffle-commons"
  [ -d "$REPO_ROOT/skeleton" ] || { warn "skip skeleton (directory missing)"; return 0; }
  [ -d "$vroot" ] || die "skeleton/vendor/waffle-commons missing — run 'composer install' in skeleton first"

  info "refreshing skeleton vendored framework src from the monorepo…"
  local synced=0 dep dep_name src
  for dep in "$vroot"/*/; do
    [ -d "$dep" ] || continue
    dep_name="$(basename "$dep")"
    # A symlinked vendor copy (rare in skeleton) is already fresh.
    [ -L "${dep%/}" ] && { info "skip $dep_name (symlinked — fresh)"; continue; }
    src="$REPO_ROOT/$dep_name/src"
    if [ ! -d "$src" ]; then
      warn "skip $dep_name (no monorepo src at $src)"; continue
    fi
    mkdir -p "${dep}src"
    rsync -a --delete "$src/" "${dep}src/"
    ok "synced $dep_name/src → skeleton/vendor/waffle-commons/$dep_name/src"
    synced=$((synced + 1))
  done
  info "synced $synced vendored dependency snapshot(s)"

  if _container_running; then
    info "composer dump-autoload (in $CONTAINER)…"
    docker exec -w /waffle-commons/skeleton "$CONTAINER" composer dump-autoload -q \
      && ok "skeleton autoloader refreshed" \
      || warn "composer dump-autoload failed — run it manually in $CONTAINER"
  else
    warn "container '$CONTAINER' not running — skipped dump-autoload (run: wfl up, then re-run)"
  fi
}

TARGET="${1:---all}"
case "$TARGET" in
  workspace) _sync_workspace ;;
  skeleton)  _sync_skeleton ;;
  --all)     _sync_workspace; _sync_skeleton ;;
  *) die "usage: scripts/sync-demos.sh [workspace|skeleton|--all]" ;;
esac

ok "sync-demos complete ($TARGET)"
exit 0
