{% ok %} -*- mode: conf -*-
# mem 模块 ROADMAP

## Phase 12 — 实用分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P12-1 | TRecyclingAllocator | Freelist 回收已释放内存块 | 7 |
| P12-2 | TCountingAllocator | 计数包装器，跟踪活跃分配数 | 7 |
| P12-3 | TZeroedAllocator | 零初始化包装器，GetMem 后清零 | 7 |
| P12-4 | TStatsCollector | 多分配器聚合统计 | 7 |

## Phase 13 — 高级分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P13-1 | TWatermarkAllocator | Checkpoint/rollback 线性分配器 | 7 |
| P13-2 | TArenaGroupAllocator | 组 ID 跟踪，批量 Reset | 7 |
| P13-3 | TLoggingAllocator | LogProc 回调包装器 | 7 |
| P13-4 | TRecyclingPoolAllocator | Size header 用于正确的 freelist 分桶 | 7 |

## Phase 14 — 专业分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P14-1 | TFreelistAllocator | Size-aware freelist with header | 7 |
| P14-2 | TGroupAllocator | Multi-group with FGroupSize field | 7 |

## Phase 15 — 扩展分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P15-1 | TSizedAllocator | SizeUInt header for O(1) MemSize | 7 |
| P15-2 | TPoolGrowAllocator | Auto-growing fixed-size pool | 7 |
| P15-3 | TRecyclingGroupAllocator | Per-size-class freelist recycling | 7 |

## Phase 16 — 分析分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P16-1 | TProfileAllocator | Size class profiling, peak bytes tracking | 7 |
| P16-2 | TPoolAutoAllocator | Auto-shrink pool with high-water mark | 7 |

## Phase 17 — 验证与路由分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P17-1 | TValidationAllocator | Alignment/size validation wrapper | 7 |
| P17-2 | TDualAllocator | Size-based routing with tag header | 7 |
| P17-3 | TSlidingAllocator | Push/Pop checkpoint linear allocator | 7 |
| P17-4 | TPageAllocator | Page-aligned allocation wrapper | 7 |

## Phase 18 — 生产级分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P18-1 | TSlabAllocator | 内核风格 slab 分配器，多 size class | 7 |
| P18-2 | TBatchAllocator | 批量分配器，减少锁开销 | 7 |
| P18-3 | TBitmapAllocator | 位图分配器，O(n) 扫描但最小内存开销 | 7 |
| P18-4 | TStackAllocator | 栈式分配器，LIFO 顺序，零碎片 | 7 |

**模块总计**: 68 allocator 文件 / ~1122 测试

## Phase 19 — 高级策略分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P19-1 | TAlignedAllocator | 对齐分配包装器，保证指定对齐 | 7 |
| P19-2 | TBumpAllocator | Bump/线性分配器，最快分配策略 | 7 |
| P19-3 | TCascadeAllocator | 级联分配器，多后端顺序尝试 | 7 |
| P19-4 | TCowAllocator | Copy-on-Write 分配器，共享内存 | 7 |

**模块总计**: 72 allocator 文件 / ~1150 测试

## Phase 20 — 工具分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P20-1 | TBoundedAllocator | 有界分配器，限制最大内存使用 | 7 |
| P20-2 | TCallbackAllocator | 回调分配器，用户自定义分配逻辑 | 7 |
| P20-3 | TFailAllocator | 失败分配器，OOM 故障注入测试 | 7 |
| P20-4 | TPrefixAllocator | 前缀分配器，O(1) 大小查询 | 7 |

**模块总计**: 76 allocator 文件 / ~1178 测试

## Phase 21 — 高级诊断分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P21-1 | TScopedAllocator | 作用域分配器，析构自动释放 | 7 |
| P21-2 | TSentinelAllocator | 哨兵分配器，溢出/double-free 检测 | 7 |
| P21-3 | TSizeClassAllocator | 大小类分配器，16 级 freelist | 7 |
| P21-4 | TPredictionAllocator | 预测分配器，热点分析 | 7 |

**模块总计**: 80 allocator 文件 / ~1206 测试

## Phase 22 — 系统级分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P22-1 | THugePageAllocator | 大页分配器，减少 TLB miss | 7 |
| P22-2 | TMmapAllocator | mmap 匿名映射分配器 | 7 |
| P22-3 | TThreadSafeAllocator | 线程安全包装器 | 7 |
| P22-4 | TSamplingAllocator | 采样分配器，1/N 采样记录 | 7 |

