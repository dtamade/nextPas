# nextpas.core.lockfree 代码契约

**模块路径**：`core/src/nextpas.core.lockfree*.pas`（103 个源文件）
**层级**：L1（依赖 L0: base, atomic；与 `core/docs/core-module-registry.md` 一致）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-17
**版本**：2.1

---

## 0. 默认门面（T1）

`uses nextpas.core.lockfree` 仅 re-export **T1 runtime core**：
SPSC/MPMC/MPSC/SPMC/SegQueue/MSQueue、Stack、WorkStealingDeque、EBR/Hazard、Channel、Selector、ShardedHashMap（及 `TConcurrentHashMap` 别名）。

T2/T3 子模块源文件仍保留在 `core/src/`，但**必须直接** `uses nextpas.core.lockfree.<unit>`，不会被默认门面拉入。

进度保证（lock-free vs lock-based）见 `README.md` 的 Progress-guarantee matrix；`TShardedHashMap` 为分片自旋锁，**不是** lock-free。

## 1. 接口契约

### 1.1 子模块（103 个源文件；默认门面仅 T1）

| 类别 | 文件 | 职责 |
|------|------|------|
| **基础** | lockfree.base | TCacheLinePad, LockFreeNextPow2, LockFreePrefetch |
| **基础** | lockfree.wait | LockFreeWaitData/Space, LockFreeNotifyData/Space |
| **内存回收** | lockfree.ebr | 基于 Epoch 的内存回收 (EBR) |
| **内存回收** | lockfree.hazard | Hazard Pointer 内存回收 |
| **内存回收** | lockfree.rcu | Read-Copy-Update |
| **队列** | lockfree.spsc | 单生产者单消费者队列 |
| **队列** | lockfree.mpmc | 多生产者多消费者队列 |
| **队列** | lockfree.mpsc | 多生产者单消费者队列 |
| **队列** | lockfree.spmc | 单生产者多消费者队列 |
| **队列** | lockfree.segqueue | 分段无锁队列 |
| **队列** | lockfree.msqueue | Michael-Scott 无锁队列 |
| **队列** | lockfree.ringbuffer | 环形缓冲区 |
| **队列** | lockfree.timeoutqueue | 带超时的队列 |
| **栈** | lockfree.stack | 无锁栈 |
| **栈** | lockfree.elimination_stack | 消除回退栈 |
| **双端队列** | lockfree.deque | 工作窃取双端队列 |
| **双端队列** | lockfree.deque_lf | 无锁双端队列 |
| **通道** | lockfree.channel | 无锁通道 |
| **通道** | lockfree.channel.spsc | SPSC 通道 |
| **映射** | lockfree.hashmap | 分片 HashMap |
| **映射** | lockfree.hashset | 并发 HashSet |
| **映射** | lockfree.hashtable | 无锁哈希表 |
| **映射** | lockfree.multimap | 并发 MultiMap |
| **映射** | lockfree.trie | 并发 Trie |
| **映射** | lockfree.trie_map | 并发 Trie Map |
| **映射** | lockfree.trie_hmt | Hash Mapped Trie |
| **映射** | lockfree.skiplist_map | 并发跳表 Map |
| **映射** | lockfree.robinhood | Robin Hood 哈希表 |
| **有序结构** | lockfree.skiplist | 并发跳表 |
| **有序结构** | lockfree.btree | 并发 B-Tree |
| **有序结构** | lockfree.bplus | B+ Tree |
| **有序结构** | lockfree.rbtree | 并发红黑树 |
| **有序结构** | lockfree.treap | 并发 Treap |
| **有序结构** | lockfree.scapegoat | Scapegoat Tree |
| **有序结构** | lockfree.radix | Radix Tree |
| **有序结构** | lockfree.sortedset | 并发有序集合 |
| **图** | lockfree.graph | 并发图 |
| **图** | lockfree.dag | 并发 DAG |
| **图** | lockfree.adjmap | 加权图邻接表 |
| **图** | lockfree.disjointset | 并查集 |
| **图** | lockfree.merkle_tree | Merkle Tree |
| **树** | lockfree.fibheap | Fibonacci 堆 |
| **树** | lockfree.fenwick | Fenwick Tree |
| **树** | lockfree.intervaltree | 区间树 |
| **树** | lockfree.persistent_vector | 持久化向量 |
| **同步原语** | lockfree.mutex | 并发互斥锁 |
| **同步原语** | lockfree.rwlock | 并发读写锁 |
| **同步原语** | lockfree.semaphore | 并发信号量 |
| **同步原语** | lockfree.barrier | 并发屏障 |
| **同步原语** | lockfree.condvar | 并发条件变量 |
| **同步原语** | lockfree.countdown | 倒计时闩 |
| **同步原语** | lockfree.phaser | 相位同步器 |
| **同步原语** | lockfree.stampedlock | 戳锁 |
| **同步原语** | lockfree.exchanger | 并发交换器 |
| **同步原语** | lockfree.flatcombining | Flat Combining |
| **同步原语** | lockfree.leftright | Left-Right 并发控制 |
| **缓存** | lockfree.lru | 并发 LRU 缓存 |
| **缓存** | lockfree.lru_cache | 并发 LRU 缓存 (AnsiString) |
| **缓存** | lockfree.lfu | LFU 缓存 |
| **缓存** | lockfree.ttl_cache | TTL 缓存 |
| **缓存** | lockfree.arccache | ARC Cache |
| **概率** | lockfree.bloom | 布隆过滤器 |
| **概率** | lockfree.counting_bloom | 计数布隆过滤器 |
| **概率** | lockfree.scalable_bloom | 可扩容布隆过滤器 |
| **概率** | lockfree.cuckooset | Cuckoo 集合 |
| **概率** | lockfree.hyperloglog | HyperLogLog |
| **概率** | lockfree.countminsketch | Count-Min Sketch |
| **概率** | lockfree.xorfilter | XOR Filter |
| **流式** | lockfree.tdigest | T-Digest 分位数 |
| **流式** | lockfree.spacesaving | Space-Saving Top-K |
| **流式** | lockfree.misragries | Misra-Gries 频繁项 |
| **流式** | lockfree.reservoirsampling | 蓄水池采样 |
| **限流** | lockfree.ratelimit | 令牌桶限流器 |
| **限流** | lockfree.leakybucket | 漏桶限流器 |
| **限流** | lockfree.slidingwindow | 滑动窗口限流器 |
| **并发模型** | lockfree.actor | Actor 模型 |
| **并发模型** | lockfree.forkjoin | ForkJoin 框架 |
| **并发模型** | lockfree.workstealing | 工作窃取线程池 |
| **并发模型** | lockfree.selector | 多路复用器 |
| **并发模型** | lockfree.selector.impl | 多路复用器实现 |
| **其他** | lockfree.counter | 并发计数器 |
| **其他** | lockfree.bag | 并发 Bag |
| **其他** | lockfree.bitset | 并发位集合 |
| **其他** | lockfree.linkedlist | 并发有序链表 |
| **其他** | lockfree.unrolled_list | 非滚动链表 |
| **其他** | lockfree.cowarray | 写时复制数组 |
| **其他** | lockfree.snapshot | 快照隔离 |
| **其他** | lockfree.statscounter | 统计计数器 |
| **其他** | lockfree.consistent_hashring | 一致性哈希环 |
| **其他** | lockfree.suffixarray | 后缀数组 |
| **其他** | lockfree.roaring_bitmap | Roaring Bitmap |
| **其他** | lockfree.timeseries_ringbuffer | 时间序列环形缓冲区 |
| **其他** | lockfree.crdt | CRDT |
| **其他** | lockfree.rope | Rope 大字符串 |
| **其他** | lockfree.versionvector | Version Vector |
| **其他** | lockfree.wrr | 加权轮询 |
| **其他** | lockfree.matrix | 并发矩阵 |
| **扩展** | lockfree.hashmap.rtm | RTM 优化 HashMap (硬件事务内存) |
| **扩展** | lockfree.hashmap.numa | NUMA 感知 HashMap |
| **门面** | lockfree.pas | 门面 re-export |

