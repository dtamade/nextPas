# 自举路线图 v3.0

> 最后更新：2026-07-06
> 基于 Codex (gpt-5.6-sol max) 战略审查 + 实际验证重构。

## 当前状态

| 指标 | 值 | 状态 |
|------|-----|------|
| compiler-pass | 53/53 | ✅ |
| self-compile | 19/19 | ✅ |
| core/ 覆盖率 | 963/972 (99.1%) | ✅ |
| FPC RTL 清零 | 0 直接 SysUtils/Classes/System 依赖 | ✅ |
| 编译器债务 C1-C9 | 全部完成 | ✅ |
| 语义债务 L1-L5 | 全部完成 | ✅ |

---

## Phase 0: 状态真相统一 ✅ 已完成

> 状态矩阵: `docs/plans/phase-0-status-matrix.md`

**关键发现**:
- LLVM 后端已就绪 (330 行已接线)
- 增量编译已接在正式 build path
- 并行编译骨架存在但未接线

---

## Phase 1: 最短自举阻塞清除（1 周）

> 只做自举必须的最小能力，不碰 Sema 拆分、LLVM 优化、并行编译。

### 实际阻塞点：SIMD 汇编排除

**根因**: unit resolver 编译搜索路径中的所有单元（252 个），包括 `nextpas.core.simd.*`（含 Intel 内联汇编），导致 assembler 失败。

**验证结果** (2026-07-06):
- thread.future: ✅ 编译成功
- text.format: ✅ 编译成功
- text.conv: ✅ 编译成功
- process.pipe: ✅ 编译成功
- http.router: ✅ 编译成功
- class helper 语法: ✅ 已支持 (通过 FPC 编译)

**修复方案**:
1. unit resolver 增加 platform-exclude 机制
2. SIMD 模块标记为 A 类平台排除
3. 编译器只编译实际依赖的单元

**gate**: 编译器编译自身源码全集，且产物可执行。

### L6-A: Class helper 最小解锁（4-6 天）

> ⚠️ 基于过时信息，实际不是自举阻塞点。保留为后续质量改进。

**目标**: 支持 sema 层面的 helper method lookup 和优先级。

**范围**:
- parser: `helper for TClass` 语法支持（已通过 FPC 实现）
- sema: 方法调度优先级规则（helper method 优先于原生 method）
- 不做：冲突解析、import/owner 边界、完整诊断

---

## Phase 2: 自举证据闭环（3-5 天）

> 两跳验证 + 性能基线，到这里才算真正"自举成功"。

### 任务清单

- [ ] `build compiler -> compiler -> rebuild compiler` 两跳验证
- [ ] 核心 runtime/RTL 零直接 FPC RTL 依赖检查
- [ ] 性能基线：冷编译、热编译、重复构建一致性
- [ ] 确定性验证：全量/增量/重复构建产物一致性

### 自举成功标准

1. nextpas 编译器能编译自身全部源码
2. 产出的编译器能再次编译自身（bootstrap 验证）
3. 核心运行时 (`nextpas.core.*`) 零 FPC RTL 依赖（FFI 绑定除外）
4. 性能：冷编译 <30s（600+ 文件），热编译 <3s（158 单元）

---

## Phase 3: 结构债收口（1-2 周）

> 自举链路稳定后再动 Sema，目标是让 MIR 成为唯一稳定后端输入。

### Sema 拆分（沿职责边界）

| 文件 | 职责 | 预估行数 |
|------|------|----------|
| `np_sema_helper_member.pas` | helper/member resolution | ~2000 |
| `np_sema_call_overload.pas` | call/overload diagnostics | ~1500 |
| `np_sema_typed_expr.pas` | typed expr production | ~3000 |
| `np_sema_lifetime_cleanup.pas` | lifetime/cleanup | ~2000 |
| `np_semantic_analyzer.pas` | 协调者 | ~3000 |

**拆分顺序**: helper/member → call/overload → typed expr → lifetime/cleanup

---

## Phase 4: 增量编译产品化（1 周）

> 如果代码已存在，就做真实性验证 + 接线 + 基准 + 失效边界修复。

### 任务清单

- [ ] 真实性审计：确认 cache/symbol cache 是否接在正式 build path
- [ ] 接线：确保 158 单元目标场景走缓存路径
- [ ] 基准：热编译 <3s 验证
- [ ] 失效边界：源文件变更、依赖变更、stub 变更的缓存失效策略

---

## Phase 5: LLVM/并行/平台扩展（1-2 周）

> 不阻塞主线，按需推进。

### LLVM 后端

- O2/LTO/pass pipeline 调优
- 不追求 native/LLVM 双路径都生产级

### 并行编译

- 在缓存和错误归因稳定后再提高优先级
- 自举前更重要的是确定性、错误 attribution、缓存失效边界

### 平台排除 B 类

- platform.pipe/signal/which: FPC 汇编输出问题
- tui.widget.linechart: FPC 汇编输出问题

---

## L6-B: Class helper 完整语义（5-8 天，Phase 5 之后）

> 完整 Pascal class helper 语义，包括冲突解析、import/owner 边界、诊断与 corner cases。

**前置**: L6-A 已在 Phase 1 完成，自举链路已稳定。

---

## 从"自举成功"到"生产可用"（5 个门）

> "自举成功"≠"可交付编译器"。以下是独立的质量门。

| 门 | 定义 | 状态 |
|----|------|------|
| **Correctness** | helper/overload/type-check/imported callable 等语义面收口 |   待评估 |
| **Determinism** | 全量/增量/重复构建产物一致性 |   待评估 |
| **Tooling** | 诊断、query、doctor、env、pkg 与 compiler truth 一致 |   待评估 |
| **Performance** | 冷编译/热编译基线稳定 |   待评估 |
| **Operability** | 调试信息、崩溃归因、最小发布与回退路径 |   待评估 |

---

## 时间线总览

```
Phase 0 (2-3d):   状态真相统一          ✅ 已完成
Phase 1 (1周):    SIMD 汇编排除 + L6-A  ← 当前
Phase 2 (3-5d):   自举证据闭环
Phase 3 (1-2周):  结构债收口 (Sema 拆分)
Phase 4 (1周):    增量编译产品化
Phase 5 (1-2周):  LLVM/并行/平台扩展
L6-B (5-8d):      Class helper 完整语义
生产可用 (5门):    贯穿后续
```

---

## 治理关联

- 项目总控计划: `PLAN.md`
- 目标树: `docs/plans/goal-tree.md`
- 编译器治理: `compiler/CLAUDE.md`

## 变更记录

- 2026-07-06: v3.0 基于 Codex 战略审查 + 实际验证重构，发现 SIMD 汇编是真正阻塞点
- 2026-07-05: v2.0 合并 c8-roadmap-v2 + selfhost-blockers-roadmap
- 2026-07-03: C7 自举验证完成
- 2026-06-30: c8-roadmap-v2 创建
- 2026-06-20: selfhost-blockers-roadmap v2.0 创建
