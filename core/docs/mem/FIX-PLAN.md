# nextpas.core.mem 问题修复 — 实施规划

**编制日期**: 2026-07-05
**依据**: FIX-RESEARCH-REPORT.md 调研结论
**策略**: 最小修复策略（策略一），全面修复作为后续扩展

---

## 里程碑总览

```
M1: Guard 分配器修复 + 测试     (本轮)
M2: SpinLock + 命名规范         (本轮)
M3: TrackingAllocator 修复      (本轮)
M4: ReallocMem 边界测试         (本轮)
M5: TBlockPool IAllocator       (下轮，需确认)
M6: 文档注释 + 门面验证         (下轮)
M7: 压力测试补充               (下轮)
```

---

## M1: Guard 分配器修复 + 测试

**目标**: 修复 Guard 分配器的防御不完整问题
**依赖**: 无
**改动量**: ~60 行（4 行代码 + ~50 行测试）
**风险**: 低

### 步骤

1. **CODE-001**: `allocator.guard.pas:139` — DoReallocMem 添加 Magic 校验
   ```pascal
   // 在读取 header 前校验
   LHdr := PGuardHeader(PtrUInt(ADst) - HeaderSize);
   if LHdr^.Magic <> GUARD_MAGIC then
   begin
     {$IFDEF DEBUG}
     raise EAllocError.Create(aeInvalidPointer, '...');
     {$ELSE}
     Exit(nil);  // Release 模式返回 nil，不崩溃
     {$ENDIF}
   end;
   ```

2. **ARCH-002**: `allocator.guard.pas:163` — DoFreeMem Release 模式改为抛异常
   ```pascal
   // 移除 {$IFDEF DEBUG} ... {$ELSE} Exit {$ENDIF}
   // 统一抛异常（Guard 是调试分配器，性能不是首要目标）
   if LHdr^.Magic <> GUARD_MAGIC then
     raise EAllocError.Create(aeInvalidPointer, '...');
   ```

3. **TEST-002**: `test_guard.lpr` — 新增测试
   - `TestReallocPreservesData`: resize 后数据完整
   - `TestReallocInvalidPointer`: 传入非法指针 → 抛异常
   - `TestFreeInvalidPointer`: Release 模式下非法 FreeMem → 抛异常

### 验证

```bash
make -C core/tests/nextpas.core.mem/test_guard clean test
```

---

## M2: SpinLock backoff + 命名规范

**目标**: 改善 central pool 争用行为，统一编译开关命名
**依赖**: 无
**改动量**: ~30 行
**风险**: 极低

### 步骤

1. **CODE-003**: `central.pas:99` — SpinLock 添加 exponential backoff
   ```pascal
   procedure SpinLock(var ALock: SizeUInt);
   var
     LBackoff: UInt32;
   begin
     LBackoff := 1;
     while AtomicCmpExchange(ALock, 1, 0) <> 0 do
     begin
       // Exponential backoff: 1, 2, 4, 8, ..., 256 iterations
       var I: UInt32;
       for I := 0 to LBackoff - 1 do
         ; // busy wait (compiler may optimize to pause/yield)
       if LBackoff < 256 then
         LBackoff := LBackoff shl 1;
     end;
   end;
   ```

2. **NORM-001**: `FAF_MEM_DEBUG` → `NEXTPAS_MEM_DEBUG`
   - `pool.fixed.pas`: 3 处替换
   - `blockpool.pas`: 1 处替换
   - `blockpool.sharded.pas`: 1 处替换
   - `blockpool.growable.pas`: 1 处替换

3. **NORM-003**: `sizeclass.pas:34,41` — 注释 "0..59" → "0..61"

### 验证

```bash
make -C core/tests/nextpas.core.mem/test_concurrent_wrappers clean test
make -C core/tests/nextpas.core.mem/test_pool clean test
make -C core/tests/nextpas.core.mem/test_blockpool clean test
```

---

## M3: TrackingAllocator 异常路径修复

**目标**: 修复 DoFreeMem 异常路径下 double-free 检测失效
**依赖**: 无
**改动量**: ~15 行
**风险**: 低

### 步骤

1. **CODE-002**: `allocator.tracking.pas:346` — DoFreeMem 添加异常保护
   ```pascal
   procedure TTrackingAllocator.DoFreeMem(ADst: Pointer);
   var
     LSize: SizeUInt;
     LAllocId: QWord;
   begin
     if ADst = nil then Exit;
     FLock.Acquire;
     try
       if not MapDelete(PtrUInt(ADst), LSize, LAllocId) then
         raise EDoubleFree.Create(aeDoubleFree, '...');
       try
         FInner.FreeMem(ADst);
       except
         // 恢复跟踪记录，保持 double-free 检测能力
         MapInsert(PtrUInt(ADst), LSize, LAllocId);
         raise;
       end;
     finally
       FLock.Release;
     end;
   end;
   ```

### 验证

```bash
make -C core/tests/nextpas.core.mem/test_tracking_allocator clean test
```

---

## M4: ReallocMem 边界测试补充

**目标**: 补充 GrowingAllocator 和 Guard 的 ReallocMem 边界测试
**依赖**: M1（Guard 修复后才能测试）
**改动量**: ~70 行测试
**风险**: 零

### 步骤

