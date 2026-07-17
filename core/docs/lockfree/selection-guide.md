# Lockfree 数据结构选型指南

> 更新: 2026-07-17

[English](selection-guide.en.md)

> 相对性能以 `core/benchmarks/nextpas.core.lockfree` 为准；本指南**不**给无平台信封的绝对 Mops/s。

## 快速决策树

```
需要队列？
├── 单生产者 + 单消费者 (SPSC)
│   └── 使用 TSpscQueue<T>
│       - 通常最快（无 CAS 竞争）
│       - 支持 batch/wait/timeout/close
│
├── 单生产者 + 多消费者 (SPMC)
│   └── 使用 TSpmcQueue<T>
│       - 多消费者 CAS 竞争 dequeue
│       - 支持 wait/timeout/close
│
├── 多生产者 + 多消费者 (MPMC)
│   ├── 使用 TMpmcQueue<T> (有界 ring)
│   │   - 通用；batch/wait/timeout/close
│   │
│   ├── 使用 TLockFreeMsQueue<T> (无界节点池)
│   │   - Michael-Scott；Close → join → Free
│   │   - Destroy 会 Close+drain；仍须 quiescent Free
│   │
│   └── 使用 TSegQueue<T> (无界分段 MPMC)
│       - EBR 回收段；Close 后 Try=False，Enqueue raise
│
├── 多生产者 + 单消费者 (MPSC)
│   └── 使用 TMpscQueue<T>
│       - 无界链表；单消费者
│       - Close 后 TryEnqueue=False；Enqueue raise
│       - 生命周期: Close → join producers/waiters → Free
│
需要栈？
├── LIFO
│   └── 使用 TLockFreeStack<T>（仅 TryPush/TryPop）
│
└── 工作窃取
    └── 使用 TWorkStealingDeque<T>
        - owner TryPush/TryPop；thief TrySteal；有 Close

需要内存回收？
├── TEbrDomain / TQSBRDomain（zero-active QSBR 风格）
└── THazardDomain（Hazard Pointer）

需要并发 HashMap？
└── TShardedHashMap / TConcurrentHashMap（同一实现别名）
    - 分片自旋锁 — NOT lock-free

---

以下为 **T2（直接 `uses nextpas.core.lockfree.<unit>`，默认 facade 不拉入）**：
多数为 **lock-based concurrent** 或专用结构，名称中的 Concurrent/LockFree 以单元 `@concurrency` 与矩阵为准。

需要 Bag（允许重复元素的并发集合）？
└── `uses nextpas.core.lockfree.bag` → TLockFreeBag<T>
    - 基于 MPMC 队列，允许重复元素
    - FIFO 顺序
    - 阻塞/非阻塞/超时
    - 适用: 任务队列、工作池

需要 MultiMap（一个键多个值）？
└── `uses nextpas.core.lockfree.multimap` → TLockFreeMultiMap
    - **分片锁** HashMap 后端（lock-based concurrent）
    - 一个键可以有多个值
    - 适用于索引、标签系统

需要 Bloom Filter（快速成员检查）？
└── `uses nextpas.core.lockfree.bloom` → TConcurrentBloomFilter<T>
    - 概率数据结构，可能存在假阳性
    - 空间效率高
    - 适用于缓存、去重、快速成员检查

需要 LRU Cache（最近最少使用缓存）？
└── `uses nextpas.core.lockfree.lru` → TConcurrentLruCache
    - **分片锁** + 访问计数（lock-based concurrent）
    - 自动淘汰最久未访问的条目
    - 适用于缓存、淘汰场景

需要并发计数器？
└── `uses nextpas.core.lockfree.counter` → TConcurrentCounter
    - 原子操作
    - Increment/Decrement/Add/Sub/Load/Store
    - 适用于统计、计数

需要信号量（资源池限流）？
└── `uses nextpas.core.lockfree.semaphore` → TConcurrentSemaphore
    - 原子 CAS 自旋/等待（非容器 lock-free 声明）
    - TryAcquire/Acquire/AcquireTimeout/Release
    - 适用于资源池、限流

需要互斥锁？
└── `uses nextpas.core.lockfree.mutex` → TConcurrentMutex
    - 原子 CAS 互斥（lock-based）
    - TryLock/Lock/LockTimeout/Unlock
    - 适用于互斥访问；长期边界见 sync 模块（ownership 迁移未在本 lane 执行）

需要读写锁？
└── `uses nextpas.core.lockfree.rwlock` → TConcurrentRwLock
    - 单 Int32 状态编码 (0/-1/>0)（lock-based）
    - 多读者并发，写者独占
    - 适用于读多写少场景

需要倒计时闩（WaitGroup）？
└── 使用 TCountDownLatch
    - 初始计数 N，Done 减 1
    - Wait 阻塞直到计数归零
    - 适用于等待一组任务完成

需要循环屏障（Barrier）？
└── 使用 TCyclicBarrier
    - N 个线程在屏障点同步
    - 可重复使用
    - 适用于分阶段并行计算

需要限流器（Rate Limiter）？
└── 使用 TTokenBucketLimiter
    - 令牌桶算法
    - 恒定速率生成令牌
    - 适用于 API 限流、请求整形

需要条件变量？
└── 使用 TConditionVariable
    - 配合 TConcurrentMutex 使用
    - Signal 唤醒一个，Broadcast 唤醒所有
    - 适用于生产者-消费者、条件同步

需要两个线程交换值？
└── 使用 TExchanger<T>
    - 两个线程 Exchange() 交换各自的值
    - 阻塞/超时两种等待模式
    - 适用于双线程管道、一对一通信

需要灵活的同步屏障（支持动态注册）？
└── 使用 TPhaser
    - 支持动态 Register/Deregister
    - 多相位连续同步
    - 比 CyclicBarrier 更灵活
    - 适用于分阶段并行计算、动态任务分组

需要乐观读锁（读多写少）？
└── 使用 TStampedLock
    - TryOptimisticRead 无锁读取
    - Validate 验证一致性
    - 读多写少场景比 RwLock 更高效
    - 适用于缓存、配置读取等场景

需要固定大小 FIFO 缓冲区？
└── 使用 TRingBuffer<T>
    - 固定大小，容量自动取整到 2 的幂
    - MPMC 安全，head/tail 双指针 CAS
    - 适用于生产者-消费者、日志缓冲、实时系统

需要前缀匹配/自动补全？
└── 使用 TConcurrentTrie<TValue>
    - 基于前缀树的并发键值存储
    - 每节点自旋锁保证并发安全
    - 适用于 IP 路由、字典、自动补全

需要定时器/超时管理？
└── 使用 TTimerWheel
    - 环形数组 + 轮次计数
    - 高效管理大量定时任务
    - 适用于超时管理、心跳检测、定时任务调度

需要超时等待的队列？
└── 使用 TTimeoutQueue<T>
    - 固定大小 MPMC 队列
    - DequeueTimeout 支持超时返回
    - 适用于请求超时、任务调度

需要任务窃取线程池？
└── 使用 TWorkStealingPool
    - 每个工作线程有自己的双端队列
    - 本地 LIFO，窃取 FIFO
    - 最小化竞争，适合任务并行
    - 适用场景：任务调度、并行计算、fork-join

需要快照隔离/MVCC？
└── 使用 TSnapshotIsolation<TValue>
    - 每个事务看到数据库在事务开始时的快照
    - 读不阻塞写，写不阻塞读
    - 适用场景：数据库事务、并发状态管理

需要并发图？
└── 使用 TLockFreeGraph
    - 基于邻接表的并发图
    - 每顶点自旋锁保证并发安全
    - 支持有向图，添加/删除顶点和边
    - 适用场景：社交网络、依赖分析、路径查找

需要 ForkJoin 并行执行？
└── 使用 TLockFreeForkJoinPool
    - 类似 Java ForkJoinPool
    - 每个工作者有本地双端队列
    - 本地 LIFO + 窃取 FIFO
    - 适用场景：递归分治、并行计算、MapReduce

需要写时复制数组（读多写极少）？
└── 使用 TCopyOnWriteArray<T>
    - 读无锁，写时复制整个数组
    - 线程安全的快照语义
    - 适用场景：配置列表、监听器列表、事件回调

需要动态连通性查询？
└── 使用 TLockFreeDisjointSet
    - 路径压缩 + 按秩合并，均摊 O(1)
    - 自动扩容
    - 适用场景：连通分量、聚类、Kruskal 最小生成树

需要无界 MPMC 队列？
└── 使用 TLockFreeMsQueue<T>
    - Michael-Scott 经典算法
    - Sentinel 节点 + CAS
    - 自动扩容，无容量限制
    - 适用场景：高吞吐消息队列、生产者-消费者

需要 Channel（生产者-消费者通信）？
├── 单向通信
│   ├── 单生产者单消费者 (1P1C)
│   │   └── 使用 TLockFreeChannelSpsc<T>
│   │       - 专为 1P1C 优化，使用原子 load/store
│   │       - 性能超越 Go channel (2.99x) 和 Rust (1.26x)
│   │       - 阻塞/非阻塞/超时
│   │
│   └── 多生产者多消费者 (MPMC)
│       └── 使用 TLockFreeChannel<T>
│           - 有界，容量自动取整到 2 的幂
│           - 阻塞/非阻塞/超时
│           - Close 后已入队数据仍可读
│
└── 多路复用（Go select 语义）
    └── 使用 TLockFreeSelector<T>
        - 等待多个 channel 中第一个就绪
        - 阻塞/超时两种等待模式
        - 所有 case 必须使用相同类型 T
```

