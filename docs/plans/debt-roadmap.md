# nextPas 技术债看板

> 最后更新：2026-07-06
> 用途：统一追踪所有已知技术债，每个 sprint 结束时 review

## 看板说明

| 字段 | 含义 |
|------|------|
| **严重度** |   阻塞自举 /   影响多模块 /   局部 /   文档/规范 |
| **范围** | compiler / core / rtl / 跨模块 |
| **预估** | 人天 |

---

## 活跃债务

### 编译器

| # | 债务 | 严重度 | 范围 | 预估 | 状态 |
|---|------|--------|------|------|------|
| C1 | **TSemanticAnalyzer God Class** (279 方法/1 class) |    | compiler/sema | 10d | ✅ 2026-07-06 |
| C2 | **permissive overload resolution** (选第一个候选) |    | compiler/sema | 3d | ✅ 2026-07-06 |
| C3 | **Pipeline 阶段模糊** (sema 做了 ir 的活) |    | compiler/sema+ir | 5d | ✅ 2026-07-06 |
| C4 | **.inc 文件伪装架构** (2 个 include 文件) |    | compiler/sema | 3d | ✅ 2026-07-06 |
| C5 | **增量编译** (符号表热缓存) |    | compiler/frontend | 5d | ✅ 2026-07-06 |
| C6 | **并行编译** (拓扑序分层) |    | compiler/frontend | 3d | ✅ 2026-07-06 |
| C7 | **Gate 2 unit lifecycle** (@llvm.global_ctors) |    | compiler/ir | 5d | ✅ 2026-07-06 |
| C8 | **Gate 4 heap manager** (真实 malloc/free) |    | compiler/ir + core/mem | 4.5d | ✅ 2026-07-06 |
| C9 | **c2p_win32_compat** (平台排除) |    | compiler | 1d | ✅ 2026-07-06 |

### Core 框架

| # | 债务 | 严重度 | 范围 | 预估 | 状态 |
|---|------|--------|------|------|------|
| L1 | **mail 模块契约缺失** (L3 2/3 → 3/3) |    | core/docs | 0.5d | ✅ 2026-07-06 |
| L2 | **TInterfacedObject 替代** (TRefCountedObject) |    | core/base | 5d | ✅ 2026-07-06 |
| L3 | **TThread 替代** (TWorkerThread) |    | core/thread | 3d | ✅ 2026-07-06 |
| L4 | **StrComp SysUtils 依赖** (lhash.pas) |    | core/base | 0.25d | ✅ 2026-07-06 |
| L5 | **泛型构造器传播** (collections, crypto.*) |    | compiler/sema | 10d |   未开始 |
| L6 | **Class helper 完整支持** (thread.future, text.format) |    | compiler/sema | 10d |   未开始 |

### 平台/构建

| # | 债务 | 严重度 | 范围 | 预估 | 状态 |
|---|------|--------|------|------|------|
| P1 | **platform.pipe** FPC 汇编问题 |    | core/platform | ? |   后续修复 |
| P2 | **platform.signal** FPC 汇编问题 |    | core/platform | ? |   后续修复 |
| P3 | **platform.which** FPC 汇编问题 |    | core/platform | ? |   后续修复 |
| P4 | **simd.sse42** 内联汇编 |    | core/simd | ? |   后续修复 |
| P5 | **tui.widget.linechart** FPC 汇编问题 |    | core/tui | ? |   后续修复 |
| P6 | **io.mapped.ring_buffer.sharded** FPC 编译错误 |    | core/io | ? |   后续修复 |
| P7 | **net.server.runtime** FPC 编译错误 |    | core/net | ? |   后续修复 |

---

## 已清偿

| # | 债务 | 清偿日期 |
|---|------|----------|
| ✅ | IsBuiltinProcedure 重构为注册表 | 2026-06 |
| ✅ | IsDeferredSystemObjectMember 清理 | 2026-06 |
| ✅ | sema 17,735 → 12,175 行拆分 | 2026-06 |
| ✅ | C5 `{$IFDEF}` 预处理器支持 | 2026-07-03 |
| ✅ | C6-H4 owned string return | 2026-07-03 |
| ✅ | C7 自举验证 | 2026-07-03 |
| ✅ | FPC RTL 清零 (0 直接 SysUtils/Classes/System) | 2026-07-03 |
| ✅ | Exception 自给自足 | 2026-06-24 |
| ✅ | 平台类型自足 (SizeInt/SizeUInt) | 2026-06-24 |
| ✅ | 57 模块契约全覆盖 | 2026-07-04 |
| ✅ | mem 审计 R4+R5 清零 | 2026-07-05 |
| ✅ | bench 审计 14/17 修复 | 2026-07-05 |
| ✅ | StrComp (Sprint 1) | 2026-06 |
| ✅ | Gate 3 process lifecycle | 2026-06 |
| ✅ | Platform Phase 1-4 (DynLibs/Socket/Windows/Unix) | 2026-06 |
| ✅ | TThread: platform_thread 迁移 | 2026-06 |

