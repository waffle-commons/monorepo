#!/usr/bin/env bash
# =============================================================================
# igor.sh — Igor-PHP memory-leak & state-mutation audit across waffle-commons.
#
# Dynamically scans every component (a sub-directory holding a composer.json)
# and audits the ones that declare "igor-php/igor-php" under "require" or
# "require-dev". Each component's own igor.json (when present at its root) is
# honored automatically: igor-php is invoked *relative to the component root*,
# where it auto-discovers that igor.json.
#
# The loop never halts on the first failure — every candidate is audited, and
# the script exits non-zero if ANY audit failed.
#
# Usage:
#   ./igor.sh [options] [-- <extra igor-php args>]
#
# Options:
#   -s, --silent           One line per component; suppress per-audit output.
#   -v, --verbose          Stream each audit's output live (default).
#   -c, --component NAME    Audit only this component (repeatable).
#       --local            Run igor-php directly (no `docker exec` wrapper).
#       --docker           Force `docker exec` into the dev container.
#       --container NAME    Dev container for docker mode (default: waffle-dev).
#   -h, --help             Show this help and exit.
#
# Exit codes: 0 = all audits passed (or nothing to audit); 1 = at least one
# component failed its audit or could not be audited in a strict context.
# =============================================================================

set -euo pipefail

# --- Self-location: operate from the directory this script lives in ----------
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Configuration (overridable via flags / environment) ---------------------
CONTAINER_NAME="${WAFFLE_CONTAINER:-waffle-dev}"
WORK_DIR_BASE="/waffle-commons"
IGOR_BIN="vendor/bin/igor-php"
OUTPUT_MODE="VERBOSE"        # VERBOSE | SILENT
MODE=""                      # docker | local (auto-detected when empty)

# Directories that are never components.
SKIP_DIRS=" vendor node_modules var images graphify-out .git .github "

# --- Colors (disabled when stdout is not a TTY, e.g. CI logs) -----------------
if [ -t 1 ]; then
    GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m';  BOLD=$'\033[1m';   DIM=$'\033[2m'; NC=$'\033[0m'
else
    GREEN=""; RED=""; YELLOW=""; BLUE=""; BOLD=""; DIM=""; NC=""
fi

info()  { printf '%s[INFO]%s  %s\n'  "$BLUE"   "$NC" "$*"; }
ok()    { printf '%s[OK]%s    %s\n'  "$GREEN"  "$NC" "$*"; }
warn()  { printf '%s[WARN]%s  %s\n'  "$YELLOW" "$NC" "$*"; }
error() { printf '%s[ERROR]%s %s\n'  "$RED"    "$NC" "$*" >&2; }

usage() {
    # Print the contiguous leading comment block (after the shebang), stripping
    # the "# " prefix and stopping at the first non-comment line.
    awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

# --- Temp workspace + cleanup trap -------------------------------------------
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/igor-audit.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

SUMMARY_FILE="$TMP_DIR/summary.tsv"
CANDIDATES_FILE="$TMP_DIR/candidates.txt"
: >"$SUMMARY_FILE"
: >"$CANDIDATES_FILE"

# --- Argument parsing --------------------------------------------------------
ONLY_COMPONENTS=""           # space-delimited allow-list (empty = all)
EXTRA_ARGS=()                # forwarded verbatim to igor-php after `--`

while [ "$#" -gt 0 ]; do
    case "$1" in
        -s|--silent)    OUTPUT_MODE="SILENT" ;;
        -v|--verbose)   OUTPUT_MODE="VERBOSE" ;;
        --local)        MODE="local" ;;
        --docker)       MODE="docker" ;;
        --container)    shift; CONTAINER_NAME="${1:?--container requires a name}" ;;
        --container=*)  CONTAINER_NAME="${1#*=}" ;;
        -c|--component) shift; ONLY_COMPONENTS="$ONLY_COMPONENTS ${1:?--component requires a name}" ;;
        --component=*)  ONLY_COMPONENTS="$ONLY_COMPONENTS ${1#*=}" ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; while [ "$#" -gt 0 ]; do EXTRA_ARGS+=("$1"); shift; done; break ;;
        -*)             error "Unknown option: $1"; usage; exit 64 ;;
        *)              error "Unexpected argument: $1"; usage; exit 64 ;;
    esac
    shift
done

# --- Mode auto-detection ------------------------------------------------------
if [ -z "$MODE" ]; then
    if [ -f /.dockerenv ] || [ -n "${WAFFLE_IN_CONTAINER:-}" ]; then
        MODE="local"
    else
        MODE="docker"
    fi
fi

