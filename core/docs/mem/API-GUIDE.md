# nextpas.core.mem API 选择指南

**目的**: 在三套 API 体系中选对入口（stdlib 手册决策树）。
**最后更新**: 2026-07-20（F3 门面收紧）
**入口**: [README.md](README.md) · **计划**: [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) · **门面冻结**: [FACADES-SURFACE.md](FACADES-SURFACE.md)

---

## 标准路径 vs 专家路径

优先 **Tier-0**；生产诊断用门面 Tier-1；冷门包装器 / 并发池变体 **直接 uses 子单元**（F3）。

| Tier | 你应该用什么 | 发现路径 |
|------|----------------|----------|
| **0 默认** | `DefaultHeap` / `GetMem`、`CreateDefaultArena` / Arena、Fixed/Block/Slab 池、`GetMemStats` | 门面 |
| **1 组合/诊断** | `TFallbackAllocator`、`TTrackingAllocator`、`TSentinelAllocator`、`TGuardAllocator`；或 `NEXTPAS_MEM_DEBUG` | 门面 |
| **2 子单元** | `TBoundedAllocator`、`TThreadSafeAllocator`、`TAlignedAllocator`、`TStatsAllocator`、`TFailAllocator`、`TSlabPoolConcurrent` … | `uses nextpas.core.mem.allocator.*` / `pool.slab.concurrent` 等 |
| **3 实验** | 已删或 growable 等 — 勿当默认 | 子单元 / 禁止回门面 |

热路径：**只** `DefaultHeap` / 过程式 `GetMem`。`DefaultAllocator` 是注入面，不要进热循环。

资源不足要写分支时用 **Try***（同一后端，False+nil，不抛）。**没有** TLS last-OOM API：

```pascal
if not TryGetMem(Size, P) then Exit;   // OOM — 用返回值，不要查 last-error
if not TryFreeMem(P) then ...;         // 丢 size 时的 size-class 恢复 free
if not TryArenaAlloc(Arena, N, P) then ...;
```

### 三套动词（勿混用）

| 动词 | 表面 | 释放 |
|------|------|------|
| `Alloc` / `Reset` | Arena 生命周期 | `Reset` / `RestoreToMark`（**不要** `FreeMem`） |
| `GetMem` / `FreeMem` | 通用堆 / IAllocator | 每块单独 free；热路径 `FreeMem(ptr,size)` |
| `Acquire` / `Release` | 固定大小池 `IPool` / BlockPool | 槽位归还池 |

### DEBUG 一键包装（`DefaultAllocator` only）

```bash
NEXTPAS_MEM_DEBUG=sentinel,leak,stats
```

| Token | 作用 |
|-------|------|
| `fail` / `oom` | `TFailAllocator`（最外；默认 FailAt=0 不失败） |
| `stats` | `TStatsAllocator` |
| `tracking` / `leak` | `TTrackingAllocator` |
| `sentinel` | `TSentinelAllocator`（最内贴真实块） |

- 固定叠层顺序，**不**按用户书写序乱叠
- **不**包装 `DefaultHeap` / 过程式 `GetMem`（热路径零税），除非：
  - `NEXTPAS_MEM_HEAP_DEBUG=1` — 过程式改走 DefaultAllocator 链（慢）
  - `NEXTPAS_MEM_HEAP_SAFETY=1` — 同上 + 无 token 时 inject tracking/sentinel
- `NEXTPAS_MEM_ARENA_STRICT=1` — Arena IAllocator `FreeMem(non-nil)` raise（默认 no-op）
- 测试/可观测：`GetDebugWrapConfig` / `GetDebugWrapTracking` / `ResetDebugWrapForTests`
- 门面：`IsMemHeapDebugEnabled` / `IsMemHeapSafetyEnabled` / `IsMemArenaStrictEnabled`
- 设计与验收：[DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md)

### 进程级 MemStats（M3-2）

```pascal
var S: TMemStats;
GetMemStats(S);
// S.LiveBytes / ReleasedBytes / LiveSpans … ← DefaultHeap (Growing)
// S.DebugCoverageGap / DebugObservesProcess … ← F1 假阴性可观测
// S.DebugActiveAllocs / DebugAllocCount … ← only if DEBUG wrap built
Writeln(FormatMemStats); // … debug_process=… debug_coverage_gap=…
```

