# mem 可用性评估发现 — 专题调研报告

**状态**: Research complete (…S1–S3 fixed; **T1–T4 residual** researched + implementing 2026-07-17)
**日期**: 2026-07-16 / 修订 2026-07-17（四轮残留 T1–T4）
**范围**: F1–F7 + R1–R5 + S1–S3 + T1–T4（见 [USABILITY-EVAL-2026-07-17.md](USABILITY-EVAL-2026-07-17.md)）
**权威评估**: … → S1–S3 **9.3** → 四轮审查 **9.05** → T1–T4 目标 **9.35**
**非目标**: 合并双轨热路径、默认开启生产安全税、新增 allocator 种类、reopen product-table dual-track、全库 pool raise 扫改

---

## 1. 问题总表

| ID | 分类 | 摘要 | 影响面 | 风险 | 优先级 |
|----|------|------|--------|------|--------|
| F1 | 诊断/可观测 | `NEXTPAS_MEM_DEBUG` 不观察过程式 `GetMem`，易假阴性 | 运维、测试、doctor | MEDIUM | P1 |
| F2 | API 形状/性能 | sized free 仅过程式优选；插件面 `IAllocator.FreeMem` 无 size | 热路径、collections 注入 | MEDIUM | P1 |
| F3 | 内存安全 | 基堆双 free/野指针默认 UB | 生产缺陷难查 | HIGH（条件） | P1 |
| F4 | 所有权/一致性 | Arena 适配器 `FreeMem` 静默 no-op | 混用 Alloc/GetMem | MEDIUM | P2 |
| F5 | 错误模型 | 异常类型分叉；消息格式未强制 | 调用方 except 面 | LOW–MED | P2 |
| F6 | 接口面 | 门面 re-export 仍宽；与 S7 张力 | 可发现性、长期兼容 | LOW | P2 |
| F7 | 过程/门禁 | 空断言；`10.0++++` 评分通胀 | 可信度 | LOW | P0（纪律，先做） |

---

## 2. 逐项根因、对标与策略

### F1 — 双轨 DEBUG 假阴性

| 项 | 内容 |
|----|------|
| **根因** | 设计上 DEBUG 只叠 `DefaultAllocator`，保证 `DefaultHeap` 零税。过程式 `GetMem` 需另开 `NEXTPAS_MEM_HEAP_DEBUG`。两变量语义正确但**可观测性不足**：`FormatMemStats` 有 `heap_debug`/`debug` 却不显式标“覆盖缺口”。 |
| **影响** | 只设 `NEXTPAS_MEM_DEBUG=leak` 时 tracking 不统计 `GetMem`；用户误判无泄漏。 |
| **Go** | 单一堆 + `GODEBUG`/`ReadMemStats`，无第二表面。 |
| **Rust** | debug 构建 + sanitizer 覆盖分配路径，不拆两套默认。 |
| **策略** | **不合并双轨**。在 `TMemStats`/`FormatMemStats` 增加覆盖缺口字段（如 `debug_process` / `debug_coverage_gap`）；纯函数可测；文档与 recipe 对齐；guardrails 锁假阴性可见。 |
| **风险** | 低：只增观测，不改默认路径。字符串格式变更需更新断言。 |

### F2 — sized free 不可强制

| 项 | 内容 |
|----|------|
| **根因** | Growing 原生 `FreeMem(ptr,size)` 快；`IAllocator` 冻结为五方法且 `FreeMem(ptr)` 单参，插件面结构性 unsized（SC8 ~8×）。 |
| **影响** | 丢 size 合法但慢；注入路径难传 size。 |
| **Go** | 用户不 free。 |
| **Rust** | `dealloc(ptr, Layout)` 强制 size/align。 |
| **策略** | 保持 `IAllocator` 五方法冻结。门面增加 **sized free 助手** `FreeMemOf(IAllocator, ptr, size)` / `TryFreeMemOf`：同堆块且无 process/plugin DEBUG 时走 `DefaultHeap.FreeMem(ptr,size)`，否则回落 `AAllocator.FreeMem(ptr)`（避免 tracking 漏 free）。过程式路径已有 sized 过载 — 用契约/guardrails 锁。**不**改 ERROR-POLICY nil/raise 铁律。 |
| **风险** | 中低：误对非 Growing 块 sized free 须先 `TryBlockSize` 或仅在同堆路径使用；实现必须失败安全；DEBUG 开时禁止 sized 短路。 |

