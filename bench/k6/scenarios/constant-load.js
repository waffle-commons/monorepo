// bench/k6/scenarios/constant-load.js — BENCH-02 constant-arrival-rate ladder.
//
// One WORKLOAD per run (json|hello|greet|dbread|dbwrite), rates ladder from
// __ENV.RATES (default 50,100,200,400,800 rps), each step __ENV.STEP_DURATION
// (default 2m), run back-to-back via startTime offsets.
//
// Thresholds are RECORDING ONLY (never abortOnFail): the ladder must complete
// so the published table shows where each engine degrades. The per-scenario
// threshold tags also force k6 to emit per-step sub-metrics
// (http_req_duration{scenario:rate_N}) into the summary JSON — report.sh
// depends on those for the per-rate rows.

import {
  workloads,
  requireWorkload,
  TREND_STATS,
  makeHandleSummary,
  durationToSeconds,
} from '../lib/common.js';

const WORKLOAD = requireWorkload(__ENV.WORKLOAD || 'json');
const RATES = (__ENV.RATES || '50,100,200,400,800')
  .split(',')
  .map((r) => parseInt(r.trim(), 10))
  .filter((r) => r > 0);
const STEP_DURATION = __ENV.STEP_DURATION || '2m';
const STEP_SECONDS = durationToSeconds(STEP_DURATION);

const scenarios = {};
const thresholds = {
  http_req_failed: ['rate<0.05'], // recording only
};

RATES.forEach((rate, i) => {
  const name = `rate_${rate}`;
  scenarios[name] = {
    executor: 'constant-arrival-rate',
    rate: rate,
    timeUnit: '1s',
    duration: STEP_DURATION,
    startTime: `${Math.round(i * STEP_SECONDS)}s`,
    preAllocatedVUs: Math.max(10, rate), // sized to rate: 1 VU per rps handles up to 1 s of latency
    maxVUs: rate * 2,
    gracefulStop: '30s',
    exec: 'hit',
  };
  // Recording thresholds (generous bounds — we want the numbers, not an abort)
  // + they materialize per-step sub-metrics in the summary JSON.
  thresholds[`http_req_duration{scenario:${name}}`] = ['p(99)<2000'];
  thresholds[`http_req_failed{scenario:${name}}`] = ['rate<0.05'];
  thresholds[`http_reqs{scenario:${name}}`] = ['count>0'];
});

export const options = {
  scenarios: scenarios,
  summaryTrendStats: TREND_STATS,
  thresholds: thresholds,
  discardResponseBodies: true,
};

export function hit() {
  workloads[WORKLOAD]();
}

export const handleSummary = makeHandleSummary('constant', WORKLOAD);
