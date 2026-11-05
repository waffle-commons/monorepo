# BENCH-GATE-RESULT — tri-engine k6 benchmark

> Two series live in this file. The **Beta7 re-measurement** (November 2026, FrankenPHP 1.13.2, `[CARRY-02]`) is
> the current one and comes first. The **Beta6 record** (August–September 2026, FrankenPHP 1.12.2) follows as it
> was written: its figures ran a skeleton image that did not preload 70 framework classes (`[CARRY-08]`), on a rig
> whose Engine C recycled its workers every 500 requests, so they are not quoted as current.

# Beta7 re-measurement — FrankenPHP 1.13.2 (`[CARRY-02]`, November 2026)

A **new series**, not a correction of the beta6 sections below: those were measured on FrankenPHP 1.12.2, with a
skeleton image that did not preload 70 framework classes (`[CARRY-08]`), on a rig without an equal-features
Symfony engine. Run `carry02-20261101T015247Z` (2026-11-01, 01:52–08:19 UTC) is the full chain on the hardened
rig (`[CARRY-02]`: run-unique series, a host record per run, soak slopes with their 95 % bound, Engine C on
Symfony's native worker runner, Engine D added), on a laptop checked idle against its power log for the whole
window.

**Environment.** Intel i7-9750H (6 cores / 12 threads, 16 GB), Docker Desktop 29.9.2 (12 vCPU / 13.6 GiB VM).
Every engine at 2 CPUs and 1 GiB (6 GiB for BENCH-05). A (Waffle skeleton, production image), C (Symfony) and D
(Symfony with A's per-request work: trusted hosts, CORS, firewall, per-action authorisation, stateless CSRF,
headers, one transaction per unsafe request) on FrankenPHP 1.13.2 / PHP 8.5.12 with 4 workers and
`MAX_REQUESTS` / `FRANKENPHP_LOOP_MAX` 1 000 000; B (the same Symfony app) on `php:8.5.12-fpm` + nginx. k6 2.3.0
on the host. Images pinned by digest (umbrella `ef92b0a`). Memory figures are MiB throughout (`report.sh` prints
them as "MB" but divides by 1 024²). Raw data, in a local archive (k6 summaries, RSS series, host records, the
power log): `project_system/Audits/Beta7/bench/carry02-20261101T015247Z/`. The processed tables are reproduced
below, under *Report*.

## `[BENCH-02]` Constant arrival rate — median / p99 latency, ms

Every engine held every rate with 0 errors. Two minutes per step, so a p99 rests on the slowest 1 % of 6 000 to
96 000 requests; p99.9 values are in the *Report* below and are indicative only.

| Rate | json A / C / D | dbread A / C / D | dbwrite A / C / D |
|---:|---|---|---|
| 50 | 2.1/2.9 · 2.2/2.9 · 2.3/3.1 | 3.4/4.7 · 2.9/3.9 · 3.0/4.0 | 3.8/5.3 · 3.2/4.2 · 3.4/4.5 |
| 100 | 2.1/2.7 · 2.1/2.7 · 2.2/2.8 | 3.1/4.2 · 2.7/3.4 · 2.8/3.6 | 3.4/4.6 · 3.0/3.9 · 3.1/4.0 |
| 200 | 1.5/2.2 · 1.5/2.2 · 1.5/2.3 | 2.2/3.2 · 1.9/2.7 · 2.0/3.3 | 2.2/3.4 · 2.1/3.1 · 2.2/3.1 |
| 400 | 0.9/1.6 · 0.9/1.6 · 0.9/1.7 | 1.4/3.0 · 1.1/2.4 · 1.2/2.5 | 1.5/3.6 · 1.3/2.6 · 1.3/2.8 |
| 800 | 0.8/1.7 · 0.8/1.8 · 0.9/2.0 | *flagged* · 1.2/3.0 · 1.4/3.5 | 1.8/4.1 · 1.3/3.2 · 1.5/3.6 |

*Flagged:* A's dbread step at 800 rps overlapped a macOS Contacts sync (02:18:11–02:19:47 UTC, 95 s of the 120 s
step; p99 61.3 ms). It is not published.

- **JSON: parity.** Waffle answers like a bare Symfony app on the same runtime, and at least as fast as Symfony
  doing the same per-request work.
- **Database: Waffle is slower.** Against D (the same work), by 0.3–0.4 ms at the median at 50–100 rps and by
  0–0.3 ms at 200–800 rps, with a p99 up to 0.8 ms above D's. The cause is not investigated yet (beta8).
- **Memory:** A's RSS is 7.7–10 MiB below D's at every rate.

## `[BENCH-05]` Memory vs concurrency — RSS by concurrency, MiB

Closed model, `constant-vus` 8 → 128, 2 min each, workload `dbread`; CPU pinned at 2, memory at 6 GiB, FPM on
`pm = dynamic`.

| Concurrency | A — Waffle | B — Symfony FPM | C — Symfony worker | D — Symfony worker, A's features | B/A |
|---:|---:|---:|---:|---:|---:|
| 8 | 70.4 | 61.3 | 78.2 | 78.2 | **0.87×** |
| 16 | 72.8 | 75.5 | 78.3 | 78.5 | 1.04× |
| 32 | 76.0 | 101.2 | 81.6 | 81.1 | 1.33× |
| 64 | 78.9 | 146.4 | 86.3 | 87.4 | 1.86× |
| 128 | 85.4 | 240.3 | 91.3 | 92.0 | **2.81×** |
| **Slope per concurrent request** | **+0.118** | **+1.478** | +0.113 | +0.121 | |

**FPM's memory grows 12.5× faster per concurrent request than Waffle's** (beta6: 10.5×). Below about 14 concurrent
requests FPM uses less memory; the fitted lines cross at ≈14; at 128 it uses 2.81× as much. The worker runtimes
(A, C, D) all grow at about the same rate: the slope is the runtime's, not the framework's.

