#!/usr/bin/env bash
# bench/scripts/report.sh — merge k6 summary JSONs + RSS CSVs into markdown.
#
#   usage: report.sh [results-dir]      (default: bench/results)
#
# Produces the tables that feed bench/BENCH-GATE-RESULT.md:
#   - per engine x scenario x workload x rate: p50/p95/p99/p99.9, achieved
#     req/s, error %, RSS mean/peak (per-rate RSS sliced from the CSV timeline
#     for constant-load ladders)
#   - RAM factor engine-b / engine-a (and engine-b / engine-c when present)
#   - BENCH-04 pool_exhausted counts
#   - BENCH-03 soak dM = mean(RSS last 10 min) - mean(RSS first 10 min
#     post-warmup); PASS if |dM| <= max(1%, 5 MB)
#
# Prints to stdout AND writes <results-dir>/REPORT.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${1:-$(dirname "$SCRIPT_DIR")/results}"

[[ -d "$RESULTS_DIR" ]] || { echo "error: results dir not found: $RESULTS_DIR" >&2; exit 1; }

python3 - "$RESULTS_DIR" <<'PY'
import csv, json, re, statistics, sys
from pathlib import Path

results = Path(sys.argv[1])
MB = 1024 * 1024

def dur_seconds(d, default=None):
    if d is None:
        return default
    d = str(d)
    parts = re.findall(r'(\d+(?:\.\d+)?)(h|m|s|ms)', d)
    if not parts:
        try:
            return float(d)
        except ValueError:
            return default
    mult = {'h': 3600, 'm': 60, 's': 1, 'ms': 0.001}
    return sum(float(v) * mult[u] for v, u in parts)

def fmt(v, nd=1):
    return 'n/a' if v is None else f'{v:.{nd}f}'

def load_mem(path):
    """[(epoch, used_bytes)] from a sampler CSV."""
    rows = []
    try:
        with open(path, newline='') as fh:
            for row in csv.DictReader(fh):
                try:
                    rows.append((int(row['epoch']), float(row['mem_used_bytes'])))
                except (KeyError, ValueError):
                    continue
    except FileNotFoundError:
        pass
    return sorted(rows)

def mem_stats(samples):
    if not samples:
        return (None, None)
    vals = [v for _, v in samples]
    return (statistics.fmean(vals) / MB, max(vals) / MB)

def slice_mem(samples, start_s, end_s):
    if not samples:
        return []
    t0 = samples[0][0]
    return [s for s in samples if start_s <= s[0] - t0 < end_s]

def trend(metrics, name):
    v = metrics.get(name, {}).get('values', {})
    return {k: v.get(k) for k in ('med', 'p(95)', 'p(99)', 'p(99.9)')}

runs, rows, factors_src = [], [], {}
for jf in sorted(results.glob('*.json')):
    try:
        data = json.loads(jf.read_text())
    except (json.JSONDecodeError, OSError):
        print(f'<!-- skipped unparseable {jf.name} -->', file=sys.stderr)
        continue
    bench = data.get('bench')
    if not bench:  # not one of ours
        continue
    engine, scenario, workload = bench['engine'], bench['scenario'], bench['workload']
    metrics = data.get('metrics', {})
    mem = load_mem(results / f'{engine}-{scenario}-{workload}-mem.csv')
    run_mem_mean, run_mem_peak = mem_stats(mem)
    runs.append({'engine': engine, 'scenario': scenario, 'workload': workload,
                 'mem': mem, 'mem_mean': run_mem_mean, 'mem_peak': run_mem_peak,
                 'metrics': metrics, 'env': bench.get('env') or {}})
    factors_src[(scenario, workload, engine)] = (run_mem_mean, run_mem_peak)

    if scenario == 'constant':
        env = bench.get('env') or {}
        rates = [int(r) for r in (env.get('RATES') or '50,100,200,400,800').split(',')]
        step_s = dur_seconds(env.get('STEP_DURATION'), 120.0)
        for i, rate in enumerate(rates):
            sub = f'{{scenario:rate_{rate}}}'
            t = trend(metrics, f'http_req_duration{sub}')
            count = metrics.get(f'http_reqs{sub}', {}).get('values', {}).get('count')
            errr = metrics.get(f'http_req_failed{sub}', {}).get('values', {}).get('rate')
            step_mem = slice_mem(mem, i * step_s, (i + 1) * step_s)
            m_mean, m_peak = mem_stats(step_mem)
            rows.append([engine, scenario, workload, str(rate),
                         fmt(count / step_s if count and step_s else None),
                         fmt(t['med']), fmt(t['p(95)']), fmt(t['p(99)']), fmt(t['p(99.9)']),
                         fmt(errr * 100 if errr is not None else None, 3),
                         fmt(m_mean), fmt(m_peak)])
    else:
        t = trend(metrics, 'http_req_duration')
        reqs = metrics.get('http_reqs', {}).get('values', {})
        errr = metrics.get('http_req_failed', {}).get('values', {}).get('rate')
        target = (bench.get('env') or {}).get('RATE') or ('150' if scenario == 'soak' else '-')
        rows.append([engine, scenario, workload, str(target),
                     fmt(reqs.get('rate')),
                     fmt(t['med']), fmt(t['p(95)']), fmt(t['p(99)']), fmt(t['p(99.9)']),
                     fmt(errr * 100 if errr is not None else None, 3),
                     fmt(run_mem_mean), fmt(run_mem_peak)])

