# nextpas.core.lockfree 代码契约

**模块路径**：`core/src/nextpas.core.lockfree*.pas`（约 100+ 源文件；默认门面仅 T1）
**层级**：L1（依赖 L0: base, atomic；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-17
**版本**：2.3

---

## 0. 默认门面（T1）

`uses nextpas.core.lockfree` 仅 re-export **T1 runtime core**：
SPSC/MPMC/MPSC/SPMC/SegQueue/MSQueue、Stack、WorkStealingDeque、EBR/Hazard、Channel、Selector、ShardedHashMap（及 `TConcurrentHashMap` 别名）。

T2/T3 子模块源文件仍保留在 `core/src/`，但**必须直接** `uses nextpas.core.lockfree.<unit>`，不会被默认门面拉入。

进度保证（lock-free vs lock-based）见 `README.md` 的 Progress-guarantee matrix；`TShardedHashMap` / `TConcurrentHashMap` 为同一分片自旋锁实现（别名，不是两套实现）。

**命名例外**：
- `nextpas.core.lockfree.deque_lf` 名称含 “lf”，实现为 **lock-based** concurrent deque（非 lock-free）。
- `nextpas.core.lockfree.lru_cache` / 部分 AnsiString 特化单元允许 managed `AnsiString` 载荷；不要求 `IsManagedType` 泛型守卫。

### 0.1 AnsiString-specialized exceptions（`IsManagedType` 守卫例外）

下列单元以 `AnsiString`（或等价 managed string 载荷）特化实现，**有意不**对 payload 做 `IsManagedType` 拒绝。泛型 T1/T2 容器仍必须在 `Create` 拒绝 managed 元素。

| 单元 | managed 载荷 |
|------|----------------|
| `actor` | AnsiString message `Data` |
| `consistent_hashring` | AnsiString node names |
| `crdt` | AnsiString LWW/OR-Set payloads |
| `cuckooset` | AnsiString keys |
| `deque_lf` | AnsiString values（且为 lock-based） |
| `intervaltree` | optional AnsiString `Id` |
| `lru_cache` | AnsiString key/value |
| `merkle_tree` | AnsiString leaf data |
| `persistent_vector` | AnsiString items |
| `radix` | AnsiString keys |
| `rope` | AnsiString text |
| `skiplist_map` | AnsiString key/value |
| `snapshot` | AnsiString key/value |
| `suffixarray` | AnsiString text |
| `timeseries_ringbuffer` | AnsiString values |
| `trie_hmt` | AnsiString key/value |
| `trie_map` | AnsiString key/value |
| `ttl_cache` | AnsiString key/value |

> 注：hash-only sketch（`counting_bloom` / `countminsketch` / `hyperloglog`）仅用 AnsiString 作瞬时哈希输入，不存储 managed 元素，归为 n/a 而非 exception。

## 1. 接口契约

### 1.1 子模块（完整源树；默认门面仅 T1）

| 类别 | 文件 | 职责 |
|------|------|------|
| **基础** | lockfree.base | TCacheLinePad, TLockFreeTryError, LockFreeNextPow2, LockFreePrefetch |
| **基础** | lockfree.wait | LockFreeWaitData/Space, LockFreeNotifyData/Space |
| **内存回收** | lockfree.ebr | 基于 Epoch 的内存回收 (EBR) |
| **内存回收** | lockfree.hazard | Hazard Pointer 内存回收 |
| **内存回收** | lockfree.rcu | Read-Copy-Update |
| **队列** | lockfree.spsc | 单生产者单消费者队列 |
| **队列** | lockfree.mpmc | 多生产者多消费者队列 |
| **队列** | lockfree.mpsc | 多生产者单消费者队列 |
| **队列** | lockfree.spmc | 单生产者多消费者队列 |
| **队列** | lockfree.segqueue | 分段无锁队列（无界 MPMC） |
| **队列** | lockfree.msqueue | Michael-Scott 无锁队列 |
| **队列** | lockfree.ringbuffer | 环形缓冲区 |
| **队列** | lockfree.timeoutqueue | 带超时的队列 |
| **栈** | lockfree.stack | 无锁栈 |
| **栈** | lockfree.elimination_stack | 消除回退栈 |
| **双端队列** | lockfree.deque | 工作窃取双端队列（有 Close） |
| **双端队列** | lockfree.deque_lf | **lock-based** 双端队列（名称例外） |
| **通道** | lockfree.channel | 有界 MPMC-style 无锁通道 |
| **通道** | lockfree.channel.spsc | SPSC 通道 |
| **映射** | lockfree.hashmap | 分片 HashMap（`TConcurrentHashMap` 同实现别名） |
| **映射 / 其他** | lockfree.* | T2/T3：trees、caches、filters、sync primitives 等（直接 import） |
| **门面** | lockfree.pas | **T1-only** 门面 re-export |

