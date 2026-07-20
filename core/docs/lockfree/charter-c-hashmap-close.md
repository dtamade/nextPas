# Charter C — T1 HashMap Close lifecycle

> **Status**: accepted (A→E line, user ordered execution)  
> **Date**: 2026-07-21  
> **Scope**: `nextpas.core.lockfree.hashmap` (`TShardedHashMap` / `TConcurrentHashMap` alias)  
> **Not**: H3-2 expansion (bag/multimap table unchanged)

## Decision

| Item | Decision |
|------|----------|
| Add `Close` / `IsClosed` | **Yes** |
| Progress | Unchanged: sharded spin locks (not lock-free) |
| H3-2 production subset | **No** — HashMap remains T1 facade |
| Skiplist Close | **Deferred** |
| Second Guarded T2 batch | **No this wave** |

## Semantics

| API | After Close |
|-----|-------------|
| `Insert` / `Reserve` / `GetOrUpdate` | **Raise** `EInvalidOperationError` |
| `TryInsert` / `Replace` (miss) | **False** (no insert/update) |
| `GetOrInsert` / `GetOrInsertFn` | Existing key: **read OK**; missing key: **raise** |
| `Find` / `Contains` / `Remove` / `ForEach*` / `Count` / `Clear` | **Allowed** (cleanup / drain reads) |
| `Destroy` | **Close first**, then free shards |
| Lifecycle | stop writers → `Close` → join → `Free` (Destroy Close does not replace join) |

## Tests

- Unit: Close idempotent; Insert raises; Find works; GetOrInsert existing vs missing  
- Stress: concurrent Insert + Close (no hang, no residual preferred regression)

## Non-goals

- Rename to remove “lockfree” from map  
- API for H3-2 bag-style result enums on every method  
- collections.concurrent.hashmap (separate type)
