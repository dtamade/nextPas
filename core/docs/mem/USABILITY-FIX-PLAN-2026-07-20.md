# mem 可用性修复 — 整体实施规划

**日期**: 2026-07-20
**状态**: **Implemented 2026-07-20**
**权威调研**: [USABILITY-FIX-RESEARCH-2026-07-20.md](USABILITY-FIX-RESEARCH-2026-07-20.md)
**原则**: 确认前零生产代码改动；分里程碑；每里程碑可独立验证回滚；禁止边调边改架构。

---

## 1. 目标与非目标

### 目标

关闭可用性评估中的 **全部** 调研项（R-*），使：

- 错误消息与 ERROR-POLICY 一致且可门禁
- FPC RTL 隔离在 mem 测试侧归零
- 诊断假阴性「吵」到可发现
- 默认路径/examples/门禁与文档对齐
- 命名与 catch 助手补齐
- **不**回退 SC1 热路径性能与双轨语义

### 非目标（确认时默认接受）

- 合并 DefaultHeap / IAllocator
- 生产默认 `HEAP_SAFETY=1`
- 扩展 `IAllocator` 增加 sized `FreeMem`
- 全仓 FreeMemOf / 新 allocator
- 改 `EOutOfMemory` 继承为 `EAllocError`（爆炸半径；用助手替代）
- 热路径 TLS last-OOM API

---

## 2. 优先级与依赖图

```text
M0 基线锁定
 │
 ├─► M1 隔离 + 门禁对齐          (R-TE-01, R-TE-02)     无代码依赖
 │
 ├─► M2 错误面统一               (R-ER-01, R-ER-02, R-CO-02)
 │     │                         依赖: M0
 │     └─► M2b catch 助手        (R-CO-01)              可与 M2 并行尾声
 │
 ├─► M3 诊断与安全习惯           (R-UX-01, R-SA-01)     可与 M2 并行
 │
 ├─► M4 可发现性                 (R-UX-02, R-IF-01/02, R-UX-03, R-CO-03, R-ER-03)
 │                                 依赖: M1 文档门禁习惯；examples 独立
 │
 └─► M5 命名对齐 Unchecked       (R-IF-03)              建议 M2 后；跨 collections

全部完成 → M6 收口（分数卡/文档权威更新/ROADMAP 指针）
```

| 里程碑 | 优先级 | 调研 ID | 依赖 |
|--------|--------|---------|------|
| **M0** | P0 流程 | — | 无 |
| **M1** | P1 | R-TE-01, R-TE-02 | M0 |
| **M2** | P1 | R-ER-01, R-ER-02, R-CO-02 | M0 |
| **M2b** | P2 | R-CO-01 | M2 的 error 单元可先 |
| **M3** | P1–P2 | R-UX-01, R-SA-01 | M0；与 M2 并行 |
| **M4** | P2 | R-UX-02/03, R-IF-01/02, R-CO-03, R-ER-03 | M1 文档检查可后置 |
| **M5** | P2 | R-IF-03 | 建议 M2 后；跨模块 |
| **M6** | 收口 | 全部 | M1–M5 |

---

## 3. 里程碑详述

### M0 — 基线锁定（0.5 人日）

| 动作 | 说明 |
|------|------|
| 记录 HEAD | `git rev-parse HEAD` |
| 跑基线 gate | `make lane-focused LANE=mem`（当前仅 guardrails） |
| 跑 contract + scorecard 抽样 | `test_contract_matrix`；`scorecard RELEASE=1`（至少记录 SC1/SC8/SC9） |
| 冻结禁止清单 | 本文件 §1 非目标贴到 PR 模板/提交说明 |

**退出**: 基线数字写入实施笔记（可放本文件附录或 commit message）；**仍不改功能代码**。

---

### M1 — 隔离 + 门禁对齐（0.5–1 人日）

#### M1.1 R-TE-01 SysUtils

| 项 | 内容 |
|----|------|
| 改动 | `core/tests/nextpas.core.mem/test_stack_guard/test_stack_guard.lpr` 删除 `SysUtils` |
| 门禁 | `check_usability_docs.sh` 或新片段：`core/tests/nextpas.core.mem/**/*.{lpr,pas}` 禁止 `uses` 行含 SysUtils/Classes |
| 验证 | `make focused FOCUS=core/tests/nextpas.core.mem/test_stack_guard` |

