# syntax=docker/dockerfile:1
# =============================================================================
# Engine C — the SAME Symfony baseline app as engine B, on the FrankenPHP
# worker runtime (runtime/frankenphp-symfony). B-vs-C isolates the runtime
# (framework held constant); A-vs-C isolates the framework (runtime constant).
#
# Base tag matches skeleton/docker/Dockerfile exactly (engine A parity):
# FrankenPHP 1.12.2 / PHP 8.5 / trixie.
#
# Build context = bench/ root:
#   docker build -f engines/symfony-worker/Dockerfile -t bench-engine-c .
# Prerequisite: scripts/bootstrap-symfony.sh has generated engines/symfony-app/.
# =============================================================================
FROM dunglas/frankenphp:1.12.2-php8-trixie

# `intl` deliberately omitted — see the rationale in engines/symfony-fpm/Dockerfile:
# unused by every bench workload, slowest build step, not on any hot path. Engine B
# and Engine C stay extension-identical to each other, which is what the
# B-vs-C runtime comparison requires.
RUN install-php-extensions pdo_pgsql opcache

COPY engines/symfony-worker/Caddyfile /etc/caddy/Caddyfile
# JIT/opcache parity (same values as engines A and B).
COPY engines/symfony-worker/zz-bench.ini $PHP_INI_DIR/conf.d/zz-bench.ini

# APP_RUNTIME selects the FrankenPHP Symfony runtime (worker entrypoint is the
# regular public/index.php — the runtime package's loop takes over when running
# under frankenphp). Worker count PINNED to 4, parity with engine A's num 4.
ENV APP_ENV=prod \
    APP_DEBUG=0 \
    SERVER_NAME=":80" \
    APP_RUNTIME="Runtime\\FrankenPhpSymfony\\Runtime" \
    FRANKENPHP_CONFIG="worker ./public/index.php 4" \
    DB_HOST=bench-postgres \
    DB_PORT=5432 \
    DB_NAME=waffle \
    DB_USER=waffle \
    DB_PASSWORD=waffle

WORKDIR /app
COPY engines/symfony-app/ /app/

# Re-warm the prod cache at the runtime path (see engine B Dockerfile note:
# the bootstrap-warmed cache hardcodes the waffle-dev project dir).
RUN rm -rf var/cache var/log \
    && mkdir -p var/cache var/log \
    && php bin/console cache:warmup --env=prod --no-debug

EXPOSE 80
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
