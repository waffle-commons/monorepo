# Tutorial — Set up your monorepo workspace

> **Diátaxis quadrant:** Tutorial (learning-oriented).
> **Release:** `0.1.0-beta7`.
> **You'll end with:** a cloned monorepo, a running `waffle-dev` Docker container, every component's
> dependencies installed, the git hooks in place, and one component proven green.
> **Time:** ~15 minutes, most of it the first Docker image build.

This tutorial gets you from zero to a working contributor environment with one command. It is *not*
about writing a feature — that's the [next tutorial](make-your-first-cross-component-change.md).

## Prerequisites

| Tool | Version | Why |
| :--- | :--- | :--- |
| **Git** | ≥ 2.30 | Submodule mechanics. |
| **Docker** with **Docker Compose** v2 | Recent | All development happens inside the `waffle-dev` container — never natively on the host. See [Why Docker-first](../explanation/docker-first-development.md). |
| **A shell** | Bash or Zsh | `bin/wfl` and the scripts behind it. |

Optional: a GitHub SSH key (without one, `wfl init` clones over HTTPS), and for the AI tooling `gh`
(the GitHub MCP server), Node ≥ 20.19 (the Postgres MCP server), `python3` and Claude Code ≥ 2.1.287.
You do **not** need a local PHP install: the container ships PHP 8.5 + Xdebug + Composer.

`bin/wfl doctor --prereqs` checks all of this in a few seconds and prints the fix for anything missing.

## 1. Clone, then run `wfl init`

```bash
git clone git@github.com:waffle-commons/monorepo.git waffle-commons
cd waffle-commons
bin/wfl init
```

Clone **without** `--recurse-submodules`: `wfl init` initialises the submodules itself, and handles
the cases a recursive clone fails on. Its seven steps:

1. **Host prerequisites** — the same checks as `wfl doctor --prereqs`.
2. **Submodules** — only the ones not yet initialised, so re-running it never touches a checked-out
   submodule. Without a working GitHub SSH key it clones over HTTPS (or pass `--https`). The `academy`
   submodule is private: if you cannot read it, it is skipped with a note and everything else works.
3. **The Docker dev stack** — `docker compose up --build -d` from `workspace/`, then it waits for
   `waffle-dev` to run. The first build takes a few minutes.
4. **Composer dependencies** — `composer install` inside the container for every component whose
   `vendor/` is missing or stale, four at a time.
5. **Git hooks** — the pre-commit Mago and pre-push sanity gates ([Install Git hooks](../how-to/install-git-hooks.md)).
6. **`wfl` on your PATH** — a link in `~/.local/bin` (add that directory to `PATH` if it isn't).
7. **MCP warm-up** — `wfl mcp:check` pre-fetches the MCP servers so Claude Code connects at once.

It ends with a summary of anything to look at. `wfl init --help` lists the flags (`--skip-docker`,
`--skip-composer`, `--skip-ai`, `--no-link`). You can run it again at any time: it only does what is
still missing.

## 2. Check the result

```bash
wfl doctor
```

Expected: a list of `✓` lines ending in `✓ ready`. A `!` line works but names something to improve,
with its fix; a `✗` line is a blocker.

## 3. Prove one component green

```bash
wfl dod contracts
```

`wfl dod` runs the whole definition of done inside the container: `composer mago` (zero output),
`composer tests` (a clean `OK (…)`), line coverage ≥ 95 % and `wfl igor` (0 KO). It ends with
`✓ DoD PASS — contracts`. The same steps by hand, in the canonical form used everywhere in these docs:

```bash
docker exec -it -w /waffle-commons/contracts waffle-dev composer mago
docker exec -it -w /waffle-commons/contracts waffle-dev composer tests
```

If either fails on a fresh clone, **that is a bug** — open an issue against `waffle-commons/monorepo`
with the output.

## 4. Fan a command out across every component

```bash
wfl check:all              # composer mago in every component, in parallel
wfl check:all --with-tests # … plus PHPUnit
./coverage.sh              # coverage per component against the 95% threshold
```

See [Run checks across components](../how-to/run-checks-across-components.md) for `loop.sh` and its flags.

## 5. (Optional) Open Claude Code

```bash
claude
```

Start it at the repository root and accept the trust prompt. That loads the team settings
(`.claude/settings.json`: the git-safety permission rules, the MCP servers) and the repository
plugins: `waffle-cockpit` draws a status band above the prompt and adds `/dod <component>`, and
`mattpocock-skills` adds `/mattpocock-skills:<name>`. If the band does not show in the very first
session, run `/reload-plugins` once.

## What you've accomplished

- the monorepo cloned, with every submodule you can read initialised;
- `waffle-dev` running, every component's dependencies installed;
- the pre-commit and pre-push gates installed;
- one component (`contracts`) proven green by its definition of done;
- `wfl doctor` to re-check the environment at any time.

## Where next

- [**Make your first cross-component change**](make-your-first-cross-component-change.md) — the next tutorial; ship a real edit through the submodule mechanics.
- [**Repository layout reference**](../reference/repository-layout.md) — what every directory is for.
- [**Docker environment reference**](../reference/docker-environment.md) — service composition, mounted paths, common gotchas.
- [**Why a monorepo of submodules?**](../explanation/why-monorepo-of-submodules.md) — the strategic choice you've just opted into.
