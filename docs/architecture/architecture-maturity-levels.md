# nextPas 架构成熟度等级 (Architecture Levels, AL0-AL5)

> **用途**: 定义 nextPas 编译器+标准库生态系统的架构演进阶段。
> 每个等级有明确的进入条件、退出条件（升级门槛）、禁止回退信号。
> 所有路线图和执行计划必须标注当前 AL 和目标 AL。
>
> **版本**: v1.0 | **日期**: 2026-07-05
> **对标**: NASA TRL 1-9 (Technology Readiness Level), CMMI ML 1-5 (Capability Maturity Model)

---

## 等级总览

```
AL0: 混沌期 (Chaos)         — 能跑就行，架构不存在
  ↓
AL1: 骨架期 (Skeleton)      — Pipeline 显式化，Truth Object 出现
  ↓
AL2: 收敛期 (Convergence)   — 查询化编译，增量+并行，诊断结构化
  ↓
AL3: 成熟期 (Maturity)      — 自举完成，编译器用标准库，IR 优化完整
  ↓
AL4: 生态期 (Ecosystem)     — IDE/LSP/Package Manager/GUI Framework
  ↓
AL5: 领先期 (Leadership)    — 性能超越 FPC，多目标后端，形式化验证
```

**当前等级**: AL1 (骨架期) 🔄
**目标等级**: AL2 (收敛期)
**升级计划**: `docs/plans/compiler-architecture-plan.md` (15 周 P0-P4)

---

## AL0: 混沌期 (Chaos)

**一句话**: 编译器能生成可执行代码，但内部结构是历史惯性产物。

### 进入条件 (已完成才算进入)

- [x] 编译器能编译自身（C0-C7 自举验证通过）
- [x] 有 compiler-pass 34/34 集成测试
- [x] 有 self-compile 19/19
- [x] core/ 模块覆盖率 99.1%

### 退出条件 (全部完成才能升级到 AL1)

- [x] C0-C7 全部完成 ✅
- [x] 57 模块契约全覆盖 ✅
- [x] FPC RTL 依赖清零 ✅
- [x] 技术债识别并记录（compiler-audit.md 36 条 findings）✅

### 典型特征

| 维度 | AL0 特征 |
|------|---------|
| Pipeline | 隐式，阶段边界模糊 |
| Sema | God Class（279 方法/1 文件） |
| IR | 单层 HIR，直接到 LLVM IR |
| 编译模式 | 顺序全量 |
| 符号查找 | O(n) 线性扫描 |
| 内存管理 | 分散堆分配，无 Arena |
| 诊断 | 纯文本，一个错误就停止 |
| 标准库使用 | 0.5%（5/975 模块） |

### 禁止回退信号

- compiler-pass 回归
- self-compile 回归
- FPC RTL 重新引入

---

## AL1: 骨架期 (Skeleton) ← 当前等级

**一句话**: Pipeline 显式化，Truth Object 体系建立，编译器接入标准库。

### 进入条件 (已完成才算进入)

- [x] 编译器审计完成（compiler-audit.md, 36 findings）✅
- [x] 架构升级计划就绪（compiler-architecture-plan.md v2.1）✅
- [x] 架构成熟度等级定义完成（本文件）✅
- [x] 规范体系就绪（53 份 docs/architecture/ 规范）✅

### 退出条件 (全部完成才能升级到 AL2)

- [ ] **P0 完成**: 编译器接入标准库
  - [ ] THashMap 替换 647 处 O(n) SameText
  - [ ] TVec<T> 替换 145 处 SetLength+1
  - [ ] TFastArena 管理 AST 节点
  - [ ] 内存峰值下降 > 50%（heaptrc 证据）
- [ ] **P1 完成**: 架构重构
  - [ ] Pipeline 接口化（ICompilerPhase）
  - [ ] Sema God Class 拆分为 6 模块，0 个 .inc 文件
  - [ ] MIR 层 HIR→MIR→LLVM IR 全流程跑通
- [ ] **P2 完成**: 查询化编译
  - [ ] 查询系统框架运行，缓存命中率 > 80%
  - [ ] 增量编译可用：热编译（改 1 行）< 1s
  - [ ] 并行编译可用：多核利用率 > 50%
