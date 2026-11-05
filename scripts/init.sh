#!/usr/bin/env bash
# =============================================================================
# scripts/init.sh — `wfl init`: from a fresh clone to a working checkout.
#
#   git clone git@github.com:waffle-commons/monorepo.git waffle-commons
#   cd waffle-commons && bin/wfl init
#
# Steps (each one skips what is already done, so a re-run is safe):
#   1. host prerequisites                 (scripts/doctor.sh --prereqs)
#   2. submodules: only the uninitialised ones. A checked-out submodule is never
#      touched, so a re-run cannot detach a pre-release branch. A submodule you
#      cannot read (the private academy) is skipped with a note.
#   3. the Docker dev stack               (docker compose up --build -d)
#   4. composer install in every component whose vendor/ is missing or stale
#   5. git hooks                          (scripts/install-git-hooks.sh)
#   6. `wfl` linked into ~/.local/bin
#   7. MCP servers warmed up              (scripts/mcp-check.sh)
#
# Usage:  wfl init [--https] [--skip-docker] [--skip-composer] [--skip-ai] [--no-link]
#   --https   clone submodules over HTTPS (automatic when no GitHub SSH key works)
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/workspace/docker-compose.yml"
CONTAINER="waffle-dev"
JOBS="${WFL_INIT_JOBS:-4}"

HTTPS=0; SKIP_DOCKER=0; SKIP_COMPOSER=0; SKIP_AI=0; NO_LINK=0
for arg in "$@"; do
  case "$arg" in
    --https)         HTTPS=1 ;;
    --skip-docker)   SKIP_DOCKER=1; SKIP_COMPOSER=1 ;;
    --skip-composer) SKIP_COMPOSER=1 ;;
    --skip-ai)       SKIP_AI=1 ;;
    --no-link)       NO_LINK=1 ;;
    -h|--help)       sed -n '2,22p' "$0"; exit 0 ;;
    *) printf 'init: unknown option %s (see: wfl init --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_CYA=$'\033[0;36m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_CYA=""; C_BLD=""; C_RST=""
fi
info() { printf '%s→ %s%s\n' "$C_CYA" "$*" "$C_RST"; }
ok()   { printf '%s✓ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s! %s%s\n' "$C_YEL" "$*" "$C_RST" >&2; NOTES+=("$*"); }
die()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; exit 1; }
step() { printf '\n%s%s═══ %s ═══%s\n' "$C_BLD" "$C_CYA" "$1" "$C_RST"; }

NOTES=()
started_at=$(date +%s)
cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"

# --- 1. prerequisites --------------------------------------------------------
step "1/7 Host prerequisites"
if ! "$REPO_ROOT/scripts/doctor.sh" --prereqs; then
  command -v git >/dev/null 2>&1 || die "git is required"
  if [ "$SKIP_DOCKER" -eq 0 ] && ! docker info >/dev/null 2>&1; then
    die "Docker is required (or re-run with --skip-docker)"
  fi
  warn "some prerequisites are missing (see above); continuing with what is there"
fi

# --- 2. submodules -----------------------------------------------------------
step "2/7 Submodules"
GIT_URL=()
if [ "$HTTPS" -eq 0 ]; then
  # GitHub's greeting exits 1 even when the key works: read its text, never its exit code
  # (and no pipe, so pipefail cannot turn a match into a failure).
  ssh_out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  case "$ssh_out" in
    *"successfully authenticated"*) : ;;
    *) HTTPS=1; info "no working GitHub SSH key: cloning over HTTPS" ;;
  esac
fi
if [ "$HTTPS" -eq 1 ]; then
  # Command-line config reaches the child clones (GIT_CONFIG_PARAMETERS); nothing is written to a config file.
  GIT_URL=(-c 'url.https://github.com/.insteadOf=git@github.com:')
fi

# A repository you cannot read fails at once instead of stopping at a username prompt.
# A credential helper that already holds a token (gh auth setup-git) still answers.
export GIT_TERMINAL_PROMPT=0

uninit=()
while IFS= read -r path; do
  [ -n "$path" ] && uninit+=("$path")
done < <(git submodule status | awk '/^-/ {print $2}')

if [ "${#uninit[@]}" -eq 0 ]; then
  ok "all $(git submodule status | grep -c .) submodules already initialised (left untouched)"
else
  info "initialising ${#uninit[@]} submodule(s): ${uninit[*]}"
  git ${GIT_URL[@]+"${GIT_URL[@]}"} submodule update --init --recursive --jobs "$JOBS" -- "${uninit[@]}" || true
  skipped=()
  for path in "${uninit[@]}"; do
    if git submodule status -- "$path" | grep -q '^-'; then
      # One more try on its own, so one unreadable repository cannot fail the others.
      git ${GIT_URL[@]+"${GIT_URL[@]}"} submodule update --init --recursive -- "$path" >/dev/null 2>&1 || true
      git submodule status -- "$path" | grep -q '^-' && skipped+=("$path")
    fi
  done
  if [ "${#skipped[@]}" -gt 0 ]; then
    warn "skipped (no access, or the network failed): ${skipped[*]} — the academy is private; everything else works without it"
  fi
  # One failed clone makes git abort before it checks the other new clones out at
  # their pinned commits, leaving them on the remote's default branch. Pin them now:
  # they were cloned by this run, so there is no local work to lose.
  unpinned=()
  for path in "${uninit[@]}"; do
    git submodule status -- "$path" | grep -q '^+' && unpinned+=("$path")
  done
  if [ "${#unpinned[@]}" -gt 0 ]; then
    git ${GIT_URL[@]+"${GIT_URL[@]}"} submodule update --recursive --jobs "$JOBS" -- "${unpinned[@]}" >/dev/null 2>&1 || true
    still=()
    for path in "${unpinned[@]}"; do
      git submodule status -- "$path" | grep -q '^+' && still+=("$path")
    done
    if [ "${#still[@]}" -gt 0 ]; then
      warn "not at the commit the umbrella pins (is the umbrella ahead of what was pushed?): ${still[*]}"
    fi
  fi
  ok "submodules ready"
  if [ "$HTTPS" -eq 1 ]; then
    info "to keep using HTTPS for fetches inside the submodules: git config --global url.https://github.com/.insteadOf git@github.com:"
  fi
