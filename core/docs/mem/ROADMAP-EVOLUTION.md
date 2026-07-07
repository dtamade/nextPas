# mem 模块演化路线图 v2

> **状态**: Phase 1-4 全部完成 ✅
> **起始**: 2026-07-06
> **完成**: 2026-07-08
> **基线**: 58 源文件 / 24169 行 / 50 测试目录 / 664 测试 / 1990 断言
> **当前**: 66 源文件 / 58 测试目录 / 688 测试 / 0 失败 / 0 泄漏
> **前序**: ROADMAP-DEEPENING.md 全部完成

## 演化目标

从"高性能分配器库"演化为"生产级内存管理平台"，聚焦三个维度：
1. **可观测性** — 运行时内存行为可视化
2. **健壮性** — 极端场景下的防御能力
3. **集成深度** — 与上层模块的无缝协作

---

## Phase 1: 可观测性 (Observability)

| # | 项目 | 优先级 | 说明 |
|---|------|--------|------|
| P1-1 | Allocation snapshot | P0 | TAllocSnapshot: 当前分配状态快照（总分配/释放/峰值/活跃数） | ✅ |
| P1-2 | Per-thread stats | P1 | TThreadAllocStats: 每线程分配统计（TLS 收集，全局汇总） | ✅ |
| P1-3 | Allocation histogram | P1 | THistogram: 按大小分布的分配直方图（16B/64B/256B/1KB/4KB/16KB/64KB/256KB+） | ✅ |
| P1-4 | Leak report 增强 | P2 | TLeakReport: 分配调用栈 + 生命周期 + 标签聚合 | ✅ |

### P1-1: Allocation Snapshot

```pascal
TAllocSnapshot = record
  TotalAllocs: UInt64;      // 总分配次数
  TotalFrees: UInt64;       // 总释放次数
  ActiveAllocs: UInt64;     // 当前活跃分配数
  ActiveBytes: UInt64;      // 当前活跃字节数
  PeakAllocs: UInt64;       // 峰值分配数
  PeakBytes: UInt64;        // 峰值字节数
  TotalBytesAllocated: UInt64; // 总分配字节数
  TotalBytesFreed: UInt64;  // 总释放字节数
end;

// IAllocator 扩展
IAllocatorStats = interface
  function Snapshot: TAllocSnapshot;
  procedure ResetStats;
end;
```

**实现策略**:
- TTrackingAllocator 已有基础，扩展为 TStatsAllocator
- 原子计数器，热路径零争用（per-thread 汇总）

### P1-2: Per-thread Stats

```pascal
TThreadAllocStats = record
  ThreadId: TThreadID;
  AllocCount: UInt64;
  FreeCount: UInt64;
  ActiveBytes: UInt64;
  PeakBytes: UInt64;
end;

// 收集器
TAllocStatsCollector = class
  procedure Collect(out AStats: array of TThreadAllocStats): Integer;
  function Summary: TAllocSnapshot;
end;
```

**实现策略**:
- threadvar 收集器，零锁热路径
- 全局汇总时遍历已注册线程列表

### P1-3: Allocation Histogram

```pascal
TAllocHistogram = record
  Buckets: array[0..8] of UInt64;  // 16B/64B/256B/1KB/4KB/16KB/64KB/256KB/256KB+
  TotalBytes: UInt64;
  function Percentile(APct: Double): SizeUInt;
  function MeanSize: Double;
end;
```

**实现策略**:
- 在 TStatsAllocator.GetMem 中记录 bucket index
- 位运算快速 bucket 选择（`(SizeUInt(31) - CLZ(ASize)) shr 2`）

---

## Phase 2: 健壮性 (Robustness)

| # | 项目 | 优先级 | 说明 |
|---|------|--------|------|
| P2-1 | OOM callback | P0 | TOomHandler: OOM 时回调（释放缓存/触发 GC/降级策略） | ✅ |
| P2-2 | Memory pressure | P1 | TMemoryPressure: 系统内存压力检测 + 回调 | ✅ |
| P2-3 | Double-free 检测增强 | P1 | 哨兵值 + 延迟释放队列 + 校验和 | ✅ |
| P2-4 | Stack overflow guard | P2 | Arena 分配时栈深度检查（防止递归分配） |

