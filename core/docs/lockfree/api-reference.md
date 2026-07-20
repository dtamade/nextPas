# Lockfree API 参考手册

> 更新: 2026-07-20（Maintenance preferred close-out + 示例/生命周期对齐）
>
> **权威顺序**：[`CONTRACT.md`](CONTRACT.md) > 本文件 > 选型/README。改 API 必须同步本文件。
> 绝对性能数字须带 [`bench-envelope.md`](bench-envelope.md)；禁止无信封 Mops 营销。
> **Preferred 原子原语**：热路径用 `atomic_*` + `mo_*` / `TAtomic*`（见 [`READY.md`](READY.md) residual 0）。
> **生命周期（T1 容器）**：**Close → join producers/waiters → Free**。Destroy 的 Close+drain **不**替代 join。
> **选型**：[`selection-guide.md`](selection-guide.md)「任务投递四选一」。
> **示例**：`t1_close_join_free`（Channel）、`t1_segqueue_workers`（SegQueue）、`t2_bag_close_join_free`（Bag）。

[English](api-reference.en.md)

## 原子类型 (nextpas.core.atomic)

> 门面优先 `atomic_load` / `atomic_store` / `atomic_compare_exchange_strong*` / `atomic_fetch_*` + `mo_*`。  
> PascalCase `AtomicLoad32` 等为 **legacy 兼容**（[`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) §1.4），新代码勿扩散。

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
    function Load(const AOrder: TMemoryOrder = moSeqCst): T;
    procedure Store(const AValue: T; const AOrder: TMemoryOrder = moSeqCst);
    function CompareExchangeStrong(var AExpected: T; const ADesired: T; ...): Boolean;
    function Exchange(const AValue: T; const AOrder: TMemoryOrder = moSeqCst): T;
  end;
```

---

## SPSC 队列 (nextpas.core.lockfree.spsc)

```pascal
type
  generic TSpscQueue<T> = class
    constructor Create(const ACapacity: PtrUInt);
    function TryEnqueue(const AValue: T): Boolean;
    function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function EnqueueWait(const AValue: T): Boolean;
    function EnqueueTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
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
- 无界 **MPMC** 分段队列（segment + EBR；生产侧 `thread.pool` 用此型）
- 分段设计（每段固定容量）
- EBR 自动回收旧段
- Enqueue 总是成功（无界，直至 Close）
- TryEnqueue 在 Close 后返回 False
- TryDequeue 可能返回 False（空队列）
- Close 后已入队仍可读；**生命周期：Close → join → Free**（教学：`t1_segqueue_workers`）

---

## MPSC 队列 (nextpas.core.lockfree.mpsc)

```pascal
type
  generic TMpscQueue<T> = class
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AValue: T);
    function TryEnqueue(const AValue: T): Boolean;
    function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function TryDequeue(out AValue: T): Boolean;
    function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
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
- 可选 `Try*Ex`：无界 publish 失败正常路径为 `lfteClosed`（无 `lfteFull`）

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

**Try\*Ex**: success→`lfteNone`；full→`lfteFull`；empty→`lfteEmpty`；closed→`lfteClosed`。

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

**特点**:
- Owner 线程：`TryPush` / `TryPop`（LIFO 端）；thief：`TrySteal`（FIFO 端）
- 有界 power-of-two；Close 后 publish 失败，已入队仍可 pop/steal
- 可选 `Try*Ex`（H2-1）：full→`lfteFull`，empty→`lfteEmpty`，closed→`lfteClosed`
- Boolean 热路径不变

**非此类型**: `lockfree.deque_lf` / `TLockFreeDeque` 为 **spin-lock** + `TDequeResult`，非 lock-free / 非 wait-free，无 `TLockFreeTryError` 面。

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

**Progress（诚实）**: **分片自旋锁** 并发 map，**不是 lock-free**。`TConcurrentHashMap` 是**同一实现别名**，不是第二套算法。

**设计特点**:
- 分片锁（16 shards），每 shard 自旋锁（preferred `atomic_exchange` 路径）
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

**命名**: `TConcurrentHashMap` ≡ `TShardedHashMap`（同 `TShardedHashMapImpl`）。不要用两者对比“性能差异”。

**精神对标**（非 API 拷贝）:

| 场景 | Go `sync.Map` | dashmap 精神 | nextpas |
|------|---------------|--------------|---------|
| 插入/覆盖 | `Store` | `insert` | `Insert` |
| 查找 | `Load` | `get` | `Find` / `Contains` |
| 条件插入 | — | `entry` API | `TryInsert` / `GetOrInsert*` |
| 删除 | `Delete` | `remove` | `Remove` |
| Progress | 运行时内部 | 分片锁 | **分片自旋锁（诚实）** |

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

