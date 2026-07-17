# Lockfree Data Structure Selection Guide

> Updated: 2026-07-17

[中文版](selection-guide.md)

> Relative performance: see `core/benchmarks/nextpas.core.lockfree`. This guide does **not** publish absolute Mops/s without a platform/compiler evidence envelope.

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

## Notes

- Default facade `uses nextpas.core.lockfree` is **T1-only**. Import T2/T3 units directly.
- Element types must be unmanaged for T1 generics (`IsManagedType` reject).
- FPC RTL isolation: only `nextpas.core.system` may `uses` SysUtils/etc.; production, examples, and tests must use framework owners.
