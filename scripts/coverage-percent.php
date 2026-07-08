<?php

declare(strict_types=1);

/**
 * Line-coverage extractor (replaces brittle HTML `aria-valuenow` scraping).
 *
 * Reads a Clover XML report and prints the project-level line-coverage
 * percentage (covered statements / statements), rounded to two decimals.
 * Clover's project rollup is the last `<metrics …>` element under `</project>`;
 * we read `statements` / `coveredstatements` from it — the same figures PHPUnit
 * renders as the HTML coverage gauge, but parsed deterministically.
 *
 * Usage:
 *   php scripts/coverage-percent.php <component>          # resolves <comp>/var/data/phpunit-coverage/clover.xml
 *   php scripts/coverage-percent.php path/to/clover.xml   # explicit report path
 *
 * Output: a bare percentage on stdout, e.g. "95.24" (no trailing newline noise
 *         beyond a single \n) so callers can capture it directly.
 * Exit:   0 on success, 1 when the report is missing/unparseable, 2 on bad args.
 */

$arg = $argv[1] ?? '';

if ($arg === '') {
    fwrite(STDERR, "usage: php scripts/coverage-percent.php <component|path/to/clover.xml>\n");
    exit(2);
}

$repoRoot = dirname(__DIR__);

// Resolve the Clover path: explicit file, or <component>/var/data/phpunit-coverage/clover.xml.
if (is_file($arg)) {
    $cloverPath = $arg;
} elseif (str_ends_with($arg, '.xml') && is_file($repoRoot . '/' . $arg)) {
    $cloverPath = $repoRoot . '/' . $arg;
} else {
    $cloverPath = $repoRoot . '/' . trim($arg, '/') . '/var/data/phpunit-coverage/clover.xml';
}

if (!is_file($cloverPath)) {
    fwrite(STDERR, sprintf("coverage report not found: %s\n", $cloverPath));
    fwrite(STDERR, "  (run 'composer tests' for the component first)\n");
    exit(1);
}

$previous = libxml_use_internal_errors(true);
$xml = simplexml_load_file($cloverPath);
libxml_use_internal_errors($previous);

if ($xml === false) {
    fwrite(STDERR, sprintf("could not parse Clover XML: %s\n", $cloverPath));
    exit(1);
}

// The project rollup is the <metrics> directly under <project>.
$metrics = $xml->project->metrics ?? null;
if ($metrics === null) {
    // Fallback: the last <metrics> anywhere is the broadest aggregate.
    $all = $xml->xpath('//metrics') ?: [];
    $metrics = $all === [] ? null : $all[count($all) - 1];
}

if ($metrics === null) {
    fwrite(STDERR, sprintf("no <metrics> rollup in Clover XML: %s\n", $cloverPath));
    exit(1);
}

$statements = (int) ($metrics['statements'] ?? 0);
$covered = (int) ($metrics['coveredstatements'] ?? 0);

// A component with zero executable statements (pure interfaces, e.g. contracts)
// is treated as fully covered — there is nothing to leave uncovered.
$percent = $statements > 0 ? ($covered / $statements) * 100 : 100.0;

printf("%.2f\n", $percent);
exit(0);