- [ ] **P3 完成**: 能力补全
  - [ ] 6 个 MIR 优化 pass 通过独立测试
  - [ ] 错误恢复：语法错误文件报告多个错误
  - [ ] JSON 诊断输出（--diagnostics=json）
- [ ] **P4 完成**: 清理打磨
  - [ ] Permissive overload 清零
  - [ ] Blob* 遗留代码清理完毕
  - [ ] sema 单元测试 ≥ 30 个
- [ ] 全量 compiler-pass 34/34 + compiler-fail snapshot + rebuild-compiler + make hygiene

### 典型特征

| 维度 | AL1 特征 |
|------|---------|
| Pipeline | 显式 9 阶段（Source DB → Lexer → Green CST → AST facade → Name resolution → Typed HIR → MIR → Codegen adapter → Target-aware output） |
| Sema | 6 模块拆分完成，每模块 < 4000 行 |
| IR | 三层：HIR → MIR → LLVM IR |
| 编译模式 | 查询化，按需+缓存 |
| 符号查找 | THashMap O(1) |
| 内存管理 | Arena + TVec 容量翻倍 |
| 诊断 | JSON 结构化 + 修复建议 |
| 标准库使用 | > 30%（编译器重度使用 core/） |

### 禁止回退信号

- Sema 重新合并为 God Class
- .inc 文件重新出现
- O(n) 线性查找重新出现（SameText 遍历数组）
- SetLength+1 逐元素扩容重新出现
- MIR 层被绕过（HIR 直接到 LLVM IR）

---

## AL2: 收敛期 (Convergence)

**一句话**: 查询化编译成熟，增量+并行稳定，诊断业界水平，编译器成为标准库优秀客户。

### 进入条件 (AL1 全部退出条件完成)

- [ ] AL1 退出条件全部 ✅

### 退出条件 (全部完成才能升级到 AL3)

- [ ] **增量编译稳定**
  - [ ] 文件级增量编译 100% 正确（全量 vs 增量产物 diff 一致）
  - [ ] 函数级增量编译可用（查询依赖图精确失效）
  - [ ] 冷编译性能不退化（vs AL1 基线）
- [ ] **并行编译稳定**
  - [ ] 单元级并行 100% 确定性（stress test 100 次一致）
  - [ ] 阶段级并行可用（查询无依赖并行）
  - [ ] 编译时间随核心数线性下降（4 核 → ~2.5x 加速）
- [ ] **MIR 优化成熟**
  - [ ] 12+ MIR 优化 pass（6 基础 + 6 进阶）
  - [ ] 进阶 pass：LICM、逃逸分析、尾调用优化、去虚拟化、内联策略、向量化识别
  - [ ] O0/O1/O2 优化级别可用
  - [ ] 优化正确性基准通过（compiler-pass + 性能 benchmark）
- [ ] **诊断达到 rustc 水平**
  - [ ] 多错误报告（不再一个错误停止）
  - [ ] 修复建议（help: did you mean...）
  - [ ] LSP 诊断推送（diagnostics streaming）
  - [ ] 错误代码体系完整（E0001-E9999）
- [ ] **编译器测试覆盖**
  - [ ] test/production 比 > 1.0x（当前 0.21x）
  - [ ] sema 单元测试 > 100 个
  - [ ] 每个 MIR pass 独立测试 > 10 个
- [ ] **编译器用标准库**
  - [ ] 编译器引用标准库模块 > 50 个
  - [ ] 编译器无自己实现的数据结构（全部来自 core/）
- [ ] **规范覆盖**
  - [ ] compiler-pipeline-specification.md 全部 9 阶段有对应实现
  - [ ] semantic-model-specification.md symbol/type/binding/Typed HIR 全部落地
  - [ ] ir-architecture-specification.md HIR/MIR 数据结构全部落地
  - [ ] backend-specification.md Codegen adapter + Target-aware output 全部落地

### 典型特征

| 维度 | AL2 特征 |
|------|---------|
| Pipeline | 9 阶段全部实现，阶段间类型化接口 |
| Sema | 6 模块稳定，每个有独立测试 |
| IR | HIR→MIR→LLVM IR 三阶段，12+ MIR pass |
| 编译模式 | 查询化成熟，增量+并行稳定 |
| 符号查找 | THashMap + 符号 ID 快速路径 |
| 内存管理 | Arena + interning，零碎片 |
| 诊断 | LSP 推送 + 修复建议 + 错误代码体系 |
| 标准库使用 | > 50% 编译器模块来自 core/ |

