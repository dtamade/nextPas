# Phase 8: EBR per-thread retire buffer — 调研结论

## 问题

EBR per-thread retire buffer 优化（Phase 7）使用 `pthread_key_create` + destructor 实现线程退出时自动 flush 缓冲区。但 destructor 会干扰 FPC 的线程清理机制，导致 stress test 挂起。

## 调研发现

### 1. pthread_key_create 的 destructor 问题

- `pthread_key_create` 注册的 destructor 对**所有线程**生效（包括不使用 EBR 的线程）
- 当线程退出时，pthread 机制会调用 destructor
- 这与 FPC 的线程清理机制冲突，导致 stress test 挂起

### 2. 尝试的方案

#### 方案 A: nil destructor + 全局 buffer 注册表
- 使用 `pthread_key_create(@GEbrTlsKey, nil)` 不注册 destructor
- 分配 buffer 时注册到全局原子链表 `GEbrAllBuffers`
- `TEbrDomain.Destroy` 遍历全局链表，flush 所有属于此 domain 的 buffer
- `finalization` 释放所有 buffer

**结果**: stress test 总是挂起（0/6 通过）

**原因**: `Destroy` 中遍历全局链表与 `atomic_exchange(FRetired, nil)` 之间存在竞态条件。`FlushBufferToDomain` 的 CAS 操作可能在 `atomic_exchange` 之后执行，导致 retired nodes 丢失或写入已释放的内存。

#### 方案 B: 只改 nil destructor（不添加全局链表）
- 使用 `pthread_key_create(@GEbrTlsKey, nil)` 不注册 destructor
- 不添加全局 buffer 注册表
- 线程退出时未 flush 的 buffer 会泄漏

**结果**: stress test flaky（3/5 通过），有 20-36 个未释放内存块

**原因**: 线程退出时 buffer 中的 retired nodes 丢失，Data 对象的 Reclaim 回调不会被调用。

### 3. 根本原因

1. **pthread destructor 与 FPC 冲突**: pthread_key_create 的 destructor 机制与 FPC 的线程清理机制不兼容
2. **全局链表竞态**: 在 `Destroy` 中遍历全局链表并 flush 到正在销毁的 domain 会产生竞态条件
3. **线程退出泄漏**: 不使用 destructor 时，线程退出会丢失 buffer 中的数据

### 4. 原始 EBR 的 flaky 问题

原始 EBR（使用 pthread_key_create + destructor）的 stress test 也是 flaky：
- 2/3 次通过，1/3 次挂起
- 这是一个已知的并发测试问题，不是 EBR 改动导致的

## 结论

**Phase 7 的 pthread_key_create + destructor 方案不可行**，因为：
1. destructor 干扰 FPC 线程清理
2. 全局 buffer 注册表引入竞态条件
3. 只改 nil destructor 会导致内存泄漏

**建议**:
1. 保持原始 EBR 实现（直接 CAS，无 per-thread buffer）
2. 如果需要 per-thread buffer 优化，需要找到不依赖 pthread_key_create 的方案
3. 或者等待 FPC 提供更好的线程本地存储机制

## 性能影响

放弃 per-thread buffer 优化意味着：
- 每次 `Retire` 都需要一次 CAS 操作
- 在高频 retire 场景下可能成为瓶颈
- 但对于当前的使用场景（SegQueue 等临界区极短的无锁数据结构），影响有限

## 后续工作

1. 如果需要 per-thread buffer 优化，可以考虑：
   - 使用 `threadvar` + 定期 flush（不依赖 destructor）
   - 使用 `threadvar` + 显式 flush 在 `Collect`/`Destroy` 中
   - 探索 FPC 是否支持线程退出回调
2. 修复 stress test 的 flaky 问题（已知并发测试问题）