Throughput under this saturation (secondary): A 1 676, C 2 029, D 1 825 req/s; B 118.5 req/s with 1.16 % errors.
At equal features, A is 8 % below D — consistent with its slower database path — while using 5–8.5 MiB less
memory at every step.

## `[BENCH-03]` Soak — 150 rps × 2 h (C and D)

| Engine | Requests (per worker) | Slope, settled window | ΔM | p99 | Errors | Verdict |
|---|---:|---:|---:|---:|---:|---|
| C | 1 080 001 (≈270 000) | +0.15 ± 0.11 MiB/h (n = 1 057) | −1.0 MiB | 3.2 ms | 0 | PASS |
| D | 1 080 001 (≈270 000) | −1.00 ± 0.12 MiB/h (n = 1 056) | −3.7 MiB | 3.5 ms | 0 | PASS |

No recycle was possible (loop limit 1 000 000); RSS was sampled every 6 s with no gap. The bounds are understated
by autocorrelation, and 2 h is not a multi-hour claim: flat within the instrument over the window, nothing more.
These soaks validate the corrected Symfony engines; Waffle's own endurance claim waits for beta8's 72-hour soak.

## What this run does not establish

- **Capacity.** One laptop, the load generator on the same host, 2 CPUs per engine: every figure is a relative
  comparison on this rig.
- **Multi-hour stability.** The soaks are 2 h.
- **Why Waffle's database path is slower than D's.** A beta8 performance question.

## How to quote it

- Memory: "FPM's memory grows about 12× faster per concurrent request than Waffle's on FrankenPHP; FPM uses less
  below ~14 concurrent requests and 2.8× more at 128" — with this method, never a bare "N× less RAM".
- Latency: "parity with Symfony on the same runtime for JSON responses; a few tenths of a millisecond slower on
  database-backed requests", with the rate and the rig.

## Invalidated series (kept, not published)

- `carry02-20261031T164459Z` — the first full run: documentation work on the laptop during BENCH-02, video playback
  during BENCH-05 and the soaks, a lid close with a brief sleep at 18:52 UTC.
- `carry02-20261101T000522Z` — the BENCH-02 re-run: audio and a video over C's and D's json runs.

## Report — `bench/scripts/report.sh` output for run `carry02-20261101T015247Z`

The generated tables, unedited. The `engine-a` dbread row at 800 rps is the flagged step (a macOS Contacts sync)
and is not published; "MB" in these tables means MiB.


### Latency / throughput / RSS — per engine x workload x rate

