#!/usr/bin/env bash
# =============================================================================
# scripts/mcp-check.sh — verify the prerequisites the MCP servers depend on.
#
# Reports readiness for the MCP servers wired into the agentic operating layer
# (filesystem/postgres/mongo/redis/github/etc.). It is READ-ONLY: it never
# starts a server, a container, or a database — it only probes and reports.
#
# Checks:
#   • npx            — present (Node-based MCP servers are spawned via npx)
#   • docker         — present (container-backed servers / dev stack)
#   • postgres :5432 — reachable on localhost
#   • mongo    :27017 — reachable IF something is listening (optional)
#   • redis    :6379  — reachable IF something is listening (optional)
#   • GitHub token   — GITHUB_TOKEN set, or 'gh auth token' resolves
#
# Usage:   scripts/mcp-check.sh
# Exit:    0 if all REQUIRED prereqs are OK, 1 if any required one is MISSING.
#          (optional services that are simply down do NOT fail the check.)
# =============================================================================
set -uo pipefail

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_BLD=""; C_DIM=""; C_RST=""
fi

required_missing=0

_line_ok()   { printf '  %s✓ %-22s%s %s\n' "$C_GRN" "$1" "$C_RST" "${2:-OK}"; }
_line_miss() { printf '  %s✗ %-22s%s %s\n' "$C_RED" "$1" "$C_RST" "${2:-MISSING}"; }
_line_opt()  { printf '  %s○ %-22s%s %s\n' "$C_YEL" "$1" "$C_RST" "${2:-not up (optional)}"; }

# Probe a TCP port. Prefers /dev/tcp (bash builtin), falls back to nc.
_port_open() {
  local host="$1" port="$2"
  if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
    exec 3>&- 3<&- 2>/dev/null || true
    return 0
  fi
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 2 "$host" "$port" >/dev/null 2>&1 && return 0
  fi
  return 1
}

printf '%s%s═══ MCP prerequisites ═══%s\n' "$C_BLD" "$C_CYA" "$C_RST"

# --- required: npx --------------------------------------------------------
if command -v npx >/dev/null 2>&1; then
  _line_ok "npx" "$(npx --version 2>/dev/null || echo present)"
else
  _line_miss "npx" "install Node.js (npx spawns Node MCP servers)"
  required_missing=$((required_missing + 1))
fi

# --- required: docker -----------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    _line_ok "docker" "daemon reachable"
  else
    _line_miss "docker" "installed but daemon not reachable (start Docker Desktop)"
    required_missing=$((required_missing + 1))
  fi
else
  _line_miss "docker" "not on PATH"
  required_missing=$((required_missing + 1))
fi

# --- required: postgres :5432 --------------------------------------------
if _port_open localhost 5432; then
  _line_ok "postgres :5432" "reachable on localhost"
else
  _line_miss "postgres :5432" "not reachable (start the dev stack: wfl up)"
  required_missing=$((required_missing + 1))
fi

# --- optional: mongo :27017 ----------------------------------------------
if _port_open localhost 27017; then
  _line_ok "mongo :27017" "reachable on localhost"
else
  _line_opt "mongo :27017"
fi

# --- optional: redis :6379 -----------------------------------------------
if _port_open localhost 6379; then
  _line_ok "redis :6379" "reachable on localhost"
else
  _line_opt "redis :6379"
fi

# --- required: GitHub token ----------------------------------------------
if [ -n "${GITHUB_TOKEN:-}" ]; then
  _line_ok "GitHub token" "GITHUB_TOKEN set"
elif command -v gh >/dev/null 2>&1 && gh auth token >/dev/null 2>&1; then
  _line_ok "GitHub token" "via 'gh auth token'"
else
  _line_miss "GitHub token" "set GITHUB_TOKEN or run 'gh auth login'"
  required_missing=$((required_missing + 1))
fi

printf '%s%s─────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$required_missing" -eq 0 ]; then
  printf '%s✓ all required MCP prerequisites present%s\n' "$C_GRN" "$C_RST"
  exit 0
fi
printf '%s✗ %d required MCP prerequisite(s) MISSING%s\n' "$C_RED" "$required_missing" "$C_RST" >&2
exit 1
