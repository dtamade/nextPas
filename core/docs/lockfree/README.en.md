# nextpas.core.lockfree

[中文版](README.md)

`nextpas.core.lockfree` provides reusable lock-free-oriented / concurrent data structures for nextpas.core internals. This module primarily serves runtime/framework internal hot paths rather than claiming to be a complete replacement for Rust std, Go std, or C++ std concurrent containers; **lock-free progress claims only apply to types listed as lock-free in the matrix**, and only where underlying platform atomics are themselves lock-free.

All structures only accept unmanaged element types; `string`, interface, dynamic array and other managed types are rejected.
All T1 element-generic containers (`TSpscQueue`, `TMpmcQueue`, `TMpscQueue`, `TSpmcQueue`, `TSegQueue`, `TLockFreeMsQueue`, `TLockFreeStack`, `TWorkStealingDeque`, `TLockFreeChannel`, `TLockFreeChannelSpsc`, `TShardedHashMap` keys/values) reject managed types at construction with `EArgumentError`.

**Layer**: L1 (depends on L0 `base` + `atomic`; see `core/docs/core-module-registry.md`).

**Status**: **Maintenance preferred close-out** — H3-1…H3-5 complete; production preferred residual **0**. See [`READY.md`](READY.md) (three-sentence delivery).
Absolute throughput numbers require [`bench-envelope.md`](bench-envelope.md). Chinese [`README.md`](README.md) is the fuller product entry.

**Preferred atomics**: new code uses `atomic_*` + `mo_*` / `TAtomic*`. Nail: `make focused FOCUS=core/tests/nextpas.core.lockfree/test_lockfree_preferred_path`.

**Teaching examples** (Close → join → Free):
- `core/examples/nextpas.core.lockfree/t1_close_join_free/` — Channel
- `core/examples/nextpas.core.lockfree/t1_segqueue_workers/` — SegQueue N producers + N workers
- `core/examples/nextpas.core.lockfree/t2_bag_close_join_free/` — H3-2 Bag
- `core/examples/nextpas.core.lockfree/t2_multimap_close_join_free/` — H3-2 MultiMap (single spin lock)

**Selection**: [`selection-guide.md`](selection-guide.md) / [EN](selection-guide.en.md) — includes **task-delivery** table (channel / bag / mpsc / segqueue).

## Progress-guarantee matrix

| Class | Progress model | Sync mechanism | Default facade (T1) |
| --- | --- | --- | --- |
| SPSC/MPMC/SPMC/SegQueue/MSQueue/Stack/Channel | lock-free | atomics | yes |
| MPSC | lock-free producers + single-owner consumer | atomics | yes |
| WorkStealingDeque | lock-free + single-owner push/pop | atomics | yes |
| EBR/Hazard | reclamation domains | atomics + TLS/HP | yes |
| Selector | concurrent multiplexer | poll/backoff | yes |
| ShardedHashMap / ConcurrentHashMap | **lock-based concurrent** | per-shard spin lock | yes |
| Trees/caches/CRDT/RTM/NUMA/most lockfree.* extras | lock-based concurrent or specialized | see unit docs | **no** — direct unit import |

**Naming honesty (do not trust the name alone)**:
- `deque_lf` / **`TLockFreeDeque`**: **spin-lock** deque — not lock-free; real LF work-stealing deque is `TWorkStealingDeque` (`lockfree.deque`).
- `hashtable` / **`TLockFreeHashTable*`**: LF-ish reads + **writer spinlock / grow**.
- `dag` / `graph` / `skiplist*` / most trees: **per-node or global locks** (headers often say NOT lock-free).
- `mutex` / `rwlock` / `phaser` / caches (`lfu`, `lru*`): concurrent helpers / sharded locks — not “LF containers by namespace”.
- Full table: [`CONTRACT.md`](CONTRACT.md) §0; inventory: [`t2-inventory.md`](t2-inventory.md).

## Tiered surface

| Tier | Contents | How to use |
| --- | --- | --- |
| **T1 runtime core** | queues, stack, deque, EBR/Hazard, channel, selector, sharded hashmap | `uses nextpas.core.lockfree;` |
| **T2 concurrent containers** | skiplist, btree, caches, bloom, bag, multimap, … | `uses nextpas.core.lockfree.<unit>;` |
| **T3 research** | RTM/NUMA maps, experimental | direct unit only |

