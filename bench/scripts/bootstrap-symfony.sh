#!/usr/bin/env bash
# =============================================================================
# bench/scripts/bootstrap-symfony.sh — generate the GITIGNORED Symfony baseline
# app (bench/engines/symfony-app/) used by BOTH engine B (php-fpm + nginx) and
# engine C (FrankenPHP worker). Idempotent: safe to re-run; re-running refreshes
# the tracked stubs and the prod install.
#
# All PHP/composer runs happen INSIDE the waffle-dev container (never on the
# host, per CLAUDE.md). The prod cache warmed here is a compile-validation only:
# the engine Dockerfiles rm + re-warm it at /app, because the dumped container
# hardcodes the project directory.
# =============================================================================
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_HOST_DIR="$BENCH_DIR/engines/symfony-app"
STUBS_DIR="$BENCH_DIR/scripts/stubs/app"
CONTAINER="waffle-dev"
ENGINES_IN_CONTAINER="/waffle-commons/bench/engines"
APP_IN_CONTAINER="$ENGINES_IN_CONTAINER/symfony-app"

# Symfony version: pinned to the 7.4 LTS line, NOT "latest stable" (8.1).
# Reason (verified 2026-08-02): runtime/frankenphp-symfony 1.0.0 — the official
# FrankenPHP worker runtime engine C depends on — requires
# symfony/dependency-injection ^5.4|^6.0|^7.0 and does not install against
# Symfony 8.x yet. 7.4 LTS is the current long-term-support production line,
# a fair "typical Symfony deployment" baseline. Recorded as a method note in
# BENCH-GATE-RESULT.md.
SYMFONY_LINE="7.4.*"

# Bench dependencies on top of symfony/skeleton:
#   doctrine/dbal + doctrine/doctrine-bundle  -> idiomatic DBAL connection wiring
#       (the bundle is what reads config/packages/doctrine.yaml -> DB_* env vars;
#        bare dbal alone has no container integration)
#   symfony/validator + symfony/serializer-pack -> #[MapRequestPayload] DTO
#   runtime/frankenphp-symfony               -> engine C worker runtime
BENCH_PACKAGES=(
    doctrine/dbal
    doctrine/doctrine-bundle
    symfony/validator
    symfony/serializer-pack
    runtime/frankenphp-symfony
)

step() { printf '\n==> %s\n' "$*"; }

in_app() { docker exec -w "$APP_IN_CONTAINER" "$CONTAINER" "$@"; }
in_app_prod() { docker exec -w "$APP_IN_CONTAINER" -e APP_ENV=prod -e APP_DEBUG=0 "$CONTAINER" "$@"; }

if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "ERROR: container '$CONTAINER' is not running (docker compose up in workspace/ first)." >&2
    exit 1
fi

mkdir -p "$BENCH_DIR/engines"

if [ ! -f "$APP_HOST_DIR/composer.json" ]; then
    step "composer create-project symfony/skeleton:$SYMFONY_LINE in waffle-dev"
    docker exec -w "$ENGINES_IN_CONTAINER" "$CONTAINER" \
        composer create-project "symfony/skeleton:$SYMFONY_LINE" symfony-app --no-interaction --no-progress
else
    step "symfony-app already present — skipping create-project (idempotent)"
fi

# --no-scripts: the doctrine-bundle recipe ships a doctrine.yaml with an orm:
# section, which makes the post-update cache:clear fail while doctrine/orm is
# (deliberately) absent. Our tracked stub overwrites that file right below;
# the prod composer install then runs the scripts against the fixed config.
step "composer require bench dependencies (--no-scripts, stubs fix the config)"
in_app composer require --no-interaction --no-progress --no-scripts "${BENCH_PACKAGES[@]}"

step "overlay tracked stubs (controllers, DTO, doctrine dbal config, .env.prod)"
cp -R "$STUBS_DIR/." "$APP_HOST_DIR/"

step "prod install: --no-dev --classmap-authoritative"
in_app_prod composer install --no-dev --classmap-authoritative --no-interaction --no-progress

step "warm prod cache (compile validation; engine images re-warm at /app)"
in_app_prod rm -rf var/cache/prod
in_app_prod php bin/console cache:warmup --env=prod --no-debug

step "resolved versions (record these in BENCH-GATE-RESULT.md)"
in_app composer show --no-interaction 2>/dev/null |
    grep -E '^(symfony/(framework-bundle|runtime|validator|serializer)|doctrine/(dbal|doctrine-bundle)|runtime/frankenphp-symfony)\s' || true

step "bootstrap done — build the engines next:"
echo "    docker compose -f $BENCH_DIR/docker-compose.bench.yml build engine-b engine-c"