完整单元清单以 `core/src/nextpas.core.lockfree*.pas` 为准；上表不再宣称“187 个类型 re-export”。

### 1.2 核心类型（T1 实际门面类型）

```pascal
// 队列（T1）
generic TSpscQueue<T> = class
  function TryEnqueue(const AValue: T): Boolean;
  function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  function EnqueueWait(const AValue: T): Boolean;
  function DequeueWait(out AValue: T): Boolean;
  procedure Close;
end;

generic TMpmcQueue<T> = class
  function TryEnqueue(const AValue: T): Boolean;
  function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  procedure Close;
end;

generic TMpscQueue<T> = class
  procedure Enqueue(const AValue: T);          // closed -> EInvalidOperationError
  function TryEnqueue(const AValue: T): Boolean; // closed -> False
  function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  procedure Close;
end;

generic TSpmcQueue<T> = class
  function TryEnqueue(const AValue: T): Boolean;
  function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  procedure Close;
end;

generic TSegQueue<T> = class
  procedure Enqueue(const AValue: T);          // closed -> EInvalidOperationError
  function TryEnqueue(const AValue: T): Boolean; // closed -> False
  function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  procedure Close;
end;

generic TLockFreeMsQueue<T> = class
  function TryEnqueue(const AValue: T): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  procedure Close;
end;

// 栈 / 工作窃取（T1）— 非阻塞 surface 使用 Try*
generic TLockFreeStack<T> = class
  function TryPush(const AValue: T): Boolean;
  function TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryPop(out AValue: T): Boolean;
  function TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  procedure Close;
end;

generic TWorkStealingDeque<T> = class
  function TryPush(const AValue: T): Boolean;
  function TryPop(out AValue: T): Boolean;
  function TrySteal(out AValue: T): Boolean;
  procedure Close;
end;

// 映射（T1）— TConcurrentHashMap 是同一实现的别名
generic TShardedHashMap<TKey, TValue> = class
  function Insert(const AKey: TKey; const AValue: TValue): Boolean;
  function Find(const AKey: TKey; out AValue: TValue): Boolean;
  function Remove(const AKey: TKey): Boolean;
end;
generic TConcurrentHashMap<TKey, TValue> = class(specialize TShardedHashMapImpl<TKey, TValue>);

// Channel / Selector / reclamation — 见 api-reference 与 README
```

### 1.3 ClosedPublishPolicy

| API 形态 | Close 后 publish 行为 |
|----------|------------------------|
| `TryEnqueue` / `TryPush` / `TrySend` | 返回 **False**（不抛异常） |
| plain `Enqueue` / `Send`（阻塞式或无界 publish） | 抛 **`EInvalidOperationError`** |
| `*Wait` / `*Timeout` publish | 返回 **False**（立即失败，不无限阻塞） |
| consume / drain | 仍可读已入队数据；closed+empty 时返回 False |

具体对齐：
- **SegQueue**：`Close` 后 `TryEnqueue=False`，plain `Enqueue` 抛 `EInvalidOperationError`；已入队仍可 `TryDequeue`。`Destroy` 会先 **`Close`**（拒绝新 publish）再释放 EBR/segment；调用方仍须 join 活跃 producer/consumer。`Close → join → Free` 是安全生命周期；Destroy 的 Close **不替代** join。
- **MPSC**：同 SegQueue publish 策略；生命周期 **Close → join producers/waiters → Free**。
- **MSQueue**：`Destroy` 执行 **Close + drain**；调用方仍须 join 活跃 producer/consumer。`Close → join → Free` 是安全生命周期；Destroy 的 Close+drain **不替代** join。
- **Channel**：`Send` closed 抛异常；`TrySend` 返回 False。

### 1.4 Diagnostic Try*Ex（可选）

Boolean 热路径 `TrySend` / `TryEnqueue` / `TryPush` / `TryReceive` / `TryDequeue` / `TryPop` **保持不变**。
需要区分 full / empty / closed 时使用可选诊断 API：

**已覆盖结构（R3+R4）**：
| 结构 | Publish Ex | Consume Ex |
|------|------------|------------|
| Channel | `TrySendEx` | `TryReceiveEx` |
| Channel SPSC | `TrySendEx` | `TryReceiveEx` |
| SegQueue | `TryEnqueueEx` | `TryDequeueEx` |
| SPSC ring | `TryEnqueueEx` | `TryDequeueEx` |
| MPMC ring | `TryEnqueueEx` | `TryDequeueEx` |
| SPMC ring | `TryEnqueueEx` | `TryDequeueEx` |
| MPSC（无界） | `TryEnqueueEx` | `TryDequeueEx` |
| Stack（有界） | `TryPushEx` | `TryPopEx` |