## Module Layers (T1 live set)

The current T1 live source set consists of these units:

| Unit | Responsibility |
|------|---------------|
| `nextpas.core.lockfree.base` | Common capacity helpers and spin parameters. |
| `nextpas.core.lockfree.wait` | Data/space wait helpers, reusing atomic wait-address platform seam. |
| `nextpas.core.lockfree.spsc` | `TSpscQueue<T>`, bounded single-producer/single-consumer ring queue. |
| `nextpas.core.lockfree.mpmc` | `TMpmcQueue<T>`, bounded multi-producer/multi-consumer ring queue. |
| `nextpas.core.lockfree.mpsc` | `TMpscQueue<T>`, unbounded multi-producer/single-consumer linked queue. |
| `nextpas.core.lockfree.stack` | `TLockFreeStack<T>`, bounded stack using tagged index to constrain ABA-sensitive top/free-list reuse risk. |
| `nextpas.core.lockfree.deque` | `TWorkStealingDeque<T>`, bounded single-owner push/pop + multi-thief steal deque. |
| `nextpas.core.lockfree.ebr` | `TEbrDomain` + `TEbrGuard`, conservative epoch-based reclamation domain. |
| `nextpas.core.lockfree.hazard` | `THazardDomain` + `THazardGuard`, Hazard Pointer memory reclamation domain. |
| `nextpas.core.lockfree.segqueue` | `TSegQueue<T>`, unbounded multi-producer/multi-consumer segment queue, recycling old segments via EBR. |
| `nextpas.core.lockfree.spmc` | `TSpmcQueue<T>`, bounded single-producer/multi-consumer ring queue. |
| `nextpas.core.lockfree.msqueue` | `TLockFreeMsQueue<T>`, Michael-Scott unbounded MPMC queue. |
| `nextpas.core.lockfree.hashmap` | `TShardedHashMap<TKey, TValue>`, **sharded-lock** concurrent HashMap (not lock-free). |
| `nextpas.core.lockfree.channel` | `TLockFreeChannel<T>`, bounded lock-free Channel, sequence-number driven MPMC channel. |
| `nextpas.core.lockfree.selector` | `TLockFreeSelector<T>`, multi-channel multiplexer. |
| `nextpas.core.lockfree` | **T1-only** default facade. |

Default facade exposes only T1 types. `TLockFreeChannelSpsc` remains on `nextpas.core.lockfree.channel.spsc`.

The facade and submodule public names are wrapper classes over shared `*Impl<T>` implementation
bases. Keep variables and parameters on one public boundary; the wrappers are source-compatible
constructors, not Pascal type aliases.

## API Boundaries

`TSpscQueue<T>` allows only one producer and one consumer to use concurrently. `TryEnqueue` / `TryDequeue`
are non-blocking operations; `EnqueueWait` / `DequeueWait` block via wait-address seam; timeout versions use nanosecond timeouts.
Batch APIs are convenience methods over consecutive single-element operations, not indicating the entire batch has a shared linearization point.
`TSpscQueue<T>.EnqueueBatch` / `DequeueBatch` publish or consume only the prefix that currently fits or is available, capped by the caller-provided array/count, and return that partial count instead of waiting for the remainder.
`TSpscQueue<T>.EnqueueBatch` returns 0 after `Close` and must not publish new items.

`TMpmcQueue<T>` supports multiple producers and multiple consumers. The queue is a fixed-capacity ring, with capacity rounded up to power-of-two at construction. `Close` prevents `TryEnqueue` from succeeding for producers that observe the closed flag and wakes waiters; producers that have already entered the admitted enqueue区间 can still publish at their normal per-item linearization point; consumers only treat closed-empty as terminal after no admitted producer can still publish.
`TMpmcQueue<T>.EnqueueBatch` / `DequeueBatch` are convenience loops over consecutive `TryEnqueue` / `TryDequeue` calls: they return the successful prefix so far when the next single-item operation would fail, instead of waiting for the remainder or promising a shared batch linearization point.
`TMpmcQueue<T>.EnqueueBatch` returns 0 when it observes `Close` before publishing any item; under concurrent `Close`, it returns the prefix already published by its underlying `TryEnqueue` calls.
`TMpmcQueue<T>` accepts requested capacity 1; its per-slot sequence token uses separate empty/full states so a single-slot queue still distinguishes full from empty.
`TLockFreeChannel<T>` uses the same empty/full sequence encoding, so capacity=1 also distinguishes full (`TrySend`/`TrySendEx` → `lfteFull`) from empty (`TryReceive`/`TryReceiveEx` → `lfteEmpty`).

