// bench/k6/scenarios/memory-scaling.js — BENCH-05: memory as a function of
// CONCURRENCY (the experiment BENCH-02 could not perform).
//
// WHY THIS IS NOT constant-load.js
// --------------------------------
// BENCH-02 drives a constant ARRIVAL RATE (open model): k6 fires N requests per
// second regardless of how many are already in flight. That is the right model
// for latency percentiles, but it does not control the quantity the RAM claim
// is about — the number of requests being served CONCURRENTLY, which is what
// decides how many PHP-FPM children exist at any instant.
//
// This scenario is a closed model: `constant-vus` stages hold a FIXED number of
// in-flight requests, stepping 8 -> 16 -> 32 -> 64 -> 128. The RSS sampler runs
// alongside, so each step yields a (concurrency, RSS) point per engine and the
// run produces a curve rather than a single number:
//
//     RSS_fpm(c)    expected to climb ~linearly with c (one process per
//                   in-flight request, each with its own heap)
//     RSS_worker(c) expected to stay ~flat (a fixed worker set serves all c)
//
// The RAM factor is then read at the highest concurrency BOTH engines sustain
// — never at an arbitrary point, and never from a single aggregate number.
//
// Workload is `dbread`: it holds a real connection and does real work for the
// duration of the request, so a request in flight genuinely occupies a worker
// or child. A pure static-JSON route completes too fast to hold concurrency
// open and would understate every engine's process count.
import { check } from 'k6';
import { workloads, TREND_STATS, makeHandleSummary } from '../lib/common.js';

// Concurrency steps. Override with e.g. -e VUS_STEPS=8,32,128.
const VUS_STEPS = (__ENV.VUS_STEPS || '8,16,32,64,128')
  .split(',')
  .map((s) => parseInt(s.trim(), 10))
  .filter((n) => Number.isInteger(n) && n > 0);

const STEP_DURATION = __ENV.STEP_DURATION || '2m';

// One `constant-vus` scenario per step, chained back to back via startTime.
// Separate scenarios (rather than ramping-vus stages) keep each step's metrics
// tagged independently, so report.sh can slice RSS and latency per concurrency
// without inferring boundaries from timestamps.
function buildScenarios() {
  const scenarios = {};
  const stepSeconds = parseDurationSeconds(STEP_DURATION);
  VUS_STEPS.forEach((vus, i) => {
    scenarios[`c_${vus}`] = {
      executor: 'constant-vus',
      vus,
      duration: STEP_DURATION,
      startTime: `${i * stepSeconds}s`,
      gracefulStop: '10s',
      tags: { concurrency: String(vus) },
      exec: 'step',
    };
  });
  return scenarios;
}

function parseDurationSeconds(d) {
  const m = /^(\d+)(s|m|h)$/.exec(d);
  if (!m) throw new Error(`STEP_DURATION must look like 30s / 2m / 1h, got "${d}"`);
  const n = parseInt(m[1], 10);
  return m[2] === 's' ? n : m[2] === 'm' ? n * 60 : n * 3600;
}

export const options = {
  scenarios: buildScenarios(),
  summaryTrendStats: TREND_STATS,
  // Recording only: saturation at the top step is an expected, reportable
  // outcome of this experiment, not a failure to abort on.
  thresholds: {
    'http_req_duration{concurrency:8}': ['p(99)>=0'],
    'http_req_duration{concurrency:16}': ['p(99)>=0'],
    'http_req_duration{concurrency:32}': ['p(99)>=0'],
    'http_req_duration{concurrency:64}': ['p(99)>=0'],
    'http_req_duration{concurrency:128}': ['p(99)>=0'],
  },
};

export function step() {
  const res = workloads.dbread();
  check(res, { 'status is 2xx': (r) => r.status >= 200 && r.status < 300 });
  // No sleep: a closed model must keep exactly `vus` requests in flight for the
  // whole step, otherwise the concurrency axis is not what it claims to be.
}

export const handleSummary = makeHandleSummary('memscale', 'dbread');