### 1.2 核心类型（187 个类型 re-export）

```pascal
// 队列
generic TSpscQueue<T> = class
  function TryEnqueue(const AValue: T): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function EnqueueWait(const AValue: T): Boolean;
  function DequeueWait(out AValue: T): Boolean;
end;

generic TMpmcQueue<T> = class
  function TryEnqueue(const AValue: T): Boolean;
  function TryDequeue(out AValue: T): Boolean;
end;

// 栈
generic TLockFreeStack<T> = class
  procedure Push(const AValue: T);
  function TryPop(out AValue: T): Boolean;
end;

// 工作窃取
generic TWorkStealingDeque<T> = class
  procedure Push(const AValue: T);
  function TryPop(out AValue: T): Boolean;
  function TrySteal(out AValue: T): Boolean;
end;

// 映射
generic TShardedHashMap<TKey, TValue> = class
  function Insert(const AKey: TKey; const AValue: TValue): Boolean;
  function Find(const AKey: TKey; out AValue: TValue): Boolean;
  function Remove(const AKey: TKey): Boolean;
end;

// 同步原语
TConcurrentMutex = class
  procedure Lock;
  procedure Unlock;
  function TryLock: Boolean;
end;

TConcurrentRwLock = class
  procedure ReadLock;
  procedure WriteLock;
  procedure Unlock;
end;
```