# --- Docker pre-flight --------------------------------------------------------
if [ "$MODE" = "docker" ]; then
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker mode requested but the 'docker' CLI is not available. Use --local."
        exit 1
    fi
    if [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || printf 'absent')" != "running" ]; then
        error "Container '$CONTAINER_NAME' is not running. Start it (e.g. 'wfl up') or use --local."
        exit 1
    fi
fi

# --- Helpers -----------------------------------------------------------------

# is_candidate <composer.json> — true when igor-php is a declared dependency.
is_candidate() {
    local file="$1"
    [ -f "$file" ] || return 1
    if command -v jq >/dev/null 2>&1; then
        jq -e '((.require // {}) + (.["require-dev"] // {})) | has("igor-php/igor-php")' \
            "$file" >/dev/null 2>&1
    else
        grep -Eq '"igor-php/igor-php"[[:space:]]*:' "$file"
    fi
}

# selected <component> — honor an optional --component allow-list.
selected() {
    [ -z "$ONLY_COMPONENTS" ] && return 0
    case " $ONLY_COMPONENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# igor_installed <component> — true when vendor/bin/igor-php is executable.
igor_installed() {
    local comp="$1"
    if [ "$MODE" = "docker" ]; then
        docker exec "$CONTAINER_NAME" test -x "$WORK_DIR_BASE/$comp/$IGOR_BIN" 2>/dev/null
    else
        test -x "$comp/$IGOR_BIN"
    fi
}

# run_audit <component> <logfile> — run igor-php, return its exit code.
run_audit() {
    local comp="$1" logfile="$2" rc=0
    set +o errexit
    if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
        if [ "$MODE" = "docker" ]; then
            docker exec -w "$WORK_DIR_BASE/$comp" "$CONTAINER_NAME" \
                "$IGOR_BIN" . ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} 2>&1 | tee "$logfile"
        else
            ( cd "$comp" && "$IGOR_BIN" . ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} ) 2>&1 | tee "$logfile"
        fi
        rc=${PIPESTATUS[0]}
    else
        if [ "$MODE" = "docker" ]; then
            docker exec -w "$WORK_DIR_BASE/$comp" "$CONTAINER_NAME" \
                "$IGOR_BIN" . ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} >"$logfile" 2>&1
        else
            ( cd "$comp" && "$IGOR_BIN" . ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} ) >"$logfile" 2>&1
        fi
        rc=$?
    fi
    set -o errexit
    return "$rc"
}

# count_findings <logfile> — number of dangerous services found.
# Prefers Igor's own "KO (Dangerous State): N" tally; otherwise falls back to a
# keyword scan so the column stays meaningful across Igor output formats.
count_findings() {
    local file="$1" n=""
    [ -f "$file" ] || { printf '0'; return 0; }
    n="$(grep -aE 'KO \(Dangerous State\)' "$file" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
    if [ -z "$n" ]; then
        n="$(grep -aciE 'mutation|leak|stateful|unsafe|violation' "$file" 2>/dev/null || true)"
    fi
    [ -n "$n" ] || n=0
    printf '%s' "$n"
}

# --- Dynamic component discovery ---------------------------------------------
SKIP_COUNT=0
shopt -s nullglob
for dir in */; do
    comp="${dir%/}"
    case "$SKIP_DIRS" in *" $comp "*) continue ;; esac
    case "$comp" in .*) continue ;; esac
    [ -f "$comp/composer.json" ] || continue
    if is_candidate "$comp/composer.json"; then
        if selected "$comp"; then
            printf '%s\n' "$comp" >>"$CANDIDATES_FILE"
        fi
    fi
done
shopt -u nullglob
LC_ALL=C sort -o "$CANDIDATES_FILE" "$CANDIDATES_FILE"

TOTAL="$(wc -l <"$CANDIDATES_FILE" | tr -d '[:space:]')"

# --- Header ------------------------------------------------------------------
printf '%s===================================================%s\n' "$BOLD" "$NC"
printf '%s🔬 Igor Audit%s — memory leaks & state mutations (mode: %s%s%s)\n' \
    "$BOLD" "$NC" "$BOLD" "$MODE" "$NC"
printf '%s===================================================%s\n' "$BOLD" "$NC"

if [ "$TOTAL" -eq 0 ]; then
    warn "No components declare igor-php/igor-php — nothing to audit."
    exit 0
fi

# --- Audit loop --------------------------------------------------------------
INDEX=0
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
FAILED_LIST=""

