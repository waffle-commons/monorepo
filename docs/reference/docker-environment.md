# Reference — Docker environment

> **Release:** `v0.1.0-beta1`.
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
- [`run-all.sh` reference](scripts/run-all.md) — note that `run-all.sh` runs on the host, not inside the container.
