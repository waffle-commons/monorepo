# How-To: Run checks across all components

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta4`.
> **Answers:** How do I run a command (`composer mago`, `composer tests`, anything else) on every component at once?

## The one-liner

```bash
./loop.sh composer mago
```

The script iterates over the hardcoded `COMPONENTS=( … )` array, `cd`s into each, runs the command, and reports a per-component pass/fail summary at the end. See the [`loop.sh` reference](../reference/scripts/run-all.md) for the exact signature.

> **Note.** `loop.sh` runs the command on the host shell (it does `cd $COMP && <cmd>`). It does **not** wrap the command in `docker exec`. For commands that require the dev container (like `composer mago`, which runs through the locally-installed `vendor/bin/mago`), the script assumes either (a) PHP is available on the host *or* (b) every component's `composer` script delegates to the container — whichever your team has set up. The skeleton workflow is to run commands explicitly via `docker exec` inside the container; `loop.sh` is for shell-level operations.

If your component scripts shell out to Docker themselves, the script works as-is. If they don't, wrap your command:

```bash
./loop.sh bash -c 'docker exec -w /waffle-commons/$(basename "$PWD") waffle-dev composer mago'
```

That `$(basename "$PWD")` trick reads the component directory name from the current working directory `loop.sh` is sitting in.

## Output modes

```bash
./loop.sh composer mago              # SILENT (default) — one line per component
./loop.sh --verbose composer mago    # full output, useful when debugging a failure
./loop.sh --silent composer mago     # explicit silent (same as default)
```

`-s` / `-v` are accepted short flags.

## Common recipes

```bash
# Confirm every component still parses (cheap)
./loop.sh composer validate --strict --no-check-publish

# Update every component's lockfile
./loop.sh composer update

# Run the full quality bar everywhere
./loop.sh composer mago && ./loop.sh composer tests

# Discover which component contains a string
./loop.sh --verbose grep -rn "MyClassName" src

# See which components are dirty in git
./loop.sh git status --porcelain
```

## The memory-neutrality gate (Igor-PHP)

Worker-mode memory safety has its own gate — [Igor-PHP](../explanation/mago-purge-protocol.md#the-memory-neutrality-companion-gate-igor-php) — a static `ΔM = 0` audit. Unlike `composer mago`, it is defined **only** on the components that hold resident state, so it must not be fanned across every component with `loop.sh` (the rest have no `igor` script). The root **`igor.sh`** handles that for you: it dynamically scans each component's `composer.json` for `igor-php/igor-php` and audits only the candidates.

```bash
./igor.sh            # audit every Igor-enabled component (docker mode auto-detected)
wfl igor             # same, via the developer CLI
./igor.sh --silent   # one line per component
./igor.sh -c runtime # scope to a single component
```

`igor.sh` runs each candidate's `vendor/bin/igor-php .` (auto-loading that component's `igor.json`), never halts early, prints a summary table (DANGEROUS = Igor's "KO (Dangerous State)" count), and exits non-zero if any audit fails. On the host it wraps each run in `docker exec` into `waffle-dev`; pass `--local` when you are already inside the container. Components scaffolded from `component-template` declare the dependency, so they are picked up automatically.

> The same audit is also available from the application console as **`igor:audit`** (`Waffle\Commons\Console\Command\MemoryAuditCommand`), a thin command whose `proc_open` engine lives in `waffle-commons/runtime`. See the [Console reference](../../documentation/reference/console.md#igoraudit).

## Exit codes

- `0` — every component succeeded.
- `1` — at least one component failed; the names are printed at the bottom of the summary.

A skipped component (directory missing) does **not** count as a failure. The summary line shows `⏭️  N skipped` independently.

## When a single component fails

```bash
./loop.sh composer mago
# [13/18] security             ❌ FAIL (exit 1)
# ...
# Failed components: security
```

Drill into that one component with verbose output:

```bash
./loop.sh --verbose composer mago 2>&1 | sed -n '/security/,/-----/p'
```

Or, more directly:

```bash
docker exec -it -w /waffle-commons/security waffle-dev composer mago
```

## Related

- [`loop.sh` reference](../reference/scripts/run-all.md) — full flag table and behavior.
- [Check coverage across components](check-coverage-across-components.md) — the coverage-specific equivalent.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — why we run mago everywhere, always.