**模块总计**: 84 allocator 文件 / ~1234 测试

## Phase 23 — 诊断与平台分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P23-1 | TStatsAllocator | 统计包装器，跟踪分配指标 | 7 |
| P23-2 | TLeakCheckAllocator | 泄漏检查工具函数 | 7 |
| P23-3 | TDebugAllocator | 调试分配器，记录分配来源 | 7 |
| P23-4 | TCrtAllocator | CRT 分配器，使用 C 运行时 | 7 |

**模块总计**: 88 allocator 文件 / ~1262 测试

## Phase 24 — 基础与高级分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P24-1 | TRtlAllocator | FPC RTL 分配器包装器 | 7 |
| P24-2 | THotswapAllocator | 热切换分配器，运行时原子替换 | 8 |
| P24-3 | TReplayAllocator | 回放分配器，录制/回放分配模式 | 10 |
| P24-4 | TMappedFileAllocator | 内存映射文件分配器 | 7 |

**模块总计**: 92 allocator 文件 / ~1294 测试

## Phase 25 — 基础与平台分配器 ✅

| ID | 类名 | 描述 | 测试数 |
|----|------|------|--------|
| P25-1 | TAllocator (base) | 基类行为测试（mock 子类） | 7 |
| P25-2 | TMimallocAllocator | mimalloc 不可用时的优雅降级 | 7 |

**模块总计**: 92 allocator 文件 / ~1308 测试

## Phase 26 — 基础设施模块 ✅

| ID | 模块 | 描述 | 测试数 |
|----|------|------|--------|
| P26-1 | TMemMutex | 互斥锁 Init/Done/Acquire/Release | 7 |
| P26-2 | TMemRwLock | 读写锁 AcquireRead/ReleaseRead/AcquireWrite/ReleaseWrite | 9 |
| P26-3 | mem.error | 错误码、异常类型、对齐验证 | 8 |

**模块总计**: 92 allocator 文件 / ~1332 测试

## Phase 27 — 深化测试（压力/边界/并发） ✅

| ID | 测试套件 | 描述 | 测试数 |
|----|----------|------|--------|
| P27-1 | test_arena_stress | Arena 压力：1000 次分配/重置循环、碎片化 | 7 |
| P27-2 | test_pool_edge | Pool 边界：满池/空池/交错释放/增长 | 7 |
| P27-3 | test_threadsafe_concurrent | 并发：4 线程 × 1000 轮 × 32 分配 | 4 |
| P27-4 | test_oom_edge | OOM 边界：Bounded/Counting/Fail 极限条件 | 7 |

**模块总计**: 92 allocator 文件 / ~1357 测试

## Phase 28 — 深化测试（Realloc/对齐/组合/碎片化） ✅

| ID | 测试套件 | 描述 | 测试数 |
|----|----------|------|--------|
| P28-1 | test_realloc_edge | Realloc 边界：grow/shrink/nil/zero/same-size/multi-grow | 7 |
| P28-2 | test_alignment_guarantee | 对齐保证：16/32/64/4096 对齐验证 | 7 |
| P28-3 | test_composition | 分配器组合：Tracking+Aligned+Stats 链式组合 | 5 |
| P28-4 | test_fragmentation | 碎片化模式（已有）：holes/churn/RSS 测量 | — |

**模块总计**: 92 allocator 文件 / ~1376 测试

## Phase A — P0 Bug 修复 + ThreadSafe 修正 ✅

| ID | 修复 | 描述 |
|----|------|------|
| P0-1 | TZeroedAllocator.DoReallocMem | ReallocMem 零填充覆盖旧数据 → 移除 FillChar |
| P0-2 | TBumpAllocator.DoReallocMem | FRegionSize 作为 old size → OOB 读 → 标记 SupportsRealloc:=False |
| P0-3 | growing.pas 毒化值 | 分配路径用 MEM_POISON_FREED → 改为 MEM_POISON_ALLOC |
| P0-4 | 基类 ThreadSafe 默认值 | True → False，修复 33 个无锁 allocator 虚假声明 |
| P0-5 | THugePageAllocator | 无锁但声明 ThreadSafe:=True → 移除 |
| P0-6 | THotswapAllocator | 无锁但声明 ThreadSafe:=True → 移除 |
| QA-1 | 12 个测试文件 | Assert → Check（统一断言 API） |
