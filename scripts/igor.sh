#!/usr/bin/env bash
# =============================================================================
# scripts/igor.sh — thin shim to the canonical Igor-PHP scanner at the repo
# root (kept beside coverage.sh / loop.sh / zip-project.sh).
#
# The root script dynamically discovers every component whose composer.json
# declares "igor-php/igor-php" and honors each component's own igor.json.
# All flags are forwarded verbatim — see `./igor.sh --help`.
# =============================================================================
exec "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/igor.sh" "$@"
