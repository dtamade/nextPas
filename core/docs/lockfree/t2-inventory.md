# T2 Inventory — nextpas.core.lockfree

> **Status**: Q4 audit (2026-07-20) · **I1 honesty pass** (2026-07-20 night)
> **Authority**: tiers abstract CONTRACT §0.2; H3-2 production subset remains §0.3 only
> **Rule**: T2 never enters default `uses nextpas.core.lockfree` facade

## How to use

1. Need production-contract Close/managed/progress? → **only** H3-2: `bag`, `multimap`.
2. Otherwise pick tier from table; open unit header for progress truth.
3. Name contains LockFree/Concurrent ≠ lock-free progress (see `deque_lf`).
4. Unlisted future units: default **Available** until audited; Experimental if RTM/NUMA/formal-only.

## I1 honesty pass (2026-07-20)

Spot-check of inventory **Progress** vs unit headers / lock signals:

| Finding | Action |
|---------|--------|
| `elimination_stack` was labeled lock-based | **Fixed** → Treiber + elimination (LF) |
| `hashtable` header: LF reads + writer lock | **Fixed** → more precise progress |
| `cowarray` / `rcu` / `bitset` / `actor` / `forkjoin` | **Fixed** → mechanism-level one-liners |
| `skiplist` / `dag` / `lfu` | Inventory already honest (locks); OK |
| Remaining placeholders | **cleared** in I1-b (mechanism one-liners for ~43 units) |

Also **C1** (same day): `rg` for production `Atomic*(` outside `nextpas.core.atomic*` → **0** calls; lockfree preferred nail green.
**I1-b** (same night): replaced remaining `read unit header` progress cells with mechanism-level honesty strings (trees/sketches/locks/etc.).

## Q4 decision — do NOT expand H3-2

| Item | Decision |
|------|----------|
| Expand H3-2 subset this wave | **No** |
| Current production subset | `bag` + `multimap` only |
| Deferred candidates | bloom, lru*, ringbuffer, timeoutqueue, … |
| Future expand requires | one-page charter + Close/managed/progress + focused tests + facade isolation + owner approve |

Rationale: Q-line optimizes navigability and honesty, not production-surface growth.

## Summary counts

| Tier | Count |
|------|------:|
| Guarded | 27 |
| Available | 55 |
| Experimental | 3 |
| **Total T2/T3-ish units** | **85** |

T1 units (not listed): queues, stack, deque, ebr/hazard, channel(+spsc), selector, sharded hashmap, wait, base.

## H3-2 production subset (only)

| Unit | Progress | Managed | Close | Tests |
|------|----------|---------|-------|-------|
| `bag` | LF MPMC seq ring + wait | unmanaged reject | yes (`arClosed`) | `test_lockfree_bag` |
| `multimap` | single map spinlock | unmanaged reject | yes (`mmClosed`) | `test_lockfree_multimap` |

## Full inventory

