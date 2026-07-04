# nextPas 编译器架构升级计划 v2.0

> **目标**: 打造先进、优雅的 Pascal 编译器，对标 Rust/Go 编译器架构
> **版本**: v2.0 | **日期**: 2026-07-05 | **总周期**: 15 周
> **审计基线**: `docs/plans/compiler-audit.md`（36 条量化发现）
> **设计原则**: 每个阶段有明确的输入/输出/验证/对标。完成即闭环。不可跳过阶段。
> **本文件用途**: (1) AI 可执行的编译器开发 spec (2) 人类可读的路线图 (3) 可持续更新的进度追踪

---

## 一、目标架构

### 1.1 六阶段 Pipeline（对标 rustc）

```
  Source Files ──→ Lexer ──→ Token Stream
                              │
                         Parser ──→ Concrete Syntax Tree (CST)
                                      │
                                 AST Lower ──→ Abstract Syntax Tree
                                                │
                                           Sema ──→ Typed AST (HIR)
                                                      │
                                                 MIR Lower ──→ Mid-level IR (CFG+SSA)
                                                                    │
                                                               MIR Optimize ──→ Optimized MIR
                                                                                  │
                                                                             Codegen ──→ LLVM IR
```

**关键设计决策**:

| # | 决策 | 对标 | 理由 |
|---|------|------|------|
| 1 | CST ≠ AST | rustc (`rustc_parse` → `rustc_ast_lowering`) | 保留语法细节给 IDE/formatter |
| 2 | HIR = Typed AST | rustc HIR | IDE 功能（跳转、补全）基于此层 |
| 3 | MIR = CFG + SSA | rustc MIR | 所有优化在此层，类型擦除 |
| 4 | MIR → LLVM IR | rustc codegen | 换后端只需写 MIR→X 翻译器 |

### 1.2 查询化编译（对标 rustc query system）

```
传统: main() { lex(); parse(); sema(); codegen(); }  // 顺序全量
查询: type_of(def_id) → 缓存命中返回，未命中计算并缓存  // 按需 + 自动依赖图
```

**优势**: 增量编译天然、并行编译天然、IDE 支持天然。
Rust/Swift/Scala 3 都用了此模式。Go 编译器没有（Go 编译单位是 package，简单场景够用）。
**nextPas 必须实现查询化编译** — 这是"先进"的核心体现。

### 1.3 三层 IR

| 层 | 名称 | 对标 | 职责 |
|----|------|------|------|
| HIR | High-level IR | rustc HIR | 类型化 AST，保留所有语法结构 |
| MIR | Mid-level IR | rustc MIR | 控制流图，SSA，类型擦除，优化 |
| LIR | Low-level IR | LLVM IR | 目标代码，寄存器分配 |

### 1.4 目标 vs 现状

| 维度 | 当前 | 目标 | 对标 |
|------|------|------|------|
| Pipeline | 隐式，sema 做所有事 | 显式 6 阶段 | rustc |
| IR 层数 | 1 (HIR) | 3 (HIR→MIR→LIR) | rustc |
| 编译模式 | 顺序全量 | 查询化，按需+缓存 | rustc |
| 增量编译 | 无 | < 1s 热编译 | rustc |
| 并行编译 | 无 | 拓扑序并行 | rustc |
| 错误恢复 | 无 | Parser 恢复 + 多错误 | rustc |
| 诊断 | 纯文本 | JSON + 修复建议 | rustc |
| AST 内存 | class 堆分配 | Arena + 索引 | Go gc |
| 符号查找 | O(n) SameText | THashMap O(1) | Go gc |
| 编译器用标准库 | 0.5% | 重度使用 | rustc 用 std |

---

## 二、分阶段实施计划

> **格式约定**（给 AI 和人类）:
> - 每个任务: `[状态] 任务名` 状态: 🔲 未开始 | 🔄 进行中 | ✅ 已完成 | ⏸️ 暂停
> - 每个阶段: 输入文件清单 / 输出文件清单 / 验证命令 / 对标参考 / 闭环证据
> - 完成日期: 实际完成时填写 `YYYY-MM-DD`

---

### 阶段 0: 基础设施 — 编译器接入标准库（2 周）

**一句话目标**: 编译器成为标准库的客户。不改架构，只换实现。性能立竿见影。

