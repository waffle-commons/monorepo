# How-To: Run checks across all components

> **Diátaxis quadrant:** How-To.
> **Release:** `v0.1.0-beta1`.
> **Answers:** How do I run a command (`composer mago`, `composer tests`, anything else) on every component at once?

## The one-liner

```bash
./run-all.sh composer mago
```

The script iterates over the hardcoded `COMPONENTS=( … )` array, `cd`s into each, runs the command, and reports a per-component pass/fail summary at the end. See the [`run-all.sh` reference](../reference/scripts/run-all.md) for the exact signature.

> **Note.** `run-all.sh` runs the command on the host shell (it does `cd $COMP && <cmd>`). It does **not** wrap the command in `docker exec`. For commands that require the dev container (like `composer mago`, which runs through the locally-installed `vendor/bin/mago`), the script assumes either (a) PHP is available on the host *or* (b) every component's `composer` script delegates to the container — whichever your team has set up. The skeleton workflow is to run commands explicitly via `docker exec` inside the container; `run-all.sh` is for shell-level operations.

If your component scripts shell out to Docker themselves, the script works as-is. If they don't, wrap your command:

```bash
./run-all.sh bash -c 'docker exec -w /waffle-commons/$(basename "$PWD") waffle-dev composer mago'
```

That `$(basename "$PWD")` trick reads the component directory name from the current working directory `run-all.sh` is sitting in.

## Output modes

```bash
./run-all.sh composer mago              # SILENT (default) — one line per component
./run-all.sh --verbose composer mago    # full output, useful when debugging a failure
./run-all.sh --silent composer mago     # explicit silent (same as default)
```

`-s` / `-v` are accepted short flags.

## Common recipes

```bash
# Confirm every component still parses (cheap)
./run-all.sh composer validate --strict --no-check-publish

# Update every component's lockfile
./run-all.sh composer update

# Run the full quality bar everywhere
./run-all.sh composer mago && ./run-all.sh composer tests

# Discover which component contains a string
./run-all.sh --verbose grep -rn "MyClassName" src

# See which components are dirty in git
./run-all.sh git status --porcelain
```

## Exit codes

- `0` — every component succeeded.
- `1` — at least one component failed; the names are printed at the bottom of the summary.

A skipped component (directory missing) does **not** count as a failure. The summary line shows `⏭️  N skipped` independently.

## When a single component fails

```bash
./run-all.sh composer mago
# [13/18] security             ❌ FAIL (exit 1)
# ...
# Failed components: security
```

Drill into that one component with verbose output:

```bash
./run-all.sh --verbose composer mago 2>&1 | sed -n '/security/,/-----/p'
```

Or, more directly:

```bash
docker exec -it -w /waffle-commons/security waffle-dev composer mago
```

## Related

- [`run-all.sh` reference](../reference/scripts/run-all.md) — full flag table and behavior.
- [Check coverage across components](check-coverage-across-components.md) — the coverage-specific equivalent.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — why we run mago everywhere, always.
