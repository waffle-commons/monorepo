<?php

declare(strict_types=1);

/**
 * Waffle Academy — rendu de la « carte de progression » (ACAD-02).
 *
 * Lit le rapport JUnit produit par PHPUnit, croise l'état des implémentations
 * (`labs/src/Lesson0NMM/`) avec les corrigés disponibles (`labs/solutions/`) et
 * affiche une carte terminale, colorisée et synthétique, par leçon.
 *
 * Usage : php scripts/academy-card.php <junit.xml> <labsRoot> <magoStatus> [labFilter]
 *   - magoStatus ∈ { ok, ko, skip } : résultat du gate statique (mago + guard).
 *   - labFilter (optionnel) : jeton « N_MM » quand seul un lab a été exécuté.
 *
 * Aucune dépendance : invoqué tel quel par `wfl academy:test`.
 */

$junitPath = $argv[1] ?? '';
$labsRoot = rtrim($argv[2] ?? '', '/');
$magoStatus = $argv[3] ?? 'skip';
$labFilter = $argv[4] ?? '';

const C_RESET = "\033[0m";
const C_BOLD = "\033[1m";
const C_DIM = "\033[2m";
const C_GREEN = "\033[32m";
const C_RED = "\033[31m";
const C_AMBER = "\033[33m";
const C_CYAN = "\033[36m";

const WIDTH = 60;

/** @return list<array{token: string, num: string, title: string, dir: string}> */
function discoverLabs(string $labsRoot): array
{
    $labs = [];
    foreach (glob($labsRoot . '/tests/Lesson_*Test.php') ?: [] as $file) {
        $base = basename($file, '.php');
        if (preg_match('/^Lesson_(\d+)_(\d+)_(.+)Test$/', $base, $m) !== 1) {
            continue;
        }
        $level = $m[1];
        $lesson = $m[2];
        $labs[] = [
            'token' => "{$level}_{$lesson}",
            'num' => "{$level}.{$lesson}",
            'title' => str_replace('_', ' ', $m[3]),
            'dir' => $labsRoot . '/src/Lesson0' . $level . $lesson,
        ];
    }
    usort($labs, static fn(array $a, array $b): int => strnatcmp($a['token'], $b['token']));

    return $labs;
}

/**
 * Agrège les résultats JUnit par jeton « N_MM ».
 *
 * @return array<string, array{tests: int, failed: int}>
 */
function parseJunit(string $junitPath): array
{
    $results = [];
    if (!is_file($junitPath)) {
        return $results;
    }
    $previous = libxml_use_internal_errors(true);
    $xml = simplexml_load_file($junitPath);
    libxml_use_internal_errors($previous);
    if ($xml === false) {
        return $results;
    }

    foreach ($xml->xpath('//testcase') ?: [] as $case) {
        $haystack = (string) ($case['class'] ?? '') . ' ' . (string) ($case['name'] ?? '');
        if (preg_match('/(\d+_\d+)/', $haystack, $m) !== 1) {
            continue;
        }
        $token = $m[1];
        $results[$token] ??= ['tests' => 0, 'failed' => 0];
        ++$results[$token]['tests'];
        if (isset($case->failure) || isset($case->error)) {
            ++$results[$token]['failed'];
        }
    }

    return $results;
}

function statusFor(bool $implemented, ?array $result): string
{
    if (!$implemented) {
        return 'pending';
    }
    if ($result === null || $result['tests'] === 0) {
        return 'norun';
    }

    return $result['failed'] > 0 ? 'fail' : 'pass';
}

function rule(string $char = '─'): string
{
    return C_DIM . str_repeat($char, WIDTH) . C_RESET;
}

$labs = discoverLabs($labsRoot);
$results = parseJunit($junitPath);

$icons = ['pass' => '✅', 'fail' => '❌', 'pending' => '⬜', 'norun' => '⚪'];
$notes = [
    'pass' => C_GREEN . 'réussi' . C_RESET,
    'fail' => C_RED . 'échec' . C_RESET,
    'pending' => C_AMBER . 'à faire' . C_RESET,
    'norun' => C_DIM . 'non exécuté' . C_RESET,
];
$tally = ['pass' => 0, 'fail' => 0, 'pending' => 0, 'norun' => 0];

echo "\n" . C_BOLD . '🧇  Waffle Academy — Carte de progression' . C_RESET;
echo $labFilter !== '' ? C_DIM . "  (filtre : {$labFilter})" . C_RESET . "\n" : "\n";
echo rule() . "\n";

if ($labs === []) {
    echo '  ' . C_AMBER . 'Aucun lab détecté dans labs/tests/.' . C_RESET . "\n";
    echo rule() . "\n";

    return;
}

$levelTitles = [
    '1' => 'Rookie · Fondations PHP 8.5',
    '2' => 'Sentinel · Cycle de vie & PSR-15',
    '3' => 'Ranger · Injection & Routing',
    '4' => 'Guardian · Sécurité & ABAC',
    '5' => 'Master · Observabilité & pooling',
];

$currentLevel = '';
foreach ($labs as $lab) {
    $level = explode('_', $lab['token'])[0];
    if ($level !== $currentLevel) {
        $currentLevel = $level;
        $title = $levelTitles[$level] ?? '';
        $suffix = $title !== '' ? C_DIM . " — {$title}" . C_RESET : '';
        echo "\n" . C_BOLD . "  Niveau {$level}" . C_RESET . $suffix . "\n";
    }

    $implemented = is_dir($lab['dir']) && (glob($lab['dir'] . '/*.php') ?: []) !== [];
    $status = statusFor($implemented, $results[$lab['token']] ?? null);
    ++$tally[$status];

    $label = C_CYAN . $lab['num'] . C_RESET . '  ' . mb_str_pad($lab['title'], 32);
    echo '   ' . $icons[$status] . '  ' . $label . ' ' . $notes[$status] . "\n";
}

echo "\n" . rule() . "\n";
printf(
    "  Progression : %s%d/%d réussis%s · %d échec · %d à faire\n",
    C_BOLD,
    $tally['pass'],
    count($labs),
    C_RESET,
    $tally['fail'],
    $tally['pending'] + $tally['norun'],
);

$cleanliness = match ($magoStatus) {
    'ok' => C_GREEN . '✅ zéro problème' . C_RESET,
    'ko' => C_RED . '❌ problèmes détectés' . C_RESET . C_DIM . ' (lancez « composer mago »)' . C_RESET,
    default => C_DIM . '— non vérifié' . C_RESET,
};
echo '  Propreté du code (mago + guard) : ' . $cleanliness . "\n";
echo rule() . "\n";
