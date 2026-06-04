# How-To: Run checks across all components

> **Diátaxis quadrant:** How-To.
> **Release:** `v0.1.0-beta2`.
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

Worker-mode memory safety has its own gate — [Igor-PHP](../explanation/mago-purge-protocol.md#the-memory-neutrality-companion-gate-igor-php) — wired as a `composer igor` script. Unlike `composer mago`, it is defined **only** on the components that hold resident state, so don't fan it across all 18 with `loop.sh` (the rest would report `Command "igor" is not defined`). Run it on the memory-sensitive set:

```bash
for c in runtime waffle container pipeline security auth data cache http http-client workspace skeleton component-template; do
  echo "=== $c ==="
  docker exec -w /waffle-commons/$c waffle-dev composer igor || true
done
```

Components scaffolded from `component-template` inherit the gate automatically.

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
