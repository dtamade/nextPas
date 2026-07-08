# Lockfree Data Structure Selection Guide

> Updated: 2026-07-06

[中文版](selection-guide.md)

## Quick Decision Tree

```
Need a queue?
├── Single producer + Single consumer (SPSC)
│   └── Use TSpscQueue<T>
│       - Fastest, no CAS contention
│       - Supports batch/wait/timeout/close
│       - Performance: 4.4 M ops/s
│
├── Single producer + Multiple consumers (SPMC)
│   └── Use TSpmcQueue<T>
│       - Multiple consumers CAS-compete for dequeue
│       - Supports wait/timeout/close
│       - Performance: 2.6 M ops/s (1P+2C)
│
├── Multiple producers + Multiple consumers (MPMC)
│   └── Use TMpmcQueue<T>
│       - General purpose but has CAS contention overhead
│       - Supports batch/wait/timeout/close
│       - Performance: 1.3 M ops/s (2P+2C)
│
├── Multiple producers + Single consumer (MPSC)
│   └── Use TMpscQueue<T>
│       - Unbounded, multi-producer safe
│       - Supports wait/timeout/try-enqueue/close
│       - Performance: Highest (no CAS enqueue)
│
└── Unbounded MPSC (high throughput)
    └── Use TSegQueue<T>
        - Segmented design, EBR reclamation
        - Unbounded, auto-extending
        - Supports try-enqueue/close
        - Performance: 1.5 M ops/s (2P+2C)

Need a stack?
├── LIFO (Last In First Out)
│   └── Use TLockFreeStack<T>
│       - Treiber stack algorithm
│       - ABA safe
│       - Performance: Highest (single CAS push/pop)
│
└── Work stealing (owner push/pop + thief steal)
    └── Use TWorkStealingDeque<T>
        - Owner LIFO pop, thief FIFO steal
        - Suitable for task scheduling
        - Performance: Depends on contention

Need memory reclamation?
├── Use TEbrDomain + TEbrGuard
│   - Epoch-Based Reclamation
│   - Conservative single-check design
│   - Suitable for: Read-heavy scenarios
│
└── Use THazardDomain
    - Hazard Pointer
    - Precise protection, suitable for balanced read/write scenarios
    - Suitable for: Latency-sensitive, memory-constrained scenarios

Need concurrent HashMap?
└── Use TShardedHashMap<TKey,TValue>
    - Sharded-lock HashMap (16 shards)
    - Insert/Find/Remove/Contains/Count
    - Auto resize + Reserve pre-allocation

Need Channel (producer-consumer communication)?
├── Single direction communication
│   ├── Single producer single consumer (1P1C)
│   │   └── Use TLockFreeChannelSpsc<T>
│   │       - Optimized for 1P1C, uses atomic load/store
│   │       - Performance surpasses Go channel (2.99x) and Rust (1.26x)
│   │       - Blocking/non-blocking/timeout
│   │
│   └── Multiple producers multiple consumers (MPMC)
│       └── Use TLockFreeChannel<T>
│           - Bounded, capacity auto-rounded to power-of-two
│           - Blocking/non-blocking/timeout
│           - Already-enqueued data still readable after Close
│           - Dynamic capacity adjustment via TryResize
│
└── Multi-channel multiplexing (Go select semantics)
    └── Use TLockFreeSelector<T>
        - Wait for first ready among multiple channels
        - Blocking/timeout wait modes
        - All cases must use same type T
```

## Performance Comparison

| Data Structure | Scenario | Throughput (M ops/s) | Latency (ns/op) |
|----------------|----------|---------------------|-----------------|
| TSpscQueue | 1P+1C | 101 | 9.9 |
| TSpmcQueue | 1P+2C | 75 | 13.4 |
| TMpmcQueue | 2P+2C | 68 | 14.6 |
| TMpscQueue | 4P+1C | ~68 | ~15 |
| TSegQueue | 2P+2C | 17 | 59.1 |
| TLockFreeStack | 4P+4C | ~67 | ~15 |
| TWorkStealingDeque | 1 owner + 2 thieves | ~2.0 | ~500 |
| **TLockFreeChannelSpsc** | **1P+1C** | **26.2** | **38.2** |
| TLockFreeChannel | MPMC | 10.6 | 94.3 |

### Cross-Language Comparison (1P1C Channel)

| Implementation | Latency (ns/op) | Throughput (M ops/s) | Relative to Go |
|----------------|-----------------|---------------------|----------------|
| **nextpas SPSC Channel** | **38.2** | **26.2** | **2.99x faster** |
| Rust std::sync::mpsc | 48.3 | 20.7 | 2.37x faster |
| Go channel | 114.3 | 8.7 | Baseline |
| C++ mutex+condvar | 202.2 | 4.9 | 0.56x |

## Thread Safety Contract

| Data Structure | Producers | Consumers | Close Safe |
|----------------|-----------|-----------|------------|
| TSpscQueue | 1 thread | 1 thread | ✅ |
| TSpmcQueue | 1 thread | N threads | ✅ |
| TMpmcQueue | N threads | N threads | ✅ |
| TMpscQueue | N threads | 1 thread | ✅ |
| TSegQueue | N threads | N threads | ✅ |
| TLockFreeStack | N threads | N threads | N/A |
| TWorkStealingDeque | 1 owner + N thieves | 1 owner + N thieves | N/A |
| TLockFreeChannelSpsc | 1 thread | 1 thread | ✅ |
| TLockFreeChannel | N threads | N threads | ✅ |

## Memory Reclamation Scheme Selection

| Scheme | Use Case | Latency | Memory Overhead |
|--------|----------|---------|-----------------|
| EBR | Read-heavy | Low | Retired list |
| Hazard Pointer | Balanced read/write | Medium | Per-thread hazard array |
| No reclamation (leak) | Short lifecycle | Lowest | None |