### 禁止回退信号

- 增量编译正确性回归（diff 不一致）
- 并行编译非确定性（stress test 失败）
- MIR 优化破坏正确性
- 测试覆盖率下降
- 编译器重新自己实现数据结构

---

## AL3: 成熟期 (Maturity)

**一句话**: 自举完成（nextPas 编译 nextPas 编译 nextPas），编译器+标准库自给自足。

### 进入条件 (AL2 全部退出条件完成)

- [ ] AL2 退出条件全部 ✅

### 退出条件 (全部完成才能升级到 AL4)

- [ ] **stage2 自举完成**
  - [ ] nextPas 编译器完全由 nextPas 编译（不依赖 FPC）
  - [ ] 自举编译产物 A 编译出 B，B 编译出 C，C == B（bit-identical 或语义等价）
  - [ ] 自举路径文档化（bootstrap-roadmap.md stage2 证据）
- [ ] **标准库完整**
  - [ ] core/ 全部 975 模块通过 nextPas 编译
  - [ ] 无 FPC 依赖（0 处 SysUtils/Classes/System 引用）
  - [ ] 泛型构造器传播完成（collections, crypto.*）
  - [ ] Class helper 完整支持（thread.future, text.format）
- [ ] **性能达到 FPC 水平**
  - [ ] 编译速度：nextPas 编译 core/ 时间 ≤ FPC 编译等价代码时间
  - [ ] 生成代码性能：benchmark 套件 ≥ FPC -O2 水平
  - [ ] 内存占用：nextPas 编译峰值 ≤ FPC 编译峰值
- [ ] **多目标后端**
  - [ ] LLVM 后端稳定（当前唯一后端）
  - [ ] 至少 1 个额外后端可用（Cranelift 或 GCC）
  - [ ] 交叉编译到至少 1 个非 Linux 目标（Windows 或 macOS）
- [ ] **ABI 兼容**
  - [ ] 与 FPC 编译的 .o/.so 互相调用
  - [ ] C interop 完整（c-interop-specification.md 全部落地）

### 典型特征

| 维度 | AL3 特征 |
|------|---------|
| 自举 | stage2 完成，nextPas 独立于 FPC |
| 标准库 | 975 模块全部 nextPas 编译 |
| 性能 | ≥ FPC -O2 水平 |
| 后端 | LLVM + 1 额外后端 |
| 目标 | Linux x86_64 + 1 额外目标 |
| ABI | 与 FPC/C 互操作 |

### 禁止回退信号

- stage2 自举链断裂
- FPC 依赖重新引入
- 性能回归到低于 FPC 水平
- ABI 兼容性破坏

---

## AL4: 生态期 (Ecosystem)

**一句话**: IDE/LSP/Package Manager/GUI Framework 全部可用，开发者体验完整。

### 进入条件 (AL3 全部退出条件完成)

- [ ] AL3 退出条件全部 ✅

### 退出条件 (全部完成才能升级到 AL5)

- [ ] **LSP 完整**
  - [ ] 跳转定义、查找引用、重命名、补全、悬停类型
  - [ ] 增量诊断推送（输入时实时报错）
  - [ ] Code actions（自动修复、重构）
  - [ ] 格式化（formatter）
- [ ] **Package Manager**
  - [ ] 包注册表（registry）
  - [ ] 依赖解析（dependency resolution）
  - [ ] 包安装/更新/卸载（install/update/remove）
  - [ ] 锁文件（lockfile）
- [ ] **GUI Framework**
  - [ ] 窗口、布局、控件、事件系统
  - [ ] 渲染管线（render-asset-pipeline-specification.md）
  - [ ] 样式/主题（ui-style-theme-specification.md）
  - [ ] 至少 1 个示例应用
- [ ] **IDE 可用**
  - [ ] 基于 GUI Framework 的自有 IDE
  - [ ] 项目管理、调试、测试集成
  - [ ] VS Code 插件（备选）
