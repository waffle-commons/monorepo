# How-To: Check coverage across components

> **Diátaxis quadrant:** How-To.
> **Release:** `0.1.0-beta4`.
> **Answers:** How do I see which components are below the 95% coverage threshold?

## The one-liner

```bash
./coverage.sh
```

The script reads `<component>/var/data/phpunit-coverage/index.html` for every registered component and extracts the top-level percentage from the HTML's `aria-valuenow="…"` attribute. It then prints a colour-coded table:

| Icon | Meaning |
| :--- | :--- |
| 🏆 | ≥100% — perfect line coverage. |
| ✅ | ≥95% (the threshold). |
| ⚠️  | 85–95% — below threshold but not critical. |
| ❌ | <85% — critical. |
| ❓ | No coverage report on disk — tests haven't been run. |

See the [`coverage.sh` reference](../reference/scripts/check-coverage.md) for the exact output format and exit codes.

## Generate the reports first

The script reads HTML reports — it does not run tests. Generate the reports:

```bash
./loop.sh composer tests
```

Each component's `composer tests` script runs `vendor/bin/phpunit --log-junit … --coverage-html var/data/phpunit-coverage`, so the HTML lands in the expected place.

Then:

```bash
./coverage.sh
```

## Exit codes

- `0` — every component ≥95%.
- non-zero (the script does not `exit 1` but the summary header reports `FAIL`) — at least one component is below threshold or has no report.

If you want CI to gate on coverage, wire `./coverage.sh` after the test run and grep for `Final state: SUCCESS`.

## Drill into a single component

If `security` is below threshold, open its detailed HTML report:

```bash
open security/var/data/phpunit-coverage/index.html
```

(or `xdg-open` on Linux). The report drills down to per-class and per-method coverage with red highlights on uncovered lines.

## Threshold

The 95% bar is a constant in the script:

```bash
THRESHOLD=95
```

If a component genuinely cannot reach it (for instance, a class doing low-level shell-out work whose error paths can't be reasonably tested), document the exception in that component's `mago.toml` `[analyzer.ignore]` section or in its README. Do **not** silently drop the threshold for the whole ecosystem.

## Related

- [`coverage.sh` reference](../reference/scripts/check-coverage.md) — exact output and tier boundaries.
- [Run checks across components](run-checks-across-components.md) — the general-purpose multiplexer.
- [The Mago Purge Protocol](../explanation/mago-purge-protocol.md) — why 95% is the bar.
