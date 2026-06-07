# Explanation — The Mago Purge Protocol

> **Diátaxis quadrant:** Explanation.
> **Release:** `v0.1.0-beta2`.

## The rule

Every component, on every commit, must pass:

```bash
vendor/bin/mago fmt --check
vendor/bin/mago lint
vendor/bin/mago analyze
vendor/bin/mago guard
```

with **zero errors, zero warnings, zero notices, zero hints**, and **no baseline files** (`mago-*-baseline.toml`). This is the Mago Purge Protocol.

Mago is the unified PHP code-quality toolchain Waffle uses (formatter + linter + static analyzer + architectural guard). Each phase is a hard gate.

## Why we run all four phases

| Phase | What it catches |
| :--- | :--- |
| `mago fmt` | Inconsistent formatting (spaces, braces, import order). Cheap but tedious diffs. |
| `mago lint` | Lexical issues (unused imports, redundant docblocks, dead branches, nested ternaries). |
| `mago analyze` | Type inference, narrow flow analysis, missing nullability, contract violations. The expensive but most-valuable phase. |
| `mago guard` | Architectural rules — *can `security` import from `routing`?* Encoded per-component in `mago.toml`. This is where the [Component Agnosticism rule](component-agnosticism.md) is enforced. |

Skipping any phase is a hole in the wall.

## Why "zero" — not "below some threshold"

Threshold-based gates teach contributors that warnings are background noise. A new warning blends into a sea of existing ones; nobody notices. Within a year you have 200 warnings and one new genuinely-important one nobody can find.

Zero-warning policy makes every new warning **visible** — it breaks the build the instant it lands. The first cost is paid once: scrubbing the existing codebase to zero. Subsequent cost is amortised across all future PRs, each of which is responsible for not regressing.

## Why no baseline files

Mago supports `mago-*-baseline.toml` files that suppress a snapshot of existing issues so a project can adopt the tool gradually. We explicitly **forbid** them in this ecosystem.

The reasoning is the same as zero-warning: a baseline file is institutional permission to leave issues unfixed. The right path for an issue that genuinely cannot be fixed (e.g. a third-party library quirk) is a **scoped `mago.toml` `[analyzer.ignore]` entry** — a documented, reviewable, narrow exception — not a snapshot file that swallows everything.

If you find yourself wanting a baseline, that's a signal to either:

- fix the underlying issue (preferred);
- carve a narrow `[analyzer.ignore]` rule for the specific path/class with a comment explaining why;
- push back on the lint rule itself if it's genuinely wrong for this codebase.

## What "no baseline files exist" looks like operationally

```bash
find . -name "mago-*-baseline.toml" -not -path "*/vendor/*" -not -path "*/node_modules/*"
# (empty)
```

`mago guard` is configured to fail on the presence of these files. CI runs this check on every PR.

## The 95% coverage twin rule

The Mago Purge Protocol covers code quality. The coverage twin is:

- Every component: PHPUnit coverage ≥ 95%.
- Enforced by [`coverage.sh`](../reference/scripts/check-coverage.md).
- Reported per-component, with a per-line drill-down available in `var/data/phpunit-coverage/index.html`.

The two together form Waffle's "Zero-Debt" guarantee: no static-analysis issues, high test coverage, no slipping standard.

## The memory-neutrality companion gate (Igor-PHP)

Mago guards *code* quality; it does not know whether a service leaks state between requests. Under FrankenPHP worker mode the process is resident, so a singleton that mutates a `static` array — or a `reset()` handler that forgets a property — accumulates in RAM and bleeds state from one request into the next. Mago cannot see that; **[Igor-PHP](https://github.com/igor-php/igor-php)** can.

Igor is an ultra-fast Go static linter purpose-built for FrankenPHP worker mode. It enforces the **zero memory-drift** invariant (`ΔM = 0`) by rejecting three classes of defect:

| Igor finding | What it catches |
| :--- | :--- |
| State mutation | `static::$prop`, `$this->items[] = …`, and other writes that survive the request loop. |
| Incomplete reset | A service implementing `ResettableInterface` whose `reset()` leaves a mutable property set. |
| Dangerous globals | Superglobals (`$_GET`, `$_SERVER`), `exit`/`die`, and ambient mutations (`date_default_timezone_set`) that poison the resident worker. |

It runs exactly like the Mago phases — a `composer igor` script (`vendor/bin/igor-php .`, configured per component in `igor.json`):

```bash
docker exec -w /waffle-commons/<component> waffle-dev composer igor
```

Igor is wired into the components that hold resident or request-scoped state — `runtime`, `waffle`, `container`, `pipeline`, `security`, `auth`, `data`, `cache`, `http`, `http-client` — plus the `workspace` / `skeleton` apps and the `component-template` scaffold. Stateless components (`contracts`, `utils`, `console`, `config`, `routing`, …) are intentionally excluded: there is no resident state to audit.

The **zero-baseline rule applies identically.** Igor supports a `baseline` key and a `--generate-baseline` flag; we use neither. A memory-drift finding is fixed, not snapshotted. See [Run checks across components](../how-to/run-checks-across-components.md#the-memory-neutrality-gate-igor-php) for how to fan it across the tree.

## When the protocol is wrong

If a Mago rule is genuinely wrong for this codebase — e.g. it flags a pattern that PHP 8.5 made legitimate but Mago hasn't yet caught up to — the right response is:

1. Open an issue on the umbrella with a minimal reproducer.
2. Add a narrowly-scoped `[analyzer.ignore]` (or equivalent) entry in the affected component's `mago.toml`, with a code comment pointing at the issue.
3. Re-evaluate when Mago is updated.

Do **not** add a baseline file as a workaround.

## When you're the one who broke it

Common situations:

- **"Mago says my type is wrong but I'm sure it's right."** Read the analyzer message carefully — Mago is usually right about types. If you genuinely disagree, narrow the scope (add explicit type annotations) until you can prove the analyzer's claim is unfounded; if you still disagree, file an issue.
- **"Mago wants me to use a Property Hook here but the legacy code is everywhere."** Convert the call site to the new style. If the surrounding code can't be changed yet, you're touching a refactor opportunity — open a separate refactor PR.
- **"My formatter changes are being rejected."** Re-run `composer formatter` (or `vendor/bin/mago fmt`) and let the tool fix everything before committing.

## Related

- [The Component Agnosticism rule](component-agnosticism.md) — `mago guard` enforces this.
- [Check coverage across components](../how-to/check-coverage-across-components.md) — the 95% twin rule.
- [`loop.sh` reference](../reference/scripts/run-all.md) — how to run the four Mago phases everywhere at once.
