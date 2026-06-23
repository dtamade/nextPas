# nextpas.core.mem API 参考

## 先看这两个核心契约

### `IArena`

`IArena` 是 class-based arena 的最小公共接口。当前实现方是 `TLocalArena`、`TChunkedArena`，以及包装器 `TArenaConcurrent`。

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

要点：

- 构造或初始化失败走异常，例如 `EOutOfMemory`、`EAllocError`
- `Alloc*` 失败返回 `nil`
- `IArena` 故意不暴露 `TotalSize`；总容量和底层保留字节数是实现细节

### `IAllocator`

`IAllocator` 是更稳定的通用分配器接口。`nextpas.core.mem` 的默认分配器、tracking wrapper、fallback wrapper、arena allocator 都围绕它工作。

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

要点：

- `AllocMem` 语义是 zero-initialized allocation
- `FreeMem` 当前是 `procedure`，不返回释放字节数
- `AllocAligned` / `FreeAligned` 是和普通分配分开的显式 contract

## 共享 arena 类型

### `TArenaMark`

```pascal
type
  TArenaMark = record
    FrontOffset: SizeUInt;
    BackOffset: SizeUInt;
    TotalUsed: SizeUInt;
  end;
```

`SaveMark` / `RestoreToMark` 通过这个记录表达“回退到某个分配位置”。

### `TArenaStats`

```pascal
type
  TArenaStats = record
    TotalAllocated: SizeUInt;
    TotalUsed: SizeUInt;
    PeakUsed: SizeUInt;
    AllocCount: QWord;
  end;
```

### `TArenaConfig`

```pascal
type
  TArenaConfig = record
    InitialSize: SizeUInt;
    MaxSize: SizeUInt;
    GrowthKind: TArenaGrowthKind;
    GrowthFactor: Double;
    GrowthStep: SizeUInt;
    Alignment: SizeUInt;
    KeepSegments: Boolean;

    class function Default(AInitialSize: SizeUInt): TArenaConfig; static;
  end;
```

这套配置目前只给 `TChunkedArena` 使用。

## `TLocalArena`

`TLocalArena` 是固定容量、class-based 的 bump arena，实现了 `IArena`。

### 构造函数

```pascal
constructor Create(const ACapacity: SizeUInt); overload;
constructor Create(const ACapacity: SizeUInt; const AAllocator: IAllocator); overload;
```

### 公开方法

```pascal
function Alloc(ASize: SizeUInt): Pointer;
function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
function AllocZeroed(ASize: SizeUInt): Pointer;
function SaveMark: TArenaMark;
procedure RestoreToMark(AMark: TArenaMark);
procedure Reset;
function UsedSize: SizeUInt;
function RemainingSize: SizeUInt;
function Stats: TArenaStats;

function AllocFast(ASize: SizeUInt): Pointer;
function AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer;
```

### 诊断属性

- `Capacity`
- `PeakUsed`
- `TotalAllocCount`

### 行为说明

- `Reset` 只把 offset 归零，不释放后备 buffer
- `AllocFast` / `AllocAlignedFast` 只适合调用方已经证明边界安全的热路径

## `TChunkedArena`

`TChunkedArena` 是分段增长的 class-based arena，实现了 `IArena`。

### 构造函数

```pascal
constructor Create(const AConfig: TArenaConfig); overload;
constructor Create(AInitialSize: SizeUInt; AMaxSize: SizeUInt = 0); overload;
```

### 公开方法

`TChunkedArena` 完整实现 `IArena`，并额外提供：

```pascal
function SegmentCount: SizeUInt;
property PeakUsed: SizeUInt;
property TotalAllocCount: QWord;
property Alignment: SizeUInt;
```

### 行为说明

- `GrowthKind` 支持几何增长和线性增长
- `KeepSegments=True` 时，`Reset` 保留现有 segments
- `KeepSegments=False` 时，`Reset` 会把多余 segments 放进 chunk cache，后续再复用

## `TVirtualArena`

`TVirtualArena` 是 record-based arena，不实现 `IArena`。它直接暴露更低层、更偏性能导向的 API。

### 初始化和释放

