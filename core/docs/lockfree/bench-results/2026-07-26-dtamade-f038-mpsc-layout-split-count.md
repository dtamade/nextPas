# F-038 — MPSC: thread-affinity layout + split single-writer count

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TMpscQueueImpl` was the only zero-pad structure in the T1 queue family: every
field (FHead/FTail/FStub/FClosed/FCount/FDataEpoch/FDataWaiters) sat adjacent,
so producers (XCHG FHead + fetch_add FCount) and the consumer (FTail cursor +
fetch_sub FCount + stub re-hook) shared cache lines on every op. It also had
the F-037 class of defect: FCount was a single counter RMW'd by ALL threads
(producers fetch_add, consumer fetch_sub) — a guaranteed per-op line ping-pong
that padding alone cannot fix.

Fix, two legs (cacheline-layout-rules.md §2 + §5-adjacent):

1. **Thread-affinity grouping**: producer line = FHead + FEnqueued + data wait
   unit (producers notify it; consumer touches it only when blocking);
   consumer line = FTail + FDequeued; FStub on its own line (both sides hit
   FStub.Next at the empty boundary — exactly where a draining consumer
   oscillates, see M1 vs M2 below); cold tail = FConstructed + FClosed.
2. **Split count**: FCount → FEnqueued (producers, fetch_add — multi-writer
   needs the RMW) + FDequeued (consumer, single-writer: plain load+store, no
   locked RMW on the consumer's hot path). ApproxCount reads FDequeued first
   (acquire orders the two loads); monotonicity makes the difference
   non-negative and conservatively over-reporting — it never hides backlog.
   The enqueue-side count still publishes before the consumer-visible link
   (StoreNode), preserving the r2_queues pinned invariant.

Bench coverage debt paid first: MPSC had NO bench scenarios at all. Added
matched/M1_Mpsc_1P1C, matched/M2_Mpsc_2P1C (unbounded, single consumer via
DequeueWait) and micro/MPSC/TryEnqueueDequeuePair, built and measured on the
baseline tree before touching the source.

## Envelope

```
date_utc:  2026-07-26 (same host, same session; both sides measured at load
           ~16-21 on a 44-core box — accepted on the F-037 dual criterion:
           controls inside known ranges + before/after separation)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-037 commit 8b5e2c688 + new MPSC bench scenarios;
           after = + mpsc layout/split-count fix; clean rebuild both sides
workload:  bench_lockfree matched (OPS=1e6; M1=1P+1C, M2=2P+1C, unbounded) + micro
warmup:    micro suite MinDuration=50ms MinSamples=5; matched = whole-run wall time
measured:  matched: ms per 1e6 paired ops; micro: ns per enqueue+dequeue pair
stats:     baseline n=5 matched + 1x all (a 6th matched run DISCARDED: control
           C1s hit 162.7ms, far outside its known 26.5-96.0 range — the whole
           round was externally polluted, per cacheline-layout-rules.md §6);
           after n=6 (1x all + 5x matched, all rounds clean — no outliers)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   core/build/.../bench_lockfree all (x1); ... matched (x5)
```

## Numbers (same host)

| Scenario | Before (n=5, median) | After (n=6, median) | Approx delta |
|----------|---------------------|---------------------|--------------|
| matched/M1_Mpsc_1P1C (signal) | 262.1–288.6 ms, median 268.1 | 167.4–227.4 ms, median 202.2 | **median ~ -25%**; ranges fully disjoint (after max 227.4 < before min 262.1) |
| matched/M2_Mpsc_2P1C (signal) | 166.9–196.2 ms, median 182.2 | 108.1–117.3 ms, median 109.9 | **median ~ -40%**; ranges fully disjoint (after max 117.3 << before min 166.9, 50ms gap) |
| micro/MPSC/TryEnqueueDequeuePair | 122.4 ns (weak: CV 49.6, P50 98.7 — heap alloc right tail + load) | 110.9 ns (CV 46.6, P50 90.1) | ~flat within noise (pair is New/Dispose-dominated) |
| matched/C1_1P1C (control, untouched) | 116.3–141.9 ms, median 135.0 | 111.8–122.1 ms, median 117.8 | overlapping ranges; median -13% = **load-differential upper bound** (see below) |
| matched/C1s_ChannelSpsc_1P1C (control, untouched) | 29.2–53.6 ms, median 42.2 (known range 26.5–96.0) | 35.3–54.8 ms, median 42.0 | flat — medians agree to 0.5% |
| micro/SPSC/TryEnqueueDequeuePair (control) | 33.8 ns | 32.9 ns | flat |

Note: M2 (2 producers) is FASTER than M1 (1 producer) on both sides — with two
producers the unbounded queue runs deep and the consumer never starves; at
1P+1C the queue oscillates at the empty boundary (stub re-hook + wait/notify),
which is precisely the path the FStub isolation targets. M1's after-side spread
(167–227) mirrors the F-036 pattern: once per-op misses stop pacing the loop,
progress runs in bursts and scheduling interleave dominates the variance.

Load asymmetry disclosed: the after batch ran at load ~12 vs ~16-21 for the
baseline. The untouched C1 control drifted -13% median across the same windows
— that is the upper bound on what the quieter window alone can explain. The
M1 (-25%) and M2 (-40%) deltas both exceed it decisively AND their ranges are
fully disjoint from baseline, while the C1s control medians agree to 0.5% —
the improvement is attributable to the layout/split-count change, though the
exact magnitude carries the usual load caveat.

## Functional check

- `test_lockfree` full suite green (incl. t2 isolation compile);
  `test_lockfree_r2_queues` 16/16 with pins updated to FEnqueued/FDequeued
  (count-publishes-before-link invariant preserved and still pinned; new pin:
  ApproxCount must read FDequeued first).
- verify-t1 + verify-t2-smoke pass; `test_atomic` 46/46; hygiene + diff-check
  clean; 0 leaks (heaptrc).
- Also fixed in the same round: r2_queues' channel resize-guard pins were
  still on the pre-F-037 single counter (FActiveOperations) — r2_queues was
  missing from the F-037 gate list. Pin-gate rule: after touching a source
  file, run every test project that ReadSource-pins it (channel/mpsc are
  pinned by test_lockfree AND test_lockfree_r2_queues).
