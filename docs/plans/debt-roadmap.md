# 编译器债务路线图

> **状态：历史快照。** 本文件保留 2026-07-06 的债务分类，不再定义当前优先级。
> 当前 evidence-based 顺序见
> `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`。
> “resolver 编译全部索引单元”和 `platform-exclude` 方案已经被 live 证据推翻。
>
> 快照日期：2026-07-06；归档标记：2026-07-12
> 基于 Codex 战略审查 + 实际验证，与 `docs/plans/selfhost-roadmap.md` v3.0 对齐。

## 已完成

### C 系列（编译器核心能力）— ✅ 全部完成

| # | 债务 | 完成日期 |
|---|------|----------|
| C1 | 编译单元级 record 字段解析 | 2026-06-29 |
| C2 | FPC InlineVar 支持 | 2026-06-29 |
| C3 | Pipeline 边界重组 (compiler/lower/) | 2026-07-06 |
| C4 | record 辅助方法 | 2026-06-29 |
| C5 | {$IFDEF} 条件编译支持 | 2026-07-03 |
| C6 | owned string return | 2026-07-03 |
| C7 | compiler module/source probe | 2026-07-03 |
| C8 | Sema 深化 (S1-S9) | 2026-06-30 |
| C9 | HIR→MIR 降低优化 | 2026-07-03 |

### L 系列（语义/平台债务）— ✅ L1-L5 完成

| # | 债务 | 完成日期 |
|---|------|----------|
| L1 | 字符串生命周期 (6 阶段) | 2026-06-29 |
| L2 | FPC RTL 隔离 (Phase A-E) | 2026-06-24 |
| L3 | Platform 语义绑定 | 2026-06-30 |
| L4 | Compiler/Platform 集成 | 2026-07-03 |
| L5 | 泛型构造器传播 | 2026-07-06 |

---

## 2026-07-06 债务快照

### 当时的 Phase 1 阻塞判断：SIMD 汇编排除（已废止）

> ⚠️ 这是 2026-07-06 的判断，现已被 live resolver 证据推翻。

**根因**: unit resolver 编译搜索路径中的所有单元（252 个），包括 `nextpas.core.simd.*`（含 Intel 内联汇编），导致 assembler 失败。

**修复方案**:
1. unit resolver 增加 platform-exclude 机制
2. SIMD 模块标记为 A 类平台排除
3. 编译器只编译实际依赖的单元

### L6-A: Class helper 最小解锁（4-6 天）

> ⚠️ 基于过时信息，实际不是自举阻塞点。保留为后续质量改进。

- parser: `helper for TClass` 语法支持（已通过 FPC 实现）
- sema: 方法调度优先级规则（helper method 优先于原生 method）
- 解锁模块: thread.future, text.format, text.conv, process.pipe, http.router（已验证可编译）

### L6-B: Class helper 完整语义（5-8 天）

> Phase 5 之后任务，自举链路稳定后再做。

- 冲突解析：多个 helper 的优先级规则
- import/owner 边界：helper 的作用域管理
- 完整诊断：helper 相关的错误消息
- corner cases：嵌套 helper、泛型 helper 等

---

## 基础设施债务（按新优先级排序）

### 增量编译真实性审计（Phase 0，2-3 天）

> 不是"做增量编译"，是审计已有代码是否真的可用。

- [ ] 确认 cache/symbol cache 是否接在正式 build path ✅ 已确认
- [ ] 确认是否覆盖 158 单元目标场景
- [ ] 确认是否真的把热编译压到 <3s
- [ ] 如果能力已存在但未产品化，排为 Phase 4 硬化

### Sema 拆分（Phase 3，1-2 周）

> 自举链路稳定后再动，沿职责边界拆。

拆分顺序：helper/member → call/overload → typed expr → lifetime/cleanup

### 并行编译（Phase 5，不阻塞主线）

> 在缓存和错误归因稳定后再提高优先级。

- 自举前更重要的是确定性、错误 attribution、缓存失效边界
- 保留为实验能力，不作为主线 gate

---

## 非债务（正式标记 out-of-scope）

| 项目 | 原因 |
|------|------|
| winssl (10 模块) | Windows-only，A 类平台排除 |
| simd.sse42 | SSE4.2 内联汇编，A 类平台排除 |
| simd.sse2/base/dispatch/cpuinfo | Intel 内联汇编，A 类平台排除 |

---

## 关联

- 自举路线图: `docs/plans/selfhost-roadmap.md` v3.0
- Phase 0 任务: 状态真相统一 ✅ 已完成
- 当前执行计划: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`
- 决策点: 6 个关键决策已确认
