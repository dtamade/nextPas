# Lockfree 数据结构选型指南

> 更新: 2026-07-06

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

需要 Channel（生产者-消费者通信）？
├── 单向通信
│   └── 使用 TLockFreeChannel<T>
│       - 有界，容量自动取整到 2 的幂
│       - 阻塞/非阻塞/超时
│       - Close 后已入队数据仍可读
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
| TSpscQueue | 1P+1C | 4.40 | 227 |
| TSpmcQueue | 1P+2C | 2.60 | 385 |
| TMpmcQueue | 2P+2C | 3.80 | 263 |
| TMpscQueue | 4P+1C | ~3.0 | ~330 |
| TSegQueue | 2P+2C | 1.50 | 667 |
| TLockFreeStack | 4P+4C | ~5.0 | ~200 |
| TWorkStealingDeque | 1 owner + 2 thieves | ~2.0 | ~500 |

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

## 内存回收方案选择

| 方案 | 适用场景 | 延迟 | 内存开销 |
|------|----------|------|----------|
| EBR | 读多写少 | 低 | 退休链表 |
| Hazard Pointer | 读写均衡 | 中 | 每线程 hazard 数组 |
| 无回收 (leak) | 短生命周期 | 最低 | 无 |