`TMpscQueue<T>` is a multi-producer, single-consumer queue. After `Close`, `TryEnqueue` returns False and plain
`Enqueue` raises `EInvalidOperationError` (aligned with `TLockFreeChannel.Send`). `Close` also wakes blocked
consumers. Lifecycle: Close → join producers/waiters → Free. `Destroy` performs Close+drain but does not replace
joining live producers. `ApproxCount` is an atomic counter snapshot.

`TSegQueue<T>` is an unbounded MPMC queue based on segmented linked ring. `Enqueue` extends storage at segment granularity when the current tail segment has no successor; `TryEnqueue` returns False after `Close`; `TryDequeue` only returns success when the corresponding slot's sequence has been published. `ApproxCount` / `IsEmpty` are snapshot helpers over current enqueue/dequeue positions, not promising a shared linearization view under contention. `Close` does not affect reading of already-enqueued data.

`TLockFreeStack<T>` is a fixed-capacity stack. push/pop first acquire or return slots from an internal free-list, so it is not an unbounded stack and does not dynamically allocate nodes.
`TLockFreeStack<T>` capacity is limited to `High(Int32)` because tagged heads pack a 32-bit slot index
with a 32-bit tag; larger capacities are rejected with `EArgumentError`.
`TLockFreeStack<T>` is a fixed-capacity stack: `TryPush` returns `False` when no free slot remains, and `IsEmpty` / `ApproxCount` are snapshot helpers over the current top-linked list rather than linearization guarantees under contention.

`TWorkStealingDeque<T>` is a work-stealing deque: owner thread executes `TryPush` / `TryPop`, thief
threads only execute `TrySteal`. Supports `Close` / `IsClosed`: after Close, `TryPush` returns False; already-queued items remain drainable via `TryPop` / `TrySteal` (no wait/timeout surface).
`TWorkStealingDeque<T>` rounds requested capacity up to power-of-two storage; `Capacity` returns that live ring bound, `TryPush` returns `False` when the deque is full or closed, and `ApproxCount` / `IsEmpty` are snapshot helpers over current top/bottom counters rather than multi-thread linearization guarantees.

`TSpmcQueue<T>` is a single-producer, multi-consumer bounded queue. `TryEnqueue` is a non-blocking operation; `TryDequeue` has multiple consumers competing via CAS;
`EnqueueWait` / `DequeueWait` block via wait-address seam; timeout versions use nanosecond timeouts.
`Close` sets the closed flag and wakes all waiters; drain-on-close semantics after close allow reading already-enqueued data.
`TSpmcQueue<T>` rounds requested capacity up to power-of-two storage; `Capacity` returns that live ring bound.

Fixed-capacity structures reject 0 capacity. `TSpscQueue<T>`, `TMpmcQueue<T>`, `TSpmcQueue<T>` and
`TWorkStealingDeque<T>` round capacity up to power-of-two; capacities exceeding the maximum representable power-of-two are rejected
rather than overflowing and continuing construction.

## Thread Safety Contract

`TSpscQueue<T>` permits exactly one producer-side caller and exactly one consumer-side caller; multiple producers or multiple consumers on the same queue are outside the contract.
`TMpmcQueue<T>` permits multiple concurrent producers and consumers; `Close` may race with producers. Enqueue calls admitted before observing the closed flag may still publish at their normal per-item linearization point; calls that observe `Close` fail, and consumers only treat closed-empty as terminal after no admitted producer can still publish.
`TMpscQueue<T>` permits multiple producers and exactly one consumer; `TryEnqueue` observes `Close` and returns False; plain `Enqueue` raises `EInvalidOperationError` after `Close`; callers must Close → join producers/waiters → Free.
`TSegQueue<T>` permits multiple concurrent producers and consumers; segment retirement is internal and readers observe only FIFO dequeue success/failure.
`TLockFreeStack<T>` permits multiple concurrent `TryPush` / `TryPop` callers over its fixed slot pool; capacity bounds and unmanaged element restrictions still apply.
`TWorkStealingDeque<T>` permits exactly one owner thread for `TryPush` / `TryPop` and multiple thief threads for `TrySteal`; owner methods are not multi-owner safe.
`TSpmcQueue<T>` permits exactly one producer and multiple concurrent consumers; CAS-protected dequeue positions ensure exactly-once delivery under contention.