**对标**: rustc 重度使用 std，Go gc 重度使用 Go 标准库

#### 任务 0.1: 符号表用 THashMap [🔲] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入文件** | `compiler/np_semantic_model.pas`（FindTypeByName, FindSymbolByName, LookupConstValue, GetTypeMetaByName, GetFieldMetaByName, GetVmtSlotByName） |
| **输出文件** | `compiler/np_semantic_model.pas`（修改后，6 个函数改为 THashMap O(1)） |
| **改动量** | 6 个查找函数，~200 行改动 |
| **验证命令** | `make compiler-pass` (34/34) + `make rebuild-compiler` |
| **对标** | Go gc 符号表用 `map[string]*Sym` |

#### 任务 0.2: 动态数组改 TVec<T> [🔲] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入文件** | 全编译器 145 处 `SetLength(arr, Length(arr)+1)` |
| **输出文件** | 高频增长的数组改为 TVec<T>（容量翻倍策略） |
| **改动量** | ~50 处高频路径，~300 行改动 |
| **验证命令** | `make compiler-pass` + `make rebuild-compiler` |
| **对标** | rustc `IndexVec`、`ArenaVec` |

#### 任务 0.3: AST 节点用 TFastArena 分配 [🔲] 预估 3 天

| 项 | 内容 |
|----|------|
| **输入文件** | `compiler/np_green_tree.pas`（TGreenNode = class，每个 token 一次堆分配） |
| **输出文件** | `compiler/np_green_tree.pas`（TGreenTree 持有 IArena，所有节点 Arena 分配） |
| **改动量** | ~500 行 |
| **验证命令** | `make compiler-pass` + heaptrc 报告（AST 分配从 5000+ → ~10 次） |
| **对标** | Go gc `Node` struct on Arena, rustc `BumpPtr` |

#### 任务 0.4: 测量基线 [🔲] 预估 1 天

| 项 | 内容 |
|----|------|
| **输入** | 阶段 0 前：编译全量 core/ 的时间 + 内存峰值 |
| **输出** | 阶段 0 后：编译全量 core/ 的时间 + 内存峰值，对比报告 |
| **验证** | 性能不退化，内存峰值下降 50%+ |

#### 阶段 0 闭环标准

```
[ ] compiler-pass 34/34
[ ] rebuild-compiler 成功
[ ] make hygiene 通过
[ ] 内存峰值下降 > 50%（heaptrc 报告）
[ ] 编译时间不退化
[ ] 对比报告写入 docs/plans/compiler-architecture-plan.md 本文件
```

---

### 阶段 1: 架构重构 — God Class 拆分 + Pipeline + MIR（4 周）

**一句话目标**: TSemanticAnalyzer 从 279 方法/1 class → 6 模块。引入 MIR 层。Pipeline 显式化。

**对标**: rustc 的 `rustc_typeck`、`rustc_trait_selection`、`rustc_mir_build`

#### 任务 1.1: 定义 Pipeline 接口 [🔲] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入文件** | `compiler/np_compilation_session.pas`（隐式编译流程） |
| **输出文件** | `compiler/np_compiler_phase.pas`（ICompilerPhase 接口），修改 `np_compilation_session.pas` |
| **改动量** | ~200 行新增 + ~100 行修改 |
| **验证** | 现有流程不改行为，只是包了一层接口。compiler-pass 34/34 |

#### 任务 1.2: 拆分 Sema God Class [🔲] 预估 15 天

| 子任务 | 输入 | 输出文件 | 行数 | 验证 |
|--------|------|---------|------|------|
| 1.2a 抽离 builtins [🔲] | TSemanticAnalyzer 中 ~500 行内置函数注册 | `compiler/np_sema_builtins.pas` | ~500 | compiler-pass 34/34 |
| 1.2b 抽离 string_ownership [🔲] | `np_sema_string_ops.inc` (2,243 行) | `compiler/np_sema_string_ownership.pas` | ~2000 | compiler-pass 34/34 |
| 1.2c 抽离 overload [🔲] | TSemanticAnalyzer 中 ~1500 行重载解析 | `compiler/np_sema_overload.pas` | ~1500 | compiler-pass 34/34 |
| 1.2d 抽离 type_check [🔲] | TSemanticAnalyzer 中 ~1500 行类型检查 | `compiler/np_sema_type_check.pas` | ~1500 | compiler-pass 34/34 |
| 1.2e 抽离 hir_lowering [🔲] | `np_sema_runtime_expr.inc` (3,345 行) | `compiler/np_sema_hir_lowering.pas` | ~3000 | compiler-pass 34/34 |
| 1.2f 协调器收敛 [🔲] | 剩余 TSemanticAnalyzer | `compiler/np_semantic_analyzer.pas` | ~3700 | compiler-pass 34/34 |