```pascal
procedure TVirtualArena_Init(var AArena: TVirtualArena; AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
procedure TVirtualArena_Release(var AArena: TVirtualArena);
```

### 公开方法

```pascal
function Alloc(ASize: SizeUInt): Pointer;
function AllocNoPointer(ASize: SizeUInt): Pointer;
function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
function AllocZeroed(ASize: SizeUInt): Pointer;
function AllocUnsafe(ASize: SizeUInt): Pointer;
function SaveMark: TArenaMark;
procedure RestoreToMark(AMark: TArenaMark);
procedure Reset;
procedure ResetHard;
procedure Release;
function TotalAllocated: SizeUInt;
function TotalUsed: SizeUInt;
function PeakUsed: SizeUInt;
function AllocCount: SizeUInt;
```

### 行为说明

- `Alloc` 从前向 bump pointer 分配
- `AllocNoPointer` 从后向 bump pointer 分配，适合 pointer-free payload
- `AllocUnsafe` 跳过安全检查，不更新统计，也不保证对齐
- `Reset` 保留 reserved range 和已经 committed 的页面
- `ResetHard` 会 decommit 已提交页面，但保留 reserved virtual address range
- 大对象（`>= ARENA_LARGE_THRESHOLD`）走独立 mmap，`Reset` / `RestoreToMark` 不回收，只有 `Release` 才统一释放

## `TVirtualArenaAllocator`、`TFastArenaAllocator` 和 `TArenaAllocator`

`TVirtualArenaAllocator` 把 `TVirtualArena` 包成 `IAllocator`。

```pascal
type
  TVirtualArenaAllocator = class(TAllocator)
  public
    constructor Create(AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
    procedure Reset;
    property Arena: TVirtualArena read FArena;
  end;

  TFastArenaAllocator = TVirtualArenaAllocator;
```

在门面 `nextpas.core.mem` 里，`TArenaAllocator` 也是同一个兼容别名链：

```pascal
TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
```

行为说明：

- `GetMem` / `AllocMem` 最终走 `TVirtualArena`
- 单块 `FreeMem` 不会真正回收 arena 内存
- `Reset` 一次性回退整个 arena

## 线程本地 arena surface

### `TThreadArenaConfig`

```pascal
type
  TThreadArenaConfig = record
    ArenaCapacity: SizeUInt;
    MaxPoolSize: Integer;
  end;
```

### `TThreadArenaManager`

```pascal
constructor Create(const AConfig: TThreadArenaConfig);
function Get: TLocalArena;
procedure DrainTLS;
function HasArena: Boolean;
function PoolSize: Integer;
function TotalCreated: Integer;
function TotalRecycled: Integer;
```

### `TThreadArena`

```pascal
class function Create(AArena: TLocalArena): TThreadArena; static;
function Alloc(ASize: SizeUInt): Pointer;
function AllocZeroed(ASize: SizeUInt): Pointer;
function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
function AllocFast(ASize: SizeUInt): Pointer;
function AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer;
function SaveMark: TArenaMark;
procedure RestoreToMark(AMark: TArenaMark);
procedure Reset;
function UsedSize: SizeUInt;
function RemainingSize: SizeUInt;
function PeakUsed: SizeUInt;
property Arena: TLocalArena read FArena;
```

行为说明：

- 当前实现通过 `threadvar` 缓存每线程 arena
- 线程结束前需要显式调用 `DrainTLS`
- 当前代码没有自动 threadvar cleanup hook

## 门面 helper

门面 `nextpas.core.mem` 还提供这几个常用 helper：

```pascal
function DefaultAllocator: IAllocator;
function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;
```

## 选择建议

- 需要固定容量、最简单的 `IArena`：`TLocalArena`
- 需要增长能力、又想保留 `IArena` 接口：`TChunkedArena`
- 需要预留大块虚拟地址空间、前后双向 bump、手工控制 `Reset` / `ResetHard`：`TVirtualArena`
- 需要把 `TVirtualArena` 接到 `IAllocator` consumer 上：`TVirtualArenaAllocator` / `TFastArenaAllocator`
- 需要每线程零锁热路径：`TThreadArenaManager` + `TThreadArena`