---

## 2. 不变量

- EBR 保护期内的节点不被回收
- 无锁栈 Push/Pop 满足 LIFO 顺序
- 工作窃取双端队列：Owner 从尾部 Pop，Thief 从头部 Steal
- SPSC 队列：单生产者单消费者，无锁
- MPMC 队列：多生产者多消费者，无锁
- 分片 HashMap：每个分片独立锁，减少竞争
- 所有 T1 泛型容器要求 T（及 HashMap 的 TKey/TValue）为非托管类型；构造时 `IsManagedType` 拒绝
- MPSC：`Close` 后 `TryEnqueue` 返回 False，`Enqueue` 抛 `EInvalidOperationError`
- 生命周期：Close → join producers/waiters → Free；Destroy 的 Close+drain 不替代 join

### 2.1 FPC RTL isolation

- 生产单元 `nextpas.core.atomic*` / `nextpas.core.lockfree*` 与 `core/examples/lockfree_example.lpr` 不得直接 `uses` FPC RTL（`SysUtils`/`Classes`/`Math`/`Windows`/`BaseUnix`/`Unix`）
- 异常走 `nextpas.core.errors`；数学走 `nextpas.core.math`

---

## 3. 错误处理

- `TryPop`/`TrySteal` 空时返回 False
- managed 元素构造抛 `EArgumentError`
- 已关闭后的阻塞式 publish（Channel.Send / MPSC.Enqueue）抛 `EInvalidOperationError`

---

## 4. 线程安全

- T1 队列/栈/channel 热路径使用 CAS/原子指令
- `TShardedHashMap` 为分片自旋锁（非 lock-free）
- EBR 使用 TLS 线程本地状态

---

## 5. 内存管理

- EBR 管理延迟回收，避免 ABA 问题
- Hazard Pointer 提供精确内存回收

---

## 6. 测试覆盖

- `test_lockfree`: 137 测试 - Stack/SegQueue/Deque/Channel/HashMap/MPMC/MPSC/EBR/Hazard/Selector
- `test_lockfree_*`: 90+ 独立测试套件，覆盖所有子模块
- `test_atomic`: 45 测试 - 原子操作/内存序/CAS/wait/notify