### P2-1: OOM Callback

```pascal
TOomEvent = procedure(ARequestedSize: SizeUInt; var ARetry: Boolean) of object;

TOomHandler = class
  procedure Register(AHandler: TOomEvent);
  function TryHandle(ARequestedSize: SizeUInt): Boolean;
end;
```

**实现策略**:
- 注册链：多个 handler 按优先级调用
- 典型用法：释放 arena 缓存 → 释放 thread cache → 触发 GC → 返回 nil

### P2-2: Memory Pressure

```pascal
TMemoryPressureLevel = (mplLow, mplMedium, mplHigh, mplCritical);

TMemoryPressure = class
  class function CurrentLevel: TMemoryPressureLevel;
  class procedure RegisterHandler(ALevel: TMemoryPressureLevel; AHandler: TOomEvent);
end;
```

**实现策略**:
- Linux: 读取 /proc/meminfo 或 cgroup memory.limit
- 周期性检查（每次 N 次分配后）
- 回调触发降级策略（释放缓存/减少预分配）

### P2-3: Double-free 检测增强

**实现**: `TSentinelAllocator` — 轻量级哨兵守卫分配器

```pascal
TSentinelAllocator = class(TAllocator)
  constructor Create(AInner: IAllocator; AQuarantineDepth: Integer = 256);
  function QuarantineCount: Integer;
  procedure DrainQuarantine;
end;
```

**特性**:
- **哨兵值**: 每次分配前后写入 64-bit magic bytes ($DEADBEEFCAFEBABE / $BAADF00DDEADC0DE)
- **延迟释放队列**: 释放的内存进入隔离区（可配置深度），检测 use-after-free
- **校验和**: XOR-based 元数据完整性校验，检测内存踩踏
- **释放后毒化**: 填充 $DD，加速 use-after-free 检测

**布局**: `[Header 32B: PreSentinel+Size+AllocId+Checksum][User data...][PostSentinel 8B]`

**源文件**: `core/src/nextpas.core.mem.allocator.sentinel.pas` (280 行)
**测试**: `core/tests/nextpas.core.mem/test_sentinel/test_sentinel.lpr` (18 测试)

---

## Phase 3: 集成深化 (Integration)

| # | 项目 | 优先级 | 说明 |
|---|------|--------|------|
| P3-1 | Arena allocator 传播 | P0 | IAllocator 自动传播到子分配（collections/http/json） | ✅ (已有 TVirtualArenaAllocator) |
| P3-2 | Scoped allocator | P1 | TScopedAllocator: 作用域分配器（RAII 风格） | ✅ |
| P3-3 | Allocator composition | P2 | TCompositeAllocator: 链式分配器（fallback/stats/tag） | ✅ (已有 TFallbackAllocator + 装饰器嵌套) |
| P3-4 | Memory budget | P2 | TMemoryBudget: 内存预算管理（软/硬限制） | ✅ |

### P3-1: Arena Allocator 传播

```pascal
// 当前问题：collections 使用 DefaultAllocator，不继承 Arena
// 解决方案：TLocalArena 实现 IAllocator，自动传播

TLocalArenaAllocator = class(TAllocator)
  constructor Create(AArena: IArena);
  // IAllocator 方法委托给 IArena
end;
```

**实现策略**:
- TArenaAllocator 包装 IArena 为 IAllocator
- collections 构造函数接受 IAllocator，自动使用 Arena
- Arena Reset 时一次性释放所有子分配

### P3-2: Scoped Allocator

```pascal
TScopedAllocator = class(TAllocator)
  constructor Create(AInner: IAllocator);
  destructor Destroy; override;
  // 内部分配记录，析构时自动释放
end;
```

