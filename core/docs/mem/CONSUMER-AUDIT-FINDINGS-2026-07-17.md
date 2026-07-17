# 全仓库 mem Consumer Audit — Findings

**日期**: 2026-07-17
**分支 / worktree**: `mem`（`.worktrees/mem`）
**范围**: 全仓库 consumer 对 `nextpas.core.mem` 的使用是否正确、范式是否一致、是否充分复用
**非目标**: mem 模块内部再审；reopen USABILITY-SCORE CLOSED keepers 为 P0
**方法**: 自动化 sweep（S1–S9）+ 关键模块 deep dive + 可编译证据 → **Wave1–7 全修 + focused 验证**
**Scratch**: `/tmp/grok-mem-consumer-audit/` · `/tmp/grok-mem-consumer-fix/`（不入仓）
**摘要**: [CONSUMER-AUDIT-SUMMARY-2026-07-17.md](CONSUMER-AUDIT-SUMMARY-2026-07-17.md)
**修复状态**: **CLOSED**（见 §9）

---

## 1. 分类法（M1–M10）

| ID | 名称 | 含义 |
|----|------|------|
| M1 | 热路径双轨误用 | 热循环走 `DefaultAllocator.GetMem` 等 vtable 面 |
| M2 | 已知 size 却 unsized free | 可 `FreeMem(ptr,size)` / `FreeMemOf` 却只 `FreeMem(ptr)` |
| M3 | Arena / FreeMem 混用 | 对 Arena 块过程式 free，或与 heap 混生命周期 |
| M4 | IAllocator API 形态错误 | 非五方法契约（如 `Allocate`/`Deallocate`） |
| M5 | 敏感数据未 SecureZero | 密钥/口令缓冲释放前未擦除 |
| M6 | 助手未复用 | `FreeMemOf`/`TryBlockSize`/`FormatAllocErrorMsg`/`AlignUp` 等门面能力零消费者 |
| M7 | 产品表 dynarray | session 表仍 `SetLength`（对照 WAIVED keepers） |
| M8 | 错误模型分叉 | 裸 `EOutOfMemory*` 字符串 vs `EAllocError`+`FormatAllocErrorMsg` |
| M9 | 旁路 System 堆 | 分配/释放不经 `nextpas.core.mem`（含 L0 合法旁路 vs 应迁移） |
| M10 | 产品接线缺口 | compiler/HTTP 等已有 wire 与未接线路径 |

**严重度**: P0 正确性/可编译 · P1 范式错误或显著性能 · P2 复用/一致性 · P3 文档/批量债 · WAIVED 故意保留

---

## 2. Sweep 计数（证据基线）

| Sweep | 查询意图 | 结果（约） |
|-------|----------|------------|
| S1 | `DefaultAllocator.(GetMem\|FreeMem\|…)` 热路径方法调用（排除 mem 本体门面） | **0** 消费者误用 |
| S1b | 任意 `DefaultAllocator` 引用 | **59** 行（几乎全是注入默认 `DefaultAllocator` / `DefaultAllocator()`，范式正确） |
| S2 | unsized `FreeMem(` | **180** 命中 / **62** 源文件（含 `FAllocator.FreeMem` 与过程式） |
| S2b | sized `FreeMem(ptr, size)` | **1** 生产点：`nextpas.core.numa.pas` |
| S3 | 同文件 Arena 面 + FreeMem | **4** 文件（http.mem / requestarena / http / compiler.mem）— 文档化 wire，非误 free |
| S4 | 含 GetMem/FreeMem/AllocMem/ReallocMem 的文件 | **78** |
| S4 | 上表中 **无** `nextpas.core.mem` uses | **52** 文件 |
| S5 | SecureZero 相关 | 有限：crypto/tls/mem.secure/platform.memory 等；非全敏感缓冲 |
| S6 | core 内 `SetLength` | ~3200+ 行；compiler product-table dual-track **CLOSED**（见 USABILITY-SCORE） |
| S7 | AlignUp 重复 | `simd.memutils` 自研 AlignUp；mem.base 已有 canonical |
| S8 | OOM / AllocError raise | **44** 命中；大量裸 `EOutOfMemory`/`EOutOfMemoryError` |
| S9 | 产品 wire（PhaseScratch / RequestArena 等） | **142** 命中；compiler backend + HTTP 面已接线 |
| Helpers | 仓外 `FreeMemOf`/`TryFreeMemOf`/`ReallocMemOf`/`TryBlockSize`/`FormatAllocErrorMsg` | **0** 生产 consumer（仅 mem 本体 + 测试） |

