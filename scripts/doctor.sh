#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh — `wfl doctor`: is this machine and this checkout ready?
#
# Read-only. Every check prints ✓ (ready), ! (works, but something is missing
# or degraded) or ✗ (a blocker), with the command that fixes it. Exits 1 when
# any blocker is found, 0 otherwise.
#
# Usage:   scripts/doctor.sh [--prereqs]     (--prereqs = host checks only)
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="waffle-dev"
PREREQS_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --prereqs) PREREQS_ONLY=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) printf 'doctor: unknown option %s\n' "$arg" >&2; exit 2 ;;
  esac
done

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_BLD=""; C_RST=""
fi

blockers=0
warns=0
_ok()   { printf '  %s✓ %-22s%s %s\n' "$C_GRN" "$1" "$C_RST" "${2:-}"; }
_warn() { printf '  %s! %-22s%s %s\n' "$C_YEL" "$1" "$C_RST" "${2:-}"; warns=$((warns + 1)); }
_fail() { printf '  %s✗ %-22s%s %s\n' "$C_RED" "$1" "$C_RST" "${2:-}"; blockers=$((blockers + 1)); }
_head() { printf '%s%s═══ %s ═══%s\n' "$C_BLD" "$C_CYA" "$1" "$C_RST"; }

# version_ge A B: true when version A >= version B (numeric dotted compare).
version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]
}

_port_busy() {
  if (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; then return 0; fi
  command -v nc >/dev/null 2>&1 && nc -z -w 1 127.0.0.1 "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
_head "Host"

if command -v git >/dev/null 2>&1; then
  git_v="$(git --version | awk '{print $3}')"
  if version_ge "$git_v" "2.30.0"; then _ok "git" "$git_v"; else _fail "git" "$git_v is too old (need >= 2.30)"; fi
else
  _fail "git" "not installed"
fi

container_state="absent"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    _ok "docker" "daemon reachable"
    container_state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || printf 'absent')"
    if docker compose version >/dev/null 2>&1; then
      _ok "docker compose" "$(docker compose version --short 2>/dev/null)"
    else
      _fail "docker compose" "the v2 plugin is missing (docker compose …)"
    fi
  else
    _fail "docker" "daemon not reachable — start Docker Desktop"
  fi
else
  _fail "docker" "not installed (https://docs.docker.com/get-docker/)"
fi

if [ "$container_state" != "running" ]; then
  busy=""
  for port in 8080 8443 8090 5432 6379 27017; do
    _port_busy "$port" && busy="$busy $port"
  done
  if [ -n "$busy" ]; then
    _warn "dev ports" "in use by something else:$busy — the dev stack needs them"
  else
    _ok "dev ports" "8080 8443 8090 5432 6379 27017 free"
  fi
fi

# GitHub's greeting exits 1 even when the key works: match its text, not its exit code.
ssh_out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
case "$ssh_out" in
  *"successfully authenticated"*) _ok "GitHub SSH" "authenticated" ;;
  *) _warn "GitHub SSH" "no working key — wfl init clones over HTTPS instead (or add a key: https://docs.github.com/authentication/connecting-to-github-with-ssh)" ;;
esac

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then _ok "gh" "logged in"; else _warn "gh" "not logged in — gh auth login (the GitHub MCP server uses it)"; fi
else
  _warn "gh" "not installed — only needed for the GitHub MCP server (https://cli.github.com)"
fi

if command -v node >/dev/null 2>&1; then
  node_v="$(node --version | tr -d v)"
  if version_ge "$node_v" "20.19.0"; then _ok "node" "$node_v"; else _warn "node" "$node_v — the postgres MCP launcher wants >= 20.19 (Node 22/24 LTS)"; fi
else
  _warn "node" "not installed — only needed for the postgres MCP server"
fi

if command -v python3 >/dev/null 2>&1; then
  _ok "python3" "$(python3 --version 2>&1 | awk '{print $2}')"
else
  _warn "python3" "not installed — wfl mcp:check and wfl ai:check need it"
fi

if command -v claude >/dev/null 2>&1; then
  claude_v="$(claude --version 2>/dev/null | awk '{print $1}')"
  if version_ge "$claude_v" "2.1.287"; then
    _ok "claude" "$claude_v"
  else
    _warn "claude" "$claude_v — the waffle-cockpit mod needs >= 2.1.287 (claude update)"
  fi
