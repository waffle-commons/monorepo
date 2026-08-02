# syntax=docker/dockerfile:1
# =============================================================================
# Engine A — Waffle on the FrankenPHP worker runtime (the benchmark SUBJECT).
#
# Build context = MONOREPO ROOT (not bench/), because this image needs both the
# skeleton app and the 20 component working trees:
#   docker compose -f bench/docker-compose.bench.yml build engine-a
#
# WHY THIS FILE EXISTS INSTEAD OF `target: prod` ON skeleton/docker/Dockerfile
# ---------------------------------------------------------------------------
# skeleton's own prod build resolves `waffle-commons/*` from Packagist through
# composer.lock — i.e. the RELEASED 0.1.0-beta5 packages. The skeleton source in
# this working tree already calls beta6 APIs that are not released yet (e.g.
# `new GlobalsFactory(uploadBaseDir: …)`, the SEC-03 upload-containment fix), so
# that image boots straight into
#   PHP Fatal error: Unknown named parameter $uploadBaseDir
# and every worker dies before reaching frankenphp_handle_request().
#
# Benchmarking the released beta5 would also measure the WRONG code: the whole
# point of AXE 5 is to publish numbers for the beta6 framework. So the builder
# below performs skeleton's real prod install (correct --no-dev tree, real
# autoloader) and then OVERLAYS each vendored component's `src/` with the
# monorepo working tree before dumping a classmap-authoritative autoloader —
# the same "vendor skew" remedy `wfl sync:demos` applies on the host, done
# hermetically at build time.
#
# Runtime posture is otherwise identical to skeleton's shipped prod stage:
# non-root user, opcache preload, validate_timestamps=0 (via jit-bench.ini).
# =============================================================================
ARG FRANKEN_VERSION='1.12.2'
ARG PHP_VERSION='8'
ARG OS='trixie'

# -----------------------------------------------------------------------------
# Stage 1: Base — mirrors skeleton/docker/Dockerfile's `base` stage exactly.
# -----------------------------------------------------------------------------
FROM dunglas/frankenphp:${FRANKEN_VERSION}-php${PHP_VERSION}-${OS} AS base

ENV APP_ENV=prod \
    SERVER_NAME=":80" \
    FRANKENPHP_CONFIG="worker ./public/index.php"

RUN apt-get update && apt-get install -y --no-install-recommends \
        acl \
        file \
        gettext \
        git \
        libyaml-dev \
        zip \
        unzip \
    && install-php-extensions \
        apcu \
        gd \
        intl \
        opcache \
        pdo_pgsql \
        pdo_mysql \
        zip \
        yaml \
    && echo "apc.enable_cli=1" >> "$PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini" \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY skeleton/docker/frankenphp/conf.d/app.ini $PHP_INI_DIR/conf.d/

# -----------------------------------------------------------------------------
# Stage 2: Builder — skeleton's prod install + the beta6 working-tree overlay.
# -----------------------------------------------------------------------------
FROM base AS builder

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY skeleton/composer.json skeleton/composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --no-progress --no-interaction --optimize-autoloader

COPY skeleton/ ./

# BETA6 OVERLAY. A bind mount (not COPY) keeps the monorepo out of the image
# layers; only the replaced `src/` trees persist. Every component vendored by
# skeleton is refreshed — the list is derived at build time, so a component
# added to skeleton's composer.json is picked up without editing this file.
RUN --mount=type=bind,source=.,target=/monorepo \
    set -eu; \
    for dir in vendor/waffle-commons/*/; do \
        name="$(basename "$dir")"; \
        if [ -d "/monorepo/${name}/src" ]; then \
            rm -rf "${dir}src"; \
            cp -R "/monorepo/${name}/src" "${dir}src"; \
            echo "overlaid beta6 source: ${name}"; \
        else \
            echo "WARNING: no working tree for vendored component ${name}" >&2; \
        fi; \
    done

# Regenerate AFTER the overlay: beta6 adds classes the beta5 classmap does not
# know (SubjectResolverInterface, RawHtml, …) and the authoritative classmap
# would otherwise refuse to autoload them.
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev

# -----------------------------------------------------------------------------
# Stage 3: Engine — mirrors skeleton's `prod` stage (non-root, preload).
# -----------------------------------------------------------------------------
FROM base AS engine

ARG USER=waffle
ARG UID=1001
ARG GID=1001

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

WORKDIR /app
COPY --from=builder /app /app

# Caddy writes its config/data under XDG paths; keep them off the app tree so
# the container can run with a read-only-ish layout like skeleton's prod compose.
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data

RUN echo "opcache.validate_timestamps = 0" >> "$PHP_INI_DIR/conf.d/app.ini" \
    && echo "opcache.preload=/app/config/preload.php" >> "$PHP_INI_DIR/conf.d/app.ini" \
    && echo "opcache.preload_user=${USER}" >> "$PHP_INI_DIR/conf.d/app.ini" \
    && mkdir -p /config /data /app/var/cache /app/var/log /app/var/uploads \
    && groupadd -g ${GID} ${USER} \
    && useradd -u ${UID} -g ${USER} -d /app -s /usr/sbin/nologin ${USER} \
    && chown -R ${USER}:${USER} /app /config /data

USER ${USER}

EXPOSE 80
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
