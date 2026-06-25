# Reference — Docker environment

> **Release:** `0.1.0-beta5`.
> **Scope:** the `waffle-dev` Docker container and its compose file.

## Where the compose file lives

`workspace/docker-compose.yml`. Boot from there:

```bash
cd workspace
docker compose up -d
```

## The `waffle-dev` service

| Property | Value |
| :--- | :--- |
| **Container name** | `waffle-dev` |
| **Base image** | FrankenPHP (Caddy + PHP) with PHP 8.5 + Xdebug + Composer pre-installed. |
| **Mount** | The umbrella root is mounted at `/waffle-commons` inside the container. |
| **Working directory** | `/waffle-commons` (override per-command with `-w`). |
| **Healthcheck** | Yes — `docker ps` should show `(healthy)` within ~30s of boot. |
| **Ports** | 80, 443 (Caddy/FrankenPHP), 9003 (Xdebug). |

## The canonical invocation pattern

Every command in these docs follows the same shape:

```bash
docker exec -it -w /waffle-commons/<component> waffle-dev <command>
```

- `-it` for interactive terminal allocation. Drop the `-i` flag for non-interactive (CI) usage.
- `-w /waffle-commons/<component>` sets the working directory.
- `waffle-dev` is the container name.
- `<command>` is what you'd type if you had `cd`'d into the component manually.

## Common variations

```bash
# Drop into a shell inside the container
docker exec -it -w /waffle-commons waffle-dev bash

# Run a one-off command without -it (CI-style)
docker exec -w /waffle-commons/security waffle-dev composer mago

# Capture output for processing
docker exec -w /waffle-commons/security waffle-dev composer tests 2>&1 | tee security-test.log
```

## What's in the container

| Tool | Purpose |
| :--- | :--- |
| PHP 8.5 | Required runtime. |
| Xdebug | Step debugging. Listens on 9003. |
| Composer | Dependency manager. |
| FrankenPHP / Caddy | The application server. |
| `ext-yaml` (PECL) | Required by `waffle-commons/config`. |

`vendor/bin/mago`, `vendor/bin/phpunit`, `vendor/bin/psalm` are resolved per-component by Composer — they aren't globally installed.

## Sandbox services on `waffle-network`

`waffle-dev` is not alone in the compose file — the workspace also boots backing services used by the framework and by the `data` component's live integration tests:

| Service | Image | Host port | Purpose |
| :--- | :--- | :--- | :--- |
| `legacy-backend` | `php:8.5-cli` | `8090` | Deliberately slow "legacy monolith" the Waffle gateway proxies (and asserts identities to, RFC-021). |
| `waffle-redis` | `redis:7-alpine` | — | PSR-16 cache backend (RFC-013) + key-value driver integration target (RFC-022). |
| `waffle-postgres` | `postgres:17-alpine` | `5432` | Primary relational sandbox (RFC-022); `bin/waffle db:migrate` runs against it. Credentials come from `workspace/.env` (`DB_*`). |
| `waffle-mongo` | `mongo:7` | — *(internal only)* | Document-driver integration target (RFC-022); data's Mongo tests skip cleanly when it is absent. |

`waffle-dev` waits for `legacy-backend`, `waffle-redis`, and `waffle-postgres` to be healthy before starting; `waffle-mongo` is independent. Postgres and Mongo persist their data in named volumes (`waffle-postgres-data`, `waffle-mongo-data`) — `down --volumes` resets them.

## File ownership gotchas

The container's PHP user has UID/GID matching the host's user by default (the Dockerfile uses ARGs). If you see permission errors on files created inside the container, your `docker-compose.yml` may need:

```yaml
services:
  waffle-dev:
    build:
      args:
        UID: ${UID:-1000}
        GID: ${GID:-1000}
```

Pass these from the host: `UID=$(id -u) GID=$(id -g) docker compose up -d`.

## Common debugging commands

```bash
# Status
docker ps --filter "name=waffle-dev" --format "{{.Names}}\t{{.Status}}"

# Logs
docker logs -f waffle-dev

# Restart cleanly
docker compose -f workspace/docker-compose.yml restart

# Nuke everything (images included)
docker compose -f workspace/docker-compose.yml down --volumes --rmi all
```

## Related

- [Set up your monorepo workspace](../tutorials/setup-your-monorepo-workspace.md) — boots `waffle-dev` in step 2.
- [Docker-first development](../explanation/docker-first-development.md) — *why* the framework refuses to run natively on the host.
- [`loop.sh` reference](scripts/run-all.md) — note that `loop.sh` runs on the host, not inside the container.
