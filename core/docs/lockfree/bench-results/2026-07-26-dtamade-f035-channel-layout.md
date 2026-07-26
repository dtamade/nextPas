# F-035 — Channel field layout: real cache-line pads + thread-affinity grouping

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TLockFreeChannelImpl` + `TLockFreeChannelSpscImpl` field blocks rebuilt per the
F-032/F-033 rules:

- Replaced the hand-rolled `array[0..47] of Byte` pads (8+48 = **56 B**, never a
  full line — with FPC's 8/16 B instance alignment the sender/receiver groups
  could still share a line ~50% of heap placements) with full-line `TCacheLinePad`.
- Added `FPadHeader` between the read-mostly header (`FSlots/FCapacity/FMask`)
  and the first hot-written field (previously unconditional read-side false
  sharing on every op).
- Wait cells moved to the notifying side's line (sender line owns
  `FDataEpoch/FDataWaiters`, receiver line owns `FSpaceEpoch/FSpaceWaiters`),
  so the per-op waiters-guard read stays on the line the op just wrote.
- MPMC channel only: `FActiveOperations` (RMW'd by every op from both sides for
  the resize guard) isolated on its own padded line so it cannot drag the
  read-mostly control words (`FClosed/FResizing/FNotifier*`) with it.

Declaration-order + padding change only; zero logic edits.

## Envelope

```
date_utc:  2026-07-26T09:39:29Z
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = 015fde0cf clean; after = 015fde0cf + channel layout edits (lands as F-035 commit)
workload:  bench_lockfree all — Q5 matched C1/C2 OPS=1e6 CAP=1024 TLockFreeChannel
           + micro TrySendReceive (Channel = TLockFreeChannel, ChannelSpsc = TLockFreeChannelSpsc)
warmup:    micro suite MinDuration=50ms MinSamples=5; matched = full-run wall clock
measured:  matched: wall-clock per 1e6 send+recv ops; micro: ns/op single-thread
stats:     samples=3 before (same host, same day), samples=3 after
units:     matched ms wall (lower better); micro ns/op (lower better)
command:   make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree build
           core/build/.../bench_lockfree all  (x3)
```

## Numbers (same host, 3 samples each)

| Scenario | Before @015fde0cf | After (F-035) | Approx delta |
|----------|-------------------|---------------|--------------|
| matched C1 1P+1C | 297.3 / 292.1 / 272.6 ms | 222.3 / 227.2 / 222.3 ms | **~ -19–24%** |
| matched C2 2P+2C | 318.8 / 345.9 / 289.2 ms | 255.4 / 267.1 / 251.2 ms | **~ -13–20%** |
| micro Channel TrySendReceive | 169.3 / 171.2 ns | 171.9 / 178.6 / 171.7 ns | flat (noise) |
| micro ChannelSpsc TrySendReceive | 41.9 / 40.9 ns | 42.3 / 42.5 / 42.2 ns | flat (noise) |

Attribution is clean: only the cross-thread matched scenarios move; the
single-thread micro paths are unchanged — exactly the signature of a false
sharing fix (padding changes cost nothing single-threaded).

Relative only; noise and load apply.

## Functional check

- `test_lockfree` full suite + `verify-t1` + `verify-t2-smoke` + `test_atomic`
  run green with the F-035 commit (see commit message for the gate evidence).
