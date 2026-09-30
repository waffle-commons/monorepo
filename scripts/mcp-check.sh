#!/usr/bin/env bash
# =============================================================================
# scripts/mcp-check.sh — prove the MCP servers actually work.
#
# Checking prerequisites is not enough: a server can have every prerequisite
# and still die before the handshake (e.g. root-owned files in ~/.npm), or
# complete the handshake while every call fails (e.g. GitHub with an empty
# token). So this script:
#
#   1. checks the prerequisites (docker, node/npx, python3, dev DB ports, a
#      GitHub token that the API actually accepts);
#   2. checks the wiring (every configured server points at a launcher in
#      scripts/mcp/, no personal absolute path in a tracked config);
#   3. opens a REAL stdio MCP session with every launcher in scripts/mcp/
#      (initialize → tools/list → one read-only tool call).
#
# The first run also warms the launchers' npm cache and pulls the images, so
# the next agent session connects within its startup timeout.
#
# Usage:   scripts/mcp-check.sh [--quick]     (--quick = steps 1–2 only)
# Env:     MCP_CHECK_TIMEOUT=180  per-server session budget, seconds
# Exit:    0 when everything passes, 1 when anything fails. Warnings (an old
#          Node, a damaged ~/.npm) are reported but do not fail the check.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE="$REPO_ROOT/scripts/mcp/probe.py"
TIMEOUT="${MCP_CHECK_TIMEOUT:-180}"
QUICK=0
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=1 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) printf 'mcp-check: unknown option %s\n' "$arg" >&2; exit 2 ;;
  esac
done

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_BLD=""; C_DIM=""; C_RST=""
fi

fails=0
warns=0
_ok()   { printf '  %s✓ %-24s%s %s\n' "$C_GRN" "$1" "$C_RST" "${2:-}"; }
_fail() { printf '  %s✗ %-24s%s %s\n' "$C_RED" "$1" "$C_RST" "${2:-}"; fails=$((fails + 1)); }
_warn() { printf '  %s! %-24s%s %s\n' "$C_YEL" "$1" "$C_RST" "${2:-}"; warns=$((warns + 1)); }
_head() { printf '%s%s═══ %s ═══%s\n' "$C_BLD" "$C_CYA" "$1" "$C_RST"; }

# Probe a TCP port: bash /dev/tcp first, nc as a fallback.
_port_open() {
  if (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null; then return 0; fi
  command -v nc >/dev/null 2>&1 && nc -z -w 2 "$1" "$2" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
_head "Prerequisites"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  _ok "docker" "daemon reachable"
else
  _fail "docker" "not on PATH or daemon down (start Docker Desktop)"
fi

if command -v python3 >/dev/null 2>&1; then
  _ok "python3" "$(python3 --version 2>&1)"
else
  _fail "python3" "required by scripts/mcp/probe.py"
fi

if command -v node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
  node_v="$(node --version 2>/dev/null)"
  node_major="${node_v#v}"; node_major="${node_major%%.*}"
  if [ "${node_major:-0}" -lt 18 ]; then
    _fail "node / npx" "$node_v is too old for the npx launchers (need >= 18)"
  elif [ "$node_major" -lt 22 ]; then
    _warn "node / npx" "$node_v works, but is end-of-life — upgrade to Node 22 or 24 LTS"
  else
    _ok "node / npx" "$node_v"
  fi
else
  _fail "node / npx" "install Node.js 22+ (postgres/filesystem launchers use npx)"
fi

if [ -d "$HOME/.npm" ] && [ -n "$(find "$HOME/.npm" -user 0 -print -quit 2>/dev/null)" ]; then
  n_root="$(find "$HOME/.npm" -user 0 2>/dev/null | wc -l | tr -d ' ')"
  _warn "npm cache ownership" "$n_root root-owned file(s): the launchers use their own cache, but any other npx fails — sudo chown -R $(id -u):$(id -g) \"$HOME/.npm\""
else
  _ok "npm cache ownership" "no root-owned files"
fi

for svc in "postgres:5432" "mongo:27017" "redis:6379"; do
  name="${svc%%:*}"; port="${svc##*:}"
  if _port_open localhost "$port"; then
    _ok "$name :$port" "reachable"
  else
    _fail "$name :$port" "not reachable — start the dev stack (wfl up)"
  fi
done

token="${GITHUB_TOKEN:-${GITHUB_PERSONAL_ACCESS_TOKEN:-}}"
token_src="GITHUB_TOKEN"
[ -z "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && token_src="GITHUB_PERSONAL_ACCESS_TOKEN"
if [ -z "$token" ] && command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"; token_src="gh keyring"
fi
if [ -z "$token" ]; then
  _fail "GitHub token" "none — export GITHUB_TOKEN or run 'gh auth login'"
else
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" https://api.github.com/user 2>/dev/null || echo 000)"
  case "$code" in
    200) _ok "GitHub token" "accepted by the API (from $token_src)" ;;
    401) _fail "GitHub token" "rejected (401) — from $token_src; refresh it (gh auth login)" ;;
    *)   _fail "GitHub token" "API check returned HTTP $code (network?)" ;;
  esac