---

## Sprint 建议

### 当前 Sprint (2026-07-05 起) — 收尾

| 优先级 | 债务 | 理由 |
|--------|------|------|
| P0 | C9: c2p_win32_compat | C8 最后残留 |
| P0 | L1: mail 模块契约 | L3 最后一块 |
| P1 | C7: Gate 2 unit lifecycle | 自举硬依赖 |

### 下一 Sprint — 基础设施

| 优先级 | 债务 | 理由 |
|--------|------|------|
| P0 | C8: Gate 4 heap manager | 自举硬依赖 |
| P1 | C5: 增量编译 | 开发体验质变 |
| P1 | C1: sema 架构重构 Phase 1 (抽离 builtins) | 降低后续改动风险 |

### 后续 Sprint — 架构偿还

| 优先级 | 债务 | 理由 |
|--------|------|------|
| P0 | C2: permissive overload → 正式 | 正确性 |
| P1 | C1: sema 架构重构 Phase 2-5 | 持续降低复杂度 |
| P1 | C3: Pipeline 边界重划 | 清晰职责 |
| P1 | C4: .inc → 独立 unit | 消除伪架构 |

---

## 治理关联

- 项目总控: `PLAN.md`
- 目标树: `docs/plans/goal-tree.md`
- 自举路线图: `docs/plans/selfhost-roadmap.md`
- 原始债务方案: `docs/plans/2026-06-18-debt-roadmap.md` (已归档)

---

*最后 review: 2026-07-05*
---

## 架构诊断 (2026-07-05)

### 核心问题：TSemanticAnalyzer God Class

| 指标 | 当前值 | 健康标准 |
|------|--------|----------|
| 方法声明 | 279 | <50 |
| 方法实现 | 183 | <50 |
| 文件行数 | 12,255 | <3,000 |
| include 文件 | 2 (.inc) | 0 |
| 私有字段 | 60+ | <15 |

**职责混乱**：单一 class 同时承担类型检查、重载解析、HIR 生成、字符串所有权、
内置函数注册、运行时变量种子化、条件编译等 7+ 种职责。

### 派生问题

1. **Pipeline 边界模糊** — sema 直接生成 HIR 表达式（`BuildRuntime*` 系列方法），
   ir/ 中的 HIR Builder 退化为被动数据结构填充器
2. **.inc 是补丁不是架构** — `np_sema_string_ops.inc` (2,243行) 和
   `np_sema_runtime_expr.inc` (3,345行) 物理分离但逻辑上仍是同一 class 的方法
3. **Permissive overload** — 代码中 15+ 处 `{ Permissive: ... }` 注释，
   是 C8 冲刺的工程妥协，埋在主文件中难以清理

### 目标架构

```
lower/ 已实现:
├── np_hir_lowering            — AST→HIR 降级 (桥接 sema→ir)

sema/ 应拆分为:
├── np_sema_type_checker       — 类型检查 + 推导 (纯函数)
├── np_sema_overload_resolver  — 重载解析 (独立可测)
├── np_sema_builtins           — 内置函数注册表 (数据驱动)
└── np_sema_string_ownership   — 字符串所有权 pass (独立 visitor)

ir/ 应承担:
├── np_hir_builder             — 从 sema 接收指令，不再被动
└── np_hir_lowering            — HIR 规范化/优化
```

### 迁移路径

| 阶段 | 内容 | 风险 | 预估 |
|------|------|------|------|
| 1 | 抽离 `np_sema_builtins` (~500行) | 极低 | 0.5d |
| 2 | 抽离 `np_sema_string_ownership` (~2000行) | 低 | 1d |
| 3 | 抽离 `np_sema_overload_resolver` (~1500行) | 中 | 2d |
| 4 | 重新设计 sema↔ir 边界 | 高 | 3d |
| 5 | 清理 permissive overload | 高 | 3d |

---
