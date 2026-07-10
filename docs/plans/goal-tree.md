<!-- 项目总控地图 -->
<!-- 版本: v2.2 | 日期: 2026-07-06 -->
<!-- 每轮工作前查阅，结束后同步状态 -->
<!-- 自举路线图: docs/plans/selfhost-roadmap.md v3.0 -->

# nextPas 目标树 v2.2

打造 FreePascal 领域最优秀的编译器+标准库生态系统。

**架构成熟度**: 当前 [AL2 收敛期] → 目标 [AL3 成熟期]
**自举路线图**: `docs/plans/selfhost-roadmap.md v3.0`（Phase 0-5）
**等级定义**: `docs/architecture/architecture-maturity-levels.md`

---

## 阶段 0: AL0 混沌期 — 编译器自举（C0-C9）✅ 已完成

**目标**: 用 nextPas 编译器编译自身 + 全部 core/ 模块

| 节点 | 内容 | 状态 | 日期 |
|------|------|------|------|
| C0-C4 | 编译器基础架构 | ✅ | 2026-06-02 |
| C5 | 预处理器 `{$IFDEF}` 支持 | ✅ | 2026-07-03 |
| C6 | owned string return 改进 | ✅ | 2026-07-03 |
| C7 | 自举验证 | ✅ | 2026-07-03 |
| C8 | Sema 深化 (S1-S9) | ✅ | 2026-06-30 |
| C9 | HIR→MIR 降低优化 | ✅ | 2026-07-03 |
| L1-L5 | 语义/平台债务 | ✅ | 2026-07-06 |

**关键指标**:

| 指标 | 值 |
|------|-----|
| compiler-pass | 53/53 ✅ |
| self-compile | 19/19 ✅ |
| core/ 覆盖率 | 963/972 (99.1%) |
| FPC RTL 清零 | 0 直接依赖 ✅ |

---

## 阶段 1: AL1→AL2 骨架期→收敛期 — 自举冲刺 + 架构升级 🏗️ 当前阶段

**目标**: 完成自举证据闭环 + 打造先进编译器架构
**自举路线图**: `docs/plans/selfhost-roadmap.md v3.0`
**总周期**: 6-9 周到自举成功 + 2-4 周到生产可用
**退出条件**: 自举两跳验证通过 + AL1 全部退出条件

### 自举路径 (Phase 0-5)

| Phase | 内容 | 状态 | 周期 |
|-------|------|------|------|
| Phase 0 | 状态真相统一 | ✅ | 2-3 天 |
| Phase 1 | SIMD 汇编排除 + L6-A |   待开工 | 1 周 |
| Phase 2 | 自举证据闭环 |   待开工 | 3-5 天 |
| Phase 3 | 结构债收口 (Sema 拆分) |   待开工 | 1-2 周 |
| Phase 4 | 增量编译产品化 |   待开工 | 1 周 |
| Phase 5 | LLVM/并行/平台扩展 |   待开工 | 1-2 周 |

**关键发现** (2026-07-06):
- L6-A (Class helper) 不是自举阻塞点，5 个"被阻塞"模块已验证可编译
- 真正阻塞点：unit resolver 编译 SIMD 模块（含 Intel 内联汇编）导致 assembler 失败
- 修复方案：unit resolver 增加 platform-exclude 机制

**关键决策点**:
1. stage2 自举唯一后端 = LLVM on Linux x86_64
2. L6 只做 L6-A 最小解锁版，完整 helper 语义后置
3. 增量/并行编译从"新功能"改成"真实性审计 + 产品化"
4. 自举前不做大规模 Sema 重构
5. 平台排除项改 A/B/C 分类管理
6. "生产可用"单独立项，不与"自举成功"混同

**P0-P4 全部完成 = AL1 退出条件满足 = 升级到 AL2**

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

## 阶段 3: AL3 成熟期 — 自举完成 + 生产可用

**目标**: stage2 自举完成 + 生产可用 5 门全通过
**前置条件**: AL2 退出条件全部完成
**生产可用定义**: `docs/plans/selfhost-roadmap.md` "从自举成功到生产可用"

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| S1 | stage2 自举（nextPas 编译 nextPas 编译 nextPas） | 🔲 | bit-identical 或语义等价 |
| S2 | 标准库完整（975 模块 nextPas 编译） | 🔲 | 0 处 FPC 依赖 |
| S3 | 性能 ≥ FPC -O2 | 🔲 | 编译速度 + 生成代码 |
| S4 | 多目标后端（LLVM + 1 额外） | 🔲 | Cranelift 或 GCC |

### 生产可用 5 门

| 门 | 定义 | 状态 |
|----|------|------|
| Correctness | helper/overload/type-check/imported callable 等语义面收口 |   待评估 |
| Determinism | 全量/增量/重复构建产物一致性 |   待评估 |
| Tooling | 诊断、query、doctor、env、pkg 与 compiler truth 一致 |   待评估 |
| Performance | 冷编译/热编译基线稳定 |   待评估 |
| Operability | 调试信息、崩溃归因、最小发布与回退路径 |   待评估 |

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