```pascal
type
  TLockFreeTryError = (lfteNone, lfteFull, lfteEmpty, lfteClosed);
```

| 结果 | Result | AError |
|------|--------|--------|
| 成功 | True | `lfteNone` |
| 有界满（未 closed） | False | `lfteFull` |
| 空（未 closed） | False | `lfteEmpty` |
| closed 后 publish | False | `lfteClosed` |
| closed 且 empty consume | False | `lfteClosed` |

实现为现有 `Try*` + `IsClosed` 的薄包装，不替代 Boolean API。
`plain Enqueue` / `Send` 在 closed 时仍抛 `EInvalidOperationError`。
无界结构（SegQueue / MPSC）：`TryEnqueueEx` 失败在正常路径上即为 `lfteClosed`（不会出现 `lfteFull`）。

---

## 2. 不变量

- EBR 保护期内的节点不被回收
- 无锁栈 TryPush/TryPop 满足 LIFO 顺序
- 工作窃取双端队列：Owner 从尾部 TryPop，Thief 从头部 TrySteal；**有 Close**
- SPSC 队列：单生产者单消费者，无锁
- MPMC 队列：多生产者多消费者，无锁
- SegQueue：无界 **MPMC**（不是 MPSC）
- 分片 HashMap：每个分片独立锁，减少竞争；`TConcurrentHashMap` 与其同实现
- 所有 T1 泛型容器要求 T（及 HashMap 的 TKey/TValue）为非托管类型；构造时 `IsManagedType` 拒绝
- T2 泛型容器同样应在构造时 `IsManagedType` 拒绝（AnsiString 特化单元除外）
- MPSC / SegQueue：`Close` 后 `TryEnqueue` 返回 False，`Enqueue` 抛 `EInvalidOperationError`
- 生命周期：Close → join producers/waiters → Free；Destroy 的 Close+drain 不替代 join

### 2.1 FPC RTL isolation

**生产单元** `nextpas.core.atomic*` / `nextpas.core.lockfree*` 与 `core/examples/lockfree_example.lpr` 不得直接 `uses` 下列 FPC RTL：

`SysUtils` / `Classes` / `Math` / `Windows` / `BaseUnix` / `Unix` / `TypInfo` / `StrUtils` / `DateUtils` / `SyncObjs` / `Contnrs`

- 异常走 `nextpas.core.errors`
- 数学走 `nextpas.core.math`
- 文本转换走 `nextpas.core.text.conv`
- 时间/休眠走 `nextpas.core.time` / `nextpas.core.platform`（`platform_monotonic_ns`、`platform_thread_sleep_ms` 等）

**测试同样适用**（`core/tests/nextpas.core.atomic/**` 与 `core/tests/nextpas.core.lockfree/**` 的 `.lpr`）：
- 不得直接 `uses` 上述 banned RTL
- 需要 `IntToStr`/`Format` 时 `uses nextpas.core.text.conv`
- 需要 `TStringList`/`TFileStream` 等时经 `nextpas.core.system.classes` / `nextpas.core.fs`，不得直接 `uses Classes`
- source-contract（`TestFpcRtlIsolationSourceContract`）覆盖全部生产 `atomic*`/`lockfree*` 单元 + example；并对主测试入口做 isolation 断言

---

## 3. 错误处理

- `TryPop`/`TrySteal` 空时返回 False
- managed 元素构造抛 `EArgumentError`
- 已关闭后的 plain publish（Channel.Send / MPSC.Enqueue / SegQueue.Enqueue）抛 `EInvalidOperationError`

---

## 4. 线程安全

- T1 队列/栈/channel 热路径使用 CAS/原子指令
- `TShardedHashMap` / `TConcurrentHashMap` 为分片自旋锁（非 lock-free）
- EBR 使用 TLS 线程本地状态
- `deque_lf` 为 lock-based，尽管单元名含 “lf”

---

## 5. 内存管理

- EBR 管理延迟回收，避免 ABA 问题
- Hazard Pointer 提供精确内存回收
- MSQueue Destroy：Close + drain 内部节点/值
- SegQueue Destroy：Close 拒绝新 publish，再释放 EBR 与 segment；调用方仍须 join 后 Free

---

## 6. 测试覆盖

| 测试入口 | 说明 | 规模（约） |
|----------|------|------------|
| `test_lockfree` | T1 + source-contract + isolation | **~166** tests |
| `test_lockfree_stress` | 多线程 stress | focused gate |
| `test_lockfree_*` | 子模块独立套件 | 90+ suites |
| `test_atomic` | 原子操作/内存序/CAS/wait/notify | **~45** tests |

入口：
```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
make -C core/tests/nextpas.core.atomic/test_atomic clean test
```
