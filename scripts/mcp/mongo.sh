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
# stdout is the MCP channel — nothing but the server may write to it.
# =============================================================================
set -euo pipefail

exec docker run --rm -i --network=host \
  -e MDB_MCP_CONNECTION_STRING="${WAFFLE_MONGO_URI:-mongodb://localhost:27017}" \
  -e MDB_MCP_READ_ONLY=true \
  -e MDB_MCP_TELEMETRY=disabled \
  mongodb/mongodb-mcp-server:3.0.4