有界无锁 Channel，序列号驱动的 **MPMC-style** 通道。

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
- 容量自动向上取整到 2 的幂；**capacity=1 支持** full/empty 可分（与 MPMC empty/full sequence 对齐；R5）
- 可选 `TrySendEx` / `TryReceiveEx`：full→`lfteFull`，empty→`lfteEmpty`，closed→`lfteClosed`

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
- 1P1C 热路径通常快于 MPMC Channel / mutex 基线；绝对倍数须带 [`bench-envelope.md`](bench-envelope.md)

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
| `select { ... default: }` | `LResult := LSelector.TrySelect`（`Completed=False` 即 default） |

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
- 所有 case 必须使用相同类型 T（Go 可在同一 `select` 混不同类型；本实现不支持）
- **无**语言级 `default` case 对象；用 **`TrySelect`** 表达 default
- 多 case 同时就绪时按 **Add 注册序** 选最早 case（**非** Go 随机选择）
- 等待：短 spin 后经 `lockfree.wait` 的 wait-address（`LockFreeWaitData`），不是纯忙轮询
- `AddSend` 存储值副本，Select/TrySelect 成功时才实际发送
- 空 closed channel 的 recv case 与 `TryReceive=False` 对齐：`TrySelect`/`SelectTimeout` 不完成
---

## Bag (nextpas.core.lockfree.bag)

> **H3-2 生产子集**（CONTRACT §0.3）：**直接** `uses nextpas.core.lockfree.bag`；**不**在默认 T1 门面。
> **Progress**：有界 **lock-free ring（MPMC 序列号槽）** + wait-address 阻塞路径；不是“集合语义完全无锁重写”。
> **Managed**：`IsManagedType(T)` → `EArgumentError`。生命周期：`Close` → drain/join → `Free`；`Destroy` 先 `Close`。

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
- 有界 ring bag，允许重复元素；FIFO
- `TryAdd`/`TryTake` 热路径 preferred CAS/序列号（`atomic_*`）；AddWait/TakeWait 可阻塞
- Close 后 `TryAdd` → `arClosed`，已入队仍可取出
- **生命周期**：Close → drain/join → Free（教学：`t2_bag_close_join_free`）
- 适用于任务袋、多生产者多消费者工作池等场景

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

## MultiMap (nextpas.core.lockfree.multimap)

> **H3-2 生产子集**（CONTRACT §0.3）：**直接** `uses nextpas.core.lockfree.multimap`；**不**在默认 T1 门面。
> **Progress**：**lock-based concurrent**（**单 map 自旋锁**），**不是**分片锁、**不是** lock-free map。
> **Managed**：键/值均须 unmanaged。生命周期：`Close` → 停写 → 读完/清理 → `Free`；`Destroy` 先 `Close`。

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
    function Count: PtrUInt;
    function KeyCount: PtrUInt;
  end;
```

**特点**:
- 单锁并发 multi-value map（每个键对应值列表）
- Remove 删除整个键，RemoveValue 删除特定值
- Close 后 `Add` → `mmClosed`；已有键仍可读/删
- 适用于索引、标签系统等场景

**使用示例**:

```pascal
var
  LMap: specialize TLockFreeMultiMap<String, Integer>;
  LValues: array[0..9] of Integer;
  LCount: Integer;
begin
  LMap := specialize TLockFreeMultiMap<String, Integer>.Create(16);
  try
    // 添加键值对（一个键可以有多个值）
    LMap.Add('tag1', 100);
    LMap.Add('tag1', 200);
    LMap.Add('tag2', 300);

    // 查找键的所有值
    LCount := LMap.Find('tag1', LValues);
    // LCount = 2, LValues[0] = 100, LValues[1] = 200

    // 删除特定值
    LMap.RemoveValue('tag1', 100);

    // 删除整个键
    LMap.Remove('tag2');
  finally
    LMap.Free;
  end;
end;
```

---

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

**特点**:
- 基于多个哈希函数的概率数据结构
- 可能存在假阳性（false positive），但不会有假阴性（false negative）
- 空间效率高，适合大规模数据去重
- 适用于缓存、去重、快速成员检查等场景

**使用示例**:

```pascal
var
  LBloom: specialize TConcurrentBloomFilter<Integer>;