**最终 sema/ 目录结构**:
```
compiler/sema/
├── np_sema_builtins.pas           ~500 行  内置函数注册表（数据驱动）
├── np_sema_string_ownership.pas   ~2000 行 字符串所有权分析（独立 visitor）
├── np_sema_overload.pas           ~1500 行 重载解析（独立可测）
├── np_sema_type_check.pas         ~1500 行 类型检查/推导（纯函数）
├── np_sema_hir_lowering.pas       ~3000 行 AST→HIR 降级（桥接 sema↔ir）
└── np_semantic_analyzer.pas       ~3700 行 协调器（编排 5 个子模块）
```

#### 任务 1.3: 引入 MIR 层 [🔲] 预估 10 天

| 子任务 | 输出文件 | 内容 | 验证 |
|--------|---------|------|------|
| 1.3a MIR 数据结构 [🔲] | `compiler/ir/np_mir_model.pas` | TBasicBlock, TStatement, TOperand, TTerminator | 单元测试 |
| 1.3b HIR→MIR 降级 [🔲] | `compiler/ir/np_hir_to_mir.pas` | HIR 遍历 → MIR 基本块 | compiler-pass |
| 1.3c MIR 优化框架 [🔲] | `compiler/ir/np_mir_optimize.pas` | Pass 注册/调度框架（优化 pass 本身在阶段 3） | 单元测试 |
| 1.3d MIR→LLVM 翻译 [🔲] | `compiler/ir/np_mir_to_llvm.pas` | MIR 基本块 → LLVM IR | compiler-pass |

**MIR 核心数据结构**（Pascal 风格）:
```pascal
type
  TBasicBlock = record
    Stmts: TVec<TStatement>;
    Terminator: TTerminator;  // goto, if, return, switch
  end;
  TStatement = record
    case Kind: TStmtKind of
      skAssign: (Dst: TPlace; Src: TOperand);
      skCall: (Dst: TPlace; Func: string; Args: TVec<TOperand>);
  end;
  TOperand = record
    case Kind: TOpKind of
      okCopy: (Val: TLocal);
      okMove: (Val: TLocal);
      okConst: (Val: TConst);
  end;
```

#### 阶段 1 闭环标准

```
[ ] compiler-pass 34/34
[ ] rebuild-compiler 成功
[ ] make hygiene 通过
[ ] sema/ 目录 6 个独立 unit，无 .inc 文件
[ ] MIR 层 HIR→MIR→LLVM IR 全流程跑通
[ ] Pipeline 接口化，阶段可独立替换
```

---

### 阶段 2: 查询化编译 — 增量 + 并行（3 周）

**一句话目标**: 查询系统 + 增量编译 < 1s + 并行编译可用。

**对标**: rustc query system (Salsa 框架)

#### 任务 2.1: 查询系统框架 [🔲] 预估 5 天

| 项 | 内容 |
|----|------|
| **输入** | 当前 TSemanticModel 顺序构建 |
| **输出文件** | `compiler/np_query_database.pas` |
| **核心接口** | `TQueryDatabase.Get(Key, Compute)` — 缓存命中返回，未命中计算并缓存；`Invalidate(Key)` — 标记失效；自动依赖追踪 |
| **验证** | 编译全量 core/，查询缓存命中率 > 80% |

#### 任务 2.2: 增量编译 [🔲] 预估 5 天

| 项 | 内容 |
|----|------|
| **输入** | 查询系统框架 |
| **输出** | 文件变化检测（mtime+hash）+ 查询失效传播（沿依赖图） |
| **验证** | 冷编译 ~6s（不变），热编译（改 1 行）< 1s |

#### 任务 2.3: 并行编译 [🔲] 预估 5 天

