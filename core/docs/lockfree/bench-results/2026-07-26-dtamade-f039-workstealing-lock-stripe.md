# F-039 — WorkStealingPool: per-line owner locks + rotor separation

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TWorkStealingPool` had three layout defects (cacheline-layout-rules.md §1-§3):

1. `FOwnerLocks: array of Int32` — bare 4-byte elements pack 16 locks per
   cache line, so with 4 workers ALL owner locks shared ONE line: every
   AcquireOwner CAS on worker A's lock invalidated the line under workers
   B/C/D spinning on theirs. Fix: `TWorkStealingOwnerLock = record Lock:
   Int32; Pad: TCacheLinePad end` — one lock per line.
2. `FNextSubmit` / `FNextSteal` adjacent — every Submit RMWs the first,
   every Steal RMWs the second; distinct writer populations ping-ponged the
   same line. Fix: full-line pad between them.
3. No header pad and hot rotors adjacent to the read-mostly header
   (FWorkerCount/FDeques/FOwnerLocks refs, read on every op) and to cold
   FClosed. Fix: FPadHeader after the header, FClosed isolated at the cold
   tail.

No algorithm change: Submit/Steal/Close logic and the AcquireOwner spin
protocol are untouched (the owner-lock-simulating-owner-thread design is a
recorded architecture debt, out of scope here).

Bench coverage debt paid first: the pool had NO bench scenarios. Added
matched/W1_Pool_1S1T, matched/W2_Pool_2S2T (4 workers fixed, submitters
retry on full deques with CpuPause, stealers spin on wsEmpty) and
micro/Pool/SubmitStealPair (1 worker), built and measured on the baseline
tree before touching the source.

## Envelope

```
date_utc:  2026-07-26 (same host, same session; both sides at load ~8-11.6
           on a 44-core box — comparable windows, controls flat)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-038 commit 21db2f480 + new pool bench scenarios;
           after = + workstealing layout fix; clean rebuild both sides
workload:  bench_lockfree matched (OPS=1e6; W1=1S+1T, W2=2S+2T; pool of 4
           workers, bounded deques cap 64) + micro
warmup:    micro MinDuration=50ms MinSamples=5; matched = whole-run wall time
measured:  matched: ms per 1e6 submitted+stolen tasks; micro: ns per
           Submit+Steal pair (1 worker, uncontended)
stats:     n=6 both sides (1x all + 5x matched); no polluted rounds
           (all controls inside known ranges)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   core/build/.../bench_lockfree all (x1); ... matched (x5)
```

## Numbers (same host)

| Scenario | Before (n=6, median) | After (n=6, median) | Approx delta |
|----------|---------------------|---------------------|--------------|
| matched/W1_Pool_1S1T (signal) | 257.9–291.7 ms, median 273.0 | 221.9–239.5 ms, median 230.6 | **median ~ -15%**; ranges fully disjoint (after max 239.5 < before min 257.9) |
| matched/W2_Pool_2S2T (signal) | 193.5–224.8 ms, median 213.6 | 157.8–176.5 ms, median 166.6 | **median ~ -22%**; ranges fully disjoint (after max 176.5 < before min 193.5) |
| micro/Pool/SubmitStealPair (1 worker) | 175.1 ns | 178.8 ns | flat (+2%) — expected: single thread, 1-element lock array, no cross-line traffic to remove |
| matched/C1_1P1C (control) | median 108.2 | median 113.6 | flat (+5%, overlapping ranges) |
| matched/M1_Mpsc_1P1C (control) | median 213.0 | median 204.2 | flat (-4%, inside F-038 after range) |
| matched/M2_Mpsc_2P1C (control) | median 113.9 | median 111.1 | flat (-2.5%) |
| matched/C1s_ChannelSpsc_1P1C (control) | median 42.4 | median 38.8 | flat (both inside known 26.5–96.0 range) |
| micro/SPSC/TryEnqueueDequeuePair (control) | 30.7 ns | 31.9 ns | flat |

Attribution signature holds: only the two cross-thread pool scenarios moved
(with fully disjoint ranges), the single-thread pool micro and every
untouched control stayed flat, and both batches ran in comparable load
windows — the improvement is attributable to the layout change.

Notes:
- W2 (2S+2T) is FASTER than W1 (1S+1T) on both sides — same shape as M2 vs
  M1: with two submitters the deques run less empty, so a stealer's scan
  finds work on the first probe more often instead of sweeping all four
  deques and rotating FNextSteal through empty passes.
- The delta is smaller than F-037/F-038 because the dominant per-op cost —
  the AcquireOwner CAS spin itself plus the deque CAS protocol — is
  untouched; this round only removed the false sharing AROUND those
  operations. The lock-per-worker design (Submit and Steal-fallback both
  funnel through AcquireOwner) is the remaining architecture debt.

## Functional check

- `test_lockfree` 191 passed / 0 failed (incl. t2 isolation compile pass;
  it pins workstealing.pas via AcquireOwner markers and pins the bench
  source — both still green with the new fields/scenarios).
- `test_lockfree_workstealing` (behavior suite for the pool) all passed —
  pin-gate rule applied: run every test project that reads the touched
  source. `test_lockfree_r2_queues` 16/16.
- verify-t1 + verify-t2-smoke pass; `test_atomic` 46/46; hygiene +
  diff-check clean; 0 leaks (heaptrc).
