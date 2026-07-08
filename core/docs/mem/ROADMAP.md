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
