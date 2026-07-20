# Q5 matched run (historical attachment)

> **Not a marketing claim.** `stats: samples=1`. Re-run with N≥3 under [`bench-envelope.md`](../bench-envelope.md) before publishing absolutes.
> Command: `make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree compare-matched`

## Envelope (representative)

```
date_utc:  2026-07-19T19:06:44Z
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 / go gc / rustc -C opt-level=3
build_id:  2db9469f4 (lane tip before Q5 commit)
workload:  Q5 C1/C2 OPS=1e6 CAP=1024
stats:     samples=1
```

## Numbers (single run)

| Scenario | nextpas | Go chan | Rust peer |
|----------|---------|---------|-----------|
| C1 1P+1C | ~2.1 Mops | ~6.6 Mops | mpsc ~22.8 Mops (unbounded) |
| C2 2P+2C | ~1.3 Mops | ~4.3 Mops | mutex queue ~0.5 Mops |

Relative only; semantic gaps apply (see bench-envelope Q5 section).
