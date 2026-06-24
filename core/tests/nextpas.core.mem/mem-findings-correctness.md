# mem-findings: 正确性 + 安全性

## 统计
- 总发现: 18
- critical: 2, major: 7, minor: 9

## Findings

### [CS-001] blockpool.growable 缺少 pool.base uses 导致编译失败（已知）
- **严重度**: critical
- **文件**: `nextpas.core.mem.blockpool.growable.pas` 行 16-20
- **描述**: uses 列表缺少 `nextpas.core.mem.pool.base`，但实现中 `AcquireN`（行 682）和 `ReleaseN`（行 687）调用了 `DefaultAcquireN`/`DefaultReleaseN`，这两个函数定义在 `pool.base.pas` 中。已知编译错误，导致 `test_sharded_pools` 和 `test_oom` 测试无法运行。
- **影响**: 两个测试编译失败，`TGrowingBlockPool` 的批量 API 无法使用。
- **建议修复方向**: 在 uses 列表中添加 `nextpas.core.mem.pool.base`。

### [CS-002] NextPowerOfTwo 在 SizeUInt 接近最大值时无限循环
- **严重度**: critical
- **文件**: `nextpas.core.mem.base.pas` 行 49-54
- **描述**: `NextPowerOfTwo` 使用 `Result := Result shl 1` 循环倍增。当 `AValue > 2^(SizeUInt位数-1)` 时（例如 64 位系统上 AValue > 2^63），`Result` 左移到全零后与 AValue 的比较永远为 `True`，导致无限循环。该函数被 `blockpool.sharded.pas`、`pool.slab.sharded.pas`、`pool.slab.pas` 等多处调用来计算哈希表容量。
- **影响**: 若传入极大值，程序会永久挂起。虽然当前调用点不太可能传入如此大的值，但这是一个基础工具函数，应该安全。
- **建议修复方向**: 添加上界保护，当 `Result > High(SizeUInt) shr 1` 时直接返回 `AValue` 或抛异常。

### [CS-003] AlignUp 在 mem.base.pas 中存在整数溢出风险
- **严重度**: major
- **文件**: `nextpas.core.mem.base.pas` 行 56-59
- **描述**: `AlignUp` 计算 `(AValue + AAlignment - 1) and not (AAlignment - 1)`。当 `AValue` 接近 `High(SizeUInt)` 且 `AAlignment` 较大时，`AValue + AAlignment - 1` 可能溢出回绕到小值，导致返回一个比 `AValue` 更小的错误地址。此函数被 `blockpool.growable.pas`、`arena.growable.pas` 等内部调用。
- **影响**: 在极端边界条件下（极大容量请求），溢出可能产生错误的对齐结果。
- **建议修复方向**: 添加溢出检测，例如 `if AValue > High(SizeUInt) - (AAlignment - 1) then raise`。

### [CS-004] ngx_slab_sizes_init 缺少 memory barrier
- **严重度**: major
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas` 行 284-301
- **描述**: 使用 `InterlockedCompareExchange` 保证只有一个线程执行初始化，但初始化结果（`ngx_slab_max_size`、`ngx_slab_exact_size`、`ngx_slab_exact_shift`）是普通写入，没有任何 memory barrier。在弱内存序架构（ARM）上，其他线程可能在 `InterlockedCompareExchange` 返回后读到未完全初始化的值。
- **影响**: 在 ARM 平台上，`ngx_slab_alloc_locked` 可能看到零值的 `ngx_slab_max_size`，导致分配逻辑错误。
- **建议修复方向**: 初始化完成后对 `ngx_slab_sizes_initialized` 使用 `InterlockedExchange`（带 release 语义），或使用 `atomic_store` 带 `mo_release`，读取端使用 `atomic_load` 带 `mo_acquire`。

### [CS-005] TFixedSlabPool.AllocMem 只清零 aSize 字节，可能不足
- **严重度**: major
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas` 行 1587-1592
- **描述**: `AllocMem` 调用 `GetMem(aSize)` 后用 `FillChar(Result^, aSize, 0)` 清零。但 slab 分配器返回的实际块大小（由 size class 决定）可能大于 `aSize`。剩余部分保留了旧数据（上一次分配的残留），可能泄露敏感信息。
- **影响**: 安全性问题。调用者可能假设 `AllocMem` 返回的整块内存为零，但超出请求大小的部分包含旧数据。虽然当前 Traits 声明 `ZeroInitialized := True`，但实际只清零了请求大小。
- **建议修复方向**: 改为清零实际块大小（通过 `ChunkSizeOf` 或 `MemSizeOf` 获取）。

