// bench/k6/scenarios/pool-starvation.js — BENCH-04 pool-starvation
// characterization (Engine A, PDOConnectionPool default size 8, DB_POOL_SIZE knob).
//
// ramping-vus 8 → 16 → 32 → 64 (held ~2 min each) against the DB workloads
// only (alternating dbwrite / dbread). Once concurrency exceeds the pool we
// EXPECT bounded fail-closed 5xx (DatabaseException) — those are COUNTED via
// the custom `pool_exhausted` Counter, not treated as scenario failure.
//
// What DOES fail the run: a hung request. http_req_duration p(99.9) must stay
// under 10 s or the test aborts (abortOnFail) — an unbounded lease queue or a
// deadlocked pool shows up here. Per-request timeout 15 s so a hang surfaces
// as a measurable timeout instead of blocking a VU forever.
//
// Cross-checks after the run (outside k6): /waffle-metrics pool-utilization
// gauges return to 0 (no leaked/severed connections) and ΔM = 0 on the RSS CSV.

import http from 'k6/http';
import exec from 'k6/execution';
import { Counter } from 'k6/metrics';
import {
  BASE_URL,
  randomSeededId,
  TREND_STATS,
  makeHandleSummary,
} from '../lib/common.js';

const poolExhausted = new Counter('pool_exhausted');

const REQ_PARAMS = { timeout: '15s' };

// Hold each concurrency level ~2 min (10 s ramp + 110 s plateau).
export const options = {
  scenarios: {
    starve: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 8 },
        { duration: '110s', target: 8 },
        { duration: '10s', target: 16 },
        { duration: '110s', target: 16 },
        { duration: '10s', target: 32 },
        { duration: '110s', target: 32 },
        { duration: '10s', target: 64 },
        { duration: '110s', target: 64 },
      ],
      gracefulRampDown: '30s',
      gracefulStop: '30s',
    },
  },
  summaryTrendStats: TREND_STATS,
  thresholds: {
    // The hang detector — the ONLY aborting threshold in the suite.
    http_req_duration: [
      { threshold: 'p(99.9)<10000', abortOnFail: true, delayAbortEval: '60s' },
    ],
    // Recording: how many requests hit the exhausted pool (expected > 0
    // at 32/64 VUs with pool=8 — that is the fail-closed behavior we want).
    pool_exhausted: ['count>=0'],
  },
  discardResponseBodies: true,
};

export default function () {
  const res =
    exec.scenario.iterationInTest % 2 === 0
      ? http.post(`${BASE_URL}/write/demo`, null, REQ_PARAMS)
      : http.get(`${BASE_URL}/read/demo?id=${randomSeededId()}`, REQ_PARAMS);

  if (res.status >= 500 || res.status === 0) {
    poolExhausted.add(1, { status: String(res.status) });
  }
}

export const handleSummary = makeHandleSummary('starve', 'db');
