# F-034 — SPSC queue: waiters>0 guard before notify

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TSpscQueueImpl` TryEnqueue / TryDequeue / EnqueueBatch / DequeueBatch: guard the
unconditional `LockFreeNotifyData/Space` (which always does a locked
`atomic_fetch_add` on the epoch) with `if atomic_load(F*Waiters, mo_relaxed) > 0`.

Same fast-path pattern MPMC / TLockFreeChannel / TLockFreeChannelSpsc already
use. Missed-wakeup window (waiter registers between the producer's guard read
and its return) is backstopped by the bounded `LOCKFREE_WAIT_TIMEOUT_NS` (10 ms)
in every blocking loop — identical accepted semantics to the existing guarded
structures.

New bench scenario `lockfree/micro/SPSC/TryEnqueueDequeuePair` added first
(steady-state single-thread pair: every iteration is a successful
enqueue+dequeue, i.e. both notify sites fire) — the old drain-style
`SPSC/TryDequeue` spends 99.9% of iterations on the empty early-exit path and
cannot see this change.

## Envelope

```
date_utc:  2026-07-26 (same host/day, back-to-back runs)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = f96d47aeb + pair scenario (bench-only edit); after = + spsc guards (lands as F-034 commit)
workload:  bench_lockfree micro — single-thread Try* loops, CAP=1024
warmup:    suite MinDuration=50ms MinSamples=5
measured:  ns per iteration (pair iteration = TryEnqueue + TryDequeue)
stats:     samples=3 before, samples=3 after (clean rebuild both sides)
units:     ns/iter (lower is better)
command:   make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean build
           core/build/.../bench_lockfree micro  (x3)
```

## Numbers (same host, 3 samples each)

| Scenario | Before (unguarded) | After (guarded) | Approx delta |
|----------|--------------------|-----------------|--------------|
| SPSC/TryEnqueueDequeuePair | 44.0 / 45.0 / 44.2 ns | 31.0 / 30.7 / 31.1 ns | **~ -30%** |
| SPSC/TryDequeue (empty path) | 11.3 / 11.5 / 11.5 ns | 12.1 / 11.9 / 11.6 ns | flat (noise; path has no notify) |

The pair saves two locked adds per iteration → ~13 ns / 2 ≈ 6.5 ns per
`lock xadd`, consistent with expected LOCK-prefix cost on this Broadwell part.

Relative only; noise and load apply.

## Functional check

- Blocking wake paths covered by `test_lockfree` runtime tests (incl. the
  pinned "SPSC DequeueTimeout consumer should still be pending before publish"
  publish-wake proof) — run green with the F-034 commit.