### [CS-006] TSlabPool.AllocMem 同样只清零请求大小
- **严重度**: major
- **文件**: `nextpas.core.mem.pool.slab.pas` 行 1114-1115
- **描述**: 与 CS-005 相同的问题。`FillChar(Result^, aSize, 0)` 只清零 `aSize` 字节，但底层 slab 分配的块可能更大。Traits 也声明 `ZeroInitialized := True`。
- **影响**: 同 CS-005，信息泄露风险。
- **建议修复方向**: 使用 `MemSizeOf(Result)` 获取实际大小后清零。

### [CS-007] TShardedBlockPool.Release 路由可能因路由表更新不及时而失败
- **严重度**: major
- **文件**: `nextpas.core.mem.blockpool.sharded.pas` 行 1178-1217
- **描述**: `Release` 调用 `TryRoute` 查找指针所属的 shard。如果路由表尚未更新（新 shard 的 segment 还没被 index），`TryRoute` 会返回 `False`，导致抛出 `aeInvalidPointer` 异常。虽然 `Acquire` 路径中有 `IndexShardNewSegmentsLocked`，但 `Release` 之前可能是在另一个线程分配的，新 segment 信息还没有传播到路由表。
- **影响**: 在高并发场景下，线程 A 从 shard 0 分配指针，线程 B 释放时可能因路由表未及时更新而失败。实际上当前代码中 `Release` 路径也持有 shard 锁并调用 `FlushRemoteFreesLocked`，所以路由表应该已经更新——但 `TryRoute` 在锁外执行，存在 TOCTOU 窗口。
- **建议修复方向**: 在 `TryRoute` 失败时，加锁重试一次（double-check pattern），或在 `Release` 内部在 shard 锁内做路由。

### [CS-008] TShardedBlockPool.RouteWriteLock 存在潜在活锁
- **严重度**: major
- **文件**: `nextpas.core.mem.blockpool.sharded.pas` 行 320-351
- **描述**: `RouteWriteLock` 使用自旋等待：先设置 `ROUTING_WAIT_BIT` 阻止新读者，然后等待读者清零。但如果读者长期持有锁（例如大量并发读），writer 可能长时间自旋。`platform_thread_yield` 在某些调度器下效果不佳。此外，`atomic_compare_exchange_weak` 只比较 `LState`（可能是旧值），如果多个 writer 同时竞争，可能导致活锁。
- **影响**: 极端并发下 writer 可能长时间无法获取写锁。
- **建议修复方向**: 添加退避策略（exponential backoff），或考虑使用系统级 rwlock 代替自旋实现。

### [CS-009] TShardedBlockPool.ThreadCache TLS 节点泄漏
- **严重度**: major
- **文件**: `nextpas.core.mem.blockpool.sharded.pas` 行 850-908
- **描述**: `GetThreadCacheNode` 使用 `GetMem` 分配 TLS 缓存节点，链入 `GShardedBlockPoolThreadCacheHead`。当线程退出时，这些节点不会被释放（threadvar 没有析构回调）。析构函数中也没有遍历释放这些节点。代码注释（行 962-964）承认了这个问题并禁用了 thread cache（`FThreadCacheCapacity := 0`），但 `GetThreadCacheNode` 函数仍然会被编译，如果将来启用会导致泄漏。
- **影响**: 当前被禁用所以无影响。但如果将来启用 thread cache，每个线程退出时泄漏 `SizeOf(TThreadCacheNode) + FShardCount * SizeOf(TRemoteFreeBuf)` 字节。
- **建议修复方向**: 在 pool 析构时遍历 `GShardedBlockPoolThreadCacheHead` 释放属于当前 pool 的节点，或使用 `ReleaseMem` callback。