| 项 | 内容 |
|----|------|
| **输入** | 查询依赖图 |
| **输出** | 无依赖查询并行执行（ThreadPool.Spawn） |
| **验证** | 多核利用率 > 50%，编译时间线性下降 |

#### 阶段 2 闭环标准

```
[ ] compiler-pass 34/34
[ ] 查询缓存命中率 > 80%
[ ] 热编译（改 1 行）< 1s
[ ] 并行编译可用（多核利用率 > 50%）
```

---

### 阶段 3: 能力补全 — MIR 优化 + 错误恢复 + 诊断（4 周）

**一句话目标**: 6 个 MIR 优化 pass，错误恢复，JSON 诊断。对标 rustc 最佳实践。

#### 任务 3.1: MIR 优化 Pass [🔲] 预估 10 天

| # | Pass | 验证 |
|---|------|------|
| 3.1a | 常量折叠 (Constant Folding) [🔲] | 独立测试 + compiler-pass |
| 3.1b | 死代码消除 (DCE) [🔲] | 独立测试 + compiler-pass |
| 3.1c | 强度削减 (Strength Reduction) [🔲] | 独立测试 + compiler-pass |
| 3.1d | 函数内联 (Inlining) [🔲] | 独立测试 + compiler-pass |
| 3.1e | 公共子表达式消除 (CSE) [🔲] | 独立测试 + compiler-pass |
| 3.1f | 无用参数消除 (Dead Arg) [🔲] | 独立测试 + compiler-pass |

**对标**: rustc MIR optimization passes

#### 任务 3.2: 错误恢复 [🔲] 预估 5 天

| 项 | 内容 |
|----|------|
| **策略** | 遇到错误 → 记录诊断 → 跳过 token 直到同步点（`;` `end` `begin`）→ 继续解析 → 最多 100 错误 |
| **验证** | 语法错误文件报告多个错误（不是只有第一个） |
| **对标** | rustc `rustc_parse` error recovery |

#### 任务 3.3: 结构化诊断 [🔲] 预估 5 天

| 项 | 内容 |
|----|------|
| **输出** | `nextpas build --diagnostics=json` 输出 JSON |
| **JSON schema** | `{message, span: {file,line,col,end_line,end_col}, level, suggestions: [{message, replacement}]}` |
| **对标** | rustc `--error-format=json` |

#### 阶段 3 闭环标准

```
[ ] 6 个 MIR 优化 pass 全部通过独立测试
[ ] compiler-pass 34/34（优化后结果正确）
[ ] 语法错误文件报告多个错误
[ ] --diagnostics=json 输出有效 JSON
```

---

### 阶段 4: 清理与打磨（2 周）

**一句话目标**: Permissive overload 清零，Blob 清理，sema 单元测试覆盖。

#### 任务 4.1: 清理 Permissive Overload [🔲] 预估 5 天

| 项 | 内容 |
|----|------|
| **输入** | 14 处 `{ Permissive: ... }` 妥协 |
| **输出** | 标准重载解析（精确匹配 → 类型提升 → 歧义报错） |
| **验证** | compiler-pass 34/34 + compiler-fail 新增歧义错误测试 |

#### 任务 4.2: 清理 Blob* 遗留代码 [🔲] 预估 3 天

| 项 | 内容 |
|----|------|
| **输入** | HIR Builder 中 284 处 `Blob*` 调用 |
| **输出** | 审计报告：活跃则重命名，遗留则删除 |
| **验证** | compiler-pass 34/34 |

#### 任务 4.3: sema 单元测试补全 [🔲] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入** | sema 0 个直接单元测试 |
| **输出** | 每个 sema 子模块 ≥ 5 个测试 |
| **验证** | `make test TEST_FILTER=compiler-sema` 全绿 |

#### 阶段 4 闭环标准

```
[ ] Permissive overload 清零（0 处 { Permissive } 注释）
[ ] Blob* 遗留代码清理完毕
[ ] sema 单元测试 ≥ 30 个（6 模块 × 5）
[ ] compiler-pass 34/34
```

---

## 三、闭环验证矩阵

> 每个阶段结束时，以下检查全部通过才算闭环。
> 完成时填入 ✅ 和日期。