| run | engine | scenario | workload | target rps | achieved req/s | p50 ms | p95 ms | p99 ms | p99.9 ms | err % | RSS mean MB | RSS peak MB |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 20261101T015311Z | engine-a | smoke | all | - | 218.0 | 2.7 | 3.9 | 4.7 | 6.6 | 0.000 | 70.2 | 70.3 |
| 20261101T015424Z | engine-b | smoke | all | - | 165.9 | 3.9 | 22.3 | 25.4 | 30.5 | 0.000 | 67.8 | 68.0 |
| 20261101T015530Z | engine-c | smoke | all | - | 219.6 | 2.4 | 3.8 | 4.7 | 7.2 | 0.000 | 76.3 | 76.7 |
| 20261101T015636Z | engine-d | smoke | all | - | 217.2 | 2.7 | 4.0 | 4.8 | 7.0 | 0.000 | 75.8 | 76.1 |
| 20261101T015819Z | engine-a | constant | json | 50 | 50.0 | 2.1 | 2.6 | 2.9 | 4.5 | 0.000 | 71.9 | 72.8 |
| 20261101T015819Z | engine-a | constant | json | 100 | 100.0 | 2.1 | 2.4 | 2.7 | 3.9 | 0.000 | 75.5 | 77.1 |
| 20261101T015819Z | engine-a | constant | json | 200 | 200.0 | 1.5 | 1.9 | 2.2 | 3.4 | 0.000 | 83.6 | 84.3 |
| 20261101T015819Z | engine-a | constant | json | 400 | 400.0 | 0.9 | 1.2 | 1.6 | 3.8 | 0.000 | 99.8 | 100.7 |
| 20261101T015819Z | engine-a | constant | json | 800 | 800.0 | 0.8 | 1.1 | 1.7 | 7.6 | 0.000 | 122.1 | 123.5 |
| 20261101T020905Z | engine-a | constant | dbread | 50 | 50.0 | 3.4 | 4.0 | 4.7 | 7.8 | 0.000 | 72.1 | 72.9 |
| 20261101T020905Z | engine-a | constant | dbread | 100 | 100.0 | 3.1 | 3.7 | 4.2 | 7.7 | 0.000 | 74.9 | 75.4 |
| 20261101T020905Z | engine-a | constant | dbread | 200 | 200.0 | 2.2 | 2.7 | 3.2 | 8.0 | 0.000 | 83.8 | 84.6 |
| 20261101T020905Z | engine-a | constant | dbread | 400 | 400.0 | 1.4 | 1.9 | 3.0 | 10.0 | 0.000 | 99.8 | 100.6 |
| 20261101T020905Z | engine-a | constant | dbread | 800 | 800.0 | 2.5 | 5.2 | 61.3 | 149.4 | 0.000 | 122.1 | 123.4 |
| 20261101T021947Z | engine-a | constant | dbwrite | 50 | 50.0 | 3.8 | 4.6 | 5.3 | 9.1 | 0.000 | 72.1 | 72.8 |
| 20261101T021947Z | engine-a | constant | dbwrite | 100 | 100.0 | 3.4 | 4.0 | 4.6 | 7.3 | 0.000 | 75.4 | 75.8 |
| 20261101T021947Z | engine-a | constant | dbwrite | 200 | 200.0 | 2.2 | 2.9 | 3.4 | 8.9 | 0.000 | 84.5 | 85.2 |
| 20261101T021947Z | engine-a | constant | dbwrite | 400 | 400.0 | 1.5 | 2.4 | 3.6 | 9.6 | 0.000 | 100.3 | 101.1 |
| 20261101T021947Z | engine-a | constant | dbwrite | 800 | 800.0 | 1.8 | 2.8 | 4.1 | 12.6 | 0.000 | 123.0 | 124.1 |
| 20261101T023030Z | engine-c | constant | json | 50 | 50.0 | 2.2 | 2.6 | 2.9 | 3.8 | 0.000 | 73.6 | 74.4 |
| 20261101T023030Z | engine-c | constant | json | 100 | 100.0 | 2.1 | 2.4 | 2.7 | 3.9 | 0.000 | 76.7 | 77.2 |
| 20261101T023030Z | engine-c | constant | json | 200 | 200.0 | 1.5 | 1.9 | 2.2 | 3.7 | 0.000 | 85.6 | 86.0 |
| 20261101T023030Z | engine-c | constant | json | 400 | 400.0 | 0.9 | 1.3 | 1.6 | 3.9 | 0.000 | 101.6 | 102.1 |
| 20261101T023030Z | engine-c | constant | json | 800 | 800.0 | 0.8 | 1.2 | 1.8 | 7.5 | 0.000 | 124.1 | 124.8 |
| 20261101T024112Z | engine-c | constant | dbread | 50 | 50.0 | 2.9 | 3.4 | 3.9 | 5.4 | 0.000 | 76.2 | 76.6 |
| 20261101T024112Z | engine-c | constant | dbread | 100 | 100.0 | 2.7 | 3.1 | 3.4 | 5.9 | 0.000 | 81.5 | 82.1 |
| 20261101T024112Z | engine-c | constant | dbread | 200 | 200.0 | 1.9 | 2.4 | 2.7 | 5.7 | 0.000 | 90.4 | 91.1 |
| 20261101T024112Z | engine-c | constant | dbread | 400 | 400.0 | 1.1 | 1.6 | 2.4 | 6.7 | 0.000 | 106.5 | 107.2 |
| 20261101T024112Z | engine-c | constant | dbread | 800 | 800.0 | 1.2 | 1.9 | 3.0 | 12.5 | 0.000 | 127.5 | 128.6 |
| 20261101T025149Z | engine-c | constant | dbwrite | 50 | 50.0 | 3.2 | 3.8 | 4.2 | 7.3 | 0.000 | 78.1 | 78.7 |
| 20261101T025149Z | engine-c | constant | dbwrite | 100 | 100.0 | 3.0 | 3.5 | 3.9 | 6.6 | 0.000 | 82.4 | 82.9 |
| 20261101T025149Z | engine-c | constant | dbwrite | 200 | 200.0 | 2.1 | 2.6 | 3.1 | 6.4 | 0.000 | 91.6 | 92.2 |
| 20261101T025149Z | engine-c | constant | dbwrite | 400 | 400.0 | 1.3 | 1.7 | 2.6 | 8.2 | 0.000 | 107.4 | 108.4 |
| 20261101T025149Z | engine-c | constant | dbwrite | 800 | 800.0 | 1.3 | 2.1 | 3.2 | 11.8 | 0.000 | 130.0 | 130.9 |
| 20261101T030231Z | engine-d | constant | json | 50 | 50.0 | 2.3 | 2.8 | 3.1 | 4.0 | 0.000 | 81.9 | 82.3 |
| 20261101T030231Z | engine-d | constant | json | 100 | 100.0 | 2.2 | 2.6 | 2.8 | 4.2 | 0.000 | 86.5 | 87.2 |
| 20261101T030231Z | engine-d | constant | json | 200 | 200.0 | 1.5 | 2.0 | 2.3 | 3.8 | 0.000 | 95.7 | 96.5 |
| 20261101T030231Z | engine-d | constant | json | 400 | 400.0 | 0.9 | 1.2 | 1.7 | 4.8 | 0.000 | 111.3 | 112.1 |
| 20261101T030231Z | engine-d | constant | json | 800 | 800.0 | 0.9 | 1.3 | 2.0 | 8.1 | 0.000 | 132.1 | 132.9 |
| 20261101T031314Z | engine-d | constant | dbread | 50 | 50.0 | 3.0 | 3.5 | 4.0 | 5.9 | 0.000 | 79.8 | 80.3 |
| 20261101T031314Z | engine-d | constant | dbread | 100 | 100.0 | 2.8 | 3.3 | 3.6 | 5.4 | 0.000 | 84.6 | 85.1 |
| 20261101T031314Z | engine-d | constant | dbread | 200 | 200.0 | 2.0 | 2.6 | 3.3 | 6.4 | 0.000 | 91.8 | 92.2 |
| 20261101T031314Z | engine-d | constant | dbread | 400 | 400.0 | 1.2 | 1.7 | 2.5 | 7.3 | 0.000 | 109.4 | 110.3 |
| 20261101T031314Z | engine-d | constant | dbread | 800 | 800.0 | 1.4 | 2.3 | 3.5 | 13.2 | 0.000 | 129.8 | 130.8 |
| 20261101T032356Z | engine-d | constant | dbwrite | 50 | 50.0 | 3.4 | 4.0 | 4.5 | 7.9 | 0.000 | 80.8 | 82.2 |
| 20261101T032356Z | engine-d | constant | dbwrite | 100 | 100.0 | 3.1 | 3.7 | 4.0 | 6.1 | 0.000 | 84.4 | 84.9 |
| 20261101T032356Z | engine-d | constant | dbwrite | 200 | 200.0 | 2.2 | 2.8 | 3.1 | 6.5 | 0.000 | 93.4 | 94.0 |
| 20261101T032356Z | engine-d | constant | dbwrite | 400 | 400.0 | 1.3 | 1.9 | 2.8 | 8.3 | 0.000 | 109.5 | 110.5 |
| 20261101T032356Z | engine-d | constant | dbwrite | 800 | 800.0 | 1.5 | 2.4 | 3.6 | 11.5 | 0.000 | 131.8 | 132.8 |
| 20261101T033439Z | engine-a-mem | memscale | dbread | - | 1675.8 | 17.5 | 83.1 | 88.1 | 103.1 | 0.000 | 76.7 | 85.9 |
| 20261101T034521Z | engine-b-dyn | memscale | dbread | - | 118.5 | 274.9 | 1304.2 | 1702.1 | 2143.3 | 1.164 | 125.6 | 261.5 |
| 20261101T035558Z | engine-c-mem | memscale | dbread | - | 2029.3 | 17.3 | 71.7 | 77.7 | 92.5 | 0.000 | 83.2 | 92.1 |
| 20261101T040641Z | engine-d-mem | memscale | dbread | - | 1824.8 | 17.2 | 80.6 | 86.3 | 100.8 | 0.000 | 83.5 | 92.4 |
| 20261101T041722Z | engine-c | soak | all | 150 | 150.0 | 1.8 | 2.9 | 3.2 | 4.6 | 0.000 | 79.5 | 81.6 |
| 20261101T061804Z | engine-d | soak | all | 150 | 150.0 | 2.0 | 3.2 | 3.5 | 5.1 | 0.000 | 84.2 | 87.1 |

