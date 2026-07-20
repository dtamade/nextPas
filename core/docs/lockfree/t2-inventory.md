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
| Remaining `lock-based concurrent (read unit header)` | Still valid **placeholder** until per-unit deep pass; prefer opening the unit |

Also **C1** (same day): `rg` for production `Atomic*(` outside `nextpas.core.atomic*` → **0** calls; lockfree preferred nail green.

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
| `adjmap` | Available | lock-based concurrent (read unit header) | yes |  |
| `arccache` | Guarded | lock concurrent | yes |  |
| `bag` | Guarded | LF ring (MPMC seq) + wait | yes | H3-2 production |
| `barrier` | Guarded | sync barrier | yes |  |
| `bitset` | Available | atomic bit CAS (+ grow lock) | yes |  |
| `bloom` | Guarded | atomic bit array (approx) | yes |  |
| `bplus` | Available | lock concurrent tree | yes |  |
| `btree` | Available | lock concurrent tree | yes |  |
| `condvar` | Guarded | lock+wait | yes |  |
| `consistent_hashring` | Available | lock-based concurrent (read unit header) | yes |  |
| `countdown` | Guarded | atomic latch | yes |  |
| `counter` | Guarded | atomic counter | yes |  |
| `counting_bloom` | Guarded | atomic counters | yes |  |
| `countminsketch` | Available | lock-based concurrent (read unit header) | yes |  |
| `cowarray` | Available | COW CAS publish (read path uncontended) | yes | retired free-list spin |
| `crdt` | Available | lock-based concurrent (read unit header) | yes |  |
| `cuckooset` | Available | lock-based concurrent (read unit header) | yes |  |
| `dag` | Available | per-node locks (NOT LF) | yes | header honest |
| `deque_lf` | Available | spin-lock (NOT LF; name misleading) | yes | misleading name: spin-lock |
| `disjointset` | Available | lock-based concurrent (read unit header) | yes |  |
| `elimination_stack` | Available | LF Treiber + elimination array | yes | Hendler et al. |
| `exchanger` | Guarded | atomic state machine (slot CAS) | yes |  |
| `fenwick` | Available | lock-based concurrent (read unit header) | yes |  |
| `fibheap` | Available | lock-based concurrent (read unit header) | yes |  |
| `flatcombining` | Available | combiner lock + publication array | yes |  |
| `forkjoin` | Available | work-stealing task pool | yes |  |
| `graph` | Available | lock-based concurrent (read unit header) | yes |  |
| `hashmap.numa` | Experimental | NUMA research | no | T3/R8 research path; no dedicated focused dir |
| `hashmap.rtm` | Experimental | RTM research | no | T3/R8 research path; no dedicated focused dir |
| `hashset` | Available | lock-based concurrent (read unit header) | yes |  |
| `hashtable` | Available | LF readers + writer spinlock / grow | yes |  |
| `hyperloglog` | Available | lock-based concurrent (read unit header) | yes |  |
| `intervaltree` | Available | lock-based concurrent (read unit header) | yes |  |
| `leakybucket` | Guarded | lock-based concurrent (read unit header) | yes |  |
| `leftright` | Available | lock-based concurrent (read unit header) | yes |  |
| `lfu` | Guarded | sharded/lock concurrent | yes |  |
| `linkedlist` | Available | lock-based concurrent (read unit header) | yes |  |
| `lru` | Guarded | sharded spinlock | yes |  |
| `lru_cache` | Guarded | sharded spinlock | yes |  |
| `matrix` | Available | lock-based concurrent (read unit header) | yes |  |
| `merkle_tree` | Available | lock-based concurrent (read unit header) | yes |  |
| `misragries` | Available | lock-based concurrent (read unit header) | yes |  |
| `multimap` | Guarded | single map spinlock | yes | H3-2 production |
| `mutex` | Guarded | CAS spin mutex | yes |  |
| `persistent_vector` | Available | lock-based concurrent (read unit header) | yes |  |
| `phaser` | Guarded | lock-based concurrent (read unit header) | yes |  |
| `priority_queue` | Guarded | lock concurrent heap | yes |  |
| `radix` | Available | lock-based concurrent (read unit header) | yes |  |
| `ratelimit` | Guarded | lock-based concurrent (read unit header) | yes |  |
| `rbtree` | Available | lock concurrent tree | yes |  |
| `rcu` | Available | RCU read uncontended + publish/grace | yes |  |
| `reservoirsampling` | Available | lock-based concurrent (read unit header) | yes |  |
| `ringbuffer` | Guarded | concurrent ring (see unit) | yes |  |
| `roaring_bitmap` | Available | lock-based concurrent (read unit header) | yes |  |
| `robinhood` | Available | lock-based concurrent (read unit header) | yes |  |
| `rope` | Available | lock-based concurrent (read unit header) | yes |  |
| `rtm` | Experimental | RTM research | yes | T3/R8 research path |
| `rwlock` | Guarded | atomic state rwlock | yes |  |
| `scalable_bloom` | Guarded | lock-based concurrent | yes |  |
| `scapegoat` | Available | lock-based concurrent (read unit header) | yes |  |
| `semaphore` | Guarded | CAS spin/wait | yes |  |
| `skiplist` | Available | per-level rwlock (NOT LF) | yes | header honest |
| `skiplist_map` | Available | per-level rwlock (NOT LF) | yes |  |
| `slidingwindow` | Available | lock-based concurrent (read unit header) | yes |  |
| `snapshot` | Available | lock-based concurrent (read unit header) | yes |  |
| `sortedset` | Available | lock-based concurrent (read unit header) | yes |  |
| `spacesaving` | Available | lock-based concurrent (read unit header) | yes |  |
| `stampedlock` | Guarded | lock-based concurrent (read unit header) | yes |  |
| `statscounter` | Guarded | atomic/stats | yes |  |
| `suffixarray` | Available | lock-based concurrent (read unit header) | yes |  |
| `tdigest` | Available | lock-based concurrent (read unit header) | yes |  |
| `timeoutqueue` | Guarded | concurrent + timer | yes |  |
| `timerwheel` | Available | lock-based concurrent (read unit header) | yes |  |
| `timeseries_ringbuffer` | Available | lock-based concurrent (read unit header) | yes |  |
| `treap` | Available | lock concurrent tree | yes |  |
| `trie` | Available | lock-based concurrent (read unit header) | yes |  |
| `trie_hmt` | Available | lock-based concurrent (read unit header) | yes |  |
| `trie_map` | Available | lock-based concurrent (read unit header) | yes |  |
| `ttl_cache` | Guarded | lock concurrent | yes |  |
| `unrolled_list` | Available | lock-based concurrent (read unit header) | yes |  |
| `versionvector` | Available | lock-based concurrent (read unit header) | yes |  |
| `workstealing` | Guarded | pool (see unit; T1 deque is separate) | yes |  |
| `wrr` | Available | lock-based concurrent (read unit header) | yes |  |
| `xorfilter` | Available | lock-based concurrent (read unit header) | yes |  |

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