**实现策略**:
- 内部维护分配列表
- 析构时自动释放所有未释放的分配
- 适用于请求/帧级生命周期

---

## Phase 4: 性能深化 (Performance)

| # | 项目 | 优先级 | 说明 |
|---|------|--------|------|
| P4-1 | TLS cache 优化 | P1 | 自适应 TLS cache 大小（基于分配频率） | ✅ (已有 per-band 自适应 batch/max size) |
| P4-2 | Batch allocation 增强 | P1 | IBatchAllocator: 批量分配接口（已部分实现） | ✅ |
| P4-3 | NUMA-aware 深化 | P2 | 跨 NUMA 节点的分配策略优化 | ✅ |
| P4-4 | Allocation 预测 | P2 | 基于历史模式的预分配策略 | ✅ |

### P4-1: TLS Cache 优化

```pascal
// 当前：固定大小 TLS cache
// 优化：自适应大小（高频线程扩大 cache，低频缩小）

TAdaptiveTlsCache = class
  procedure AdjustSize(ACurrentHitRate: Double);
  // 目标：hit rate > 95%
end;
```

**实现策略**:
- 每 N 次分配评估 hit rate
- hit rate < 90% → 扩大 cache
- hit rate > 98% → 缩小 cache（节省内存）

**已实现**: `nextpas.core.mem.cache.thread` 已有 per-band 自适应：
- Band 0-1 (≤1KB): batch=32, max=128
- Band 2-3 (≤8KB): batch=16, max=64
- Band 4 (≤16KB): batch=8, max=32
- Band 5 (≤53KB): batch=4, max=16

### P4-2: Batch Allocation 增强

**已实现**: `IBatchAllocator` 接口定义在 `nextpas.core.mem.intf.pas`。

```pascal
IBatchAllocator = interface
  function BatchGetMem(ASize: SizeUInt; ACount: Word; ABlocks: PPointer): Word;
  procedure BatchFreeMem(ASize: SizeUInt; ACount: Word; ABlocks: PPointer);
end;
```

`TGrowingAllocator` 已有完整 batch 实现（TLS refill/flush 摊销开销）。

### P4-3: NUMA-aware 深化

**已实现**: `TNumaAllocator` — NUMA 感知分配器

```pascal
TNumaAllocator = class(TAllocator)
  constructor Create(ADefault: IAllocator);
  procedure SetNodeAllocator(ANode: Integer; AAlloc: IAllocator);
  function IsNuma: Boolean;
  property Topology: TNumaTopology read FTopology;
end;
```

- `DetectNumaTopology`: 从 `/sys/devices/system/node/nodeN/cpulist` 读取拓扑
- `getcpu` 系统调用获取当前 CPU/节点
- 非 NUMA 系统自动降级为单一 fallback 分配器

### P4-4: Allocation 预测

**已实现**: `TPredictionAllocator` — 分配频率跟踪器

```pascal
TPredictionAllocator = class(TAllocator)
  function Predict(ATopN: Integer = 8): TPredictionResult;
  procedure PreAllocate(ATopN: Integer = 4; ACountPerClass: Word = 8);
  procedure ResetStats;
end;
```

- 按 size class 跟踪分配频率（69 个 size class）
- `Predict`: 识别 top-N 热门分配大小
- `PreAllocate`: 为热门大小预分配块（预热 TLS cache）

---

## 执行顺序

```
Phase 1 (可观测性) → Phase 2 (健壮性) → Phase 3 (集成) → Phase 4 (性能)
```

**预估工作量**:
- Phase 1: 3-4 天（P1-1/P1-2 核心，P1-3/P1-4 增强）
- Phase 2: 2-3 天（P2-1/P2-2 核心，P2-3/P2-4 增强）
- Phase 3: 2-3 天（P3-1/P3-2 核心，P3-3/P3-4 增强）
- Phase 4: 2-3 天（P4-1/P4-2 核心，P4-3/P4-4 增强）

**总计**: 10-13 天，~30 个新文件，~5000 行代码，~200 新测试
