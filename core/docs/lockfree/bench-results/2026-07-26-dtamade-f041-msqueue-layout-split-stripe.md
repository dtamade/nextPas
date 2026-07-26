# F-041 — MsQueue: thread-affinity layout + counter split + striped resize guard

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TLockFreeMsQueueImpl` (array-based Michael-Scott MPMC queue) was the last
T1 queue carrying ALL three generations of layout defects at once
(cacheline-layout-rules.md §1-§3), and the baseline measured it as the
slowest structure in the whole matched suite:

1. **Zero padding, one field cluster** (F-032/F-039 defect): FNodes/
   FFreeList/FCapacity/FFreeHead/FHead/FTail/FCount/FClosed/
   FActiveOperations/FResizing all adjacent (~44B → one or two lines).
   Every successful op performed 5 locked RMWs on that cluster
   (guard enter + freelist CAS + link/head CAS + tail CAS + count + guard
   leave) from ALL threads.
2. **FCount single-point counter** (F-038 defect): RMW'd by every thread
   with the DEFAULT (seq_cst) order on both sites.
3. **FActiveOperations single-point resize guard** (F-037 defect): every
   op from both sides did an Enter/Leave RMW pair on one shared counter.

Fix (no algorithm change; enqueue/dequeue CAS protocol untouched):

- **Layout** by accessing thread (F-033 rule): read-mostly header
  (FNodes/FFreeList/FCapacity) + FPadHeader; producer line FTail +
  FEnqueued; consumer line FHead + FDequeued; **FFreeHead on its own
  line** — it is CAS'd by BOTH sides every op (alloc on enqueue, recycle
  on dequeue) so it cannot join either side's line; cold tail
  FResizing/FClosed.
- **Counter split by writer population** (F-038 pattern): FCount →
  FEnqueued (enqueue site) + FDequeued (dequeue site), both mo_relaxed
  (diagnostic-only counters; the old sites used default seq_cst).
  MPMC caveat: unlike mpsc's single-writer FDequeued, BOTH counters keep
  fetch_add here (multiple writers on each side) — the win is line
  separation, not fewer RMWs. ApproxCount reads FDequeued first
  (acquire) then FEnqueued, clamps at 0: biased toward overstating,
  conservative for drain polling (F-038 argument). The clamp also covers
  a pre-existing transient window where the old single FCount could read
  negative (consumer counts its dequeue before the producer counts the
  matching enqueue).
- **Striped resize guard** (F-037 template, verbatim from channel):
  `FOpStripes: array[0..MSQUEUE_OP_STRIPES-1] of TMsQueueOpStripe`
  (8 stripes, each Count + full-line pad), multiplicative thread-id hash
  (`* $9E3779B9 shr 24 and 7`, {$Q-}{$R-}); the stripe index is computed
  ONCE per call and passed to the paired Enter/Leave (recomputing could
  decrement a different stripe and let Grow see false quiescence =
  use-after-free); Grow scans all 8 stripes for quiescence.

Pin updates (gate rule: run every project that ReadSource-pins the file):
r2_queues' `FActiveOperations` pin → `FOpStripes` stripe pin + new Grow
stripe-scan pin. The Destroy/value-copy-before-head-CAS/IsManagedType
pins are untouched by design.

Bench coverage debt paid first: msqueue had NO bench scenarios — added
matched/Q1_MsQueue_1P1C, matched/Q2_MsQueue_2P2C (producers retry full
with CpuPause, consumers spin on empty) and micro/MsQueue/
TryEnqueueDequeuePair, built and measured on the baseline tree before
touching the source.

## Envelope

```
date_utc:  2026-07-26 (same host, same session; baseline at load
           ~16.8-19.9, after at ~16.0-17.9 on a 44-core box —
           comparable windows)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-040 commit 9f0819f81 + new msqueue bench
           scenarios; after = + msqueue layout/counter/stripe fix;
           clean rebuild both sides
workload:  bench_lockfree matched (OPS=1e6; Q1=1P+1C, Q2=2P+2C,
           unbounded, initial capacity from scenario setup) + micro
warmup:    micro MinDuration=50ms MinSamples=5; matched = whole-run wall
measured:  matched: ms per 1e6 enqueued+dequeued values; micro: ns per
           TryEnqueue+TryDequeue pair (single thread, uncontended)
