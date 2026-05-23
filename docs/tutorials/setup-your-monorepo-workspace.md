# Tutorial — Set up your monorepo workspace

> **Diátaxis quadrant:** Tutorial (learning-oriented).
> **Release:** `v0.1.0-beta1`.
> **You'll end with:** a fully cloned monorepo, a running `waffle-dev` Docker container, and one component's tests passing.
> **Time:** ~15 minutes if Docker is already installed.

This tutorial walks you through getting from zero to a working contributor environment. It is *not* about writing a feature — that's the [next tutorial](make-your-first-cross-component-change.md).

## Prerequisites

| Tool | Version | Why |
| :--- | :--- | :--- |
| **Git** | ≥ 2.30 | Submodule mechanics (`--recurse-submodules`). |
| **Docker** with **Docker Compose** | Recent | All development happens inside the `waffle-dev` container — never natively on the host. See [Why Docker-first](../explanation/docker-first-development.md). |
| **A shell** | Bash, Zsh, Fish — anything POSIX-ish | For the `run-all.sh` / `check-coverage.sh` helpers. |

You do **not** need a local PHP install. The container ships PHP 8.5 + Xdebug + Composer.

## 1. Clone the umbrella with submodules

The monorepo is 19 Git submodules in a trench coat. Clone with `--recurse-submodules` so every component is checked out at the commit the umbrella pins:

```bash
git clone --recurse-submodules git@github.com:waffle-commons/monorepo.git waffle-commons
cd waffle-commons
```

If you forgot the flag (e.g. someone copy-pasted a plain `git clone`), the component directories will exist but be empty. Recover with:

```bash
git submodule update --init --recursive
```

Verify:

```bash
ls -1 contracts security pipeline http-client | head
# contracts:
# README.md
# composer.json
# ...
```

If those files don't exist, the submodules are still uninitialised — re-run the recursive update.

## 2. Boot the `waffle-dev` Docker container

The `workspace` submodule owns the dev-environment `docker-compose.yml`:

```bash
cd workspace
docker compose up -d
```

This starts a single long-lived service named `waffle-dev` with FrankenPHP, PHP 8.5, Xdebug, and Composer pre-installed. The container mounts the entire monorepo at `/waffle-commons` so file changes on the host are visible inside immediately.

Confirm it's up:

```bash
docker ps --filter "name=waffle-dev" --format "{{.Names}}  {{.Status}}"
# waffle-dev  Up 8 seconds (healthy)
```

> If the health check is "starting" for more than ~30 seconds, run `docker compose logs waffle-dev` to see what's stuck. The most common cause is the host's port 443 already being in use.

## 3. Install dependencies in one component

Pick any component — let's use `contracts` because it has no inter-component deps.

```bash
docker exec -it -w /waffle-commons/contracts waffle-dev composer install
```

`-w /waffle-commons/contracts` sets the working directory **inside** the container. This is the canonical invocation pattern used everywhere in these docs.

## 4. Run the quality bar

```bash
docker exec -it -w /waffle-commons/contracts waffle-dev composer mago
docker exec -it -w /waffle-commons/contracts waffle-dev composer tests
```

Expected:

```
INFO No issues found.
INFO No issues found.
INFO No issues found.
PHPUnit 12.5.x by Sebastian Bergmann and contributors.
...
OK (3 tests, 5 assertions)
```

If either command fails on a fresh clone, **that is a bug** — open an issue against `waffle-commons/monorepo` with the output.

## 5. Fan a command out across every component

The `run-all.sh` script wraps `cd $COMP && <command>` over every component. Try a read-only ping first:

```bash
./run-all.sh ls composer.json
```

That should print 18 ✅ lines (one per component). Now the real one:

```bash
./run-all.sh composer mago
```

This takes 1–3 minutes the first time (composer installs hit the network for every component). The summary at the bottom should say `🎉 Final state: SUCCESS`.

> **If a component fails**, run `./run-all.sh --verbose composer mago` to see per-component output. See the [`run-all.sh` reference](../reference/scripts/run-all.md) for flags.

## 6. Verify coverage

```bash
./check-coverage.sh
```

This reads each component's `var/data/phpunit-coverage/index.html` and compares against the 95% threshold. Components without a coverage report show as `❓ N/A` — that just means you haven't run their tests yet. Re-run after `./run-all.sh composer tests` if you want a complete picture.

## 7. (Optional) Install Git hooks

If you'll be authoring commits, install the Project Graphify hooks so they trigger automatically:

```bash
./install-git-hooks.sh
```

Hooks land in **each submodule's** `.git/hooks/` directory (`pre-commit`, `post-checkout`, `post-merge`, `post-rewrite`). See [`install-git-hooks.sh` reference](../reference/scripts/install-git-hooks.md).

## What you've accomplished

- 19 submodules cloned and initialised;
- `waffle-dev` container running;
- one component (`contracts`) installed, lint-clean, and test-green;
- familiarity with the canonical `docker exec -it -w /waffle-commons/<comp> waffle-dev <cmd>` invocation;
- the cross-component scripts (`run-all.sh`, `check-coverage.sh`) working.

## Where next

- [**Make your first cross-component change**](make-your-first-cross-component-change.md) — the next tutorial; ship a real edit through the submodule mechanics.
- [**Repository layout reference**](../reference/repository-layout.md) — what every directory is for.
- [**Docker environment reference**](../reference/docker-environment.md) — service composition, mounted paths, common gotchas.
- [**Why a monorepo of submodules?**](../explanation/why-monorepo-of-submodules.md) — the strategic choice you've just opted into.
