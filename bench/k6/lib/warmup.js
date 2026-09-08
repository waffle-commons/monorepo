// bench/k6/lib/warmup.js — 30 s warmup pass over all 5 workloads.
// Fired by run-bench.sh BEFORE the measured scenario so opcache/JIT/pool are
// hot; produces NO summary JSON on purpose (never confuse it with a result).

import { sleep } from 'k6';
import { workloads, WORKLOAD_NAMES, TREND_STATS } from './common.js';

export const options = {
  vus: 5,
  duration: __ENV.WARMUP_DURATION || '30s',
  summaryTrendStats: TREND_STATS,
};

export default function () {
  for (const name of WORKLOAD_NAMES) {
    workloads[name]();
  }
  sleep(0.05);
}

export function handleSummary() {
  return { stdout: '\nwarmup done (no summary recorded)\n' };
}
