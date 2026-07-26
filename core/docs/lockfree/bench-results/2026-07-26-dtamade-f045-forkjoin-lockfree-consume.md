# F-045 — ForkJoin: lock-free consume side (PopOrSteal drops the owner lock)

## Motivation

After F-040, J1 remained the slowest matched family (~351-371ms, ~1.6x W1
on the same deque skeleton). The residual cause was architectural:
`PopOrSteal` took `AcquireOwner(AWorkerId)` + `TryPop` for the local deque
on EVERY consume, while workstealing's `Steal` tries the lock-free
`TrySteal` first. In J1 (1 forker + 1 worker) the worker's every-op lock
acquisition also contends with the forker's round-robin `Fork` on the same
lock word (25% of forks target deque 0).

Key observation that unlocked the cut: `Fork` round-robins tasks across
ALL deques — tasks are never forked by the worker that pops them, so the
"local LIFO pop = stack-hot cache" property was already fictional under
this API. The Chase-Lev deque contract makes `TrySteal` multi-thief safe,
so the consume side needs no owner role at all.

## Change

`PopOrSteal` now scans all deques with lock-free `TrySteal`, starting at
the caller's own (I = 0..WorkerCount-1, victim = (AWorkerId+I) mod N).
The owner lock survives only on the `Fork` side, where the deque's
single-owner `TryPush` contract genuinely requires serialization. Local
take order changes LIFO → FIFO — semantically free (task pool, no
ordering contract; behavior suite asserts sums, not order). `False` may
still mean "lost a steal race" rather than "empty", same as before —
callers already poll. Docs updated; the invalid-worker-ID guard (pinned
by test_lockfree ReadSource) is unchanged.

## Envelope

```
date_utc:  2026-07-26 (same host/session as F-042/F-043/F-044)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = committed tree @9e6eee480 clean build;
           after = + F-045, clean rebuild
workload:  bench_lockfree matched J1 (1F+1W) / J2 (2F+2W, 4 workers,
           bounded deques) + micro ForkJoin Fork+PopOrSteal pair (1T)
stats:     n=7 matched / n=4 micro per side; loads baseline 11.9-15.6,
           after 11.4-12.6 (after ran LIGHTER — favors neither claim
           direction since controls stayed flat)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
```

## Numbers (same host)

| Scenario | Before (median, range) | After (median, range) | Verdict |
|----------|------------------------|------------------------|---------|
| matched/J1_ForkJoin_1F1W | 370.6 (350.7–405.3) | 273.6 (258.5–289.5) | **-26.2%, ranges fully separated** |
| matched/J2_ForkJoin_2F2W | 287.3 (260.2–302.6) | 230.2 (226.5–233.2) | **-19.9%, ranges fully separated** |
| micro/ForkJoin/ForkPopPair | 200.2 (198.1–208.1) | 156.2 (155.0–171.2) | **-22.0%, ranges fully separated** |
| controls: C1/C2/C1s/M1/M2/Q1/Q2/R1/R2/W1/W2 + 4 micro | known ranges | all ranges overlap (drift -7.9%..+11.9%, high-variance C1s/R1 within their known spread) | healthy |

Attribution signature matches F-040's taxonomy: the cut removes locked
RMWs from the consume path itself (lock CAS + release store per op, plus
TryPop's seq_cst last-item arbitration replaced by TrySteal's single
CAS), so micro moves big alongside matched — unlike pure layout cuts
(micro flat, F-041/F-042).

## Post-cut standing

J1 273.6 / J2 230.2 vs W1 230.3 / W2 169.7 — the residual ~19-36% gap vs
workstealing is structural: Fork still takes the owner lock (TryPush
contract) and forkjoin pays the FForked/FDone pending-count semantics that
the workstealing pool does not offer. J1 is no longer the slowest matched
family; Q1 (407) / Q2 (382) msqueue now top the pain list.

## Residuals (recorded, not acted on)

- Fork-side lock: removing it needs an MPMC push channel (inbox) or true
  owner-thread affinity (workers fork to their own deque) — API-level.
- `TWorkStealingPool.Steal` still carries an AcquireOwner+TryPop fallback
  after its TrySteal sweep (its ReadSource pin asserts it); candidate for
  the same treatment in a separate cut with its own bench reading.
