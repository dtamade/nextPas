# mem 模块演化路线图 Phase 6

> **状态**: Phase 6 全部完成 ✅
> **起始**: 2026-07-08
> **完成**: 2026-07-08
> **基线**: 71 源文件 / 63 测试目录 / 728 测试
> **当前**: 75 源文件 / 67 测试目录 / 757 测试 / 0 失败
> **前序**: Phase 1-5 全部完成

## 演化目标

从"企业级内存管理平台"演化为"全功能内存管理平台"，聚焦三个维度：
1. **碎片治理** — 内存压缩、碎片整理
2. **运行时灵活性** — 分配器热切换、运行时配置
3. **持久化集成** — 内存映射文件分配器

---

## Phase 6: 全功能增强 (Full-Featured)

| # | 项目 | 优先级 | 说明 |
|---|------|--------|------|
| P6-1 | Memory compaction | P0 | TCompactArena: 内存碎片整理（arena 内压缩） | ✅ |
| P6-2 | Allocator hotswap | P1 | THotswapAllocator: 运行时分配器切换（原子替换） | ✅ |
| P6-3 | Mapped file allocator | P2 | TMappedFileAllocator: 内存映射文件分配器（持久化） | ✅ |
| P6-4 | Allocation sampler | P2 | TSamplingAllocator: 采样分配器（1/N 采样记录） | ✅ |

---

### P6-1: Memory Compaction

**目标**: Arena 内碎片整理，压缩活跃分配减少内存占用。

```pascal
TCompactAllocator = class(TAllocator)
  constructor Create(AInner: IAllocator; AThreshold: Double = 0.3);
  function FragmentationRatio: Double;
  function Compact: SizeUInt;  // 返回释放的字节数
  property Threshold: Double read FThreshold;
end;
```

**实现策略**:
- 追踪每个 span 的碎片率（空闲槽位 / 总槽位）
- 碎片率 > 阈值时触发压缩
- 压缩：将活跃分配迁移到紧凑的 span，释放空闲 span
- 需要对象支持重定位（回调通知）

**源文件**: `core/src/nextpas.core.mem.allocator.compact.pas`
**测试**: `core/tests/nextpas.core.mem/test_compact/test_compact.lpr`

---

### P6-2: Allocator Hotswap

**目标**: 运行时原子替换分配器，支持无缝切换。

```pascal
THotswapAllocator = class(TAllocator)
  constructor Create(AInitial: IAllocator);
  procedure Swap(ANew: IAllocator);
  function Current: IAllocator;
  function SwapCount: UInt64;
end;
```

**实现策略**:
- 使用原子指针存储当前分配器
- `Swap` 原子替换，新分配立即使用新分配器
- 旧分配器在所有引用释放后自动回收
- 用途：运行时切换 debug/release 分配器

**源文件**: `core/src/nextpas.core.mem.allocator.hotswap.pas`
**测试**: `core/tests/nextpas.core.mem/test_hotswap/test_hotswap.lpr`

---

### P6-3: Mapped File Allocator

**目标**: 内存映射文件分配器，支持持久化数据。

```pascal
TMappedFileAllocator = class(TAllocator)
  constructor Create(const AFileName: string; ASize: UInt64;
    ACreate: Boolean = True);
  function IsMapped: Boolean;
  function BaseAddress: Pointer;
  function MappedSize: UInt64;
  procedure Flush;
  procedure Close;
end;
```

**实现策略**:
- 使用 `TMemoryMap` 映射文件到内存
- 分配器在映射区域内管理分配
- 支持 `Flush` 刷新到磁盘
- 适用于：持久化数据结构、数据库存储引擎

**源文件**: `core/src/nextpas.core.mem.allocator.mapped_file.pas`
**测试**: `core/tests/nextpas.core.mem/test_mapped_file/test_mapped_file.lpr`

---

### P6-4: Allocation Sampler

**目标**: 采样分配器，每 N 次分配记录一次，用于性能分析。

```pascal
TSamplingAllocator = class(TAllocator)
  constructor Create(AInner: IAllocator; ASampleRate: UInt32 = 1000);
  function SampleCount: UInt64;
  function TotalAllocs: UInt64;
  procedure ResetStats;
  property SampleRate: UInt32 read FSampleRate;
end;
```

**实现策略**:
- 原子计数器，每 N 次分配记录一次
- 采样记录：大小、时间戳、调用者地址
- 零开销：非采样分配直接透传
- 用途：生产环境性能分析、分配热点识别

**源文件**: `core/src/nextpas.core.mem.allocator.sampling.pas`
**测试**: `core/tests/nextpas.core.mem/test_sampling/test_sampling.lpr`

---

## 执行顺序

```
P6-1 (Compaction) → P6-2 (Hotswap) → P6-3 (Mapped File) → P6-4 (Sampler)
```

**预估工作量**:
- P6-1: 2-3 天（碎片检测 + 压缩算法）
- P6-2: 1 天（原子指针 + 切换）
- P6-3: 1-2 天（mmap + 分配管理）
- P6-4: 1 天（采样计数器 + 记录）

**总计**: 5-7 天，~8 个新文件，~1500 行代码，~50 新测试