while IFS= read -r comp; do
    [ -n "$comp" ] || continue
    INDEX=$((INDEX + 1))
    logfile="$TMP_DIR/$comp.log"
    mkdir -p "$(dirname "$logfile")"

    has_config="no"
    [ -f "$comp/igor.json" ] && has_config="yes"

    if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
        printf '%s---------------------------------------------------%s\n' "$DIM" "$NC"
        if [ "$has_config" = "yes" ]; then
            info "[$INDEX/$TOTAL] Auditing $BOLD$comp$NC (igor.json found)"
        else
            info "[$INDEX/$TOTAL] Auditing $BOLD$comp$NC (no igor.json — using defaults)"
        fi
    else
        printf '[%2d/%2d] %-20s %s⏳ running…%s' "$INDEX" "$TOTAL" "$comp" "$BLUE" "$NC"
    fi

    if ! igor_installed "$comp"; then
        WARN_COUNT=$((WARN_COUNT + 1))
        printf 'WARN\t%s\t-\n' "$comp" >>"$SUMMARY_FILE"
        if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
            warn "$comp: igor-php not installed (run 'composer install' in $comp) — skipped."
        else
            printf '\r[%2d/%2d] %-20s %s[WARN]%s not installed       \n' \
                "$INDEX" "$TOTAL" "$comp" "$YELLOW" "$NC"
        fi
        continue
    fi

    rc=0
    run_audit "$comp" "$logfile" || rc=$?
    findings="$(count_findings "$logfile")"

    if [ "$rc" -eq 0 ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf 'OK\t%s\t%s\n' "$comp" "$findings" >>"$SUMMARY_FILE"
        if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
            ok "$comp: audit clean."
        else
            printf '\r[%2d/%2d] %-20s %s[OK]%s   findings: %-4s\n' \
                "$INDEX" "$TOTAL" "$comp" "$GREEN" "$NC" "$findings"
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_LIST="$FAILED_LIST $comp"
        printf 'ERROR\t%s\t%s\n' "$comp" "$findings" >>"$SUMMARY_FILE"
        if [ "$OUTPUT_MODE" = "VERBOSE" ]; then
            error "$comp: audit FAILED (exit $rc, findings: $findings)."
        else
            printf '\r[%2d/%2d] %-20s %s[ERROR]%s exit %-2d findings: %-4s\n' \
                "$INDEX" "$TOTAL" "$comp" "$RED" "$NC" "$rc" "$findings"
            # Surface the failing output even in silent mode for debuggability.
            sed 's/^/    /' "$logfile" >&2
        fi
    fi
done <"$CANDIDATES_FILE"

# --- Final summary table -----------------------------------------------------
echo
printf '%s===================================================%s\n' "$BOLD" "$NC"
printf '%s📊 Igor Audit Summary%s\n' "$BOLD" "$NC"
printf '%s===================================================%s\n' "$BOLD" "$NC"
printf '  %-8s %-22s %s\n' "STATUS" "COMPONENT" "DANGEROUS*"
printf '%s---------------------------------------------------%s\n' "$DIM" "$NC"
while IFS=$'\t' read -r status comp findings; do
    [ -n "$status" ] || continue
    case "$status" in
        OK)    color="$GREEN"; label="[OK]" ;;
        ERROR) color="$RED";   label="[ERROR]" ;;
        WARN)  color="$YELLOW"; label="[WARN]" ;;
        *)     color="$NC";    label="[$status]" ;;
    esac
    printf '  %s%-8s%s %-22s %s\n' "$color" "$label" "$NC" "$comp" "$findings"
done <"$SUMMARY_FILE"
printf '%s---------------------------------------------------%s\n' "$DIM" "$NC"
printf '  Audited: %s%d%s   %s[OK] %d%s   %s[ERROR] %d%s   %s[WARN] %d%s   (skipped dirs: %d)\n' \
    "$BOLD" "$TOTAL" "$NC" \
    "$GREEN" "$PASS_COUNT" "$NC" \
    "$RED" "$FAIL_COUNT" "$NC" \
    "$YELLOW" "$WARN_COUNT" "$NC" \
    "$SKIP_COUNT"
printf '  %s* DANGEROUS = Igor'\''s "KO (Dangerous State)" count; the [OK]/[ERROR]\n' "$DIM"
printf '    status is authoritative (driven by igor-php'\''s exit code).%s\n' "$NC"
printf '%s===================================================%s\n' "$BOLD" "$NC"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf '%s%s💥 Final state: FAIL%s — failed:%s\n' "$BOLD" "$RED" "$NC" "$FAILED_LIST"
    exit 1
fi
printf '%s%s🎉 Final state: SUCCESS%s — no leaks or state mutations detected.\n' "$BOLD" "$GREEN" "$NC"
exit 0
