# HTTP × Atomic/Lockfree — Integration Notes

> **Date**: 2026-07-26
> **Owner (lockfree side)**: atomic-lockfree lane
> **HTTP owner**: separate `codex/http` (or equivalent) lane — **they implement wiring**
> **This document does NOT authorize edits to `nextpas.core.http*`**

## 0. Collaboration protocol

| Role | Does | Does not |
|------|------|----------|
| **atomic-lockfree** | Keep T1/atomic contracts green; answer API/lifecycle questions; optional T1 API gap fixes under charter | Default-change HTTP production code; force-replace DIY rings |
| **http lane** | Decide whether/where to adopt T1 containers; implement wiring + HTTP tests | Depend on lockfree → http (forbidden direction) |
| **Joint H6** | Only after both agree on a one-page charter | Silent cross-module land without charter |

**Dependency direction if wired**: `http` → `lockfree` / `atomic` (downward). Never the reverse.

## 1. Lifecycle template (mandatory if using T1)

```
Close container  →  join producers / waiters / workers  →  Free
```

- `Destroy` may Close+drain for safety; **it does not replace join**.
- Managed types (`string`, interface, dynarray) **cannot** enter T1 element-generic containers.
- Pattern from production (H4-1 / H5-1): heap node + `Pointer` payload:

| Production example | Queue | Element |
|--------------------|-------|---------|
| H3-1 `async.loop` | `TMpscQueueImpl<TAsyncPendingItem>` | unmanaged record (or redesign) |
| H4-1 `thread.pool` | `TSegQueueImpl<Pointer>` | `PTaskNode` holds managed task |
| H5-1 `net.server` poll completion | `TMpscQueueImpl<Pointer>` | `PCompletionNode` holds interfaces |
| H3-5 worksteal | `TWorkStealingDequeImpl<TDequeSlot>` | slot.Node → heap task |

Charters: [`charter-h4-thread-pool-mpsc.md`](charter-h4-thread-pool-mpsc.md), [`charter-h5-net-completion-mpsc.md`](charter-h5-net-completion-mpsc.md), [`roadmap-h3.md`](roadmap-h3.md).

## 2. Selection cheatsheet (HTTP-shaped problems)

| Need | Prefer | Avoid / notes |
|------|--------|----------------|
| N workers complete work; **one** reactor drains | **`TMpscQueue`** (H5-1) | Multi-consumer on same MPSC |
| N workers share **unbounded** task pool | **`TSegQueue`** (H4-1) | MPSC if multi-consumer |
| Owner push/pop + steal | **`TWorkStealingDeque`** | `deque_lf` / `TLockFreeDeque` is **spin-lock** |
| Bounded back-pressure channel | **`TLockFreeChannel`** / SPSC variant | Unbounded growth under overload |
| Byte stream SPSC (TLS-style) | Keep **DIY byte ring** or dedicated byte API | Do **not** stuff bytes into `TSpscQueue<T>` element queue without design |
| Concurrent map | `TShardedHashMap` (**shard spin locks**, not LF) | Assuming lock-free progress from the name |

Full tree: [`selection-guide.md`](selection-guide.md). Contract: [`CONTRACT.md`](CONTRACT.md).

## 3. Read-only audit (this worktree, 2026-07-26)

**Method**: `rg` on `core/src/nextpas.core.http*.pas` for `uses nextpas.core.lockfree*`, queues, handoff, completion.
**Caveat**: HTTP lane may have moved ahead on its own worktree; **re-audit on http HEAD before H6**.

| Finding | Detail | Recommendation |
|---------|--------|----------------|
| **No direct lockfree uses** | No `uses nextpas.core.lockfree*` in http units | Expected; keep until charter |
| **No direct atomic uses** in scanned http units | Concurrency via net/server handoff / sync elsewhere | Prefer `atomic_*` if HTTP adds atomics later |
| **H1 poll worker handoff** | `TH1ServerConnectionState`: `FWorkerHandoff: ITcpServerWorkerHandoff`, `EnqueuePollResponse`, `FPollCompletionReady`, spare outbound buffers | Completion path already sits on **net** poll completion (**H5-1 MPSC**). Prefer improve handoff **through net**, not a second HTTP-local queue |
| **HPACK “ring”** | `http.impl.h2.hpack` dynamic table ring | **Protocol state**, not thread queue — do not replace with lockfree queue |
| **Middleware spinlock** | `http.middleware` uses `nextpas.core.sync.spinlock` | Fine; not a T1 queue candidate |
| **TLS DIY SPSC** | `nextpas.core.tls.ringbuffer.lockfree` byte SPSC | **Bypass — do not replace this wave** (consumer-audit) |

### Candidate map (for http lane discussion only)

| ID | Hotspot | Current | If ever adopt T1 | Priority |
|----|---------|---------|------------------|----------|
| H-A | Poll completion (server) | **Already H5-1** on net `TTcpServerPollCompletionQueue` | Done at net layer | — |
| H-B | Worker handoff / request offload | `ITcpServerWorkerHandoff` + H1 flags | Only if handoff grows a DIY multi-producer queue; then MPSC or SegQueue per consumer shape | Low until measured |
| H-C | Per-connection outbound queue | `EnqueuePollResponse` / spare outbound | Usually **single-owner connection state** — not MPMC T1 | Avoid |
| H-D | TLS byte rings | DIY SPSC | Keep DIY or dedicated byte ring; not `TSpscQueue<Byte>` without design | Do not this wave |
| H-E | Shared HTTP metrics/maps | middleware / metrics | Optional `TShardedHashMap` or atomic counters | Opt-in |

**This wave recommendation**: **no HTTP code change**. Consume H5-1 benefits via net; document only.

## 4. Anti-patterns

1. Putting `IHttp*` / `string` directly into T1 generics → use Pointer nodes.
2. Freeing a T1 queue while workers still Enqueue.
3. Treating `TShardedHashMap` / `TLockFreeDeque` as lock-free progress.
4. lockfree unit `uses` http (layer violation).
5. Absolute Mops claims without [`bench-envelope.md`](bench-envelope.md).

## 5. When to open H6 charter

Open a one-page charter **only if all** hold:

1. HTTP lane requests a concrete wiring site (file + type).
2. Progress model + Close lifecycle agreed.
3. Test ownership clear (http focused gate + optional verify-h3 widen).
4. No silent Closed-policy change on T1.
5. Controllers aware of cross-module land.

Until then: Maintenance on atomic/lockfree; HTTP develops independently.

## 6. Verify (lockfree side; no http edit)

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make -C core/tests/nextpas.core.lockfree verify-h3-consumers   # includes test_net_server (H5)
make hygiene
```

## 7. Pointers

- Consumer audit: [`consumer-audit.md`](consumer-audit.md)
- READY: [`READY.md`](READY.md)
- Atomic preferred: [`../atomic/preferred-path.md`](../atomic/preferred-path.md)