1. **TEST-001**: `test_growing_allocator.lpr` — 新增测试
   - `TestReallocNilZero`: `ReallocMem(nil, 0, 0)` → nil
   - `TestReallocLargeToSmall`: 2048→1024（同 class 内 shrink）
   - `TestReallocCrossBoundary`: 64→65536（small→large mmap 路径）

2. **TEST-002**: `test_guard.lpr` — 新增测试（见 M1）

### 验证

```bash
make -C core/tests/nextpas.core.mem/test_growing_allocator clean test
make -C core/tests/nextpas.core.mem/test_guard clean test
make -C core/tests/nextpas.core.mem/test_stability clean test
```

---

## M5: TBlockPool IAllocator（需确认）

**目标**: TBlockPool 支持自定义 IAllocator
**依赖**: 无
**改动量**: ~120 行（80 行代码 + 40 行测试）
**风险**: 中（4 文件构造函数变更）

### 步骤

1. **ARCH-001**: `blockpool.pas` — 添加 IAllocator 支持
   - 新增 `FAllocator: IAllocator` 字段
   - 添加重载构造函数 `Create(ABlockSize, ACapacity, AAlignment, AAllocator)`
   - 默认构造函数使用 `GetRtlAllocator`
   - `Destroy` 通过 `FAllocator.FreeMem` 释放

2. 同步更新：
   - `blockpool.concurrent.pas`: 构造函数透传 IAllocator
   - `blockpool.sharded.pas`: 同上
   - `blockpool.growable.pas`: 同上

3. **ARCH-004**: 添加文档注释说明位图+free-list 设计理由

### 验证

```bash
make -C core/tests/nextpas.core.mem/test_blockpool clean test
make -C core/tests/nextpas.core.mem/test_concurrent_wrappers clean test
make -C core/tests/nextpas.core.mem/test_sharded_pools clean test
```

### 风险缓解

- 使用重载构造函数，现有调用方无需修改
- 逐步回归：先改 blockpool.pas，验证后再改子类

---

## M6: 文档注释 + 门面验证

**目标**: 补全核心内部模块文档，验证门面完整性
**依赖**: 无
**改动量**: ~120 行纯文档
**风险**: 零

### 步骤

1. **NORM-002**: 为以下文件的公开函数添加 `{** @desc *}` 注释：
   - `central.pas`: CentralPoolInit/Destroy/Alloc/Free/Scavenge
   - `cache.thread.pas`: ThreadCacheInit/Alloc/Free/Refill/Flush
   - `span.pas`: SpanInit/Alloc/Free/HasFree/IsEmpty
   - `shuffle.pas`: FreeListInsertShuffled
   - `sizeclass.pas`: SizeClassIndex/SizeClassSize/IsSizeClassable

2. **NORM-004**: 对照 ARCHITECTURE.md 验证 `mem.pool.pas` 门面
   - 检查是否有遗漏的类型 re-export
   - 补全缺失项

---

## M7: 压力测试补充

**目标**: 补充高争用和分片并发测试
**依赖**: M2（SpinLock backoff）
**改动量**: ~140 行测试
**风险**: 零

### 步骤

1. **TEST-003**: `test_concurrent_wrappers.lpr` — 新增
   - `TestArenaConcurrentHighContention`: 8 线程 × 5000 ops × Alloc/Reset 交替
   - `TestArenaConcurrentDeadlock`: 16 线程 × 1000 ops + 30s timeout

2. **TEST-004**: `test_sharded_pools.lpr` — 新增
   - `TestShardedPoolConcurrent`: 8 线程 × 10000 ops × Acquire/Release
   - `TestShardedPoolDistribution`: 验证分片路由均匀性

---

## 依赖关系图

```
M1 (Guard) ──────┐
                 ├──→ M4 (测试)
M2 (SpinLock) ───┤
                 │
M3 (Tracking) ───┘

M5 (BlockPool) ──── 独立

M6 (文档) ───────── 独立

M7 (压力测试) ────── 依赖 M2
```

---

## 预计总改动量

| 里程碑 | 代码行 | 测试行 | 文件数 |
|--------|--------|--------|--------|
| M1 | 4 | 50 | 2 |
| M2 | 15 | 0 | 5 |
| M3 | 8 | 0 | 1 |
| M4 | 0 | 70 | 2 |
| M5 | 80 | 40 | 5 |
| M6 | 120 | 0 | 6 |
| M7 | 0 | 140 | 2 |
| **合计** | **227** | **300** | **~15** |

---

## 不修复项清单（已评估后排除）

| 问题 | 排除原因 |
|------|---------|
| ARCH-003 ThreadArena 单例 | 无多实例需求，方案 C（推迟） |
| CODE-004 TLS cache 多实例 | 当前单实例够用 |
| CODE-006 AllocUnsafe 溢出 | Unsafe 方法的设计契约 |
| CODE-007 StartOffset | 非问题（Reset 后 UsedSize=0 正确） |
| CODE-008 Mutex Init 超时 | 内核调用卡死是 OS 级问题 |
| CODE-009 MapGrow tombstone | 影响可忽略 |
| ARCH-005 FallbackArena Reset | 设计如此，文档已说明 |
| ARCH-006 模块膨胀 | 长期架构问题，不在本轮 |
| ARCH-007 RingBuffer 定位 | 长期迁移，不在本轮 |
| BENCH-001 FindSpanIndex | 当前无性能问题 |
| BENCH-002 Growing IAllocator | 无多态需求 |
| BENCH-003/004 基准 | 低优先级 |
