# F-044 — MPSC: node pooling (NEGATIVE result, reverted)

## Motivation (why this looked like the top pain point)

`TMpscQueueImpl` allocates one heap node per enqueue (`New` on a producer
thread) and frees it per dequeue (`Dispose` on the consumer thread). That
pairing makes EVERY node a cross-thread free — FPC's per-thread heap must
route it through the owning heap's locked pending list. The micro pair
baseline carried the matching signature: median ~113.6ns with RSD 44–47
and a bistable distribution (p50 ~92–98, p95 ~173–178), i.e. a fast path
plus a fat heap-manager tail.

## Change (implemented, measured, then REVERTED)

Fixed-capacity node pool (256 nodes, array never moves) + packed
(index:32 | tag:32) Treiber free list (the proven msqueue-pool protocol),
`New`/`Dispose` fallback on pool exhaustion so the queue stays unbounded
and needs NO quiescence protocol. Producers pop the free list on alloc;
the single consumer pushes on recycle. Behavior suites all green
(test_lockfree 191/0, r2_queues 16/0, stress 20/0, 0 leaks).

## Envelope

```
date_utc:  2026-07-26 (same host/session as F-042/F-043)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = committed tree @ef11dd2b4 (v2-batch n=5 reused +
           top-up n=2 same binary); after = + node pool, clean rebuild
workload:  bench_lockfree matched M1 (1P+1C) / M2 (2P+1C, unbounded) +
           micro MPSC TryEnqueueDequeuePair (single thread)
stats:     baseline matched n=7 / micro n=4 at load ~10.0-10.6;
           after matched n=6 / micro n=4 at load ~16-21.6 (load
           asymmetry disclosed; controls stayed within ±3%, so the
           +25..44% signal is not a load artifact)
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
```

## Numbers (same host)

| Scenario | Before (median, range) | After pool (median, range) | Verdict |
|----------|------------------------|----------------------------|---------|
| matched/M1_Mpsc_1P1C | 203.0 (166.3–225.5, n=7) | 292.5 (251.0–341.1, n=6) | **+44% REGRESSION, ranges fully separated** |
| matched/M2_Mpsc_2P1C | 109.5 (103.4–117.2, n=7) | 137.0 (131.4–142.5, n=6) | **+25% REGRESSION, ranges fully separated** |
| micro/MPSC pair | 113.6 (111.7–117.0, RSD 44–47 bistable) | ~121 (112.8–123.7, RSD 2.0–26.9) | +6.6% mean; bistability GONE (p95 174 → 115–168) |
| controls C1/C2/C1s/Q1/Q2/R1/R2/W1/W2/J1/J2 | known ranges | all within range or ±3% edge drift | healthy — regression is real (two-sided reading discipline) |

## Attribution experiment (disclosed, contaminated but directional)

Padding pool nodes to 64B (isolating the pool-nodes-share-a-cache-line
hypothesis) did NOT recover M1 (329/460/329ms across three rounds; M2
126–132 flat vs the pooled build). The experiment batch ran under a
climbing load (22→29.6) with C1 controls +19%/+41% out of range in two
of three rounds — numbers are not quotable, but the direction is
consistent: node adjacency is not the driver. The remaining suspect —
`FFreeHead`, one word CAS'd by producers (pop) AND the consumer (push)
on every op — is exactly the single-point free-list disease F-041
measured in msqueue (there it kept Q2 > Q1 until F-043 striped it).

## Why the heap wins here (the actual finding)

FPC's per-thread heap already IS the right structure for the MPSC node
lifecycle:

- Producer `New` hits the producer's own TLS free list — zero shared
  contention (the pool replaced this with a shared every-op CAS word).
- Consumer `Dispose` takes the owning heap's pending-list lock, but the
  single consumer is the only cross-thread freer — the lock is
  uncontended.
- Pending frees are reclaimed in batches by the owning thread's next
  allocation — the cross-thread cost is amortized, not per-op.

So the "every node pays a cross-thread free" pain hypothesis was wrong
in the dimension that matters: the heap path has no shared hot word,
while any per-queue pool must funnel both sides through one (striping
cannot fix the M1 topology — 1P+1C drains through a single stripe pair,
the F-043 Q1 lesson). The pool's only measured win was distribution
shape in the single-threaded micro (bistable heap tail eliminated), and
that does not pay for -44% matched throughput.

Striping was considered and rejected without measuring: it only helps
multi-producer fan-out (M2's shape), not M1 (1P+1C), which is both the
regression's worst case and MPSC's most common topology (single event
loop fed by a few producers).

## Decision

Full revert to @ef11dd2b4 state (`git checkout` of the module; bench
binary rebuilt from HEAD, r2_queues re-verified 16/0). No source change
lands; this envelope is the deliverable. Residual candidates that would
attack the heap cost WITHOUT a shared word (segment/block allocation à
la crossbeam's 32-node blocks — amortizes New to 1/K with block-local
bump allocation) are algorithm-level and belong to a future cut only if
MPSC ever re-emerges as the top pain.

## Lesson (methodology)

Before pooling any allocator-touching hot path, measure WHERE the
allocator actually contends. A per-thread-freelist heap is already a
TLS pool; layering a shared pool on top converts zero-contention
structure into a single-point CAS. "Heap call in hot path" is a smell,
not a verdict — the envelope discipline (controls flat + signal alone
moved = real) caught this in one round-trip.
