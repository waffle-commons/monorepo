# MCP.md — Model Context Protocol servers for waffle-commons

> **Scope:** developer tooling only. MCP servers are an *editor/agent* convenience (Claude Code,
> opencode & AntigravityCLI); they are **not** part of the framework runtime and ship with **no** secrets.

This repo registers five MCP servers so agents (Claude Code, opencode, AntigravityCLI) can read the
working tree, query the local development databases, and reach GitHub. The same five servers are mirrored
across all three runtimes (AntigravityCLI shares the `.opencode/` skills+agents via symlink, so only its
MCP config is repo-specific). Configuration lives in four files:

| File | Consumer | Role |
|------|----------|------|
| [`.mcp.json`](./.mcp.json) | Claude Code | Server definitions (`mcpServers`) |
| [`opencode.json`](./opencode.json) | opencode | Mirror of the same servers under `mcp` |
| [`.claude/settings.local.json`](./.claude/settings.local.json) | Claude Code | `enabledMcpjsonServers` allowlist + non-secret `env` defaults |
| [`.antigravitycli/mcp_config.json`](./.antigravitycli/mcp_config.json) | AntigravityCLI (Antigravity/Gemini CLI) | Project-scoped mirror (`mcpServers`); gitignored. Global fallback: `~/.gemini/config/mcp_config.json` |

> ⚙️ **uvx is intentionally avoided.** This environment has `npx`, `node`, and `docker` but **no**
> `uvx`. Every server below runs through `npx` or `docker` only. Where the official upstream is a
> Python/`uvx` package (Redis), we use its maintained **Docker image** instead.

---

## 🔌 Servers

### 1. `filesystem` — workspace file access
- **Package:** [`@modelcontextprotocol/server-filesystem`](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem) (official, `npx`)
- **Purpose:** read/list/search files under the repo root.
- **Scope:** pinned to `/Users/lesliepetrimaux/Git/Perso/waffle-commons` — the server only exposes that directory.
- **Prereqs:** none beyond `npx`/`node`.

