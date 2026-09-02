# nextpas.core.lockfree 代码契约

**模块路径**：`core/src/nextpas.core.lockfree*.pas`（约 100+ 源文件；默认门面仅 T1）
**层级**：L1（依赖 L0: base, atomic；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：2.10

**Audit follow-ups（2026-07-26）**：见 [`findings.md`](findings.md)。要点：T2 freeze（F-004）；`-dLOCKFREE_DEBUG` owner 检查（F-005）；`verify-t2-smoke` + 测试 RTL isolation（F-001/F-006）。

---

## 0. 默认门面（T1）

`uses nextpas.core.lockfree` 仅 re-export **T1 runtime core**：
SPSC/MPMC/MPSC/SPMC/SegQueue/MSQueue、Stack、WorkStealingDeque、EBR/Hazard、Channel、Selector、ShardedHashMap（及 `TConcurrentHashMap` 别名）。

T2/T3 子模块源文件仍保留在 `core/src/`，但**必须直接** `uses nextpas.core.lockfree.<unit>`，不会被默认门面拉入。

进度保证（lock-free vs lock-based）见 `README.md` 的 Progress-guarantee matrix；`TShardedHashMap` / `TConcurrentHashMap` 为同一分片自旋锁实现（别名，不是两套实现）。

**命名例外 / T2 命名诚实（R7 扩充）**：

| 单元 / 名称 | 看起来像 | 实际 progress | 备注 |
|-------------|---------|---------------|------|
| `lockfree.deque_lf` / **`TLockFreeDeque`** | lock-free deque | **spin-lock** concurrent deque | **Phase D**：实现在 `lockfree.deque_spin` / **`TConcurrentSpinDeque`**；`deque_lf`+`TLockFreeDeque` 为历史 alias；真 LF deque → `lockfree.deque` / `TWorkStealingDeque` |
| `TShardedHashMap` / `TConcurrentHashMap` | 可能被当成 lock-free map | **per-shard spin lock** | T1 门面诚实别名，同一实现 |
| `lockfree.hashtable` / **`TLockFreeHashTable*`** | lock-free table | **LF 读路径 + writer spinlock / grow** | 名字偏 LF；写路径有锁 |
| `lockfree.dag` / `graph` / `adjmap` | 无锁图 | **per-node / per-vertex locks** | 头注释已写 NOT lock-free |
| `lockfree.skiplist*` / `btree`/`rbtree`/`treap`/`scapegoat`/`bplus`/`radix`/`trie*` | 在 `lockfree.*` 命名空间 | **锁或 RW 锁** | **不进**默认门面；直接 import |
| `lockfree.lru` / `lru_cache` / `ttl_cache` / `arccache` / `lfu` | 无锁缓存 | **分片锁 / 自旋锁** | `lru_cache` 另属 AnsiString 例外 |
| `lockfree.mutex` / `rwlock` / `semaphore` / `stampedlock` / `condvar` / `phaser` | 无锁同步原语 | **锁或 CAS 自旋** | concurrent helper，非 container LF 声明 |
| `lockfree.cuckooset` / `hashset` / `robinhood` | 无锁 set/map | **锁序列化** | 见 unit 头 |
| `lockfree.hashmap.rtm` / `hashmap.numa` | 生产默认 | **T3 研究扩展** | 直接 import；不进 T1 门面 |
| `collections.concurrent.hashmap.TConcurrentHashMap` | 与 lockfree 同名 | **另一套实现** | 勿与 lockfree 门面别名混淆 |

**规则**：单元落在 `lockfree.*` 或类型名含 `LockFree` / `Concurrent` **≠** progress 为 lock-free。以本表 + README Progress matrix + 单元 `@concurrency` / 头注释为准。

- 部分 AnsiString 特化单元允许 managed `AnsiString` 载荷；不要求 `IsManagedType` 泛型守卫（表见 §0.1）。
- Progress 总表以 [`README.md`](README.md) Progress-guarantee matrix 为准；冲突时以 **CONTRACT + README** 覆盖单元头注释中的“无锁”口语。

消费者审计：[`consumer-audit.md`](consumer-audit.md)。

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

### 0.2 T2 maturity tiers（H2-2）

**权威可扫清单**（单元 → 档位 → progress → 测试）：[`t2-inventory.md`](t2-inventory.md)（Q4）。
下表为摘要；与 inventory 冲突时以 inventory + 本文件 §0.3 为准。

默认门面 **不** 升 T2。T2 直接 import 时用下列成熟度档位（文档分档，**不**重写算法）：