- 对标 Go `runtime.ReadMemStats` 的“一结构体读进程堆”体验
- 热路径不调用；DEBUG 字段默认全 0
- 细节字段与 SC5 对齐：`TGrowingHeapStats`
- 插件面 sized free 助手：`FreeMemOf(Alloc, P, Size)` / `TryFreeMemOf`（见下节决策树；`TryFreeMemOf(nil, P)` 仅当 DefaultHeap 自有时 process free，foreign → False）
- 插件面 sized realloc：`ReallocMemOf(Alloc, P, Old, New)` / `TryReallocMemOf`（同门控；wrap 开时走 `Alloc.ReallocMem`；**Try 与非 Try 成功语义一致**，含 nil allocator → process GetMem）
- 一行 env profile：`FormatMemDebugProfile`（`heap_debug`/`heap_safety`/`arena_strict`/`debug`/`debug_process`/`debug_coverage_gap`）
- `FormatMemStats` 含 `heap_safety=` / `arena_strict=`（与 HEAP_DEBUG / coverage_gap 并列）
- 错误消息：`FormatAllocErrorMsg` / `IsWellFormedAllocErrorMsg`（见 [ERROR-POLICY.md](ERROR-POLICY.md)）
- 门面冻结：[FACADES-SURFACE.md](FACADES-SURFACE.md)

### FreeMemOf 决策树（H0）

无 DEBUG wrap 且无 HEAP_DEBUG/SAFETY 时，`FreeMemOf` 可能对 **DefaultHeap 自有** 块走 sized `DefaultHeap.FreeMem`，**不**调用 `AAllocator.FreeMem`。

```
已知 size 且指针来自 DefaultHeap / 同堆 inject？
├─ 需要插件观察 free（TTrackingAllocator.ActiveAllocCount 等）？
│  └─ 是 → 用 AAllocator.FreeMem(ptr)     // tui inject 反例
│  └─ 否 → FreeMemOf(alloc, ptr, size)  // 表/槽/builder 主路径
├─ NEXTPAS_MEM_DEBUG / HEAP_DEBUG 开启？
│  └─ FreeMemOf 会走 AAllocator.FreeMem，保留 tracking 链
└─ size 未知？
   └─ AAllocator.FreeMem 或先 TryBlockSize 再 sized
```

| 用 FreeMemOf | 用 IAllocator.FreeMem |
|--------------|----------------------|
| 容量字段已知的表/registry/槽 | inject 面要测 tracking 计数 |
| builder 缓冲（text/bytes；Realloc 用 `ReallocMemOf`） | 不确定是否同堆 |
| 解析器 node 数组（json/yaml/…） | （已关闭）无 size 的 owned 串 — **Era I** 起用 size 表 |
| owned 串 + size 表（`TJsonOwnedStr` / `TTomlOwnedBuf`） | tui inject 须观察 Free（永久 WAIVE FreeMemOf） |

样板：builders · json/yaml/toml/xml/ini/csv · collections.node/hashmap/swiss。  
**mem-owner**（Era J/K）：单 slab + 已记录 size 的 growable/chunked/stack/ring 用 `FreeMemOf`。  
**禁止**全仓机械替换；无 size 字段的复杂 slab 路径不默认扫。

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
│     ├─ 容量可知 → CreateDefaultArena / TLocalArena
│     ├─ IAllocator 有界 inject → CreateArenaAllocator(cap)  // LocalArena，满=nil
│     ├─ 需要增长 → TChunkedArena
│     ├─ 超大/编译器热路径 → TVirtualArena / CreateVirtualArenaAllocator
│     ├─ 编译单元作用域 → TCompilerUnitScope（BeginScope/Reset/EndScope）
│     ├─ HTTP 服务路径 → THttpServerOptions.WithRequestArena / NewHttpServerWithRequestArena
│     └─ 多线程共享 → TArenaConcurrent（显式）
│
├─ 频繁分配/释放相同大小的对象？
│  └─ 用 IPool (Acquire/Release)
│     ├─ 单线程 → TLocalBlockPool / TFixedSlabPool / TFixedPool
│     └─ 多线程 → TBlockPoolConcurrent / TShardedBlockPool
│
├─ 通用内存分配（大小不固定）？
│  └─ 过程式 GetMem / DefaultHeap（Growing 原生，热路径）
│     ├─ 需要 IAllocator 注入 → DefaultAllocator（非热路径）
│     ├─ 需要跟踪泄漏 → TTrackingAllocator 或 NEXTPAS_MEM_DEBUG=tracking
│     ├─ 需要 OOM 降级 → TFallbackAllocator
│     └─ 需要 slab 优化 → TSlabPool
│
└─ 不确定？→ DefaultHeap / GetMem 或 CreateDefaultArena（最常见）
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

## 错误处理策略（冻结）

全文见 [ERROR-POLICY.md](ERROR-POLICY.md)。摘要：

| 场景 | IAllocator / 热路径堆 | IArena | 固定池 |
|------|----------------------|--------|--------|
| OOM / 容量不足 | **nil** | **nil** | **nil / False** |
| 非法参数 | 抛 / 或 nil（Arena） | 常 **nil** | **抛** |
| 双重释放 / 坏指针 | 诊断器 **抛**；基堆 UB | N/A | **抛** |

