#!/usr/bin/env bash
# =============================================================================
# scripts/mcp/postgres.sh — stdio launcher for the PostgreSQL MCP server.
#
# Target: the workspace dev database (waffle-postgres, host port 5432).
# Override the DSN with WAFFLE_PG_DSN. The package version is pinned: npx never
# pulls an unreviewed "latest" at session start.
#
# stdout is the MCP channel — nothing but the server may write to it.
# =============================================================================
set -euo pipefail

# A launcher-owned npm cache: ~/.npm can hold root-owned files after a
# `sudo npm …`, and then every npx dies with EACCES before the MCP handshake.
export npm_config_cache="${WAFFLE_MCP_NPM_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/waffle-commons/mcp-npm}"
export npm_config_update_notifier=false

exec npx --yes @henkey/postgres-mcp-server@1.0.7 \
  --connection-string "${WAFFLE_PG_DSN:-postgresql://waffle:waffle@localhost:5432/waffle}"
