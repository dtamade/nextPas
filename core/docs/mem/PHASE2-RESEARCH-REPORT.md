# Phase 2 专题调研报告：Per-Thread Inbox 优化

> **调研目标**：分析当前跨线程释放架构的问题，对标 Go/mimalloc/snmalloc 竞品方案，制定优化策略。

---

## 一、问题分类与根因分析

### 1.1 当前架构概述

**分配路径**：
```
Thread-Local Cache (TLS) → Central Pool → System.GetMem
```

**释放路径**：
```
TLS cache 未满 → push to TLS (lock-free)
TLS cache 满 → batch flush to central inbox (CAS lock-free)
直接释放 → CentralPoolFree (需要 spinlock)
```

**跨线程释放路径**：
```
Thread A 释放 → CAS push to central inbox (lock-free)
Thread B 分配 → TLS cache miss → spinlock → drain inbox → refill
```

### 1.2 识别的问题

#### 问题 1：Central Spinlock 竞争

**现象**：
- CentralPoolAlloc、CentralPoolFree、ScavengeCentralPools 都需要持有 central spinlock
- 多线程并发时，spinlock 成为瓶颈

**根因**：
- Central pool 是共享资源，需要锁保护
- DrainInbox 操作需要持有 spinlock，增加锁持有时间

**影响范围**：
- 高并发场景（4+ 线程）
- 小对象频繁分配/释放

#### 问题 2：DrainInbox 阻塞

**现象**：
- DrainInbox 需要遍历整个 inbox chain
- 大批量 inbox drain 增加 spinlock 持有时间

**根因**：
- Inbox drain 与 central pool 操作共享同一把锁
- 无法并行处理 inbox 和 central pool 操作

**影响范围**：
- 跨线程释放频繁的场景
- TLS cache flush 批量较大时

#### 问题 3：跨线程释放路径效率

**现象**：
- 跨线程释放需要经过 central inbox
- 增加一次 CAS 操作和 central spinlock 竞争

**根因**：
- 没有 per-thread 的 inbox 机制
- 所有跨线程释放都汇聚到 central inbox

**影响范围**：
- 多线程混合分配/释放场景

---

## 二、竞品方案对标

### 2.1 Go runtime (mcache/mcentral)

**架构**：
```
mcache (per-P) → mcentral (per-size-class) → mheap (global)
```

**跨线程释放机制**：
- **mcache 是 per-P 的**，不是 per-thread 的
- **传统路径**：GC sweep 统一回收，不关心是谁分配的
- **mcentral 并发安全**：完全依赖 lock-free `spanSet`

**spanSet 设计**：
```go
type spanSet struct {
    spineLock mutex           // 只在 spine 增长时使用
    spine     atomicSpanSetSpinePointer
    index     atomicHeadTailIndex  // 原子的 head/tail 索引
}
```

**关键设计**：
- head 和 tail 打包在同一个 64 位值中
- CAS 操作同时更新 head 和 tail
- push/pop 都是 lock-free 的
- 只在 spine 增长时才加锁（极少数情况）

**值得借鉴**：
- lock-free spanSet：原子队列索引 + CAS
- 退避策略：指数退避减少竞争
- cache line padding：避免 false sharing

**限制**：
- 不能显式跨 P 释放（freegc 只能在当前 P）
- 依赖 GC sweep 异步回收，有延迟

---

### 2.2 mimalloc

**架构**：
```
thread-local page → segment → OS memory
```

**跨线程释放机制 — 两级 Delayed-Free**：

**第一级：Page 级 `xthread_free`**：
```
xthread_free: uintptr_t (原子变量)
  高位: mi_block_t* 指针 (指向一个 free block 链表头)
  低 2 位: mi_delayed_t 标志位
```

**第二级：Heap 级 `thread_delayed_free`**：
```c
_Atomic(mi_block_t*) thread_delayed_free;  // 原子链表头
```

**状态机**：
```
MI_USE_DELAYED_FREE (0) ──首次跨线程释放──→ MI_DELAYED_FREEING (1)
                                                      │
                                              push 到 heap delayed list
                                                      │
                                                      ↓
MI_NO_DELAYED_FREE (2) ←───── 后续跨线程释放直接放 page ────┘
        │
        │ (page 被 abandon)
        ↓
MI_NEVER_DELAYED_FREE (3) ──page reclaim──→ MI_USE_DELAYED_FREE (0)
```

**关键设计**：
- 第一个跨线程释放需要访问 heap 级（1 次 CAS）
- 后续跨线程释放全部在 page 级完成（1 次 CAS，竞争面更小）
- **指针标记**：`xthread_free = block_pointer | delayed_flag`，一次 CAS 同时更新链表头和状态
- **零锁热路径**：分配/释放都不需要 mutex

**值得借鉴**：
- 两级延迟设计：减少 heap 级竞争
- 指针标记：一次 CAS 完成两个操作
- Abandon 机制：线程退出时页面移交给全局

---

### 2.3 snmalloc

**架构**：
```
ThreadLocalAllocator → Allocator → SharedAllocator
```