## 性能对比

| 数据结构 | 场景 | 吞吐 (M ops/s) | 延迟 (ns/op) |
|----------|------|---------------|-------------|
| TSpscQueue | 1P+1C | 101 | 9.9 |
| TSpmcQueue | 1P+2C | 75 | 13.4 |
| TMpmcQueue | 2P+2C | 68 | 14.6 |
| TMpscQueue | 4P+1C | ~68 | ~15 |
| TSegQueue | 2P+2C | 17 | 59.1 |
| TLockFreeStack | 4P+4C | ~67 | ~15 |
| TWorkStealingDeque | 1 owner + 2 thieves | ~2.0 | ~500 |
| **TLockFreeChannelSpsc** | **1P+1C** | **26.2** | **38.2** |
| TLockFreeChannel | MPMC | 10.6 | 94.3 |

### 跨语言对比 (1P1C Channel)

| 实现 | 延迟 (ns/op) | 吞吐 (M ops/s) | 相对 Go |
|------|-------------|---------------|---------|
| **nextpas SPSC Channel** | **38.2** | **26.2** | **2.99x 快** |
| Rust std::sync::mpsc | 48.3 | 20.7 | 2.37x 快 |
| Go channel | 114.3 | 8.7 | 基准 |
| C++ mutex+condvar | 202.2 | 4.9 | 0.56x |

