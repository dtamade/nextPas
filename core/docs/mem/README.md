# nextpas.core.mem

标准库级内存底座。目标不是“更多分配器”，而是：**默认路径正确、契约一致、性能可证明、诊断零成本默认**。

**Lane 状态（2026-07-20）**: A–C **CLOSED**；D **Steady**；E **Steady+**；F **CLOSED**；**G Steady**（Ecosystem Steward 收口）— [ROADMAP](ROADMAP.md) · [PARITY](PARITY-GO-RUST.md) · [FACADES-SURFACE](FACADES-SURFACE.md) · [growable KEEP](GROWABLE-KEEP-2026-07-20.md) · [OPENSSL 堆纪律](OPENSSL-HEAP-DISCIPLINE.md)。
可用性权威：[USABILITY-SCORE.md](USABILITY-SCORE.md)。默认 focused：

```bash
make lane-focused LANE=mem
# make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
```

**活路线图**: [ROADMAP.md](ROADMAP.md) · 决策树：[API-GUIDE.md](API-GUIDE.md) · 性能：[SCORECARD.md](SCORECARD.md) · Tier 规则：[STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §3

**Consumer audit（FIX CLOSED）**: [摘要](CONSUMER-AUDIT-SUMMARY-2026-07-17.md) · [Findings](CONSUMER-AUDIT-FINDINGS-2026-07-17.md)。回归：`check_consumer_audit_contracts.sh`（guardrails source-contract）。

**Steward 观测（2026-07-17，只读）**: [Inventory 可删清单](INVENTORY-AUDIT-2026-07-17.md) · [Consumer 热路径/unsized free](CONSUMER-OBSERVATION-2026-07-17.md) — **不删代码、不强制改 consumer**。

**P-a / P-b prune（EXECUTED）**: [P-a](PRUNE-P-a-DESIGN-2026-07-19.md) · [P-b](PRUNE-P-b-DESIGN-2026-07-19.md) — 实验分配器博物馆已收敛（保留 blockpool.growable）。

**Go/Rust 对照**: `make -C core/benchmarks/nextpas.core.mem/bench_arena_go_rust compare`

**证据入口**: `make -C core/tests/nextpas.core.mem/scorecard clean test RELEASE=1` · `make -C core/tests/nextpas.core.mem/test_soak clean test` · `make -C core/tests/nextpas.core.mem/test_mem_cross_os_compile_gate clean test`

---

## 30 秒上手

```pascal
uses nextpas.core.mem;

var
  P: Pointer;
  Arena: IArena;
  S: TMemStats;
  Sz: SizeUInt;
begin
  { 1. 通用堆热路径 — Growing，无 interface 间接调用 }
  P := GetMem(64);
  FreeMem(P, 64);   // 已知 size 的热 free（优选）

  { 1a. ERROR-POLICY 可操作形态：资源不足 = False，不抛 }
  if TryGetMem(128, P) then
  begin
    // ...
    if not TryFreeMem(P) then  // size-class 恢复 + sized free
      FreeMem(P);              // 兜底
  end;

  { 1b. 丢了 size 时：先 TryBlockSize 再 sized free（仍优于裸 FreeMem(P)） }
  P := GetMem(128);
  if TryBlockSize(P, Sz) then
    FreeMem(P, Sz)
  else
    FreeMem(P);     // 兼容：内部同样会扫描

  { 2. 请求/帧生命周期 — Arena，Reset 一次放完 }
  Arena := CreateDefaultArena(64 * 1024);
  P := Arena.Alloc(128);
  Arena.Reset;

  { 3. 进程堆快照（运维 / 测试，非热路径） }
  GetMemStats(S);
  // S.LiveBytes, S.ReleasedBytes, ...
end;
```

| 你要做什么 | 用什么 | 不要用 |
|------------|--------|--------|
| malloc 替代 / 通用对象 | `GetMem` / `DefaultHeap` | 热循环里的 `DefaultAllocator` |
| 请求结束一起释放 | `CreateDefaultArena` / `TLocalArena` | 对 Arena 指针 `FreeMem` |
| 请求 inject（有界） | `CreateArenaAllocator(cap)` | 把 cap 当 alignment 的 Virtual 路径 |
| 编译单元 / 大 AST | `CreateVirtualArenaAllocator` / `compiler.mem` | 有界 LocalArena 塞超大 AST |
| 固定大小高频 | `TLocalBlockPool` / `TFixedSlabPool` | 可变大小塞进 IPool |
| 注入/组合/测泄漏 | `DefaultAllocator` + 包装器 | 当默认热路径 |
| 一键诊断 | 见下表 DEBUG | 改业务调用点 |
| HTTP 请求 scratch | `HttpCreateRequestArena` / **`RequestArenaMiddleware`** | 对 Arena 块 `FreeMem` |

---

## 默认双轨（必读）

**一句话**：一个进程堆，两种调用面——热路径要零 vtable，插件面要 `IAllocator`。

| API | 实现 | 角色 |
|-----|------|------|
| **`DefaultHeap` / 过程式 `GetMem`·`FreeMem`·`AllocMem`·`ReallocMem`** | `TGrowingAllocator` 原生 | **热路径** |
| **`DefaultAllocator: IAllocator`** | Growing IAllocator 根，可叠 `NEXTPAS_MEM_DEBUG` | 插件/诊断/注入，**非热路径**（同堆，有 vtable） |

硬规则：框架与业务热循环走 `DefaultHeap`；不要为“接口统一”把热路径改回 `IAllocator` 虚调用。
S5：`DefaultAllocator` 与 `DefaultHeap` **同一进程堆**（互释合法，见 SC9 `same_heap`）；collections 等注入路径自动吃 Growing。显式 RTL 仍可用 `GetRtlAllocator`。

性能证据：Scorecard **SC9** — `hot_heap` vs `plugin_ia`（vtable + 单参 free 扫描税）。

```pascal
{ 热路径 — 已知 old size }
P := GetMem(32);
P := ReallocMem(P, 32, 128);
FreeMem(P, 128);

{ 插件面 — 组合器 / collections 注入（同堆，虚调用） }
LAlloc := DefaultAllocator;
LWrap := TTrackingAllocator.Create(LAlloc);

{ 同堆互释（合法，但热循环仍应走过程式/DefaultHeap） }
P := DefaultAllocator.GetMem(64);
if TryBlockSize(P, Sz) then
  FreeMem(P, Sz);
```

### 错误用法（必读）

| 错误 | 为什么错 | 正确 |
|------|----------|------|
| 热循环 `DefaultAllocator.GetMem` | 虚调用 + 单参 free 扫描，不是零 vtable 热路径 | `GetMem` / `DefaultHeap` |
| `NEXTPAS_MEM_DEBUG=leak` 查 `GetMem` 泄漏 | 默认 DEBUG **只**叠插件面 | 再开 `NEXTPAS_MEM_HEAP_DEBUG=1`（慢）；或 `GetMemStats` / 注入面 DEBUG |
| 对 Arena 指针 `FreeMem` | 生命周期属 Arena | `Arena.Reset` / `RestoreToMark` |
| `FreeMem(P)` 当热路径默认 | 未知 size 要扫 span，更慢（SC8 可证） | `FreeMem(P, Size)`；丢 size 时 `TryBlockSize` 再 sized free |
| 把 `DefaultAllocator` 当“零成本默认堆” | 它是注入/诊断面（虽同堆） | 热路径 = `DefaultHeap` / 过程式 `GetMem` |

防呆门禁：`make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails`

---

## 选择决策树

```text
有限生命周期（请求/帧/文档）？
  是 → Arena
       容量可知     → CreateDefaultArena / TLocalArena
       需要增长     → TChunkedArena
       超大/编译器  → TVirtualArena (+ AllocFast)
       多线程共享   → TArenaConcurrent（显式）
  否 → 固定大小高频？
         是 → TLocalBlockPool / FixedSlab / BlockPool
         否 → DefaultHeap / GetMem
诊断 / 故障注入 → 包装器或 NEXTPAS_MEM_DEBUG（只叠 DefaultAllocator）
预算 / OOM 降级 → Bounded / Fallback / Budget / OomHandler
```

细节与误区见 [API-GUIDE.md](API-GUIDE.md)。

---

## 契约（摘要）

全 Tier-0/1 必须遵守；完整矩阵：

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
```

| 操作 | 行为 |
|------|------|
| `GetMem(0)` / `Alloc(0)` | nil |
| `FreeMem(nil)` / `Release(nil)` | 无操作 |
| `ReallocMem(nil, n)` | ≡ `GetMem(n)` |
| `ReallocMem(p, 0)` | ≡ `FreeMem(p)` |
| OOM / 容量不足 | **返回 nil 或 False**（不抛） |
| 编程错误（双 free / 坏指针 / 非法参数） | **抛 `EAllocError`**（池与诊断器；基堆双 free 为 UB 除非开 DEBUG 包装） |

Growing 热路径：`FreeMem(ptr, size)` 优于 `FreeMem(ptr)`（Scorecard **SC8**）；`ReallocMem(ptr, old, new)` 优于未知 old size。丢 size 时门面 `TryBlockSize(ptr, out size)` 可恢复 size-class 容量。

错误模型冻结全文：[ERROR-POLICY.md](ERROR-POLICY.md)。

---

## 可观测性

```pascal
var S: TMemStats;
GetMemStats(S);
```

| 字段族 | 来源 | 含义 |
|--------|------|------|
| `LiveBytes` / `LiveSpans` / `IdleSpans` | DefaultHeap | 当前保留 |
| `Released*` / `Decommit*` | DefaultHeap scavenge | 归还 OS 寿命计数 |
| `heap_debug` / `HeapDebugEnabled` | HEAP_DEBUG 或 HEAP_SAFETY | 过程式路径是否走插件链 |
| `heap_safety` / `HeapSafetyEnabled` | `NEXTPAS_MEM_HEAP_SAFETY` | dev 双 free profile |
| `arena_strict` / `ArenaStrictEnabled` | `NEXTPAS_MEM_ARENA_STRICT` | Arena FreeMem raise |
| `debug` / `DebugEnabled` | `NEXTPAS_MEM_DEBUG`（或 SAFETY 注入） | wrap 是否建成 |
| `debug_process` / `DebugObservesProcess` | debug ∧ heap_debug | wrap 是否观察过程式 GetMem |
| `debug_coverage_gap` | debug ∧ ¬heap_debug | **假阴性风险**（只 DEBUG 不看热路径） |
| `DebugActiveAllocs` / `DebugAllocCount` | 仅 wrap 建成时 | 插件面诊断计数 |

`FormatMemStats` 一行始终含 `heap_safety=` / `arena_strict=` / `debug_process=` / `debug_coverage_gap=`。
仅要开关快照时用 `FormatMemDebugProfile`（无 live_bytes 等保留计数）。

Gate：`make focused FOCUS=core/tests/nextpas.core.mem/test_get_mem_stats`

强制 scavenge：`DefaultHeap.Scavenge`（先 flush TLS）。字段与 SC5 对齐，见 [SCORECARD.md](SCORECARD.md)。

---

## DEBUG 一键包装

| 你在查什么 | 开什么 | 别指望 |
|------------|--------|--------|
| 注入面 / collections 泄漏 | `NEXTPAS_MEM_DEBUG=leak`（或 `sentinel,leak,stats`） | 过程式 `GetMem`（见 `debug_coverage_gap=y`） |
| 过程式 `GetMem` 泄漏 | **再加** `NEXTPAS_MEM_HEAP_DEBUG=1`（慢） | 热路径零税 |
| dev 双 free profile | `NEXTPAS_MEM_HEAP_SAFETY=1`（自动 tracking+sentinel） | 生产默认开 |
| Arena FreeMem 混用 | `NEXTPAS_MEM_ARENA_STRICT=1` | 默认 no-op 兼容 |
| 进程堆快照 | `GetMemStats` / `FormatMemStats`（无需 DEBUG） | `DebugActive*` 仅 wrap 建成 |
| doctor 一行进程诊断 | `nextpas doctor` → `mem-process-stats=` | session arena（用 build `mem-session-stats`） |

```bash
NEXTPAS_MEM_DEBUG=sentinel,leak,stats
NEXTPAS_MEM_HEAP_DEBUG=1   # 仅当必须覆盖过程式 GetMem；DefaultHeap 仍裸
# 或：NEXTPAS_MEM_HEAP_SAFETY=1
# FormatMemStats / doctor：
#   heap_debug=y debug=y debug_process=y debug_coverage_gap=n
#   debug_active_allocs=… debug_allocs=… debug_frees=…
# 仅 DEBUG=stats → heap_debug=n debug=y debug_coverage_gap=y（假阴性可见）
# 仅 HEAP_DEBUG=1、无 NEXTPAS_MEM_DEBUG → heap_debug=y debug=n（无 plugin 计数）
```

- **只**包装 `DefaultAllocator`（fail → stats → tracking → sentinel → Growing IAllocator）
- 默认 **不**包装 `DefaultHeap` / 过程式 `GetMem`（热路径零税）
- 门面：`IsMemHeapDebugEnabled` / `IsMemHeapSafetyEnabled` / `IsMemArenaStrictEnabled`、`FormatMemStats`（含 `heap_safety`/`arena_strict`）、`FormatMemDebugProfile`、`FreeMemOf`/`ReallocMemOf`、`FormatAllocErrorMsg`
- Token：`fail`/`oom`、`stats`、`tracking`/`leak`、`sentinel`
- Gate：`make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap`；体验锁：`test_usability_guardrails`
- CI / verify：`make stage0-heap-debug-recipe`（`scripts/stage0-heap-debug-env-recipe.sh`；doctor 双轨投影）
- 设计：[DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md)

### HTTP / compiler 产品路径

```pascal
uses nextpas.core.http;  // re-exports http.mem + RequestArenaMiddleware

{ 手动：handler 自己持有 }
LArena := HttpCreateRequestArena;           // 请求 scratch，结束即丢
LAlloc := HttpCreateRequestAllocator;       // LocalArena IAllocator，FreeMem no-op
LHeap  := HttpProcessHeap;                  // = DefaultHeap

{ 推荐：options carrier 内核接线（hello 示例） }
LOptions := THttpServerOptions.Default.WithRequestArena;
LServer := NewHttpServer(LRouter, LOptions);
// H1/H2 默认：连接级 LocalArena，每请求/stream Reset + HttpAttach（无 middleware 双层）
// 工厂：NewHttpServerWithRequestArena(LRouter, LOptions);
// 任意 handler：HttpWithRequestArena(LInner);
// Router：HttpUseRequestArena(LRouter);
// handler: HttpRequestArenaOf / HttpRequestAllocatorOf
// 运维：HttpFormatProcessMemStats  // live_bytes=… heap_debug=…
```

```pascal
uses nextpas.core.compiler.mem;

{ 推荐（多单元会话）：TCompilerSessionScope }
var LSession: TCompilerSessionScope;
FillChar(LSession, SizeOf(LSession), 0);
LSession.BeginSession;
try
  LSession.UnitBegin;
  LNode := LSession.Alloc(SizeOf(TAstNode));
  LSession.UnitEnd;   // 记录 peak；下个 UnitBegin 会 Reset
  // 诊断一行：LSession.FormatStats / CompilerFormatSessionStats(LSession)
finally
  LSession.EndSession;
end;

{ 单单元：TCompilerUnitScope（BeginScope/EndScope 配对） }
var LScope: TCompilerUnitScope;
FillChar(LScope, SizeOf(LScope), 0);
LScope.BeginScope;
try
  LNode := LScope.Alloc(SizeOf(TAstNode));  // VirtualArena AST/IR
  LScope.Reset;                             // 单元边界 bulk reclaim
finally
  LScope.EndScope;
end;

{ 或裸 API }
CompilerInitUnitArena(LUnitArena);
// ...
CompilerReleaseUnitArena(LUnitArena);
LPlugin := CompilerCreateUnitAllocator;     // IAllocator inject
```

进程堆一行快照（运维/测试，非热路径）：

```pascal
WriteLn(FormatMemStats);  // live_bytes=… free_slots=… heap_debug=n …
```

#### Arena IAllocator 工厂分流（契约）

| 工厂 | 后端 | 容量语义 |
|------|------|----------|
| `CreateArenaAllocator(cap)` | **TLocalArena** | **有界**：满返回 nil |
| `CreateVirtualArenaAllocator` | **TVirtualArena** | **可增长**（mmap）；编译/大 AST |
| `HttpCreateRequestAllocator` | LocalArena | 同 CreateArenaAllocator |
| `CompilerCreateUnitAllocator` | VirtualArena | 同 CreateVirtualArenaAllocator |

Gate：
- `make focused FOCUS=core/tests/nextpas.core.http/test_http_mem`
- `make focused FOCUS=core/tests/nextpas.core.compiler/test_compiler_mem`

---

## 性能（Scorecard）

权威入口是 Scorecard，不是历史微基准博物馆。

```bash
make focused FOCUS=core/tests/nextpas.core.mem/scorecard
make -C core/tests/nextpas.core.mem/scorecard clean test RELEASE=1
```

| ID | 场景 | 要证明的事 |
|----|------|------------|
| SC1 | 64B alloc+free | 默认堆吞吐 |
| SC2 | mixed 16B–4KB | 多 size-class + p99 |
| SC3 | cross-thread free | 正确性 + 并发代价 |
| SC4 | arena reset+reuse | 确定性生命周期 |
| SC5 | long-run scavenge | LiveBytes / Released* |
| SC6 | VirtualArena AST churn | 编译器式 bulk reclaim |
| SC7 | LocalArena per-request | HTTP 式 p99 |
| SC8 | sized vs unsized free | `FreeMem(ptr,size)` 税 |
| SC9 | hot heap vs plugin IA | 双轨税（~8–9×） |

最新数字与环境见 [SCORECARD.md](SCORECARD.md)（RELEASE=1 基线 2026-07-17）。改 Growing/DefaultHeap 必跑：

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make focused FOCUS=core/tests/nextpas.core.mem/test_stability
make focused FOCUS=core/tests/nextpas.core.mem/test_concurrent
make focused FOCUS=core/tests/nextpas.core.mem/scorecard
```

---

## Arena / Pool 速查

| 场景 | 推荐 |
|------|------|
| 请求/帧固定容量 | `TLocalArena` / `CreateDefaultArena` |
| 可增长批量 | `TChunkedArena` |
| 编译器热路径 | `TVirtualArena` + `AllocFast` |
| 多线程共享 arena | `TArenaConcurrent`（显式） |
| 单线程固定块 | `TLocalBlockPool` |
| 公共 IBlockPool 契约 | `TBlockPool` / concurrent / sharded |
| 可变 size-class slab | `TSlabPool` |

```pascal
var Arena: TLocalArena;
Arena := TLocalArena.Create(64 * 1024);
try
  P := Arena.Alloc(64);
  Arena.Reset;
finally
  Arena.Free;
end;
```

---

## 门面与 Tier

- **门面** `nextpas.core.mem`：Tier-0 + 生产诊断（tracking/sentinel/guard）+ mapped/ring/mimalloc（**冻结**；F3 已 demote 冷门包装器）
- **冷门包装器 / 并发池变体 / Tier-3**：直接 `uses` 子单元，无门面兼容承诺
- 门面白名单 / demoted 名单：[FACADES-SURFACE.md](FACADES-SURFACE.md)
- 分层规则与符号表：[STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §3
- 架构 / owner：[ARCHITECTURE.md](ARCHITECTURE.md)
- 运行时契约全文：[CONTRACT.md](CONTRACT.md)
- 参考 API 百科（长）：[API.md](API.md) — **以本 README + API-GUIDE 为准**；API.md 中 “Default=RTL 热路径” 为历史表述

---

## 成功标准（进度）

| # | 标准 | 状态 |
|---|------|------|
| S1 | 默认路径无聊且正确 | ✅ 双轨文档 + 决策树 + 反例 + guardrails |
| S2 | 契约矩阵 | ✅ `test_contract_matrix`（RTL/Growing/DefaultHeap/Arena/Pool） |
| S3 | Scorecard 可信 | ✅ SC1–SC9 + RELEASE 基线（2026-07-17） |
| S4 | 诊断零成本默认 | ✅ `NEXTPAS_MEM_DEBUG`（仅插件面） |
| S5 | 上层注入吃 DefaultHeap | ✅ Growing IAllocator 根；**HTTP + compiler 产品面**；compiler 源改用另 lane |
| S6 | Arena/Pool 延迟优势 | ✅ SC4 / SC6 / SC7 |
| S7 | 小门面 | ✅ Tier-3 出门面；F3 uses 65→41 |

---

## 文档索引

| 文档 | 用途 |
|------|------|
| **[ROADMAP.md](ROADMAP.md)** | **唯一活路线图**（时代 D） |
| [USABILITY-SCORE.md](USABILITY-SCORE.md) | **权威**可用性评分（主线 CLOSED） |
| [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) | 时代 B 档案；**§3 Tier 仍权威** |
| [API-GUIDE.md](API-GUIDE.md) | 选择决策树与误区 |
| [ERROR-POLICY.md](ERROR-POLICY.md) | **错误模型冻结**（nil vs raise） |
| [SCORECARD.md](SCORECARD.md) | SC1–SC9 权威性能（RELEASE 基线） |
| [DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md) | DEBUG 链设计 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层与 owner |
| [CONTRACT.md](CONTRACT.md) | 运行时契约 |
| [FACADES-SURFACE.md](FACADES-SURFACE.md) | 门面白/黑名单 |
| [CONSUMER-AUDIT-SUMMARY-2026-07-17.md](CONSUMER-AUDIT-SUMMARY-2026-07-17.md) | consumer-audit 收口摘要（FIX CLOSED） |
| [INVENTORY-AUDIT-2026-07-17.md](INVENTORY-AUDIT-2026-07-17.md) | Tier-3 / 无 consumer 可删清单（**未删**） |
| [CONSUMER-OBSERVATION-2026-07-17.md](CONSUMER-OBSERVATION-2026-07-17.md) | unsized free / 插件面只读观测 |
| [BENCHMARKS.md](BENCHMARKS.md) | 历史微基准（非 Ready 权威） |
| [API.md](API.md) | 长参考；冲突时以 README/GUIDE 为准 |
| [USABILITY-AUDIT.md](USABILITY-AUDIT.md) | 历史可用性长报告（SUPERSEDED） |
| [archive/](archive/) | 时代 A ROADMAP phase 清单与旧设计 |
