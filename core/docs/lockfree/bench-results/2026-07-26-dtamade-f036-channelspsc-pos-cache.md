# F-036 — ChannelSpsc: peer-position caching (rigtorp pattern)

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TLockFreeChannelSpscImpl` did a cross-line acquire load of the peer's position
on EVERY op: TrySend read `FRecvPos` (receiver line), TryReceive read
`FSendPos` (sender line). Under steady 1P1C flow that is one guaranteed
coherence miss per op per side — the exact traffic `TSpscQueue` already
eliminates with `FHeadCache`/`FTailCache`.

Fix: add `FRecvCache` (sender line) / `FSendCache` (receiver line) — each cache
lives on the line of the thread that reads it (F-033 rule). The peer position
is re-loaded (acquire) only when the cached value says full/empty; if the fresh
value still says full/empty, fail. Same acquire ordering as before on the
refresh path, so slot reuse/consume visibility is unchanged.

Bonus: TryReceive's dead closed-recheck block (both branches `Exit(False)`)
folded into the cache refresh.

New bench scenario `lockfree/matched/C1s_ChannelSpsc_1P1C` added first
(bench-only edit, built+measured at baseline): 1P+1C threads, OPS=1e6,
CAP=1024 — `matched/C1_1P1C` only covers `TLockFreeChannel`, and the
single-thread `micro/ChannelSpsc/TrySendReceive` cannot see cross-thread
coherence traffic.

## Envelope

```
date_utc:  2026-07-26 (same host/day, back-to-back runs)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-035 commit f96d47aeb + C1s scenario (bench-only edit);
           after = + pos caches (lands as F-036 commit)
workload:  bench_lockfree matched (1P1C threads, OPS=1e6, CAP=1024) + micro
warmup:    micro suite MinDuration=50ms MinSamples=5; matched = whole-run wall time
measured:  matched: ms per 1e6 paired ops; micro: ns per send+receive pair
stats:     C1s: samples=3 before, samples=8 after (3x all + 5x matched);
           others: 3 before / 3+ after; clean rebuild both sides
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean; make ...
           core/build/.../bench_lockfree all (x3); ... matched (x5, after only)
```

## Numbers (same host)

| Scenario | Before | After | Approx delta |
|----------|--------|-------|--------------|
| matched/C1s_ChannelSpsc_1P1C | 89.1 / 98.6 / 106.4 ms | 26.5–96.0 ms, median 46.9 (n=8) | **median ~ -52%**; 7/8 after-samples below the entire before-range |
| micro/ChannelSpsc/TrySendReceive | 39.4 / 39.9 / 41.4 ns | 36.5 / 37.0 / 40.4 ns | ~ -7% (single-thread: only the sender-side load is actually saved per iter) |
| matched/C1_1P1C (control, untouched class) | 252.8 / 254.8 / 299.6 ms | 219.7–327.9 ms (n=8) | overlapping ranges — flat |
| micro/SPSC/TryEnqueueDequeuePair (control) | 30.5 / 30.7 / 31.1 ns | 30.6 / 32.1 / 32.2 ns | flat (noise) |

After-side C1s variance is high (26.5–96.0 ms): with caching, progress runs in
bursts whose length depends on scheduler interleaving; the before-side per-op
coherence miss acted as a (slow) pacing clock. Claim is therefore stated on the
median with the full range disclosed, per envelope discipline.

Attribution signature is clean: the cross-thread scenario moves, the
single-thread micro moves only slightly, and both controls (untouched
TLockFreeChannel, TSpscQueue) are flat.

Relative only; noise and load apply.

## Functional check

- `test_lockfree` full suite green with the F-036 commit (blocking send/receive,
  close semantics, wait/notify paths all exercised there).
- IsEmpty/ApproxLen intentionally keep reading the real published positions
  (no cache) — cross-thread observers see the same freshness as before.
