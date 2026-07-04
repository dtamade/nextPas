<!-- 项目总控地图 -->
<!-- 版本: v2.1 | 日期: 2026-07-05 -->
<!-- 每轮工作前查阅，结束后同步状态 -->

# nextPas 目标树 v2.1

打造 FreePascal 领域最优秀的编译器+标准库生态系统。

**架构成熟度**: 当前 [AL1 骨架期] → 目标 [AL2 收敛期]
**等级定义**: `docs/architecture/architecture-maturity-levels.md`

---

## 阶段 0: AL0 混沌期 — 编译器自举（C0-C7）✅ 已完成

**目标**: 用 nextPas 编译器编译自身 + 全部 core/ 模块

| 节点 | 内容 | 状态 | 日期 |
|------|------|------|------|
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

---

## 阶段 1: AL1→AL2 骨架期→收敛期 — 编译器架构升级（P0-P4）🏗️ 当前阶段

**目标**: 打造先进、优雅的 Pascal 编译器，对标 Rust/Go 编译器架构
**总周期**: 15 周（约 4 个月）
**退出条件**: 完成 AL1 全部退出条件 → 升级到 AL2 收敛期
**详细计划**: `docs/plans/compiler-architecture-plan.md`
**审计报告**: `docs/plans/compiler-audit.md`

| 阶段 | 内容 | 状态 | 周期 |
|------|------|------|------|
| P0 | 基础设施 — 编译器接入标准库 (THashMap/TVec/Arena) | 🔲 | 2周 |
| P1 | 架构重构 — God Class 拆分 + Pipeline + MIR | 🔲 | 4周 |
| P2 | 查询化编译 — 增量编译 + 并行编译 | 🔲 | 3周 |
| P3 | 能力补全 — MIR 优化 + 错误恢复 + 结构化诊断 | 🔲 | 4周 |
| P4 | 清理打磨 — Permissive 清零 + Blob 清理 + 测试 | 🔲 | 2周 |

**P0-P4 全部完成 = AL1 退出条件满足 = 升级到 AL2**

**P0 入口任务**（编译器负责人立即可开工）:
1. 符号表用 THashMap（O(1) 替换 647 处 SameText O(n)）
2. 动态数组改 TVec<T>（容量翻倍替换 145 处 SetLength+1）
3. AST 节点用 TFastArena 分配（减少 80% 堆分配）
4. 测量基线（编译时间 + 内存峰值，前后对比）

---

## 阶段 2: AL2 收敛期 — 标准库 + 编译器成熟

**目标**: 查询化编译稳定，增量+并行成熟，诊断达业界水平
**前置条件**: AL1 退出条件全部完成

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| L0 | 内核稳定 | ✅ | 11/11 模块契约完成 |
| L1 | 基础设施完善 | ✅ | 12/12 模块契约完成 |
| L2 | 系统能力扩展 | ✅ | 4/4 模块契约完成 |
| L3 | 框架层建设 | ✅ | 3/3 模块契约完成 |

**契约体系**: 57 模块全覆盖 ✅

---

## 阶段 3: AL3 成熟期 — 自举完成 + 多目标

**目标**: stage2 自举完成，性能 ≥ FPC，多目标后端
**前置条件**: AL2 退出条件全部完成

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| S1 | stage2 自举（nextPas 编译 nextPas 编译 nextPas） | 🔲 | bit-identical 或语义等价 |
| S2 | 标准库完整（975 模块 nextPas 编译） | 🔲 | 0 处 FPC 依赖 |
| S3 | 性能 ≥ FPC -O2 | 🔲 | 编译速度 + 生成代码 |
| S4 | 多目标后端（LLVM + 1 额外） | 🔲 | Cranelift 或 GCC |

---

## 阶段 4: AL4 生态期 — IDE/LSP/Package Manager

**目标**: 完整开发者体验
**前置条件**: AL3 退出条件全部完成

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| E1 | LSP 完整（跳转/引用/补全/诊断） | 🔲 | |
| E2 | Package Manager | 🔲 | registry + 依赖解析 + lockfile |
| E3 | GUI Framework | 🔲 | 窗口/布局/控件/渲染 |
| E4 | IDE 可用 | 🔲 | 自有 IDE 或 VS Code 插件 |
| E5 | 文档完整 | 🔲 | API + 教程 + 语言参考 |

---

## 阶段 5: AL5 领先期 — 全面超越

**目标**: 性能领先，形式化验证，生态成熟
**前置条件**: AL4 退出条件全部完成

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| X1 | 性能 > 2x FPC 编译速度 | 🔲 | |
| X2 | 多目标完整（Linux/Win/macOS/WASM, x86_64/ARM64/RISC-V） | 🔲 | |
| X3 | 形式化验证关键路径 | 🔲 | |
| X4 | 社区 1000+ 第三方包 | 🔲 | |

---

## 本周任务 (2026-07-05)

1. [x] 治理文档刷新 (合并碎片文档 + 重写 goal-tree.md v2)
2. [x] 编译器审计报告 (compiler-audit.md, 36 findings)
3. [x] 编译器架构计划 v2.2 (compiler-architecture-plan.md, 15周 5阶段 + 规范对齐 + 风险矩阵 + 源码对标)
4. [x] 架构成熟度等级定义 (architecture-maturity-levels.md, AL0-AL5)
5. [ ] c2p_win32_compat 平台排除
6. [ ] P0 启动：编译器负责人开工

## 本月任务

1. [ ] P0 完成：编译器接入标准库 (THashMap/TVec/Arena) + 基线测量
2. [ ] P1 启动：Pipeline 接口化 + sema 拆分 Phase 1 (抽离 builtins)
3. [ ] c2p_win32_compat 平台排除
4. [ ] C7 深化: 多目标 IR、LLVM O2/LTO (smoke 已完成)

---

## 进度追踪

| 日期 | 事件 | 备注 |
|------|------|------|
| 2026-07-03 | C7 自举验证完成 | self-compile 19/19, core/ 99.1% |
| 2026-07-04 | 契约体系全部完成 | 57 模块全覆盖 |
| 2026-07-05 | 架构诊断 | TSemanticAnalyzer God Class (279方法/1class) |
| 2026-07-05 | 编译器审计 v1 | compiler-audit.md 合并 findings + critique，36 条量化发现 |
| 2026-07-05 | 架构计划 v2.2 | compiler-architecture-plan.md，15 周 5 阶段 + 规范对齐 + 风险矩阵 + 源码对标 |
| 2026-07-05 | 架构成熟度等级 | architecture-maturity-levels.md AL0-AL5 定义完成 |
| 2026-07-05 | 目标树 v2.1 | 5 阶段 + AL 等级标注 + AL3-AL5 长期目标 |

---

## 治理文档索引

| 文档 | 用途 |
|------|------|
| `goal-tree.md` (本文件) | 项目总控地图 |
| `architecture-maturity-levels.md` | 架构成熟度等级 AL0-AL5 |
| `compiler-architecture-plan.md` | 编译器架构升级 15 周计划（AL1→AL2） |
| `compiler-audit.md` | 编译器 36 条量化审计发现 |
| `debt-roadmap.md` | 技术债看板 |
| `selfhost-roadmap.md` | 自举路线图 |
| `PLAN.md` | 根总控计划 |

*最后更新: 2026-07-05 | 版本: v2.1*