#### M1.2 R-TE-02 lane gate

| 项 | 内容 |
|----|------|
| 改动 | 新增 `core/tests/nextpas.core.mem/lane_gate/Makefile`：`clean`/`test` 顺序调用 `test_usability_guardrails` + `test_contract_matrix` |
| 改动 | `scripts/lane-focused.sh` mem → `FOCUS_PATH=core/tests/nextpas.core.mem/lane_gate` |
| 文档 | `docs/worktrees.md`、`USABILITY-SCORE`、`README` 同步 |
| 验证 | `make lane-focused LANE=mem` |

**退出**: 测试无 SysUtils；lane ≡ 双 gate。

---

### M2 — 错误消息统一（2–3 人日）

#### M2.1 R-ER-02 BuildAllocMsg 格式

| 项 | 内容 |
|----|------|
| 改动 | `BuildAllocMsg`：`aMsg + ' [' + ERROR_MESSAGES[aError] + ']'`（aMsg 空则仅 ERROR_MESSAGES） |
| 测试 | contract_matrix / guardrails：最终 Message 含 `[` + 码文案；stem 仍 `IsWellFormed` 在 **传入 Create 前** |
| 注意 | 已 raise 后的 `E.Message` 不再要求 `IsWellFormed(E.Message)`（除非调整解析器） |

**确认点（用户）**: 若希望 **零消息格式变化**，本子项降级为「仅文档冻结旧形态」——见 §6 确认清单。

#### M2.2 R-ER-01 全量 FormatAllocErrorMsg

| 批 | 文件簇 | 估计 raise 数 |
|----|--------|----------------|
| 2a | pool.fixed_slab, pool.pas, pool.allocator, pool.fixed*, pool.slab*, sizeclass | ~40 |
| 2b | blockpool*, mapped_slab, stack_pool, ring_buffer | ~40 |
| 2c | allocator.*（mmap/mimalloc/sentinel/guard/…） | ~40 |
| 2d | arena.*, budget, watermark, stats, registry, pas facade | ~20 |

规则：

```pascal
// before
raise EAllocError.Create(aeDoubleFree, 'TLocalBlockPool.Release: double free detected');
// after
raise EAllocError.Create(aeDoubleFree,
  FormatAllocErrorMsg('TLocalBlockPool', 'Release', 'double free detected'));
```

动态 method：

```pascal
FormatAllocErrorMsg('TFixedSlabPool', AOperation, 'pointer cannot be nil')
```

#### M2.3 R-CO-02 历史类型

| 项 | 内容 |
|----|------|
| raise | 优先 `EAllocError.Create`；或保留子类构造但 message 经助手 |
| 类型 | 保留声明；ERROR-POLICY / README 写「新代码用 EAllocError + TAllocError」 |
| 门禁 | 禁止新增 `E\w+ = class(EAllocError)` 于 mem（白名单现有文件）— 可选 shell |

#### M2.4 source-contract

| 项 | 内容 |
|----|------|
| 脚本 | `test_usability_guardrails/check_alloc_error_raises.sh`：扫 `core/src/nextpas.core.mem*.pas`，`raise EAllocError|EOutOfMemory.Create` 必须同行/下几行含 `FormatAllocErrorMsg`，排除 `mem.error.pas` 自举 |
| 接入 | guardrails Makefile 调用 |

**验证**: guardrails + contract_matrix；抽测 fixed_slab / mmap / blockpool。

**退出**: bare raise = 0；助手覆盖 100%（白名单除外）。

---

### M2b — Catch 助手（0.5 人日）

#### R-CO-01

| 项 | 内容 |
|----|------|
| API | `function TryAllocErrorCode(E: Exception; out ACode: TAllocError): Boolean` in `mem.error`；门面 re-export |
| 语义 | `E is EAllocError` → 其 `.Error`；`E is mem.EOutOfMemory` → 其 `.Error`；否则 False |
| 文档 | ERROR-POLICY §2.1：推荐 `except on E: ENextPasError` + 助手 |
| 测试 | guardrails：两类 raise 均可取出码 |
| **不做** | 改继承树 |

**退出**: 助手测试绿；文档更新。

---

### M3 — 诊断与安全习惯（1–1.5 人日）

