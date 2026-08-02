// bench/k6/scenarios/smoke.js — sanity pass: 30 s, 5 VUs, all 5 workloads.
// Purpose: prove an engine exposes the canonical routes correctly (no 403/404
// traps, DB reachable) before spending hours on BENCH-02/03/04.

import { check, sleep } from 'k6';
import {
  workloads,
  WORKLOAD_NAMES,
  TREND_STATS,
  makeHandleSummary,
} from '../lib/common.js';

export const options = {
  vus: 5,
  duration: '30s',
  summaryTrendStats: TREND_STATS,
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  for (const name of WORKLOAD_NAMES) {
    const res = workloads[name]();
    check(res, {
      [`${name}: status is 2xx`]: (r) => r.status >= 200 && r.status < 300,
    });
  }
  sleep(0.1);
}

export const handleSummary = makeHandleSummary('smoke', 'all');
