#!/usr/bin/env bash
# =============================================================================
# scripts/mcp/github.sh — stdio launcher for the GitHub MCP server (Docker).
#
# Token resolution, first match wins: GITHUB_TOKEN, GITHUB_PERSONAL_ACCESS_TOKEN,
# then the GitHub CLI keyring (`gh auth token`). The token reaches the container
# through the environment only — never argv, never a file.
#
# READ-ONLY by design: merges, pushes, releases and repository changes stay
# with the human, through `gh` and its own prompts (see AGENTS.md, "Git &
# release safety"). The `actions` toolset adds read access to CI runs and logs.
#
# stdout is the MCP channel — diagnostics go to stderr only.
# =============================================================================
set -euo pipefail

token="${GITHUB_TOKEN:-${GITHUB_PERSONAL_ACCESS_TOKEN:-}}"
if [ -z "$token" ] && command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"
fi
if [ -z "$token" ]; then
  echo "github MCP: no token found — export GITHUB_TOKEN or run 'gh auth login'" >&2
  exit 1
fi
export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
unset token

exec docker run --rm -i -e GITHUB_PERSONAL_ACCESS_TOKEN \
  ghcr.io/github/github-mcp-server:v1.12.2 \
  stdio --read-only --toolsets=default,actions