### F3 — 热路径编程错误 UB

| 项 | 内容 |
|----|------|
| **根因** | 热路径零税选择：基堆不检双 free。检测存在于 DEBUG 包装器，但默认不覆盖过程式堆。 |
| **影响** | 生产双 free = UB；调试需知 HEAP_DEBUG+token 组合。 |
| **Go** | runtime 有一定防护 + GC。 |
| **Rust** | Miri/ASan/debug assert。 |
| **策略** | 新增 **opt-in safety profile**：`NEXTPAS_MEM_HEAP_SAFETY`（truthy）≡ 过程式堆走插件链 **且** 若未配置 DEBUG token 则默认 `tracking,sentinel`。生产默认仍关。文档写清 dev profile。 |
| **风险** | 中：安全 profile 有税（近 SC9）；必须永不默认开启。缓存/单例重建与现有 HEAP_DEBUG 共用路径。 |

### F4 — Arena FreeMem 静默 no-op

| 项 | 内容 |
|----|------|
| **根因** | Arena→IAllocator 适配器契约：生命周期属 Arena，`FreeMem` no-op 以便注入方无条件调用 Free。 |
| **影响** | 误把 Arena 块当堆 free 时无信号。 |
| **Go** | 无用户级 free；`sync.Pool` / 手写 bump 靠约定；混用不会 silent-free 堆块，但 GC 掩盖误用。 |
| **Rust** | `bumpalo`/`typed-arena`：块不实现独立 `Drop` 释放；类型系统阻止 `Box`/`dealloc` 对 arena 指针；越界 API 在 debug 可 panic。 |
| **策略** | 默认保持 no-op（兼容）。Opt-in `NEXTPAS_MEM_ARENA_STRICT`：`FreeMem(non-nil)` raise `EAllocError(aeInvalidPointer)` + `Type.Method: reason`。契约测试双模式。 |
| **风险** | 中：若上层依赖 no-op Free，strict 会破；默认 off 可接受。 |

### F5 — 异常与消息不一致

| 项 | 内容 |
|----|------|
| **根因** | 历史多异常类（`EMemFixedPool*`、`EStackPoolError`）；`EOutOfMemory` 不挂 `EAllocError`；消息格式推荐未工具化。 |
| **影响** | `except on EAllocError` 不完整；消息机器不可靠解析。 |
| **Go** | 错误是 `error` 接口；惯例 `fmt.Errorf("pkg.Op: %w", err)` / `errors.Is`/`As`；无异常层次树，但消息 stem 约定可机读。 |
| **Rust** | `Result` + `thiserror`/`anyhow`；`Display`/`Error::source` 统一链；分配失败多为 `AllocError`/`try_reserve` 返回值而非 panic（`oom=panic` 可配）。 |
| **策略** | 门面暴露 `FormatAllocErrorMsg` / `IsWellFormedAllocErrorMsg` 纯助手；ERROR-POLICY 写明统一 catch 面为 `ENextPasError` + `TAllocError` 码；本批 **新建/修改的 raise** 必须用助手；contract 测助手与若干代表路径。**不**做全库异常类大迁移（爆炸半径）。 |
| **风险** | 低（助手+文档+抽测）；全库重写 raise 不做。 |

### F6 — 门面膨胀