fi

# --- 3. Docker dev stack ----------------------------------------------------
step "3/7 Docker dev stack"
if [ "$SKIP_DOCKER" -eq 1 ]; then
  info "skipped (--skip-docker)"
else
  [ -f "$COMPOSE_FILE" ] || die "compose file missing: $COMPOSE_FILE (is the workspace submodule checked out?)"
  info "building and starting the stack (the first build takes a few minutes)…"
  (cd "$REPO_ROOT/workspace" && docker compose -f "$COMPOSE_FILE" up --build -d) || die "docker compose up failed"
  for _ in $(seq 1 60); do
    [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)" = "running" ] && break
    sleep 2
  done
  [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)" = "running" ] \
    || die "$CONTAINER did not reach 'running' (docker compose -f $COMPOSE_FILE logs waffle)"
  ok "$CONTAINER running"
fi

# --- 4. composer install ----------------------------------------------------
step "4/7 Composer dependencies"
if [ "$SKIP_COMPOSER" -eq 1 ]; then
  info "skipped"
else
  todo=()
  while IFS= read -r comp; do
    case "$comp" in component-template|documentation|academy|workspace|"") continue ;; esac
    [ -f "$comp/composer.json" ] || continue
    if [ ! -f "$comp/vendor/autoload.php" ]; then
      todo+=("$comp")
    elif [ -f "$comp/composer.lock" ] && [ "$comp/composer.lock" -nt "$comp/vendor/composer/installed.json" ]; then
      todo+=("$comp")
    fi
  done < <("$REPO_ROOT/scripts/list-components.sh")

  if [ "${#todo[@]}" -eq 0 ]; then
    ok "every component already installed (left untouched)"
  else
    info "composer install in ${#todo[@]} component(s), $JOBS at a time: ${todo[*]}"
    logdir="$(mktemp -d "${TMPDIR:-/tmp}/wfl-init.XXXXXX")"
    failed=()
    running=0
    for comp in "${todo[@]}"; do
      ( docker exec -w "/waffle-commons/$comp" "$CONTAINER" composer install --no-interaction --no-progress \
          >"$logdir/$comp.log" 2>&1 && touch "$logdir/$comp.ok" ) &
      running=$((running + 1))
      if [ "$running" -ge "$JOBS" ]; then wait -n 2>/dev/null || wait; running=$((running - 1)); fi
    done
    wait
    for comp in "${todo[@]}"; do
      if [ -f "$logdir/$comp.ok" ]; then ok "$comp"; else failed+=("$comp"); fi
    done
    if [ "${#failed[@]}" -gt 0 ]; then
      warn "composer install failed in: ${failed[*]} (logs: $logdir)"
    else
      rm -rf "$logdir"
    fi
  fi
fi

# --- 5. git hooks -----------------------------------------------------------
step "5/7 Git hooks"
if [ -x "$REPO_ROOT/scripts/install-git-hooks.sh" ]; then
  "$REPO_ROOT/scripts/install-git-hooks.sh" >/dev/null && ok "pre-commit (mago) and pre-push hooks installed" \
    || warn "the git hook installer failed (run scripts/install-git-hooks.sh to see why)"
else
  warn "scripts/install-git-hooks.sh not found or not executable"
fi

# --- 6. wfl on PATH ---------------------------------------------------------
step "6/7 wfl on PATH"
if [ "$NO_LINK" -eq 1 ]; then
  info "skipped (--no-link)"
else
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$REPO_ROOT/bin/wfl" "$HOME/.local/bin/wfl"
  ok "~/.local/bin/wfl → $REPO_ROOT/bin/wfl"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) : ;;
    *) warn "\$HOME/.local/bin is not on \$PATH — add it to your shell rc to type 'wfl' anywhere" ;;
  esac
fi

# --- 7. AI layer ------------------------------------------------------------
step "7/7 AI layer"
if [ "$SKIP_AI" -eq 1 ]; then
  info "skipped (--skip-ai)"
else
  if [ "$SKIP_DOCKER" -eq 1 ]; then
    info "MCP warm-up skipped: the dev databases are not running (--skip-docker)"
  elif "$REPO_ROOT/scripts/mcp-check.sh"; then
    ok "MCP servers answer (images and packages pre-fetched for the first session)"
  else
    warn "an MCP server is not ready (see above); Claude Code works without it — fix it later with wfl mcp:check"
  fi
fi

# --- summary ----------------------------------------------------------------
elapsed=$(( $(date +%s) - started_at ))
printf '\n%s%s═══ Done in %dm%02ds ═══%s\n' "$C_BLD" "$C_CYA" $((elapsed / 60)) $((elapsed % 60)) "$C_RST"
if [ "${#NOTES[@]}" -gt 0 ]; then
  printf '%sTo look at:%s\n' "$C_YEL" "$C_RST"
  for note in "${NOTES[@]}"; do printf '  ! %s\n' "$note"; done
fi
cat <<EOF
Next:
  wfl doctor                 check everything again
  wfl dod contracts          prove one component green (mago + tests + coverage + igor)
  claude                     at the repository root; accept the trust prompt so the team
                             settings, the MCP servers and the repo plugins load
                             (run /reload-plugins once if the status band does not show)
EOF
