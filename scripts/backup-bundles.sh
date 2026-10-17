#!/usr/bin/env bash
# =============================================================================
# scripts/backup-bundles.sh — off-disk backup of every local git repository (`wfl backup`).
#
# Writes one `git bundle --all` per repository (the umbrella, every initialised
# submodule recursively, each repo under contributions/) into a new dated
# folder and verifies each bundle. Uncommitted tracked changes go into a patch
# beside the bundle; a repository with no commit yet has nothing to bundle, so its
# working tree is archived instead. It also tars the gitignored data that has no other copy and
# writes a MANIFEST.txt that says how to restore. The repositories are only
# read. The last step sets push.recurseSubmodules=check in the umbrella, so a
# push there can never pin submodule commits that exist only on this disk.
# When every bundle verifies, it stamps the time in
# ${XDG_STATE_HOME:-~/.local/state}/waffle/last-backup (WAFFLE_BACKUP_STAMP),
# which the waffle-cockpit reads for its `backup 6h ago` segment.
#
# Usage: u1-backup-bundles.sh [--dest DIR] [--dry-run] [--no-data] [--no-push-check]
#   --dest DIR       parent of the dated snapshot folder (default: $WAFFLE_BACKUP_DIR, else iCloud Drive/waffle-backup)
#   --dry-run        list what would be backed up, write nothing
#   --no-data        skip the tarball of gitignored data
#   --no-push-check  leave push.recurseSubmodules alone
#   --root DIR       the umbrella (default: the parent of this script's folder)
# Exit: 0 when every bundle verifies, 1 otherwise.
# =============================================================================
set -euo pipefail

if [ -t 1 ]; then G=$'\033[0;32m' Y=$'\033[0;33m' R=$'\033[0;31m' C=$'\033[0;36m' N=$'\033[0m'; else G='' Y='' R='' C='' N=''; fi
info() { printf '%s→ %s%s\n' "$C" "$*" "$N"; }
ok()   { printf '%s✓ %s%s\n' "$G" "$*" "$N"; }
warn() { printf '%s! %s%s\n' "$Y" "$*" "$N" >&2; }
die()  { printf '%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${WAFFLE_BACKUP_DIR:-$ICLOUD/waffle-backup}"
STAMP_FILE="${WAFFLE_BACKUP_STAMP:-${XDG_STATE_HOME:-$HOME/.local/state}/waffle/last-backup}"
DRY_RUN=0
WITH_DATA=1
PUSH_CHECK=1

# Gitignored data with no other copy. Secrets (*.pem, *.jks) and .project-memory/
# (its anonymization map is local by design) stay out on purpose.
DATA_PATHS="project_system/Audits project_system/Notes project_system/TODOs bench/results .claude/settings.local.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)          [ $# -ge 2 ] || die "--dest needs a directory"; BASE="$2"; shift 2 ;;
    --dest=*)        BASE="${1#--dest=}"; shift ;;
    --root)          [ $# -ge 2 ] || die "--root needs a directory"; ROOT="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=1; shift ;;
    --no-data)       WITH_DATA=0; shift ;;
    --no-push-check) PUSH_CHECK=0; shift ;;
    -h|--help)       awk 'NR > 2 && /^# =+$/ { exit } NR > 2 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)               die "unknown option: $1 (see --help)" ;;
  esac
done

[ -f "$ROOT/.gitmodules" ] && [ -x "$ROOT/bin/wfl" ] || die "not the waffle-commons umbrella: $ROOT (pass --root)"
if [ "$BASE" = "$ICLOUD/waffle-backup" ] && [ ! -d "$ICLOUD" ]; then
  die "iCloud Drive not found at $ICLOUD — pass --dest <dir> (an external disk works too)"
fi

