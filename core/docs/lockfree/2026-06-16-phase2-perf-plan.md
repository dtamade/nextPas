# Phase 2 性能优化详细计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 atomic/lockfree 性能提升到对标并超越 Go channel + Rust crossbeam 的水平

**Architecture:** L0 atomic + lockfree，依赖 FPC RTL + futex

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, SIMD (SSE/AVX)

---

## 当前性能基线

| 数据结构 | 当前 (M ops/s) | 目标 (M ops/s) | 差距 |
|----------|---------------|---------------|------|
| SPSC 1P+1C | 4.40 | 6.0+ | +36% |
| MPMC 2P+2C | 1.29 | 2.0+ | +55% |
| SegQueue 2P+2C | 1.50 | 2.5+ | +67% |
| SPMC 1P+2C | 2.60 | 4.0+ | +54% |

---

## Task 2.1: 消除 SPMC 双次通知冗余

**文件**: `core/src/nextpas.core.lockfree.spmc.pas`

**当前问题**:
- `TryEnqueue` (line 102): 调用 `LockFreeNotifyData(@FDataEpoch, @FDataWaiters)`
- `EnqueueWait` (line 153): 又调用 `LockFreeWakeAll(@FDataEpoch)`
- `EnqueueTimeout` (line 186, 198): 又调用 `LockFreeWakeAll(@FDataEpoch)`
- `TryDequeue` (line 131): 调用 `LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters)`
- `DequeueWait` (line 171): 又调用 `LockFreeWakeAll(@FSpaceEpoch)`
- `DequeueTimeout` (line 220): 又调用 `LockFreeWakeAll(@FSpaceEpoch)`

**问题**:
1. Epoch 被递增两次，缩短了 wrap-around 周期
2. `LockFreeWakeAll` 无条件调用 `platform_wake_address_all`，即使没有等待者
3. `LockFreeNotifyData`/`LockFreeNotifySpace` 在无等待者时只递增 epoch，不做系统调用

**修复方案**: 移除 wait/timeout 方法中的 `LockFreeWakeAll`，只依赖 Try 方法内部的 notify。

**Step 1**: 读取 spmc.pas 确认当前代码行号
**Step 2**: 移除 EnqueueWait 中的 LockFreeWakeAll
**Step 3**: 移除 DequeueWait 中的 LockFreeWakeAll
**Step 4**: 移除 EnqueueTimeout 中的 LockFreeWakeAll (两处)
**Step 5**: 移除 DequeueTimeout 中的 LockFreeWakeAll
**Step 6**: 运行完整测试套件验证唤醒语义不变
**Step 7**: 运行基准测量性能改进
**Step 8**: 提交

**验证**:
```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
```

---

## Task 2.2: 批量操作 SIMD 加速

**依赖**: nextpas.core.simd 模块 (需 Codex 审核)

**文件**:
- `core/src/nextpas.core.lockfree.spsc.pas`
- `core/src/nextpas.core.lockfree.mpmc.pas`

**优化点**:
- `EnqueueBatch`/`DequeueBatch` 中的 for 循环逐元素拷贝
- 当 T 是简单类型 (Integer, UInt32, UInt64) 时，可用 SIMD 批量拷贝

**Step 1**: 与 Codex 讨论 SIMD 加速策略
**Step 2**: 在 batch 操作中添加 SIMD 批量拷贝路径
**Step 3**: 添加 SIMD 批量操作测试
**Step 4**: 基准测量

---

## Task 2.3: SegQueue 预分配优化

**文件**: `core/src/nextpas.core.lockfree.segqueue.pas`

**当前问题**:
- 每次 segment 用完都 AllocSegment + FreeMem 回收
- 高频 enqueue/dequeue 场景下分配/释放开销显著

**优化方案**:
1. 维护一个 segment 空闲链表 (`FFreeSegments: PSegment`)
2. `SegQueueReclaimSegment` 不再 FreeMem，而是将 segment 放回空闲链表
3. `AllocSegment` 先检查空闲链表，有则复用
4. `Destroy` 统一释放所有 segment (包括空闲链表)

**Step 1**: 添加 `FFreeSegments` 字段和 `FPoolCapacity` 限制
**Step 2**: 修改 `SegQueueReclaimSegment` 放回空闲链表
**Step 3**: 修改 `AllocSegment` 优先从空闲链表取
**Step 4**: 修改 `Destroy` 释放空闲链表
**Step 5**: 运行完整测试验证无泄漏
**Step 6**: 基准测量

**API 不变**: 这是内部实现优化，public API 不受影响。

---

## Task 2.4: Cache Line 对齐审计

**检查清单**:

| 数据结构 | 字段 | 对齐状态 | 操作 |
|----------|------|----------|------|
| SPMC | FEnqueuePos | ❌ 无 padding | 添加 TCacheLinePad |
| SPMC | FDequeuePos | ❌ 无 padding | 添加 TCacheLinePad |
| SegQueue | FHead | ❌ 无 padding | 添加 TCacheLinePad |
| SegQueue | FTail | ❌ 无 padding | 添加 TCacheLinePad |
| Stack | FHead | ❌ 无 padding | 添加 TCacheLinePad |
| Deque | FBottom | ❌ 无 padding | 添加 TCacheLinePad |
| Deque | FTop | ❌ 无 padding | 添加 TCacheLinePad |

**文件**:
- `core/src/nextpas.core.lockfree.spmc.pas`
- `core/src/nextpas.core.lockfree.segqueue.pas`
- `core/src/nextpas.core.lockfree.stack.pas`
- `core/src/nextpas.core.lockfree.deque.pas`

**Step 1**: 审计 SPMC 热路径字段
**Step 2**: 审计 SegQueue 热路径字段
**Step 3**: 审计 Stack 热路径字段
**Step 4**: 审计 Deque 热路径字段
**Step 5**: 添加 TCacheLinePad 到需要对齐的字段
**Step 6**: 运行测试 + 基准

---

## 执行顺序

```
Task 2.1 (SPMC 双次通知) → Task 2.4 (Cache Line 对齐) → Task 2.3 (SegQueue 预分配) → Task 2.2 (SIMD)
```

## 验证命令

```bash
# 完整测试
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test

# 基准
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
```
