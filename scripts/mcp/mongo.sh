#!/usr/bin/env bash
# =============================================================================
# scripts/mcp/mongo.sh — stdio launcher for the MongoDB MCP server (Docker).
#
# Target: the workspace dev database (waffle-mongo, host port 27017).
# Override the URI with WAFFLE_MONGO_URI.
#
# Runs MongoDB's official image rather than npx: mongodb-mcp-server 3.x needs
# Node >= 20.19 and crashes on older hosts with ERR_REQUIRE_ESM. The container
# carries its own Node. Read-only and telemetry-free by construction.
#
# The image is pinned by digest: a version tag can be re-pushed, and two
# different builds were published as 3.0.4 (2026-09-29 and 2026-10-01).
# Docker resolves only the digest; the tag is a label for readers, so keep
# both in step. To update: copy the index digest from
# `docker buildx imagetools inspect mongodb/mongodb-mcp-server:<version>`,
# then run `wfl mcp:check`, which pulls the image before a session needs it.
#
# stdout is the MCP channel — nothing but the server may write to it.
# =============================================================================
set -euo pipefail

exec docker run --rm -i --network=host \
  -e MDB_MCP_CONNECTION_STRING="${WAFFLE_MONGO_URI:-mongodb://localhost:27017}" \
  -e MDB_MCP_READ_ONLY=true \
  -e MDB_MCP_TELEMETRY=disabled \
  mongodb/mongodb-mcp-server:3.0.4@sha256:f8484a34d85bdb5ec895081d3089dfc6b1de5c6963dba978743090c4a8deaf58
