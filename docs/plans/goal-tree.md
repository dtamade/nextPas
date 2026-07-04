<!-- 项目总控地图 -->
<!-- 版本: v2.0 | 日期: 2026-07-05 -->
<!-- 每轮工作前查阅，结束后同步状态 -->
# nextPas 目标树 v2.0
打造 FreePascal 领域最优秀的编译器+标准库生态系统。
## 阶段 0: 编译器自举（C0-C7）✅ 已完成
**目标**: 用 nextPas 编译器编译自身 + 全部 core/ 模块
| C0-C4 | 编译器基础架构 | ✅ | 2026-06-02 |
| C5 | 预处理器 `{$IFDEF}` 支持 | ✅ | 2026-07-03 |
| C6 | owned string return 改进 | ✅ | 2026-07-03 |
| C7 | 自举验证 | ✅ | 2026-07-03 |
**关键指标**:
| 指标 | 值 |
|------|-----|
| compiler-pass | 34/34 ✅ |
| self-compile | 19/19 ✅ |
| core/ 覆盖率 | 963/972 (99.1%) |
## 阶段 1: 编译器架构升级（P0-P4）🏗️ 当前阶段
**目标**: 打造先进、优雅的 Pascal 编译器，对标 Rust/Go 编译器架构
**总周期**: 15 周（约 4 个月）
**详细计划**: `docs/plans/compiler-architecture-plan.md`
**审计报告**: `docs/plans/compiler-audit.md`
| P0 | 基础设施 — 编译器接入标准库 (THashMap/TVec/Arena) | 🔲 | 2周，阶段 0 |
| P1 | 架构重构 — God Class 拆分 + Pipeline + MIR | 🔲 | 4周，阶段 1 |
| P2 | 查询化编译 — 增量编译 + 并行编译 | 🔲 | 3周，阶段 2 |
| P3 | 能力补全 — MIR 优化 + 错误恢复 + 结构化诊断 | 🔲 | 4周，阶段 3 |
| P4 | 清理打磨 — Permissive 清零 + Blob 清理 + 测试 | 🔲 | 2周，阶段 4 |

**P0 入口任务**（编译器负责人立即可开工）:
1. 符号表用 THashMap（O(1) 替换 647 处 SameText O(n)）
2. 动态数组改 TVec<T>（容量翻倍替换 145 处 SetLength+1）
3. AST 节点用 TFastArena 分配（减少 80% 堆分配）
4. 测量基线（编译时间 + 内存峰值，前后对比）
## 阶段 2: 标准库完善（L0-L3）
**目标**: core/ 模块完整，接口契约完备
| L0 | 内核稳定 | ✅ | 11/11 模块契约完成 |
| L1 | 基础设施完善 | ✅ | 12/12 模块契约完成 |
| L2 | 系统能力扩展 | ✅ | 4/4 模块契约完成 |
| L3 | 框架层建设 | ✅ | 3/3 模块契约完成 |

**契约体系**: 57 模块全覆盖 ✅

**剩余**:
- mail 模块契约 ✅ (已完成)
- c2p_win32_compat 平台排除

---

## 阶段 3: 生态建设

**目标**: 社区、文档、工具链完善

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| E1 | 文档完善 | 🔲 | 架构文档、API 文档 |
| E2 | 社区建设 | 🔲 | 贡献指南、示例 |
| E3 | 工具链优化 | 🔲 | IDE 支持、调试 |
1. [x] 治理文档刷新 (合并碎片文档 + 重写 goal-tree.md v2)
2. [x] 编译器审计报告 (compiler-audit.md, 36 findings)
3. [x] 编译器架构计划 v2.1 (compiler-architecture-plan.md, 15周 5阶段 + 规范对齐 + 风险矩阵 + 源码对标)
4. [ ] c2p_win32_compat 平台排除
5. [ ] P0 启动：编译器负责人开工
1. [ ] P0 完成：编译器接入标准库 (THashMap/TVec/Arena) + 基线测量
2. [ ] P1 启动：Pipeline 接口化 + sema 拆分 Phase 1 (抽离 builtins)
3. [ ] c2p_win32_compat 平台排除
4. [ ] C7 深化: 多目标 IR、LLVM O2/LTO (smoke 已完成)
| 2026-07-05 | 架构诊断 | TSemanticAnalyzer God Class (279方法/1class)；制定 5 阶段重构方案 |
| 2026-07-05 | 编译器审计 v1 | compiler-audit.md 合并 findings + critique，36 条量化发现 |
| 2026-07-05 | 架构计划 v2.1 | compiler-architecture-plan.md，15 周 5 阶段 + 规范对齐 + 风险矩阵 + Rust/Go 源码对标 |
| 2026-07-05 | 目标树 v2.0 | 重构为 4 阶段，编译器架构升级为当前阶段 |
## 治理文档索引
| 文档 | 用途 |
|------|------|
| `goal-tree.md` (本文件) | 项目总控地图 |
| `compiler-architecture-plan.md` | 编译器架构升级 15 周计划（对 AI 友好，可持续更新） |
| `compiler-audit.md` | 编译器 36 条量化审计发现（单一真相来源） |
| `debt-roadmap.md` | 技术债看板 |
| `selfhost-roadmap.md` | 自举路线图 |
| `PLAN.md` | 根总控计划 |
*最后更新: 2026-07-05 | 版本: v2.0*