| Unit | Tier | Progress (honest) | Tests | Notes |
|------|------|-------------------|-------|-------|
| `actor` | Available | MPSC mailbox + actor-system locks | yes | sequential handler |
| `adjmap` | Available | graph + vertex/global locks | yes |  |
| `arccache` | Guarded | lock concurrent | yes |  |
| `bag` | Guarded | LF ring (MPMC seq) + wait | yes | H3-2 production |
| `barrier` | Guarded | sync barrier | yes |  |
| `bitset` | Available | atomic bit CAS (+ grow lock) | yes |  |
| `bloom` | Guarded | atomic bit array (approx) | yes |  |
| `bplus` | Available | lock concurrent tree | yes |  |
| `btree` | Available | lock concurrent tree | yes |  |
| `condvar` | Guarded | lock+wait | yes |  |
| `consistent_hashring` | Available | consistent hash ring + locks | yes |  |
| `countdown` | Guarded | atomic latch | yes |  |
| `counter` | Guarded | atomic counter | yes |  |
| `counting_bloom` | Guarded | atomic counters | yes |  |
| `countminsketch` | Available | count-min sketch (atomic counters) | yes |  |
| `cowarray` | Available | COW CAS publish (read path uncontended) | yes | retired free-list spin |
| `crdt` | Available | CRDT merge + per-type locks | yes |  |
| `cuckooset` | Available | cuckoo table + locks | yes |  |
| `dag` | Available | per-node locks (NOT LF) | yes | header honest |
| `deque_spin` (+ `deque_lf` alias) | Available | spin-lock (NOT LF) | yes | honest type `TConcurrentSpinDeque`; `TLockFreeDeque` alias |
| `disjointset` | Available | union-find + locks | yes |  |
| `elimination_stack` | Available | LF Treiber + elimination array | yes | Hendler et al. |
| `exchanger` | Guarded | atomic state machine (slot CAS) | yes |  |
| `fenwick` | Available | fenwick tree + locks | yes |  |
| `fibheap` | Available | fib heap + lock | yes |  |
| `flatcombining` | Available | combiner lock + publication array | yes |  |
| `forkjoin` | Available | work-stealing task pool | yes |  |
| `graph` | Available | graph + vertex/global locks | yes |  |
| `hashmap.numa` | Experimental | NUMA research | no | T3/R8 research path; no dedicated focused dir |
| `hashmap.rtm` | Experimental | RTM research | no | T3/R8 research path; no dedicated focused dir |
| `hashset` | Available | hash set + locks (see unit) | yes |  |
| `hashtable` | Available | LF readers + writer spinlock / grow | yes |  |
| `hyperloglog` | Available | HyperLogLog atomics | yes |  |
| `intervaltree` | Available | interval tree + locks | yes |  |
| `leakybucket` | Guarded | leaky bucket + lock | yes |  |
| `leftright` | Available | left-right dual publish | yes |  |
| `lfu` | Guarded | sharded/lock concurrent | yes |  |
| `linkedlist` | Available | linked list + locks | yes |  |
| `lru` | Guarded | sharded spinlock | yes |  |
| `lru_cache` | Guarded | sharded spinlock | yes |  |
| `matrix` | Available | matrix + locks | yes |  |
| `merkle_tree` | Available | merkle tree + locks | yes |  |
| `misragries` | Available | Misra-Gries sketch + locks | yes |  |
| `multimap` | Guarded | single map spinlock | yes | H3-2 production |
| `mutex` | Guarded | CAS spin mutex | yes |  |
| `persistent_vector` | Available | persistent/COW vector chunks | yes |  |
| `phaser` | Guarded | phase barrier (state lock) | yes |  |
| `priority_queue` | Guarded | lock concurrent heap | yes |  |
| `radix` | Available | radix tree + locks | yes |  |
| `ratelimit` | Guarded | token bucket + lock | yes |  |
| `rbtree` | Available | lock concurrent tree | yes |  |
| `rcu` | Available | RCU read uncontended + publish/grace | yes |  |
| `reservoirsampling` | Available | reservoir sampling + locks | yes |  |
| `ringbuffer` | Guarded | concurrent ring (see unit) | yes |  |
| `roaring_bitmap` | Available | roaring bitmap concurrent | yes |  |
| `robinhood` | Available | robin-hood hash + locks | yes |  |
| `rope` | Available | rope + locks | yes |  |
| `rtm` | Experimental | RTM research | yes | T3/R8 research path |
| `rwlock` | Guarded | atomic state rwlock | yes |  |
| `scalable_bloom` | Guarded | lock-based concurrent | yes |  |
| `scapegoat` | Available | scapegoat tree + locks | yes |  |
| `semaphore` | Guarded | CAS spin/wait | yes |  |
| `skiplist` | Available | per-level rwlock (NOT LF) | yes | header honest |
| `skiplist_map` | Available | per-level rwlock (NOT LF) | yes |  |
| `slidingwindow` | Available | sliding window counters | yes |  |
| `snapshot` | Available | snapshot publish | yes |  |
| `sortedset` | Available | sorted set + locks | yes |  |
| `spacesaving` | Available | Space-Saving sketch + locks | yes |  |
| `stampedlock` | Guarded | optimistic stamp + exclusive write | yes |  |
| `statscounter` | Guarded | atomic/stats | yes |  |
| `suffixarray` | Available | suffix array + locks | yes |  |
| `tdigest` | Available | t-digest + locks | yes |  |
| `timeoutqueue` | Guarded | concurrent + timer | yes |  |
| `timerwheel` | Available | timer wheel + locks | yes |  |
| `timeseries_ringbuffer` | Available | timeseries ring | yes |  |
| `treap` | Available | lock concurrent tree | yes |  |
| `trie` | Available | trie + locks | yes |  |
| `trie_hmt` | Available | hash-mapped trie + locks | yes |  |
| `trie_map` | Available | trie map + locks | yes |  |
| `ttl_cache` | Guarded | lock concurrent | yes |  |
| `unrolled_list` | Available | unrolled list + locks | yes |  |
| `versionvector` | Available | version vector atomics | yes |  |
| `workstealing` | Guarded | pool (see unit; T1 deque is separate) | yes |  |
| `wrr` | Available | weighted round-robin | yes |  |
| `xorfilter` | Available | xor filter (probabilistic) | yes |  |

## Downgrade / honesty notes (docs only this wave)

| Unit | Action |
|------|--------|
| `deque_lf` | Keep Available; **never** claim LF; selection-guide already warns |
| `hashmap.rtm` / `hashmap.numa` / `rtm` | Experimental; no production subset |
| Units with `tests=no` | Prefer Experimental for new consumers; do not expand H3-2 onto them |

## Maintenance

- Re-run audit when adding T2 units or changing tiers.
- Algorithm rewrites out of scope for Q4.
- See also: [selection-guide.md](selection-guide.md), [CONTRACT.md](CONTRACT.md) §0.2–§0.3, [quality-parity.md](quality-parity.md).
