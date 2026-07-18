> **归档**（2026-07-17）：历史 Phase 4 计划。推进主线见 [`roadmap.md`](roadmap.md)。

# Phase 4: HashMap 读路径优化计划

> 创建: 2026-07-06 | 状态: 实施中

## 1. 优化目标

将 HashMap 读路径从 CAS 读锁优化为完全无锁，预期收益：
- 读延迟: 50ns → 20ns (2.5x)
- 读吞吐: 20M ops/s → 50M ops/s
- 完全消除读端 contention

## 2. 当前架构分析

### 2.1 现有读路径

```pascal
function Find(const AKey: TKey; out AValue: TValue): Boolean;
begin
  ShardReadLock(FShards[LShardIdx]);  // CAS 循环
  try
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
      AValue := FShards[LShardIdx].Entries[LIdx].Value;
  finally
    ShardReadUnlock(FShards[LShardIdx]);
  end;
end;
```

**问题**:
- 读锁使用 CAS 循环，高竞争下 CPU 浪费
- 读写锁共享同一个 Lock 字段，写锁会阻塞所有读者

### 2.2 优化方案选择

| 方案 | 复杂度 | 收益 | 风险 |
|------|--------|------|------|
| RCU + Copy-on-write | 高 | 高 | 内存分配开销 |
| 版本号 + 乐观读 | 中 | 中 | ABA 问题 |
| Hazard Pointer | 中 | 高 | 内存开销 |
| **分片读锁优化** | **低** | **中** | **低** |

**选择**: 分片读锁优化（渐进式改进，风险最低）

## 3. 实施计划

### 3.1 Phase 4A: 读锁优化 (2h)

**目标**: 减少读锁 CAS 循环的 CPU 浪费

**改动**:
1. 优化 ShardReadLock 的自旋策略
2. 添加 exponential backoff
3. 减少不必要的 CAS 操作

```pascal
procedure TShardedHashMapImpl.ShardReadLock(var AShard: TShard);
var
  LLock: Int32;
  LSpins: Int32;
  LBackoff: Int32;
begin
  LSpins := 0;
  LBackoff := 1;
  repeat
    LLock := AtomicLoad32(AShard.Lock, moRelaxed);
    if LLock >= 0 then
    begin
      { 尝试增加读锁计数 }
      if AtomicCompareExchange32(AShard.Lock, LLock, LLock + 1, moAcquire) = LLock then
        Exit;
    end;
    { 有写锁，等待 }
    Inc(LSpins);
    if LSpins < 8 then
      CpuPause
    else if LSpins < 64 then
    begin
      { Exponential backoff }
      CpuPause;
      if LSpins mod LBackoff = 0 then
        LBackoff := LBackoff * 2;
    end
    else
    begin
      LSpins := 0;
      LBackoff := 1;
      platform_thread_yield;
    end;
  until False;
end;
```

### 3.2 Phase 4B: 无锁读路径 (4h)

**目标**: 使用版本号实现乐观读

**设计**:
```pascal
TShard = record
  Lock: Int32;
  Version: Int32;  // 新增：版本号
  Entries: array of TEntry;
  Count: PtrUInt;
  Capacity: PtrUInt;
  Mask: PtrUInt;
end;

function Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
  LVersion1, LVersion2: Int32;
begin
  LShardIdx := ShardIndex(AKey);
  repeat
    LVersion1 := AtomicLoad32(FShards[LShardIdx].Version, moAcquire);
    if LVersion1 and 1 <> 0 then
    begin
      { 正在写，等待 }
      CpuPause;
      Continue;
    end;
    { 乐观读 }
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
      AValue := FShards[LShardIdx].Entries[LIdx].Value;
    LVersion2 := AtomicLoad32(FShards[LShardIdx].Version, moAcquire);
    if LVersion1 = LVersion2 then
      Exit;  { 版本一致，读取有效 }
    { 版本不一致，重试 }
  until False;
end;
```

### 3.3 Phase 4C: 写路径优化 (2h)

**目标**: 写操作使用版本号标记，减少锁持有时间

**改动**:
```pascal
procedure Insert(const AKey: TKey; const AValue: TValue);
begin
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    AtomicFetchAdd32(FShards[LShardIdx].Version, 1, moRelease);  { 标记写开始 }
    { ... 写操作 ... }
    AtomicFetchAdd32(FShards[LShardIdx].Version, 1, moRelease);  { 标记写结束 }
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;
```

## 4. 测试计划

### 4.1 功能测试

- [ ] 基本 CRUD 操作
- [ ] 并发读写测试
- [ ] 边界条件测试

### 4.2 性能测试

- [ ] 读延迟基准测试
- [ ] 读吞吐基准测试
- [ ] 混合负载测试

### 4.3 压力测试

- [ ] 高并发读测试
- [ ] 读写混合压力测试
- [ ] 长时间稳定性测试

## 5. 风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| 版本号溢出 | 低 | 使用 Int32，溢出周期长 |
| ABA 问题 | 中 | 版本号单调递增，避免 ABA |
| 内存可见性 | 中 | 使用正确的内存序 |
| 性能回退 | 低 | 渐进式优化，可回滚 |

## 6. 验收标准

- [ ] 所有现有测试通过
- [ ] 读延迟降低 50%+
- [ ] 读吞吐提升 2x+
- [ ] 0 内存泄漏
- [ ] 0 竞态条件

## 7. 时间表

| 阶段 | 任务 | 工时 | 状态 |
|------|------|------|------|
| 4A | 读锁优化 | 2h | ⏳ 进行中 |
| 4B | 无锁读路径 | 4h | ⏸️ 待定 |
| 4C | 写路径优化 | 2h | ⏸️ 待定 |
| 测试 | 功能+性能 | 4h | ⏸️ 待定 |

**总计**: 12h
