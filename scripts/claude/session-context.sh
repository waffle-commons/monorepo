#!/usr/bin/env bash
# =============================================================================
# scripts/claude/session-context.sh — Claude Code SessionStart hook.
#
# Gives the model one line of context at the start of every session: the
# umbrella branch, the release phase it implies (AGENTS.md §5b) and whether the
# dev container is up. Cheap on purpose (one git call, one docker inspect); it
# never fails a session start.
# =============================================================================
set -u

root="${CLAUDE_PROJECT_DIR:-$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '?')"

case "$branch" in
  pre-release/*-beta7) phase="beta7 build: the Roadmap_Beta7 items" ;;
  pre-release/*-beta8) phase="beta8 freeze: no new capability, bug fixes after the tag" ;;
  pre-release/*-RC*)   phase="RC certification: bug fixes only" ;;
  pre-release/*)       phase="${branch#pre-release/}" ;;
  *)                   phase="none (not a pre-release branch)" ;;
esac

state="$(docker inspect -f '{{.State.Status}}' waffle-dev 2>/dev/null || printf 'absent')"
if [ "$state" = "running" ]; then
  container="waffle-dev is running"
else
  container="waffle-dev is ${state} (wfl up starts it; PHP gates cannot run until then)"
fi

context="waffle-commons session: umbrella on ${branch}; release phase ${phase}; ${container}."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "${context//\"/\\\"}"