> constant-load RSS columns are sliced per rate step from the sampler
> timeline; other scenarios show whole-run RSS.

### Runs and hosts (CARRY-02: the hardware travels with every run)

| run | engine | host CPU | cores | RAM GB | Docker VM CPUs / RAM GB | engine CPUs / RAM GB | umbrella commit |
|---|---|---|---:|---:|---:|---:|---|
| 20261101T015311Z | engine-a | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T015424Z | engine-b | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T015530Z | engine-c | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T015636Z | engine-d | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T015819Z | engine-a | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T020905Z | engine-a | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T021947Z | engine-a | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T023030Z | engine-c | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T024112Z | engine-c | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T025149Z | engine-c | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T030231Z | engine-d | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T031314Z | engine-d | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T032356Z | engine-d | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T033439Z | engine-a-mem | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 6.00 | 8a77f30788 |
| 20261101T034521Z | engine-b-dyn | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 6.00 | 8a77f30788 |
| 20261101T035558Z | engine-c-mem | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 6.00 | 8a77f30788 |
| 20261101T040641Z | engine-d-mem | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 6.00 | 8a77f30788 |
| 20261101T041722Z | engine-c | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |
| 20261101T061804Z | engine-d | Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz | 12 | 16.0 | 12 / 13.6 | 2.00 / 1.00 | 8a77f30788 |

### RSS ratio at pinned, bounded concurrency — NOT the 5-10x claim

> **Do not quote these as the RAM factor.** BENCH-02 pre-forks FPM at a fixed 16
> children and caps every engine at 1 GiB, which flattens FPM's memory curve before
> the first sample. These ratios describe this rig, not the runtimes. The 5-10x claim
> is tested by BENCH-05 (`run-bench.sh engine-b-dyn memscale`), which pins only CPU,
> lets memory grow, and switches FPM to a dynamic pool.

| scenario | workload | metric | engine-b / engine-a | engine-b / engine-c |
|---|---|---|---:|---:|
| smoke | all | RSS mean | 0.97 | 0.89 |
| smoke | all | RSS peak | 0.97 | 0.89 |

### BENCH-03 soak dM (leak verdict, PASS if |dM| <= max(1%, 5 MB))

| run | engine | span | first-window mean MB | last-window mean MB | dM MB | tolerance MB | slope MB/h ± 95 % (n) | verdict |
|---|---|---:|---:|---:|---:|---:|---:|---|
| 20261101T041722Z | engine-c | 120min | 79.4 | 78.4 | -1.03 | 5.00 | +0.15 ± 0.11 (n=1057) | PASS (bounds leak rate at ~2 MB/h — window is 120min, not multi-hour) |
| 20261101T061804Z | engine-d | 119min | 84.6 | 80.8 | -3.74 | 5.00 | -1.00 ± 0.12 (n=1056) | PASS (bounds leak rate at ~3 MB/h — window is 119min, not multi-hour) |

> dM windows adapt to the sampled span: settle for 20% (max 10min), then compare that window against the final one (30% of span, max 10min). Engine-a must have run with MAX_REQUESTS=1000000 (Trap 3) or worker recycling masks a leak. `docker stats` quantises to ~0.1 MiB, so treat sub-MB deltas as flat, not as precision.

> The slope is the least-squares fit of RSS over the settled window (everything after the settle), with its 95 % bound (Student t). RSS samples are autocorrelated, so the bound understates the true uncertainty: a leak claim needs the whole interval above zero, and a flat run is "no leak above this rate", not "no leak" (AGENTS.md §7).

---

# Beta6 AXE 5 (tri-engine k6 benchmark) — as recorded, August–September 2026

- **Date:** 2026-08-02 / 2026-08-03 (full-length soaks) · Engine C corrections recorded 2026-09-23
- **Subject:** `waffle-commons/skeleton` @ `pre-release/0.1.0-beta6`, FrankenPHP 1.12.2 / PHP 8.5
- **Harness:** `bench/` (this directory) — `run-bench.sh <engine> <scenario> [workload]`
- **Raw data:** `bench/results/*.json` + `*-mem.csv` (gitignored; archived to
  `project_system/Audits/Beta6/bench/`)

