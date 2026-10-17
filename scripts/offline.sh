#!/usr/bin/env bash
# =============================================================================
# scripts/offline.sh — can every component install with no network?
#
# Composer installs from a lock file without asking Packagist when every
# locked dist is already in its cache. waffle-dev keeps that cache in the
# container's own layer, which a rebuild throws away, so this script keeps one
# on the bind mount instead: tmp/composer-cache (gitignored, survives `wfl
# build`, `wfl docker:reset` and the network).
#
#   warm    fill the cache: a throwaway install of each component's lock into
#           /tmp, with scripts, plugins and the autoloader off (the component's
#           own vendor/ is never touched)
#   check   the same install with COMPOSER_DISABLE_NETWORK=1: a component that
#           passes installs offline; one that fails names what is missing
#   status  the cache's size
#
# Usage:   scripts/offline.sh warm|check|status [component…]
# Exit:    0 on success, 1 when a component failed.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"
CACHE_REL="tmp/composer-cache"
CACHE="/waffle-commons/$CACHE_REL"

die() { printf '✗ %s\n' "$*" >&2; exit 1; }

ACTION="${1:-status}"
shift || true
COMPONENTS=("$@")
if [ "${#COMPONENTS[@]}" -eq 0 ]; then
  while IFS= read -r c; do
    [ -f "$REPO_ROOT/$c/composer.lock" ] && COMPONENTS+=("$c")
  done < <("$REPO_ROOT/scripts/list-components.sh")
fi

case "$ACTION" in
  status)
    if [ -d "$REPO_ROOT/$CACHE_REL" ]; then
      printf '%s  %s\n' "$(du -sh "$REPO_ROOT/$CACHE_REL" | cut -f1)" "$CACHE_REL"
    else
      printf '· no cache yet: scripts/offline.sh warm\n'
    fi
    exit 0
    ;;
  warm|check) ;;
  *) die "usage: scripts/offline.sh warm|check|status [component…]" ;;
esac

[ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)" = running ] || die "$CONTAINER is not running (wfl up)"
mkdir -p "$REPO_ROOT/$CACHE_REL"

failed=0
for comp in "${COMPONENTS[@]}"; do
  [ -f "$REPO_ROOT/$comp/composer.lock" ] || { printf '  · %-18s no composer.lock\n' "$comp"; continue; }
  scratch="/tmp/offline-vendor-$comp"
  envs=(-e "COMPOSER_CACHE_DIR=$CACHE" -e "COMPOSER_VENDOR_DIR=$scratch" -e "COMPOSER_HOME=/tmp/offline-home")
  [ "$ACTION" = check ] && envs+=(-e COMPOSER_DISABLE_NETWORK=1)
  out="$(docker exec "${envs[@]}" -w "/waffle-commons/$comp" "$CONTAINER" \
    composer install --no-scripts --no-plugins --no-autoloader --no-progress --no-interaction 2>&1)"
  code=$?
  docker exec "$CONTAINER" rm -rf "$scratch" >/dev/null 2>&1
  if [ "$code" -eq 0 ]; then
    printf '  ✓ %-18s %s\n' "$comp" "$([ "$ACTION" = check ] && printf 'installs offline' || printf 'cached')"
  else
    failed=1
    printf '  ✗ %-18s %s\n' "$comp" "$(printf '%s\n' "$out" | grep -iE 'error|failed|could not|network' | head -1)"
  fi
done
"$0" status
exit "$failed"
