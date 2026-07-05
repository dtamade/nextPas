# Lockfree API 参考手册

> 更新: 2026-07-05

## 原子类型 (nextpas.core.atomic)

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
    // 所有标准原子操作 + FetchMax/FetchMin/FetchNand
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

## SPSC 队列 (nextpas.core.lockfree.spsc)

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

**线性化点**:
- Enqueue: CAS on FWritePos (moRelease store to slot)
- Dequeue: CAS on FReadPos (moAcquire load from slot)

---

## SPMC 队列 (nextpas.core.lockfree.spmc)

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
  end;
```

**线性化点**:
- Enqueue: CAS on FEnqueuePos → moRelease store to slot Sequence
- Dequeue: CAS on FDequeuePos → moAcquire load from slot Sequence

**注意**: SPMC 不支持 Close（单生产者无界等待语义不同）

---

## MPMC 队列 (nextpas.core.lockfree.mpmc)

```pascal
type
  generic TMpmcQueue<T> = class
    // 同 SPSC API
  end;
```

**线性化点**: 与 SPMC 相同（基于 slot Sequence 的序列锁）

---

## SegQueue (nextpas.core.lockfree.segqueue)

```pascal
type
  generic TSegQueue<T> = class
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AValue: T);
    function TryDequeue(out AValue: T): Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
  end;
```

**特点**:
- 无界 MPSC 队列
- 分段设计（每段 32 元素）
- EBR 自动回收旧段
- Enqueue 总是成功（无界）
- TryDequeue 可能返回 False（空队列）

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

**安全约束**:
- `Collect` 仅在 `ActiveCount = 0` 时回收
- Guard 必须在访问共享数据前 Acquire，访问后 Release
- TOCTOU 窗口: `Collect` 检查和退休链表交换之间，可能有新线程进入
- Destroy 强制回收所有退休项（无视 ActiveCount）

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

    // 基础操作
    procedure Insert(const AKey: TKey; const AValue: TValue);
    function Find(const AKey: TKey; out AValue: TValue): Boolean;
    function Remove(const AKey: TKey): Boolean;
    function Contains(const AKey: TKey): Boolean;
    function Count: PtrUInt;

    // 高级操作
    procedure ForEach(const ACallback: TForEachCallback);
    function GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
    procedure Clear;
  end;
```

**设计特点**:
- 分片锁（16 shards），每个 shard 使用 AtomicExchange32 自旋锁
- 开放寻址 + 线性探测
- 负载因子 3/4，自动扩容
- 仅支持 unmanaged 类型

**API 说明**:

| 方法 | 复杂度 | 并发安全 | 说明 |
|------|--------|----------|------|
| Insert | O(1) amortized | ✅ | 插入或覆盖 |
| Find | O(1) amortized | ✅ | 查找并返回值 |
| Remove | O(1) amortized | ✅ | 删除键（标记 esDeleted） |
| Contains | O(1) amortized | ✅ | 检查键是否存在 |
| Count | O(shards) | ✅ | 逐 shard 加锁累加 |
| ForEach | O(n) | ✅ | 逐 shard 遍历，持锁期间回调 |
| GetOrInsert | O(1) amortized | ✅ | 原子获取或插入，仅加锁一次 |
| Clear | O(n) | ✅ | 逐 shard 清空 |

**性能特征**（vs TConcurrentHashMap）:

| 场景 | TShardedHashMap | TConcurrentHashMap |
|------|-----------------|-------------------|
| 锁机制 | AtomicExchange ~1ns | RWLock ~10-50ns |
| 内存管理 | 无引用计数 | 有引用计数 |
| 适用场景 | 高频、低竞争、unmanaged | 通用、支持 managed |

**使用示例**:

```pascal
var
  LMap: specialize TShardedHashMap<AnsiString, Integer>;
  LRes: specialize TGetOrInsertResult<Integer>;
begin
  LMap := specialize TShardedHashMap<AnsiString, Integer>.Create;
  try
    // 基础操作
    LMap.Insert('key1', 100);
    if LMap.Find('key1', LValue) then
      WriteLn('Found: ', LValue);

    // ForEach 遍历
    LMap.ForEach(@MyCallback);

    // GetOrInsert 原子操作
    LRes := LMap.GetOrInsert('key2', 200);
    if LRes.Existed then
      WriteLn('Existing: ', LRes.Value)
    else
      WriteLn('Inserted: ', LRes.Value);

    // 清空
    LMap.Clear;
  finally
    LMap.Free;
  end;
end;
```

**注意事项**:
- ForEach 回调期间持有 shard 锁，应尽快完成
- 不可在 ForEach 回调中调用本 HashMap 的其他方法（死锁）
- Count 返回近似值（逐 shard 加锁）
- Remove 使用标记删除（esDeleted），不会 compact

---

## 内存顺序参考

| Order | 语义 | 使用场景 |
|-------|------|----------|
| moRelaxed | 无顺序约束 | 计数器、统计 |
| moAcquire | 后续操作不重排到此之前 | 读共享数据 |
| moRelease | 之前操作不重排到此之后 | 写共享数据 |
| moAcqRel | Acquire + Release | CAS 成功路径 |
| moSeqCst | 全局顺序一致性 | 默认，最安全 |

## T 类型约束

所有 lockfree 数据结构要求 `T` 为非托管类型：
```pascal
if IsManagedType(T) then
  raise EArgumentError.Create('T must be unmanaged');
```

支持的类型: Integer, UInt32, UInt64, Pointer, record (无 string/dyn array/interface)
