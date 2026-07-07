# nextpas.core.mem - 内存管理模块

## 概述

`nextpas.core.mem` 是 nextPas 框架的内存管理模块，提供高性能的内存分配器抽象和实现。

## 设计目标

- **高性能**：超越 Go/Rust 标准库的内存分配性能
- **零碎片**：Arena 分配器消除内存碎片
- **零泄漏**：完善的内存泄漏检测机制
- **接口优雅**：遵循 Rust trait / Go interface 风格的接口设计
- **生产级质量**：完整的测试覆盖和基准对照

## Arena 选择指南

| 场景            | 推荐                           | 原因                        |
| --------------- | ------------------------------ | --------------------------- |
| 编译器热路径    | TVirtualArena + AllocFast    | 2ns, 476M ops/s             |
| 请求/帧生命周期 | TLocalArena                    | 固定容量, 3ns, 307M ops/s   |
| 动态增长批量    | TChunkedArena                  | Go-style chunk cache, 15ns  |
| 多线程共享      | TArenaConcurrent               | mutex-protected IArena 包装 |
| 单线程固定块池  | TLocalBlockPool                | class-only, 最小 surface    |
| 固定大小块分配  | TBlockPool / TShardedBlockPool | O(1) acquire/release        |
| Slab 分配       | TSlabPool / TSlabPoolSharded   | 页级 slab, IMemoryPool      |

## 核心类型

### IArena 接口

线性分配器接口：

- `Alloc` / `AllocAligned` / `AllocZeroed` — 分配
- `SaveMark` / `RestoreToMark` — 保存/恢复分配位置
- `Reset` — 重置 Arena（保留已提交页面）
- `UsedSize` / `RemainingSize` / `Stats` — 查询

### IAllocator 接口

通用分配器接口（40+ 模块引用）：

- `GetMem` / `AllocMem` / `ReallocMem` / `FreeMem` — 标准分配（5 方法契约）
- `Traits` — 分配器特性（ZeroInitialized / ThreadSafe / SupportsRealloc）

对齐分配见 `IArena.AllocAligned`，分配大小查询见 `IMemoryPool`。

### TVirtualArena (record)

基于 mmap 的零虚分发 Arena：

- 预留 256MB 虚拟地址空间
- 双向 bump pointer（指针对象从前往后，无指针从后往前）
- 大对象（>=64KB）独立 mmap
- `AllocFast`: 纯 bump pointer, 2ns（前提：页面已提交）

### TLocalArena (class, IArena)

基于 GetMem 的固定容量 Arena：

- 预分配 buffer, 分配只前进
- `AllocFast` / `AllocAlignedFast`: DEBUG Assert 保护, Release 零额外分支
- 适用于请求/帧/文档等有限生命周期场景

### TChunkedArena (class, IArena)

分段可增长 Arena：

- Go-style chunk cache（Reset 缓存 freed segments, 最多 8 个）
- FSegments 几何扩容
- 支持几何/线性增长策略

## BlockPool 选择指南

- `TLocalBlockPool`：单线程、单 owner、调用点就在本模块内时选它。它是 class-only 固定块池，surface 最小，只保留 `Acquire/Release/Reset` 和基础容量查询。
- `TBlockPool`：需要把固定块池作为公共 contract 暴露出去，或者需要 `IBlockPool` / `IBlockPoolBatch`、显式对齐、批量 `AcquireN/ReleaseN`、`Owns/GetRange` 之类诊断能力时选它。
- 如果后续已经确定会走 shard/concurrent 变体，优先从 `TBlockPool` 这条接口面进入，避免先写一套 `TLocalBlockPool` 局部调用再补一层适配。

## 性能基准 (2026-06-22)

64B alloc, Reset+Reuse:
| 分配器 | ns/op | ops/s |
|--------|-------|-------|
| VirtualArena AllocFast | 2 | 476M |
| LocalArena | 3 | 307M |
| ChunkedArena | 15 | 68M |
| VirtualArena Alloc | 37 | 27M |
| RTL GetMem+FreeMem | 64 | 15M |

## 使用示例

### 基本 Arena 使用