else
  _warn "claude" "Claude Code not installed (https://code.claude.com/docs/en/setup)"
fi

if [ "$PREREQS_ONLY" -eq 1 ]; then
  printf '%s%s─────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
  [ "$blockers" -eq 0 ] && exit 0 || exit 1
fi

# ---------------------------------------------------------------------------
_head "Checkout"

cd "$REPO_ROOT" || exit 1
uninit="$(git submodule status 2>/dev/null | awk '/^-/ {print $2}' | tr '\n' ' ')"
total="$(git submodule status 2>/dev/null | grep -c . || true)"
if [ -z "$uninit" ]; then
  _ok "submodules" "$total initialised"
else
  _warn "submodules" "not initialised: ${uninit% } — wfl init (a private one you cannot read stays empty)"
fi

case "$container_state" in
  running) _ok "$CONTAINER" "running" ;;
  absent)  _warn "$CONTAINER" "not created — wfl init (or wfl up)" ;;
  *)       _warn "$CONTAINER" "$container_state — wfl up" ;;
esac

missing=""
while IFS= read -r comp; do
  case "$comp" in component-template|documentation|academy|workspace|"") continue ;; esac
  [ -f "$comp/composer.json" ] || continue
  [ -f "$comp/vendor/autoload.php" ] || missing="$missing $comp"
done < <("$REPO_ROOT/scripts/list-components.sh" 2>/dev/null)
if [ -z "$missing" ]; then
  _ok "vendor/" "every component installed"
else
  _warn "vendor/" "missing in:$missing — wfl init (composer install in the container)"
fi

hooks_dir="$(git rev-parse --git-path hooks 2>/dev/null)"
if [ -n "$hooks_dir" ] && grep -q 'BEGIN WAFFLE PRE-COMMIT HOOK' "$hooks_dir/pre-commit" 2>/dev/null; then
  _ok "git hooks" "installed"
else
  _warn "git hooks" "not installed — scripts/install-git-hooks.sh"
fi

wfl_path="$(command -v wfl 2>/dev/null || true)"
if [ -n "$wfl_path" ] && [ "$(cd -P -- "$(dirname -- "$(readlink "$wfl_path" 2>/dev/null || printf '%s' "$wfl_path")")" 2>/dev/null && pwd)" = "$REPO_ROOT/bin" ]; then
  _ok "wfl on PATH" "$wfl_path"
elif [ -n "$wfl_path" ]; then
  _warn "wfl on PATH" "$wfl_path points at another checkout — wfl init relinks it"
else
  _warn "wfl on PATH" "not found — wfl init links it into ~/.local/bin (add that to PATH)"
fi

# ---------------------------------------------------------------------------
_head "AI layer"

if [ -f .claude/settings.json ] && git ls-files --error-unmatch .claude/settings.json >/dev/null 2>&1; then
  _ok "team settings" ".claude/settings.json is tracked"
elif [ -f .claude/settings.json ]; then
  _warn "team settings" ".claude/settings.json exists but is not tracked yet"
else
  _warn "team settings" ".claude/settings.json is missing"
fi

if [ -d .claude/skills ] && [ ! -L .claude/skills ] && [ -d .claude/agents ] && [ ! -L .claude/agents ]; then
  _ok "skills & agents" "$(find .claude/skills -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ') skills, $(find .claude/agents -maxdepth 1 -name '*.md' | wc -l | tr -d ' ') agents"
else
  _warn "skills & agents" ".claude/skills or .claude/agents is missing or a symlink"
fi

if [ -f .claude-plugin/marketplace.json ]; then
  _ok "repo marketplace" "waffle-cockpit, mattpocock-skills (load after the trust prompt)"
else
  _warn "repo marketplace" ".claude-plugin/marketplace.json is missing"
fi

printf '%s%s─────────────────────────%s\n' "$C_BLD" "$C_CYA" "$C_RST"
if [ "$blockers" -gt 0 ]; then
  printf '%s✗ %d blocker(s), %d warning(s)%s\n' "$C_RED" "$blockers" "$warns" "$C_RST" >&2
  exit 1
fi
printf '%s✓ ready%s%s\n' "$C_GRN" "$([ "$warns" -gt 0 ] && printf ' (%d warning(s))' "$warns")" "$C_RST"
exit 0
