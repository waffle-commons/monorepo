#!/usr/bin/env bash
# =============================================================================
# scripts/mcp/filesystem.sh — stdio launcher for the filesystem MCP server.
#
# Exposes THIS repository only; the root is resolved from the script location,
# so no personal path is committed. Wired into opencode and AntigravityCLI.
# Claude Code does not enable it: its native file tools cover the same ground.
#
# stdout is the MCP channel — nothing but the server may write to it.
# =============================================================================
set -euo pipefail

ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

# A launcher-owned npm cache: ~/.npm can hold root-owned files after a
# `sudo npm …`, and then every npx dies with EACCES before the MCP handshake.
export npm_config_cache="${WAFFLE_MCP_NPM_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/waffle-commons/mcp-npm}"
export npm_config_update_notifier=false

exec npx --yes @modelcontextprotocol/server-filesystem@2026.8.31 "$ROOT"
