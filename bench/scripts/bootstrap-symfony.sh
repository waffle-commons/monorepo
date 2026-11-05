#!/usr/bin/env bash
# =============================================================================
# bench/scripts/bootstrap-symfony.sh — generate the GITIGNORED Symfony baseline
# app (bench/engines/symfony-app/) used by BOTH engine B (php-fpm + nginx) and
# engine C (FrankenPHP worker), then derive from it the equivalent-features app
# (bench/engines/symfony-app-secured/) for engine D. Idempotent: safe to re-run;
# re-running refreshes the tracked stubs and the prod installs.
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
# 7.4 LTS is the current long-term-support production line, a fair "typical
# Symfony deployment" baseline, and the line the beta6 numbers were measured
# on: the CARRY-02 re-run changes Engine C's runner, not the framework version
# as well. (The first reason, runtime/frankenphp-symfony 1.0.0 not installing
# against Symfony 8, left with that package: 7.4 ships the native
# FrankenPhpWorkerRunner.) Recorded as a method note in BENCH-GATE-RESULT.md.
SYMFONY_LINE="7.4.*"

# Bench dependencies on top of symfony/skeleton:
#   doctrine/dbal + doctrine/doctrine-bundle  -> idiomatic DBAL connection wiring
#       (the bundle is what reads config/packages/doctrine.yaml -> DB_* env vars;
#        bare dbal alone has no container integration)
#   symfony/validator + symfony/serializer-pack -> #[MapRequestPayload] DTO
# Engine C needs no runtime package: symfony/runtime (part of symfony/skeleton)
# has shipped the native FrankenPhpWorkerRunner since 7.4.
BENCH_PACKAGES=(
    doctrine/dbal
    doctrine/doctrine-bundle
    symfony/validator
    symfony/serializer-pack
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

# Apps bootstrapped before CARRY-02 still carry the bridge Engine C was forced
# through (APP_RUNTIME); remove it so nothing can select it again.
if grep -q '"runtime/frankenphp-symfony"' "$APP_HOST_DIR/composer.json"; then
    step "composer remove runtime/frankenphp-symfony (Engine C uses the native runner)"
    in_app composer remove --no-interaction --no-progress --no-scripts runtime/frankenphp-symfony
fi

step "overlay tracked stubs (controllers, DTO, doctrine dbal config, .env.prod)"
cp -R "$STUBS_DIR/." "$APP_HOST_DIR/"

step "prod install: --no-dev --classmap-authoritative"
in_app_prod composer install --no-dev --classmap-authoritative --no-interaction --no-progress

step "warm prod cache (compile validation; engine images re-warm at /app)"
in_app_prod rm -rf var/cache/prod
in_app_prod php bin/console cache:warmup --env=prod --no-debug

step "resolved versions (record these in BENCH-GATE-RESULT.md)"
in_app composer show --no-interaction 2>/dev/null |
    grep -E '^(symfony/(framework-bundle|runtime|validator|serializer)|doctrine/(dbal|doctrine-bundle))\s' || true

# -----------------------------------------------------------------------------
# Engine D — the equivalent-features app (CARRY-02): the bare app plus
# SecurityBundle. It is derived from the bare app's lock, so every package the
# two share stays at the same version and only the security packages are new;
# its tracked stubs then add what mirrors Engine A's pipeline (bench/README.md).
# -----------------------------------------------------------------------------
SECURED_HOST_DIR="$BENCH_DIR/engines/symfony-app-secured"
SECURED_STUBS_DIR="$BENCH_DIR/scripts/stubs/app-secured"
SECURED_IN_CONTAINER="$ENGINES_IN_CONTAINER/symfony-app-secured"

in_secured() { docker exec -w "$SECURED_IN_CONTAINER" "$CONTAINER" "$@"; }
in_secured_prod() { docker exec -w "$SECURED_IN_CONTAINER" -e APP_ENV=prod -e APP_DEBUG=0 "$CONTAINER" "$@"; }

step "derive the equivalent-features app from the bare app (its vendor and var kept)"
mkdir -p "$SECURED_HOST_DIR"
rsync -a --delete --exclude /vendor/ --exclude /var/ --exclude /.git/ "$APP_HOST_DIR/" "$SECURED_HOST_DIR/"

# The bundle's own dependencies are named too: their ranges reach Symfony 8
# and Flex's extra.symfony.require did not hold them to the line (verified
# 2026-10-22: security-core, security-csrf, password-hasher and clock came in at
# 8.1). The line check below fails the bootstrap if one slips again.
SECURITY_PACKAGES=(
    "symfony/security-bundle:$SYMFONY_LINE"
    "symfony/security-core:$SYMFONY_LINE"
    "symfony/security-http:$SYMFONY_LINE"
    "symfony/security-csrf:$SYMFONY_LINE"
    "symfony/password-hasher:$SYMFONY_LINE"
    "symfony/clock:$SYMFONY_LINE"
)
step "composer require the security bundle on $SYMFONY_LINE (the shared packages stay locked)"
in_secured composer require --no-interaction --no-progress --no-scripts "${SECURITY_PACKAGES[@]}"

step "overlay Engine D's tracked stubs (security, CSRF, CORS, headers, transaction)"
cp -R "$SECURED_STUBS_DIR/." "$SECURED_HOST_DIR/"

step "prod install of the equivalent-features app"
in_secured_prod composer install --no-dev --classmap-authoritative --no-interaction --no-progress

step "warm its prod cache (compile validation)"
in_secured_prod rm -rf var/cache/prod
in_secured_prod php bin/console cache:warmup --env=prod --no-debug

step "check both locks: shared packages identical, every Symfony component on $SYMFONY_LINE"
docker exec -w "$ENGINES_IN_CONTAINER" "$CONTAINER" php -r '
    $versions = static function (string $lock): array {
        $data = json_decode((string) file_get_contents($lock), true, 512, JSON_THROW_ON_ERROR);
        return array_column($data["packages"], "version", "name");
    };
    $bare = $versions("symfony-app/composer.lock");
    $secured = $versions("symfony-app-secured/composer.lock");
    $drift = [];
    foreach ($bare as $name => $version) {
        if (($secured[$name] ?? null) !== $version) {
            $drift[] = sprintf("%s: %s (bare) vs %s (secured)", $name, $version, $secured[$name] ?? "absent");
        }
    }
    // Contracts, polyfills and Flex have their own version lines.
    $line = rtrim($argv[1], "*");
    foreach ($secured as $name => $version) {
        $component = str_starts_with($name, "symfony/") && !str_ends_with($name, "-contracts")
            && !str_starts_with($name, "symfony/polyfill-") && $name !== "symfony/flex";
        if ($component && !str_starts_with(ltrim($version, "v"), $line)) {
            $drift[] = sprintf("%s: %s is off the %s line", $name, $version, $argv[1]);
        }
    }
    if ($drift !== []) {
        fwrite(STDERR, "ERROR: the Symfony app locks fail the bench rules:\n  " . implode("\n  ", $drift) . "\n");
        exit(1);
    }
    printf("%d shared packages at identical versions, %d added by the security bundle\n", count($bare), count($secured) - count($bare));
' "$SYMFONY_LINE"
in_secured composer show --no-interaction 2>/dev/null | grep -E '^symfony/(security-(bundle|core|http|csrf)|password-hasher|clock)\s' || true

step "bootstrap done — build the engines next:"
echo "    docker compose -f $BENCH_DIR/docker-compose.bench.yml build engine-b engine-c engine-d"