begin
  // 创建布隆过滤器：期望 10000 个元素，1% 假阳性率
  LBloom := specialize TConcurrentBloomFilter<Integer>.Create(10000, 0.01);
  try
    // 添加元素
    LBloom.Add(42);
    LBloom.Add(100);

    // 检查元素是否存在
    if LBloom.Contains(42) then
      WriteLn('42 might exist');  // 可能存在（假阳性可能）

    // 检查不存在的元素
    if not LBloom.Contains(999) then
      WriteLn('999 definitely does not exist');  // 一定不存在
  finally
    LBloom.Free;
  end;
end;
```

**参数说明**:
- `AExpectedItems`: 期望存储的元素数量
- `AFalsePositiveRate`: 期望的假阳性率（0-1 之间）
- 位数组大小和哈希函数数量会自动计算

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

---

## Counter (nextpas.core.lockfree.counter)

```pascal
type
  TConcurrentCounter = class
    constructor Create(const AInitialValue: Int64 = 0);
    function Increment: Int64;      // 返回新值
    function Decrement: Int64;      // 返回新值
    function Add(const AValue: Int64): Int64;
    function Sub(const AValue: Int64): Int64;
    function Load: Int64;
    procedure Store(const AValue: Int64);
    procedure Reset;
    procedure Close;
    function IsClosed: Boolean;
  end;
```

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

**特点**:
- 两个线程交换值的同步点
- 线程 A Exchange(A) 阻塞等待，线程 B Exchange(B) 阻塞等待
- 两方到达后交换值，各自拿到对方的值
- 适用场景：双线程管道、一对一通信

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

**特点**:
- 灵活的同步屏障，支持动态注册/注销
- 每个相位(phase)有 N 个参与方，所有到达后进入下一相位
- 支持多相位连续同步
- 适用场景：分阶段并行计算、动态任务分组

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

**特点**:
- 乐观读锁 + 悲观读写锁
- TryOptimisticRead 无锁读取，Validate 验证一致性
- 读多写少场景比 RwLock 更高效
- 单 Int64 状态编码（高32位=版本，低32位=锁状态）

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

**特点**:
- 固定大小 FIFO 队列，基于数组
- 容量自动取整到 2 的幂，位掩码取模
- MPMC 安全，head/tail 双指针 CAS
- 适用场景：生产者-消费者、日志缓冲、实时系统

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

**特点**:
- 基于前缀树的并发键值存储
- 每节点自旋锁保证并发安全
- 支持前缀匹配、自动补全
- 适用场景：IP 路由、字典、自动补全

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

**特点**:
- 环形数组 + 轮次计数实现定时器
- 每个 tick 推进一个槽位，到期执行回调
- 适用场景：超时管理、心跳检测、定时任务调度

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

**特点**:
- 固定大小 MPMC 队列，支持超时等待
- DequeueTimeout 支持超时返回
- 适用场景：请求超时、任务调度、生产者-消费者

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

**特点**:
- 每个工作线程有自己的双端队列
- 本地任务 LIFO push/pop，窃取任务 FIFO steal
- 最小化竞争，适合任务并行场景
- 适用场景：任务调度、并行计算、fork-join

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

**特点**:
- 每个事务看到数据库在事务开始时的快照
- 支持多版本并发控制 (MVCC)
- 读操作不阻塞写操作，写操作不阻塞读操作
- 适用场景：数据库事务、并发状态管理

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

**特点**:
- 基于邻接表的并发图数据结构
- 每顶点自旋锁保证并发安全
- 支持有向图，添加/删除顶点和边
- 适用场景：社交网络、依赖分析、路径查找

---

### TLockFreeMsQueue\<T\> (nextpas.core.lockfree.msqueue)

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

**特点**:
- Michael-Scott 经典无锁无界 MPMC 队列
- index-based 节点池，自动扩容
- Sentinel 节点简化空队列边界处理
- 适用场景：高吞吐消息队列、生产者-消费者模式

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

**特点**:
- 类似 Java ForkJoinPool 的并行执行框架
- 每个工作者有本地双端队列
- 本地任务 LIFO 执行，窃取任务 FIFO 执行
- 适用场景：递归分治、并行计算、MapReduce

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

**特点**:
- 读无锁，写时复制整个数组
- 线程安全的快照语义
- 适用场景：读多写极少（配置列表、监听器列表）

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

**特点**:
- 路径压缩 + 按秩合并，均摊 O(α(n)) ≈ O(1)
- 自动扩容
- 适用场景：动态连通性查询、聚类、图算法、Kruskal 最小生成树

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

所有 lockfree 数据结构要求 `T` 为非托管类型（推荐文案见 CONTRACT §3.1）：
```pascal
if IsManagedType(T) then
  raise EArgumentError.Create('<TypeName>: T must be unmanaged');
```

支持的类型: Integer, UInt32, UInt64, Pointer, record (无 string/dyn array/interface)