| 项 | 内容 |
|----|------|
| **根因** | 分配器博物馆时代 re-export；S7 要求面小但门面仍含大量 Tier-1/2。 |
| **影响** | 可发现性差；误用实验类型。 |
| **Go** | 标准库 `runtime`/`sync` 面积极小；实验能力在 `x/` 或第三方；用户默认路径几乎只有 GC 堆。 |
| **Rust** | `std::alloc` + `Global` 极小；特殊分配器在 `allocator_api` 特性或 crates.io；不把实验 crate 的类型 re-export 进 `std`。 |
| **策略** | **冻结**：文档白名单 + source-contract 测试禁止门面 `uses` Tier-3（prediction/numa/replay/…）。本批 **不** 大规模删除 Tier-2 re-export（兼容），禁止新增。见 [FACADES-SURFACE.md](FACADES-SURFACE.md)。 |
| **风险** | 低。 |

### F7 — 空断言与评分通胀

| 项 | 内容 |
|----|------|
| **根因** | 占位 `Check(True,…)`；自评用 `10.0++++` 记进度。 |
| **影响** | 门禁可信度与外部评估不一致。 |
| **Go** | `testing` 要求失败路径可证明（`t.Fatal`/`cmp`）；无“永远 True”占位；质量分若存在则用独立 rubric（如 Go 官方博客/设计评审），不靠 `+` 串联自抬。 |
| **Rust** | `assert!`/`assert_eq!` 绑定真实谓词；`cargo test` 不鼓励 no-op；crate 评分（crates.io/docs.rs）与工程自评分离，避免内部“满分链”。 |
| **策略** | 删除空断言，改为真实双轨表面检查；USABILITY-SCORE 改为独立 rubric（基线 7.7 → 修复后重评），废除 plus-chain。 |
| **风险** | 极低。 |

---

## 3. 跨项依赖

```text
F7 (纪律) ─────────────────────────────► 任意实现前清理门禁噪声
F1 (观测) ──┬──► FormatMemStats/TMemStats 扩展
            └──► F3 safety profile 共用 env/cache
F3 (safety) ──► 扩展 HEAP_DEBUG 解析路径 / ResolveDefaultAllocator
F2 (sized)  ──► 门面 FreeMemOf（依赖 DefaultHeap / TryBlockSize）
F4 (arena)  ──► 可选 strict 与 F3 env 正交
F5 (error)  ──► FormatAllocErrorMsg；F4 raise 复用
F6 (facade) ──► 文档 + source contract（独立）
```

---

## 4. 总体风险与回滚

| 策略选择 | 风险 | 回滚 |
|----------|------|------|
| 只增观测/助手/opt-in | 低 | 关 env / 删助手调用 |
| 改 FormatMemStats 行格式 | 中（断言） | 同步更新测试与 recipe |
| 默认开启安全税 | **禁止** | N/A |

**结论（F1–F7）**: 七项已用 **观测 + opt-in 安全 + 助手 API + 契约测试 + 文档冻结** 落地。

---

## 5. 本轮残留 R1–R5（2026-07-17 复评）

| ID | 分类 | 摘要 | 影响面 | 风险 | 优先级 |
|----|------|------|--------|------|--------|
| R1 | 诊断 | FormatMemStats 不打印 `heap_safety` | 运维/doctor | MEDIUM | P1 |
| R2 | 诊断 | ArenaStrict 未进 TMemStats/FormatMemStats | 运维 | MEDIUM | P1 |
| R3 | API 对称 | 缺 ReallocMemOf / TryReallocMemOf | 插件注入 | MEDIUM | P1 |
| R4 | 可发现性 | 四 env 无单行 profile | 配方错误 | LOW–MED | P2 |
| R5 | 门禁 | R1–R4 无 source/guardrails 锁 | 回归 | LOW | P0 |

### R1 — FormatMemStats 省略 heap_safety

