# Phase E — Channel NotifySelector hot-path skip

> Relative improvement only. Not a Go/Rust absolute marketing claim.

## Change

`TLockFreeChannelImpl.NotifySelector`: exit early when `FNotifierState = CHANNEL_NOTIFIER_NONE`
(no selector registered). Avoids taking `FNotifierLock` on every successful TrySend/TryReceive.

Matched bench and typical runtime use never set a channel notifier; Selector path still takes the lock when enabled.

## Envelope

```
date_utc:  2026-07-20T19:15:53Z
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1
build_id:  12705504c (+ channel.pas uncommitted at measure) / land with E commit
workload:  Q5 matched C1/C2 OPS=1e6 CAP=1024 TLockFreeChannel
measured:  wall-clock one suite entry = 1e6 send+recv ops
stats:     samples=3 post-change (same binary); baseline sample=1 pre-change same host
units:     ms wall for OPS=1e6 (lower is better)
command:   make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree build
           core/build/.../bench_lockfree matched
```

## Numbers (same host, OPS=1e6)

| Scenario | Before (1 sample) | After (3 samples) | Approx delta |
|----------|-------------------|-------------------|--------------|
| C1 1P+1C | 446.73 ms (~2.2 Mops) | 314.92 / 298.65 / 307.66 ms (~3.2–3.3 Mops) | **~1.4–1.5×** faster |
| C2 2P+2C | 647.74 ms (~1.5 Mops) | 344.79 / 318.28 / 344.83 ms (~2.9–3.1 Mops) | **~1.9–2.0×** faster |

Relative only; noise and load apply. Go/Rust absolute gaps may remain (see Q5 matched notes).

## Functional check

- `test_lockfree` Selector cases remain part of main suite (run with land verification).