| Engine | Framework | Runtime | Role |
|---|---|---|---|
| **A** | Waffle-Commons (skeleton, prod image) | FrankenPHP worker, 4 workers | subject |
| **B** | Symfony (shared app) | php-fpm + nginx, `pm.static` 16 | classic-stack baseline |
| **C** | Symfony (same app) | FrankenPHP worker, 4 workers, via `runtime/frankenphp-symfony` (restarted every 500 requests — see *Engine C corrections*) | runtime-held-constant control |

Pinned identically: 2 CPUs, 1 GiB, `APP_ENV=prod`, opcache `validate_timestamps=0`,
JIT `1234` / 128 M buffer, one engine running at a time,
30 s warm-up before every measured window, identical 10 000-row `users` dataset.

**Correction (2026-09-17): worker recycling was *not* pinned identically.** `MAX_REQUESTS=1000000`
reached Engine A only; Engine C's workers restarted every 500 requests. The Engine C readings in
BENCH-02 and BENCH-03 are annotated accordingly — see *Engine C corrections*.

---

## Verdicts at a glance

| Item | Verdict | Note |
|---|---|---|
| `[BENCH-01]` reproducible tri-engine harness | **PASS** | one command per run; Symfony app bootstrap-scripted |
| `[BENCH-02]` constant-load percentiles | **PASS** (latency) | vs PHP-FPM: decisive win. vs Symfony-on-worker: parity to 200 rps on dbread / 400 on dbtxn, earlier knee after |
| `[BENCH-02]` 5–10× RAM factor | **NOT TESTABLE HERE** | pinning made the claim unmeasurable — superseded by BENCH-05 |
| `[BENCH-03]` soak ΔM = 0 | **PASS** (full window, Engine A) | 3 h, 1.62 M requests, zero restarts, ΔM −1.76 MiB. Engine C's run restarted its workers every 500 requests — not a leak test |
| `[BENCH-04]` pool-starvation behaviour | **PASS** | 8× oversubscription, bounded, zero errors |
| `[BENCH-05]` memory vs concurrency | **PASS — claim REFRAMED** | FPM grows **10.5× faster** per concurrent request; 2.37× total at 128 concurrency; bare "5–10×" is **not** publishable as stated |

---

## `[BENCH-02]` Constant-arrival-rate ladder

Method: constant-arrival-rate steps 50 / 100 / 200 / 400 / 800 rps, **1 min per step**
(reduced from the specified 2 min — see *Deviations*), workloads `json`, `dbread`,
`dbwrite`.

**Read the per-rate table, not an aggregate.** An aggregate median over a ladder that
includes saturated steps is meaningless; the first draft of this report quoted one and
it was wrong.

p50 / p99 in ms:

| Workload | rps | A (Waffle worker) | B (Symfony FPM) | C (Symfony worker) |
|---|---:|---|---|---|
| json | 50 | 2.0 / 3.4 | 3.1 / 6.2 | 2.1 / 3.0 |
| json | 200 | 1.5 / 4.3 | 2.3 / 50.7 | 1.5 / 3.3 |
| json | 800 | **1.0** / 38.2 | 587.8 / 1005 | 1.3 / 84.6 |
| dbread | 50 | 4.3 / 8.8 | 26.3 / 61.8 | 2.8 / 4.1 |
| dbread | 200 | 3.4 / 11.8 | 3311 / 3558 | 1.9 / 4.0 |
| dbread | 800 | 2586 / 3210 | 13214 / 15915 | 1.3 / 6.4 |
| dbtxn | 50 | 4.8 / 16.0 | 22.1 / 956 | 3.2 / 12.6 |
| dbtxn | 100 | 4.5 / 15.2 | 2467 / 3555 | 2.8 / 11.4 |
| dbtxn | 800 | 2849 / 3401 | 17205 / 21707 | 6.2 / 598 |

> **`dbtxn` was published as `dbwrite` in the first draft of this report, and that
> draft was wrong.** Engine A's `/write/demo` performs `BEGIN + SELECT 1 + COMMIT`
> — the endpoint is public and CSRF-exempt, so the reference template deliberately
> commits nothing durable — while the Symfony stub performed a single autocommit
> `INSERT`. The two engines were running different workloads, so the original
> `dbwrite` row compared nothing meaningful. The stub now mirrors Engine A exactly
> (verified identical response bodies), the ladder was re-run, and the workload is
> named for what it actually measures: **pipeline + transaction boundary + one
> trivial statement — not the cost of a durable write.**
>
> Correcting it moved the result *against* the Symfony baseline, not for it: B now
> pays the same three round trips and collapses at 100 rps where its single INSERT
> had previously held to 200.
>
> `dbread` was re-run at the same time: both engines dropped `email` from the
> projection (a public endpoint should not model returning PII), and the two must
> fetch identical columns or that workload drifts apart the same way.

### A vs B — the roadmap's actual claim: **decisive win**

Symfony on PHP-FPM collapses on DB workloads between 100 and 200 rps — 2 467 ms
median on `dbtxn` at 100 rps, 3 311 ms on `dbread` at 200 — while Waffle holds
single-digit milliseconds through 200 rps on both and through 400 on `dbtxn`.
At a matched low rate Waffle is ~6× faster on `dbread` (4.3 ms vs 26.3 ms) and
~4.6× on `dbtxn` (4.8 ms vs 22.1 ms).

Engine C (the same Symfony app on the worker runtime) is the fairer framework
comparison and holds throughout, which is the honest reading: most of the
advantage over the classic stack is the **runtime**, not the framework.

### A vs C — parity up to the knee, which arrives earlier for Waffle

The knee is workload-dependent and the corrected data places it lower than the first
draft of this report claimed: on `json` Waffle holds throughout (1.0 ms at 800 rps);
on `dbtxn` it holds to 400 rps (6.1 ms); on `dbread` it holds to 200 rps (3.4 ms) and
is already queueing at 400 (883 ms) where C is still at 1.6 ms. Investigated rather than published as-is:

