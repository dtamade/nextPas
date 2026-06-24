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
| 编译器热路径    | TVirtualArena + AllocUnsafe    | 2ns, 476M ops/s             |
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

- `GetMem` / `AllocMem` / `ReallocMem` / `FreeMem` — 标准分配
- `AllocAligned` — 对齐分配
- `MemSize` — 查询已分配大小
- `Traits` — 分配器特性

### TVirtualArena (record)

基于 mmap 的零虚分发 Arena：

- 预留 256MB 虚拟地址空间
- 双向 bump pointer（指针对象从前往后，无指针从后往前）
- 大对象（>=64KB）独立 mmap
- `AllocUnsafe`: 纯 bump pointer, 2ns（前提：页面已提交）

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
| VirtualArena AllocUnsafe | 2 | 476M |
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

### VirtualArena + AllocUnsafe

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
    LP := LArena.AllocUnsafe(64); // 纯 bump, 2ns
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
- **AllocUnsafe 前提**：调用方确保页面已提交, 不更新统计, 不保证对齐
- **大对象生命周期**：不受 mark/reset 影响；`FLargeBlocks` metadata 与对象映射同生命周期，只在 `Release` 时统一释放/关闭
- **非线程安全**：Arena 默认非线程安全, 多线程请用 TArenaConcurrent
- `nextpas.core.mem.mapped_slab_pool` owns only the anonymous mapping allocator surface.
- `nextpas.core.io.mapped.slab_pool` is the fixed owner for file-backed and shared-memory slab pools.
- mem 侧 mapped slab API must not grow `CreateFile`, `OpenFile`, `CreateShared`, `OpenShared`, or `nextpas.core.platform.files` dependencies.

## 测试覆盖

- 29 test projects with a static count of 289 `T.Run` cases
- 0 memory leaks
- 完整接口覆盖

## 相关文档

- [架构设计](ARCHITECTURE.md)
- [API 参考](API.md)
- [基准测试](BENCHMARKS.md)
- [审查报告](mem-findings.md)
- [修复计划](mem-fix-plan.md)

## 版本历史

- v2.1 (2026-06-23): TLA + SizeClass Slab + Fallback Chain + FPC FillChar/Move 清理
- v2.0 (2026-06-22): 架构清理 + 性能优化 + 安全防护 + 并发语义补强
- v1.0 (2026-06-22): 初始 Arena 实现
