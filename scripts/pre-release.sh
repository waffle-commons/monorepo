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
# '--all' covers exactly the packages the release wave tags — the RELEASE_INCLUDE
# allowlist in .github/workflows/release-wave.yml, which is the single source of
# truth for "releasable". It is parsed rather than mirrored here so the two can
# never drift: 'workspace', 'academy' and the 'component-template' scaffold are
# not released and carry no release paperwork, while 'documentation' IS released
# (docs-only, so paperwork applies but there are no code gates to run).
#
# '--all' also holds the release on its audit (the release-audit skill) for beta8,
# later betas, and every X.Y.0 and its RCs (`scripts/release-audit.py required`):
# `scripts/release-audit.py check <version> --gate --for <version>` must pass. A
# patch release (x.y.Z, Z > 0) is exempt. WFL_AUDIT_VERSION=<X.Y.Z-RCn> holds a
# final X.Y.Z on its RC's run (a Gold that changes no code); the script refuses
# any other pairing.
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

  if [ -f "$REPO_ROOT/$comp/composer.json" ]; then
    if "$REPO_ROOT/scripts/dod.sh" "$comp"; then
      ok "  DoD passed"
    else
      fail=1; warn "  DoD failed"
    fi
  else
    # A released package with no composer.json (documentation/) has no mago,
    # test, coverage or igor surface — paperwork is the whole gate.
    info "  no composer.json — docs-only package, DoD not applicable"
  fi

  if _check_paperwork "$comp"; then
    ok "  paperwork ready"
  else
    fail=1
  fi

  # The bill of materials the release ships with (CycloneDX, from composer.lock).
  if [ -f "$REPO_ROOT/$comp/composer.lock" ]; then
    if python3 -I "$REPO_ROOT/scripts/sbom.py" "$comp" --version "$VERSION" >/dev/null; then
      ok "  SBOM written: tmp/sbom/$comp-$VERSION.cdx.json"
    else
      fail=1; warn "  SBOM could not be generated (scripts/sbom.py $comp)"
    fi
  fi

  return "$fail"
}

# --- Release allowlist (parsed from the release-wave workflow) -------------
# Resolved once, up front: a failure to read the allowlist must abort the run,
# and `die` inside a subshell (process/command substitution) would only kill the
# subshell and leave `--all` iterating an empty list — i.e. reporting READY.
WAVE_WORKFLOW="$REPO_ROOT/.github/workflows/release-wave.yml"
[ -f "$WAVE_WORKFLOW" ] || die "release allowlist unavailable: $WAVE_WORKFLOW not found"
RELEASE_TARGETS="$(
  sed -n "s/^[[:space:]]*RELEASE_INCLUDE:[[:space:]]*'\([^']*\)'[[:space:]]*\$/\1/p" \
      "$WAVE_WORKFLOW" | head -n 1 | tr ',' '\n' | sed '/^[[:space:]]*$/d'
)"
[ -n "$RELEASE_TARGETS" ] || die "could not parse RELEASE_INCLUDE from $WAVE_WORKFLOW"

TARGET="${1:---all}"
overall=0
declare -a not_ready=()
COMPONENTS="$("$REPO_ROOT/scripts/list-components.sh")"
[ -n "$COMPONENTS" ] || die "scripts/list-components.sh returned no components"

if [ "$TARGET" = "--all" ]; then
  while IFS= read -r comp; do
    # Fail loudly on allowlist/.gitmodules drift rather than silently skipping.
    if ! printf '%s\n' "$COMPONENTS" | grep -qx "$comp"; then
      overall=1; not_ready+=("$comp")
      warn "$comp: in RELEASE_INCLUDE but not a submodule in .gitmodules"
      continue
    fi
    if [ ! -d "$REPO_ROOT/$comp" ]; then
      overall=1; not_ready+=("$comp")
      warn "$comp: submodule directory missing (run: git submodule update --init)"
      continue
    fi
    if ! _assess "$comp"; then overall=1; not_ready+=("$comp"); fi
  done < <(printf '%s\n' "$RELEASE_TARGETS")
else
  if ! printf '%s\n' "$COMPONENTS" | grep -qx "$TARGET"; then
    die "unknown component: '$TARGET' (see: scripts/list-components.sh, or use --all)"
  fi
  if ! printf '%s\n' "$RELEASE_TARGETS" | grep -qx "$TARGET"; then
    warn "'$TARGET' is not in RELEASE_INCLUDE — the wave never tags it; paperwork findings below are informational"
  fi
  if ! _assess "$TARGET"; then overall=1; not_ready+=("$TARGET"); fi
fi

# --- Release audit gate (beta8 [AUD-01] onward) ----------------------------------
# The script decides which releases wait for their audit (`required`: exit 0 yes,
# 1 exempt). Anything else, a missing python3 included, holds the release.
if [ "$TARGET" = "--all" ]; then
  python3 -I "$REPO_ROOT/scripts/release-audit.py" required "$VERSION" >/dev/null 2>&1
  audit_rule=$?
  if [ "$audit_rule" -ne 1 ]; then
    AUDIT_VERSION="${WFL_AUDIT_VERSION:-$VERSION}"
    info "release audit gate: ${C_BLD}${AUDIT_VERSION}${C_RST}${C_CYA}"
    [ "$AUDIT_VERSION" = "$VERSION" ] || warn "  WFL_AUDIT_VERSION: $VERSION is held on the audit of $AUDIT_VERSION"
    if [ "$audit_rule" -eq 0 ] && python3 -I "$REPO_ROOT/scripts/release-audit.py" check "$AUDIT_VERSION" --gate --for "$VERSION"; then
      ok "  release audit: every run complete, every finding decided, every fix verified and released, the surface covered"
    else
      overall=1; not_ready+=("release-audit")
      warn "  release audit gate failed for $AUDIT_VERSION (wfl audit:status $AUDIT_VERSION)"
    fi
  fi
fi

printf '%s%s════════════════════════════════════════%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$overall" -eq 0 ]; then
  ok "pre-release READY — every targeted component is release-ready for $VERSION"
  exit 0
fi
warn "NOT READY: ${not_ready[*]}"
die "pre-release FAILED — see findings above"