- **Not the connection pool.** Sweeping `DB_POOL_SIZE` 8 → 32 → 64 barely moved the
  median (75 / 85 / 74 ms).
- **Not a slow query or per-request connection cost.** At single-request concurrency
  A's DB route answers in 6.8–11.6 ms versus 4.8–14 ms for its no-DB route — no DB
  penalty.
- **It is per-request work.** Waffle's default pipeline is 12 middlewares (fail-closed
  ABAC, CSRF, auth, anonymous session, CORS, trusted-host, metrics, tracing,
  transaction isolation, secure headers) plus ping-before-dispense on pool lease, which
  doubles DB round trips. The Symfony baseline runs FrameworkBundle + DoctrineBundle
  only — **no security, no CSRF, no telemetry, no per-request transaction**.

> **Fairness caveat — state this wherever these numbers are quoted.** This is
> *Waffle's fully-secured default stack* against a *bare* Symfony app, not a
> like-for-like framework-overhead measurement. Waffle doing more work per request is
> the product decision, but it must not be presented as pure framework overhead.
> Beta7 should add an "equivalent-features Symfony" engine (security-bundle + CSRF +
> a transaction subscriber) to separate the two.

> **Engine C caveat (post-run audit, 2026-09-17 — see *Engine C corrections*).** C ran through
> the external `runtime/frankenphp-symfony` bridge, and its workers restarted every 500 requests,
> each restart booting the Symfony kernel again. Restarts most likely add latency to C, so the
> reading above stands; if anything, C's lead is understated.

**Actionable optimisation identified:** make ping-before-dispense skippable for
connections leased within a freshness window — halves DB round trips on the hot path.
Recorded as a beta7 item.

---

## `[BENCH-03]` Soak — ΔM

Method: constant 150 rps, all five workloads round-robin, **3 hours per worker engine** (the full
window the roadmap specifies), RSS sampled every 5 s, `MAX_REQUESTS=1000000` so Engine A's worker
loop never recycles and cannot mask a leak. **Engine C did not get the equivalent setting:** its
workers restarted every 500 requests (see *Engine C corrections*).

| Engine | Requests | p50 / p99 | First window | Last window | ΔM | Verdict |
|---|---:|---|---|---|---|---|
| A (Waffle worker) | 1 620 001 | 1.85 / 6.23 ms | 73.21 MiB | 71.45 MiB | **−1.76 MiB** | **PASS** |
| C (Symfony worker) | 1 620 001 | 1.68 / 4.80 ms | 60.78 MiB | 60.49 MiB | −0.29 MiB | **not a leak test** (restarted every 500 requests) |

Zero failed requests on either engine across 1.62 million requests each (1 729 RSS samples per run,
tolerance ±5 MiB). **Both deltas are negative, but only Engine A's is a leak result.** A never
recycled, so memory ending *lower* than it began is the opposite of a leak rather than merely a small
one. C's workers restarted every 500 requests, and each restart discards whatever the worker had
accumulated, so C's run cannot detect a slow leak. Peak RSS: A 76.0 MiB, C 64.4 MiB. Cross-checked
against `wfl igor` (0 KO) on the same build.

**Why the full window mattered.** The initial 30-minute pass reported +1.5 MiB and, read alone,
looked like a mild upward drift; its 30-minute buckets ran 73.07 → 73.31 → 73.93 MiB, which
extrapolates to a slow leak. Over three hours the trajectory settles back
(73.07 / 73.31 / 73.93 / 73.22 / 70.77 / 71.75 / 70.64 MiB) and the drift inverts. The short window
was not wrong so much as **too short to distinguish settling from leaking** — exactly the failure
mode a ΔM gate exists to catch, and the reason the shortened run was re-done at full length rather
than published with a caveat.

Detection sensitivity improved accordingly: the bound on an undetectable leak rate falls from
~10 MB/h (30 min) to **~1.7 MB/h** (3 h), a ~6× sharper claim.

## `[BENCH-04]` Connection-pool starvation

Method: closed-model ramp 8 → 16 → 32 → 64 VUs against `dbread`/`dbwrite` with
`DB_POOL_SIZE=8` — i.e. **8× oversubscription** of the pool at peak.

| Metric | Value |
|---|---|
| Sustained throughput | **868.8 req/s** (417 066 requests) |
| Latency p50 / p95 / p99 / p99.9 | 25.0 / 76.9 / 81.6 / **98.4 ms** |
| `pool_exhausted` (5xx) | **0** |
| Failed requests | **0.00 %** |
| RSS mean / peak | 70.3 / 74.0 MiB (flat) |

**PASS.** Degradation is bounded and graceful: at 8× oversubscription the p99.9 stays
under 100 ms, no request is rejected, no deadlock occurs, and the pool returns to idle
with no leaked or severed connections. Lease-wait latency shows up as the orderly
climb from ~4 ms (unsaturated) to 25 ms p50, exactly the expected queueing behaviour.

**This reframes the BENCH-02 result.** BENCH-02 uses an *open* model (unbounded
arrival), where exceeding capacity queues without limit — textbook behaviour for any
system without admission control, not a Waffle defect. Under the *closed* model real
clients actually impose, the same engine and the same 8-connection pool sustain
**868 rps with a sub-100 ms p99.9**. Quote BENCH-04 for capacity, BENCH-02 for
latency-under-arrival-rate.

---

## `[BENCH-05]` Memory vs concurrency — the corrected RAM experiment

Method: closed model, `constant-vus` steps **8 → 16 → 32 → 64 → 128**, 2 min each,
workload `dbread` (holds a connection for the life of the request, so a request in
flight genuinely occupies a worker or child). CPU pinned at 2 (controlled variable);
memory raised to 6 GiB and FPM switched to `pm=dynamic, max_children=128` so the
dependent variable can actually move.

### RSS by concurrency

