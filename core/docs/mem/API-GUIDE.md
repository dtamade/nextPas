# nextpas.core.mem API 选择指南

**目的**: 帮助开发者在 mem 模块的三套 API 体系中选择正确的入口。
**最后更新**: 2026-07-03

---

## 三套 API 体系

mem 模块有三套命名体系，分别服务于不同语义场景：

| 体系 | 方法签名 | 适用场景 | 接口/类型 |
|------|----------|----------|-----------|
| **Alloc/Free** | `Alloc(ASize): Pointer` | Arena 线性分配（只前进，Reset 释放全部） | `IArena`, `TLocalArena`, `TChunkedArena` |
| **GetMem/FreeMem** | `GetMem(ASize): Pointer` | 通用分配器（单独释放每块） | `IAllocator`, `TSlabPool` |
| **Acquire/Release** | `Acquire(out APtr): Boolean` | 固定大小池（O(1) 分配/释放） | `IPool`, `IBlockPool`, `TLocalBlockPool` |

## 选择决策树

```
你的使用场景是什么？
│
├─ 请求/帧/文档等有限生命周期？
│  └─ 用 IArena (Alloc/Reset)
│     ├─ 单线程 → TLocalArena / TChunkedArena
│     └─ 多线程 → TArenaConcurrent
│
├─ 频繁分配/释放相同大小的对象？
│  └─ 用 IPool (Acquire/Release)
│     ├─ 单线程 → TLocalBlockPool / TFixedSlabPool
│     └─ 多线程 → TBlockPoolConcurrent / TShardedBlockPool
│
├─ 通用内存分配（大小不固定）？
│  └─ 用 IAllocator (GetMem/FreeMem)
│     ├─ 默认 → DefaultAllocator
│     ├─ 需要跟踪泄漏 → TTrackingAllocator
│     ├─ 需要 OOM 降级 → TFallbackAllocator
│     └─ 需要 slab 优化 → TSlabPool
│
└─ 不确定？→ 用 IAllocator (最通用)
```

## 命名约定速查

| 操作 | IAllocator | IArena | IPool |
|------|------------|--------|-------|
| 分配 | `GetMem(Size)` | `Alloc(Size)` | `Acquire(out Ptr)` |
| 分配+清零 | `AllocMem(Size)` | `AllocZeroed(Size)` | N/A |
| 释放 | `FreeMem(Ptr)` | N/A (用 Reset) | `Release(Ptr)` |
| 重分配 | `ReallocMem(Ptr, Size)` | N/A | N/A |
| 释放全部 | N/A | `Reset` | `Reset` |

## nil 和 0 的处理契约

所有分配器/池/Arena 统一遵守以下契约：

| 操作 | 行为 |
|------|------|
| `GetMem(0)` / `Alloc(0)` / `Acquire` with size=0 | 返回 nil |
| `FreeMem(nil)` / `Release(nil)` | 静默返回，无操作 |
| `ReallocMem(nil, Size)` | 等价于 `GetMem(Size)` |
| `ReallocMem(Ptr, 0)` | 等价于 `FreeMem(Ptr)` |
| `ReallocMem(nil, 0)` | 无操作，返回 nil |

**注意**: `STRICT_NULL_FREE` 调试模式下 `FreeMem(nil)` 会抛异常，仅用于检测调用方 bug。

## 错误处理策略

| 场景 | IAllocator | IArena | IPool |
|------|------------|--------|-------|
| OOM | 返回 nil | 返回 nil | 返回 nil / False |
| 非法参数 | 抛异常 | 返回 nil | 抛异常 |
| 双重释放 | 抛异常 | N/A | 抛异常 |
| 容量耗尽 | N/A | 返回 nil | 返回 nil / False |

**设计哲学**: Arena 的 `Alloc` 返回 nil 表示容量不足（正常运行时条件），Pool/Allocator 的非法操作抛异常（编程错误）。

## 常见误区

### ❌ 混用 Alloc 和 GetMem

```pascal
// 错误：Arena 分配的内存不能用 FreeMem 释放
var Arena: IArena;
Arena := CreateDefaultArena(4096);
var P := Arena.Alloc(128);
FreeMem(P);  // ❌ Arena 不支持单独释放
```

```pascal
// 正确：Arena 用 Reset 释放全部
var Arena: IArena;
Arena := CreateDefaultArena(4096);
var P := Arena.Alloc(128);
Arena.Reset;  // ✅ 一次性释放全部
```