### [CS-010] TStackPool.RestoreState 不验证 aState 语义
- **严重度**: minor
- **文件**: `nextpas.core.mem.stack_pool.pas` 行 431-435
- **描述**: `RestoreState` 接受任意 `SizeUInt` 值，仅检查 `aState <= FSize`。如果调用者传入的是从另一个 pool 实例获取的 state，或是一个随机值，会静默地将 `FOffset` 设为错误位置，后续分配可能覆盖已有数据。
- **影响**: 调用者误用时不会得到任何警告，可能导致数据损坏。
- **建议修复方向**: 可以考虑添加一个 generation 计数器来验证 state 来源，但这会增加复杂度。至少添加文档说明。

### [CS-011] TStackPool.Alloc 对齐计算可能溢出
- **严重度**: minor
- **文件**: `nextpas.core.mem.stack_pool.pas` 行 389-413
- **描述**: `AlignOffset` 计算 `(aOffset + aAlignment - 1) and not (aAlignment - 1)`，当 `aOffset` 接近 `High(SizeUInt)` 时可能溢出。虽然后续有 `if (LAlignedOffset > FSize)` 的检查，但溢出后 `LAlignedOffset` 可能变成一个很小的值，通过边界检查。
- **影响**: 极端情况下可能返回池外的指针。
- **建议修复方向**: 在 `AlignOffset` 中添加溢出检查，或在调用前确保 `FSize` 不会接近 `High(SizeUInt)`。

### [CS-012] TRingBuffer.Push 批量操作使用 mod 而 GetNextIndex 使用位与
- **严重度**: minor
- **文件**: `nextpas.core.mem.ring_buffer.pas` 行 374, 429
- **描述**: 批量 `Push` 和 `Pop` 使用 `FTail := (FTail + LToWrite) mod FCapacity`，而单元素操作使用 `GetNextIndex`（对 2 的幂容量使用位与优化）。批量操作没有利用 `FIsPow2Capacity` 优化，且 `mod` 在 FPC 中可能比位与慢很多。
- **影响**: 性能不一致，批量操作比预期慢。
- **建议修复方向**: 批量操作中也使用 `FIsPow2Capacity` 判断，对 2 的幂容量使用位与。

### [CS-013] TRingBuffer.Clear 不清零数据可能泄露敏感信息
- **严重度**: minor
- **文件**: `nextpas.core.mem.ring_buffer.pas` 行 450-456
- **描述**: `Clear` 只重置头尾指针和计数，不清零缓冲区内容。注释说明是"出于性能考虑"。如果 ring buffer 存储了敏感数据（如密码、密钥），`Clear` 后数据仍残留在内存中。
- **影响**: 安全敏感场景下信息泄露。
- **建议修复方向**: 可选的安全清零参数，或在安全相关的子类中覆盖。

### [CS-014] TSlabPool.Shard 路由中 PageMap 用 key+1 但 Lookup 不加 1
- **严重度**: minor
- **文件**: `nextpas.core.mem.pool.slab.sharded.pas` 行 275-308
- **描述**: `PageMapInsert` 行 280 有 `if aKey = 0 then aKey := 1`，将 page key 0 映射为 1（保留 0 为空标记）。`PageMapLookup` 行 295 也有同样的转换。但 `FPageKeys` 存储的值就是转换后的 key。如果实际有两个不同的地址，一个映射到 key 0，一个映射到 key 1，它们会被视为同一个 key。key 0 和 key 1 在 hash map 中会冲突。
- **影响**: 在极端地址布局下（指针地址恰好落在两个相邻 page 边界），可能路由到错误的 shard。但实际中这种概率极低，因为 0 号 page 通常在内核空间。
- **建议修复方向**: 存储 `aKey + 1` 而不是直接替换为 1，查询时也用 `aKey + 1` 查找，以避免 0 和 1 的碰撞。