**铁律**: 资源不足 = 返回值；编程错误 = 异常。不要把池满写成“Out of memory”异常，除非构造阶段无法取得后备内存。

## 常见误区

### ❌ 把 DefaultAllocator 当热路径默认堆

```pascal
// 错误：插件面虽同堆（S5），但仍是虚调用 + 单参 free 扫描；不要当热路径
P := DefaultAllocator.GetMem(64);
DefaultAllocator.FreeMem(P);
```

```pascal
// 正确：过程式 / DefaultHeap = Growing 零 vtable 热路径
P := GetMem(64);
FreeMem(P, 64);
// collections / 组合器注入则继续用 DefaultAllocator（自动同堆）
```

### ❌ 只开 NEXTPAS_MEM_DEBUG 就指望查过程式 GetMem 泄漏

```bash
# 错误预期：以为单开 DEBUG 就能看到 GetMem 泄漏
export NEXTPAS_MEM_DEBUG=tracking,stats
# 业务：P := GetMem(64); 忘记 FreeMem  →  tracking 仍为 0（默认）
```

```bash
# 正确（显式慢路径）：同意过程式 GetMem 改走 DefaultAllocator 诊断链
export NEXTPAS_MEM_DEBUG=tracking,stats
export NEXTPAS_MEM_HEAP_DEBUG=1
# 一行可观测（日志 / nextpas doctor mem-process-stats）：
#   heap_debug=y debug=y debug_active_allocs=… debug_allocs=… debug_frees=…
```

```pascal
// 或：热路径用进程快照；泄漏检测只包住 IAllocator 注入面
GetMemStats(S);  // DefaultHeap 字段始终可用；Debug* 默认只看插件面
WriteLn(FormatMemStats);  // heap_debug / debug + 可选 debug_active_* / debug_allocs
// 运行时门闩：if IsMemHeapDebugEnabled then …
// 或：L := TTrackingAllocator.Create(DefaultAllocator);
```

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
// 正确：需要重分配时用默认堆（Growing）
var P: Pointer;
P := GetMem(128);
P := ReallocMem(P, 128, 256);  // 已知 old size 的热路径
FreeMem(P, 256);
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

### ❌ 热循环 DefaultAllocator.GetMem（双轨反例）

```pascal
// 可运行：同堆，但每步 IAllocator 虚调用 + FreeMem(ptr) 扫描（见 Scorecard SC9）
LAlloc := DefaultAllocator;
P := LAlloc.GetMem(64);
LAlloc.FreeMem(P);
```

```pascal
// 正确：热路径过程式 / DefaultHeap + sized free
P := GetMem(64);
FreeMem(P, 64);
```

### ❌ 热路径默认 FreeMem(P)（未知 size）

```pascal
// 可运行但不推荐：Growing 需 span 扫描或回落（见 Scorecard SC8）
FreeMem(P);
```

```pascal
// 正确：已知 size 的热 free
FreeMem(P, Size);

// 丢了 size：门面 TryBlockSize 恢复 size-class 后再 sized free
var Sz: SizeUInt;
if TryBlockSize(P, Sz) then
  FreeMem(P, Sz)
else
  FreeMem(P);  // huge/foreign：兼容扫描或 System 回落
```

## 高级路径（子模块入口）

门面 `nextpas.core.mem` 导出 65 个常用类型。以下高级功能需直接引用子模块：

### Go-style Growing Allocator（即 DefaultHeap）

```pascal
// 门面已导出：DefaultHeap / GetMem 即 Growing 热路径
var GAlloc: TGrowingAllocator;
GAlloc := DefaultHeap;
P := GAlloc.GetMem(64);  // TLS cache 热路径
GAlloc.FreeMem(P, 64);

// 可观测 / 强制归还（SC5）
var Stats: TGrowingHeapStats;
GAlloc.GetHeapStats(Stats);   // LiveBytes, ReleasedBytes, ...
N := GAlloc.Scavenge;         // flush TLS → hard-release idle spans
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

**推荐**：`RequestArenaMiddleware` 在请求入口创建 LocalArena，handler 用 `HttpRequestArenaOf` 取 scratch，请求结束自动释放。

```pascal
uses nextpas.core.http;

// 启动时 — options carrier 内核接线（hello 示例）
LOptions := THttpServerOptions.Default.WithRequestArena; // 或 WithRequestArena(1 shl 20)
LServer := NewHttpServer(LRouter, LOptions);
// H1/H2 默认 transport：连接级 LocalArena（Reset 每请求/stream + HttpAttach/Detach）
// 自定义 / H3 transport：回退 HttpWithRequestArena middleware
// 工厂：LServer := NewHttpServerWithRequestArena(LRouter, LOptions);
// 任意 handler：LHandler := HttpWithRequestArena(LInner);
// Router 挂载（options-demo）：HttpUseRequestArena(LRouter);
// handler 内：HttpRequestArenaOf / HttpRequestAllocatorOf
// 运维诊断：HttpFormatProcessMemStats（/memstats 文本一行）