### 2. `postgres` — PostgreSQL dev sandbox
- **Package:** [`@henkey/postgres-mcp-server`](https://www.npmjs.com/package/@henkey/postgres-mcp-server) (`npx`)
- **Why this one:** the original `@modelcontextprotocol/server-postgres` is **archived**. `@henkey/postgres-mcp-server` is an actively maintained drop-in (17+ tools, schema introspection, safe query execution) that runs over `npx` — no `uvx`, no Docker network juggling.
- **Connection:** `--connection-string postgresql://waffle:waffle@localhost:5432/waffle` (Claude Code reads it from `${WAFFLE_PG_DSN}` with that value as the default). Postgres is **host-reachable** on `:5432` via the `waffle-postgres` compose service.
- **Prereqs:** `wfl up` (the `waffle-postgres` container must be healthy).

> 🐳 **Docker alternative (noted, not used):** [`crystaldba/postgres-mcp`](https://hub.docker.com/r/crystaldba/postgres-mcp)
> exists and is maintained. Swap it in only if you prefer a containerized Postgres MCP; it would need
> `--network=host` (or `host.docker.internal`) to reach `localhost:5432`.

### 3. `mongo` — MongoDB dev sandbox
- **Package:** [`mongodb-mcp-server`](https://www.npmjs.com/package/mongodb-mcp-server) — **MongoDB's official** server (`npx`).
- **Connection:** `MDB_MCP_CONNECTION_STRING=mongodb://localhost:27017` (Claude Code reads `${WAFFLE_MONGO_URI}` with that default).
- **Prereqs:** `wfl up` **and** the host port mapping `27017:27017` on the `waffle-mongo` service (added to [`workspace/docker-compose.yml`](./workspace/docker-compose.yml) for this purpose — Mongo is otherwise internal-only).

### 4. `redis` — Redis dev sandbox
- **Image:** [`mcp/redis`](https://hub.docker.com/r/mcp/redis) — the **official Redis** MCP server, run via **Docker** (the upstream `@redis/mcp-redis` is published only to PyPI / `uvx`, which we avoid; there is no maintained first-party npm build).
- **Run:** `docker run --rm -i --network=host -e REDIS_HOST -e REDIS_PORT mcp/redis`. The image takes discrete `REDIS_HOST`/`REDIS_PORT` env vars (it does **not** accept a single `REDIS_URL`); we set `localhost`/`6379`. `--network=host` lets the container reach the host-published Redis port.
- **Connection target:** `redis://localhost:6379` (host port mapping `6379:6379` on `waffle-redis`).
- **Prereqs:** `wfl up` **and** the host port mapping `6379:6379` on the `waffle-redis` service (added to [`workspace/docker-compose.yml`](./workspace/docker-compose.yml) — Redis is otherwise internal-only). The `mcp/redis` image is pulled on first use.

> 🐳 **npm alternative (noted, not used):** [`@gongrzhe/server-redis-mcp`](https://www.npmjs.com/package/@gongrzhe/server-redis-mcp)
> is a maintained `npx` Redis MCP that accepts a `redis://…` URL argument. Use it if you would rather
> avoid Docker for Redis.

### 5. `github` — GitHub API
- **Image:** [`ghcr.io/github/github-mcp-server`](https://github.com/github/github-mcp-server) — the **official GitHub** MCP server, run via **Docker**.
- **Run:** `docker run --rm -i -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server`.
- **Auth:** `GITHUB_PERSONAL_ACCESS_TOKEN` is sourced from **`${GITHUB_TOKEN}`** — never inlined. Export it in your shell, or pipe `gh auth token` into it (see below).
- **Prereqs:** Docker; a valid `GITHUB_TOKEN` in the environment.

---

## 🔑 Secrets & environment

- **No secret is ever inlined.** The GitHub token is an env-var reference (`${GITHUB_TOKEN}`).
- The database connection values are **non-secret local dev defaults** (the same `waffle/waffle`
  credentials documented in [`workspace/.env`](./workspace/.env)) and are surfaced as overridable
  env vars in `.claude/settings.local.json`:

  | Env var | Default | Used by |
  |---------|---------|---------|
  | `WAFFLE_PG_DSN` | `postgresql://waffle:waffle@localhost:5432/waffle` | `postgres` |
  | `WAFFLE_MONGO_URI` | `mongodb://localhost:27017` | `mongo` |
  | `WAFFLE_REDIS_HOST` / `WAFFLE_REDIS_PORT` | `localhost` / `6379` | `redis` |
  | `GITHUB_TOKEN` | *(unset — you must provide it)* | `github` |

- **Set the GitHub token** before launching an agent:

  ```bash
  export GITHUB_TOKEN="$(gh auth token)"   # reuse your gh CLI login
  # or: export GITHUB_TOKEN=ghp_xxx        # a fine-grained PAT
  ```

- **Bring the DB sandboxes up** (required for `postgres`, `mongo`, `redis`):

  ```bash
  wfl up
  ```

  `wfl up` starts the `workspace/` compose stack. The MCP servers run **on the host** and reach the
  databases through the published host ports (`5432`, `27017`, `6379`).

---

## ✅ Quick test per server

Run these from the repo root. They confirm each transport is reachable **without** starting a
long-running MCP session.

```bash
# 0. Prereqs
wfl up                                   # databases healthy
export GITHUB_TOKEN="$(gh auth token)"   # github server auth

# 1. filesystem — package resolves
npx -y @modelcontextprotocol/server-filesystem --help

# 2. postgres — host port answers, package resolves
pg_isready -h localhost -p 5432 -U waffle           # or: nc -z localhost 5432
npx -y @henkey/postgres-mcp-server --help

# 3. mongo — host port answers, package resolves
nc -z localhost 27017 && echo "mongo up"
npx -y mongodb-mcp-server --version

# 4. redis — host port answers, image present
nc -z localhost 6379 && echo "redis up"
docker run --rm -i --network=host -e REDIS_HOST=localhost -e REDIS_PORT=6379 mcp/redis --help

# 5. github — token set, image present
test -n "$GITHUB_TOKEN" && echo "token set"
docker run --rm -i -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server --help
```

Inside Claude Code, `/mcp` lists the connected servers and their tool inventories; in opencode the
servers appear once `opencode.json`'s `mcp` block is loaded; AntigravityCLI loads them from
`.antigravitycli/mcp_config.json` (project-scoped; falls back to `~/.gemini/config/mcp_config.json` if the
CLI build only reads the global path). Only the five servers in `enabledMcpjsonServers` are activated from
`.mcp.json`. Run `wfl mcp:check` to verify prerequisites (npx/docker, DB reachability, `GITHUB_TOKEN`).
