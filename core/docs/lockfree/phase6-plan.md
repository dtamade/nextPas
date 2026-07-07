# Phase 6: EBR Per-thread Retire Buffer

> 创建: 2026-07-06 | 状态: 评估完成，方案不可行

## 目标

优化 `TEbrDomain.Retire` 的 CAS contention。每次调用都 CAS 操作全局链表，高并发时有 cacheline bouncing。

## 方案评估

### 方案 A: threadvar Per-thread Buffer ❌ 不可行

**实现**:
```pascal
threadvar
  GRetireBuffer: array[0..15] of TEbrRetireEntry;
  GRetireBufferCount: Int32;

procedure TEbrDomain.Retire(...);
begin
  // 先本地积累
  GRetireBuffer[GRetireBufferCount] := entry;
  Inc(GRetireBufferCount);
  // 满了再批量 CAS
  if GRetireBufferCount >= 16 then
    FlushRetireBuffer;
end;
```

**问题**: `threadvar` 不支持析构函数。线程退出时缓冲区内容丢失，导致内存泄漏。

**验证**: 实现后 heaptrc 报告 50 unfreed memory blocks。

### 方案 B: Domain 内 Per-thread Buffer ⚠️ 复杂

**实现**: 在 TEbrDomain 内维护 per-thread buffer 数组，用 thread ID 索引。

**问题**:
1. 需要动态管理 per-thread buffer 生命周期
2. 线程退出时需要清理（需要 pthread_key_create destructor）
3. 平台相关（Linux/Windows 不同）
4. 增加复杂度，收益有限

### 方案 C: 保持现状 ✅ 推荐

**理由**:
1. CAS 操作在低竞争下已经很快（~10ns）
2. Retire 通常在临界区外调用，不阻塞主路径
3. 简单可靠，无泄漏风险
4. 真正的高竞争场景应该用 Hazard Pointer

## 结论

EBR per-thread retire buffer 优化因 `threadvar` 限制不可行。当前实现已足够好：
- 单次 CAS ~10ns
- 适用于低竞争场景
- 高竞争场景应使用 THazardDomain

## 替代优化方向

1. **Hazard Pointer per-thread slot**: 已实现，性能优秀
2. **Sharded HashMap**: 已实现，读路径无锁
3. **SPSC 批量操作**: 已优化，使用 Move
4. **MPMC exponential backoff**: 已优化

---

| 任务 | 状态 | 原因 |
|------|------|------|
| EBR threadvar buffer | ❌ 不可行 | 线程退出时泄漏 |
| EBR domain buffer | ⚠️ 延迟 | 复杂度高，收益有限 |
| 文档记录 | ✅ 完成 | 已记录方案评估 |
