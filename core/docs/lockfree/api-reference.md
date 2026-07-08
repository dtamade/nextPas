# Lockfree API 参考手册

> 更新: 2026-07-06

[English](api-reference.en.md)

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
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**线性化点**:
- Enqueue: CAS on FEnqueuePos → moRelease store to slot Sequence
- Dequeue: CAS on FDequeuePos → moAcquire load from slot Sequence

**Close 语义**:
- Close 后 TryEnqueue 返回 False，EnqueueWait/EnqueueTimeout 立即返回 False
- Close 后 DequeueWait/DequeueTimeout 实现 drain-on-close：已入队数据仍可读，空时返回 False
- Close 唤醒所有阻塞的 EnqueueWait/DequeueWait

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
    function TryEnqueue(const AValue: T): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function IsEmpty: Boolean;
    function ApproxCount: PtrUInt;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

**特点**:
- 无界 MPSC 队列
- 分段设计（每段 32 元素）
- EBR 自动回收旧段
- Enqueue 总是成功（无界）
- TryEnqueue 在 Close 后返回 False
- TryDequeue 可能返回 False（空队列）
- Close 不影响已入队数据的读取

---

## MPSC 队列 (nextpas.core.lockfree.mpsc)

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

**特点**:
- 无界 MPSC 链表队列（Treiber stack 变体）
- Enqueue 使用 CAS 链表追加，总成功
- TryEnqueue 在 Close 后返回 False
- Close 后 DequeueWait/DequeueTimeout 实现 drain-on-close
- ApproxCount 使用原子计数器（近似值）

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
    function Remove(const AKey: TKey; out AValue: TValue): Boolean;  // 返回旧值
    function TryInsert(const AKey: TKey; const AValue: TValue): Boolean;  // CAS 语义
    function Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
    function Contains(const AKey: TKey): Boolean;
    function Count: PtrUInt;

    // 高级操作
    procedure ForEach(const ACallback: TForEachCallback);
    procedure ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
    function GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
    function GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;
    function GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;
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
| Remove (out) | O(1) amortized | ✅ | 删除键并返回旧值 |
| TryInsert | O(1) amortized | ✅ | CAS 语义：仅不存在时插入 |
| Replace | O(1) amortized | ✅ | 原子替换并返回旧值 |
| Contains | O(1) amortized | ✅ | 检查键是否存在 |
| Count | O(shards) | ✅ | 逐 shard 加锁累加（快照） |
| ForEach | O(n) | ✅ | 逐 shard 遍历，持锁期间回调 |
| ForEachCtx | O(n) | ✅ | 带上下文的逐 shard 遍历 |
| GetOrInsert | O(1) amortized | ✅ | 原子获取或插入，仅加锁一次 |
| GetOrInsertFn | O(1) amortized | ✅ | 延迟计算：仅在键不存在时调用 |
| GetOrUpdate | O(1) amortized | ✅ | 原子 get-or-create-then-update |
| Clear | O(n) | ✅ | 逐 shard 清空 |

**性能特征**（vs TConcurrentHashMap）:

| 场景 | TShardedHashMap | TConcurrentHashMap |
|------|-----------------|-------------------|
| 锁机制 | AtomicExchange ~1ns | RWLock ~10-50ns |
| 内存管理 | 无引用计数 | 有引用计数 |
| 适用场景 | 高频、低竞争、unmanaged | 通用、支持 managed |

**键相等性**:
- 使用 `CompareByte` 逐字节比较，适用于所有 unmanaged 类型（Integer、Int64、record 等）
- 不支持 managed 类型（AnsiString、UnicodeString 等）作为键——比较的是指针值而非内容
- 记录类型键需注意 padding 字节：建议使用 packed record 或确保 padding 已清零

**使用示例**:

