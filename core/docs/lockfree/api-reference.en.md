# Lockfree API Reference

> Updated: 2026-07-06

[中文版](api-reference.md)

## Atomic Types (nextpas.core.atomic)

### TAtomicInt32 / TAtomicInt64

```pascal
type
  TAtomicInt32 = record
    function Load(const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    procedure Store(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent);
    function CompareExchangeStrong(var AExpected: Int32; const ADesired: Int32; ...): Boolean;
    function CompareExchangeWeak(var AExpected: Int32; const ADesired: Int32; ...): Boolean;
    function FetchAdd(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function FetchSub(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function FetchAnd(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function FetchOr(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function FetchXor(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function FetchMax(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function FetchMin(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
    function Exchange(const AValue: Int32; const AOrder: TMemoryOrder = moSequentiallyConsistent): Int32;
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
    function Load(const AOrder: TMemoryOrder = moSequentiallyConsistent): T;
    procedure Store(const AValue: T; const AOrder: TMemoryOrder = moSequentiallyConsistent);
    function CompareExchangeStrong(var AExpected: T; const ADesired: T; ...): Boolean;
    function Exchange(const AValue: T; const AOrder: TMemoryOrder = moSequentiallyConsistent): T;
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
- Unbounded MPSC queue
- Segmented design (32 elements per segment)
- EBR automatically reclaims old segments
- Enqueue always succeeds (unbounded)
- TryEnqueue returns False after Close
- TryDequeue may return False (empty queue)
- Close does not affect reading of already-enqueued data

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

**Design Features**:
- Sharded locks (16 shards), each shard uses AtomicExchange32 spin lock
- Open addressing + linear probing
- Load factor 3/4, automatic expansion
- Only supports unmanaged types

**API Description**:

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

**Key Equality**:
- Uses `CompareByte` byte-by-byte comparison, suitable for all unmanaged types (Integer, Int64, record, etc.)
- Does not support managed types (AnsiString, UnicodeString, etc.) as keys—compares pointer values, not content
- Record type keys need attention to padding bytes: recommend using packed record or ensuring padding is zeroed

**Usage Example**:

```pascal
var
  LMap: specialize TShardedHashMap<Integer, AnsiString>;
  LRes: specialize TGetOrInsertResult<AnsiString>;
  LValue: AnsiString;
begin
  LMap := specialize TShardedHashMap<Integer, AnsiString>.Create;
  try
    // Basic operations
    LMap.Insert(1, 'value1');
    if LMap.Find(1, LValue) then
      WriteLn('Found: ', LValue);

    // ForEach traversal
    LMap.ForEach(@MyCallback);

    // ForEachCtx traversal with context
    LMap.ForEachCtx(@MyCtxCallback, @MyContext);

    // GetOrInsert atomic operation
    LRes := LMap.GetOrInsert(2, 'default');
    if LRes.Existed then
      WriteLn('Existing: ', LRes.Value)
    else
      WriteLn('Inserted: ', LRes.Value);

    // GetOrInsertFn lazy compute
    LRes := LMap.GetOrInsertFn(3, function(const AKey: Integer): AnsiString begin
      Result := 'computed_' + IntToStr(AKey);  // Only called when key doesn't exist
    end);

    // GetOrUpdate atomic update
    LRes := LMap.GetOrUpdate(99, 0, function(const AOld: Integer): Integer begin
      Result := AOld + 1;  // Read old value, return new value
    end);
    WriteLn('Counter: ', LRes.Value);

    // Clear
    LMap.Clear;
  finally
    LMap.Free;
  end;
end;
```

**Notes**:
- ForEach callback holds shard lock during execution, should complete quickly
- Do not call other HashMap methods inside ForEach callback (deadlock)
- Count returns approximate value (per-shard locking)
- Remove uses lazy deletion (esDeleted), does not compact

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
- Capacity automatically rounded up to power-of-two
- `TryResize` dynamically adjusts capacity (spin-flag mechanism)

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
- Performance surpasses Go channel (2.99x) and Rust std::sync::mpsc (1.26x)

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

**Correspondence with Go select**:

| Go | Pascal |
|----|--------|
| `case v := <-ch:` | `LSelector.AddRecv(LChannel, LOutVar)` |
| `case ch <- v:` | `LSelector.AddSend(LChannel, LValue)` |
| `select { ... }` | `LResult := LSelector.Select` |

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
- All cases must use the same type T (consistent with Go select type constraints)
- Does not support `default` branch (use TrySend/TryReceive directly when needed)
- poll + backoff strategy (pure user-space polling, no kernel wait address)
- `AddSend` stores value copy, actual send only on Select success

---

## Memory Order Reference

| Order | Semantics | Use Case |
|-------|-----------|----------|
| moRelaxed | No ordering constraints | Counters, statistics |
| moAcquire | Subsequent operations not reordered before this | Reading shared data |
| moRelease | Previous operations not reordered after this | Writing shared data |
| moAcqRel | Acquire + Release | CAS success path |
| moSeqCst | Global sequential consistency | Default, safest |

## T Type Constraints

All lockfree data structures require `T` to be unmanaged type:
```pascal
if IsManagedType(T) then
  raise EArgumentError.Create('T must be unmanaged');
```

Supported types: Integer, UInt32, UInt64, Pointer, record (no string/dyn array/interface)
