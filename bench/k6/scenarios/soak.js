// bench/k6/scenarios/soak.js — BENCH-03 leak soak (ΔM = 0 target).
//
// Fixed arrival rate (__ENV.RATE, default 150 rps) for __ENV.DURATION
// (default 2h), all 5 workloads in a WEIGHTED ROUND-ROBIN:
//   json 40 / hello 20 / greet 15 / dbread 15 / dbwrite 10  (per 100 reqs)
// The pattern is deterministic (indexed by the global iteration counter),
// not random — two soak runs issue the exact same request mix.
//
// The verdict itself comes from the RSS CSV sampled by sample-memory.sh
// (report.sh computes ΔM = mean(last 10 min) − mean(first 10 min post-warmup),
// PASS if |ΔM| ≤ max(1%, 5 MB)). Remember Trap 3: engine-a must run with
// MAX_REQUESTS=1000000 or worker recycling masks leaks.

import exec from 'k6/execution';
import {
  workloads,
  TREND_STATS,
  makeHandleSummary,
} from '../lib/common.js';

const RATE = parseInt(__ENV.RATE || '150', 10);
const DURATION = __ENV.DURATION || '2h';

// Weighted pattern, 20 slots == 100% (json 8/20 = 40%, hello 4/20 = 20%,
// greet 3/20 = 15%, dbread 3/20 = 15%, dbwrite 2/20 = 10%), interleaved so
// every 10-slot half already approximates the target mix.
const PATTERN = [
  'json', 'hello', 'json', 'greet', 'json', 'dbread', 'json', 'dbwrite',
  'hello', 'json', 'greet', 'json', 'dbread', 'hello', 'json', 'greet',
  'dbread', 'json', 'hello', 'dbwrite',
];

export const options = {
  scenarios: {
    soak: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.max(20, Math.ceil(RATE / 2)),
      maxVUs: RATE * 2,
      gracefulStop: '30s',
    },
  },
  summaryTrendStats: TREND_STATS,
  thresholds: {
    // Recording only — a soak must run to completion to measure drift.
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(99)<2000'],
  },
  discardResponseBodies: true,
};

export default function () {
  const name = PATTERN[exec.scenario.iterationInTest % PATTERN.length];
  workloads[name]();
}

export const handleSummary = makeHandleSummary('soak', 'all');
