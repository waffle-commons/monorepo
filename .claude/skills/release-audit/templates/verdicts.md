# Verdicts · S-A05

Run: 0.1.0-beta8 / release-audit · verifier: finding-verifier (opus · high)
Status: complete

<!-- Fictional examples. Keep the "### <ID> · <CONFIRMED|PLAUSIBLE|REFUTED> · <SEVERITY>" heading exactly:
     wfl audit:status counts it. Judge each claim on its own. -->

### S-A05-01 · CONFIRMED · MEDIUM
- checked: example-repo/src/Report/ReportRepository.php:30-60 @ 1a2b3c4d5e6f
- refute-attempt: looked for an allow-list of sortable columns (none), a caller that validates the option (none in the repository), framework quoting on ORDER BY (not applied)
- reason: the option reaches the SQL text unquoted; any caller that maps it from a request makes it injectable
- severity: MEDIUM (library code, reachable through a common extension point)

### S-A05-02 · REFUTED · LOW
- checked: example-repo/src/Http/RetryingClient.php:70-110 @ 1a2b3c4d5e6f
- refute-attempt: looked for re-validation of the target on each attempt
- reason: the guard runs before every attempt (example-repo/src/Http/RetryingClient.php:84), so a retry cannot reach a private address

<!-- Closure (fix-check mode) writes verdicts/fix-<ID>.md instead:

### FIX S-A05-01 · HOLDS
- fix: example-repo@9f8e7d6c5b4a
- checked: example-repo/src/Report/ReportRepository.php:42 @ 9f8e7d6c5b4a (and every "also" location)
- test: example-repo/tests/Report/ReportRepositoryTest.php::testHostileSortColumnIsRejected
- reason: the column now goes through the allow-list; the test fails on the parent commit

(FAILS instead of HOLDS when a location still carries the flaw or no test covers it.) -->
