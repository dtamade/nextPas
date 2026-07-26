# F-043 — MsQueue: free-list striping (multi-writer CAS fan-out)

## Change

F-041 left one measured serial point in `TLockFreeMsQueueImpl`: `FFreeHead`,
a single packed (index:32 | aba:32) Treiber-stack top CAS'd by BOTH sides on
every op (alloc on enqueue, recycle on dequeue). Q2 stayed the slowest
matched scenario (468ms median) and stayed ABOVE Q1 — adding threads made
the queue slower.

Fix: `FFreeHead`+pad replaced by `FFreeStripes[0..MSQUEUE_OP_STRIPES-1]`
(8 self-padded `{Head: Int64; Pad: TCacheLinePad}` records, same argument
as the op-guard stripes). Key decisions:

- **Stripe index = the op guard's stripe**, computed once per op and passed
  to alloc/recycle (zero extra hashing; the caller-computes-once pairing
  discipline is inherited for free).
- Alloc: fast path pops the caller's own stripe — hand-peeled into the
  same single-loop shape as the pre-stripe allocator; on OBSERVED EMPTY
  (not CAS failure) it probes the remaining 7 stripes; only all-empty
  reports exhaustion (→ Grow). CAS failure retries the same stripe, so
  lock-free progress is unchanged.
- Recycle: pushes to the caller's own stripe. Per-stripe aba tag, +1 per
  CAS, same ABA protocol as before, now per stripe.
- Create/Grow chain nodes round-robin (`I + 8`) across stripes; Grow's
  empty recheck scans all 8 heads; the rebuild runs under the existing
  quiescence protocol (FResizing + op-stripe drain), tags kept monotone
  per stripe. `LNewFreeList` storage shape unchanged (r2 pin intact).

Baseline reuse: the F-042 after batch IS this round's baseline (n=9,
binary = committed tree @6ed63eb33, same host/day, msqueue source
untouched between those measurements and this change).

## Envelope

```
date_utc:  2026-07-26 (same host, same session; baseline at load
           ~10.3-15.2, after v2 at ~11.3-15.9 on a 44-core box)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-042 commit 6ed63eb33 (reused batch);
           after v2 = + freelist striping incl. peeled fast path;
           clean rebuild; measured binary = committed source
workload:  bench_lockfree matched (OPS=1e6; Q1=1P+1C, Q2=2P+2C,
           unbounded MPMC) + micro pair
warmup:    micro MinDuration=50ms MinSamples=5; matched = whole-run wall
measured:  matched: ms per 1e6 enqueued+dequeued values; micro: ns per
           TryEnqueue+TryDequeue pair (single thread)
stats:     baseline n=9; after v2 n=5, 1 round discarded for control
           contamination (disclosed below) -> n=4
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   bench_lockfree all (x1); ... matched (x4 kept); ... micro
```

## Numbers (same host)

| Scenario | Before (n=9, median) | After v2 (n=4, median) | Verdict |
|----------|---------------------|------------------------|---------|
| matched/Q2_MsQueue_2P2C (signal) | 457.2–498.6 ms, median 468.3 | 359.7–416.1 ms, median 378.6 | **-19.2%, ranges fully separated** (after max 416.1 < before min 457.2) |
| matched/Q1_MsQueue_1P1C | 323.8–442.0 ms, median 423.3 | 356.3–432.1 ms, median 391.4 | flat (median -7.5%, ranges overlap — 1P1C drains through one stripe pair as designed) |
| micro/MsQueue/TryEnqueueDequeuePair | 285.2 ns (RSD 7.3) | 286.5 / 289.0 (clean rounds, RSD ~4) / 304.3 / 317.2 | flat — see the intermediate regression story below |
| matched/C1_1P1C (control) | 104.5–131.7 | 115.6 / 121.9 / 140.7 / 180.6 | r2's 180.6 is +37% over range (disclosed); rest in/near range |
| matched/C2_2P2C (control) | 244.3–287.6 | 222.0–252.9 | in range |
| matched/C1s (control) | 26.5–96.0 | 42.6–74.4 | in range |
| matched/M1 (control) | 173.0–243.7 | 198.4–225.5 | in range |
| matched/M2 (control) | 102.6–118.9 | 103.4–117.2 | in range |
| matched/R1_Ring (control) | 127.9–156.9 | 134.6–152.5 | in range |
| matched/R2_Ring (control) | 188.2–225.7 | 189.7–225.1 | in range |
| matched/W1_Pool (control) | 201.9–231.5 | 205.6–248.9 | upper edge +5-7% (disclosed) |
| matched/W2_Pool (control) | 156.9–179.0 | 162.7–177.3 | in range |
| matched/J1_ForkJoin (control) | 334.5–363.0 | 311.2–350.5 | in range (fast edge -7%) |
| matched/J2_ForkJoin (control) | 272.5–297.5 | 257.0–346.1 | r2's 346.1 +16% (disclosed); rest in range |

Discarded round (disclosure): after-batch round r3 measured control
C1 at 339.4ms (+158% over its known range) and C2 at 398.4ms (+39%) —
whole-round contamination; its Q1 313.5 / Q2 330.8 (the LOWEST readings
of the batch) were dropped rather than kept, i.e. the discard is
conservative against the claim.

**The scaling story (the point of the round)**: before, Q2 > Q1
(468 > 423 — adding threads made it slower, the single-CAS-point
signature). After, Q2 < Q1 (378.6 < 391.4) — 2P2C's four threads fan
out over four stripes while 1P1C's two threads share one stripe pair.
First time the MS queue scales the right way on this host.

## Intermediate micro regression + fix (measured, disclosed)

The first striping version wrote alloc as one nested loop
(`for probe -> while true`). Matched moved the same way (Q2 -18.5%,
v1 batch n=6), but micro regressed +15..22% (340.3/325.6/349.1 vs
285.2; confirmed real: round 3's controls were all flat ±6% while
MsQueue alone was +22%) with batch-internal bistability (RSD 42–97 vs
baseline 7.3). Hand-peeling the first iteration — own-stripe fast path
in the exact single-loop shape of the pre-stripe code, probe loop
entered only on observed empty — recovered micro to 286.5ns (RSD 4.4)
immediately. FPC -O2 does not peel this itself; the outer loop's
book-keeping (`(AStripe+LProbe) and 7`) was riding the hot path.
Matched was re-measured on the peeled (= committed) binary; v1's Q2
-18.5% and v2's -19.2% agree, so the matched win is the striping, not
the peel.

Notes:
- Sink checksum: all kept matched rounds = 15000019500000 on both
  sides (identical to the F-042 batches; zero value loss). all/micro
  rounds carry the usual dynamic micro contribution (same structure as
  baseline: 5x fixed + 1x variable).
- 1P1C keeps a structural limit: producer allocs drain the consumer's
  recycle stripe via probing, so steady state still funnels through
  one stripe pair — that is why Q1 is flat and why this was never the
  1P1C fix. Single-thread users have ring/spsc at 3-9x faster anyway;
  the MS queue's reason to exist is exactly the multi-writer case Q2
  measures.
- Cost: +7 cache lines per instance (8 stripe heads vs 1), zero extra
  atomics per op on the fast path.

## Functional check

- `test_lockfree_msqueue` behavior suite (20244 tests) re-run AFTER the
  peel edit + `test_lockfree_r2_queues` (pin gate: LNewFreeList /
  FOpStripes scan pins intact) + `test_lockfree` + `test_lockfree_stress`
  + `test_atomic` + verify-t1 + verify-t2-smoke + hygiene +
  `git diff --check`: see commit gate log (run after the after-batch so
  the measured binary is the committed source).
