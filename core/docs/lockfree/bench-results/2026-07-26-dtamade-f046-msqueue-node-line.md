# F-046 — MsQueue: free link folded into the node; full-line node pad measured null

## Motivation

After F-043, Q1 (407ms) / Q2 (382ms) topped the matched pain list — the
remaining serial cost was hypothesized as index-pool data-plane locality.
Two suspected diseases:

1. `TNode` was 24B (T=Pointer): 2.67 nodes/line. At near-empty steady
   state the working set is a handful of indices, so the producer filling
   node n+1 and the consumer recycling node n constantly hit the SAME
   line — every-op false sharing between DIFFERENT nodes. (The handoff on
   one node is algorithm-inherent true sharing; the neighbor traffic is
   not — the part padding could treat, per the F-032 argument.)
2. `FFreeList` was a separate 4B-element array: 16 free-links/line — the
   same disease on the recycle path. Every alloc/recycle touched two
   arrays (node + free link) = two lines per op.

Distinction vs the F-042 ring null result: F-042 padded CONTROL words
while the ring's traffic lives in the slot array; here the pad went on
the DATA plane itself — first data-plane pad actually measured.

## Change (final, landed)

- `FFreeNext: Int32` moves INTO `TNode`; the separate `FFreeList` array
  (and `TFreeNode`) are deleted. Alloc/recycle now touch one line, not
  two. Grow/Create build the per-stripe free chains in the node storage.
- The full-line node pad (TNode 24B → 96B) was implemented, measured,
  and REVERTED: no matched-pair signal (see Numbers), so the 4x node
  storage cost is not justified. Nodes stay dense (32B with the folded
  link, 2 nodes/line).
- CAS protocol, stripe scheme (F-041/F-043), and all orderings unchanged.
- r2_queues pin updated: free-chain-in-local-storage marker
  (`LNewNodes[LI].FFreeNext`).

## Envelope

```
date_utc:  2026-07-26 (same host/session as F-043/F-044/F-045)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = committed tree @354bd1783 clean build
           (= F-045 after batch, /tmp/f045_after.txt);
           padded  = + fold + full-line node pad, clean rebuild;
           final   = + fold only (pad reverted), clean rebuild
workload:  bench_lockfree matched (13 scenarios) + micro
           MsQueue TryEnqueueDequeuePair (1T)
stats:     baseline n=7 matched / n=4 micro, loads 11.4-12.6;
           padded   n=7 matched / n=4 micro, loads 14.0-17.5;
           final    n=5 matched / n=3 micro, loads 12.2-15.1
           (one earlier padded batch at loads 20.7-26.4 was discarded —
           controls blew out of known ranges)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
```

## Numbers (same host)

| Scenario | Baseline (median, range) | Padded (median, range) | Final = fold only (median, range) | Verdict |
|----------|--------------------------|-------------------------|-----------------------------------|---------|
| matched/Q1_MsQueue_1P1C | 407.2 (341.5-431.2) | 424.5 (336.5-448.8) | 433.0 (412.7-487.4) | flat (host drift, see below) |
| matched/Q2_MsQueue_2P2C | 382.5 (319.1-455.6) | 361.5 (302.8-396.5) | 385.2 (326.8-404.2) | flat |
| micro/MsQueue/TryEnqueueDequeuePair | 300.8 (287.2-339.6) | 285.2 (280.6-300.6) | 286.4 (271.3-325.0) | ~-5% both variants |
| controls (C1/C1s/C2/J1/J2/M1/M2/R1/W1/W2) | known ranges | 10/11 in range | 10/11 in range | pass |
| control R2 | 199.6 (188.8-213.9) | 222.7 (208.9-243.4) | 219.8 (207.1-233.0) | +10% BOTH batches = session drift, not msqueue |

Reading discipline notes:

- **Q1 verdict**: both variants drift +4-6% vs baseline in the same
  direction and magnitude as the R2 control (+10% in both after
  batches) — a shared session-drift signature, not a per-variant
  regression. Neither variant separates from baseline. The padded
  batch also ran under heavier load (14.0-17.5 vs 11.4-12.6), which
  masks small effects in the noise direction; disclosed, not corrected.
- **micro attribution**: the two variants share ONLY the freelist fold,
  and both land ~-5% with several rounds below the baseline range floor
  (287.2): 280.6/281.3/284.2 (padded), 271.3/286.4 (final). Natural
  A/A' cross-check → the gain is the one-line-fewer touch per
  alloc/recycle, independent of node spacing. n small; direction
  consistent, no separation claim.
- **Null result (the headline)**: one-node-per-line padding moved
  NOTHING in matched pairs. The multi-thread cost of msqueue is CAS
  contention on head/tail (+ the inherent single-node handoff), not
  neighbor-node false sharing — the F-042 conclusion (pad the wrong
  plane, no signal) now reproduced ON the data plane. Combined with
  F-042 this closes the padding family for queue data planes: density
  stays.

## Gates

msqueue 20244 + r2_queues 16 (pin updated) + lockfree 191 + atomic 46 +
stress (8 rounds padded / 3 rounds final) + verify-t1 + verify-t2-smoke +
hygiene + `git diff --check` — all green, 0 leaks, both variants.

Side-product: stress MPMC close-race timing flake fixed independently
@f30e76e8b (3P+2C burn 8192 values inside one 1ms sleep quantum on an
idle host; producers now spin until IsClosed after exhausting values —
the close-while-live assertion holds by construction). Baseline 10
rounds → 3 failures; fixed 15 rounds → all green.