---

## 3. Finding 总表

| ID | 分类 | 摘要 | 严重度 | 状态 |
|----|------|------|--------|------|
| **CA-001** | M4 | `hashmap.swiss.i32` `Allocate`/`Deallocate` | **P0** | **FIXED** |
| **CA-002** | M6 | `FreeMemOf` 零生产复用 | **P1** | **FIXED**（swiss 族 + 文档推广） |
| **CA-003** | M2 | 已知 size unsized free | **P1** | **FIXED**（主簇） |
| **CA-004** | M9 | 无 mem uses 的分配族 | **P1–P2** | **FIXED**（L1+）；L0 / xml 缓冲 **WAIVED** |
| **CA-005** | M8 | 裸 OOM 消息 | **P2** | **FIXED**（yaml/lockfree 触达点） |
| **CA-006** | M6 | simd 自研 AlignUp | **P2** | **FIXED** |
| **CA-007** | M4/M9 | swiss nil ≠ DefaultAllocator | **P2** | **FIXED** |
| **CA-008** | M3 | Arena∩FreeMem | **info** | **CONFIRMED healthy** |
| **CA-009** | M1 | DefaultAllocator 热路径误用 | **info** | **CONFIRMED healthy** |
| **CA-010** | M10 | PhaseScratch / RequestArena | **info** | **CONFIRMED healthy** |
| **CA-011** | M7 | dynarray 产品表 | **WAIVED** | **WAIVED** |
| **CA-012** | M5 | SecureZero 覆盖 | **P2–P3** | **FIXED**（可证路径）；全仓闭合非本批 |
| **CA-013** | M2/M9 | platform.fs sized free / L0 | **P1** | **FIXED** + L0 **WAIVED** |
| **CA-014** | M8/M6 | FormatAllocErrorMsg 未推广 | **P2** | **FIXED**（本批触达点） |
| **CA-015** | M9 | lockfree 旁路 mem | **P2** | **FIXED** |

---

## 4. 逐项详情

### CA-001 — swiss.i32 `Allocate`/`Deallocate`（P0）

| 项 | 内容 |
|----|------|
| **位置** | [`core/src/nextpas.core.collections.hashmap.swiss.i32.pas`](../../src/nextpas.core.collections.hashmap.swiss.i32.pas) `AllocTable` / `FreeTable` / `GrowAndRehash` |
| **事实** | `FAllocator: IAllocator`；非 nil 分支调用 `FAllocator.Allocate` / `Deallocate` |
| **契约** | `IAllocator` 五方法仅 `GetMem`/`AllocMem`/`ReallocMem`/`FreeMem`/`Traits`（[`mem.intf.pas`](../../src/nextpas.core.mem.intf.pas)） |
| **证据** | 最小程序 specialize + `CreateWith`：FPC 报 *Identifier idents no member "Allocate"/"Deallocate"*（6 errors） |
| **对照** | 同族 [`hashmap.swiss.str.pas`](../../src/nextpas.core.collections.hashmap.swiss.str.pas) / generic swiss 使用 `GetMem`/`FreeMem` |
| **影响** | 任何强制实例化 `TSwissTableI32` 的编译单元失败；`CreateWith` 注入路径不可用；默认 `Create` 若 specialization 编译整方法体同样失败 |
| **修复方向** | `Allocate`→`GetMem`，`Deallocate`→`FreeMem`；nil 默认改为 `DefaultAllocator` 或过程式 `GetMem` 并与 str 表对齐；补 `CreateWith` 回归 |
| **非本 slice** | 不在此修复生产代码 |

