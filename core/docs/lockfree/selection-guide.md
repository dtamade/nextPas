# Lockfree 数据结构选型指南

> 更新: 2026-07-06

[English](selection-guide.en.md)

## 快速决策树

```
需要队列？
├── 单生产者 + 单消费者 (SPSC)
│   └── 使用 TSpscQueue<T>
│       - 最快，无 CAS 竞争
│       - 支持 batch/wait/timeout/close
│       - 性能: 4.4 M ops/s
│
├── 单生产者 + 多消费者 (SPMC)
│   └── 使用 TSpmcQueue<T>
│       - 多消费者 CAS 竞争 dequeue
│       - 支持 wait/timeout/close
│       - 性能: 2.6 M ops/s (1P+2C)
│
├── 多生产者 + 多消费者 (MPMC)
│   └── 使用 TMpmcQueue<T>
│       - 通用但有 CAS 竞争开销
│       - 支持 batch/wait/timeout/close
│       - 性能: 1.3 M ops/s (2P+2C)
│
├── 多生产者 + 单消费者 (MPSC)
│   └── 使用 TMpscQueue<T>
│       - 无界，多生产者安全
│       - 支持 wait/timeout/try-enqueue/close
│       - 性能: 最高 (无 CAS enqueue)
│
└── 无界 MPSC (高吞吐)
    └── 使用 TSegQueue<T>
        - 分段设计，EBR 回收
        - 无界，自动扩展
        - 支持 try-enqueue/close
        - 性能: 1.5 M ops/s (2P+2C)

需要栈？
├── LIFO (后进先出)
│   └── 使用 TLockFreeStack<T>
│       - Treiber stack 算法
│       - ABA 安全
│       - 性能: 最高 (单 CAS push/pop)
│
└── 工作窃取 (owner push/pop + thief steal)
    └── 使用 TWorkStealingDeque<T>
        - owner LIFO pop, thief FIFO steal
        - 适用于任务调度
        - 性能: 取决于竞争程度

需要内存回收？
├── 使用 TEbrDomain + TEbrGuard
│   - Epoch-Based Reclamation
│   - 保守单次检查设计
│   - 适用: 读多写少场景
│
└── 使用 THazardDomain
    - Hazard Pointer
    - 精确保护，适合读写均衡场景
    - 适用: 延迟敏感、内存受限场景

需要并发 HashMap？
└── 使用 TLockFreeHashMap<TKey,TValue>
    - 分片锁 HashMap (16 shards)
    - Insert/Find/Remove/Contains/Count
    - 自动 resize

需要 Bag（允许重复元素的并发集合）？
└── 使用 TLockFreeBag<T>
    - 基于 MPMC 队列，允许重复元素
    - FIFO 顺序
    - 阻塞/非阻塞/超时
    - 适用: 任务队列、工作池

需要 MultiMap（一个键多个值）？
└── 使用 TLockFreeMultiMap<TKey,TValue>
    - 基于分片锁 HashMap
    - 一个键可以有多个值
    - 适用于索引、标签系统

需要 Bloom Filter（快速成员检查）？
└── 使用 TConcurrentBloomFilter<T>
    - 概率数据结构，可能存在假阳性
    - 空间效率高
    - 适用于缓存、去重、快速成员检查

需要 LRU Cache（最近最少使用缓存）？
└── 使用 TConcurrentLruCache<TKey,TValue>
    - 分片锁 HashMap + 访问计数
    - 自动淘汰最久未访问的条目
    - 适用于缓存、淘汰场景

需要并发计数器？
└── 使用 TConcurrentCounter
    - 原子操作，无锁
    - Increment/Decrement/Add/Sub/Load/Store
    - 适用于统计、计数

需要信号量（资源池限流）？
└── 使用 TConcurrentSemaphore
    - 原子 CAS 操作
    - TryAcquire/Acquire/AcquireTimeout/Release
    - 适用于资源池、限流

需要互斥锁？
└── 使用 TConcurrentMutex
    - 原子 CAS 操作
    - TryLock/Lock/LockTimeout/Unlock
    - 适用于互斥访问

需要读写锁？
└── 使用 TConcurrentRwLock
    - 单 Int32 状态编码 (0/-1/>0)
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

| 数据结构 | 生产者 | 消费者 | Close 安全 |
|----------|--------|--------|-----------|
| TSpscQueue | 1 线程 | 1 线程 | ✅ |
| TSpmcQueue | 1 线程 | N 线程 | ✅ |
| TMpmcQueue | N 线程 | N 线程 | ✅ |
| TMpscQueue | N 线程 | 1 线程 | ✅ |
| TSegQueue | N 线程 | N 线程 | ✅ |
| TLockFreeStack | N 线程 | N 线程 | N/A |
| TWorkStealingDeque | 1 owner + N thieves | 1 owner + N thieves | N/A |
| TLockFreeChannelSpsc | 1 线程 | 1 线程 | ✅ |
| TLockFreeChannel | N 线程 | N 线程 | ✅ |

## 内存回收方案选择

| 方案 | 适用场景 | 延迟 | 内存开销 |
|------|----------|------|----------|
| EBR | 读多写少 | 低 | 退休链表 |
| Hazard Pointer | 读写均衡 | 中 | 每线程 hazard 数组 |
| 无回收 (leak) | 短生命周期 | 最低 | 无 |