stats:     n=6 both sides (1x all + 5x matched); controls
           inside/overlapping known ranges, outliers disclosed below
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   core/build/.../bench_lockfree all (x1); ... matched (x5)
```

## Numbers (same host)

| Scenario | Before (n=6, median) | After (n=6, median) | Approx delta |
|----------|---------------------|---------------------|--------------|
| matched/Q1_MsQueue_1P1C (signal) | 523.1–603.2 ms, median 573.9 | 419.0–463.2 ms, median 427.7 | **median ~ -25%**; ranges fully disjoint (after max 463.2 < before min 523.1) |
| matched/Q2_MsQueue_2P2C (signal) | 611.9–630.7 ms, median 618.6 | 452.7–524.3 ms, median 465.3 | **median ~ -25%**; ranges fully disjoint (after max 524.3 < before min 611.9) |
| micro/MsQueue/TryEnqueueDequeuePair | 276.0 ns | 288.4 ns | **+4.5%** — disclosed, not hidden: same RMW count as before (MPMC keeps fetch_add on both counters), plus per-op stripe hash and a two-line counter footprint. Single sample per side (micro runs once per batch). |
| matched/W1_Pool_1S1T (control) | median 245.8 (230.8–250.3) | median 238.7 (209.1–272.6) | -3%, overlap |
| matched/W2_Pool_2S2T (control) | median 167.6 (159.4–176.1) | median 174.8 (162.0–270.8) | +4%, overlap; one 270.8 outlier (round 1, same round as W1's 272.6 — transient scheduling blip on pool scenarios) |
| matched/C1_1P1C (control) | median 118.9 (107.2–123.3) | median 120.2 (115.6–316.0) | flat; one 316.0 outlier in round 5 disclosed (C1 has known variance; median robust) |
| matched/C1s_ChannelSpsc_1P1C (control) | 35.3–70.7, median 45.7 | 36.2–69.7, median 51.3 | flat (both inside known 26.5–96.0 range) |
| matched/M1_Mpsc_1P1C (control) | median 199.4 (165.9–225.2) | median 219.8 (205.9–230.9) | +10% drift, overlapping ranges — disclosed as the noise bound; signal far exceeds it |
| matched/M2_Mpsc_2P1C (control) | median 110.0 (100.7–112.4) | median 110.2 (103.7–116.4) | flat |
| matched/J1_ForkJoin_1F1W (control) | median 371.1 (332.2–386.4) | median 357.5 (336.7–392.0) | -3.7%, overlap |
| matched/J2_ForkJoin_2F2W (control) | median 267.3 (247.2–294.5) | median 265.7 (249.6–294.2) | flat |

Attribution signature: both cross-thread msqueue scenarios moved ~-25%
with fully disjoint ranges while every untouched control stayed within
overlapping ranges (worst control drift +10% M1). This is the
**pure-layout signature** (cross-thread big, micro flat-to-slightly-up):
unlike F-038/F-040, the counter split here removes NO locked RMWs (MPMC
needs fetch_add on both sides), so the entire win is line separation.
The small micro regression is the price of the stripe hash + wider
counter footprint, traded for -25% under any contention.

Notes:
- Baseline confirmed the audit diagnosis: Q1 573.9 was the slowest
  structure in the whole suite (2.9x M1, 2.3x W1, 1.5x J1) and Q2 > Q1
  (618.6 vs 573.9) — ADDING threads made it slower, the classic
  signature of all threads RMW-ing one line.
- After the fix Q2 (465.3) is STILL > Q1 (427.7): the remaining
  serialization is FFreeHead — the node-pool design makes both sides CAS
  one freelist head every op. That is an algorithm-level debt (per-thread
  freelist stripes / elimination would be an F-042-class change),
  recorded, not attempted here.
- Matched Sink checksum identical across all 5 matched rounds on BOTH
  sides (12750016500000) — the counter rewrite changed no delivered-value
  accounting. (The `all` rounds' Sink differs between sides only because
  micro iteration counts differ run to run.)

## Functional check

- `test_lockfree_msqueue` 20244/20244 (behavior suite; pin-gate rule).
- `test_lockfree_r2_queues` 16 passed / 0 failed (msqueue source pins
  updated: striped-guard field + Grow stripe scan).
- `test_atomic` 46 passed / 0 failed; 0 unfreed blocks (heaptrc).
- `test_lockfree` + `test_lockfree_stress` + verify-t1 + verify-t2-smoke
  + hygiene + `git diff --check`: see commit gate log (run after the
  after-batch so the measured binary is the committed source).
