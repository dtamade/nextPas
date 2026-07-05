# Phase 2C 调研报告：Cross-Thread Free 直接投递优化

> **调研日期**: 2026-07-05
> **目标**: 让 cross-thread free 直接 push 到目标线程的 per-thread inbox，绕过 central inbox

---

## 一、当前架构分析

### 1.1 Cross-Thread Free 路径

**当前路径**：
```
Thread B 释放 Thread A 分配的块
  → push 到 Thread B 的 TLS cache
  → TLS cache 满时 flush 到 central inbox (CAS lock-free)
  → Thread A 分配时 GrabInboxChain (lock-free) + ProcessInboxChain (spinlock)
```

**问题**：
1. 块经过 Thread B 的 TLS cache，增加延迟
2. Central inbox 需要 spinlock 保护，增加竞争
3. Thread A 需要从 central inbox drain，增加 spinlock 持有时间

### 1.2 竞品方案对标

**Go runtime (mcache/mcentral)**：
- mcache 是 per-P 的，不是 per-thread 的
- GC sweep 统一回收，不关心是谁分配的
- mcentral 使用 lock-free spanSet

**mimalloc**：
- 两级 Delayed-Free：page 级 + heap 级
- 第一个跨线程释放需要访问 heap 级（1 次 CAS）
- 后续跨线程释放全部在 page 级完成（1 次 CAS）

**snmalloc**：
- MPSC 消息队列
- pagemap 元数据绑定：一次查表判断本地/远程
- 本地缓存 → ring batching → MPSC queue

---

## 二、问题分析

### 2.1 核心问题

**如何知道块属于哪个线程？**

**方案 A：在块中存储 owner 线程 ID**
- 优点：简单直接
- 缺点：增加内存开销，需要修改块布局

**方案 B：全局 registry 映射块地址 → 线程 ID**
- 优点：不需要修改块布局
- 缺点：需要维护全局 registry，查找开销大

**方案 C：使用 span 元数据存储 owner 线程 ID**
- 优点：不需要修改块布局，利用现有 span 结构
- 缺点：需要持有 spinlock 查询

### 2.2 方案对比

| 方案 | 内存开销 | 查找开销 | 实现复杂度 | 线程安全 |
|------|----------|----------|------------|----------|
| 块内存储 | +8 bytes/block | O(1) | 低 | 高 |
| 全局 registry | +256 bytes | O(1) 哈希 | 中 | 中 |
| span 元数据 | 0 | O(N) 扫描 | 低 | 需要 spinlock |

---

## 三、推荐方案

### 3.1 方案 C：Span 元数据存储 Owner Thread ID

**实现思路**：
1. 在 `TCentralSpanEntry` 中添加 `FOwnerThreadId: QWord`
2. 在 `AddSpan` 时设置 `FOwnerThreadId := GetCurrentThreadId`
3. 在 `FreeMem` 时查询 span 的 owner
4. 如果 owner 是其他线程，push 到 owner 的 per-thread inbox

**优点**：
- 不修改块布局，零内存开销
- 利用现有 span 结构
- 实现简单

**缺点**：
- 查询需要持有 spinlock（但已经在 FreeMem 中持有）
- 跨线程释放时需要查询 central pool

### 3.2 实现方案

**步骤 1：修改 TCentralSpanEntry**
```pascal
TCentralSpanEntry = record
  FSpan: TSpan;
  FMemory: Pointer;
  FMemorySize: SizeUInt;
  FLastFreeTick: UInt64;
  FOwnerThreadId: QWord;  { 新增：owner 线程 ID }
end;
```

**步骤 2：修改 AddSpan**
```pascal
function AddSpan(var APool: TCentralPool): Int32;
begin
  ...
  APool.FEntries[LIdx].FOwnerThreadId := GetCurrentThreadId;
  ...
end;
```

**步骤 3：添加 FindSpanOwnerThreadId**
```pascal
function FindSpanOwnerThreadId(var APool: TCentralPool; APtr: Pointer): QWord;
var
  I: Int32;
begin
  // 先查 MRU cache
  I := APool.FLastHitIndex;
  if (I >= 0) and (I < APool.FEntryCount) then
    if InSpanRange(APool.FEntries[I], APtr) then
      Exit(APool.FEntries[I].FOwnerThreadId);
  // 反向扫描
  for I := APool.FEntryCount - 1 downto 0 do
    if InSpanRange(APool.FEntries[I], APtr) then
    begin
      APool.FLastHitIndex := I;
      Exit(APool.FEntries[I].FOwnerThreadId);
    end;
  Result := 0;
end;
```

**步骤 4：修改 FreeMem**
```pascal
procedure TGrowingAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
var
  LOwnerThreadId: QWord;
  LOwnerCache: Pointer;
begin
  ...
  { 计算 size class index }
  LIndex := SizeClassIndex(ASize);
  
  { 查询块的 owner 线程 }
  LOwnerThreadId := FindSpanOwnerThreadId(FCentrals[LIndex], APtr);
  
  { 如果是其他线程的块，push 到 owner 的 per-thread inbox }
  if (LOwnerThreadId <> 0) and (LOwnerThreadId <> GetCurrentThreadId) then
  begin
    LOwnerCache := FindThreadCache(LOwnerThreadId);
    if LOwnerCache <> nil then
    begin
      ThreadCacheInboxPush(TThreadCache(LOwnerCache^), LIndex, APtr);
      Exit;
    end;
  end;
  
  { 同线程释放：push 到本地 TLS cache }
  ...
end;
```

---

## 四、风险评估

### 4.1 性能风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| FindSpanOwnerThreadId 开销 | 中 | 低 | 使用 MRU cache |
| spinlock 竞争 | 中 | 低 | 已在 FreeMem 中持有 |
| 全局 registry 查找开销 | 中 | 低 | 使用哈希表 |

### 4.2 正确性风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 线程退出后 inbox 泄漏 | 高 | 中 | 完善线程退出清理 |
| 竞态条件 | 高 | 低 | 使用 atomic 操作 |
| 块归属错误 | 高 | 低 | 严格测试 |

---

## 五、实施计划

### 5.1 里程碑

| 阶段 | 内容 | 预计工作量 | 依赖 |
|------|------|------------|------|
| M1 | TCentralSpanEntry 添加 FOwnerThreadId | 1 轮 | — |
| M2 | FindSpanOwnerThreadId 实现 | 1 轮 | M1 |
| M3 | FreeMem 跨线程释放路径 | 1 轮 | M2 |
| M4 | 测试与验证 | 1 轮 | M3 |

### 5.2 测试计划

1. **单元测试**：验证 FindSpanOwnerThreadId 正确性
2. **并发测试**：验证跨线程释放路径
3. **压力测试**：高并发场景下的正确性
4. **性能测试**：对比优化前后的性能

---

## 六、结论

### 6.1 推荐方案

**方案 C：Span 元数据存储 Owner Thread ID**

**理由**：
1. 不修改块布局，零内存开销
2. 利用现有 span 结构，实现简单
3. 查询开销低（MRU cache + 反向扫描）
4. 与现有架构兼容

### 6.2 预期收益

| 场景 | 当前 | 优化后 | 提升 |
|------|------|--------|------|
| Cross-thread free | ~25ns | ~15ns | 1.7x |
| Central spinlock 竞争 | 高 | 低 | — |
| 分配时 inbox drain | 需要 spinlock | lock-free | — |

### 6.3 下一步

1. 实施 M1-M4
2. 运行完整测试套件
3. 性能基准测试验证
4. 更新文档

---

**调研完成时间**: 2026-07-05
**调研人**: Claude (mem module owner)
