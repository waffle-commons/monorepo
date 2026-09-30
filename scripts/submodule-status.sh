#!/usr/bin/env bash
# =============================================================================
# scripts/submodule-status.sh — READ-ONLY sync report for the umbrella and
# every submodule: current branch, dirty files, commits ahead/behind
# origin/main and the branch's own upstream, and whether the umbrella gitlink
# matches the submodule HEAD.
#
# It never moves a HEAD, never updates a gitlink, never pulls. (The old
# `/sync-components` ran `git submodule update --remote`, which detaches every
# submodule from its local pre-release branch.) --fetch refreshes the
# remote-tracking refs first; that touches refs/remotes/* only.
#
# Usage:   scripts/submodule-status.sh [--fetch]
# Exit:    0 always (a report, not a gate).
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FETCH=0
[ "${1:-}" = "--fetch" ] && FETCH=1

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_YEL=$'\033[0;33m'; C_GRN=$'\033[0;32m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_YEL=""; C_GRN=""; C_DIM=""; C_RST=""
fi

# row <label> <repo-dir> <expected-gitlink-sha-or-empty>
row() {
  local label="$1" dir="$2" gitlink="$3"
  local branch dirty up ahead_main behind_main ahead_up behind_up link_state
  [ "$FETCH" -eq 1 ] && git -C "$dir" fetch --quiet origin 2>/dev/null
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  [ "$branch" = "HEAD" ] && branch="${C_RED}DETACHED${C_RST}"
  dirty="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if git -C "$dir" rev-parse --verify --quiet origin/main >/dev/null; then
    ahead_main="$(git -C "$dir" rev-list --count origin/main..HEAD 2>/dev/null)"
    behind_main="$(git -C "$dir" rev-list --count HEAD..origin/main 2>/dev/null)"
  else
    ahead_main="?"; behind_main="?"
  fi
  up="$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
  if [ -n "$up" ]; then
    ahead_up="$(git -C "$dir" rev-list --count "$up"..HEAD 2>/dev/null)"
    behind_up="$(git -C "$dir" rev-list --count HEAD.."$up" 2>/dev/null)"
    up="$up +$ahead_up/-$behind_up"
  else
    up="${C_DIM}no upstream${C_RST}"
  fi
  link_state="-"
  if [ -n "$gitlink" ]; then
    if [ "$gitlink" = "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" ]; then
      link_state="${C_GRN}match${C_RST}"
    else
      link_state="${C_YEL}moved${C_RST}"
    fi
  fi
  [ "$dirty" -gt 0 ] && dirty="${C_YEL}${dirty}${C_RST}"
  [ "$behind_main" != "?" ] && [ "$behind_main" -gt 0 ] && behind_main="${C_RED}${behind_main}${C_RST}"
  printf '%-20s %-34s dirty=%-4s main +%s/-%-4s %-32s gitlink=%s\n' \
    "$label" "$branch" "$dirty" "$ahead_main" "$behind_main" "$up" "$link_state"
}

row "(umbrella)" "$REPO_ROOT" ""
while IFS= read -r path; do
  [ -e "$REPO_ROOT/$path/.git" ] || { printf '%-20s %s\n' "$path" "not checked out"; continue; }
  gitlink="$(git -C "$REPO_ROOT" ls-tree HEAD "$path" 2>/dev/null | awk '{print $3}')"
  row "$path" "$REPO_ROOT/$path" "$gitlink"
done < <("$REPO_ROOT/scripts/list-components.sh")

printf '%s\nmain +a/-b = commits ahead/behind origin/main (as of the last fetch%s).\n' "$C_DIM" \
  "$([ "$FETCH" -eq 1 ] && echo ', refreshed now' || echo '; add --fetch to refresh')"
printf 'gitlink=moved: the submodule HEAD differs from the commit the umbrella records.%s\n' "$C_RST"
exit 0
