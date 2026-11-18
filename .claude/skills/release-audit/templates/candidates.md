# Candidates · S-A05 · Injection

Run: 0.1.0-beta8 / release-audit · finder: owasp-finder (opus · medium) · scope: example-repo @ 1a2b3c4d5e6f
Status: complete

<!-- The example below is fictional on purpose: it names no Waffle code. Keep the shapes exactly:
     the "### <ID> · <SEVERITY> · <title>" heading, the " · " separators, the "- key: value" fields
     before any snippet, and the "Status: complete" line, which wfl audit:status counts. -->

## Checked
- example-repo/src/Query/Compiler.php:88: identifiers quoted per dialect, values bound as parameters (holds)
- evidence/example-repo/psalm-taint.json: no taint path (0 items)
- not established: whether an application can pass a raw sort key (no wiring in the repository)

## Candidates

### S-A05-01 · MEDIUM · Report export splices a sort column into ORDER BY
- lens: A05
- component: example-repo
- where: example-repo/src/Report/ReportRepository.php:42
- also: example-repo/src/Report/ExportRepository.php:57
- claim: the sort column from the caller reaches the SQL text unquoted, while every other identifier goes through the dialect's quoting.
- reach: library code; reachable when an application maps a request parameter to the sort option
- evidence: the quoting helper is used at example-repo/src/Query/Compiler.php:88 but not here; Psalm reports no taint path because the option is typed string
- fix: route the column through the quoting helper and allow-list sortable columns; add a hostile-column test

```php
$sql = sprintf('SELECT * FROM reports ORDER BY %s', $options->sort);
```

<!-- No candidates: write "None." under "## Candidates" and keep "## Checked". -->
<!-- A regression of an earlier fix adds:   - regression: FIX-01 14 -->
<!-- A modernization candidate (M-<group>-NN, lens M1|M2|M3) adds:   - public-api: yes|no -->
<!-- A calibration unit writes candidates/C-<n>.md with C-<n>-NN ids, in the same shape. -->