## 线程安全契约

生命周期：**Close → join producers/waiters → Free**。Destroy 的 Close+drain 不替代 join。
T1 元素类型必须 unmanaged（构造时 `EArgumentError`）。
需要区分 full/empty/closed 时用可选 `Try*Ex`（`TLockFreeTryError`；Boolean `Try*` 热路径不变）。

| 数据结构 | 生产者 | 消费者 | Close 安全 |
|----------|--------|--------|-----------|
| TSpscQueue | 1 线程 | 1 线程 | ✅ |
| TSpmcQueue | 1 线程 | N 线程 | ✅ |
| TMpmcQueue | N 线程 | N 线程 | ✅ |
| TMpscQueue | N 线程 | 1 线程 | ✅（Close 后 Enqueue 抛错；用 TryEnqueue） |
| TSegQueue | N 线程 | N 线程 | ✅ |
| TLockFreeStack | N 线程 | N 线程 | N/A |
| TWorkStealingDeque | 1 owner + N thieves | 1 owner + N thieves | N/A |
| TLockFreeChannelSpsc | 1 线程 | 1 线程 | ✅ |
| TLockFreeChannel | N 线程 | N 线程 | ✅（Send 在 closed 时抛错） |
| TLockFreeMsQueue | N 线程 | N 线程 | ✅ |
| TLockFreeForkJoinPool | N 工作者 | N 工作者 | ✅ (T2) |
| TCopyOnWriteArray | N 读 / 1 写 | N 读 | ✅ (T2) |
| TLockFreeDisjointSet | N 线程 | N 线程 | N/A (T2) |

## 内存回收方案选择

| 方案 | 适用场景 | 延迟 | 内存开销 |
|------|----------|------|----------|
| EBR | 读多写少 | 低 | 退休链表 |
| Hazard Pointer | 读写均衡 | 中 | 每线程 hazard 数组 |
| 无回收 (leak) | 短生命周期 | 最低 | 无 |