| concurrency | A — Waffle worker | B — Symfony FPM (dynamic) | B/A |
|---:|---:|---:|---:|
| 8 | 68.0 MiB | 59.4 MiB | **0.87×** |
| 16 | 68.4 MiB | 73.4 MiB | 1.07× |
| 32 | 71.1 MiB | 96.4 MiB | 1.36× |
| 64 | 74.5 MiB | 130.9 MiB | 1.76× |
| 128 | 80.6 MiB | 191.2 MiB | **2.37×** |

**Growth rate — the real result:**

| Engine | RSS slope | Interpretation |
|---|---|---|
| A (worker) | **+0.105 MiB** per concurrent request | fixed worker set; memory ~flat |
| B (FPM) | **+1.099 MiB** per concurrent request | one process per in-flight request |

**FPM's memory grows 10.5× faster per unit of concurrency.** That ratio — not a single
total-RAM number — is the defensible claim, and it is the mechanism the "5–10×" slogan
was always gesturing at.

### What this means for the "5–10× RAM" claim — state it this way

- **At low concurrency the claim is false, and inverted.** At 8 concurrent requests
  Symfony/FPM uses *less* total RAM than Waffle (0.87×), because Waffle pays a fixed
  floor — 256 MB opcache + 128 MB JIT buffer shared across a resident worker set —
  that FPM amortises differently. Publishing "5–10× less RAM" without qualification
  would be refutable by anyone running a small instance.
- **The crossover is near 12–16 concurrent requests.** Below it FPM wins on total RAM;
  above it Waffle wins, and the gap widens without bound.
- **Measured, at 128 concurrent: 2.37×.** That is the number this rig earned.
- **5× extrapolates to ≈490 concurrent requests** on these slopes — beyond the measured
  range, and it also requires `max_children` ≳ 490, since at 128 children FPM stops
  growing and starts queueing instead. **10× is not reachable by extrapolation** here,
  because Waffle's slope is small but not zero.

> **Recommendation for the conference:** publish the *slope* (10.5× lower memory growth
> per concurrent request), the measured 2.37× at 128 concurrency, and the crossover
> point. Do not publish a bare "5–10×". The slope is the honest, defensible, and
> frankly more interesting claim — it says the two runtimes have different *shapes*,
> not merely different constants.

### Throughput at the same concurrency (secondary, but decisive)

Both engines under the *fairer* dynamic-pool FPM configuration:

| Engine | throughput | p50 | p99 | errors |
|---|---:|---:|---:|---:|
| A — Waffle worker | **781.6 req/s** | 35.0 ms | 223.9 ms | 0.00 % |
| B — Symfony FPM (dynamic, 128 children) | 100.5 req/s | 303.7 ms | 2076.0 ms | 0.03 % |

**7.8× the throughput at identical concurrency and CPU.** This also retires the concern
that BENCH-02's `pm.static` pinning unfairly penalised FPM: given a dynamic pool with
128 children — a *more* favourable configuration — FPM still delivers an eighth of the
throughput at 8.7× the p50 latency.

---

## Deviations from the specification (all deliberate, none silent)

1. **BENCH-02 step duration 1 min, not 2**, and three workloads (`json`, `dbread`,
   `dbwrite`) rather than five. Time-boxing for a same-day release; costs statistical
   smoothing per step, not validity. `hello`/`greet` are covered by the smoke pass.
2. ~~BENCH-03 soak 30 min per engine.~~ **Resolved 2026-08-03:** re-run at the full 3 h per
   worker engine. The shortened window is retained in the history only as the reason the re-run
   happened — its apparent +1.5 MiB upward drift did not survive the longer observation.
3. **The 5–10× RAM factor is not published from BENCH-02.** The harness pinned
   `pm.static, max_children=16` and `mem_limit: 1g`, which makes FPM's memory constant
   by construction and truncates the dependent variable — it cannot demonstrate *or*
   refute the claim. BENCH-05 was built to answer it properly. Publishing a factor from
   BENCH-02 would have been a fabricated number.
4. **Engine A is built by a bench-specific Dockerfile.** Skeleton's own prod image
   resolves `waffle-commons/*` from Packagist — the released beta5 — which both
   boot-loops against beta6 app code and would have measured the wrong framework
   version. The bench builder performs skeleton's real prod install, then overlays each
   vendored component's `src/` from the working tree and re-dumps an authoritative
   classmap.
5. **`intl` is not installed on engines B/C.** Unused by every workload and the single
   slowest build step; opcache/JIT parity — what actually shapes throughput — is intact.

## Engine C corrections (post-run audit, 2026-09-17)

Found after this report was published and, unlike the deviations above, not deliberate. Engine C
has not been re-run yet: the affected readings are annotated in place, and no measured number in
this report has changed.

1. **Engine C's workers restarted every 500 requests; Engine A's never did.** Engine C runs Symfony
   through `runtime/frankenphp-symfony` 1.0.0, whose worker loop exits after `frankenphp_loop_max`
   requests — **500** by default, overridden only by that runtime option or `FRANKENPHP_LOOP_MAX`.
   The rig set `MAX_REQUESTS=1000000`, which Engine A's worker script reads and this package does
   not, and set nothing for Engine C (`docker-compose.bench.yml`, service `engine-c`). FrankenPHP
   then restarts the worker script, which boots the Symfony kernel again.
   - **BENCH-03:** each restart discards whatever the worker had accumulated, so C's soak cannot
     detect a slow leak. Its row stays for the record, not as a PASS. Engine A's result is
     unaffected.
   - **BENCH-02:** restarts most likely add latency to C, mostly in the tail. The A-vs-C reading
     stands; if anything, C's lead is understated.
