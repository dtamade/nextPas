# nextpas.core.mem 架构设计

## 模块在解决什么问题

`nextpas.core.mem` 提供两层核心能力：

- 稳定的分配契约：`IAllocator`、`IArena`
- 几类针对不同场景的实现：固定 arena、分段 arena、虚拟内存 arena、thread-local arena、allocator wrapper、pool family

设计目标没有变：

1. 热路径优先
2. public surface 尽量清晰
3. owner boundary 明确，避免把部署、并发或上层策略偷偷混进 mem 基础契约

## 当前分层

### L0：基础契约和错误

- `nextpas.core.mem.base`
- `nextpas.core.mem.intf`
- `nextpas.core.mem.error`
- `nextpas.core.mem.mutex`
- `nextpas.core.mem.rwlock`

这里放的是基础类型、对齐 helper、错误类型，以及 `IAllocator` 这种更稳定的底层 contract。

### L1：arena family

- `nextpas.core.mem.arena.base`
- `nextpas.core.mem.arena.intf`
- `nextpas.core.mem.arena.local`
- `nextpas.core.mem.arena.chunked`
- `nextpas.core.mem.arena.virtual`
- `nextpas.core.mem.arena.concurrent`
- `nextpas.core.mem.arena.thread`
- `nextpas.core.mem.arena` facade

当前活跃的增长型 arena 是 `TChunkedArena`。`arena.growable` 已经不属于当前架构 truth。

### L2：allocator 和 pool

Allocator 侧常用单元：

- `nextpas.core.mem.allocator.base`
- `nextpas.core.mem.allocator.arena`
- `nextpas.core.mem.allocator.tracking`
- `nextpas.core.mem.allocator.leak_check`
- `nextpas.core.mem.allocator.fallback`
- `nextpas.core.mem.allocator.mimalloc.loader`
- `nextpas.core.mem.allocator.mimalloc`

Pool 侧常用单元：

- `nextpas.core.mem.pool`
- `nextpas.core.mem.pool.sizeclass`
- `nextpas.core.mem.blockpool`
- `nextpas.core.mem.blockpool.sharded`
- `nextpas.core.mem.stack_pool`

### L3：门面

- `nextpas.core.mem`

门面负责聚合最常用的 arena、allocator 和 pool surface。更细的 owner-only surface 仍建议直接 `uses` 子单元。

## 两个核心 contract

### `IArena`

```pascal
type
  IArena = interface
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function SaveMark: TArenaMark;
    procedure RestoreToMark(AMark: TArenaMark);
    procedure Reset;
    function UsedSize: SizeUInt;
    function RemainingSize: SizeUInt;
    function Stats: TArenaStats;
  end;
```

设计点：

- `IArena` 只表达“向前分配、按 mark 回退、整体 reset”
- 它不暴露 `TotalSize`，因为 `TLocalArena`、`TChunkedArena`、`TVirtualArena` 的底层容量模型不一样
- arena 的单块释放不属于这条契约

### `IAllocator`

```pascal
type
  IAllocator = interface
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;
```

设计点：

- `FreeMem` 是 `procedure`，当前 contract 不返回释放字节数
- `AllocAligned` / `FreeAligned` 是显式能力，而不是把 aligned block 混进普通 `FreeMem`
- 40+ 模块依赖这条 surface，所以这里的变化成本远高于 arena 内部实现

## 四类 arena 的定位

### `TLocalArena`

- 固定容量
- class-based
- 实现 `IArena`
- 适合请求、帧、短生命周期对象

`Reset` 只回退 offset，不释放 backing buffer，也不清掉累计统计。

### `TChunkedArena`

- 分段增长
- class-based
- 实现 `IArena`
- 支持几何增长和线性增长

`Reset` 的行为受 `KeepSegments` 控制：

- `KeepSegments=True`：保留 segments
- `KeepSegments=False`：把多余 segments 放进 chunk cache，后续优先复用

### `TVirtualArena`

- record-based
- 不实现 `IArena`
- 通过 `platform_virtual_reserve` 预留虚拟地址空间
- 前后双向 bump pointer
- 大对象直接走独立 mmap

这是最偏性能和虚拟内存控制的 arena。它暴露 `Reset`、`ResetHard`、`AllocUnsafe` 这些 `IArena` 不适合承载的低层语义。

### `TArenaConcurrent` 和 `TThreadArena*`

- `TArenaConcurrent`：给任意 `IArena` 加 mutex 包装
- `TThreadArenaManager` / `TThreadArena`：thread-local fast path，当前要求调用方显式 `DrainTLS`

两者解决的是完全不同的并发问题：

- 多线程共享同一个 arena：`TArenaConcurrent`
- 每线程独享自己的 arena：`TThreadArenaManager`

## Reset 语义要分开看

### `TLocalArena.Reset`

- 归零 offset
- 保留 backing buffer
- 保留峰值和累计分配统计

### `TChunkedArena.Reset`

- 归零逻辑 used state
- 可能保留 segments，也可能把它们转进 cache，取决于 `KeepSegments`

### `TVirtualArena.Reset`

- 保留 reserved virtual range
- 保留已 committed 页面
- 保留大对象 mmap block

### `TVirtualArena.ResetHard`

- decommit 已提交页面
- 保留 reserved virtual range
- 大对象仍然不在这里释放，只有 `Release` 才统一释放

## allocator wrapper 的角色

### `TVirtualArenaAllocator`

`TVirtualArenaAllocator` 把 `TVirtualArena` 包成 `IAllocator`，方便接到已经依赖 allocator contract 的 consumer 上。

要点：

- `GetMem` / `AllocMem` 最终走 arena bump allocation
- 单块 `FreeMem` 是 no-op
- `Reset` 一次性回退整个底层 arena

`TFastArenaAllocator` 现在只是它的兼容性别名。

## mimalloc loader boundary

- `nextpas.core.mem.allocator.mimalloc` 保留 mimalloc FFI 绑定、symbol 解析和 allocator 语义
- `nextpas.core.mem.allocator.mimalloc.loader` owns mimalloc path discovery and search order.
- Search order: env override -> executable-relative `lib/<cpu-os>/` -> system loader fallback.
- 环境变量覆盖名保持现状：Windows 用 `NEXTPAS_MIMALLOC_DLL`，其他宿主用 `NEXTPAS_MIMALLOC_SO`

## 门面怎么用

### `nextpas.core.mem.arena`

适合只想要 arena family，不想把 pool 和 allocator surface 一起引进来的 consumer。

### `nextpas.core.mem`

适合大多数普通 consumer。这里 re-export 了：

- `IAllocator`
- `IArena`
- `TLocalArena`
- `TChunkedArena`
- `TVirtualArena`
- `TThreadArenaManager`
- `TVirtualArenaAllocator` 的兼容别名链
- 常用 pool 类型

高级子模块或 owner-only surface 仍建议直接 `uses` 具体子单元。

## 现在仍然刻意保留的边界

- `TVirtualArena` 不强行实现 `IArena`
- `IAllocator` 和 `IArena` 保持两条不同 contract
- thread-local arena 当前不宣称“线程退出自动回收”
- 文档里的兼容名词只能作为 alias 出现，不能再被当成主 surface 介绍