### CA-002 — sized free 助手零生产复用（P1）

| 项 | 内容 |
|----|------|
| **事实** | 全仓生产路径（排除 `nextpas.core.mem*` 与 mem tests）**无** `FreeMemOf` / `TryFreeMemOf` / `ReallocMemOf` / `TryBlockSize` 调用 |
| **对比** | sized 过程式 `FreeMem(ptr,size)` 仅 **numa** 一处 |
| **影响** | F2/SC8 已落地的 ~8× sized free 优势在 consumer 侧几乎未兑现；插件面仍走单参 `IAllocator.FreeMem` |
| **修复方向** | 优先改 **知 size 的热 free** 点（collections 表增长、platform 缓冲、tui ParamCopy）；注入路径用 `FreeMemOf(AAlloc, P, Sz)`；丢 size 时 `TryBlockSize` 再 sized |
| **注意** | DEBUG wrap 开启时 `FreeMemOf` 不得绕过 tracking（已实现门控） |

### CA-003 / CA-013 — 已知 size + unsized free（P1）

**代表簇**:

1. **platform.fs** `platform_fs_read_until_eof`
   - `GetMem(LBuf, LBufSize)` 后 `FreeMem(LBuf)` / 扩容后 free 旧缓冲均 unsized
   - 注释明确 “Caller must FreeMem”
   - **无** `uses nextpas.core.mem` → 走 FPC `System.GetMem`（L0 旁路，见 CA-004）

2. **platform.io / pty** — poll 缓冲、属性表：分配 size 已知，free unsized

3. **tui.task** — `GetMem(ParamCopy, Spec.ParamSize)` + `FreeMem(ParamCopy)`；`ParamSize` 在分配时已知

4. **collections** — `node`/`swiss`/`hashmap`/`element_manager`：`FAllocator.GetMem(known)` + `FAllocator.FreeMem(ptr)`（接口冻结单参属契约限制；可改用 `FreeMemOf`）

5. **tls / simd / lockfree** — 大量过程式 unsized free

**修复优先级建议**: platform 动态缓冲与 tui 任务参数（size 局部可见）→ collections 注入路径 `FreeMemOf` → 其余批量。

### CA-004 / CA-015 — 无 mem uses 的分配族（P1–P2）

**52 文件**（S4）含分配 API 且不引用 `nextpas.core.mem`。主簇：

| 簇 | 文件数（约） | 解读 |
|----|--------------|------|
| tls.* | 多 | FFI/后端缓冲；部分合法旁路，部分应 Growing |
| lockfree.* | 9+ | 自管节点堆；应用 DefaultHeap 或文档声明 RTL 堆 |
| platform.{fs,io,pty} | 3 | L0 与 mem 同层；**允许**不依赖 mem，但应在文档标明“System 堆 / 调用方 FreeMem” |
| simd.* | 5+ | 对齐分配平行实现（CA-006） |
| tui.task / yaml.builder / xml.reader / regex / compress | 各 1 | 应评估 uses mem + 错误模型 |
| bench / test | 若干 | 低优先级 |

**分层原则**:

- **L0 platform.memory / SysGetMem**: 底座实现，**WAIVED** 为 mem 依赖源，不得倒依赖
- **L0 其他 platform 文件**: 可用 System 堆，但 consumer 契约必须写清
- **L1+（collections 已部分接入；lockfree/tui/yaml）**: 默认应 `uses nextpas.core.mem`，走过程式 `GetMem` 或 `DefaultAllocator` 注入

### CA-005 / CA-014 — 错误模型分叉（P2）

