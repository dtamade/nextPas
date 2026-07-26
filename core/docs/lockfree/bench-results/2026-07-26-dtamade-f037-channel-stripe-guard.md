# F-037 — Channel: resize-guard counter striping

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TLockFreeChannelImpl` guarded TryResize with a single `FActiveOperations`
counter that EVERY thread bumped twice per op (`EnterOperation` fetch_add +
`LeaveOperation` fetch_sub) — one cache line ping-ponging across all producers
and consumers on every TrySend/TryReceive/ApproxLen/Capacity. Padding cannot
help: the contention is on the field itself (cacheline-layout-rules.md §5).
This is the main reason matched C1 (~255ns/op) ran ~5x slower than C1s
(~47ns/op) after F-036.

Fix: split the guard into `CHANNEL_OP_STRIPES = 8` stripes, each a
`{Count: Int32; Pad: TCacheLinePad}` record (adjacent Counts ≥64B apart).
Threads pick a stripe via multiplicative hash of the thread id
(`* $9E3779B9 shr 24 and 7`, `{$Q-}{$R-}` wrap-by-design) — plain shifting
would systematically collide because Linux pthread descriptor addresses are
often 8MB-strided. The stripe index is computed ONCE per op at the call site
and passed explicitly to Enter/LeaveOperation so both hit the same stripe.

TryResize quiescence scans all 8 stripes instead of one counter. The argument
is isomorphic to the single-counter one: `FResizing := 1` is published first;
any entrant that bumps a stripe afterwards re-reads `FResizing` and backs off,
so a stripe observed at 0 can only see transient (immediately undone)
increments. x86 locked RMW closes the Dekker store-load window; no new
memory-order assumptions.

## Envelope

```
date_utc:  2026-07-26 (same host; baseline in a quiet window, after at load ~13
           on a 44-core box — accepted because every control matched its known
           range and the after/before ranges are fully disjoint, see below)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-036 commit 8cdbf7d94; after = + stripe guard
           (lands as F-037 commit); clean rebuild both sides
workload:  bench_lockfree matched (OPS=1e6, CAP=1024) + micro
warmup:    micro suite MinDuration=50ms MinSamples=5; matched = whole-run wall time
measured:  matched: ms per 1e6 paired ops; micro: ns per send+receive pair
stats:     baseline n=8 (3x all + 5x matched); after n=6 (5x matched + 1x all)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   core/build/.../bench_lockfree all (x3); ... matched (x5)
```

A first after-run batch was DISCARDED: external load (other lanes' builds/tests,
load average 35+) polluted the box — detected by the control C1s throwing a
372ms outlier (normal 42–105ms) and micro CV exploding to 36–73 (baseline
1.8–18). Per cacheline-layout-rules.md §6 the control doubles as a pollution
detector; that batch was thrown away. The accepted batch below ran later at
load ~13 (external builds never fully stopped on this box) and passed both
acceptance checks: all controls inside known ranges, signal ranges disjoint.

## Numbers (same host)

| Scenario | Before (n=8, median) | After (n=6, median) | Approx delta |
|----------|---------------------|---------------------|--------------|
| matched/C1_1P1C (signal) | 219.7–327.9 ms, median 254.6 | 107.7–127.5 ms, median 114.0 | **median ~ -55%**; ranges fully disjoint (after max 127.5 << before min 219.7) |
| matched/C2_2P2C (signal) | 277.7–336.7 ms, median 310.5 | 201.1–240.9 ms, median 224.3 | **median ~ -28%**; ranges fully disjoint (after max 240.9 < before min 277.7) |
| micro/Channel/TrySendReceive | 172.9 / 176.2 / 185.0 ns | 179.4 ns (n=1 run, median-of-samples) | flat (single thread: the stripe line stays cached) |
| matched/C1s_ChannelSpsc_1P1C (control, untouched) | 26.5–96.0 ms, median 46.9 | 39.5–52.9 ms, median 43.4 | flat — inside the known range, medians agree |
| micro/SPSC/TryEnqueueDequeuePair (control) | 30.6 / 32.1 / 32.2 ns | 32.1 ns | flat |
| micro/ChannelSpsc/TrySendReceive (control) | 36.5 / 37.0 / 40.4 ns | 37.9 ns | flat |

Attribution signature is clean: both multi-thread channel scenarios move
massively, the single-thread micro is flat (locked RMW on an owned line is
cheap), and all three controls are flat. The after batch ran at load ~13 on a
44-core host; it is accepted despite the non-quiet window because every control
landed inside its known range (C1s medians 46.9 vs 43.4 across batches) and the
signal ranges are fully disjoint from baseline — external noise of this
magnitude cannot manufacture a 2x separation, only mask improvement.

Relative only; noise and load apply.

## Functional check

- `test_lockfree` full suite green with the stripe guard (includes 7 TryResize
  runtime tests); verify-t1 + verify-t2-smoke pass; `test_atomic` 46/46.
- ApproxLen/Capacity keep the guard (they read FCapacity/positions under it);
  the post-TryResize unconditional `LockFreeNotifySpace` is intentional
  (capacity grew — wake all space waiters), not an F-034 violation.