### ❌ 在 Arena 上调用 ReallocMem

```pascal
// 错误：Arena 不支持重分配
var Arena: IArena;
Arena.Alloc(128);
// Arena 没有 ReallocMem 方法
```

```pascal
// 正确：需要重分配时用 IAllocator
var Alloc: IAllocator;
Alloc := DefaultAllocator;
var P := Alloc.GetMem(128);
P := Alloc.ReallocMem(P, 256);
```

### ❌ 用 IPool 分配不同大小的对象

```pascal
// 错误：固定大小池不支持可变大小
var Pool: TLocalBlockPool;
Pool := TLocalBlockPool.Create(64, 100);
Pool.Acquire;  // 只能分配 64 字节的块
```

```pascal
// 正确：可变大小用 IAllocator 或 IMemoryPool
var Pool: TSlabPool;
Pool := TSlabPool.Create(4096);
Pool.GetMem(32);   // ✅ 自动选择合适的 size class
Pool.GetMem(1024); // ✅ 大对象走 fallback
```

## 高级路径（子模块入口）

门面 `nextpas.core.mem` 导出 65 个常用类型。以下高级功能需直接引用子模块：

### Go-style Growing Allocator

```pascal
uses nextpas.core.mem.allocator.growing;

// TGrowingAllocator: TLS cache → central pool → system GetMem
// 架构匹配 Go mcache/mcentral/mheap，线程安全
var GAlloc: TGrowingAllocator;
GAlloc := DefaultGrowingAllocator;
P := GAlloc.GetMem(64);  // ~5ns via TLS cache
GAlloc.FreeMem(P, 64);
```

### Span-based 内部分片

```pascal
uses nextpas.core.mem.span;

// TSpan: 64-bit bitmap 管理固定大小 slot，O(1) BSF 分配
var S: TSpan;
SpanInit(S, BasePtr, 64, 32);
Slot := SpanAlloc(S);  // O(1)
SpanFree(S, Slot);     // O(1) + double-free 检测
```

### Size Class 查询

```pascal
uses nextpas.core.mem.sizeclass;

// 62 个 size class，覆盖 16B-57344B
Idx := SizeClassIndex(100);  // → 对应 class index
Sz := SizeClassSize(Idx);    // → 实际分配大小
```

### Central Pool / Thread Cache

```pascal
uses nextpas.core.mem.central;
uses nextpas.core.mem.cache.thread;

// TCentralPool: spinlock 保护的批量 refill/flush
// TThreadCache: TLS 缓存，零竞争
```

### Slab 专用异常

```pascal
uses nextpas.core.mem.pool.slab;

// ESlabPoolInvalidSize: 无效大小
// ESlabPoolCorruption: 池损坏检测
```

### Shuffle Shard

```pascal
uses nextpas.core.mem.shuffle;

// TShuffleShard: 概率分片策略，用于负载均衡
```

> **原则**: 门面提供常用路径，子模块提供专业路径。不确定时用门面。

---

## 完整场景示例

### 场景 1: HTTP 请求处理 (Arena per Request)

每个请求分配一个 Arena，请求结束时 Reset 释放全部内存，零碎片。

```pascal
uses nextpas.core.mem, nextpas.core.mem.arena;

procedure HandleRequest(ARequest: TRequest; AResponse: TResponse);
var
  LArena: IArena;
  LBody, LHeaders: PByte;
begin
  LArena := CreateDefaultArena(64 * 1024);  // 64KB per request
  try
    // 解析阶段：从 Arena 分配临时缓冲区
    LBody := LArena.Alloc(ARequest.ContentLength);
    LHeaders := LArena.Alloc(4096);

    // 处理业务逻辑...
    ProcessBody(LBody, ARequest.ContentLength);
    BuildResponse(LHeaders, AResponse);

    // 请求结束，Arena 自动 Reset（IArena 引用计数归零时释放）
  except
    on E: Exception do
      LogError(E.Message);
  end;
  // LArena 离开作用域 → Reset → 所有内存一次性释放
end;
```

### 场景 2: 编译器 AST 节点分配 (Arena per Compilation Unit)

编译器处理一个源文件时，所有 AST 节点从 Arena 分配，编译完成时整体释放。