| 模式 | 示例 |
|------|------|
| 裸 `EOutOfMemoryError.Create('out of memory')` | `yaml.builder`（十余处） |
| `EOutOfMemory.Create('…')` | collections.vec/arr/node, text.builder, simd |
| `EOutOfMemoryError` capacity overflow | lockfree.msqueue/deque/priority_queue |
| `EAllocError` + 手写消息 | io.mapped.slab_pool, mem 内部 |
| `FormatAllocErrorMsg` | **仅 mem 内部**（Arena Realloc、AllocArray 等） |

ERROR-POLICY：资源不足可 nil/False；编程错误 raise。Consumer 在 **已检查 nil 后 raise** 属于“把 OOM 升级为异常”的业务选择，可保留，但消息应渐进统一为 `Type.Method: reason`（助手已有，未推广）。

**不**做全库 raise 扫改（爆炸半径大；与 USABILITY 调研一致）。

### CA-006 — simd 平行对齐分配（P2）

| 项 | 内容 |
|----|------|
| **位置** | `simd.memutils.pas`：`AlignUp`/`AlignUpSize`/`AlignedAlloc`；`simd.alloc.pas` |
| **行为** | 自实现 AlignUp；`GetMem(totalSize)` + 头指针布局；失败 `EOutOfMemory.CreateFmt` |
| **mem 侧** | `mem.base.AlignUp`；`allocator.aligned`；门面 aligned 路径 |
| **影响** | 双份对齐语义；simd 旁路 Growing/DEBUG/stats |
| **修复方向** | Align 数学复用 `mem.base`；分配后端可选注入 IAllocator 或文档声明“SIMD 专用 RTL 堆” |

### CA-007 — nil allocator ≠ DefaultAllocator（P2）

| 表 | nil 行为 |
|----|----------|
| `TVec` 等 | `DefaultAllocator()` → Growing IAllocator |
| `swiss.str` / generic swiss | `System.GetMem`/`FreeMem` |
| `swiss.i32` | 意图同 str，但非 nil 分支 API 错误（CA-001） |
| `yaml` document | nil → `DefaultAllocator`（正确） |

**影响**: 同一 collections 域默认堆不一致；DEBUG/`DefaultAllocator` 包装无法覆盖 nil 路径 swiss 表。

### CA-008 / CA-009 / CA-010 — 健康项

- **M1**: 无消费者热路径 `DefaultAllocator.GetMem` 误用（门面内部桥接除外）
- **M3**: `http` RequestArena / `compiler.mem` PhaseScratch 为正确 bulk-reclaim wire；S3 交集文件为文档与 re-export，未发现 Arena 块 `FreeMem` 实锤
- **M10**: `np_backend_plan` `PhaseScratch := CompilerCreateUnitAllocator`；HTTP `RequestArenaMiddleware` / `HttpRequestAllocatorOf` 已产品化

### CA-011 — dynarray keepers（WAIVED）

见 [USABILITY-SCORE.md](USABILITY-SCORE.md) intentional keepers 与 product-table dual-track **CLOSED**。本审计**不**将 HIR Operands / package DTO 等 reopen 为 P0。

### CA-012 — SecureZero 覆盖（P2–P3）

- 已用：`tls.secure`、`mem.secure`、部分 crypto / tls13 / pkcs11
- 未做全仓敏感字段×释放点闭合证明
- 建议：tls/crypto lane 单独 source-contract，而非 mem 可用性主线

---

## 5. Deep dive 模块结论

| 模块 | 结论 |
|------|------|
| **collections** | 主路径（vec/arr/hashmap swiss generic）已注入 `DefaultAllocator`；**swiss.i32 P0**；nil 旁路与 FreeMemOf 未用 |
| **platform** | L0 合法 System 堆；fs/io/pty 已知 size unsized free；文档契约弱 |
| **http** | RequestArena 接线正确；门面 re-export 健康 |
| **compiler** | PhaseScratch / session 默认堆 keepers 符合 USABILITY-SCORE |
| **tls** | 大量自管缓冲 + 部分 SecureZero；无 FreeMemOf；错误模型杂 |
| **lockfree** | 整族旁路 mem 门面；OOM raise 手写 |
| **simd** | 平行 AlignUp/AlignedAlloc |
| **yaml** | Doc 用 DefaultAllocator；builder 裸 OOM 字符串 |
| **tui** | ParamCopy 已知 size unsized free；无 mem uses |

