# nextPas 项目总控计划

> 最后更新：2026-07-05
> 架构成熟度：[AL1 骨架期] → [AL2 收敛期] | 等级定义：`docs/architecture/architecture-maturity-levels.md`
> 目标树：`docs/plans/goal-tree.md` | 编译器架构计划：`docs/plans/compiler-architecture-plan.md` | 编译器审计：`docs/plans/compiler-audit.md`

## 北极星

打造 FreePascal 领域最优秀的编译器+标准库生态系统。

## 当前状态 (2026-07-05)

### ✅ 已完成 — 阶段 0: 编译器自举 (C0-C7)

| 里程碑 | 内容 | 日期 |
|--------|------|------|
| C0-C4 | 编译器基础架构 | 2026-06-02 |
| C5 | `{$IFDEF}` 预处理器支持 | 2026-07-03 |
| C6-H4 | owned string return 改进 | 2026-07-03 |
| C7 | 自举验证 | 2026-07-03 |
| L0-L3 | 框架层模块契约 (57/57) | 2026-07-04 |
| - | mem 审计 R4+R5 清零 | 2026-07-05 |
| - | bench 审计 14/17 修复 | 2026-07-05 |
| - | 编译器审计 + 架构计划 + 目标树 v2 | 2026-07-05 |

### 🔢 关键指标

- compiler-pass: 34/34 ✅
- self-compile: 19/19 ✅
- core/ 覆盖率: 963/972 (99.1%)
- 契约体系: 57 模块全覆盖 ✅

### 🏗️ 当前阶段 — 阶段 1: 编译器架构升级

**详细计划**: `docs/plans/compiler-architecture-plan.md`（15周 5阶段，对标 rustc/go）
**审计基线**: `docs/plans/compiler-audit.md`（36条量化发现）

| 阶段 | 内容 | 周期 | 状态 |
|------|------|------|------|
| P0 | 基础设施 — 编译器接入标准库 (THashMap/TVec/Arena) | 2周 | 🔲 |
| P1 | 架构重构 — God Class 拆分 + Pipeline + MIR | 4周 | 🔲 |
| P2 | 查询化编译 — 增量编译 + 并行编译 | 3周 | 🔲 |
| P3 | 能力补全 — MIR 优化 + 错误恢复 + 结构化诊断 | 4周 | 🔲 |
| P4 | 清理打磨 — Permissive 清零 + Blob 清理 + 测试 | 2周 | 🔲 |

### 🏗️ 其他进行中

- **c2p_win32_compat**: 平台排除（C8 最后残留）
- **test 框架**: M1 安全加固 ✅, M2 API 统一 🔄, M3 功能增强 🔲, M4 质量加固 🔲
- **bench 审计收尾**: 14/17 findings 修复，3 个文档化跳过

## 三阶段路线图

### 阶段 1: 编译器架构升级（当前）
- [ ] P0: 编译器接入标准库（THashMap 替换 647 处 SameText，TVec 替换 145 处 SetLength+1，Arena 管理 AST 节点）
- [ ] P1: 架构重构（Pipeline 接口化、sema God Class 拆分为 6 模块、引入 MIR 层）
- [ ] P2: 查询化编译（增量编译 <1s，并行编译可用）
- [ ] P3: 能力补全（6 个 MIR 优化 pass、错误恢复、JSON 诊断）
- [ ] P4: 清理打磨（permissive overload 清零、Blob 清理、sema 单元测试）
- [ ] c2p_win32_compat 平台排除

### 阶段 2: 框架深度完善
- [ ] mem 模块编译器集成（HIR builder Arena, LLVM emitter buffer）
- [ ] test 框架 M2-M4 完成
- [ ] 泛型构造器传播（collections, crypto.*）
- [ ] Class helper 完整支持（thread.future, text.format）

### 阶段 3: 生态建设
- [ ] 架构文档、API 文档完善
- [ ] 贡献指南、示例项目
- [ ] IDE 支持、调试工具链

## 治理文档索引

| 文档 | 用途 |
|------|------|
| `docs/plans/goal-tree.md` | 项目总控地图，每轮工作前后查阅同步 |
| `docs/plans/compiler-architecture-plan.md` | 编译器架构升级 15 周计划（对 AI 友好，可持续更新） |
| `docs/plans/compiler-audit.md` | 编译器 36 条量化审计发现（单一真相来源） |
| `docs/plans/debt-roadmap.md` | 技术债看板 |
| `docs/plans/selfhost-roadmap.md` | 自举路线图 |
| `compiler/CLAUDE.md` | 编译器工程治理：模块结构、质量门禁、技术债 |
| `core/docs/design-conventions.md` | Core 模块设计规范 |
| `docs/contracts/` | 57 模块代码契约 |

## 工作纪律
- 每轮开始前查阅 `goal-tree.md` 对齐方向
- 每轮结束后同步 goal-tree 状态
- 代码变更通过质量门禁后提交，commit message 有明确语义
- 重大设计决策写入 `docs/adr/`