| 检查项 | 阶段 0 | 阶段 1 | 阶段 2 | 阶段 3 | 阶段 4 |
|--------|--------|--------|--------|--------|--------|
| compiler-pass 34/34 | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| compiler-fail snapshot | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| rebuild-compiler | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| make hygiene | 🔲 | 🔲 | 🔲 | 🔲 | 🔲 |
| 内存峰值下降 > 50% | 🔲 | — | — | — | — |
| 热编译 < 1s | — | — | 🔲 | — | — |
| 并行编译可用 | — | — | 🔲 | — | — |
| JSON 诊断输出 | — | — | — | 🔲 | — |
| sema 单元测试 ≥ 30 | — | — | — | — | 🔲 |
| Permissive 清零 | — | — | — | — | 🔲 |

---

## 四、对标清单

| 设计 | nextPas | Rust 对标 | Go 对标 |
|------|---------|----------|--------|
| CST → AST Lowering | ✅ | `rustc_ast_lowering` | N/A |
| HIR (Typed AST) | ✅ | `rustc_hir` | N/A |
| MIR (CFG + SSA) | ✅ | `rustc_mir` | `ssa` package |
| 查询系统 | ✅ | `rustc_query_system` / Salsa | N/A |
| 增量编译 | ✅ | incremental compilation | `go build -i` |
| 并行编译 | ✅ | `-Z threads=N` | `go build -p N` |
| Arena 分配 | ✅ | `BumpPtr` / `TypedArena` | Node on Arena |
| 错误恢复 | ✅ | `rustc_parse` error recovery | `scanner.ErrorCount` |
| 结构化诊断 | ✅ | `--error-format=json` | `go vet -json` |
| 编译器用标准库 | ✅ | rustc 用 std | gc 用 Go std |

---

## 五、总时间线

```
Week  1-2:  阶段 0 — 基础设施（接入标准库，性能立竿见影）
Week  3-6:  阶段 1 — 架构重构（Pipeline + Sema + MIR）
Week  7-9:  阶段 2 — 查询化编译（增量 + 并行）
Week 10-13: 阶段 3 — 能力补全（优化 + 诊断 + 错误恢复）
Week 14-15: 阶段 4 — 清理打磨（Permissive + Blob + 测试）
```

**总计: 15 周（约 4 个月）**

---

## 六、编译器负责人入口指南

### 立即开始 — 阶段 0 第一步

```bash
# 1. 确认环境
cd /home/dtamade/projects/nextPas
git worktree list --porcelain  # 确认在 compiler worktree

# 2. 阅读上下文（15 分钟）
cat docs/plans/compiler-audit.md      # 了解 36 条量化发现
cat docs/plans/goal-tree.md           # 了解项目全局

# 3. 开始任务 0.1：符号表用 THashMap
# 打开 compiler/np_semantic_model.pas
# 找到 6 个 O(n) 查找函数，改为 THashMap

# 4. 每完成一个子任务验证
make compiler-pass    # 必须 34/34
make rebuild-compiler # 必须成功
make hygiene          # 必须通过
```

### 遇到问题

| 问题类型 | 查阅 |
|---------|------|
| 不知道某个 finding 的具体位置 | `docs/plans/compiler-audit.md` 有文件名+行数 |
| 不确定设计方向 | 看本文件"对标"列，找 rustc/go 对应模块 |
| 改动影响范围不明 | `make compiler-pass` + `make rebuild-compiler` |
| 需要新增标准库依赖 | 先确认 core/ 模块已有该功能，再看 `core/docs/design-conventions.md` |

### 进度更新

每完成一个任务，在本文件中将 `[🔲]` 改为 `[✅]` 并填写完成日期。
不要另建临时进度文件。

---

## 七、可持续更新机制

1. **本文件是唯一行动计划** — 不要创建 `compiler-sprint-plan-v2.md`、`compiler-progress.md` 等临时文件
2. **状态标记直接改本文件** — `[🔲]` → `[🔄]` → `[✅ 2026-07-XX]`
3. **闭环证据附在本文件末尾** — 每个阶段完成后追加一节 `## 阶段 N 闭环证据`
4. **路线图变更走 PR** — 任何阶段调整必须更新本文件 + goal-tree.md + PLAN.md，保持一致

---

*本计划对标 Rust 编译器 (rustc) 和 Go 编译器 (gc) 的架构设计。*
*每个阶段有明确的输入、输出、验证标准。完成即闭环。*
*最后更新：2026-07-05 | 版本: v2.0*