# Every repository as "path<TAB>bundle name", umbrella first.
list_repos() {
  printf '.\tumbrella\n'
  git -C "$ROOT" submodule foreach --recursive --quiet \
    'printf "%s\t%s\n" "$displaypath" "$(printf %s "$displaypath" | tr / _)"'
  local d top
  for d in "$ROOT"/contributions/*/; do
    [ -d "$d" ] || continue
    d="$(cd -P -- "$d" && pwd)"
    # contributions/ sits inside the umbrella's tree: only a repo of its own counts.
    top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
    [ "$top" = "$d" ] || continue
    printf '%s\tcontrib_%s\n' "contributions/${d##*/}" "${d##*/}"
  done
}

# Packed + loose object size of a repository, in KiB.
size_kib() {
  git -C "$1" count-objects -v | awk '/^size(-pack)?:/ { s += $2 } END { print s + 0 }'
}

STAMP="$(date +%Y-%m-%d)"
SNAP="$BASE/$STAMP"
[ -e "$SNAP" ] && SNAP="$BASE/${STAMP}_$(date +%H%M%S)"   # never overwrite a snapshot

REPOS="$(list_repos)"
COUNT="$(printf '%s\n' "$REPOS" | wc -l | tr -d ' ')"
if [ "$DRY_RUN" -eq 1 ]; then
  info "$COUNT repositories → $SNAP (dry run: nothing is written)"
else
  info "$COUNT repositories → $SNAP"
  mkdir -p "$SNAP"
fi

MANIFEST="$(printf '%-34s %-28s %-9s %10s %11s\n' bundle branch head local-only uncommitted)"
FAILED=0
TOTAL_KIB=0
# fd 3 carries the list, so no command in the loop can swallow it from stdin.
while IFS=$'\t' read -r path name <&3; do
  dir="$ROOT/$path"

  # No commit yet (a fresh `git init`): nothing to bundle, so archive the working tree.
  if ! git -C "$dir" rev-parse -q --verify HEAD >/dev/null; then
    MANIFEST="$MANIFEST
$(printf '%-34s %-28s %-9s %10s %11s' "$name.worktree.tgz" "(no commit yet)" "-" "-" "-")"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "  $path: no commit yet, its working tree would be archived as $name.worktree.tgz"
      continue
    fi
    if tar -czf "$SNAP/$name.worktree.tgz" --exclude .git --exclude node_modules --exclude vendor \
         --exclude coverage -C "$(dirname "$dir")" "$(basename "$dir")"; then
      printf '  %sok%s  %s (no commit yet: working tree)\n' "$G" "$N" "$name.worktree.tgz"
    else
      printf '  %sFAIL%s  %s (%s)\n' "$R" "$N" "$name.worktree.tgz" "$path"
      FAILED=$((FAILED + 1))
    fi
    continue
  fi

  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  head="$(git -C "$dir" rev-parse --short HEAD)"
  local_only="$(git -C "$dir" rev-list --count --branches --not --remotes)"
  dirty="$(git -C "$dir" status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  MANIFEST="$MANIFEST
$(printf '%-34s %-28s %-9s %10s %11s' "$name.bundle" "$branch" "$head" "$local_only" "$dirty")"

  [ "$(git -C "$dir" rev-parse --is-shallow-repository)" = false ] || warn "$path is shallow: its bundle needs the missing history to restore"

  if [ "$DRY_RUN" -eq 1 ]; then
    kib="$(size_kib "$dir")"
    TOTAL_KIB=$((TOTAL_KIB + kib))
    printf '  %-34s %-28s %6s KiB  local-only %s\n' "$name.bundle" "$branch" "$kib" "$local_only"
    [ "$dirty" -eq 0 ] || info "  $path: $dirty uncommitted tracked change(s) would be saved as $name.uncommitted.patch"
    continue
  fi

  # A bundle holds commits only: uncommitted tracked changes go into a patch beside it.
  if [ "$dirty" -gt 0 ]; then
    git -C "$dir" diff HEAD --binary > "$SNAP/$name.uncommitted.patch"
    warn "$path: $dirty uncommitted tracked change(s) saved as $name.uncommitted.patch (not in the bundle)"
  fi

  if git -C "$dir" bundle create --quiet "$SNAP/$name.bundle" --all \
     && git -C "$dir" bundle verify --quiet "$SNAP/$name.bundle" >/dev/null 2>&1; then
    printf '  %sok%s  %s\n' "$G" "$N" "$name.bundle"
  else
    printf '  %sFAIL%s  %s (%s)\n' "$R" "$N" "$name.bundle" "$path"
    FAILED=$((FAILED + 1))
  fi