#### M3.1 R-UX-01 WARN

| 项 | 内容 |
|----|------|
| 改动 | `FormatMemStats` / `FormatMemDebugProfile`：当 `DebugCoverageGap` 为 True，追加 ` WARN=debug_coverage_gap`（保持原有 key） |
| 测试 | guardrails / test_get_mem_stats / test_debug_wrap |
| doctor | `stage0-heap-debug-env-recipe`：DEBUG-only 场景 assert 输出含 WARN（失败可选） |
| 文档 | README 错误用法 + DEBUG 表 |

#### M3.2 R-SA-01 HEAP_SAFETY 习惯

| 项 | 内容 |
|----|------|
| 测试 | 新建或扩展：`test_heap_safety_profile`（或扩展 `test_double_free`）在 `NEXTPAS_MEM_HEAP_SAFETY=1` 下验证 tracking/sentinel 路径可检测双 free；**默认** CI 配置写入 Makefile 注释与 `MEM-HOST-RUNTIME-CI.md` |
| lane | **不**默认并入 lane_gate（防变慢/变脆）；文档写「改堆安全时再跑」 |
| 生产 | 默认仍关 SAFETY |

**退出**: gap→WARN；SAFETY 有可发现验证入口。

---

### M4 — 可发现性（1–1.5 人日）

#### M4.1 R-UX-02 examples

```text
core/examples/nextpas.core.mem/
  heap_default/     # GetMem, FreeMem(size), TryGetMem, GetMemStats
  arena_request/    # CreateDefaultArena, Alloc, Reset
  inject_tracking/  # DefaultAllocator + TTrackingAllocator；对照 FreeMem vs FreeMemOf
```

每个：`Makefile` build/run/clean → `build/projects/...`；**禁止 SysUtils**。

#### M4.2 R-IF-01 / R-IF-02 / R-UX-03 / R-CO-03 / R-ER-03

| 项 | 内容 |
|----|------|
| 文档 | API-GUIDE 顶部「三套动词」表 + FreeMemOf 决策树强化 + 「OOM 用 Try* 不用 last-error」 |
| 接口注释 | `mem.intf` FreeMem 注 FreeMemOf；`arena.intf` / `pool.base` 交叉链接 |
| 门禁 | `check_usability_docs.sh` 要求关键字：`Acquire/Release`、`FreeMemOf`、`debug_coverage_gap`、`TryGetMem` |
| R-ER-03 | **关闭为**：无 TLS；examples+文档即完成 |

**退出**: 三 examples `make run`；文档门禁绿。

---

### M5 — Unchecked 命名（0.5–1 人日）

#### R-IF-03

| 旧 | 新 |
|----|-----|
| `CopyUnChecked` | `CopyUnchecked` |
| `CopyNonOverlapUnChecked` | `CopyNonOverlapUnchecked` |
| `IsOverlapUnChecked` | `IsOverlapUnchecked` |
| `AlignUpUnChecked` | `AlignUpUnchecked` |
| `AlignDownUnChecked` | `AlignDownUnchecked` |

| 项 | 内容 |
|----|------|
| 改动 | `mem.utils` 定义 + 内部调用 |
| 跨模块 | `collections.element_manager`；`pool.slab` / `fixed_slab` / `pool.allocator` |
| 策略 | **无长期别名**（引用少，一次切完） |
| 验证 | 相关 mem pool 测试 + `make focused FOCUS=core/tests/nextpas.core.collections/...`（element_manager 所属 gate，实施时查 Makefile） |

**Ready 报告** 必须列 cross-module 文件。

---

### M6 — 收口（0.5 人日）

| 项 | 内容 |
|----|------|
| 验证全集 | `make lane-focused LANE=mem`；scorecard `RELEASE=1`；examples run；`make hygiene` |
| 文档 | 更新 `USABILITY-SCORE.md`（新评估分与关闭表）；`README` 链到 RESEARCH/PLAN；`ROADMAP` 记 Era 可用性债清理 **CLOSED** |
| 清理 | 无临时 task_plan 进主线 |
| 报告 | Ready：分支、HEAD、文件清单、验证证据、禁止带入项 |

---

## 4. 建议提交切片（确认后执行）

