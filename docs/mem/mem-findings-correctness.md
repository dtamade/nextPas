# mem-findings: 正确性 + 安全性

## 统计
- 总发现: 18
- critical: 2, major: 7, minor: 9
- 已修复: 12, 仍开放: 6 (CS-007/008/009/014/016/017)

---

### [CS-001] blockpool.growable 缺少 pool.base uses 导致编译失败 — ✅ 已修复
- **严重度**: critical → 已关闭
- **文件**: `nextpas.core.mem.blockpool.growable.pas`
- **状态**: uses 列表已包含 `nextpas.core.mem.pool.base`，`test_sharded_pools` (9/9) 和 `test_oom` (8/8) 编译运行通过。

### [CS-002] NextPowerOfTwo 在 SizeUInt 接近最大值时无限循环 — ✅ 已修复
- **严重度**: critical → 已关闭
- **文件**: `nextpas.core.mem.base.pas` 行 65-66
- **状态**: 已添加上界保护 `if AValue > (1 shl 63) then Exit(AValue)`

### [CS-003] AlignUp 在 mem.base.pas 中存在整数溢出风险 — ✅ 已修复
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.base.pas` 行 72-80
- **状态**: 已改用溢出安全公式 `LPad := (not AValue + 1) and (AAlignment - 1); Result := AValue + LPad`

### [CS-004] ngx_slab_sizes_init 缺少 memory barrier — ✅ 已修复
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas` 行 ~300
- **状态**: 在计算完成后添加 `InterlockedExchange(ngx_slab_sizes_initialized, 1)` 提供 release 语义。修复于 2026-06-29 审计第四轮。

### [CS-005] TFixedSlabPool.AllocMem 只清零 aSize 字节 — ✅ 已修复
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas` 行 1587-1601
- **状态**: 已改用 `LActualSize := MemSizeOf(Result)` 清零实际分配块大小。

### [CS-006] TSlabPool.AllocMem 同样只清零请求大小 — ✅ 已修复
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.pool.slab.pas` 行 1120-1135
- **状态**: 已改用 `LActualSize := MemSizeOf(Result)` 清零实际分配块大小。

### [CS-007] TShardedBlockPool.Release 路由可能因路由表更新不及时而失败 — ✅ 非 bug
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.blockpool.sharded.pas`
- **状态**: 深入分析确认 `IndexShardNewSegmentsLocked` 在 `Acquire` shard 锁内执行，路由在指针返回前已发布。无 TOCTOU 窗口。

### [CS-008] TShardedBlockPool.RouteWriteLock 存在潜在活锁 — ✅ 已修复
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.blockpool.sharded.pas` 行 269-345
- **状态**: RouteReadLock 和 RouteWriteLock 均添加 exponential backoff (cpu_pause 1→2→4→...→256)。CAS 失败路径不再是紧自旋。修复于 2026-06-29。

### [CS-009] TShardedBlockPool.ThreadCache TLS 节点泄漏 — ✅ 已确认安全
- **严重度**: major → 已关闭
- **文件**: `nextpas.core.mem.blockpool.sharded.pas` 行 850-908
- **状态**: 缓存已禁用 (`FThreadCacheCapacity := 0` + raise if >0)，`GetThreadCacheNode` 守卫返回 nil，无节点分配，无泄漏。启用需实现 thread-exit hook + pool-destroy 清理。

### [CS-010] TStackPool.RestoreState 不验证 aState 语义 — ✅ 已文档化
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.stack_pool.pas` 行 142
- **状态**: 注释已说明 "aState 必须来自同一 pool 实例的 SaveState 调用，否则行为未定义"。

### [CS-011] TStackPool.AlignOffset 对齐计算可能溢出 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.stack_pool.pas` 行 499-507
- **状态**: 添加溢出保护 `if aOffset > High(SizeUInt) - (aAlignment - 1) then Exit(High(SizeUInt))`。修复于 2026-06-29 审计第四轮。

### [CS-012] TRingBuffer.Push 批量操作使用 mod — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.ring_buffer.pas`
- **状态**: 所有索引操作统一使用 `AdvanceIndex`，支持 pow2 位与优化。

### [CS-013] TRingBuffer.Clear 不清零数据 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.ring_buffer.pas` 行 515-523
- **状态**: `Clear` 现在调用 `nextpas.core.mem.utils.Zero(FBuffer, FCapacity * FElementSize)` 清零。

### [CS-014] TSlabPool.Shard 路由中 PageMap key 0/1 碰撞 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.pool.slab.sharded.pas` 行 237-270
- **状态**: Insert/Lookup 统一使用 `aKey+1` 存储和查询，保留 0 为空标记，消除碰撞。修复于 2026-06-29。

### [CS-015] TBlockPoolConcurrent.Available/InUse 未加锁读取 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.blockpool.concurrent.pas` 行 204-222
- **状态**: `Available` 和 `InUse` 已在 `FLock` 内读取。

### [CS-016] TFixedSlabPool.FreeMem 释放后不擦除数据 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas`
- **状态**: 新增 `SecureFree` 方法：释放前用 `SecureZeroMemory(ADst, LSize)` 清零实际分配块大小，防止敏感信息残留。关键顺序：先清零再释放。test_slab_pool 17/17 通过。修复于 2026-06-29。

### [CS-017] TSlabPool 自身无保护的线程安全声明缺失 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.pool.slab.pas`
- **状态**: DEBUG 模式下 GetMem/FreeMem 检测跨线程访问并抛出 EAllocError。RELEASE 模式零开销。修复于 2026-06-29。

### [CS-018] TChunkedArena.RestoreToMark SizeUInt 减法下溢 — ✅ 已修复
- **严重度**: minor → 已关闭
- **文件**: `nextpas.core.mem.arena.chunked.pas` 行 ~642
- **状态**: 二分搜索后添加 `if LMark < FSegments[LActiveIdx].StartOffset then raise` 防止下溢。修复于 2026-06-29 审计第四轮。
