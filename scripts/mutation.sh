#!/usr/bin/env bash
# =============================================================================
# scripts/mutation.sh — mutation testing for one component (Infection).
#
# Coverage says a line ran; mutation testing says a test would notice if it
# were wrong. Infection mutates src/ (flips conditions, drops calls, changes
# return values) and reruns the tests: a mutant no test kills is a gap.
#
# The Infection phar is pinned in .infection-version ("<version> <sha256>"),
# downloaded once into tmp/tools/ and checked against that hash (the digest
# GitHub publishes for the release asset). It runs inside waffle-dev with
# Xdebug's coverage mode. A component needs no config of its own: the run
# writes one under var/infection/ (gitignored), with absolute paths since
# Infection resolves them from the config file's folder.
#
# The Mutation Score Indicator (MSI) must reach the component's floor in
# .mutation-floors (or --min-msi); --ratchet raises that floor to this run.
# Not part of `wfl dod`: a run takes minutes. Use it before a release and on
# the security-critical components (security, auth, http, http-client, data).
#
# Usage:   scripts/mutation.sh <component> [--min-msi=N] [--threads=N] [--ratchet] [--filter=path]
# Exit:    0 when the MSI reaches the floor, 1 otherwise.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"
PIN_FILE="$REPO_ROOT/.infection-version"
FLOORS="$REPO_ROOT/.mutation-floors"

die() { printf '✗ %s\n' "$*" >&2; exit 1; }
ok()  { printf '✓ %s\n' "$*"; }
info() { printf '→ %s\n' "$*"; }

COMP="${1:-}"
[ -n "$COMP" ] || die "usage: scripts/mutation.sh <component> [--min-msi=N] [--threads=N] [--ratchet] [--filter=path]"
shift
MIN_MSI=""
THREADS="max"
RATCHET=0
FILTER=""
for a in "$@"; do
  case "$a" in
    --min-msi=*) MIN_MSI="${a#--min-msi=}" ;;
    --threads=*) THREADS="${a#--threads=}" ;;
    --ratchet)   RATCHET=1 ;;
    --filter=*)  FILTER="${a#--filter=}" ;;
    *)           die "unknown option: $a" ;;
  esac
done
"$REPO_ROOT/scripts/list-components.sh" | grep -qx "$COMP" || die "unknown component: $COMP"
[ -d "$REPO_ROOT/$COMP/src" ] || die "$COMP has no src/ to mutate"
[ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)" = running ] || die "$CONTAINER is not running (wfl up)"

# --- the pinned phar -----------------------------------------------------
read -r VERSION SHA < "$PIN_FILE" || die "cannot read $PIN_FILE"
PHAR_REL="tmp/tools/infection-$VERSION.phar"
PHAR="$REPO_ROOT/$PHAR_REL"
if [ ! -f "$PHAR" ]; then
  info "downloading Infection $VERSION"
  mkdir -p "$(dirname "$PHAR")"
  curl -fsSL -o "$PHAR.part" "https://github.com/infection/infection/releases/download/$VERSION/infection.phar"
  mv "$PHAR.part" "$PHAR"
fi
actual="$(shasum -a 256 "$PHAR" | cut -d' ' -f1)"
if [ "$actual" != "$SHA" ]; then
  rm -f "$PHAR"
  die "Infection $VERSION does not match the pinned sha256 (got $actual): deleted, not run"
fi

# --- the floor ------------------------------------------------------------
if [ -z "$MIN_MSI" ]; then
  MIN_MSI="$(awk -v c="$COMP" '$1 == c { print $2 }' "$FLOORS" 2>/dev/null || true)"
  MIN_MSI="${MIN_MSI:-0}"
fi

# --- the run ---------------------------------------------------------------
WORK="/waffle-commons/$COMP"
docker exec -i -w "$WORK" "$CONTAINER" sh -c 'mkdir -p var/infection && cat > var/infection/infection.json5' <<JSON
{
  "source": { "directories": ["$WORK/src"] },
  "tmpDir": "$WORK/var/infection/tmp",
  "logs": { "text": "$WORK/var/infection/infection.log", "summary": "$WORK/var/infection/summary.log", "json": "$WORK/var/infection/infection.json" },
  "phpUnit": { "configDir": "$WORK", "customPath": "$WORK/vendor/bin/phpunit" },
  "mutators": { "@default": true }
}
JSON

info "Infection $VERSION on $COMP (floor ${MIN_MSI}% MSI, threads $THREADS)"
set +e
docker exec -w "$WORK" -e XDEBUG_MODE=coverage "$CONTAINER" \
  php -d memory_limit=-1 "/waffle-commons/$PHAR_REL" \
  --configuration=var/infection/infection.json5 --threads="$THREADS" --no-progress --no-interaction \
  --show-mutations=30 ${FILTER:+--filter="$FILTER"}
code=$?
set -e
[ "$code" -eq 0 ] || die "Infection exited $code (see $COMP/var/infection/infection.log)"

msi="$(docker exec -w "$WORK" "$CONTAINER" php -r '$j = json_decode((string) file_get_contents("var/infection/infection.json"), true); echo is_array($j) && isset($j["stats"]["msi"]) ? $j["stats"]["msi"] : "";')"
[ -n "$msi" ] || die "no MSI in $COMP/var/infection/infection.json"

if awk -v m="$msi" -v f="$MIN_MSI" 'BEGIN { exit !(m + 0.005 < f) }'; then
  die "$COMP MSI ${msi}% is below its floor ${MIN_MSI}%: the surviving mutants above are untested behaviour"
fi
ok "$COMP MSI ${msi}% (floor ${MIN_MSI}%)"

if [ "$RATCHET" -eq 1 ] && [ -z "$FILTER" ]; then
  new="$(awk -v m="$msi" 'BEGIN { printf "%.2f", int(m * 100) / 100 }')"
  [ -f "$FLOORS" ] || printf '# Mutation (MSI) floors: `wfl mutation <comp> --ratchet` raises them; lowered only by hand, in a reviewed commit.\n' > "$FLOORS"
  tmp="$(mktemp "$FLOORS.XXXXXX")"
  awk -v c="$COMP" '$1 != c' "$FLOORS" > "$tmp"
  printf '%s %s\n' "$COMP" "$new" >> "$tmp"
  { grep '^#' "$tmp"; grep -v '^#' "$tmp" | sort; } > "$FLOORS"
  rm -f "$tmp"
  ok "floor for $COMP set to ${new}% (.mutation-floors)"
fi