```pascal
uses nextpas.core.mem, nextpas.core.mem.arena;

type
  PASTNode = ^TASTNode;
  TASTNode = record
    Kind: TNodeKind;
    Left, Right: PASTNode;
    Value: string;
  end;

function ParseUnit(const ASource: string): PASTNode;
var
  LArena: IArena;
  LNode: PASTNode;
begin
  // 每个编译单元一个 Arena，几何增长
  LArena := CreateChunkedArena(8192);
  try
    // 所有 AST 节点从 Arena 分配
    LNode := LArena.Alloc(SizeOf(TASTNode));
    LNode^.Kind := nkUnit;
    LNode^.Left := LArena.Alloc(SizeOf(TASTNode));
    LNode^.Right := LArena.Alloc(SizeOf(TASTNode));

    // 递归解析...
    ParseDeclarations(LArena, LNode);

    Result := LNode;
  except
    // 解析失败时 Arena 自动释放
    Result := nil;
  end;
end;
```

### 场景 3: 游戏实体对象池 (Fixed-Size Pool)

游戏循环中频繁创建/销毁实体，使用固定大小池避免碎片。

```pascal
uses nextpas.core.mem, nextpas.core.mem.pool;

type
  PEntity = ^TEntity;
  TEntity = record
    X, Y, Z: Single;
    Health: Integer;
    Active: Boolean;
  end;

var
  GEntityPool: IBlockPool;

procedure InitEntityPool(AMaxEntities: Integer);
begin
  // 创建固定大小池：SizeOf(TEntity) 字节块，预分配 AMaxEntities 个
  GEntityPool := CreateBlockPool(SizeOf(TEntity), AMaxEntities);
end;

function SpawnEntity: PEntity;
begin
  Result := GEntityPool.Acquire;
  if Result <> nil then
  begin
    Result^.X := 0; Result^.Y := 0; Result^.Z := 0;
    Result^.Health := 100;
    Result^.Active := True;
  end;
end;

procedure DestroyEntity(AEntity: PEntity);
begin
  if AEntity <> nil then
    GEntityPool.Release(AEntity);  // O(1)，块回到池中
end;
```

### 场景 4: 开发阶段泄漏检测 (Tracking Allocator)

包装默认分配器，程序退出时报告所有未释放的内存。

```pascal
uses nextpas.core.mem, nextpas.core.mem.allocator.tracking;

var
  GTracker: TTrackingAllocator;

procedure InitLeakDetection;
begin
  GTracker := TTrackingAllocator.Create(DefaultAllocator);
end;

procedure ReportLeaks;
var
  LReport: string;
begin
  if GTracker.HasLeaks then
  begin
    LReport := GTracker.ReportLeaks;
    WriteLn('=== MEMORY LEAKS DETECTED ===');
    WriteLn(LReport);
  end
  else
    WriteLn('No memory leaks detected.');
end;

// 使用：用 GTracker 代替 DefaultAllocator
var P := GTracker.GetMem(128);
GTracker.SetTag('parser.buffer');  // 标记来源
// ... 使用 P ...
GTracker.FreeMem(P);              // 释放时自动清除标记

// 程序退出时
ReportLeaks;
GTracker.Free;
```

### 场景 5: OOM 降级 (Fallback Allocator)

主分配器（Arena）OOM 时自动降级到系统分配器，保证服务不中断。

```pascal
uses nextpas.core.mem, nextpas.core.mem.allocator.fallback;

var
  GFallback: TFallbackAllocator;

procedure InitWithFallback;
var
  LArenaAllocator: IAllocator;
begin
  // Arena 包装为 IAllocator（只分配，不释放单块）
  LArenaAllocator := CreateArenaAllocator(1024 * 1024);  // 1MB Arena
  // Fallback：Arena 优先，OOM 时降级到默认分配器
  GFallback := TFallbackAllocator.Create(LArenaAllocator, DefaultAllocator);
end;

procedure ProcessLargeData(const AData: TBytes);
var
  LBuf: Pointer;
begin
  // 小分配走 Arena（快速），大分配可能 OOM 走 fallback
  LBuf := GFallback.GetMem(Length(AData));
  if LBuf <> nil then
  begin
    Move(AData[0], LBuf^, Length(AData));
    // ... 处理 ...
    GFallback.FreeMem(LBuf);  // 自动从正确的分配器释放
  end;
end;

// 统计降级次数
WriteLn('Fallback count: ', GFallback.TotalFallbacks);
```
