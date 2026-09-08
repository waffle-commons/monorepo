// bench/k6/lib/probe.js — single-shot readiness probe used by run-bench.sh.
// Exit code is non-zero (threshold failure) unless GET / answers 200, which
// lets the shell retry-loop from inside the compose network without needing
// curl/wget in any image.

import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL } from './common.js';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: { checks: ['rate==1'] },
};

export default function () {
  const res = http.get(`${BASE_URL}/`, { timeout: '3s' });
  check(res, { 'engine answers GET / with 200': (r) => r.status === 200 });
}

export function handleSummary() {
  return {}; // silence — this is plumbing, not a measurement
}