## Linearization Points

- `TSpscQueue<T>.TryEnqueue`: After writing to slot, release store to `FTailPublished` publishes the element.
- `TSpscQueue<T>.TryDequeue`: After reading slot, release store to `FHeadPublished` publishes the space.
- `TMpmcQueue<T>.TryEnqueue`: After successful CAS on `FEnqueuePos` to acquire slot, release store to slot `Sequence` publishes the element.
- `TMpmcQueue<T>.TryDequeue`: After successful CAS on `FDequeuePos` to acquire slot, release store to slot `Sequence` reclaims the space.
- `TMpscQueue<T>.Enqueue`: Exchange on `FHead` acquires predecessor node, then release store to predecessor's `Next` publishes the node.
- `TMpscQueue<T>.TryDequeue`: Single consumer advances `FTail` and acquires node value; when the queue is in stub repair path, the current implementation relies on producers having published the node via `Next`.
- `TSegQueue<T>.Enqueue`: After incrementing `FEnqueuePos` to acquire logical position, write to slot and release store to slot `Sequence` publishes the element.
- `TSegQueue<T>.TryDequeue`: After successfully advancing `FDequeuePos`, acquire current slot value; after head segment advances, old segment is reclaimed via EBR retire.
- `TLockFreeStack<T>.TryPush`: Free-list CAS acquires slot, top CAS publishes the slot.
- `TLockFreeStack<T>.TryPop`: Top CAS acquires slot, after reading and clearing value, free-list CAS returns the slot.
- `TWorkStealingDeque<T>.TryPush`: Owner writes to buffer, then release store to `FBottom` publishes the element.
- `TWorkStealingDeque<T>.TryPop`: Owner decrements `FBottom`; last element requires top CAS arbitration with thief.
- `TWorkStealingDeque<T>.TrySteal`: Successful CAS on `FTop` acquires the element.
- `TSpmcQueue<T>.TryEnqueue`: After successful CAS on `FEnqueuePos` to acquire slot, release store to slot `Sequence` publishes the element.
- `TSpmcQueue<T>.TryDequeue`: After successful CAS on `FDequeuePos` to acquire slot, release store to slot `Sequence` reclaims the space.

`TWorkStealingDeque<T>` last-item owner/thief arbitration uses `seq_cst` ordering on `FTop` / `FBottom` loads, bottom store, and top CAS so the single remaining item is won exactly once.

These points are source-contract and current implementation notes, not cross-platform runtime proofs.

## ABA

`TLockFreeStack<T>` packs 32-bit index and 32-bit tag into 64-bit head. Both `FTop` and `FFreeHead`
use tagged index, reducing ABA risk from rapid pop/push reuse of fixed slots.

`TMpmcQueue<T>` uses per-slot sequence token to distinguish ring slot lifetimes; the token simultaneously encodes position
and empty/full state, serving as the ring queue's publish/reclaim token.

`TWorkStealingDeque<T>` uses monotonic `FTop` / `FBottom` counter and last-element CAS arbitration. Currently no
hazard pointer or epoch reclamation, because deque storage is a fixed array.

## Memory Reclamation

`TSpscQueue<T>`, `TMpmcQueue<T>`, `TSpmcQueue<T>`, `TLockFreeStack<T>` and
`TWorkStealingDeque<T>` all use fixed arrays or fixed slots. They do not dynamically allocate nodes on the hot path and require `T`
to be an unmanaged type.

`TMpscQueue<T>` uses `New` / `Dispose` to manage linked list nodes. This structure has only one consumer, so the consumer can
release the old tail node after successful dequeue. The module currently has no hazard pointer, epoch reclamation or reference
count reclamation; safety boundaries rely on the single-consumer contract and producers having stopped before destruction.

`TSegQueue<T>` uses EBR to protect the segment linked list. After the head segment advances, the old segment is reclaimed via `TEbrDomain.Retire`
delayed reclamation, so callers should only access nodes through the public queue surface and must not cache internal segment pointers.

### EBR Collect Safety Constraints

