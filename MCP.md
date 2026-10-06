# MCP.md — Model Context Protocol servers for waffle-commons

> **Scope:** developer tooling only. MCP servers are a Claude Code convenience; they are **not** part of
> the framework runtime and ship with **no** secrets.

Claude Code gets the local development databases and GitHub through four MCP servers. Every server
starts through a **launcher** in [`scripts/mcp/`](./scripts/mcp/), so versions are pinned in one place,
no personal path is committed, and `wfl mcp:check` can prove each one works.

## 🔌 Servers

| Server | Runs via | Pinned version | Access |
|---|---|---|---|
| `postgres` | `npx` | `@henkey/postgres-mcp-server@1.0.7` | read + write (writes ask) |
| `mongo` | Docker | `mongodb/mongodb-mcp-server:3.0.4@sha256:f8484a34…` | **read-only** |
| `redis` | Docker | `mcp/redis@sha256:e886a7e9…` | read + write (writes ask) |
| `github` | Docker | `ghcr.io/github/github-mcp-server:v1.12.2@sha256:508a0857…` | **read-only** (`default,actions` toolsets) |

- **`postgres`** targets the workspace `waffle-postgres` (`localhost:5432`). The original
  `@modelcontextprotocol/server-postgres` is archived; `@henkey/postgres-mcp-server` is the maintained
  replacement.
- **`mongo`** runs MongoDB's official image instead of `npx`: `mongodb-mcp-server` 3.x needs Node ≥ 20.19
  and crashes on older hosts (`ERR_REQUIRE_ESM`). The container carries its own Node. It is started
  read-only and with telemetry disabled.
- **`redis`** runs the official Redis server image (its upstream package is PyPI/`uvx` only, which this
  environment avoids). `mcp/redis` publishes only a moving `latest` tag, so it is pinned by digest.
- **`github`** is **read-only by design**: merges, pushes, releases and repository settings stay with the
  human, through `gh` and its own prompts (see `AGENTS.md` §6, "Git & release safety"). The `actions`
  toolset adds read access to workflow runs and logs.

The three Docker images are pinned by digest, because a tag can be re-pushed: two different builds were
published as `mongodb-mcp-server` `3.0.4`. Docker resolves only the digest; the version tag beside it
(`mongo`, `github`) is a label for readers.

The Postgres and Redis *write* tools are listed under `permissions.ask` in the team settings
(`.claude/settings.json`), so each one prompts before it runs, on every clone.

## 🗂️ Configuration files

| File | Tracked | Content |
|---|---|---|
| [`.mcp.json`](./.mcp.json) | yes | `bash scripts/mcp/<server>.sh` for the four servers |
| [`.claude/settings.json`](./.claude/settings.json) | yes | `enabledMcpjsonServers` (no approval prompt per server once the folder is trusted) and the ask rules for the write tools |
| `.claude/settings.local.json` | no | your own additions, if any |

The commands are **relative to the repository root**: start the agent from the root.

## 🔑 Secrets & environment

- **No secret is ever written to a file.** The GitHub launcher resolves the token at start-up — first
  `GITHUB_TOKEN`, then `GITHUB_PERSONAL_ACCESS_TOKEN`, then the GitHub CLI keyring (`gh auth token`) —
  and hands it to the container through the environment only. A plain `gh auth login` is enough.
- The database values are **non-secret local dev defaults** (the `waffle/waffle` credentials of
  [`workspace/.env`](./workspace/.env)). The launchers apply them; override with:

  | Env var | Default | Used by |
  |---|---|---|
  | `WAFFLE_PG_DSN` | `postgresql://waffle:waffle@localhost:5432/waffle` | `postgres` |
  | `WAFFLE_MONGO_URI` | `mongodb://localhost:27017` | `mongo` |
  | `WAFFLE_REDIS_HOST` / `WAFFLE_REDIS_PORT` | `localhost` / `6379` | `redis` |
  | `WAFFLE_MCP_NPM_CACHE` | `~/.cache/waffle-commons/mcp-npm` | `npx` launchers |

- The `npx` launchers use their **own npm cache** (`WAFFLE_MCP_NPM_CACHE`). A `~/.npm` holding
  root-owned files (left by a `sudo npm …`) makes every `npx` fail with `EACCES`; the MCP servers no
  longer depend on it.

## ✅ Verify

```bash
wfl up            # the dev databases (postgres :5432, mongo :27017, redis :6379)
wfl mcp:check     # prerequisites + wiring + a real MCP session per server
```

`wfl mcp:check` checks the prerequisites (Docker, Node/npx, python3, the database ports, a GitHub token
that the API accepts), the wiring (every configured server uses a launcher, no personal path), then opens
a **real stdio session with every launcher** — `initialize`, `tools/list` and one read-only tool call —
so it cannot report green while a server is down. `--quick` stops after the wiring. The first run also
downloads the packages and images, so the next agent session connects within its start-up timeout.

In Claude Code, `/mcp` lists the servers; reconnect one there after changing its launcher.

## 🩺 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `npm error code EACCES` … "root-owned files" | a past `sudo npm` left root-owned files in `~/.npm` | the launchers avoid it; to repair npm itself: `sudo chown -R "$(id -u):$(id -g)" ~/.npm` |
| mongo exits with `ERR_REQUIRE_ESM` | `mongodb-mcp-server` 3.x on Node < 20.19 via `npx` | use the Docker launcher (the default); upgrade Node to 22/24 LTS |
| github connects but every call returns 401 | empty or stale token | `gh auth login`, or export a valid `GITHUB_TOKEN` |
| a server times out on the very first session | first-time package download / image pull | run `wfl mcp:check` once, then reconnect |
| postgres/mongo/redis tools fail | the dev stack is down | `wfl up` |

## ⬆️ Updating a server

Edit the pin in its launcher (`scripts/mcp/<server>.sh`), run `wfl mcp:check`, and reconnect. For
`mongo` and `github`, change the version tag and copy the new index digest from
`docker buildx imagetools inspect <image>:<version>`: a tag left behind misleads readers without failing
anything. For `mcp/redis`, pull `latest` and copy the new digest from
`docker image inspect mcp/redis:latest --format '{{index .RepoDigests 0}}'`.