| 档位 | 含义 | 消费者期望 |
|------|------|------------|
| **Available** | 有测试套件；API 稳定可用；progress 多为 lock-based | 可生产使用，须读单元 progress 与 managed 例外 |
| **Guarded** | Available + 有 managed 守卫或 AnsiString 例外表；生命周期/关闭语义文档化 | 生产可用但需遵守 Close/守卫约束 |
| **Experimental** | 研究/局部覆盖；命名或算法可能变 | 仅 opt-in；不进默认门面 |

**分档示例（非穷尽；以单元文档 + 测试存在为准）**：

| 档位 | 示例单元 / 类型 |
|------|-----------------|
| **Guarded** | `bag`, `multimap`, `ringbuffer`, `timeoutqueue`, `workstealing`（`TWorkStealingPool`）, `priority_queue`, 多数 `*cache` / `bloom` / `counter` / sync helpers |
| **Available** | `skiplist*`, `btree`/`rbtree`/`treap`/`bplus`/`scapegoat`, `graph`/`dag`, `crdt`, sketch 类（HLL/CMS…）, `deque_lf`（spin-lock + AnsiString） |
| **Experimental** | `hashmap.rtm`, `hashmap.numa`, RTM/NUMA 扩展，formal-only 路径 |

T1 成熟度不在本表：T1 为 **Ready-for-consumer**（见 READY）。T3 = Experimental 的子集（研究扩展）。

**R8 研究 pack（opt-in close-out）**：诚实状态见 [`r8-research-status.md`](r8-research-status.md)；形式化入口 [`formal/README.md`](formal/README.md)。
R8 轴 **不** 因文档收口而升入 T1 / 默认门面；生产化属重大变更。

**不做（H2-2）**：把任一 T2 档升入默认门面；统一重写 T2 算法；改变 Closed 语义。

### 0.3 H3-2 — T2 Guarded 生产契约子集（bag + multimap）

**授权状态**：H3-2（用户/总控显式授权）。**不**将 T2 升入默认 `uses nextpas.core.lockfree` 门面。
**范围**：仅下列 2 个 Guarded 类型获得**统一生产向** Close / managed / progress 契约；其余 T2 仍按 §0.2 分档与各单元文档。

| 类型 | 单元 | Import | 默认门面 |
|------|------|--------|----------|
| `TLockFreeBag<T>` / `TLockFreeBagImpl<T>` | `nextpas.core.lockfree.bag` | **直接** `uses` | **否** |
| `TLockFreeMultiMap<TKey,TValue>` / `…Impl` | `nextpas.core.lockfree.multimap` | **直接** `uses` | **否** |

#### Progress（诚实）

| 类型 | Progress | 说明 |
|------|----------|------|
| **Bag** | **lock-free ring（MPMC 序列号槽）** + wait-address 阻塞路径 | `TryAdd`/`TryTake` 热路径为 CAS/序列号；`AddWait`/`TakeWait` 可阻塞。**不是**“集合语义上的完全无锁算法重写”，是有界 ring bag。 |
| **MultiMap** | **lock-based concurrent**（**单 map 自旋锁** `FLock`） | 所有突变与多数读在锁内。**不是**分片锁、**不是** lock-free map。名称在 `lockfree.*` 仅表示并发容器命名空间。 |

#### Managed 元素

| 类型 | 规则 |
|------|------|
| **Bag** | `Create`：`IsManagedType(T)` → `EArgumentError`。T 必须 unmanaged。 |
| **MultiMap** | `Create`：`IsManagedType(TKey)` 或 `IsManagedType(TValue)` → `EArgumentError`。键值均须 unmanaged。 |
| **例外** | 二者**不**在 §0.1 AnsiString 例外表；禁止用 AnsiString 特化绕过。 |

#### Close / 生命周期

| 类型 | Close 后行为 | 生命周期 |
|------|----------------|----------|
| **Bag** | `IsClosed`；`TryAdd` → `arClosed`；已入队元素仍可 `TryTake`/`TakeWait`（空且 closed 时 take 失败）；`Close` 唤醒 data/space waiters；`Destroy` **先** `Close` | 生产推荐：`Close` → drain（按需）→ join producers/consumers → `Free` |
| **MultiMap** | `IsClosed`；`Add` → `mmClosed`；**已有**键值仍可 `Find`/`Contains`/`Remove*`（读/删不因 Close 单独禁止）；`Clear` 在 Close 后仍清空已有数据（调用方须知）；`Destroy` **先** `Close` 再释放桶 | 生产推荐：`Close` → 停止新写入方 → 读完/清理 → `Free` |

**Closed 语义边界（H3-2 不改动）**：