`TEbrDomain.Collect` checks `FActiveCount == 0` before reclamation, but there is a time window between this check and actual reclamation:
another thread may `Enter` (incrementing FActiveCount) and `Retire` new nodes during this window.

The current design is safe under these conditions:

1. **Unlinked from public root set before retire**: After the retired segment is removed from the `FHead` linked list, new entrants can only traverse from the current `FHead` and cannot acquire the unlinked old segment.
2. **Guard established before retire**: `TSegQueue<T>.TryDequeue` first `Enter` (acquires guard), then operates on segments, ensuring retired nodes are not reclaimed during the guard's lifetime.
3. **Callers must not cache internal pointers**: Only access data through queue public API, not holding segment pointers across operations.

**Extension Warning**: If EBR is promoted to structures where "retired nodes remain reachable to future entrants", full epoch advancement or retry checks in `Collect` must be implemented. The current conservative design (single zero-check + no epoch advancement) only applies to scenarios where "nodes are unlinked from root set before retire".

## ShardedHashMap

`TShardedHashMap<TKey, TValue>` is a sharded-lock concurrent HashMap. Design goal is optimal performance under high-frequency low-contention scenarios.

**Design Features**:
- 16 shards, each using `AtomicExchange32` spin lock
- Open addressing + linear probing, load factor 3/4
- Automatic expansion (2x)
- Only supports unmanaged types

**API Overview**:

| Method | Complexity | Concurrent Safe | Description |
|--------|-----------|-----------------|-------------|
| Insert | O(1) amortized | ✅ | Insert or overwrite |
| Find | O(1) amortized | ✅ | Find and return value |
| Remove | O(1) amortized | ✅ | Delete key (mark esDeleted) |
| Remove (out) | O(1) amortized | ✅ | Delete key and return old value |
| TryInsert | O(1) amortized | ✅ | CAS semantics: insert only if not exists |
| Replace | O(1) amortized | ✅ | Atomic replace and return old value |
| Contains | O(1) amortized | ✅ | Check if key exists |
| Count | O(shards) | ✅ | Lock-across-shards accumulation (snapshot) |
| ForEach | O(n) | ✅ | Per-shard traversal, callback while holding lock |
| ForEachCtx | O(n) | ✅ | Per-shard traversal with context pointer |
| GetOrInsert | O(1) amortized | ✅ | Atomic get or insert, single lock acquisition |
| GetOrInsertFn | O(1) amortized | ✅ | Lazy compute: callback only when key doesn't exist |
| GetOrUpdate | O(1) amortized | ✅ | Atomic get-or-create-then-update |
| Clear | O(n) | ✅ | Per-shard clear |
| Reserve | O(shards) | ✅ | Pre-allocate capacity to avoid runtime resize |

**Performance Characteristics** (vs TConcurrentHashMap):

| Scenario | TShardedHashMap | TConcurrentHashMap |
|----------|-----------------|-------------------|
| Lock mechanism | AtomicExchange ~1ns | RWLock ~10-50ns |
| Memory management | No reference counting | Has reference counting |
| Use case | High-frequency, low-contention, unmanaged | General purpose, supports managed |

**Use Cases**:
- High-frequency read/write, low-contention caching
- Statistics counters (GetOrUpdate)
- Lazy initialization (GetOrInsertFn)

## Channel

`TLockFreeChannel<T>` is a bounded lock-free Channel, sequence-number driven MPMC channel.

**Design Features**:
- Capacity automatically rounded up to power-of-two (bitwise optimization); **capacity=1 is valid** with distinguishable full/empty
- Per-slot sequence uses the same empty/full token encoding as `TMpmcQueue`
- Blocking/non-blocking/timeout send and receive modes
- Already-enqueued data still readable after Close
- Send to closed channel throws exception, TrySend returns False (Go-aligned)
- Dynamic capacity adjustment via `TryResize(ANewCapacity)`

**API Overview**:

| Method | Description |
|--------|-------------|
| Send | Blocking send (throws EInvalidOperationError when closed) |
| TrySend | Non-blocking send (returns False when full/closed) |
| SendTimeout | Send with timeout |
| Receive | Blocking receive (returns False when closed+empty) |
| TryReceive | Non-blocking receive |
| ReceiveTimeout | Receive with timeout |
| Close | Close channel, wake all waiters |
| TryResize | Dynamically adjust capacity (spin-flag mechanism) |

