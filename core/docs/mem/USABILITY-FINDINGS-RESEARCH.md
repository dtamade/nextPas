# mem 可用性评估发现 — 专题调研报告

**状态**: Research complete (+ post-impl Go/Rust parity for F5–F7)  
**日期**: 2026-07-16 / 修订 2026-07-17  
**范围**: 独立可用性评估 F1–F7  
**权威评估**: 综合分 7.7/10（B+）→ 修复后 9.1（见 USABILITY-SCORE）  
**非目标**: 合并双轨热路径、默认开启生产安全税、新增 allocator 种类、reopen product-table dual-track

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

**结论**: 全部七项可用 **观测 + opt-in 安全 + 助手 API + 契约测试 + 文档冻结** 在不破坏双轨零税默认的前提下修复。
