# mem 模块演化路线图 Phase 5

> **状态**: Phase 5 全部完成 ✅
> **起始**: 2026-07-08
> **完成**: 2026-07-08
> **基线**: 67 源文件 / 59 测试目录 / 695 测试
> **当前**: 71 源文件 / 63 测试目录 / 728 测试 / 0 失败 / 0 泄漏
> **前序**: Phase 1-4 全部完成

## 演化目标

从"生产级内存管理平台"演化为"企业级内存管理平台"，聚焦三个维度：
1. **性能增强** — 大页支持、内存压缩
2. **可观测性增强** — 分配回放、内存水位线
3. **集成增强** — 分配器注册表、配置驱动

---

## Phase 5: 企业级增强 (Enterprise)

| # | 项目 | 优先级 | 说明 |
|---|------|--------|------|
| P5-1 | Huge page support | P0 | THugePageAllocator: 大页分配器（2MB/1GB，减少 TLB miss） | ✅ |
| P5-2 | Memory watermark | P0 | TMemoryWatermark: 高/低水位线监控 + 回调 | ✅ |
| P5-3 | Allocator registry | P1 | TAllocatorRegistry: 分配器注册表（按名称查找/切换） | ✅ |
| P5-4 | Allocation replay | P2 | TReplayAllocator: 分配模式录制/回放（调试用） | ✅ |

---

### P5-1: Huge Page Support

**目标**: 使用大页（2MB/1GB）减少 TLB miss，提升大内存工作负载性能。

```pascal
THugePageSize = (hpsNormal, hps2MB, hps1GB);

THugePageStats = record
  Allocated: UInt64;      // 大页分配总字节
  Fallbacks: UInt64;      // 回退到普通页的次数
  HugePageCount: UInt64;  // 使用的大页数
end;

THugePageAllocator = class(TAllocator)
  constructor Create(AInner: IAllocator; APageSize: THugePageSize = hps2MB;
    AThreshold: SizeUInt = 2 * 1024 * 1024);
  function IsHugePage(APtr: Pointer): Boolean;
  function GetStats: THugePageStats;
  property PageSize: THugePageSize read FPageSize;
  property Threshold: SizeUInt read FThreshold;
end;
```

**实现策略**:
- 分配 >= Threshold 时尝试大页，失败回退普通页
- Linux: `mmap(MAP_HUGETLB)` 或 `madvise(MADV_HUGEPAGE)`
- 统计大页使用率和回退率
- 支持运行时切换页面大小

**源文件**: `core/src/nextpas.core.mem.allocator.huge_page.pas`
**测试**: `core/tests/nextpas.core.mem/test_huge_page/test_huge_page.lpr`

---

### P5-2: Memory Watermark

**目标**: 内存使用高/低水位线监控，触发回调进行降级/恢复。

```pascal
TWatermarkLevel = (wlNormal, wlHigh, wlCritical);

TWatermarkEvent = procedure(ALevel: TWatermarkLevel; AUsedBytes: UInt64) of object;

TMemoryWatermark = class
  constructor Create(AHighBytes: UInt64; ACriticalBytes: UInt64);
  procedure Check(AUsedBytes: UInt64);
  procedure RegisterHandler(ALevel: TWatermarkLevel; AHandler: TWatermarkEvent);
  function CurrentLevel: TWatermarkLevel;
  property HighBytes: UInt64 read FHighBytes;
  property CriticalBytes: UInt64 read FCriticalBytes;
end;
```

**实现策略**:
- 与 TAllocStatsAllocator 配合，每次分配后检查
- 高水位线：触发缓存释放/减少预分配
- 临界水位线：触发 OOM handler 链
- 回调链：多个 handler 按注册顺序调用

**源文件**: `core/src/nextpas.core.mem.watermark.pas`
**测试**: `core/tests/nextpas.core.mem/test_watermark/test_watermark.lpr`

---

### P5-3: Allocator Registry

**目标**: 分配器注册表，按名称查找/切换分配器。

```pascal
TAllocatorRegistry = class
  class function Instance: TAllocatorRegistry;
  procedure Register(const AName: string; AAllocator: IAllocator);
  function Get(const AName: string): IAllocator;
  function TryGet(const AName: string; out AAllocator: IAllocator): Boolean;
  procedure Unregister(const AName: string);
  function Names: TArray<string>;
end;
```

**实现策略**:
- 全局单例，线程安全
- 预注册：'default', 'guard', 'stats', 'arena' 等
- 支持配置驱动的分配器选择
- 名称查找 O(1)（哈希表）

**源文件**: `core/src/nextpas.core.mem.registry.pas`
**测试**: `core/tests/nextpas.core.mem/test_registry/test_registry.lpr`

---

### P5-4: Allocation Replay

**目标**: 录制分配模式，回放用于调试和性能分析。

```pascal
TReplayAllocator = class(TAllocator)
  constructor Create(AInner: IAllocator; AMaxRecords: SizeUInt = 1000000);
  procedure StartRecording;
  procedure StopRecording;
  function IsRecording: Boolean;
  procedure SaveToFile(const AFileName: string);
  procedure LoadFromFile(const AFileName: string);
  function ReplayCount: SizeUInt;
  procedure Replay(ATarget: IAllocator);
end;
```

**实现策略**:
- 录制：记录每次分配/释放的 (操作, 大小, 顺序号)
- 序列化：二进制格式，紧凑高效
- 回放：按相同顺序在目标分配器上重放
- 用途：重现生产环境的分配模式进行测试

**源文件**: `core/src/nextpas.core.mem.allocator.replay.pas`
**测试**: `core/tests/nextpas.core.mem/test_replay/test_replay.lpr`

---

## 执行顺序

```
P5-1 (Huge Pages) → P5-2 (Watermark) → P5-3 (Registry) → P5-4 (Replay)
```

**预估工作量**:
- P5-1: 1-2 天（mmap 大页 + 回退）
- P5-2: 1 天（水位线 + 回调链）
- P5-3: 1 天（注册表 + 预注册）
- P5-4: 2 天（录制/回放 + 文件序列化）

**总计**: 5-6 天，~8 个新文件，~1500 行代码，~60 新测试