## Selector

`TLockFreeSelector<T>` is a multi-channel multiplexer (Go `select` style; Q3-a pins).

**Design Features**:
- All cases must use the same type T
- **`TrySelect` ≡ Go `select { default: }`** (`Completed=False` means default)
- Multi-ready: earliest **Add** index wins (not Go random)
- Wait: short spin + wait-address via `lockfree.wait` (not pure busy-poll)
- Blocking / timeout / non-blocking modes
- AddSend stores a value copy; send only on successful Select/TrySelect

**Usage Example**:
```pascal
var LSel: specialize TLockFreeSelector<Integer>;
    LCh1, LCh2: specialize TLockFreeChannel<Integer>;
    LResult: TSelectResult;
    LVal: Integer;
begin
  LSel := specialize TLockFreeSelector<Integer>.Create;
  try
    LSel.AddRecv(LCh1, LVal);   // case v := <-LCh1
    LSel.AddSend(LCh2, 42);     // case LCh2 <- 42
    LResult := LSel.Select;
    if LResult.Completed then
      case LResult.Index of
        0: WriteLn('Received ', LVal);
        1: WriteLn('Sent');
      end;
  finally
    LSel.Free;
  end;
end;
```

## Hazard Pointer

`THazardDomain` is a Hazard Pointer memory reclamation domain based on Michael & Scott algorithm. Complementary to EBR, suitable for scenarios requiring precise protection of specific pointers.

**Design Features**:
- Per-thread independent hazard pointers, contention-free
- Deferred reclamation: retired nodes processed in batch during Collect
- Safety constraint: Retire does not traverse thread list (avoiding concurrent modification)

**API Overview**:

| Method | Description |
|--------|-------------|
| Acquire | RAII guard: register thread + set HP index |
| Protect | Protect pointer (via Guard or direct call) |
| Clear | Clear protection |
| Release | RAII release: clear protection + unregister thread |
| Retire | Add pointer to retired list |
| Collect | Reclaim unprotected retired nodes |

**Reclamation Flow**:
1. `Protect`: Set thread's hazard pointer (moRelease)
2. `Clear`: Clear thread's hazard pointer (moRelease)
3. `Retire`: Add pointer to retired list (CAS moRelease)
4. `Collect`: Check all threads' hazard pointers, reclaim unprotected nodes

**Safety Constraints**:
- `Collect` must be called before `UnregisterThread` (traverses thread list)
- `Retire` does not call `Collect` (avoiding concurrent list modification)
- Retired node's reclamation callback must be idempotent (may be called multiple times)

**Comparison with EBR**:

| Feature | EBR | Hazard Pointer |
|---------|-----|----------------|
| Protection granularity | Entire critical section | Specific pointers |
| Memory overhead | Low (3 epochs per thread) | Medium (N hazard pointers per thread) |
| Reclamation latency | Low (epoch advancement reclaims) | High (requires explicit Collect) |
| Use case | Read-heavy, short critical sections | Need precise protection of specific pointers |

## Close/Destroy Discipline

`TSpscQueue<T>` and `TMpmcQueue<T>`'s `Close` sets the closed flag and wakes data/space waiters. After close,
producer-side waiting operations should return failure, consumer-side can continue draining published elements.
`Close` is not a lifetime barrier: callers must keep the queue object alive until all producer and consumer calls have returned, then join/quiesce those threads before `Free`.
`TSpscQueue<T>.Close` wakes already-blocked `EnqueueWait` / `DequeueWait` calls so a closed queue stops waiting even without a timeout.
`TSpscQueue<T>.Close` wakes already-blocked `EnqueueTimeout` / `DequeueTimeout` calls so a closed queue stops waiting promptly instead of sleeping until the full timeout.
`TMpmcQueue<T>.Close` wakes already-blocked `EnqueueWait` / `DequeueWait` calls so blocked producers and consumers stop waiting even without a timeout.
`TMpmcQueue<T>.Close` wakes already-blocked `EnqueueTimeout` / `DequeueTimeout` calls so blocked producers and consumers stop waiting promptly instead of sleeping until the full timeout.