```pascal
uses nextpas.core.mem;

var
  LArena: TLocalArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024);
  try
    LP := LArena.Alloc(64);
    // 使用 LP...
    LArena.Reset;  // 一次性释放全部
  finally
    LArena.Free;
  end;
end;
```

### VirtualArena + AllocFast

```pascal
uses nextpas.core.mem.arena.virtual;

var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.Alloc(4096);   // 首次分配提交页面
    LArena.Reset;                // Reset 不释放页面
    LP := LArena.AllocFast(64); // 纯 bump, 2ns
  finally
    TVirtualArena_Release(LArena);
  end;
end;
```

### IAllocator 接口

```pascal
var
  LAllocator: IAllocator;
begin
  LAllocator := DefaultAllocator;  // 全局默认分配器
  LP := LAllocator.GetMem(256);
  // ...
end;
```

### 泄漏检测

```pascal
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(procedure(AAllocator: IAllocator)
  begin
    // 测试代码...
  end);
  if LResult.LeakCount > 0 then
    WriteLn('Memory leaks detected!');
end;
```

## 关键约定

- **Arena 不支持单个释放**：需要 `Reset` 一次性释放全部
- **AllocFast 前提**：调用方确保页面已提交, 不更新统计, 不保证对齐
- **大对象生命周期**：不受 mark/reset 影响；`FLargeBlocks` metadata 与对象映射同生命周期，只在 `Release` 时统一释放/关闭
- **非线程安全**：Arena 默认非线程安全, 多线程请用 TArenaConcurrent
- `nextpas.core.mem.mapped_slab_pool` owns only the anonymous mapping allocator surface.
- `nextpas.core.io.mapped.slab_pool` is the fixed owner for file-backed and shared-memory slab pools.
- mem 侧 mapped slab API must not grow `CreateFile`, `OpenFile`, `CreateShared`, `OpenShared`, or `nextpas.core.platform.files` dependencies.

## 测试覆盖

- 44 test suites with 639 tests (migrated to `nextpas.core.test` v3.x)
- 0 memory leaks, 0 unfreed blocks
- 完整接口覆盖：Arena / Pool / Allocator / Concurrent / Sharded / Contract / OOM / Facade

## 相关文档

- [架构设计](ARCHITECTURE.md)
- [API 参考](API.md)
- [API 选择指南](API-GUIDE.md)
- [代码契约](CONTRACT.md)
- [基准测试](BENCHMARKS.md)
- [可用性审计](USABILITY-AUDIT.md)
- [审查报告](mem-findings.md) — 61项全部关闭
- [归档文档](archive/) — 已完成的研究和计划文档

## 版本历史

- v7.2 (2026-06-27): Phase F 基准测试 + Go 对照
  - 新增: `bench_pool_family` 9 基准覆盖 TBlockPool/TFixedPool/TStackPool/TRingBuffer
  - Go 对照: TBlockPool (15.6ns) 快于 sync.Pool (18.0ns)，TRingBuffer (31.8ns) 2x 快于 chan (63.7ns)
  - 修复: bench_arena_vs_rtl Makefile build dir 创建
  - Phase F 完成
- v7.1 (2026-06-27): Round 15 — test_ring_buffer + 并发池恢复 + 测试修复
  - 新增: `test_ring_buffer` 30 tests — TRingBuffer 全公共 API 覆盖
  - 恢复: `test_sharded_pools` 9 tests — CS-001 修复后编译通过
  - 恢复: `test_oom` 8 tests — CS-001 修复后编译通过
  - 修复: NormalizeAlignment 实现与文档不一致（缺少 >= DEFAULT_ALIGNMENT 检查）
  - 修复: test_mem_secure CheckContains 大小写 + compile gate 测试更新
  - 重构: test_platform_virtual 迁移到 nextpas.core.test 框架
  - 文档: RestoreState @note + RingBuffer.Clear 安全说明 (CS-010/CS-013)
  - 34 suites / 465 tests / 0 leaks / 0 failures
