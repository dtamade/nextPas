# Q5 formal matched results (samples≥3)

> **Not a marketing claim.** Relative same-host comparison only.
> Absolute Mops require this envelope; re-run after significant code/hardware change.

## Envelope

```
date_utc:  2026-07-20T05:33:48Z
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz
compiler:  fpc 3.3.1 / go / rustc -C opt-level=3
build_id:  9d9e5653f87c7449121da9bdd8b64e9d74e4aa75
workload:  Q5 C1/C2 OPS=1e6 CAP=1024 (matched suite)
warmup:    none (each sample cold-start process)
measured:  wall-clock full scenario per sample
stats:     samples=3 mean/median/min/max
units:     M ops/sec
command:   SAMPLES=3 /home/dtamade/projects/nextPas/.worktrees/atomic-lockfree/core/docs/lockfree/scripts/run-q5-matched-formal.sh
```

## Results (M ops/sec)

| Lang | Scenario | mean | median | min | max | n |
|------|----------|-----:|-------:|----:|----:|--:|
| go | C1 chan uint64 1P+1C | 8.400 | 8.300 | 8.100 | 8.800 | 3 |
| go | C2 chan uint64 2P+2C | 4.000 | 4.000 | 3.800 | 4.200 | 3 |
| nextpas | C1 TLockFreeChannel 1P+1C | 2.300 | 2.300 | 2.200 | 2.400 | 3 |
| nextpas | C2 TLockFreeChannel 2P+2C | 1.433 | 1.400 | 1.400 | 1.500 | 3 |
| rust | C1 std::sync::mpsc 1P+1C | 23.467 | 22.800 | 21.900 | 25.700 | 3 |
| rust | C2 Mutex+Condvar VecDeque 2P+2C | 0.500 | 0.500 | 0.500 | 0.500 | 3 |

## Notes

- nextpas: `TLockFreeChannel` C1 1P+1C / C2 2P+2C
- go: buffered `chan` peers (includes historical 1T if present)
- rust: mpsc / mutex queue peers — semantic gaps apply
- See [bench-envelope.md](../bench-envelope.md) Q5 section.
