# Lockfree API Reference

> Updated: 2026-07-20 (Maintenance preferred close-out; EN tracks Chinese for lifecycle/examples)
>
> **Authority**: [`CONTRACT.md`](CONTRACT.md) > this file. The **Chinese** [`api-reference.md`](api-reference.md)
> is the fuller surface for Stack/Deque Try\*Ex, H3-2 bag/multimap, and T2 extras.
> Absolute Mops claims require [`bench-envelope.md`](bench-envelope.md).
> **Preferred atomics**: `atomic_*` + `mo_*` / `TAtomic*` ([`READY.md`](READY.md) residual 0).
> **Lifecycle (T1)**: **Close → join → Free**. Examples: `t1_close_join_free`, `t1_segqueue_workers`, `t2_bag_close_join_free`, `t2_multimap_close_join_free`.
> **Selection**: [`selection-guide.en.md`](selection-guide.en.md) task-delivery table.

[中文版](api-reference.md)

## Atomic Types (nextpas.core.atomic)

> Prefer facade `atomic_*` + `mo_*`. PascalCase `AtomicLoad32` etc. are **legacy** ([`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) §1.4).

### TAtomicInt32 / TAtomicInt64

```pascal
type
  TAtomicInt32 = record
    function Load(const AOrder: TMemoryOrder = moSeqCst): Int32;
    procedure Store(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst);
    function CompareExchangeStrong(var AExpected: Int32; const ADesired: Int32; ...): Boolean;
    function CompareExchangeWeak(var AExpected: Int32; const ADesired: Int32; ...): Boolean;
    function FetchAdd(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function FetchSub(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function FetchAnd(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function FetchOr(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function FetchXor(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function FetchMax(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function FetchMin(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function Exchange(const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32;
    function UpdateIfEqual(const AExpected, ADesired: Int32; ...): Boolean;
    procedure Wait(const AExpected: Int32);
    procedure NotifyOne;
    procedure NotifyAll;
  end;
```

### TAtomicUInt64

```pascal
type
  TAtomicUInt64 = record
    // All standard atomic operations + FetchMax/FetchMin/FetchNand
    function FetchMax(const AValue: UInt64; ...): UInt64;
    function FetchMin(const AValue: UInt64; ...): UInt64;
    function FetchNand(const AValue: UInt64; ...): UInt64;
  end;
```

### TAtomicPtr

```pascal
type
  generic TAtomicPtr<T> = record
    function Load(const AOrder: TMemoryOrder = moSeqCst): T;
    procedure Store(const AValue: T; const AOrder: TMemoryOrder = moSeqCst);
    function CompareExchangeStrong(var AExpected: T; const ADesired: T; ...): Boolean;
    function Exchange(const AValue: T; const AOrder: TMemoryOrder = moSeqCst): T;
  end;
```

---

## SPSC Queue (nextpas.core.lockfree.spsc)

```pascal
type
  generic TSpscQueue<T> = class
    constructor Create(const ACapacity: PtrUInt);
    function TryEnqueue(const AValue: T): Boolean;
    function EnqueueWait(const AValue: T): Boolean;
    function EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function DequeueWait(out AValue: T): Boolean;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    function EnqueueBatch(const AItems: array of T): PtrUInt;
    function DequeueBatch(out AItems: array of T; const AMaxCount: PtrUInt): PtrUInt;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    function ApproxCount: PtrUInt;
    function Capacity: PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Linearization Points**:
- Enqueue: CAS on FWritePos (moRelease store to slot)
- Dequeue: CAS on FReadPos (moAcquire load from slot)

---

## SPMC Queue (nextpas.core.lockfree.spmc)

```pascal
type
  generic TSpmcQueue<T> = class
    constructor Create(const ACapacity: PtrUInt);
    function TryEnqueue(const AValue: T): Boolean;
    function EnqueueWait(const AValue: T): Boolean;
    function EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function DequeueWait(out AValue: T): Boolean;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    function ApproxCount: PtrUInt;
    function Capacity: PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Linearization Points**:
- Enqueue: CAS on FEnqueuePos → moRelease store to slot Sequence
- Dequeue: CAS on FDequeuePos → moAcquire load from slot Sequence

**Close Semantics**:
- After Close, TryEnqueue returns False, EnqueueWait/EnqueueTimeout immediately return False
- After Close, DequeueWait/DequeueTimeout implement drain-on-close: already-enqueued data still readable, returns False when empty
- Close wakes all blocked EnqueueWait/DequeueWait

---

## MPMC Queue (nextpas.core.lockfree.mpmc)

```pascal
type
  generic TMpmcQueue<T> = class
    // Same as SPSC API
  end;
```

**Linearization Points**: Same as SPMC (sequence-lock based on slot Sequence)

---

## SegQueue (nextpas.core.lockfree.segqueue)

```pascal
type
  generic TSegQueue<T> = class
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AValue: T);
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**:
- Unbounded **MPMC** segmented queue (production: `thread.pool` task nodes)
- Segmented design (fixed segment capacity)
- EBR reclaims old segments
- Enqueue always succeeds until Close
- TryEnqueue returns False after Close
- TryDequeue may return False (empty)
- After Close, already-enqueued data remains readable
- **Lifecycle: Close → join → Free** (teaching: `t1_segqueue_workers`)
- Optional `TryEnqueueEx` / `TryDequeueEx` → `TLockFreeTryError`

---

## MPSC Queue (nextpas.core.lockfree.mpsc)

```pascal
type
  generic TMpscQueue<T> = class
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AValue: T);
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function DequeueWait(out AValue: T): Boolean;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
  end;
```

**Features**:
- Unbounded MPSC linked queue (Treiber stack variant)
- Enqueue uses CAS linked-list append, always succeeds
- TryEnqueue returns False after Close
- After Close, DequeueWait/DequeueTimeout implement drain-on-close
- ApproxCount uses atomic counter (approximate)

---

## EBR (nextpas.core.lockfree.ebr)

```pascal
type
  TLockFreeReclaimProc = procedure(AData: Pointer; AUserData: Pointer);

  TEbrDomain = class
    constructor Create;
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
    procedure Retire(AData: Pointer; AReclaim: TLockFreeReclaimProc; AUserData: Pointer = nil);
    procedure Collect;
    function ActiveCount: PtrUInt;
    function RetiredCount: PtrUInt;
  end;

  TEbrGuard = record
    class function Acquire(ADomain: TEbrDomain): TEbrGuard; static;
    procedure Release;
  end;
```

**Safety Constraints**:
- `Collect` only reclaims when `ActiveCount = 0`
- Guard must be Acquired before accessing shared data, Released after
- TOCTOU window: between `Collect` check and retired list swap, new threads may enter
- Destroy forcibly reclaims all retired items (ignoring ActiveCount)

---

## ShardedHashMap (nextpas.core.lockfree.hashmap)

```pascal
type
  generic TShardedHashMap<TKey, TValue> = class
  public type
    TForEachCallback = procedure(const AKey: TKey; const AValue: TValue);
    TGetOrInsertResult = record
      Value: TValue;
      Existed: Boolean;
    end;
  public
    constructor Create(const AInitialCapacity: PtrUInt = 16);
    destructor Destroy; override;

    // Basic operations
    procedure Insert(const AKey: TKey; const AValue: TValue);
    function Find(const AKey: TKey; out AValue: TValue): Boolean;
    function Remove(const AKey: TKey): Boolean;
    function Remove(const AKey: TKey; out AValue: TValue): Boolean;  // Returns old value
    function TryInsert(const AKey: TKey; const AValue: TValue): Boolean;  // CAS semantics
    function Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
    function Contains(const AKey: TKey): Boolean;
    function Count: PtrUInt;

    // Advanced operations
    procedure ForEach(const ACallback: TForEachCallback);
    procedure ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
    function GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
    function GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;
    function GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;
    procedure Clear;
    procedure Reserve(const ACount: PtrUInt);
  end;
```

**Progress (honest)**: **sharded spin locks** — **not** lock-free. `TConcurrentHashMap` is the **same implementation alias**, not a second algorithm.

**Lifecycle** (Charter C): `Close` / `IsClosed`. After Close: Insert/Reserve/GetOrUpdate raise; TryInsert/Replace reject writes; GetOrInsert* only for existing keys; Find/Remove/ForEach/Clear still allowed. Destroy closes first. Teaching: `t2_hashmap_join_free`. Skiplist Close deferred; **not** H3-2 subset.

**Design Features**:
- 16 shards; preferred `atomic_exchange` spin path per shard
- Open addressing + linear probing; load factor 3/4; auto grow
- Unmanaged keys/values only

**API (summary)**:

| Method | Notes |
|--------|-------|
| Insert / Find / Remove / Contains | Per-shard lock; Remove marks `esDeleted` |
| TryInsert / Replace / GetOrInsert* / GetOrUpdate | Conditional / atomic update helpers |
| Count / ForEach / Clear | Count snapshots across shards; ForEach holds shard lock |

**Key equality**: `CompareByte` on unmanaged blobs; managed keys unsupported (pointer compare, not content). Prefer packed records or zeroed padding.

**Notes**:
- ForEach callback holds the shard lock — keep short; do not re-enter the map (deadlock)
- Not H3-2; not default-facade-only — HashMap **is** on the T1 facade

---


## Hazard Pointer (nextpas.core.lockfree.hazard)

```pascal
type
  TLockFreeReclaimProc = procedure(AData: Pointer; AUserData: Pointer);

  THazardThread = record
    // Per-thread registered hazard pointers
  end;

  THazardDomain = class
    constructor Create(const AHPCount: PtrUInt = 2);
    destructor Destroy; override;
    function RegisterThread: PtrUInt;
    procedure UnregisterThread(const AThreadId: PtrUInt);
    function Protect(const AThreadId: PtrUInt; const AHPIndex: PtrUInt; const APtr: Pointer): Pointer;
    procedure Clear(const AThreadId: PtrUInt; const AHPIndex: PtrUInt);
    procedure Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer = nil);
    procedure Collect(const AThreadId: PtrUInt);
    function ActiveThreads: PtrUInt;
    function RetiredCount: PtrUInt;
  end;

  THazardGuard = record
    class function Acquire(const ADomain: THazardDomain; const AHPIndex: PtrUInt = 0): THazardGuard; static;
    function Protect(const APtr: Pointer): Pointer;
    procedure Release;
  end;
```

**Design Features**:
- Based on Michael & Scott Hazard Pointer algorithm
- Per-thread independent hazard pointers, contention-free
- Deferred reclamation: retired nodes processed in batch during Collect
- Safety constraint: Retire does not traverse thread list (avoiding concurrent modification)

**Usage Example (Recommended: THazardGuard RAII)**:

```pascal
var
  LDomain: THazardDomain;
  LGuard: THazardGuard;
  LData: Pointer;
begin
  LDomain := THazardDomain.Create;
  try
    LGuard := THazardGuard.Acquire(LDomain, 0);
    try
      LData := LGuard.Protect(SharedPointer);
      // Safely access LData
      DoSomething(LData);
    finally
      LGuard.Release;
    end;

    // Retire old pointer
    LDomain.Retire(LData, @MyReclaimProc, nil);
  finally
    LDomain.Free;
  end;
end;
```

**Usage Example (Low-level API)**:

```pascal
var
  LDomain: THazardDomain;
  LThread: PtrUInt;
  LData: Pointer;
begin
  LDomain := THazardDomain.Create;
  try
    LThread := LDomain.RegisterThread;
    try
      LDomain.Protect(LThread, 0, LData);
      try
        // Safely access LData
        DoSomething(LData);
      finally
        LDomain.Clear(LThread, 0);
      end;

      // Retire old pointer
      LDomain.Retire(LData, @MyReclaimProc, nil);

      // Trigger reclamation (explicit call)
      LDomain.Collect(LThread);
    finally
      LDomain.UnregisterThread(LThread);
    end;
  finally
    LDomain.Free;
  end;
end;
```

**Reclamation Flow**:
1. `Protect`: Set thread's hazard pointer (moRelease)
2. `Clear`: Clear thread's hazard pointer (moRelease)
3. `Retire`: Add pointer to retired list (CAS moRelease)
4. `Collect`: Check all threads' hazard pointers, reclaim unprotected nodes

**Safety Constraints**:
- Recommend using `THazardGuard` RAII guard for automatic lifecycle management
- `Collect` must be called before `UnregisterThread` (traverses thread list)
- `Retire` does not call `Collect` (avoiding concurrent list modification)
- Retired node's reclamation callback must be idempotent (may be called multiple times)
- `Protect`/`Clear` validate parameters in DEBUG mode, silently ignore invalid parameters in Release mode

---

## Channel (nextpas.core.lockfree.channel)

Bounded lock-free Channel, sequence-number driven **MPMC-style** channel.

```pascal
type
  generic TLockFreeChannel<T> = class
    constructor Create(const ACapacity: PtrUInt);
    // Send (blocking/non-blocking/timeout)
    procedure Send(const AValue: T);               // Blocking, throws EInvalidOperationError when closed
    function TrySend(const AValue: T): Boolean;    // Non-blocking, returns False when closed/full
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    // Receive (blocking/non-blocking/timeout)
    function Receive(out AValue: T): Boolean;      // Blocking, returns False when closed+empty
    function TryReceive(out AValue: T): Boolean;   // Non-blocking
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    // Control
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxLen: PtrUInt;
    function Capacity: PtrUInt;
    function TryResize(const ANewCapacity: PtrUInt): Boolean;
  end;
```

**Key Semantics**:
- `Send` to closed channel throws `EInvalidOperationError` (Go panic aligned)
- `TrySend` to closed channel returns `False` (Go select ok=false aligned)
- Already-enqueued data still readable after Close
- Capacity automatically rounded up to power-of-two; **capacity=1 supported** with distinguishable full/empty (same empty/full sequence encoding as MPMC; R5)
- Optional `TrySendEx` / `TryReceiveEx`: full→`lfteFull`, empty→`lfteEmpty`, closed→`lfteClosed`
- `TryResize` dynamically adjusts capacity (spin-flag mechanism)
- **Lifecycle: Close → join → Free** (teaching: `t1_close_join_free`)

---

## SPSC Channel (nextpas.core.lockfree.channel.spsc)

Single-producer single-consumer bounded Channel, optimized for 1P1C scenarios.

```pascal
type
  generic TLockFreeChannelSpsc<T> = class
    constructor Create(const ACapacity: PtrUInt);
    // Send (blocking/non-blocking/timeout)
    procedure Send(const AValue: T);
    function TrySend(const AValue: T): Boolean;
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    // Receive (blocking/non-blocking/timeout)
    function Receive(out AValue: T): Boolean;
    function TryReceive(out AValue: T): Boolean;
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    // Control
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxLen: PtrUInt;
    function Capacity: PtrUInt;
  end;
```

**Differences from TLockFreeChannel**:
- Uses atomic load/store instead of CAS (1P1C contention-free)
- No sequence number overhead (direct ring buffer indexing)
- 1P1C hot path is typically faster than MPMC Channel / mutex baselines; absolute speedups require a full [`bench-envelope.md`](bench-envelope.md)

**Use Cases**:
- Single producer single consumer
- High-performance bounded channel needed
- No MPMC support required

**Limitations**:
- Only supports 1P1C, does not support MPMC
- For MPMC scenarios, use TLockFreeChannel

---

## Selector (nextpas.core.lockfree.selector)

Multi-channel multiplexer, Pascal implementation of Go `select` semantics.

```pascal
type
  TSelectResult = record
    Index: PtrInt;      // Completed case index (0-based)
    Completed: Boolean; // True=case completed, False=timeout
  end;

  generic TLockFreeSelector<T> = class
    constructor Create(const AExpectedCount: PtrUInt = 4);
    // Register cases
    procedure AddRecv(const AChannel: TLockFreeChannelImpl<T>; var AOutValue: T);
    procedure AddSend(const AChannel: TLockFreeChannelImpl<T>; const AValue: T);
    // Wait
    function Select: TSelectResult;                               // Blocking
    function SelectTimeout(const ATimeoutNs: Int64): TSelectResult; // Timeout
    function TrySelect: TSelectResult;                            // Non-blocking
    // Management
    procedure Clear;
    function CaseCount: PtrUInt;
  end;
```

**Correspondence with Go select** (Q3-a):

| Go | Pascal |
|----|--------|
| `case v := <-ch:` | `LSelector.AddRecv(LChannel, LOutVar)` |
| `case ch <- v:` | `LSelector.AddSend(LChannel, LValue)` |
| `select { ... }` | `LResult := LSelector.Select` |
| `select { ... default: }` | `LResult := LSelector.TrySelect` (`Completed=False` means default) |

**Usage Example**:
```pascal
var LSel: specialize TLockFreeSelector<Integer>;
    LCh1, LCh2: specialize TLockFreeChannel<Integer>;
    LResult: TSelectResult;
    LVal: Integer;
begin
  LCh1 := specialize TLockFreeChannel<Integer>.Create(4);
  LCh2 := specialize TLockFreeChannel<Integer>.Create(4);
  LSel := specialize TLockFreeSelector<Integer>.Create;
  try
    LSel.AddRecv(LCh1, LVal);
    LSel.AddSend(LCh2, 42);
    LResult := LSel.Select;
    if LResult.Completed then
      case LResult.Index of
        0: WriteLn('Received ', LVal, ' from Ch1');
        1: WriteLn('Sent 42 to Ch2');
      end;
  finally
    LSel.Free;
    LCh2.Free;
    LCh1.Free;
  end;
end;
```

**Design Constraints**:
- All cases must use the same type T (Go may mix types in one `select`; this API does not)
- No language-level `default` case object; use **`TrySelect`** for default
- When multiple cases are ready, earliest **Add** index wins (**not** Go random choice)
- Wait path: short spin then wait-address via `lockfree.wait` (`LockFreeWaitData`), not pure busy-poll
- `AddSend` stores a value copy; actual send only on successful Select/TrySelect
- Closed-empty recv aligns with `TryReceive=False`: TrySelect/SelectTimeout do not complete

---

## Stack (nextpas.core.lockfree.stack)

```pascal
type
  generic TLockFreeStack<T> = class
    constructor Create(const ACapacity: PtrUInt);
    function TryPush(const AValue: T): Boolean;
    function TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function TryPop(out AValue: T): Boolean;
    function TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
  end;
```

**Try\*Ex**: success→`lfteNone`; full→`lfteFull`; empty→`lfteEmpty`; closed→`lfteClosed`.

---

## WorkStealingDeque (nextpas.core.lockfree.deque) — T1

```pascal
type
  generic TWorkStealingDeque<T> = class
    constructor Create(const ACapacity: PtrUInt);
    function TryPush(const AValue: T): Boolean;
    function TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function TryPop(out AValue: T): Boolean;
    function TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function TrySteal(out AValue: T): Boolean;
    function TryStealEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
    function Capacity: PtrUInt;
  end;
```

**Features**:
- Owner: `TryPush` / `TryPop` (LIFO end); thieves: `TrySteal` (FIFO end)
- Bounded power-of-two; Close rejects new publish; already-enqueued may still pop/steal
- Optional `Try*Ex` (H2-1): full/empty/closed as above

**Not this type**: `lockfree.deque_lf` / `TLockFreeDeque` is **spin-lock** + `TDequeResult` — not lock-free / not wait-free; no `TLockFreeTryError` surface.

---

## Bag (nextpas.core.lockfree.bag)

> **H3-2 production subset** (CONTRACT §0.3): **direct** `uses nextpas.core.lockfree.bag`; **not** on default T1 facade.
> **Progress**: bounded **lock-free MPMC sequence ring** + wait-address path.
> **Managed**: rejected. **Lifecycle**: Close → drain/join → Free (teaching: `t2_bag_close_join_free`).

```pascal
type
  TLockFreeBagAddResult = (arAdded, arFull, arClosed);

  generic TLockFreeBag<T> = class
    constructor Create(const ACapacity: PtrUInt);
    function TryAdd(const AValue: T): TLockFreeBagAddResult;
    function TryTake(out AValue: T): Boolean;
    function AddWait(const AValue: T): Boolean;
    function TakeWait(out AValue: T): Boolean;
    function AddTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function TakeTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    function Capacity: PtrUInt;
    function ApproxCount: PtrUInt;
  end;
```

Duplicates allowed; FIFO. After Close, `TryAdd` → `arClosed`; already-added items remain takeable.

---

## MultiMap (nextpas.core.lockfree.multimap)

> **H3-2 production subset** (CONTRACT §0.3): direct `uses`; **not** default facade.
> **Progress**: **single map spin lock** — **not** lock-free, **not** sharded.
> **Managed** keys/values rejected. Close → stop writers → read/cleanup → Free
> (teaching: `t2_multimap_close_join_free`). After Close, `Add` → `mmClosed`; existing keys remain readable/removable.

```pascal
type
  TLockFreeMultiMapAddResult = (mmAdded, mmKeyExists, mmFull, mmClosed);

  generic TLockFreeMultiMap<TKey, TValue> = class
    constructor Create(const ACapacity: PtrUInt = 16);
    function Add(const AKey: TKey; const AValue: TValue): TLockFreeMultiMapAddResult;
    function Find(const AKey: TKey; out AValues: array of TValue): Integer;
    function Contains(const AKey: TKey): Boolean;
    function Remove(const AKey: TKey): Boolean;
    function RemoveValue(const AKey: TKey; const AValue: TValue): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
  end;
```

## Bloom Filter (nextpas.core.lockfree.bloom)

```pascal
type
  generic TConcurrentBloomFilter<T> = class
    constructor Create(const AExpectedItems: PtrUInt = 10000; const AFalsePositiveRate: Double = 0.01);
    function Add(const AValue: T): Boolean;
    function Contains(const AValue: T): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
    function Count: PtrUInt;
    function BitCount: PtrUInt;
    function HashCount: Integer;
  end;
```

**Features**: Probabilistic set (false positives possible, no false negatives). After `Close`, `Add` is rejected. **Not** H3-2 production subset — direct `uses` only; treat Close as unit-local API.

---

## LRU Cache (nextpas.core.lockfree.lru)

```pascal
type
  TLockFreeLruResult = (lrAdded, lrUpdated, lrFull, lrClosed);

  generic TConcurrentLruCache<TKey, TValue> = class
    constructor Create(const ACapacity: PtrUInt);
    function Get(const AKey: TKey; out AValue: TValue): Boolean;
    function Put(const AKey: TKey; const AValue: TValue): TLockFreeLruResult;
    function Remove(const AKey: TKey): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
    function Count: PtrUInt;
    function Capacity: PtrUInt;
  end;
```

**Progress**: concurrent cache with internal locks (not lock-free). `Put` → `lrClosed` after Close. Unmanaged keys/values. **Not** H3-2.

---

## Counter (nextpas.core.lockfree.counter)

```pascal
type
  TConcurrentCounter = class
    constructor Create(const AInitialValue: Int64 = 0);
    function Increment: Int64;
    function Decrement: Int64;
    function Add(const AValue: Int64): Int64;
    function Sub(const AValue: Int64): Int64;
    function Load: Int64;
    procedure Store(const AValue: Int64);
    procedure Reset;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: Atomic shared counter with optional Close gate. Prefer `TAtomic*` / `atomic_*` for simple counters when no Close is needed.

---

## Semaphore (nextpas.core.lockfree.semaphore)

```pascal
type
  TLockFreeSemaphoreAcquireResult = (saAcquired, saFull, saClosed, saTimeout);

  TConcurrentSemaphore = class
    constructor Create(const AMaxPermits: Int64);
    function TryAcquire: Boolean;
    function Acquire: Boolean;
    function AcquireTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Release;
    procedure Close;
    function IsClosed: Boolean;
    function AvailablePermits: Int64;
    function MaxPermits: Int64;
  end;
```

**Progress**: permit counting with wait/Close — **not** “lock-free by namespace”. Close unblocks waiters with closed results.

---

## Mutex (nextpas.core.lockfree.mutex)

```pascal
type
  TLockFreeMutexLockResult = (mlLocked, mlClosed, mlTimeout);

  TConcurrentMutex = class
    constructor Create;
    function TryLock: Boolean;
    function Lock: Boolean;
    function LockTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Unlock;
    procedure Close;
    function IsClosed: Boolean;
    function IsLocked: Boolean;
  end;
```

**Progress**: exclusive lock (spin/CAS path). Name is historical; treat as concurrent mutex, not LF data structure.

---

## RwLock (nextpas.core.lockfree.rwlock)

```pascal
type
  TConcurrentRwLock = class
    constructor Create;
    function TryReadLock: Boolean;
    function ReadLock: Boolean;
    function TryWriteLock: Boolean;
    function WriteLock: Boolean;
    procedure ReadUnlock;
    procedure WriteUnlock;
    procedure Close;
    function IsClosed: Boolean;
    function IsReadLocked: Boolean;
    function IsWriteLocked: Boolean;
  end;
```

**Features**: multiple readers / single writer; Close rejects new locks.

---

## CountdownLatch (nextpas.core.lockfree.countdown)

```pascal
type
  TCountDownLatch = class
    constructor Create(const AInitialCount: Int64);
    procedure Done;
    procedure DoneN(const AN: Int64);
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function GetCount: Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: one-shot barrier count-down; Wait until zero or Close.

---

## CyclicBarrier (nextpas.core.lockfree.barrier)

```pascal
type
  TCyclicBarrierWaitResult = (bwArrived, bwClosed, bwTimeout, bwBroken);

  TCyclicBarrier = class
    constructor Create(const AParties: Int64);
    function Await: TCyclicBarrierWaitResult;
    function AwaitTimeout(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
    function GetParties: Int64;
    function GetNumberWaiting: Int64;
    procedure Reset;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: N parties arrive each generation; Reset starts a new round; Close → `bwClosed`.

---

## Rate Limiter (nextpas.core.lockfree.ratelimit)

```pascal
type
  TLockFreeRateLimiterResult = (rlAllowed, rlRejected, rlClosed);

  TTokenBucketLimiter = class
    constructor Create(const ARatePerSecond: Double; const ABurst: Double);
    function TryAcquire: TLockFreeRateLimiterResult;
    function TryAcquireN(const AN: Double): TLockFreeRateLimiterResult;
    procedure Close;
    function IsClosed: Boolean;
    function GetRate: Double;
    function GetBurst: Double;
  end;
```

**Features**: token bucket admit/reject; after Close → `rlClosed`.

---

## Condition Variable (nextpas.core.lockfree.condvar)

```pascal
type
  TConditionVariableWaitResult = (cvSignaled, cvClosed, cvTimeout);

  TConditionVariable = class
    constructor Create;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): TConditionVariableWaitResult;
    procedure Signal;
    procedure Broadcast;
    procedure Close;
    function IsClosed: Boolean;
    function GetWaiterCount: Int32;
  end;
```

**Features**: wait/signal coordination with Close unblocking waiters.

---

## Exchanger (nextpas.core.lockfree.exchanger)

```pascal
type
  TLockFreeExchangeResult = (exExchanged, exClosed, exTimeout);

  generic TExchangerImpl<T> = class
    constructor Create;
    function Exchange(const AValue: T; out AOutValue: T): TLockFreeExchangeResult;
    function ExchangeTimeout(const AValue: T; out AOutValue: T; const ATimeoutNs: Int64): TLockFreeExchangeResult;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: two-thread rendezvous swap; both block until peer arrives or Close/timeout.

---

## Phaser (nextpas.core.lockfree.phaser)

```pascal
type
  TLockFreePhaserArriveResult = (paArrived, paAdvanced, paClosed, paTimeout);

  TPhaser = class
    constructor Create(const AParties: Int64 = 0);
    function Register: Int64;
    function Arrive: Int64;
    function ArriveAndAwaitAdvance: Int64;
    function ArriveAndDeregister: Int64;
    function AwaitAdvance(const APhase: Int64): TLockFreePhaserArriveResult;
    function AwaitAdvanceTimeout(const APhase: Int64; const ATimeoutNs: Int64): TLockFreePhaserArriveResult;
    function GetPhase: Int64;
    function GetParties: Int64;
    function GetArrived: Int64;
    function GetUnarrived: Int64;
    procedure Terminate;
    procedure Close;
    function IsClosed: Boolean;
    function IsTerminated: Boolean;
  end;
```

**Features**: multi-phase barrier with dynamic register/deregister; Terminate/Close end waiting.

---

## StampedLock (nextpas.core.lockfree.stampedlock)

```pascal
type
  TStampedLock = class
    constructor Create;
    function ReadLock: Int64;
    function TryReadLock: Int64;
    function TryReadLockTimeout(const ATimeoutNs: Int64): Int64;
    function WriteLock: Int64;
    function TryWriteLock: Int64;
    function TryWriteLockTimeout(const ATimeoutNs: Int64): Int64;
    function TryOptimisticRead: Int64;
    function Validate(const AStamp: Int64): Boolean;
    procedure UnlockRead(const AStamp: Int64);
    procedure UnlockWrite(const AStamp: Int64);
    procedure Close;
    function IsClosed: Boolean;
    function IsReadLocked: Boolean;
    function IsWriteLocked: Boolean;
  end;
```

**Features**: optimistic read + pessimistic R/W; stamp validates consistency. Read-heavy alternative to RwLock.

---

## Ring Buffer (nextpas.core.lockfree.ringbuffer)

```pascal
type
  TLockFreeRingBufferResult = (rbWritten, rbFull, rbEmpty, rbClosed);

  generic TRingBufferImpl<T> = class
    constructor Create(const ACapacity: Int64);
    function TryWrite(const AValue: T): TLockFreeRingBufferResult;
    function TryRead(out AValue: T): TLockFreeRingBufferResult;
    function WriteWait(const AValue: T): TLockFreeRingBufferResult;
    function ReadWait(out AValue: T): TLockFreeRingBufferResult;
    function WriteTimeout(const AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
    function ReadTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeRingBufferResult;
    function Count: Int64;
    function GetCapacity: Int64;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: fixed-capacity FIFO (power-of-two); MPMC head/tail CAS; Close → `rbClosed`. Prefer T1 Channel/SegQueue for production messaging.

---

## Concurrent Trie (nextpas.core.lockfree.trie)

```pascal
type
  TLockFreeTrieResult = (trInserted, trUpdated, trDeleted, trNotFound, trClosed);

  generic TConcurrentTrieImpl<TValue> = class
    constructor Create;
    function Insert(const AKey: string; const AValue: TValue): TLockFreeTrieResult;
    function Find(const AKey: string; out AValue: TValue): Boolean;
    function Delete(const AKey: string): TLockFreeTrieResult;
    function Contains(const AKey: string): Boolean;
    function GetCount: Int64;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Progress**: per-node spin locks (not lock-free). Prefix key/value store with Close gate.

---

## Timer Wheel (nextpas.core.lockfree.timerwheel)

```pascal
type
  TTimerCallback = procedure(AData: Pointer);
  TLockFreeTimerResult = (twScheduled, twCancelled, twClosed, twNotFound);

  TTimerWheel = class
    constructor Create(const ASlotCount: Int64; const ATickIntervalNs: Int64);
    function Schedule(const ACallback: TTimerCallback; const AData: Pointer; const ADelayTicks: Int64): Int64;
    function Cancel(const ATimerId: Int64): TLockFreeTimerResult;
    procedure Tick;
    procedure TickN(const AN: Int64);
    function ProcessExpired: Int64;
    function GetCurrentSlot: Int64;
    function GetTotalTicks: Int64;
    function GetTickIntervalNs: Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: hierarchical/slot wheel for delayed callbacks; drive with `Tick` / `ProcessExpired`.

---

## Timeout Queue (nextpas.core.lockfree.timeoutqueue)

```pascal
type
  TLockFreeTimeoutQueueResult = (tqDequeued, tqTimeout, tqEmpty, tqClosed);

  generic TTimeoutQueueImpl<T> = class
    constructor Create(const ACapacity: Int64; const ATimeoutNs: Int64);
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): TLockFreeTimeoutQueueResult;
    function DequeueWait(out AValue: T): TLockFreeTimeoutQueueResult;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): TLockFreeTimeoutQueueResult;
    function GetCount: Int64;
    function GetCapacity: Int64;
    function GetTimeoutNs: Int64;
    function IsEmpty: Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: bounded MPMC queue with timed dequeue; Close ends waiters.

---

## Work Stealing Pool (nextpas.core.lockfree.workstealing)

```pascal
type
  TWorkStealingTask = procedure(AData: Pointer);
  TLockFreeWorkStealingResult = (wsSubmitted, wsStolen, wsEmpty, wsClosed);

  TWorkStealingPool = class
    constructor Create(const AWorkerCount: Int64);
    function Submit(const ATask: TWorkStealingTask; const AData: Pointer): Boolean;
    function Steal(out ATask: TWorkStealingTask; out AData: Pointer): TLockFreeWorkStealingResult;
    function GetWorkerCount: Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Features**: per-worker deques; local LIFO, steal FIFO. Prefer `thread.pool.worksteal` + T1 `TWorkStealingDeque` for production core paths.

---

## Snapshot Isolation (nextpas.core.lockfree.snapshot)

```pascal
type
  TSnapshotResult = (srCommitted, srAborted, srConflict, srNotFound, srClosed);

  generic TSnapshotIsolationImpl<TValue> = class
    constructor Create;
    function BeginSnapshot: Int64;
    function Read(const AKey: string; const ASnapshotTs: Int64; out AValue: TValue): TSnapshotResult;
    function Write(const AKey: string; const AValue: TValue; const ATransactionTs: Int64): TSnapshotResult;
    function Commit(const ATransactionTs: Int64): TSnapshotResult;
    function Abort(const ATransactionTs: Int64): TSnapshotResult;
    procedure Close;
    function IsClosed: Boolean;
    function GetCurrentTimestamp: Int64;
  end;
```

**Features**: MVCC-style snapshot reads; writers do not block readers. Experimental / Guarded tier — see inventory.

---

## Graph (nextpas.core.lockfree.graph)

```pascal
type
  TLockFreeGraphResult = (grAdded, grRemoved, grNotFound, grExists, grClosed);

  TLockFreeGraph = class
    constructor Create;
    function AddVertex(AId: Int64): TLockFreeGraphResult;
    function RemoveVertex(AId: Int64): TLockFreeGraphResult;
    function AddEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
    function RemoveEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
    function HasEdge(AFromId, AToId: Int64): Boolean;
    function GetVertexCount: Int64;
    function GetEdgeCount: Int64;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**Progress**: adjacency-list graph with per-vertex spin locks (not lock-free).

---

### TLockFreeMsQueue\<T\> (nextpas.core.lockfree.msqueue) — T1 facade

```pascal
type
  generic TLockFreeMsQueue<T> = class
    constructor Create(ACapacity: Int32 = 64);
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function ApproxCount: Int64;
    function IsEmpty: Boolean;
  end;
```

**Features**: Michael–Scott lock-free unbounded MPMC; index node pool + auto grow. **Lifecycle** (CONTRACT §1.3): `Close` → join producers/consumers → `Free`. `Destroy` does Close+drain — **does not** replace join. Teaching: `t1_msqueue_close_join_free`.

---

### TLockFreeForkJoinPool (nextpas.core.lockfree.forkjoin)

```pascal
type
  TLockFreeForkJoinPool = class
    constructor Create(AWorkerCount: Int32 = 4);
    function Fork(const ATask: TForkJoinTask): TLockFreeForkJoinResult;
    function PopOrSteal(AWorkerId: Int32; out ATask: TForkJoinTask): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function WorkerCount: Int32;
    function ApproxPendingCount: Int64;
    function ApproxCompletedCount: Int64;
  end;
```

**Features**: Fork/join style pool; local LIFO + steal FIFO. Prefer production `thread.pool.worksteal` when integrating with core thread module.

---

### TCopyOnWriteArray\<T\> (nextpas.core.lockfree.cowarray)

```pascal
type
  generic TCopyOnWriteArray<T> = class
    function Get(AIndex: Int32; out AValue: T): TLockFreeCowArrayResult;
    function Count: Int32;
    function IsEmpty: Boolean;
    function Append(const AValue: T): TLockFreeCowArrayResult;
    function SetItem(AIndex: Int32; const AValue: T): TLockFreeCowArrayResult;
    function Delete(AIndex: Int32): TLockFreeCowArrayResult;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
    function Snapshot: TItems;
  end;
```

**Features**: lock-free reads, copy-on-write updates; best for rare writers (config / listener lists).

---

### TLockFreeDisjointSet (nextpas.core.lockfree.disjointset)

```pascal
type
  TLockFreeDisjointSet = class
    constructor Create(ACapacity: Int32 = 64);
    function MakeSet: Int32;
    function Find(AIdx: Int32): Int32;
    function Union(AIdx1, AIdx2: Int32): TLockFreeDisjointSetResult;
    function Connected(AIdx1, AIdx2: Int32): Boolean;
    function Count: Int32;
  end;
```

**Features**: union-find with path compression + rank; auto grow. **No Close** — stop mutators then Free.

---

### SkipList / other trees (index)

| Unit | Type (examples) | Close? | Progress note |
|------|-----------------|--------|----------------|
| `skiplist` / `skiplist_map` | `TConcurrentSkipList` | **No** | concurrent ordered map; stop mutators → join → Free (same honesty as HashMap) |
| `btree` / `rbtree` / `treap` / … | see inventory | unit-local | mixed locks; not H3-2 |
| caches (`lfu`, `ttl_cache`, `arccache`) | see inventory | often yes | sharded / spin — not LF |
| sketches (`hyperloglog`, `tdigest`, …) | see inventory | unit-local | atomic counters / mixed |

**H3-2 production Close subset remains Bag + MultiMap only** (CONTRACT §0.3 / Q4 — do not expand without charter). Inventory: [`t2-inventory.md`](t2-inventory.md). Chinese full prose: [`api-reference.md`](api-reference.md).

## Memory Order Reference

| Order | Semantics | Use Case |
|-------|-----------|----------|
| moRelaxed | No ordering constraints | Counters, statistics |
| moAcquire | Subsequent operations not reordered before this | Reading shared data |
| moRelease | Previous operations not reordered after this | Writing shared data |
| moAcqRel | Acquire + Release | CAS success path |
| moSeqCst | Global sequential consistency | Default, safest |

## T Type Constraints

All lockfree data structures require `T` to be unmanaged (preferred message template: CONTRACT §3.1):
```pascal
if IsManagedType(T) then
  raise EArgumentError.Create('<TypeName>: T must be unmanaged');
```

Supported types: Integer, UInt32, UInt64, Pointer, record (no string/dyn array/interface)