// handler
procedure Handle(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
var
  LArena: IArena;
  LBody, LHeaders: Pointer;
begin
  LArena := HttpRequestArenaOf(AReq);            // H1 attach / middleware 挂上的 LocalArena
  LHeaders := LArena.Alloc(4096);
  LBody := LArena.Alloc(SizeUInt(AReq.ContentLength));
  // ... 处理 ...
  // 不要 FreeMem(LBody)；请求结束 bulk 丢弃 Arena
  AW.WriteHeader(HTTP_STATUS_OK);
end;
```

手动路径（无中间件）：`HttpCreateRequestArena` / `CreateDefaultArena`，handler 自己持有并在结束时放掉接口。

#### Arena IAllocator 工厂（勿混）

| 工厂 | 后端 | 满时行为 | 用途 |
|------|------|----------|------|
| `CreateArenaAllocator(cap)` | TLocalArena | **nil**（有界） | 请求 inject / 已知上限 |
| `CreateVirtualArenaAllocator` | TVirtualArena | 继续增长 | 编译单元 / 大 AST |
| `HttpCreateRequestAllocator` | LocalArena | nil | HTTP 插件面 |
| `CompilerCreateUnitAllocator` | VirtualArena | 增长 | compiler 插件面 |

**错误用法**：把 `CreateArenaAllocator` 的 `cap` 当成 alignment 喂 Virtual 路径（9.1 前的 bug 面，已分流）。

### 场景 2: 编译器 AST 节点分配 (Arena per Compilation Unit / Session)

编译器处理一个源文件时，所有 AST 节点从 Arena 分配，编译完成时整体释放。

```pascal
uses nextpas.core.compiler.mem;

type
  PASTNode = ^TASTNode;
  TASTNode = record
    Kind: TNodeKind;
    Left, Right: PASTNode;
    Value: string;
  end;

function ParseUnit(const ASource: string): PASTNode;
var
  LScope: TCompilerUnitScope;
  LNode: PASTNode;
begin
  // 产品路径：compiler.mem 单元作用域（VirtualArena）
  FillChar(LScope, SizeOf(LScope), 0);
  LScope.BeginScope;
  try
    LNode := PASTNode(LScope.Alloc(SizeOf(TASTNode)));
    LNode^.Kind := nkUnit;
    LNode^.Left := PASTNode(LScope.Alloc(SizeOf(TASTNode)));
    LNode^.Right := PASTNode(LScope.Alloc(SizeOf(TASTNode)));
    ParseDeclarations(LScope, LNode);
    Result := LNode;
    { 注意：Result 仅在 scope 存活期内有效；跨单元请拷出或延长 scope。 }
  finally
    LScope.EndScope;  // bulk reclaim；不要 FreeMem 节点
  end;
end;

// 多单元会话（unit_arena_demo 产品路径）
// LSession.BeginSession; LSession.UnitBegin; … Alloc …; LSession.UnitEnd; LSession.EndSession;
// SessionPeak 记录各单元 PeakUsed 最大值
// 诊断一行（非热路径）：LSession.FormatStats / CompilerFormatSessionStats(LSession)
//   → "mem session: active=1 units=… peak=… used=…"
// 单单元：LScope.FormatStats / CompilerFormatUnitStats(LScope)
//   → "mem unit: active=1 peak=… used=…"
//
// 编译会话（TCompilationSession）：CreateBuildSession 已 BeginSession；
// AnalyzeSyntax / ResolveUnits / AnalyzeSemantics / LowerToMir：UnitBegin…UnitEnd；
// ParseGreenTree(..., MemAstAllocator)：根 AST 节点 TVec 走 session VirtualArena；
// MemScratchAllocator：依赖树 + sema 工作 TVec（phase 结束 Reset）；
// MemFormatSessionStats = FMemScope.FormatStats + " ast=… scratch=…"；
// MemSessionPeak / MemUnitCount 为产品诊断面。
//
// stage0 ops 投影（非热路径）：
//   nextpas build …  → mem-session-stats=<MemFormatSessionStats>
//   nextpas doctor … → mem-process-stats=<FormatMemStats>
//   command-envelope JSON：memSessionStats / memProcessStats
//
// Arena 契约（回归锁在 test_compiler_mem）：
//   FAstAllocator 不随 UnitBegin/ResetScratch 回收（仅 ResetSyntaxState）；
//   FScratchAllocator phase 结束 Reset；Detach 产物与 entry-owned nested 默认堆；
//   VirtualArena FreeMem = no-op，bulk reclaim 靠 Reset；SessionPeak 跨 UnitBegin 保留。
```

进程堆诊断一行（运维，非热路径）：`WriteLn(FormatMemStats);`

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
