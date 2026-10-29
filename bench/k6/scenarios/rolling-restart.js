// bench/k6/scenarios/rolling-restart.js — the load of the rolling-restart check
// (scripts/rolling-restart.sh, OPS acceptance).
//
// A constant arrival rate (RATE, default 100 rps) through the load balancer for
// DURATION (default 75s), cycling through the five bench workloads, while the
// script drains, stops and restarts each replica in turn. The check passes only
// if every request answers 2xx. The thresholds record; they never abort, so the
// run always covers the whole restart window. Each failed request is logged with
// its time, so it can be matched against the script's events.

import { check } from 'k6';
import exec from 'k6/execution';
import { Counter } from 'k6/metrics';
import { workloads, WORKLOAD_NAMES, TREND_STATS } from '../lib/common.js';

const RATE = parseInt(__ENV.RATE || '100', 10);
const DURATION = __ENV.DURATION || '75s';
const REPLICAS = ['app-1', 'app-2'];

const servedBy = new Counter('served_by');

const thresholds = {
  http_req_failed: ['rate==0'],
  checks: ['rate==1'],
};
// Per-replica sub-metrics: both replicas must have served traffic.
for (const replica of REPLICAS) {
  thresholds[`served_by{upstream:${replica}}`] = ['count>0'];
}

export const options = {
  scenarios: {
    rolling: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.max(10, RATE),
      maxVUs: Math.max(20, RATE * 2),
      gracefulStop: '30s',
    },
  },
  summaryTrendStats: TREND_STATS,
  thresholds: thresholds,
};

export default function () {
  const name = WORKLOAD_NAMES[exec.scenario.iterationInTest % WORKLOAD_NAMES.length];
  const res = workloads[name]();
  const upstream = res.headers['X-Upstream'] || 'none';
  const ok = res.status >= 200 && res.status < 300;

  check(res, { 'status is 2xx': () => ok });
  servedBy.add(1, { upstream: upstream });
  if (!ok) {
    console.warn(JSON.stringify({
      at: new Date().toISOString(),
      workload: name,
      status: res.status,
      error: res.error || null,
      upstream: upstream,
    }));
  }
}

export function handleSummary(data) {
  const count = (metric) => (data.metrics[metric] ? data.metrics[metric].values : {});
  const failed = count('http_req_failed');
  const lines = [
    '',
    `rolling-restart  rate=${RATE}/s duration=${DURATION}`,
    `  requests   ${count('http_reqs').count || 0}`,
    `  failed     ${failed.passes || 0}`,
  ];
  for (const replica of REPLICAS) {
    lines.push(`  ${replica}      ${count(`served_by{upstream:${replica}}`).count || 0} served`);
  }
  lines.push('');

  const out = { stdout: lines.join('\n') };
  if (__ENV.OUT) {
    out[__ENV.OUT] = JSON.stringify(data, null, 2);
  }
  return out;
}