2. **Engine C used the external bridge, not Symfony's native runner.** `symfony/runtime` 7.4
   (7.4.14 installed) ships `FrankenPhpWorkerRunner` and detects worker mode on its own, but
   `APP_RUNTIME=Runtime\FrankenPhpSymfony\Runtime` (compose and `engines/symfony-worker/Dockerfile`)
   forces the older package. Engine C therefore measures Symfony on FrankenPHP through that bridge,
   not through Symfony's built-in integration. The bridge is also why the baseline is Symfony 7.4
   rather than 8.x: it does not install against Symfony 8 (`scripts/bootstrap-symfony.sh`).

**Next run:** remove `APP_RUNTIME` from Engine C (compose and Dockerfile) so Symfony auto-detects
worker mode, and set `FRANKENPHP_LOOP_MAX=1000000`. The native runner reads the same variable and
**also defaults to 500**, so switching runners alone would not stop the restarts. Then re-run
BENCH-02 and BENCH-03 for Engine C.

**Rig fixed 2026-10-22 (`[CARRY-02]`); Engine C not re-measured yet.**
- `APP_RUNTIME` is gone from compose and the Dockerfile, both set `FRANKENPHP_LOOP_MAX=1000000`,
  and `scripts/bootstrap-symfony.sh` removes the bridge package. `engine-c-mem` adds Engine C to
  BENCH-05.
- The bootstrap re-run also moved doctrine/dbal to 4.5.0, doctrine/doctrine-bundle to 3.3.2 and
  symfony/validator to 7.4.21; framework-bundle 7.4.15 and runtime 7.4.14 are unchanged.
- A probe on the rebuilt image (FrankenPHP 1.13.2, Caddy `metrics` enabled for the probe only) sent
  3 000 requests twice. With the loop max at 500 the workers restarted 5 times; at 1 000 000 they did
  not restart once.
- Harness checks on the rebuilt rig, not measurements: the Engine C smoke passed every check (run
  `20261022T115850Z`, 6 675 requests, none failed), and a 3 × 30 s `engine-c-mem` memscale ran end to
  end (run `20261022T120027Z`, 172 923 requests, none failed).
- BENCH-02 and BENCH-03 for Engine C still need their re-run on the new rig, so the readings above
  stand as annotated.

## Engine D and what building it exposed (`[CARRY-02]`, 2026-10-22)

Engine D is the bare Symfony app plus Engine A's per-request work: trusted hosts, CORS, a stateless
bearer-token firewall, per-action authorisation, stateless CSRF, three security headers and one
transaction per unsafe request (`bench/README.md`). It has not been measured yet. Building it exposed
three facts about this rig; none changes a measured number above.

1. **Engine A's `POST /greet` is not a database-free workload.** `TransactionIsolationMiddleware` wraps
   every POST, so each `/greet` leases a pooled connection, runs the pool's liveness `SELECT 1`
   (ping-before-dispense, `[CARRY-01]`) and commits a transaction. `scripts/check-features.sh` counted
   603 commits for 200 `/greet` on A, 207 on D and 4 on C. B and C never touch the database on that
   route, and the same middleware and ping were in place in beta6, so the beta6 `greet` comparison
   charged A database round trips that B and C did not make.
2. **Engine A issues a new session id on most bench requests.** k6 empties its cookie jar after every
   iteration, so `AnonymousSessionMiddleware` generates a 32-byte id and a `Set-Cookie` each time.
   Neither Symfony engine does such work, and Engine D does not mirror it.
3. **The rig's tmpfs mounts were closed to Engine A's user.** Compose reads `mode: 1777` as a decimal
   number (octal 3361), so `/tmp`, `/config`, `/data` and `/app/var` were not writable by the non-root
   `waffle` user. The beta6 run booted anyway; beta7's fail-fast upload root (`http` `b6c2213`) turns it
   into a boot failure. The rig now writes `0o1777`, and so does `skeleton/docker-compose.prod.yml`,
   which had the same four lines (skeleton `a50dea2`).

Harness checks on the rebuilt rig, not measurements: `check-features.sh` passed on A, C and D, and the
smoke runs (A `20261022T124138Z`, C `20261022T115850Z`, D `20261022T124248Z`) and the short memscales
(C-mem `20261022T120027Z`, D-mem `20261022T124356Z`) finished with no failed request. Engine D's
security components are pinned to the 7.4 line like the rest of the app.

## Defects found by this benchmark (all fixed at source)

| Defect | Where | Consequence |
|---|---|---|
| No `pdo_pgsql` / `pdo_mysql` in the shipped prod image | `skeleton/docker/Dockerfile` | every DB route in the template failed; user-facing since beta5 |
| `/greet` GET-only while its docblock documents `POST` | `skeleton/src/Controller/HelloController.php` | documented call returned 405 |
| Demo routes lacked `#[PublicAccess]` | `skeleton/src/Controller/HelloController.php` | 403 through the real pipeline; controller tests bypassed it |
| `driver: mysql` with no DB service in compose | `skeleton/config/app.yaml` | default template pairing could not work |
| k6 and `init.sql` used different id schemes | `bench/k6/lib/common.js` | **every `dbread` was a miss** — invisible on A (200 `found:false`), loud on B/C (404) |
| Engine miss semantics diverged (200 vs 404) | `bench/scripts/stubs/.../BenchController.php` | an id drift could masquerade as "Symfony is broken" |

## Reproducing

```bash
cd bench
./scripts/bootstrap-symfony.sh                     # generates the gitignored Symfony app
docker compose -f docker-compose.bench.yml build
./scripts/run-bench.sh engine-a smoke              # gate: require 0 % failures first
RATES=50,100,200,400,800 STEP_DURATION=2m ./scripts/run-bench.sh engine-a constant dbread
RATE=150 DURATION=3h ./scripts/run-bench.sh engine-a soak
DB_POOL_SIZE=8 ./scripts/run-bench.sh engine-a starve
VUS_STEPS=8,16,32,64,128 STEP_DURATION=2m ./scripts/run-bench.sh engine-a-mem memscale
./scripts/report.sh
```
