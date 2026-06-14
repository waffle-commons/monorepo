<?php

declare(strict_types=1);

/**
 * SEC-03 timing-safe comparison gate (standalone runner).
 *
 * Reuses the unit-tested {@see \Waffle\Commons\Console\Audit\SensitiveComparisonScanner}
 * to ban naive `===` / `!==` between two runtime secrets (token, hmac, signature,
 * key, …) that must instead go through `hash_equals()`. Requires the scanner
 * sources directly (no Composer autoload) so it runs both inside the dev
 * container (via `wfl compare-audit`) and on a bare CI runner.
 *
 * Usage:  php scripts/sec03-compare-audit.php [component ...]
 * Default components: auth security http http-client data cache
 * Exit:   0 clean, 1 at least one finding (CI fails closed), 2 bad invocation.
 */

use Waffle\Commons\Console\Audit\SensitiveComparisonScanner;

$repoRoot = dirname(__DIR__);

$comparison = $repoRoot . '/console/src/Audit/SensitiveComparison.php';
$scannerSrc = $repoRoot . '/console/src/Audit/SensitiveComparisonScanner.php';

if (!is_file($comparison) || !is_file($scannerSrc)) {
    fwrite(STDERR, "SEC-03: console scanner sources not found — are submodules checked out?\n");
    exit(2);
}

require $comparison;
require $scannerSrc;

$components = array_slice($argv, 1);
if ($components === []) {
    $components = ['auth', 'security', 'http', 'http-client', 'data', 'cache'];
}

$scanner = new SensitiveComparisonScanner();
$total = 0;

foreach ($components as $component) {
    $dir = $repoRoot . '/' . $component . '/src';
    if (!is_dir($dir)) {
        fwrite(STDERR, sprintf("skip %s (no src)\n", $component));
        continue;
    }

    foreach ($scanner->scanDirectory($dir) as $finding) {
        ++$total;
        fwrite(STDERR, sprintf(
            "%s:%d  %s  (%s) — use hash_equals().\n",
            $finding->file,
            $finding->line,
            $finding->snippet,
            $finding->operator,
        ));
    }
}

if ($total === 0) {
    echo "SEC-03: no timing-unsafe comparisons.\n";
    exit(0);
}

fwrite(STDERR, sprintf("SEC-03: %d timing-unsafe comparison(s).\n", $total));
exit(1);
