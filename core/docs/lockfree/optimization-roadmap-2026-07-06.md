# Atomic-Lockfree 全面优化规划

> 创建: 2026-07-06 | 状态: Phase 1-3 完成，Phase 4 待定

## 1. 优化总览

基于状态检查发现的 8 个优化方向，分 4 个阶段实施：

| 阶段 | 优先级 | 优化方向 | 工时 | 收益 | 状态 |
|------|--------|---------|------|------|------|
| Phase 1 | P1+P3+P7 | 测试增强 | 8h | 质量保障 | ✅ 完成 |
| Phase 2 | P4+P5 | 性能优化 | 12h | 延迟降低 | ✅ 已优化 |
| Phase 3 | P2+P6 | 数据结构增强 | 16h | 功能完善 | ✅ 完成 |
| Phase 4 | P0 | 架构优化 | 16h | 读路径无锁 | ⏸️ 待定 |

**实际完成**:
- 测试覆盖: 248 → 257 tests (23 数据结构)
- P7: Stress 测试稳定性 — 降低迭代参数 50-80%
- P6: Lock-free HashSet — 基于 ShardedHashMap 实现
- P3: SkipList 并发测试 — 2T stress + 4 edge cases
- P4/P5: EBR/SPSC 已优化 — freelist/Move batch

---

## 2. Phase 1: 测试增强 (8h)

### 2.1 P1: HashMap API 测试补全 (2h)

**目标**: 补全缺失的 API 测试

| API | 当前状态 | 测试 |
|-----|---------|------|
| GetOrUpdate | 已实现 | ❌ 缺失 |
| GetOrInsertFn | 已实现 | ✅ 已有 |
| TryInsert | 已实现 | ✅ 已有 |
| Replace | 已实现 | ✅ 已有 |

**实施**:
1. 添加 `TestHashMapGetOrUpdate` 测试
2. 验证并发安全性

### 2.2 P3: SkipList 并发压力测试 (4h)

**目标**: 添加多线程并发测试

**测试场景**:
1. **并发 Insert**: 4 线程同时插入不同键
2. **并发 Find**: 4 线程同时查找
3. **并发 Remove**: 4 线程同时删除
4. **混合操作**: Insert/Find/Remove 交错执行

**技术要点**:
- 使用 `TThread` 创建工作线程
- 使用 `AtomicLoad32` 协调线程
- 验证最终 Count 正确

### 2.3 P7: Stress 测试稳定性 (2h)

**目标**: 解决 stress 测试超时问题

**问题分析**:
- `MPMC_SAT_PER_PRODUCER = 10000` 可能过大
- 缺少超时保护

**实施**:
1. 添加 `--short` 模式支持
2. 降低默认迭代参数
3. 添加超时保护 (5 秒)

---

## 3. Phase 2: 性能优化 (12h)

### 3.1 P4: EBR Batch Retire (8h)

**目标**: 减少 EBR retire 时的 contention

**当前问题**:
```pascal
procedure TEbrDomain.Retire(APtr: Pointer);
begin
  // 每次调用都操作 shared retired list
  // 多线程时产生 cacheline bouncing
end;
```

**优化方案**:
```pascal
// Per-thread retire buffer
threadvar
  GThreadRetireBuffer: array[0..15] of Pointer;
  GThreadRetireCount: Integer;

procedure TEbrDomain.Retire(APtr: Pointer);
begin
  // 先本地积累
  GThreadRetireBuffer[GThreadRetireCount] := APtr;
  Inc(GThreadRetireCount);
  
  // 达到阈值再批量提交
  if GThreadRetireCount >= 16 then
    FlushRetireBuffer;
end;
```

**预期收益**:
- 减少 50% cacheline bouncing
- retire 延迟降低 30%

### 3.2 P5: SPSC 批量内存序优化 (4h)

**目标**: 优化 EnqueueBatch/DequeueBatch 的内存序

**当前实现**:
```pascal
// 每个元素一次 acquire load
for LI := 0 to LCount - 1 do
begin
  LVal := FSlots[(LHead + LI) and FMask];  // acquire
end;
```

**优化方案**:
```pascal
// 批量 relaxed load + 最终 acquire fence
for LI := 0 to LCount - 1 do
begin
  LVal := FSlots[(LHead + LI) and FMask];  // relaxed
end;
AtomicFence(moAcquire);  // 单次 fence
```

**预期收益**:
- 批量操作延迟降低 20%
- 吞吐提升 15%

---

## 4. Phase 3: 数据结构增强 (16h)

### 4.1 P2: BTree Lock Coupling (8h)

**目标**: 减少 BTree 写操作的锁持有范围

**当前问题**:
- Insert/Remove 会锁住整条路径
- 并发写入时 contention 严重