---

## 6. 修复序列（已执行）

1. **Wave1 P0** CA-001/007：swiss.i32/str/i32i32/generic → GetMem/FreeMemOf + DefaultAllocator
2. **Wave2** CA-004/015：L1+ 注入 `uses nextpas.core.mem`；两参 `GetMem(var,size)` 改为函数形式
3. **Wave3** CA-002/003/013：platform/tui/lockfree/tls/text/… 已知 size → sized free / FreeMemOf
4. **Wave4** CA-006：simd.memutils → `mem.base.AlignUp`
5. **Wave5** CA-005/014：yaml.builder + lockfree OOM → FormatAllocErrorMsg
6. **Wave6** CA-012：mbedtls 私钥 / tls.secure 全容量 SecureZero + sized free
7. **Wave7**：re-sweep、findings CLOSED、hygiene、focused gates

**保留**: CA-011 WAIVED；L0 platform 不 `uses nextpas.core.mem`（循环依赖）；不全库机械 FreeMemOf；旧 raise 不全扫。

---

## 7. 与可用性主线关系

| 项 | 状态 |
|----|------|
| mem 可用性主线（F1–U1） | **CLOSED** @ 9.4 — 本修复**不**改分 |
| 本文件 | audit + **fix evidence**；consumer 范式债主线关闭 |
| 落地 | 在 `mem` worktree 跨模块最小必要修改；landing 需 path-limited review |

---

## 8. 验证（audit 时）

- 只读 audit 阶段：swiss.i32 `Allocate` 编译失败证据
- fix 阶段：见 §9

---

## 9. Fix CLOSED — 证据

### 修后 residual（非 mem 本体）

| 指标 | 值 |
|------|-----|
| sized FreeMem 命中 | ~74 |
| FreeMemOf 命中 | ~21 |
| FormatAllocErrorMsg 命中 | ~15 |
| SecureZeroMemory 命中 | ~27 |
| 真无 mem uses 的 alloc 文件 | bench/test.runner（工具）+ L0 platform + **xml.reader**（见下） |
| L0 platform | 注释 WAIVED；`System.FreeMem(ptr,size)` sized |
| xml.reader 输入缓冲 | 保留 **System** `GetMem/FreeMem(size)`：注入 `nextpas.core.mem` 后 Growing freelist 在 heaptrc 下触发 error-path AV（58→4 fail 证据）；sized free 仍落地 |
| `FAllocator.Allocate/Deallocate` | **0** |

### Focused gates（fix slice，exit 0 证据）

| Gate | 结果 |
|------|------|
| `collections/test_swisstable` | **pass** |
| `collections/test_hashmap` | **pass** |
| `collections/test_treemap` | **pass** |
| `lockfree/test_lockfree` | **pass** |
| `lockfree/test_lockfree_rbtree` | **pass** |
| `lockfree/test_lockfree_hazard` | **pass** |
| `yaml/test_yaml_builder` | **pass** |
| `platform/test_platform` | **pass** |
| `mem/test_usability_guardrails` | **pass** |
| `mem/test_numa` | **pass** |
| `text.builder/test_text_builder` | **pass** |
| `text/test_tstring` | **pass** |
| `regex/test_regex_basic` | **pass** |
| `xml/test_xml_reader` | **pass**（System 缓冲 + sized free） |
| `tui/test_tui_task` | **pass** |
| `compress/test_compress` | **pass** |
| `simd/test_algorithms` | **pre-existing fail**（缺 unit `simd.algorithms.testcase`，非本 diff） |
| `make hygiene` | **pass** |
| `git diff --check` | **pass** |

本地完整日志：`/tmp/grok-mem-consumer-fix/full_gates2.txt` · `extra_gates.txt`