After `TMpscQueue<T>.Close`: `TryEnqueue` returns False, plain `Enqueue` raises `EInvalidOperationError`,
and `DequeueWait` / `DequeueTimeout` return failure when currently empty. `Close` wakes blocked consumers.
Before destruction, these must be satisfied:
`TMpscQueue<T>.Close` wakes already-blocked `DequeueWait` consumers so a closed-empty queue stops waiting even without a timeout.
`TMpscQueue<T>.Close` wakes already-blocked `DequeueTimeout` consumers so a closed-empty queue stops waiting promptly.

1. `Close` has been called.
2. Producers have stopped and joined (`Close` is not a join barrier).
3. Consumer has drained the queue (or rely on Destroy Close+drain).

`TMpscQueue.Destroy` calls `Close` then drains remaining nodes; callers must still join producers/waiters before `Free`.

## Atomic Dependency

The lockfree module depends on these contracts from `nextpas.core.atomic`:

- `AtomicLoad32/64`, `AtomicStore32/64`, `AtomicCompareExchange64` and `AtomicExchange64`'s
  acquire/release/acq_rel/seq_cst semantics.
- Pointer-sized `atomic_load` / `atomic_store` / `atomic_exchange` for `TMpscQueue<T>` node links;
  node pointers must not be widened through legacy `AtomicLoad64` / `AtomicStore64` / `AtomicExchange64` casts.
- `CpuPause` as spin hint.
- `atomic_wait` / `atomic_notify_*` backed by `platform_wait_address32`,
  `platform_wake_address_one` and `platform_wake_address_all` seam.
- EBR guard/retire path used by `TSegQueue<T>` for segment lifetime and deferred reclamation.

`nextpas.core.lockfree.wait` only waits on 32-bit epoch addresses. Do not extend 64-bit or pointer
wait at the lockfree layer; if extension is needed, first design atomic/platform wait-address contract, then add consumer gate.
Wait helpers receive the caller-observed epoch and only block while the epoch is unchanged. This closes the
notify-between-retry-and-wait window: if a producer or consumer advances the epoch before the platform wait,
the helper returns instead of sleeping on the new epoch.

## Verification

**One-shot T1 gate (R6)**: atomic + lockfree main suite + stress; log defaults to `core/build/verify-lockfree/verify-t1.log`:

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
```

Normal lockfree slice at minimum runs:

```bash
make hygiene
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-forced-compile
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-debug
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
git diff --check
git status --short --branch
```

`test_lockfree` covers API behavior, close/timeout, managed type guard and source-contract coverage.
`test-forced-compile` is a public facade-only host compile gate, not a runtime or stress proof.
`test_lockfree` also covers local Linux x86_64 timeout runtime checks for
SPSC producer-published data (`DequeueTimeout`), SPSC consumer-released space (`EnqueueTimeout`),
MPMC producer-published data (`DequeueTimeout`), MPMC consumer-released space (`EnqueueTimeout`),
and MPSC producer-published data (`DequeueTimeout`).
`test-debug` uses `-dDEBUG` compiled focused gate to execute `TMpscQueue<T>.Destroy`'s
close-before-destroy assert, preventing test code from bypassing MPSC producer-stop / drain discipline.
`test_lockfree_stress` covers multi-thread stress scenarios on local Linux x86_64. Without target machine runtime gate, only
source-contract or local Linux x86_64 runtime evidence can be claimed, not claiming other platforms have been verified on real machines.
These stress outputs are focused evidence, not production soak, fairness or cross-platform runtime proof.

## Benchmark

Current benchmark entry:

```bash
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
```

Pascal benchmark source is located at
`core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr`. It covers:

- `TSpscQueue<T>`'s 1 producer + 1 consumer blocking wait path.
- `TMpmcQueue<T>`'s 2 producer + 2 consumer blocking wait path.
- `nextpas.core.thread.channel` mutex channel's 1 producer + 1 consumer comparison baseline.
- `TSpscQueue<T>` and `TMpscQueue<T>`'s single-thread `Try*` hot path.

Benchmark uses `OPS=1000000`, capacity `1024`, Makefile default compile flags are `-MObjFPC -Sh -O2`.
Run output first prints `platform/compiler flags/input size/baseline` envelope, then prints each scenario's
ms, M ops/sec and ns/op.
Pascal benchmark keeps consumed values in a printed sink to reduce optimizer-elision risk.
Pascal benchmark hot paths should not add extra per-item progress atomics that Rust/Go/C++ comparison sources do not pay; keep only scenario-result sink accumulation and synchronization required by the queue contract itself.
