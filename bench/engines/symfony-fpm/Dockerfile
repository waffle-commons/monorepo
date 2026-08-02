# syntax=docker/dockerfile:1
# =============================================================================
# Engine B — the shared Symfony baseline app on the CLASSIC runtime:
# php:8.5-fpm + nginx, in ONE container.
#
# Build context = bench/ root (so the gitignored generated app is COPY-able):
#   docker build -f engines/symfony-fpm/Dockerfile -t bench-engine-b .
# Prerequisite: scripts/bootstrap-symfony.sh has generated engines/symfony-app/.
#
# Single-container choice (vs nginx sidecar) is DELIBERATE: the compose resource
# pinning (cpus: "2", mem_limit: 1g) then bounds the WHOLE engine, exactly like
# the single-process FrankenPHP engines A and C — a sidecar would let nginx
# escape the shared budget and skew the RAM-factor comparison.
# =============================================================================
FROM php:8.5-fpm

# `intl` is deliberately NOT installed: no bench workload touches it (the five
# routes are JSON + DBAL), its C++ compile is the single slowest build step, and
# it is not on any hot path — so its absence cannot bias the comparison. What
# MUST match across engines is the runtime that actually shapes throughput:
# PHP 8.5, opcache with validate_timestamps=0, and the identical JIT settings
# in zz-bench.ini.
#
# opcache is NOT installed here: in php:8.5 it is compiled statically into the
# binary (`php -m` already lists "Zend OPcache"), so `docker-php-ext-install
# opcache` finds no shared module to copy and dies with
# "cp: cannot stat 'modules/*'". The engine still gets the identical opcache/JIT
# tuning via zz-bench.ini below — only the redundant build step is gone.
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# JIT/opcache parity (same values as engines A and C) + FPM static pool sizing.
COPY engines/symfony-fpm/zz-bench.ini /usr/local/etc/php/conf.d/zz-bench.ini
COPY engines/symfony-fpm/zzz-bench-pool.conf /usr/local/etc/php-fpm.d/zzz-bench-pool.conf
COPY engines/symfony-fpm/nginx.conf /etc/nginx/nginx.conf
COPY engines/symfony-fpm/start.sh /usr/local/bin/engine-start
RUN chmod +x /usr/local/bin/engine-start

# Fairness pinning env + DB defaults (compose values take precedence).
ENV APP_ENV=prod \
    APP_DEBUG=0 \
    DB_HOST=bench-postgres \
    DB_PORT=5432 \
    DB_NAME=waffle \
    DB_USER=waffle \
    DB_PASSWORD=waffle

WORKDIR /app
COPY engines/symfony-app/ /app/

# Re-warm the prod cache HERE: the container dumped by bootstrap-symfony.sh
# inside waffle-dev hardcodes /waffle-commons/... as project dir; the runtime
# path is /app, so a stale copied cache would be silently wrong in prod
# (debug=false never freshness-checks).
RUN rm -rf var/cache var/log \
    && mkdir -p var/cache var/log \
    && php bin/console cache:warmup --env=prod --no-debug \
    && chown -R www-data:www-data var

EXPOSE 80
CMD ["engine-start"]