| Commit | 内容 |
|--------|------|
| 1 | M1 SysUtils + lane_gate + docs/scripts |
| 2 | M2.1 BuildAllocMsg + 测试 |
| 3–6 | M2.2 raise 批 2a–2d + contract 脚本 |
| 7 | M2b TryAllocErrorCode |
| 8 | M3 WARN + SAFETY 测试/文档 |
| 9 | M4 examples + 文档/注释 |
| 10 | M5 Unchecked 重命名 |
| 11 | M6 收口文档与分数 |

可合并 3–6 为 1–2 个 commit，但避免单 commit 混跨模块与 raise 全库。

---

## 5. 验证矩阵

| 阶段 | 命令 |
|------|------|
| 每 commit | `make hygiene`；相关 `make focused FOCUS=...` |
| M1 后 | `make lane-focused LANE=mem` |
| M2 后 | lane + 抽 `test_fixed_slab` / `test_blockpool` / `test_mmap*` |
| M3 后 | `test_debug_wrap` / `test_get_mem_stats`；recipe 若改 |
| M4 后 | 三 examples `make run` |
| M5 后 | mem utils 相关 + collections 触点 gate |
| M6 | scorecard `RELEASE=1`；lane；hygiene；`git diff --check` |

**性能红线**: SC1 growing 不得系统性慢于基线（允许噪声）；SC8/SC9 比例叙事不变。

---

## 6. 确认清单（请用户勾选）

实施前请确认：

| # | 议题 | 默认建议 | 你的决定 |
|---|------|----------|----------|
| C1 | 范围 = RESEARCH 全部 R-*（含文档关闭项） | 接受 | ？ |
| C2 | `BuildAllocMsg` 改为 `stem [code label]` | **接受 A** | ？保留旧 `stem: code` 则勾「文档 only」 |
| C3 | `EOutOfMemory` **不**改继承，只加 `TryAllocErrorCode` | 接受 | ？ |
| C4 | UnChecked 重命名并改 `element_manager`（跨模块） | 接受 | ？ |
| C5 | lane_gate = guardrails + contract_matrix | 接受 | ？ |
| C6 | 生产默认仍无 HEAP_SAFETY；仅加可跑测试/文档 | 接受 | ？ |
| C7 | 不做 TLS last-OOM / 不改 FreeMemOf 语义 / 不合并双轨 | 接受 | ？ |
| C8 | 实施顺序 M0→M1→M2→… 还是允许 M3∥M2 | **允许并行 M3∥M2** | ？ |

**确认方式**: 回复例如「确认 C1–C8 默认」或逐条修改。
**在此之前**: 仅维护 RESEARCH/PLAN 文档；**不**改 `core/src` 生产代码。

---

## 7. 工作量与风险摘要

| 项 | 估计 |
|----|------|
| 总工作量 | **6–9 人日**（含验证） |
| 关键路径 | 错误字符串、诊断一行、命名、测试/门禁 |
| 整体风险 | LOW–MEDIUM |
| 回滚 | 按 commit 回滚；M2 最大，可按文件簇回滚 |

---

## 8. 实施启动条件

1. 用户确认 §6
2. worktree `mem` 干净或仅含本 PLAN/RESEARCH
3. M0 基线数字已记录

启动后第一条代码改动 = **M1.1**（最小、可逆），再铺开 M2。

---

## 附录 A — 调研 ID ↔ 关闭证据

| ID | 关闭证据 |
|----|----------|
| R-ER-01 | check_alloc_error_raises 绿；抽查 0 bare |
| R-ER-02 | BuildAllocMsg 单测 + 文档 |
| R-ER-03 | API-GUIDE Try* 节 + example heap_default |
| R-UX-01 | Format 含 WARN；guardrails |
| R-UX-02 | 三 examples run |
| R-UX-03 | 文档 + docs contract 关键字 |
| R-CO-01 | TryAllocErrorCode 测试 |
| R-CO-02 | raise 统一 + 文档 deprecated |
| R-CO-03 | intf 注释 + FACADES |
| R-SA-01 | SAFETY 测试入口文档化 |
| R-IF-01/02 | 文档表 + examples + check_usability_docs |
| R-IF-03 | 无 UnChecked 符号残留（定义侧） |
| R-TE-01 | 无 uses SysUtils；脚本门禁 |
| R-TE-02 | lane-focused 跑双 gate |
