#!/usr/bin/env bash
# =============================================================================
# scripts/mcp/redis.sh — stdio launcher for the Redis MCP server (Docker).
#
# Target: the workspace dev Redis (waffle-redis, host port 6379).
# Override with WAFFLE_REDIS_HOST / WAFFLE_REDIS_PORT (the image takes discrete
# host/port variables, not a redis:// URL).
#
# mcp/redis only publishes a moving `latest` tag, so the image is pinned by
# digest. To update: docker pull mcp/redis:latest, then copy the new
# `docker image inspect mcp/redis:latest --format '{{index .RepoDigests 0}}'`.
#
# stdout is the MCP channel — nothing but the server may write to it.
# =============================================================================
set -euo pipefail

exec docker run --rm -i --network=host \
  -e REDIS_HOST="${WAFFLE_REDIS_HOST:-localhost}" \
  -e REDIS_PORT="${WAFFLE_REDIS_PORT:-6379}" \
  mcp/redis@sha256:e886a7e9990a084a20d46adcea8e7c89d539271f1b453ffabdce4c3f96f27fa0