fi
unset token

# ---------------------------------------------------------------------------
_head "Wiring"

# Every server declared for Claude Code / opencode must go through a launcher
# that exists, and no tracked config may carry a personal absolute path.
if command -v python3 >/dev/null 2>&1; then
  wiring="$(cd "$REPO_ROOT" && python3 - <<'PY'
import json, os
problems, notes = [], []
def check(label, servers, get_cmd):
    for name, spec in servers.items():
        argv = get_cmd(spec)
        launcher = next((a for a in argv if a.startswith("scripts/mcp/")), None)
        if launcher is None:
            problems.append(f"{label}: '{name}' does not use a scripts/mcp/ launcher")
        elif not os.path.isfile(launcher):
            problems.append(f"{label}: '{name}' → missing {launcher}")
        else:
            notes.append(f"{label}: {name}")
        if any(a.startswith("/Users/") or a.startswith("/home/") for a in argv):
            problems.append(f"{label}: '{name}' embeds a personal absolute path")
try:
    mcp = json.load(open(".mcp.json"))["mcpServers"]
    check(".mcp.json", mcp, lambda s: [s.get("command", "")] + s.get("args", []))
except Exception as e:
    problems.append(f".mcp.json unreadable: {e}")
try:
    oc = json.load(open("opencode.json")).get("mcp", {})
    check("opencode.json", oc, lambda s: s.get("command", []))
except Exception as e:
    problems.append(f"opencode.json unreadable: {e}")
for p in problems: print("FAIL " + p)
print("OK " + ", ".join(notes))
PY
)"
  while IFS= read -r line; do
    case "$line" in
      FAIL*) _fail "config" "${line#FAIL }" ;;
      OK*)   _ok "config" "${line#OK }" ;;
    esac
  done <<< "$wiring"
fi

# ---------------------------------------------------------------------------
if [ "$QUICK" -eq 0 ]; then
  _head "MCP sessions (handshake + one read-only call)"
  # launcher → read-only smoke tool (and its JSON arguments)
  for entry in \
      "postgres|pg_monitor_database|{}" \
      "mongo|list-connections|{}" \
      "redis|dbsize|{}" \
      "github|get_me|{}" \
      "filesystem|list_allowed_directories|{}"; do
    name="${entry%%|*}"; rest="${entry#*|}"; tool="${rest%%|*}"; args="${rest#*|}"
    launcher="$REPO_ROOT/scripts/mcp/$name.sh"
    if [ ! -f "$launcher" ]; then
      _fail "$name" "launcher scripts/mcp/$name.sh missing"
      continue
    fi
    out="$(cd "$REPO_ROOT" && python3 "$PROBE" --timeout "$TIMEOUT" --call "$tool" --call-args "$args" -- bash "scripts/mcp/$name.sh" 2>&1)"
    first="$(printf '%s\n' "$out" | head -n 1)"
    if [ "${first%% *}" = "OK" ]; then
      _ok "$name" "${first#OK }"
    else
      _fail "$name" "${first#FAIL }"
      printf '%s\n' "$out" | tail -n +2 | sed "s/^/${C_DIM}/;s/\$/${C_RST}/"
    fi
  done
fi

printf '%s%s─────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$fails" -eq 0 ]; then
  printf '%s✓ MCP check passed%s%s\n' "$C_GRN" "$([ "$warns" -gt 0 ] && printf ' (%d warning(s))' "$warns")" "$C_RST"
  exit 0
fi
printf '%s✗ MCP check FAILED — %d problem(s)%s\n' "$C_RED" "$fails" "$C_RST" >&2
exit 1
