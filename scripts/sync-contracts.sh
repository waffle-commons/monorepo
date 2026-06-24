#!/usr/bin/env bash
# =============================================================================
# scripts/sync-contracts.sh — the vendor-contracts skew fix.
#
# A component can be mago-green yet PHPUnit-red because its vendored copy of
# waffle-commons/contracts (under <comp>/vendor/waffle-commons/contracts) lags
# the fresh contracts/src in the monorepo. This mirrors contracts/src/ into the
# consumer's vendored copy so the runtime sees the same interfaces the analyzer
# does.
#
# The 'workspace' app vendors contracts via a SYMLINK (always fresh) and is
# skipped. 'contracts' itself is the source and is skipped too.
#
# Usage:   scripts/sync-contracts.sh [component|--all]
#          (no arg ⇒ --all)
# Exit:    0 on success, 1 on error.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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

SRC="$REPO_ROOT/contracts/src/"
[ -d "$SRC" ] || die "contracts/src not found at $SRC (is the 'contracts' submodule checked out?)"

TARGET="${1:---all}"

# Mirror contracts/src into one component's vendored copy.
_sync_one() {
  local comp="$1"
  case "$comp" in
    contracts) return 0 ;;             # the source itself
    workspace) info "skip workspace (contracts is symlinked — already fresh)"; return 0 ;;
  esac

  local dest_parent="$REPO_ROOT/$comp/vendor/waffle-commons/contracts"
  if [ ! -d "$REPO_ROOT/$comp" ]; then
    warn "skip $comp (directory missing)"; return 0
  fi
  if [ ! -d "$dest_parent" ]; then
    info "skip $comp (no vendored contracts — does not consume it, or run 'composer install')"
    return 0
  fi
  # A symlinked vendor copy is already fresh; never rsync through it.
  if [ -L "$dest_parent" ]; then
    info "skip $comp (contracts is symlinked — already fresh)"; return 0
  fi

  mkdir -p "$dest_parent/src"
  rsync -a --delete "$SRC" "$dest_parent/src/"
  ok "synced contracts/src → $comp/vendor/waffle-commons/contracts/src"
}

command -v rsync >/dev/null 2>&1 || die "rsync not found on host"

if [ "$TARGET" = "--all" ]; then
  info "syncing fresh contracts/src into every consumer's vendored copy…"
  while IFS= read -r comp; do
    _sync_one "$comp"
  done < <("$REPO_ROOT/scripts/list-components.sh")
  ok "sync-contracts complete (--all)"
else
  if ! "$REPO_ROOT/scripts/list-components.sh" | grep -qx "$TARGET"; then
    die "unknown component: '$TARGET' (see: scripts/list-components.sh, or use --all)"
  fi
  _sync_one "$TARGET"
fi
exit 0
