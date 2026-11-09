#!/usr/bin/env bash
# =============================================================================
# scripts/claude/session-context.sh — Claude Code SessionStart hook.
#
# Gives the model one line of context at the start of every session: the
# umbrella branch, the release phase it implies (AGENTS.md §5b) and whether the
# dev container is up. Cheap on purpose (one git call, one docker inspect, and
# one docker version only when the inspect fails); it never fails a session
# start.
#
# Claude Code rejects output that starts like JSON but does not parse, so jq
# encodes the payload. Without jq the line goes out as plain text, which a
# SessionStart hook may also print. Tests: scripts/tests/test_session_context.py.
# =============================================================================
set -u

root="${CLAUDE_PROJECT_DIR:-$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"

# A failing command can still write to stdout (git prints HEAD in a repository
# without a commit, docker inspect an empty line), so a fallback replaces the
# captured text instead of being appended to it.
branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch='?'

case "$branch" in
  pre-release/*-beta7) phase="beta7 build: the Roadmap_Beta7 items" ;;
  pre-release/*-beta8) phase="beta8 freeze: no new capability, bug fixes after the tag" ;;
  pre-release/*-RC*)   phase="RC certification: bug fixes only" ;;
  pre-release/*)       phase="${branch#pre-release/}" ;;
  *)                   phase="none (not a pre-release branch)" ;;
esac

if state="$(docker inspect -f '{{.State.Status}}' waffle-dev 2>/dev/null)"; then
  if [ "$state" = "running" ]; then
    container="waffle-dev is running"
  else
    container="waffle-dev is ${state} (wfl up starts it; PHP gates cannot run until then)"
  fi
elif docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  container="waffle-dev is absent (wfl up starts it; PHP gates cannot run until then)"
else
  container="Docker is not reachable (start Docker Desktop, then wfl up; PHP gates cannot run until then)"
fi

context="waffle-commons session: umbrella on ${branch}; release phase ${phase}; ${container}."
if command -v jq >/dev/null 2>&1 &&
  payload="$(jq -cn --arg context "$context" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $context}}' 2>/dev/null)"; then
  printf '%s\n' "$payload"
else
  printf '%s\n' "$context"
fi
