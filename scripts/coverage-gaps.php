<?php

declare(strict_types=1);

/**
 * Coverage-gap analyzer — the recurrent "which files are under 95% and how many
 * statements are uncovered?" diagnostic, parsed deterministically from Clover XML
 * (no HTML scraping). Complements scripts/coverage-percent.php (which prints only
 * the rollup %).
 *
 * Usage:
 *   php scripts/coverage-gaps.php <component> [threshold=95]
 *   php scripts/coverage-gaps.php path/to/clover.xml [threshold]
 *
 * Output: overall %, the count of uncovered statements, and every source file
 *         below the threshold (path → %), sorted worst-first.
 * Exit:   0 if every file meets the threshold, 1 if any file is below it (so it
 *         doubles as a gate), 2 on bad args / missing report.
 */

$arg = $argv[1] ?? '';
$threshold = (float) ($argv[2] ?? 95.0);

if ($arg === '') {
    fwrite(STDERR, "usage: php scripts/coverage-gaps.php <component|path/to/clover.xml> [threshold=95]\n");
    exit(2);
}

$repoRoot = dirname(__DIR__);

if (is_file($arg)) {
    $cloverPath = $arg;
} elseif (str_ends_with($arg, '.xml') && is_file($repoRoot . '/' . $arg)) {
    $cloverPath = $repoRoot . '/' . $arg;
} else {
    $cloverPath = $repoRoot . '/' . trim($arg, '/') . '/var/data/phpunit-coverage/clover.xml';
}

if (!is_file($cloverPath)) {
    fwrite(STDERR, sprintf("coverage report not found: %s (run 'composer tests' first)\n", $cloverPath));
    exit(2);
}

$previous = libxml_use_internal_errors(true);
$xml = simplexml_load_file($cloverPath);
libxml_use_internal_errors($previous);

if ($xml === false) {
    fwrite(STDERR, sprintf("could not parse Clover XML: %s\n", $cloverPath));
    exit(2);
}

$rollup = $xml->project->metrics ?? null;
$totalStmt = $rollup !== null ? (int) ($rollup['statements'] ?? 0) : 0;
$totalCov = $rollup !== null ? (int) ($rollup['coveredstatements'] ?? 0) : 0;
$overall = $totalStmt > 0 ? ($totalCov / $totalStmt) * 100 : 100.0;

/** @var list<array{file: string, pct: float, uncovered: int}> $low */
$low = [];
foreach ($xml->xpath('//file') ?: [] as $file) {
    $m = $file->metrics ?? null;
    if ($m === null) {
        continue;
    }
    $s = (int) ($m['statements'] ?? 0);
    if ($s === 0) {
        continue; // nothing executable to cover
    }
    $c = (int) ($m['coveredstatements'] ?? 0);
    $pct = ($c / $s) * 100;
    if ($pct < $threshold) {
        $name = (string) ($file['name'] ?? '?');
        $low[] = ['file' => $name, 'pct' => $pct, 'uncovered' => $s - $c];
    }
}

usort($low, static fn(array $a, array $b): int => $a['pct'] <=> $b['pct']);

printf("coverage: %.2f%%  (%d/%d statements; %d uncovered)\n", $overall, $totalCov, $totalStmt, $totalStmt - $totalCov);

if ($low === []) {
    printf("✓ every file ≥ %.0f%%\n", $threshold);
    exit(0);
}

printf("✗ %d file(s) below %.0f%%:\n", count($low), $threshold);
foreach ($low as $row) {
    // Shorten the path to the component-relative tail for readability.
    $short = preg_replace('#^.*?/(src/.*)$#', '$1', $row['file']) ?? $row['file'];
    printf("   %6.2f%%  (%d uncovered)  %s\n", $row['pct'], $row['uncovered'], $short);
}
exit(1);