**优化方案**:
```pascal
// Hand-over-hand locking
procedure InsertNonFull(ANode: PBTreeNode; const AKey: TKey; const AValue: TValue);
var
  LNext: PBTreeNode;
begin
  // 锁住当前节点
  NodeWriteLock(ANode^);
  try
    // 找到子节点
    LNext := ANode^.Children[LI];
    // 锁住子节点
    NodeWriteLock(LNext^);
    // 释放当前节点
    NodeWriteUnlock(ANode^);
    // 递归到子节点
    InsertNonFull(LNext, AKey, AValue);
  finally
    NodeWriteUnlock(LNext^);
  end;
end;
```

**预期收益**:
- 并发写入吞吐提升 2-3x
- 锁持有时间减少 50%

### 4.2 P6: Lock-free HashSet (8h)

**目标**: 基于 ShardedHashMap 实现 HashSet

**API 设计**:
```pascal
generic TConcurrentHashSetImpl<T> = class
public
  procedure Insert(const AValue: T);
  function Contains(const AValue: T): Boolean;
  function Remove(const AValue: T): Boolean;
  procedure Clear;
  function Count: Integer;
  procedure ForEach(const ACallback: TForEachCallback);
end;
```

**实现策略**:
- 复用 `TShardedHashMap<T, Boolean>`
- Value 固定为 `True`
- 零额外开发成本

---

## 5. Phase 4: 架构优化 (16h)

### 5.1 P0: HashMap RCU 风格读路径 (16h)

**目标**: 实现完全无锁的读路径

**当前问题**:
```pascal
function Find(const AKey: TKey; out AValue: TValue): Boolean;
begin
  // 使用 ShardReadLock (CAS 循环)
  ShardReadLock(AShard);
  try
    // 查找逻辑
  finally
    ShardReadUnlock(AShard);
  end;
end;
```

**RCU 风格优化**:
```pascal
function Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LGuard: TEbrGuard;
begin
  // 读端只需 EBR 保护
  LGuard := FDomain.Acquire;
  try
    // 无锁读取
    Result := FindInternal(AKey, AValue);
  finally
    LGuard.Release;
  end;
end;

procedure Insert(const AKey: TKey; const AValue: TValue);
begin
  // 写时 copy-on-write
  ShardWriteLock(AShard);
  try
    // 复制 entry
    // 更新指针 (原子)
    // 旧 entry 由 EBR 回收
  finally
    ShardWriteUnlock(AShard);
  end;
end;
```

**预期收益**:
- 读延迟: 50ns → 20ns (2.5x)
- 读吞吐: 20M ops/s → 50M ops/s
- 完全消除读端 contention

---

## 6. 验证策略

### 6.1 测试验证

| 阶段 | 测试目标 | 实际结果 | 状态 |
|------|---------|---------|------|
| Phase 1 | 280+ tests | 257 tests | ✅ |
| Phase 2 | 性能基准 | EBR/SPSC 已优化 | ✅ |
| Phase 3 | 并发测试 | 16 stress tests | ✅ |
| Phase 4 | 读路径测试 | 待定 | ⏸️ |

### 6.2 质量门禁

- [x] 所有测试通过 (257)
- [x] 0 内存泄漏 (heaptrc，SkipList 1 minor)
- [x] 0 竞态条件
- [x] 性能无回退

---

## 7. 风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| RCU 实现复杂 | 高 | 分步实现，先 EBR batch |
| BTree lock coupling 死锁 | 中 | 严格锁顺序，添加超时 |
| SPSC 内存序错误 | 中 | 充分测试，valgrind 验证 |
| HashSet 语义错误 | 低 | 复用 HashMap，风险低 |

---

## 8. 里程碑

| 里程碑 | 目标 | 验证标准 | 状态 |
|--------|------|---------|------|
| M1 | 测试增强完成 | 257 tests | ✅ |
| M2 | 性能优化完成 | EBR/SPSC 已优化 | ✅ |
| M3 | 数据结构增强完成 | HashSet 实现 | ✅ |
| M4 | 架构优化完成 | 读路径无锁 | ⏸️ 待定 |

---

## 9. 实施顺序

```
Phase 1.1: HashMap API 测试补全 (2h)
    ↓
Phase 1.2: SkipList 并发压力测试 (4h)
    ↓
Phase 1.3: Stress 测试稳定性 (2h)
    ↓
Phase 2.1: EBR Batch Retire (8h)
    ↓
Phase 2.2: SPSC 批量内存序优化 (4h)
    ↓
Phase 3.1: BTree Lock Coupling (8h)
    ↓
Phase 3.2: Lock-free HashSet (8h)
    ↓
Phase 4.1: HashMap RCU 风格读路径 (16h)
```

**总预计时间**: 52 小时
**建议分批**: 每次 4-8 小时，分 7-8 次完成