| 项 | 内容 |
|----|------|
| **根因** | F3 加了 `TMemStats.HeapSafetyEnabled` 与 `IsMemHeapSafetyEnabled`，FormatMemStats 只扩展了 coverage_gap 族，漏打 safety 位。 |
| **影响** | `NEXTPAS_MEM_HEAP_SAFETY=1` 时日志无法确认 profile；与 heap_debug 混淆。 |
| **Go** | MemStats / GODEBUG 相关状态可观测，不藏半套开关。 |
| **Rust** | 环境/feature 开关在诊断输出中显式（或编译期明确）。 |
| **策略** | FormatMemStats 增加 `heap_safety=y|n`（读现有字段）。 |
| **风险** | 低：格式追加字段；更新 guardrails 断言。 |

### R2 — ArenaStrict 不可见

| 项 | 内容 |
|----|------|
| **根因** | F4 只加 env 与 FreeMem 行为，未进进程 stats 快照。 |
| **影响** | doctor 不知 ARENA_STRICT 是否生效。 |
| **Go/Rust** | 行为开关应可查询（配置 dump / debug print）。 |
| **策略** | `TMemStats.ArenaStrictEnabled` + FormatMemStats `arena_strict=`；GetMemStats 填 IsMemArenaStrictEnabled。 |
| **风险** | 低。 |

### R3 — 插件面缺 sized realloc 助手

| 项 | 内容 |
|----|------|
| **根因** | F2 只补 FreeMemOf；过程式已有 `ReallocMem(ptr,old,new)`，插件面 IAllocator.ReallocMem 单参 new。 |
| **影响** | collections 注入路径 sized realloc 不可对称调用；或绕过 tracking。 |
| **Go** | 用户不 realloc 裸指针。 |
| **Rust** | `realloc(ptr, Layout, new_size)` 强制带旧 Layout。 |
| **策略** | `ReallocMemOf` / `TryReallocMemOf`：门控同 FreeMemOf（无 process DEBUG 且无 wrap 时 DefaultHeap sized realloc；否则 `AAllocator.ReallocMem(ptr,new)`）。 |
| **风险** | 中低：与 FreeMemOf 同 stale-tracking 坑；必须共用门控。 |

### R4 — 多 env 无单行 profile

| 项 | 内容 |
|----|------|
| **根因** | 四独立 env 逐步叠加，无 `FormatMemDebugProfile` 一类入口。 |
| **影响** | 用户/CI 拼配方易漏 HEAP_DEBUG → 假阴性。 |
| **Go** | GODEBUG 字符串集中。 |
| **Rust** | 少量 env + 文档；或 cargo 特性。 |
| **策略** | 门面 `FormatMemDebugProfile`：一行 `heap_debug=… heap_safety=… arena_strict=… debug=… debug_process=… debug_coverage_gap=…`（可复用 GetMemStats）。 |
| **风险** | 极低。 |

### R5 — 门禁未锁 R1–R4

| 项 | 内容 |
|----|------|
| **根因** | check_usability_docs / guardrails 停在 F1–F7。 |
| **策略** | 扩展脚本与 Test*；禁止 Check(True)。 |
| **风险** | 极低。 |

### 依赖

```text
R5 ────────────────► 与实现同批锁门禁
R1+R2 ──► FormatMemStats / TMemStats
R4 ─────► FormatMemDebugProfile（依赖 GetMemStats 字段）
R3 ─────► ReallocMemOf（复用 FreeMemOfAllowsSizedHeapFree）
```

---

## 6. 三轮残留 S1–S3（2026-07-17）

| ID | 分类 | 摘要 | 影响面 | 风险 | 优先级 |
|----|------|------|--------|------|--------|
| S1 | API 对称 | TryReallocMemOf 错误拒绝 nil allocator GetMem 回落 | 插件助手 | MEDIUM | P1 |
| S2 | 错误消息 | error.pas 对齐 raise 裸字符串 | 机读日志 | LOW–MED | P2 |
| S3 | 门禁 | S1 无 guardrails | 回归 | LOW | P0 |

