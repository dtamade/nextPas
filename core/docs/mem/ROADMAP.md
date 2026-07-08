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