```pascal
var
  LMap: specialize TShardedHashMap<Integer, AnsiString>;
  LRes: specialize TGetOrInsertResult<AnsiString>;
  LValue: AnsiString;
begin
  LMap := specialize TShardedHashMap<Integer, AnsiString>.Create;
  try
    // 基础操作
    LMap.Insert(1, 'value1');
    if LMap.Find(1, LValue) then
      WriteLn('Found: ', LValue);

    // ForEach 遍历
    LMap.ForEach(@MyCallback);

    // ForEachCtx 带上下文遍历
    LMap.ForEachCtx(@MyCtxCallback, @MyContext);

    // GetOrInsert 原子操作
    LRes := LMap.GetOrInsert(2, 'default');
    if LRes.Existed then
      WriteLn('Existing: ', LRes.Value)
    else
      WriteLn('Inserted: ', LRes.Value);

    // GetOrInsertFn 延迟计算
    LRes := LMap.GetOrInsertFn(3, function(const AKey: Integer): AnsiString begin
      Result := 'computed_' + IntToStr(AKey);  // 仅在键不存在时调用
    end);

    // GetOrUpdate 原子更新
    LRes := LMap.GetOrUpdate(99, 0, function(const AOld: Integer): Integer begin
      Result := AOld + 1;  // 读取旧值，返回新值
    end);
    WriteLn('Counter: ', LRes.Value);

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

## Hazard Pointer (nextpas.core.lockfree.hazard)

```pascal
type
  TLockFreeReclaimProc = procedure(AData: Pointer; AUserData: Pointer);

  THazardThread = record
    // 每线程注册的 hazard 指针
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

**设计特点**:
- 基于 Michael & Scott Hazard Pointer 算法
- 每线程独立的 hazard 指针，无竞争
- 延迟回收：退休节点在 Collect 时批量处理
- 安全约束：Retire 不遍历线程链表（避免并发修改）

**使用示例（推荐：THazardGuard RAII）**:

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
      // 安全访问 LData
      DoSomething(LData);
    finally
      LGuard.Release;
    end;

    // 退休旧指针
    LDomain.Retire(LData, @MyReclaimProc, nil);
  finally
    LDomain.Free;
  end;
end;
```

**使用示例（底层 API）**:

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
        // 安全访问 LData
        DoSomething(LData);
      finally
        LDomain.Clear(LThread, 0);
      end;

      // 退休旧指针
      LDomain.Retire(LData, @MyReclaimProc, nil);

      // 触发回收（显式调用）
      LDomain.Collect(LThread);
    finally
      LDomain.UnregisterThread(LThread);
    end;
  finally
    LDomain.Free;
  end;
end;
```

**回收流程**:
1. `Protect`: 设置线程的 hazard 指针（moRelease）
2. `Clear`: 清除线程的 hazard 指针（moRelease）
3. `Retire`: 将指针加入退休链表（CAS moRelease）
4. `Collect`: 检查所有线程的 hazard 指针，回收未被保护的节点

**安全约束**:
- 推荐使用 `THazardGuard` RAII 守卫，自动管理生命周期
- `Collect` 必须在 `UnregisterThread` 前调用（遍历线程链表）
- `Retire` 不调用 `Collect`（避免并发修改链表）
- 退休节点的回收回调必须幂等（可能被多次调用）
- `Protect`/`Clear` 在 DEBUG 模式下校验参数，Release 模式静默忽略无效参数

---

## Channel (nextpas.core.lockfree.channel)

有界无锁 Channel，序列号驱动的 MPSC/SPMC 通道。

```pascal
type
  generic TLockFreeChannel<T> = class
    constructor Create(const ACapacity: PtrUInt);
    // 发送（阻塞/非阻塞/超时）
    procedure Send(const AValue: T);               // 阻塞，closed 时抛 EInvalidOperationError
    function TrySend(const AValue: T): Boolean;    // 非阻塞，closed/full 时返回 False
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    // 接收（阻塞/非阻塞/超时）
    function Receive(out AValue: T): Boolean;      // 阻塞，closed+空时返回 False
    function TryReceive(out AValue: T): Boolean;   // 非阻塞
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    // 控制
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxLen: PtrUInt;
    function Capacity: PtrUInt;
  end;
```