- [ ] **文档完整**
  - [ ] API 文档全覆盖（core/ 975 模块）
  - [ ] 教程、示例、贡献指南
  - [ ] 语言参考（language reference）

### 典型特征

| 维度 | AL4 特征 |
|------|---------|
| 开发体验 | IDE + LSP + Package Manager 完整 |
| GUI | 自有 GUI Framework + IDE |
| 文档 | API + 教程 + 语言参考 |
| 社区 | 贡献指南 + 示例 + 注册表 |

### 禁止回退信号

- LSP 功能退化
- Package Manager 数据丢失
- GUI Framework 不兼容破坏

---

## AL5: 领先期 (Leadership)

**一句话**: nextPas 成为 Pascal 世界的默认选择，性能超越 FPC，生态超越 Delphi。

### 进入条件 (AL4 全部退出条件完成)

- [ ] AL4 退出条件全部 ✅

### 退出条件 (持续演进，无终点)

- [ ] **性能领先**
  - [ ] 编译速度 > 2x FPC
  - [ ] 生成代码性能 > 1.5x FPC -O3
  - [ ] 增量编译 < 100ms（IDE 级响应）
- [ ] **多目标完整**
  - [ ] Linux / Windows / macOS / WASM
  - [ ] x86_64 / ARM64 / RISC-V
  - [ ] 嵌入式目标（bare metal）
- [ ] **形式化验证**
  - [ ] 类型系统安全证明（type safety proof）
  - [ ] MIR 优化正确性证明（translation validation）
  - [ ] 关键运行时 contract 形式化
- [ ] **生态成熟**
  - [ ] 社区贡献者 > 100
  - [ ] 第三方包 > 1000
  - [ ] 生产环境案例 > 50
- [ ] **语言演进**
  - [ ] 语言规范（language specification）正式发布
  - [ ] 语言提案流程（RFC process）
  - [ ] 向后兼容保证（edition/version 机制）

### 典型特征

| 维度 | AL5 特征 |
|------|---------|
| 性能 | 全面超越 FPC |
| 目标 | Linux/Windows/macOS/WASM, x86_64/ARM64/RISC-V |
| 正确性 | 形式化验证关键路径 |
| 生态 | 社区驱动，1000+ 第三方包 |

---

## 等级判定规则

1. **等级不可跳过** — 必须按 AL0→AL1→AL2→AL3→AL4→AL5 顺序升级
2. **退出条件全部完成才算升级** — 部分完成不算进入下一级
3. **禁止回退信号触发时，等级不降级但阻塞进一步升级** — 先修复回退，再继续
4. **每完成一个等级，在 goal-tree.md 和本文件中标注完成日期**
5. **所有执行计划（compiler-architecture-plan.md 等）必须标注当前 AL 和目标 AL**

---

## 当前状态 (2026-07-05)

| 等级 | 状态 | 完成日期 |
|------|------|----------|
| AL0: 混沌期 | ✅ 已完成 | 2026-07-03 (C7 自举验证) |
| AL1: 骨架期 | 🔄 当前等级 | 预计 2026-10 (15 周 P0-P4) |
| AL2: 收敛期 | 🔲 未开始 | 预计 2027 Q1-Q2 |
| AL3: 成熟期 | 🔲 未开始 | 预计 2027 Q3-Q4 |
| AL4: 生态期 | 🔲 未开始 | 预计 2028 |
| AL5: 领先期 | 🔲 未开始 | 持续演进 |

---

## 治理关联

- **产品路线图**: `master-roadmap.md` — 按 AL 等级展开 7 段产品轴
- **编译器路线图**: `compiler-roadmap.md` — 按 AL 等级展开编译器接管顺序
- **自举路线图**: `bootstrap-roadmap.md` — stage0/1/2 映射到 AL0/1/3
- **执行计划**: `docs/plans/compiler-architecture-plan.md` — 当前 AL1→AL2 的 15 周计划
- **目标树**: `docs/plans/goal-tree.md` — 标注当前 AL 和目标 AL
- **架构原则**: `architecture-principles-specification.md` — 每个 AL 的质量门槛

---

*版本: v1.0 | 日期: 2026-07-05*
*对标: NASA TRL 1-9, CMMI ML 1-5*
*最后更新: 2026-07-05*