out = []
out.append('# Bench report (generated by scripts/report.sh)\n')

out.append('## Latency / throughput / RSS — per engine x workload x rate\n')
out.append('| engine | scenario | workload | target rps | achieved req/s | p50 ms | p95 ms | p99 ms | p99.9 ms | err % | RSS mean MB | RSS peak MB |')
out.append('|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
for r in rows:
    out.append('| ' + ' | '.join(r) + ' |')
out.append('')
out.append('> constant-load RSS columns are sliced per rate step from the sampler')
out.append('> timeline; other scenarios show whole-run RSS.\n')

# RAM factor: engine-b (Symfony/FPM baseline) divided by the other engines.
out.append('## RAM factor (engine-b as numerator — target 5-10x vs engine-a)\n')
out.append('| scenario | workload | metric | engine-b / engine-a | engine-b / engine-c |')
out.append('|---|---|---|---:|---:|')
pairs = sorted({(s, w) for (s, w, _) in factors_src})
for s, w in pairs:
    b = factors_src.get((s, w, 'engine-b'))
    a = factors_src.get((s, w, 'engine-a'))
    c = factors_src.get((s, w, 'engine-c'))
    for idx, label in ((0, 'RSS mean'), (1, 'RSS peak')):
        fa = fmt(b[idx] / a[idx], 2) if b and a and b[idx] and a[idx] else 'n/a'
        fc = fmt(b[idx] / c[idx], 2) if b and c and b[idx] and c[idx] else 'n/a'
        if fa != 'n/a' or fc != 'n/a':
            out.append(f'| {s} | {w} | {label} | {fa} | {fc} |')
out.append('')

# BENCH-04 pool exhaustion counts.
starve = [r for r in runs if r['scenario'] == 'starve']
if starve:
    out.append('## BENCH-04 pool starvation (expected bounded 5xx once VUs > pool)\n')
    out.append('| engine | pool_exhausted (5xx count) | total reqs | p99.9 ms (hang detector, must be < 10000) |')
    out.append('|---|---:|---:|---:|')
    for r in starve:
        pe = r['metrics'].get('pool_exhausted', {}).get('values', {}).get('count', 0)
        total = r['metrics'].get('http_reqs', {}).get('values', {}).get('count')
        p999 = r['metrics'].get('http_req_duration', {}).get('values', {}).get('p(99.9)')
        out.append(f"| {r['engine']} | {int(pe)} | {int(total) if total else 'n/a'} | {fmt(p999)} |")
    out.append('')

# BENCH-03 soak dM.
WARMUP_SKIP_S, WINDOW_S = 600, 600
soaks = [r for r in runs if r['scenario'] == 'soak' and r['mem']]
if soaks:
    out.append('## BENCH-03 soak dM (leak verdict, PASS if |dM| <= max(1%, 5 MB))\n')
    out.append('| engine | first-window mean MB | last-window mean MB | dM MB | tolerance MB | verdict |')
    out.append('|---|---:|---:|---:|---:|---|')
    for r in soaks:
        mem = r['mem']
        span = mem[-1][0] - mem[0][0]
        if span < WARMUP_SKIP_S + 2 * WINDOW_S:
            out.append(f"| {r['engine']} | n/a | n/a | n/a | n/a | INSUFFICIENT DATA ({span}s sampled, "
                       f"need >= {WARMUP_SKIP_S + 2 * WINDOW_S}s) |")
            continue
        first = slice_mem(mem, WARMUP_SKIP_S, WARMUP_SKIP_S + WINDOW_S)
        last = slice_mem(mem, span - WINDOW_S, span + 1)
        m1, _ = mem_stats(first)
        m2, _ = mem_stats(last)
        dm = m2 - m1
        tol = max(0.01 * m1, 5.0)
        verdict = 'PASS' if abs(dm) <= tol else 'FAIL (drift -> AXE 2 native fix, not accepted)'
        out.append(f"| {r['engine']} | {fmt(m1)} | {fmt(m2)} | {fmt(dm, 2)} | {fmt(tol, 2)} | {verdict} |")
    out.append('')
    out.append(f'> dM windows: skip first {WARMUP_SKIP_S}s (warmup settle), compare the next '
               f'{WINDOW_S}s against the final {WINDOW_S}s. Engine-a must have run with '
               'MAX_REQUESTS=1000000 (Trap 3) for the verdict to be meaningful.\n')

report = '\n'.join(out) + '\n'
(results / 'REPORT.md').write_text(report)
print(report)
print(f'-- written to {results / "REPORT.md"} --', file=sys.stderr)
PY
