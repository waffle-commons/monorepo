// bench/k6/lib/common.js — shared helpers for the beta6 AXE 5 tri-engine bench.
//
// Every scenario imports from here so that all engines are hit with byte-identical
// requests. TARGET selects the engine (http://engine-a | http://engine-b | http://engine-c),
// injected by scripts/run-bench.sh via `-e TARGET=...`.

import http from 'k6/http';
import crypto from 'k6/crypto';

export const BASE_URL = __ENV.TARGET || 'http://engine-a';

// Trend stats every scenario must expose (options.summaryTrendStats).
export const TREND_STATS = ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'p(99.9)', 'max'];

// Canonical workload names — keep in sync with run-bench.sh usage text.
export const WORKLOAD_NAMES = ['json', 'hello', 'greet', 'dbread', 'dbwrite'];

// "engine-a" from "http://engine-a" (also tolerates ports/paths).
export function engineName() {
  return BASE_URL.replace(/^https?:\/\//, '').replace(/[:/].*$/, '');
}

// ---------------------------------------------------------------------------
// Deterministic existing-id derivation for GET /read/demo
// ---------------------------------------------------------------------------
// RECONCILED 2026-08-02 against the real bench/sql/init.sql — that file is the
// SOURCE OF TRUTH for the seed, this helper follows it. The scheme, rows
// 1..10000, is:
//
//   id(n)    = md5('bench-user-' || n) formatted as a dashed lowercase UUID
//              (36 chars, fits users.id VARCHAR(36))
//   email(n) = 'user' || n || '@bench.waffle.local'
//
// An earlier draft of this file assumed md5(String(n)) instead — a silent
// mismatch that made EVERY /read/demo request a miss. Waffle answers a miss
// with 200 {"found":false}, so the corruption was invisible on Engine A while
// Engine B/C (404 on miss) failed loudly. If you change either side, re-run
// `./scripts/run-bench.sh <engine> smoke` and require dbread pass=100%.
// ---------------------------------------------------------------------------

export const SEEDED_ROWS = 10000;

export function existingId(rowNumber) {
  const hex = crypto.md5(`bench-user-${rowNumber}`, 'hex');
  return (
    hex.slice(0, 8) + '-' +
    hex.slice(8, 12) + '-' +
    hex.slice(12, 16) + '-' +
    hex.slice(16, 20) + '-' +
    hex.slice(20)
  );
}

export function randomSeededId() {
  const n = 1 + Math.floor(Math.random() * SEEDED_ROWS);
  return existingId(n);
}

// ---------------------------------------------------------------------------
// The 5 canonical workloads (identical routes on all three engines)
// ---------------------------------------------------------------------------

const JSON_HEADERS = { 'Content-Type': 'application/json' };

export const workloads = {
  // GET / — static JSON
  json: () => http.get(`${BASE_URL}/`),

  // GET /hello/{name} — JSON with routed param
  hello: () => http.get(`${BASE_URL}/hello/k6`),

  // POST /greet — JSON body -> validated DTO -> JSON
  greet: () =>
    http.post(`${BASE_URL}/greet`, JSON.stringify({ name: 'Ada' }), {
      headers: JSON_HEADERS,
    }),

  // GET /read/demo?id=<uuid> — SELECT by id from users (seeded ids only)
  dbread: () => http.get(`${BASE_URL}/read/demo?id=${randomSeededId()}`),

  // POST /write/demo — INSERT into users, server-generated values (empty body)
  dbwrite: () => http.post(`${BASE_URL}/write/demo`, null),
};

export function requireWorkload(name) {
  if (!Object.prototype.hasOwnProperty.call(workloads, name)) {
    throw new Error(
      `Unknown WORKLOAD "${name}" — expected one of: ${WORKLOAD_NAMES.join('|')}`
    );
  }
  return name;
}

// ---------------------------------------------------------------------------
// Summary export — /results/<engine>-<scenario>-<workload>.json
// ---------------------------------------------------------------------------
// The k6 service mounts ./results at /results (see docker-compose.bench.yml).
// `defaultWorkload` is used when the scenario has no single workload
// (smoke/soak = 'all', pool-starvation = 'db').

export function makeHandleSummary(scenario, defaultWorkload) {
  const workload = __ENV.WORKLOAD || defaultWorkload || 'all';
  const engine = engineName();
  const path = `/results/${engine}-${scenario}-${workload}.json`;

  return function (data) {
    // Embed run metadata so report.sh needs no filename archaeology.
    data.bench = {
      engine: engine,
      scenario: scenario,
      workload: workload,
      target: BASE_URL,
      env: {
        RATES: __ENV.RATES || null,
        STEP_DURATION: __ENV.STEP_DURATION || null,
        RATE: __ENV.RATE || null,
        DURATION: __ENV.DURATION || null,
      },
    };

    const reqs = data.metrics.http_reqs || { values: {} };
    const dur = data.metrics.http_req_duration || { values: {} };
    const failed = data.metrics.http_req_failed || { values: {} };
    const digest = [
      '',
      `bench summary  engine=${engine} scenario=${scenario} workload=${workload}`,
      `  http_reqs      count=${reqs.values.count} rate=${num(reqs.values.rate)}/s`,
      `  req duration   med=${num(dur.values.med)}ms p(95)=${num(dur.values['p(95)'])}ms ` +
        `p(99)=${num(dur.values['p(99)'])}ms p(99.9)=${num(dur.values['p(99.9)'])}ms`,
      `  http_req_failed rate=${num((failed.values.rate || 0) * 100)}%`,
      `  json -> ${path}`,
      '',
    ].join('\n');

    const out = { stdout: digest };
    out[path] = JSON.stringify(data, null, 2);
    return out;
  };
}

function num(v) {
  return v === undefined || v === null ? 'n/a' : Number(v).toFixed(2);
}

// Parse '2m' / '90s' / '1h30m' → seconds (used for ladder startTime math).
export function durationToSeconds(d) {
  const re = /(\d+(?:\.\d+)?)(h|m|s|ms)/g;
  let total = 0;
  let matched = false;
  let m;
  while ((m = re.exec(String(d))) !== null) {
    matched = true;
    const v = parseFloat(m[1]);
    if (m[2] === 'h') total += v * 3600;
    else if (m[2] === 'm') total += v * 60;
    else if (m[2] === 's') total += v;
    else total += v / 1000;
  }
  if (!matched) {
    const bare = parseFloat(String(d));
    if (!Number.isNaN(bare)) return bare; // bare number = seconds
    throw new Error(`Cannot parse duration "${d}"`);
  }
  return total;
}