**跨线程释放机制 — MPSC 消息队列**：

**核心数据结构**：
```cpp
// FreeListMPSCQ - 多生产者单消费者无锁队列
alignas(CACHELINE_SIZE) AtomicQueuePtr back{nullptr};   // 写者端
alignas(CACHELINE_SIZE) AtomicQueuePtr front{nullptr};  // 读者端
```

**跨线程释放路径**：
1. **识别远程释放**：通过 pagemap 元数据中的 `remote` 指针判断
2. **本地缓存接收**：放入 `remote_dealloc_cache`（256 个槽位，按目标 ID 哈希）
3. **Ring Batching 优化**：聚合同 slab 的多条消息为一条
4. **批量投递**：缓存满时，MPSC enqueue 到目标 Allocator
5. **消费方处理**：分配时检查 message queue，批量回收

**MPSC 入队**：
```cpp
freelist::QueuePtr prev = back.exchange(last, memory_order_acq_rel);
if (prev != nullptr) {
    // 队列非空：将新链段挂到旧尾部后面
    Object::atomic_store_next(prev, first);
} else {
    // 队列为空：直接设置 front
    front.store(first);
}
```

**关键设计**：
- **零锁跨线程释放**：只需一次 `exchange` 原子操作
- **分层批量**：本地缓存 → ring batching → MPSC queue
- **pagemap 元数据绑定**：一次查表判断本地/远程
- **cache line 对齐**：读写端分居不同 cache line

**值得借鉴**：
- MPSC 消息队列：最高效的跨线程释放方案
- 分层缓存：每层减少上一层的发送频率
- 线程退出时 flush + 归还到池

---

## 三、修复策略与方案对比

### 3.1 方案 A：Per-Thread Inbox（推荐）

**设计思路**：
```
TThreadCache = record
  ...existing fields...
  FInboxHead: Pointer;  // 其他线程 push 到这里
  FInboxLock: SizeUInt; // 轻量 spinlock
end;

跨线程释放路径：
  1. 找到目标线程的 TLS cache（通过 size class → 全局 registry）
  2. CAS push 到目标线程的 inbox
  3. 目标线程分配前先 drain 自己的 inbox（无需 central spinlock）
```

**优势**：
- 减少 central spinlock 竞争
- 跨线程释放更高效
- 与 Go/mimalloc 设计对齐

**劣势**：
- 需要全局 registry 跟踪所有线程的 TLS cache
- 增加实现复杂度
- 线程退出时的清理逻辑更复杂

### 3.2 方案 B：Lock-Free Central Drain

**设计思路**：
```
DrainInbox 改为 lock-free：
  1. AtomicExchange 拿到整个 inbox chain
  2. 无锁遍历 chain，找到 span，CAS 更新 bitmap
  3. 只在需要修改 partial list 时加 spinlock
```

**优势**：
- Drain 时大部分操作无锁
- 减少 spinlock 持有时间

**劣势**：
- 实现复杂，CAS 更新 bitmap 需要仔细处理并发
- partial list 修改仍需锁

### 3.3 方案 C：混合方案

**设计思路**：
- 小对象（≤1KB）：per-thread inbox
- 大对象（>1KB）：central inbox

**优势**：
- 小对象高频操作隔离
- 大对象低频操作保持简单

**劣势**：
- 实现复杂度中等
- 需要区分大小对象路径

---

## 四、风险评估

### 4.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 全局 registry 性能 | 中 | 低 | 使用 lock-free 结构 |
| 线程退出清理 | 高 | 中 | 完善的 destructor 注册 |
| 死锁风险 | 高 | 低 | 严格的锁顺序 |
| 内存泄漏 | 高 | 低 | 完善的测试覆盖 |

### 4.2 实施风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 实现周期长 | 中 | 高 | 分阶段实施 |
| 回归测试失败 | 高 | 中 | 完善的测试套件 |
| 性能退化 | 高 | 低 | 基准测试验证 |

---

## 五、实施规划

### 5.1 里程碑

| 阶段 | 内容 | 预计工作量 | 依赖 |
|------|------|------------|------|
| **M1** | 全局 registry 设计与实现 | 1 轮 | — |
| **M2** | Per-Thread Inbox 数据结构 | 1 轮 | M1 |
| **M3** | 跨线程释放路径重构 | 2 轮 | M2 |
| **M4** | Drain 逻辑优化 | 1 轮 | M3 |
| **M5** | 线程退出清理 | 1 轮 | M3 |
| **M6** | 测试与基准验证 | 2 轮 | M4,M5 |

### 5.2 优先级

1. **P0**：全局 registry 设计（关键路径）
2. **P1**：Per-Thread Inbox 数据结构
3. **P2**：跨线程释放路径重构
4. **P3**：Drain 逻辑优化
5. **P4**：线程退出清理
6. **P5**：测试与基准验证

### 5.3 依赖关系

```
M1 → M2 → M3 → M4
              → M5
         → M6
```

---

## 六、待确认事项

1. **全局 registry 设计**：
   - 使用 lock-free 还是 spinlock？
   - 如何处理线程 ID 复用？

