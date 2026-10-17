#!/usr/bin/env bash
# =============================================================================
# scripts/local-only.sh — how much work exists only on this disk.
#
# Counts the commits that no remote holds (`--branches --not --remotes`) in the
# umbrella, every initialised submodule (recursively) and each repository of
# its own under contributions/, and reads how long ago `wfl backup` last
# finished. The waffle-cockpit draws both under the prompt (`⇡91 · backup 6h`).
#
# Usage:   scripts/local-only.sh
# Output:  two lines, read by the cockpit:
#            local-only <N>
#            backup-age-s <seconds>|none
# Exit:    0 (read-only; an unreadable repository counts as 0)
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="${WAFFLE_BACKUP_STAMP:-${XDG_STATE_HOME:-$HOME/.local/state}/waffle/last-backup}"

count_in() {
  git -C "$1" rev-list --count --branches --not --remotes 2>/dev/null || printf '0\n'
}

total="$(count_in "$REPO_ROOT")"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  total=$((total + $(count_in "$REPO_ROOT/$path")))
done < <(git -C "$REPO_ROOT" submodule foreach --recursive --quiet 'printf "%s\n" "$displaypath"' 2>/dev/null)

for dir in "$REPO_ROOT"/contributions/*/; do
  [ -d "$dir" ] || continue
  dir="${dir%/}"
  # contributions/ sits inside the umbrella's tree: only a repository of its own counts.
  [ "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" = "$dir" ] || continue
  git -C "$dir" rev-parse -q --verify HEAD >/dev/null 2>&1 || continue
  total=$((total + $(count_in "$dir")))
done

printf 'local-only %s\n' "$total"
if [ -f "$STAMP" ]; then
  then_s="$(tr -dc '0-9' < "$STAMP")"
  now_s="$(date +%s)"
  if [ -n "$then_s" ] && [ "$then_s" -le "$now_s" ]; then
    printf 'backup-age-s %s\n' "$((now_s - then_s))"
    exit 0
  fi
fi
printf 'backup-age-s none\n'