done 3<<EOF
$REPOS
EOF

# Gitignored data.
DATA_LIST=""
if [ "$WITH_DATA" -eq 1 ]; then
  for p in $DATA_PATHS; do
    if [ -e "$ROOT/$p" ]; then DATA_LIST="$DATA_LIST $p"; fi
  done
  for p in "$ROOT"/tmp/ai-layer-backup-*.tgz; do
    if [ -e "$p" ]; then DATA_LIST="$DATA_LIST ${p#"$ROOT"/}"; fi
  done
  if [ -z "$DATA_LIST" ]; then
    info "no gitignored data to archive"
  elif [ "$DRY_RUN" -eq 1 ]; then
    info "would archive:$DATA_LIST"
  else
    # shellcheck disable=SC2086 # DATA_LIST is a space-separated list of repo-relative paths
    tar -czf "$SNAP/ignored-data.tgz" -C "$ROOT" $DATA_LIST
    ok "ignored-data.tgz:$DATA_LIST"
  fi
fi

# Manifest.
if [ "$DRY_RUN" -eq 0 ]; then
  cat > "$SNAP/MANIFEST.txt" <<EOF
waffle-commons backup — $(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname -s)
root: $ROOT

$MANIFEST

ignored-data.tgz:${DATA_LIST:- (none)}
Not included on purpose: *.pem, *.jks, .project-memory/ (keep those on an encrypted disk).
Bundles hold commits only: uncommitted tracked changes are in <name>.uncommitted.patch;
untracked files are not saved.

Restore:
  git bundle list-heads <name>.bundle                                  # what it holds
  git clone -b <branch> <name>.bundle <dir>                            # rebuild a repository
  git -C <repo> fetch <name>.bundle 'refs/heads/*:refs/remotes/backup/*'  # into an existing clone
  git -C <repo> apply <name>.uncommitted.patch                         # its uncommitted changes
  tar -xzf <name>.worktree.tgz -C <parent dir>                          # a repository with no commit yet
  tar -xzf ignored-data.tgz -C <umbrella>                              # the gitignored data
EOF
fi

# push.recurseSubmodules=check in the umbrella.
if [ "$PUSH_CHECK" -eq 1 ]; then
  cur="$(git -C "$ROOT" config --get push.recurseSubmodules || true)"
  if [ "$cur" = check ] || [ "$cur" = on-demand ]; then
    ok "push.recurseSubmodules already '$cur'"
  elif [ "$DRY_RUN" -eq 1 ]; then
    info "would set push.recurseSubmodules=check in the umbrella (now: ${cur:-unset})"
  else
    git -C "$ROOT" config push.recurseSubmodules check
    ok "push.recurseSubmodules=check in the umbrella (was: ${cur:-unset})"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  info "about $((TOTAL_KIB / 1024)) MiB of git objects; run again without --dry-run to write the backup"
  exit 0
fi
if [ "$FAILED" -gt 0 ]; then
  die "$FAILED of $COUNT bundles failed — the snapshot in $SNAP is incomplete"
fi
ok "$COUNT bundles verified · $(du -sh "$SNAP" | cut -f1) in $SNAP"
mkdir -p "$(dirname "$STAMP_FILE")" && date +%s > "$STAMP_FILE"
case "$SNAP" in
  "$ICLOUD"/*) info "iCloud uploads in the background: wait for the Finder sync badge before relying on it" ;;
esac