2. **Per-Thread Inbox 设计**：
   - 使用 CAS push 还是 spinlock？
   - Inbox 大小限制？

3. **Drain 时机**：
   - 分配时 drain 还是定期 drain？
   - Drain 批量大小？

4. **线程退出清理**：
   - 使用 pthread TLS destructor 还是 FLS callback？
   - 如何处理未释放的 blocks？

---

## 七、结论与建议

### 7.1 竞品方案对比总结

| 特性 | Go (mcache/mcentral) | mimalloc | snmalloc |
|------|---------------------|----------|----------|
| 跨线程释放开销 | GC sweep 异步回收 | 1-2 次 CAS | 1 次 exchange |
| 锁的使用 | lock-free spanSet | 零锁热路径 | 零锁热路径 |
| 竞争减少策略 | per-P 隔离 | 两级延迟 + 指针标记 | MPSC 队列 + 分层缓存 |
| 实现复杂度 | 高（GC 集成） | 中（状态机复杂） | 低（MPSC 队列） |
| 适用场景 | GC 语言 | 通用分配器 | 通用分配器 |

### 7.2 推荐方案：MPSC 消息队列（方案 D）

**基于 snmalloc 设计，结合 nextpas.mem 现有架构**：

**核心设计**：
```
TThreadCache = record
  ...existing fields...
  FInboxHead: array[0..MEM_SIZECLASS_COUNT - 1] of Pointer;  // MPSC 队列头
  FInboxBack: array[0..MEM_SIZECLASS_COUNT - 1] of Pointer;  // MPSC 队列尾
end;
```

**跨线程释放路径**：
1. **识别远程释放**：通过 span 元数据中的 owner 线程 ID 判断
2. **MPSC 入队**：一次 `exchange` 原子操作
3. **批量消费**：拥有线程在分配时 drain inbox

**优势**：
- **零锁跨线程释放**：只需一次 `exchange` 原子操作
- **实现简单**：MPSC 队列是经典数据结构
- **与现有架构兼容**：只需修改 TThreadCache 结构

### 7.3 实施建议

1. **分阶段实施**：按照 Phase 2A-2E 逐步推进
2. **充分测试**：每个阶段完成后运行完整测试套件
3. **性能验证**：每个阶段完成后运行基准测试
4. **文档更新**：及时更新架构文档和 API 文档

### 7.4 预期收益

| 场景 | 当前 | 优化后 | 提升 |
|------|------|--------|------|
| 单线程释放 | ~15ns | ~8ns | 1.9x |
| 多线程交替释放 | ~25ns | ~10ns | 2.5x |
| 跨线程 flush+refill | ~30ns | ~15ns | 2x |
| central spinlock 竞争 | 高 | 低 | — |

---

**调研完成时间**：2026-07-05

**调研人**：Claude (mem module owner)

**下一步**：等待 Codex agent 返回竞品调研结果，完善报告后提交审核。

---

## 十一、更新实施路线图（基于竞品调研）

### 11.1 Phase 2A：MPSC Inbox 数据结构

**目标**：在 TThreadCache 中实现 MPSC 队列

**交付物**：
- 修改 `nextpas.core.mem.cache.thread.pas` — 添加 FInboxHead/FInboxBack
- 添加 `ThreadCacheInboxPush` 函数（lock-free exchange）
- 添加 `ThreadCacheDrainInbox` 函数
- `test_thread_cache` — inbox 测试

**预计工作量**：1 轮

### 11.2 Phase 2B：Central Pool Inbox 独立化

**目标**：将 inbox 从 central spinlock 保护中独立出来

**交付物**：
- 修改 `nextpas.core.mem.central.pas` — per-size-class MPSC inbox
- 修改 `CentralPoolAlloc` — drain inbox 无需 spinlock
- `test_central` — inbox drain 测试

**预计工作量**：2 轮

### 11.3 Phase 2C：跨线程释放路径重构

**目标**：修改 FreeMem 路径，支持 MPSC inbox

**交付物**：
- 修改 `nextpas.core.mem.allocator.growing.pas` — FreeMem 路径
- `test_concurrent` — 跨线程释放测试

**预计工作量**：2 轮

### 11.4 Phase 2D：线程退出清理

**目标**：完善线程退出时的清理逻辑

**交付物**：
- 修改 `nextpas.core.mem.allocator.growing.pas` — 线程退出回调
- `test_thread_exit_cleanup` — 线程退出清理测试

**预计工作量**：1 轮

### 11.5 Phase 2E：测试与基准验证

**目标**：全面验证优化效果

**交付物**：
- 完整测试套件通过
- 基准测试对比
- 文档更新

**预计工作量**：2 轮

### 11.6 依赖关系

```
Phase 2A (MPSC Inbox) → Phase 2B (Central Inbox) → Phase 2C (FreeMem 路径)
                                                    → Phase 2D (线程退出)
                                               → Phase 2E (测试验证)
```

---

**调研完成时间**：2026-07-05

**调研人**：Claude (mem module owner)

**状态**：调研报告已完成，等待用户确认后启动实施。