### [CS-015] TBlockPoolConcurrent.Available/InUse 未加锁读取
- **严重度**: minor
- **文件**: `nextpas.core.mem.blockpool.concurrent.pas` 行 199-217
- **描述**: `BlockSize`、`Capacity`、`Available`、`InUse` 属性直接读取 `FInner` 的字段，没有加锁。虽然这些是只读操作，但在并发环境下 `FInner` 的状态可能正在被其他线程修改（例如 `Reset`），读到的值可能是中间状态。
- **影响**: 返回值可能不一致（例如 Capacity 读到新值但 Available 读到旧值），但不会导致崩溃。
- **建议修复方向**: 如果需要一致性快照，这些属性也应该在锁内读取。至少文档说明返回值是近似值。

### [CS-016] TFixedSlabPool.FreeMem 释放后不擦除数据
- **严重度**: minor
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas` 行 1623-1638
- **描述**: `FreeMem` 释放 slab 块后不清零内容。如果块中存储了敏感信息（密钥、密码），释放后数据仍残留在 slab 内存中，可能被后续分配读取。DEBUG 模式下的 `ngx_slab_junk` 用 `$A5` 填充，但这不是安全擦除。
- **影响**: 安全敏感场景下信息泄露。
- **建议修复方向**: 提供可选的安全擦除模式（例如 `SecureFree` 方法），在释放前用 `SecureZeroMemory` 清零。

### [CS-017] TSlabPool 自身无保护的线程安全声明缺失
- **严重度**: minor
- **文件**: `nextpas.core.mem.pool.slab.pas` 全文
- **描述**: `TSlabPool` 注释明确说明"不是线程安全的"，`Traits.ThreadSafe := False`。但其内部使用的 `TFixedSlabPool` 同样声明 `ThreadSafe := False`。问题在于 `TSlabPool` 的并发包装 `TSlabPoolConcurrent` 用单个 mutex 保护所有操作，而 `TSlabPoolSharded` 用分片锁——两者都是正确的。但如果有人直接在多线程中使用裸 `TSlabPool`，没有任何编译期或运行时警告。
- **影响**: 误用风险，但这是 API 使用者的问题而非实现缺陷。
- **建议修复方向**: 可以在 `DEBUG` 模式下添加线程 ID 检测，在检测到多线程并发访问时发出警告。

### [CS-018] TGrowingArena.RestoreToMark 不处理 FActive < 0 的情况
- **严重度**: minor
- **文件**: `nextpas.core.mem.arena.growable.pas` 行 589-626
- **描述**: `RestoreToMark` 在二分查找后直接使用 `LActiveIdx` 作为 `FSegments` 索引。如果 `FSegments` 为空（`Length = 0`），循环不会执行（因为 `LLeft = 0 > LRight = -1` 时 `while` 不进入），`LActiveIdx = 0`，但后续 `FSegments[LActiveIdx]` 会越界。代码行 603-604 检查了 `Length(FSegments) = 0` 的情况直接 Exit，所以实际上不会触发。但 `LMark = 0` 且只有一个 segment 且 `Segment[0].StartOffset = 0` 且 `Segment[0].Size = 0` 时，`LSegOffset = 0 = Size`，会进入行 620-624 的分支尝试 `Inc(LActiveIdx)`，如果 `LActiveIdx < High(FSegments)` 为 False 则保持原值，后续 `NormalizeState(0, 0)` 是安全的。
- **影响**: 当前不会触发，但代码逻辑较脆弱。
- **建议修复方向**: 添加 `Assert(LActiveIdx >= 0) and (LActiveIdx <= High(FSegments))` 防御性检查。
