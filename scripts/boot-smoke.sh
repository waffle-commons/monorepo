#!/usr/bin/env bash
# boot-smoke — verify a template app's kernel boots without HTTP. Runs the app's
# dedicated Boot/Smoke test (workspace KernelBootTest / skeleton BootTest), which
# drives AppKernelFactory::create()->boot()->configure() (the dev strict-compliance
# scan proves every registered service is resettable) + handles a synthetic PSR-7
# request. The recurrent demo-wiring verification, contained in one command.
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${WFL_CONTAINER:-waffle-dev}"

APP="${1:-}"
case "$APP" in
  workspace | skeleton) ;;
  *) echo "usage: wfl boot-smoke <workspace|skeleton>" >&2; exit 2 ;;
esac

docker inspect "$CONTAINER" >/dev/null 2>&1 || { echo "dev container '$CONTAINER' not running — run 'wfl up'" >&2; exit 1; }

# --filter Boot matches KernelBootTest / BootTest / *Boot* — the app's boot smoke test.
echo "→ boot smoke test for '$APP' (kernel create → boot → configure → handle)…"
exec docker exec -w "/waffle-commons/$APP" "$CONTAINER" vendor/bin/phpunit --no-coverage --filter 'Boot'