**关键语义**:
- `Send` 到已关闭 channel 抛 `EInvalidOperationError`（Go panic 对齐）
- `TrySend` 到已关闭 channel 返回 `False`（Go select ok=false 对齐）
- 已入队数据在 Close 后仍可读
- 容量自动向上取整到 2 的幂

---

## SPSC Channel (nextpas.core.lockfree.channel.spsc)

单生产者单消费者有界 Channel，专为 1P1C 场景优化。

```pascal
type
  generic TLockFreeChannelSpsc<T> = class
    constructor Create(const ACapacity: PtrUInt);
    // 发送（阻塞/非阻塞/超时）
    procedure Send(const AValue: T);
    function TrySend(const AValue: T): Boolean;
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    // 接收（阻塞/非阻塞/超时）
    function Receive(out AValue: T): Boolean;
    function TryReceive(out AValue: T): Boolean;
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    // 控制
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function ApproxLen: PtrUInt;
    function Capacity: PtrUInt;
  end;
```

**与 TLockFreeChannel 的区别**:
- 使用原子 load/store 替代 CAS（1P1C 无竞争）
- 无序列号开销（环形缓冲区直接索引）
- 性能超越 Go channel (2.99x) 和 Rust std::sync::mpsc (1.26x)

**使用场景**:
- 单生产者单消费者
- 需要高性能的有界通道
- 不需要 MPMC 支持

**限制**:
- 仅支持 1P1C，不支持 MPMC
- 使用 MPMC 场景请使用 TLockFreeChannel

---

## Selector (nextpas.core.lockfree.selector)

多路 Channel 复用器，Go `select` 语义的 Pascal 实现。

```pascal
type
  TSelectResult = record
    Index: PtrInt;      // 完成的 case 索引（从 0 开始）
    Completed: Boolean; // True=有 case 完成，False=超时
  end;

  generic TLockFreeSelector<T> = class
    constructor Create(const AExpectedCount: PtrUInt = 4);
    // 注册 case
    procedure AddRecv(const AChannel: TLockFreeChannelImpl<T>; var AOutValue: T);
    procedure AddSend(const AChannel: TLockFreeChannelImpl<T>; const AValue: T);
    // 等待
    function Select: TSelectResult;                               // 阻塞
    function SelectTimeout(const ATimeoutNs: Int64): TSelectResult; // 超时
    function TrySelect: TSelectResult;                            // 非阻塞
    // 管理
    procedure Clear;
    function CaseCount: PtrUInt;
  end;
```

**与 Go select 的对应**:

| Go | Pascal |
|----|--------|
| `case v := <-ch:` | `LSelector.AddRecv(LChannel, LOutVar)` |
| `case ch <- v:` | `LSelector.AddSend(LChannel, LValue)` |
| `select { ... }` | `LResult := LSelector.Select` |

**使用示例**:
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

**设计约束**:
- 所有 case 必须使用相同类型 T（与 Go select 的类型约束一致）
- 不支持 `default` 分支（需要时直接 TrySend/TryReceive）
- poll + backoff 策略（纯用户态轮询，不使用内核 wait address）
- `AddSend` 存储值副本，Select 成功后才实际发送

---

## Bag (nextpas.core.lockfree.bag)

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

**特点**:
- 基于 MPMC 队列实现，允许重复元素
- FIFO 顺序（先进先出）
- AddWait/TakeWait 阻塞等待
- AddTimeout/TakeTimeout 超时等待
- Close 后不能再添加，但可以取出已有元素
- 适用于任务队列、工作池等场景

**使用示例**:

```pascal
var
  LBag: specialize TLockFreeBag<Integer>;
  LValue: Integer;
begin
  LBag := specialize TLockFreeBag<Integer>.Create(1024);
  try
    // 添加元素（允许重复）
    LBag.TryAdd(42);
    LBag.TryAdd(42);  // 可以重复

    // 取出元素
    if LBag.TryTake(LValue) then
      WriteLn('Got: ', LValue);  // 42

    // 关闭
    LBag.Close;
  finally
    LBag.Free;
  end;
end;
```

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