### S1 — Try/非 Try 成功语义

| 项 | 内容 |
|----|------|
| **根因** | 防御性早退过严：禁止无 allocator + 无 ptr 时走 process GetMem。 |
| **影响** | `ReallocMemOf(nil,nil,0,N)` 成功；`TryReallocMemOf` 同入参 False — 违反 ERROR-POLICY「Try=同一后端+Boolean」。 |
| **Go/Rust** | 错误形态单一；包装层不比底层更严。 |
| **策略** | 删早退；`Result := (ptr<>nil) or (newSize=0)`。 |
| **风险** | 低：行为变宽。 |

### S2 — 对齐 raise 助手

| 项 | 内容 |
|----|------|
| **根因** | F5 只强制「本批新建」；Sanitize* 为历史裸字符串。 |
| **策略** | 仅改 `SanitizeRuntimeAlignment` / `SanitizeConfigAlignment`。 |
| **风险** | 极低；全库 pool 不扫。 |

### S3 — 门禁

| 项 | 内容 |
|----|------|
| **策略** | `TestTryReallocMemOfNilAllocatorGetMem` + check_usability_docs。 |
| **风险** | 极低。 |

---

## 7. 四轮残留 T1–T4（2026-07-17）

| ID | 分类 | 摘要 | 影响面 | 风险 | 优先级 |
|----|------|------|--------|------|--------|
| T1 | 错误消息 | Arena ReallocMem 裸字符串 | 机读 / 一致性 | LOW–MED | P2 |
| T2 | 错误模型 | AllocArray 溢出 → EOutOfMemory + 非 stem 消息 | except 面 | MED | P1 |
| T3 | 边界/易用 | AllocZeroed/AllocArray(nil) 崩溃 | 插件注入 | MED | P1 |
| T4 | 门禁 | T1–T3 无锁 | 回归 | LOW | P0 |

### T1 — Arena Realloc FormatAllocErrorMsg

| 项 | 内容 |
|----|------|
| **根因** | FreeMem 路径在 F4/S2 已迁助手；Realloc 仍历史字面量（虽已像 Type.Method）。 |
| **策略** | `FormatAllocErrorMsg('TLocalArenaAllocator','ReallocMem', reason)` 等同 Virtual。 |
| **风险** | 极低。 |

### T2 — AllocArray 溢出类型与消息

| 项 | 内容 |
|----|------|
| **根因** | 早期把溢出当 OOM；ERROR-POLICY 明确 size 溢出为编程错误 → raise，码表有 `aeInvalidLayout`。 |
| **影响** | `except on EAllocError` 漏捕；OOM 处理器误伤。 |
| **Go** | 参数错误 vs 资源错误分型。 |
| **Rust** | `Layout::from_size_align` / capacity overflow ≠ OOM panic 语义。 |
| **策略** | `raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('AllocArray','AllocArray','count*elemSize overflow'))`。 |
| **风险** | 低：若外部只捕 EOutOfMemory 会变；正确性优先。 |

### T3 — nil IAllocator

| 项 | 内容 |
|----|------|
| **根因** | 助手未走 `ResolveAllocator`；S5 契约 nil=过程默认堆。 |
| **策略** | `AllocZeroed`/`AllocArray` 用 `ResolveAllocator(AAllocator)` 再 AllocMem。 |
| **风险** | 低：行为从崩溃变成功（与 S5 一致）。 |

### T4 — 门禁

| 项 | 内容 |
|----|------|
| **策略** | guardrails：nil AllocZeroed/AllocArray；AllocArray 溢出 EAllocError+well-formed；arena Realloc FormatAllocErrorMsg 源锁。 |
| **风险** | 极低。 |

### 依赖

```text
T4 ────────────────► 与实现同批
T2 + T3 ──► mem.pas
T1 ───────► allocator.arena.pas
```