- v7.0 (2026-06-27): Phase E 文档注释 + Round 14 打磨
  - Phase E: 9 文件 150+ 处方法级 `{** @desc *}` 文档注释
  - E-2: 6 类型级文档补全 (TSlabPerfCounters/TSlabPoolStats/TSlabConfig/TFixedPoolConfig/TStackPoolConfig/TStackMemoryMapEntry)
  - 修复: test_object_pool 48 bytes 泄漏 (TestPoolExhaustion 未归还对象)
  - 修复: deprecation warning (platform_secure_zero → platform_secure_zero_memory)
  - 修复: doc-extras 代理文档注释格式错误 ({** ... * → {** ... *})
  - 34 suites / 465 tests / 0 leaks
- v6.0 (2026-06-27): Phase D 测试覆盖 100% — 3 新测试套件 + 4 补充
  - D-1a: `test_growing_fixed_pool` 12 tests — TGrowingFixedPool 全路径覆盖
  - D-1b: `test_growing_block_pool` 12 tests — TGrowingBlockPool 全路径覆盖
  - D-1c: `test_shared_memory` 8 tests — TSharedMemory 全 API 覆盖
  - D-2a: TryGetRtlAllocator 测试 (test_allocator_foundation)
  - D-2c: NextPowerOfTwo + NormalizeAlignment 边界测试 (test_mem_utils)
  - D-2d: rwlock 写锁竞争 8 线程压力测试 (test_concurrent_wrappers)
  - 31 suites / 465 tests / 0 leaks / 0 new failures
- v5.0 (2026-06-27): I-04 FallbackArena 提取 + T-04/T-05 边界测试 + capacity=1 修复
  - 修复: `TBlockPool.RebuildFreeList` capacity=1 时 `SizeUInt` 下溢导致 A/V
  - I-04: `TFallbackArena` 3 处重复跟踪代码提取为 `TrackFallback` 私有方法
  - T-04: mutex 递归获取检测 + mutex 无锁释放 + rwlock 并发读者 (3 tests)
  - T-05: blockpool capacity=1 / block_size=1 / alignment=1 / minimal 边界 (4 tests)
  - 31 suites / 430 tests / 0 leaks / 0 failures
- v4.0 (2026-06-27): E1 Facade 完整性 — 35→57 类型 re-export
  - 补全 14 个缺失 uses 导入，新增 22 个类型 re-export
  - Facade 类型覆盖率：15% → 26%（57/219 公共类型）
  - 新增 SecureZeroMemory/Bytes/String facade 转发
  - test_mem 迁移到 nextpas.core.test + 12 facade 可访问性测试
  - 31 suites / 423 tests / 0 leaks / 0 failures
- v3.0 (2026-06-26): 自举修复 + 并发测试修复 + B4 并发测试补全 + D1 框架迁移
  - 修复 `TChunkedArena.FSegmentCount` signed/unsigned 类型不匹配（自举阻塞）
  - 修复并发测试 TMemMutex/TMemRwLock 未初始化导致无限循环（record 栈变量 FillChar）
  - 补全 B4 并发测试：Reset/Alloc 竞争、Mark/Alloc 竞争、多次 Mark/Restore 循环
  - 迁移 test_allocator_foundation 到新测试框架
  - 30 suites / 398 tests / 0 leaks / 0 failures
- v2.5 (2026-06-25): TObjectPool 双重释放检测 + Arena AllocAligned(0) 统一归一化
- v2.4 (2026-06-25): 4 项深审修复 — TArenaMark AllocCount、ChunkedArena Reset 偏移、SlabSharded 清零、Fallback ReallocMem
- v2.3 (2026-06-25): 4 项深审修复 — AcquireUnchecked 统计、TObjectPool 边界、FixedPool DEBUG 指针、Slab SupportsAligned
- v2.2 (2026-06-25): 9 项打磨 — nil 安全、TLS 多实例隔离、AllocMem 路径、DEBUG 防护、门面补全
- v2.1 (2026-06-23): TLA + SizeClass Slab + Fallback Chain + FPC FillChar/Move 清理
- v2.0 (2026-06-22): 架构清理 + 性能优化 + 安全防护 + 并发语义补强
- v1.0 (2026-06-22): 初始 Arena 实现