- 不改变 T1 Channel/SegQueue 等 ClosedPublishPolicy（§1.3）。
- Bag/MultiMap 的 closed 返回值（`arClosed` / `mmClosed`）保持现有枚举语义；H3-2 **不**改为抛异常。

#### 测试与门禁

| 证据 | 路径 |
|------|------|
| Bag 行为 + Close + source-contract | `core/tests/nextpas.core.lockfree/test_lockfree_bag` |
| MultiMap 行为 + Close + source-contract | `core/tests/nextpas.core.lockfree/test_lockfree_multimap` |
| 门面不含 bag/multimap | `nextpas.core.lockfree.pas` 无 re-export（source-contract 钉住） |

**H3-2 非目标**：全量 T2 契约化；T2 进默认门面；算法重写；R8 生产化；删 legacy CAS。

**Q4（2026-07-20）**：明确 **不** 扩展 H3-2 生产子集。若未来扩展，须单独 charter（Close/managed/progress + focused tests + 门面隔离 + 批准）。见 [`t2-inventory.md`](t2-inventory.md)。

---

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
  function TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
  function TryPop(out AValue: T): Boolean;
  function TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  function TrySteal(out AValue: T): Boolean;
  function TryStealEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
  procedure Close;
end;

// 映射（T1）— TConcurrentHashMap 是同一实现的别名
generic TShardedHashMap<TKey, TValue> = class
  function Insert(const AKey: TKey; const AValue: TValue): Boolean;
  function Find(const AKey: TKey; out AValue: TValue): Boolean;
  function Remove(const AKey: TKey): Boolean;
end;
generic TConcurrentHashMap<TKey, TValue> = class(specialize TShardedHashMapImpl<TKey, TValue>);

