# Lockfree Data Structure Selection Guide

> Updated: 2026-07-20 (Maintenance preferred close-out; task-delivery table)

[中文版](selection-guide.md)

> Relative performance: see `core/benchmarks/nextpas.core.lockfree`. This guide does **not** publish absolute Mops/s without a platform/compiler evidence envelope.
> Production atomics: prefer `atomic_*` + `mo_*` ([`READY.md`](READY.md) preferred residual 0).

## Task delivery: channel / bag / mpsc / segqueue

Shortest map when handing work to other threads (details still in the decision tree and [`CONTRACT.md`](CONTRACT.md)).

| Need | Choose | Common mistake |
|------|--------|----------------|
| **Bounded + backpressure** | `TLockFreeChannel` (MPMC) or `TLockFreeChannelSpsc` (1P1C) | Unbounded queues under overload |
| **Many producers, one consumer** | `TMpscQueue` | Multiple consumers → use MPMC / SegQueue / Channel |
| **N-worker shared task pool (unbounded)** | `TSegQueue` (production: `thread.pool`) | Prefer MPSC when there is truly one consumer |
| **Bag / multiset work items** | `TLockFreeBag` (**H3-2**, direct `uses`, not on default facade) | Need keyed index → multimap, not bag |
| **One key, many values** | `TLockFreeMultiMap` (**H3-2**, single lock, not LF) | Do not treat as lock-free map |
| **Owner + steal scheduling** | `TWorkStealingDeque` (`thread.pool.worksteal`) | `deque_lf` is **spin-lock** (name is misleading) |

**Lifecycle (T1 containers):** **Close → join producers/waiters → Free**.
`Destroy` Close+drain does **not** replace join.
Teaching: `t1_close_join_free/` (Channel), `t1_segqueue_workers/` (SegQueue), `t2_bag_close_join_free/` (H3-2 Bag).

**SegQueue and MPSC:** stop enqueuers after Close → join → Free; segment reclamation uses EBR — do not Free while producers are live.

## Quick Decision Tree

```
Need a queue?
├── Single producer + Single consumer (SPSC)
│   └── Use TSpscQueue<T>
│       - Usually fastest (no CAS contention)
│       - Supports batch/wait/timeout/close
│
├── Single producer + Multiple consumers (SPMC)
│   └── Use TSpmcQueue<T>
│       - Consumers CAS-compete on dequeue
│       - Supports wait/timeout/close
│
├── Multiple producers + Multiple consumers (MPMC)
│   ├── Use TMpmcQueue<T> (bounded ring)
│   ├── Use TLockFreeMsQueue<T> (unbounded node pool)
│   │   - Close → join → Free; Destroy Close+drain still needs quiescent Free
│   └── Use TSegQueue<T> (unbounded segmented MPMC)
│       - EBR segments; after Close: TryEnqueue=False, Enqueue raises
│
├── Multiple producers + Single consumer (MPSC)
│   └── Use TMpscQueue<T>
│       - Unbounded linked list; single consumer
│       - After Close: TryEnqueue=False; Enqueue raises EInvalidOperationError
│       - Lifecycle: Close → join producers/waiters → Free
│
Need a stack?
├── LIFO
│   └── Use TLockFreeStack<T> (TryPush/TryPop only)
│
└── Work stealing
    └── Use TWorkStealingDeque<T>
        - Owner TryPush/TryPop; thieves TrySteal; Close supported

Need reclamation?
├── TEbrDomain / TQSBRDomain (zero-active QSBR-style)
└── THazardDomain (hazard pointers)

Need concurrent HashMap?
└── TShardedHashMap / TConcurrentHashMap (same implementation alias)
    - Sharded spin locks — NOT lock-free
```

## ClosedPublishPolicy (T1)

| Surface | After Close |
|---------|-------------|
| All `Try*` | False |
| Plain `Enqueue` / `Send` (MPSC, Channel, SegQueue) | raise `EInvalidOperationError` |
| Ring Wait/Timeout | False |

Optional `Try*Ex` (`TLockFreeTryError`) distinguishes full/empty/closed without changing Boolean hot-path `Try*` (Channel/SegQueue/SPSC/MPMC/SPMC/MPSC/Stack).

## Notes

- Default facade `uses nextpas.core.lockfree` is **T1-only**. Import T2/T3 units directly.
- Element types must be unmanaged for T1 generics (`IsManagedType` reject).
- FPC RTL isolation: only `nextpas.core.system` may `uses` SysUtils/etc.; production, examples, and tests must use framework owners.
