# F-040 — ForkJoinPool: layout fix + counter writer-population split

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TLockFreeForkJoinPool` repeated every F-039 workstealing defect and added
two of its own (cacheline-layout-rules.md §1-§3 + F-038 counter pattern):

1. `FOwnerLocks: array of Int32` — bare 4-byte elements pack 16 locks per
   line; with 4 workers ALL owner locks shared ONE line. Fix:
   `TForkJoinOwnerLock = record Lock: Int32; Pad: TCacheLinePad end`.
2. No header pad, rotor/counters/FClosed all adjacent in one field cluster.
   Fix: read-mostly header + FPadHeader, cold FClosed at the tail.
3. `FTaskCount` + `FCompletedCount` were two single-point counters RMW'd by
   ALL threads — worse than F-038's mpsc FCount because PopOrSteal hit BOTH
   per op (`add FCompletedCount; sub FTaskCount` = 2 RMWs), and both sites
   used the DEFAULT memory order (seq_cst). Fix: split by writer
   population — `FForked` (Fork side only: add before TryPush, sub rollback
   on full) and `FDone` (PopOrSteal side only: ONE relaxed add per success).
   pending = Forked − Done (read FDone first with acquire, difference never
   negative, conservative direction — same argument as F-038 mpsc);
   completed = FDone.
4. Line assignment follows F-033's same-writer-same-line rule: FNextWorker
   and FForked are both RMW'd by every Fork, so they SHARE one padded line
   (one line pulled once serves both RMWs); FDone gets its own line.

No public API change; PopOrSteal argument-validation contract untouched.

Bench coverage debt paid first (pool had NO bench scenarios): added
matched/J1_ForkJoin_1F1W, matched/J2_ForkJoin_2F2W (pool of 4 workers,
forkers retry fjFull with CpuPause, workers spin on empty PopOrSteal) and
micro/ForkJoin/ForkPopPair (1 worker), built and measured on the baseline
tree before touching the source.

## Envelope

```
date_utc:  2026-07-26 (same host, same session; baseline at load ~12.0-12.6,
           after at ~11.9-13.4 on a 44-core box — comparable windows, after
           slightly HIGHER load yet faster: conservative direction)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-039 commit 886d6845a + new forkjoin bench scenarios;
           after = + forkjoin layout/counter fix; clean rebuild both sides
workload:  bench_lockfree matched (OPS=1e6; J1=1F+1W, J2=2F+2W; pool of 4
           workers, bounded deques cap 64) + micro
warmup:    micro MinDuration=50ms MinSamples=5; matched = whole-run wall time
measured:  matched: ms per 1e6 forked+executed tasks; micro: ns per
           Fork+PopOrSteal pair (1 worker, uncontended)
stats:     n=6 both sides (1x all + 5x matched); no polluted rounds
           (controls inside/overlapping known ranges, drift disclosed below)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   core/build/.../bench_lockfree all (x1); ... matched (x5)
```

## Numbers (same host)

| Scenario | Before (n=6, median) | After (n=6, median) | Approx delta |
|----------|---------------------|---------------------|--------------|
| matched/J1_ForkJoin_1F1W (signal) | 409.2–527.6 ms, median 461.4 | 343.6–385.8 ms, median 351.5 | **median ~ -24%**; ranges fully disjoint (after max 385.8 < before min 409.2) |
| matched/J2_ForkJoin_2F2W (signal) | 342.4–372.8 ms, median 355.4 | 279.2–289.5 ms, median 286.6 | **median ~ -19%**; ranges fully disjoint (after max 289.5 < before min 342.4) |
| micro/ForkJoin/ForkPopPair (1 worker) | 201.6 ns | 190.3 ns | **-6%** — expected NON-flat: the counter split removes one locked RMW per pair even single-threaded (2 seq_cst RMWs → 1 relaxed in PopOrSteal) |
| matched/W1_Pool_1S1T (control) | median 230.9 | median 215.5 | -6.7% drift, ranges overlap (217.3–237.4 vs 199.6–233.8) — disclosed as the noise bound; signal far exceeds it |
| matched/W2_Pool_2S2T (control) | median 168.6 | median 167.5 | flat |
| matched/C1_1P1C (control) | median 118.6 | median 128.2 | +8%, one noisy round (149.8), ranges overlap |
| matched/C1s_ChannelSpsc_1P1C (control) | 33.7–72.5 | 34.7–87.1 | flat (both inside known 26.5–96.0 range) |
| matched/M1_Mpsc_1P1C (control) | median 216.7 | median 206.3 | flat (-5%, overlapping) |
| matched/M2_Mpsc_2P1C (control) | median 109.9 | median 111.0 | flat |

Attribution signature: both cross-thread forkjoin scenarios moved with
fully disjoint ranges while every untouched control stayed within
overlapping ranges (worst control drift -6.7%/+8%, signal -19%/-24% with
range separation noise cannot fake). Unlike the pure-layout F-039, the
single-thread micro is expected to move a little here (-6%) because the
counter split removes one locked RMW per pair independent of contention —
this is the counter-split signature, distinct from the pure-layout
signature (cross-thread moves, micro flat).

Notes:
- Matched Sink checksum identical across all 5 matched rounds on BOTH
  sides (10500013500000) — the counter rewrite changed no delivered-task
  accounting.
- Baseline J1 (461.4) was ~2x W1 (230.9) on the same deque/lock skeleton —
  the forkjoin extra cost was exactly the 3 per-task seq_cst counter RMWs
  plus the doubled lock-array false sharing. After the fix J1 (351.5) is
  still ~1.6x W1: the remaining gap is the owner-lock-based local TryPop
  (PopOrSteal takes AcquireOwner even on the fast local path, where
  workstealing's Steal tries lock-free TrySteal first) — recorded debt.
- Residual (recorded, not fixed): Fork's FNextWorker fetch_add still uses
  the default (seq_cst) order — identical x86-64 codegen (lock xadd), so
  it cannot affect these numbers; on ARM it would matter. Candidate for a
  follow-up consistency pass with the other ~default-order sites.

## Functional check

- `test_lockfree` 191 passed / 0 failed (incl. t2 isolation compile pass;
  pins forkjoin.pas via the PopOrSteal validation marker — untouched).
- `test_lockfree_forkjoin` 114/114 (behavior suite for the pool) —
  pin-gate rule applied. `test_lockfree_r2_queues` 16/16.
- verify-t1 + verify-t2-smoke pass; `test_atomic` 46/46; hygiene +
  diff-check clean; 0 leaks (heaptrc).