// Channel / reclamation — 见 api-reference 与 README
```

### 1.2a Selector（Q3-a）

`TLockFreeSelector<T>`（门面）/ `TLockFreeSelectorImpl<T>`：

| 约束 | 语义 |
|------|------|
| 同类型 T | 所有 case 的 channel 元素类型必须相同 |
| `TrySelect` | **Go `select { default: }` 等价**；无就绪 → `Completed=False` |
| 多就绪次序 | 按 **Add 注册序** 选最早 case（**非** Go 随机） |
| 等待 | 短 spin 后 `LockFreeWaitData`（`lockfree.wait`） |
| closed-empty recv | 与 channel `TryReceive=False` 对齐；不伪完成 |
| 并发 | **同一 selector 实例** 上不支持并发 `Select*` |

权威 API 文本：[`api-reference.md`](api-reference.md) Selector 节。

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

**已覆盖结构（R3+R4+H2-1）**：
| 结构 | Publish Ex | Consume Ex |
|------|------------|------------|
| Channel | `TrySendEx` | `TryReceiveEx` |
| Channel SPSC | `TrySendEx` | `TryReceiveEx` |
| SegQueue | `TryEnqueueEx` | `TryDequeueEx` |
| SPSC ring | `TryEnqueueEx` | `TryDequeueEx` |
| MPMC ring | `TryEnqueueEx` | `TryDequeueEx` |
| SPMC ring | `TryEnqueueEx` | `TryDequeueEx` |
| MPSC（无界） | `TryEnqueueEx` | `TryDequeueEx` |
| MSQueue（无界） | `TryEnqueueEx` | `TryDequeueEx` |
| Stack（有界） | `TryPushEx` | `TryPopEx` |
| WorkStealingDeque（有界 T1） | `TryPushEx` | `TryPopEx` / `TryStealEx` |

**非 T1 Try\*Ex 目标**：`lockfree.deque_spin`（**`TConcurrentSpinDeque`**；历史 `deque_lf`/`TLockFreeDeque`）为 **spin-lock** + `TDequeResult`（`dqOk`/`dqEmpty`/`dqFull`），**无** `Close` / `TLockFreeTryError` 面；progress **非** lock-free / **非** wait-free。真 lock-free 双端队列用 `TWorkStealingDeque`。

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
无界结构（SegQueue / MPSC / MSQueue）：`TryEnqueueEx` 失败在正常路径上即为 `lfteClosed`（不会出现 `lfteFull`）。

### 1.5 Channel capacity=1（R5）

`TLockFreeChannel<T>` 接受请求容量 1（向上取整后仍为 1）。per-slot sequence 使用与 `TMpmcQueue` 相同的 empty/full 分离编码（`empty(pos)=pos*2`，`full(pos)=pos*2+1`），因此单槽 channel 下 `TrySend`/`TrySendEx` 与 `TryReceive`/`TryReceiveEx` 可区分 full 与 empty：

| 状态（未 closed） | Boolean | Try\*Ex `AError` |
|-------------------|---------|------------------|
| 空 | `TryReceive` False | `lfteEmpty` |
| 满 | `TrySend` False | `lfteFull` |
| 有空间 | `TrySend` True | `lfteNone` |
| 有数据 | `TryReceive` True | `lfteNone` |

`TLockFreeChannelSpsc` 用 count 路径，本就支持 cap=1；本条锁定 MPMC Channel 与队列对齐。

---

## 2. 不变量

- EBR 保护期内的节点不被回收
- 无锁栈 TryPush/TryPop 满足 LIFO 顺序
- 工作窃取双端队列：Owner 从尾部 TryPop，Thief 从头部 TrySteal；**有 Close**
- SPSC 队列：单生产者单消费者，无锁
- MPMC 队列：多生产者多消费者，无锁；capacity=1 时 empty/full sequence 可分
- Channel（MPMC）：同 MPMC empty/full sequence 编码；capacity=1 时 full/empty 可分
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

**测试 / 示例 / bench 同样适用**（`core/tests/nextpas.core.atomic/**`、`core/tests/nextpas.core.lockfree/**`、`core/examples/**lockfree**`、`core/benchmarks/nextpas.core.{atomic,lockfree}/**`）：
- 不得直接 `uses` 上述 banned RTL
- 需要 `IntToStr`/`Format` 时 `uses nextpas.core.text.conv`
- 需要 `TStringList`/`TFileStream` 等时经 `nextpas.core.system.classes` / `nextpas.core.fs`，不得直接 `uses Classes`
- 需要 `NaN`/`Infinity` 时 `uses nextpas.core.math.scalar`，不得 `uses Math`
- source-contract（`TestFpcRtlIsolationSourceContract`）覆盖生产 `atomic*`/`lockfree*` 单元 + example
- **回归脚本**：`core/tests/nextpas.core.lockfree/check_test_rtl_isolation.sh`（挂入 `verify-t1` / `verify-t2-smoke`）

---

## 3. 错误处理

- `TryPop`/`TrySteal` 空时返回 False
- managed 元素构造抛 `EArgumentError`
- 已关闭后的 plain publish（Channel.Send / MPSC.Enqueue / SegQueue.Enqueue）抛 `EInvalidOperationError`

### 3.1 managed 拒绝文案（推荐模板）

泛型 `Create` 在 `IsManagedType` 拒绝时，**推荐**统一为：

```text
'<TypeName>: T must be unmanaged'
```

Key/Value 双参数类型用：

```text
'<TypeName>: TKey must be unmanaged'
'<TypeName>: TValue must be unmanaged'
```

历史消息可能附带 `(no string/interface/dynarray)` 后缀；语义等价，**不强制全量改名**。新代码与触达修改优先用短模板。

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
| `test_lockfree` | T1 + source-contract + isolation | **~178** tests（H2-1 +Deque Try\*Ex） |
| `test_lockfree_stress` | 多线程 stress（含 H2-5 Channel Close-join-Free） | focused gate |
| `test_lockfree_*` | 子模块独立套件 | 90+ suites |
| `examples/.../t1_close_join_free` | H2-6 真实消费者证明 | manual / `make run` |

### 6.1 Formal / 已知限制（H2-5）+ R8 research status

诚实总览（NUMA / RTM / formal）：[`r8-research-status.md`](r8-research-status.md)。
如何跑 TLC / 无 TLC 时 model-only：[`formal/README.md`](formal/README.md)。
可选研究门：`make -C core/tests/nextpas.core.lockfree verify-r8`（**不**替代 `verify-t1`；**不**升 T1）。

| 模型 | 路径 | 覆盖 | 限制 |
|------|------|------|------|
| SPSC | `formal/tla/SpscQueue.tla` | 有界 SPSC 协议 | 研究证据；非 CI 默认门 |
| MPMC | `formal/tla/MpmcQueue.tla` | 有界 MPMC sequence | 同上 |
| Channel | `formal/tla/LockFreeChannel.tla` | channel 发送/接收 | 同上；cap=1 以 R5 测试为准 |
| Stack | `formal/tla/LockFreeStack.tla` | LIFO + Close 拒绝 publish | 同上；R8 加深；model-only 若无 TLC |

形式化模型加深 **不** 改变 T1 运行时契约。R8 research pack close-out **不** 晋升 T1。失败场景优先修 bug；无法修则记入本表。
| `test_atomic` | 原子操作/内存序/CAS/wait/notify | **~45** tests |

入口：
```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
make -C core/tests/nextpas.core.atomic/test_atomic clean test
```
