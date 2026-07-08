#!/usr/bin/env bash
# =============================================================================
# scripts/pre-release.sh — per-component release-readiness check.
#
# For each target component, runs the full Definition of Done (scripts/dod.sh)
# and then verifies the release paperwork:
#   • README.md carries the current version stamp (0.1.0-betaN, NO 'v' prefix)
#   • CHANGELOG.md has a "## [0.1.0-betaN]" entry for the current version
#
# The current version is taken from $WFL_RELEASE_VERSION, else inferred from the
# checked-out branch (pre-release/0.1.0-betaN → 0.1.0-betaN). The no-v-prefix
# convention matches the umbrella tag gate.
#
# Usage:   scripts/pre-release.sh [component|--all]
#          WFL_RELEASE_VERSION=0.1.0-beta5 scripts/pre-release.sh contracts
# Exit:    0 if every targeted component is release-ready, 1 otherwise.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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

# --- Resolve the current release version (no 'v' prefix) ------------------
VERSION="${WFL_RELEASE_VERSION:-}"
if [ -z "$VERSION" ]; then
  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  case "$branch" in
    */0.1.0-beta*|*/[0-9].[0-9].[0-9]*) VERSION="${branch##*/}" ;;
  esac
fi
[ -n "$VERSION" ] || die "could not determine release version; set WFL_RELEASE_VERSION=0.1.0-betaN"
case "$VERSION" in
  v*) die "version must NOT carry a 'v' prefix (got '$VERSION') — use e.g. 0.1.0-beta5" ;;
esac
info "release version target: ${C_BLD}${VERSION}${C_RST}${C_CYA}"

# --- Paperwork check (version stamp + CHANGELOG entry) --------------------
_check_paperwork() {
  local comp="$1" cdir="$REPO_ROOT/$comp" issues=0
  local readme="$cdir/README.md" changelog="$cdir/CHANGELOG.md"

  if [ -f "$readme" ]; then
    if grep -qF "$VERSION" "$readme"; then
      ok "  README stamped $VERSION"
    else
      issues=$((issues + 1)); warn "  README does not mention $VERSION"
    fi
    # Guard against a stray 'v'-prefixed stamp slipping in.
    if grep -qE "v${VERSION//./\\.}" "$readme"; then
      issues=$((issues + 1)); warn "  README has a 'v'-prefixed stamp (drop the 'v')"
    fi
  else
    warn "  no README.md (skipping stamp check)"
  fi

  if [ -f "$changelog" ]; then
    if grep -qE "^##[[:space:]]+\[${VERSION//./\\.}\]" "$changelog"; then
      ok "  CHANGELOG has a [$VERSION] entry"
    else
      issues=$((issues + 1)); warn "  CHANGELOG missing a '## [$VERSION]' entry"
    fi
  else
    issues=$((issues + 1)); warn "  no CHANGELOG.md"
  fi

  return "$issues"
}

# --- Per-component readiness ----------------------------------------------
_assess() {
  local comp="$1"
  printf '%s%s═══ pre-release — %s ═══%s\n' "$C_BLD" "$C_CYA" "$comp" "$C_RST"
  local fail=0

  if "$REPO_ROOT/scripts/dod.sh" "$comp"; then
    ok "  DoD passed"
  else
    fail=1; warn "  DoD failed"
  fi

  if _check_paperwork "$comp"; then
    ok "  paperwork ready"
  else
    fail=1
  fi

  return "$fail"
}

TARGET="${1:---all}"
overall=0
declare -a not_ready=()

if [ "$TARGET" = "--all" ]; then
  while IFS= read -r comp; do
    # The scaffold + docs-only submodules are not released framework packages.
    case "$comp" in component-template|documentation) continue ;; esac
    [ -d "$REPO_ROOT/$comp" ] || continue
    if ! _assess "$comp"; then overall=1; not_ready+=("$comp"); fi
  done < <("$REPO_ROOT/scripts/list-components.sh")
else
  if ! "$REPO_ROOT/scripts/list-components.sh" | grep -qx "$TARGET"; then
    die "unknown component: '$TARGET' (see: scripts/list-components.sh, or use --all)"
  fi
  if ! _assess "$TARGET"; then overall=1; not_ready+=("$TARGET"); fi
fi

printf '%s%s════════════════════════════════════════%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$overall" -eq 0 ]; then
  ok "pre-release READY — every targeted component is release-ready for $VERSION"
  exit 0
fi
warn "NOT READY: ${not_ready[*]}"
die "pre-release FAILED — see findings above"
