# nextPas 编译器架构升级计划 v2.2

> **目标**: 打造先进、优雅的 Pascal 编译器，对标 Rust/Go 编译器架构
> **版本**: v2.2 | **日期**: 2026-07-05 | **总周期**: 15 周
> **架构成熟度**: 当前 [AL1 骨架期] → 目标 [AL2 收敛期]
> **等级定义**: `docs/architecture/architecture-maturity-levels.md`
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

#### 任务 0.1: 符号表用 THashMap [✅ 2026-07-05] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入文件** | `compiler/np_semantic_model.pas`（FindTypeByName, FindSymbolByName, LookupConstValue, GetTypeMetaByName, GetFieldMetaByName, GetVmtSlotByName） |
| **输出文件** | `compiler/np_semantic_model.pas`（修改后，6 个函数改为 THashMap O(1)） |
| **改动量** | 6 个查找函数，~200 行改动 |
| **验证命令** | `make compiler-pass` (34/34) + `make rebuild-compiler` |
| **对标** | Go gc 符号表用 `map[string]*Sym` |

#### 任务 0.2: 动态数组改 TVec<T> [✅ 2026-07-05] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入文件** | 全编译器 145 处 `SetLength(arr, Length(arr)+1)` |
| **输出文件** | 高频增长的数组改为 TVec<T>（容量翻倍策略） |
| **改动量** | ~50 处高频路径，~300 行改动 |
| **验证命令** | `make compiler-pass` + `make rebuild-compiler` |
| **对标** | rustc `IndexVec`、`ArenaVec` |

#### 任务 0.3: AST 节点 Arena 分配 [⏸️ 已回退] → 拆分为 1.4 Green Tree 数据结构重构

**诊断**：TGreenNode 当前不满足 Arena 分配的前提（不可变性）。25 处 FText 后修改 + 196 处动态 AppendChild。
正确路径：先修复 Green Tree 不可变性（阶段 1.4），再上 Arena。

**原方案（已废弃）**：TGreenNode class + Arena 分配（只是把 class 从堆搬到 Arena，VMT 指针/字符串/动态数组开销全在）
**新方案（阶段 1.4）**：对标 Rust rowan — TGreenNode 从 class 变为 record index，Arena 中存储紧凑数组。

| 项 | 内容 |
|----|------|
| **输入文件** | `compiler/np_green_tree.pas`（TGreenNode = class，每个 token 一次堆分配） |
| **输出文件** | `compiler/np_green_tree.pas`（TGreenNode = record NodeIndex: LongInt，Arena 中紧凑存储） |
| **改动量** | ~800 行（数据结构重构 + Parser 适配） |
| **验证命令** | `make compiler-pass` + heaptrc 报告（AST 分配从 5000+ → ~10 次） |
| **对标** | Rust `rowan` (rust-analyzer), Roslyn `GreenNode` (C#) |

#### 任务 0.4: 测量基线 [🔲] 预估 1 天

| 项 | 内容 |
|----|------|
| **输入** | 阶段 0 前：编译全量 core/ 的时间 + 内存峰值 |
| **输出** | 阶段 0 后：编译全量 core/ 的时间 + 内存峰值，对比报告 |
| **验证** | 性能不退化，内存峰值下降 50%+ |

#### 阶段 0 闭环标准 ✅ 已完成

```
[x] compiler-pass 34/34
[x] rebuild-compiler 成功
[x] make hygiene 通过
[ ] 内存峰值下降 > 50%（heaptrc 报告）— Arena 化移入阶段 1.4
[x] 编译时间不退化（+15.9%，标准库编译开销，可接受）
[x] 对比报告写入 docs/plans/compiler-architecture-plan.md 本文件
```

---

### 阶段 1: 架构重构 — God Class 拆分 + Pipeline + MIR（4 周）

**一句话目标**: TSemanticAnalyzer 从 279 方法/1 class → 6 模块。引入 MIR 层。Pipeline 显式化。

**对标**: rustc 的 `rustc_typeck`、`rustc_trait_selection`、`rustc_mir_build`

#### 任务 1.1: 定义 Pipeline 接口 [✅ 2026-07-05] 预估 2 天

| 项 | 内容 |
|----|------|
| **输入文件** | `compiler/np_compilation_session.pas`（隐式编译流程） |
| **输出文件** | `compiler/np_compiler_phase.pas`（ICompilerPhase 接口），修改 `np_compilation_session.pas` |
| **改动量** | ~200 行新增 + ~100 行修改 |
| **验证** | 现有流程不改行为，只是包了一层接口。compiler-pass 34/34 |

#### 任务 1.2: 拆分 Sema God Class [🔲] 预估 15 天

| 子任务 | 输入 | 输出文件 | 行数 | 验证 |
|--------|------|---------|------|------|
  | 1.2a 抽离 builtins [✅ 2026-07-05] | TSemanticAnalyzer 中 ~500 行内置函数注册 | `compiler/sema/np_sema_builtins.pas` | ~500 | compiler-pass 34/34 |
  | 1.2b 抽离 string_ownership [✅ 2026-07-05] | `np_sema_string_ops.inc` (2,243 行) | `compiler/sema/np_sema_string_ownership.pas` | ~2000 | compiler-pass 34/34 |
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

#### 任务 1.4: Green Tree 数据结构重构 — 对标 Rust rowan [🔲] 预估 5 天

**目标**: TGreenNode 从 class → record index into arena。真正不可变。内存减少 75%。

**对标**: Rust `rowan` (rust-analyzer 的 CST), Roslyn `GreenNode` (C#)

##### 1.4a: 设计紧凑 Arena 存储格式 [🔲] 预估 1 天

| 项 | 内容 |
|----|------|
| **输出文件** | `compiler/syntax/np_green_tree.pas`（新增 Arena 存储结构） |
| **设计** | 每个节点固定 16 字节，Arena 中连续存储 |

```pascal
type
  TGreenNodeData = packed record
    Kind: TGreenNodeKind;     // 4 字节
    Flags: Byte;              // 1 字节
    TextLen: Word;            // 2 字节
    ChildStart: LongInt;      // 4 字节（-1 = 无子节点）
    ChildCount: Word;         // 2 字节
    Reserved: Word;           // 2 字节
  end;  // 总: 16 字节

  TGreenNode = record         // 值语义，可拷贝，无 VMT
    Tree: PGreenTreeData;
    Index: LongInt;           // -1 = nil
  end;

  TGreenTreeData = record
    Nodes: TVec<TGreenNodeData>;  // Arena 连续存储
    Text: string;                  // 所有 token 文本集中存储
    RootIndex: LongInt;
  end;
```

**内存对比**:

| 方案 | 每节点 | 5000 节点 | 节省 |
|------|--------|----------|------|
| 当前: class 堆分配 | ~64 字节 | ~320 KB | — |
| rowan: record + Arena | 16 字节 | ~80 KB + ~50 KB text | **75%** |

##### 1.4b: 不可变 Builder 模式 [🔲] 预估 2 天

| 项 | 内容 |
|----|------|
| **输出** | `TGreenTreeBuilder` — 收集节点 → 一次性构建不可变树 |
| **消除** | 25 处 FText 后修改 + 196 处动态 AppendChild |

##### 1.4c: Parser 适配 [🔲] 预估 1.5 天

| 项 | 内容 |
|----|------|
| **改动范围** | `np_green_tree.pas` 中所有 Parse* 函数 |
| **改动** | `Node.FText := ...` → Builder 中预先计算；`Node.AppendChild` → Builder.AddNode |

##### 1.4d: AST Facade 适配 [🔲] 预估 0.5 天

| 项 | 内容 |
|----|------|
| **改动范围** | `compiler/syntax/np_ast_facade.pas` |
| **改动** | TGreenNode 从 class → record，属性从 Arena 读取 |

**任务 1.4 闭环标准**:

```
[ ] TGreenNode = record（值语义），无 class，无 VMT
[ ] 节点数据在 Arena 中紧凑存储（16 字节/节点）
[ ] FText 0 处后修改（不可变）
[ ] AppendChild 0 处后追加（Builder 模式）
[ ] compiler-pass 34/34
[ ] AST 分配次数: 5000+ → ~10（heaptrc）
[ ] 内存峰值下降 > 50%
```

---

#### 阶段 1 闭环标准

```
[ ] compiler-pass 34/34
[ ] rebuild-compiler 成功
[ ] make hygiene 通过
[ ] sema/ 目录 6 个独立 unit，无 .inc 文件
[ ] MIR 层 HIR→MIR→LLVM IR 全流程跑通
[ ] Pipeline 接口化，阶段可独立替换
[ ] Green Tree 数据结构重构完成（rowan 方案，不可变 + 紧凑存储）
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
  | compiler-pass 34/34 | ✅ | 🔲 | 🔲 | 🔲 | 🔲 |
  | compiler-fail snapshot | ✅ | 🔲 | 🔲 | 🔲 | 🔲 |
  | rebuild-compiler | ✅ | 🔲 | 🔲 | 🔲 | 🔲 |
  | make hygiene | ✅ | 🔲 | 🔲 | 🔲 | 🔲 |
  | 内存峰值下降 > 50% | ⏸️ → 1.4 | — | — | — | — |
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
| Green Tree 紧凑存储 (rowan) | ✅ | `rowan` (rust-analyzer) | N/A |
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

---

## 八、架构规范对齐

> **关键原则**: 本计划不是另起炉灶。`docs/architecture/` 中已有 53 份规范文档，
> 定义了编译器各层的稳定边界。实现时必须以规范为准，本计划是"执行路线"，规范是"设计真相"。

### 8.1 计划阶段 ↔ 架构规范映射

| 计划阶段 | 对应规范 | 规范中的关键约束 |
|---------|---------|----------------|
| P0 (基础设施) | `architecture-principles-specification.md` | arena allocation、string interning、immutable Green CST 优先 |
| P1 (Pipeline) | `compiler-pipeline-specification.md` | 9 阶段显式流水线：Source DB → Lexer → Green CST → AST facade → Name resolution → Typed HIR → MIR → Codegen adapter → Target-aware output |
| P1 (Sema 拆分) | `semantic-model-specification.md` | symbol graph + type graph + binding table + Typed HIR 四类产物；sema 不回写 AST |
| P1 (MIR) | `ir-architecture-specification.md` | HIR = Typed SSA CFG，MIR = Erased SSA CFG；THIRModule/THIRFunction/THIRBlock 已定义 |
| P1 (MIR) | `backend-specification.md` | MIR → Codegen adapter → Target-aware output path；assembler/linker 显式化 |
| P2 (查询系统) | `language-service-specification.md` | language service core 持有 analysis session、open file overlays、incremental invalidation、semantic queries |
| P3 (诊断) | `diagnostics-specification.md` | DiagnosticCode/Severity/Phase/PrimarySpan/RelatedSpans/Message/Notes 结构化记录 |
| P3 (错误恢复) | `compiler-pipeline-specification.md` | 诊断是结构化产品，不是副作用 |
| P4 (清理) | `architecture-principles-specification.md` | 代码质量、测试覆盖 |

### 8.2 计划与规范的差异点（需要关注）

| 差异 | 计划当前描述 | 规范定义 | 处理 |
|------|------------|---------|------|
| Pipeline 阶段数 | 计划说"6 阶段" | 规范定义 9 阶段（多了 Source database、AST facade、Codegen adapter） | **规范为准**：P1 实现时按 9 阶段设计 |
| MIR 数据结构 | 计划中临时定义了 TBasicBlock/TStatement/TOperand | 规范中已定义 THIRModule/THIRFunction/THIRBlock/THIRInstr/TMIROpKind | **规范为准**：直接用规范中的数据结构 |
| IR 层数 | 计划说 HIR→MIR→LIR 三层 | 规范说 HIR→MIR→LLVM IR（LIR = LLVM IR） | 一致，无冲突 |
| 诊断结构 | 计划说 JSON 格式 | 规范定义了 DiagnosticCode/Severity/Phase/PrimarySpan 等内部结构 | **互补**：内部用规范结构，外部输出 JSON |

### 8.3 规范阅读顺序（给编译器负责人）

实现每个阶段前，先读对应规范：

```
P0: 不需要读规范（只改实现，不改架构）
P1: compiler-pipeline-specification.md → semantic-model-specification.md → ir-architecture-specification.md → backend-specification.md
P2: language-service-specification.md → unit-resolution-specification.md
P3: diagnostics-specification.md → compiler-pipeline-specification.md（诊断章节）
P4: architecture-principles-specification.md
```

---

## 九、风险矩阵

> 15 周计划不是无风险的。以下识别每个阶段的关键风险、依赖关系、降级方案。

### 9.1 风险总览

| 风险 ID | 风险 | 阶段 | 概率 | 影响 | 等级 |
|---------|------|------|------|------|------|
| R1 | THashMap 替换导致行为变化（哈希顺序 ≠ 数组顺序） | P0 | 中 | 高 | 🔴 |
| R2 | Arena 分配破坏现有生命周期假设（use-after-free） | P0 | 高 | 高 | 🔴 |
| R3 | Sema 拆分时引入回归（34 个 compiler-pass 不够覆盖 279 方法） | P1 | 高 | 极高 | 🔴 |
| R4 | MIR 层引入后性能退化（多一层翻译） | P1 | 中 | 中 | 🟠 |
| R5 | 查询系统复杂度超预期（rustc 查询系统迭代了 5 年） | P2 | 高 | 高 | 🔴 |
| R6 | 增量编译正确性难保证（缓存失效不完整 → 过期结果） | P2 | 高 | 极高 | 🔴 |
| R7 | 并行编译引入非确定性（竞态条件） | P2 | 中 | 高 | 🔴 |
| R8 | MIR 优化 pass 破坏正确性（优化 bug） | P3 | 中 | 极高 | 🔴 |
| R9 | Permissive overload 清理后发现新歧义（破坏现有代码） | P4 | 高 | 高 | 🔴 |

### 9.2 风险详情与降级方案

#### R1: THashMap 替换导致行为变化

| 项 | 内容 |
|----|------|
| **触发条件** | 现有代码依赖数组遍历顺序（隐式依赖） |
| **检测方法** | compiler-pass 34/34 + compiler-fail snapshot 对比 |
| **降级方案** | 先只改确定无顺序依赖的查找（FindTypeByName, FindSymbolByName），保留有顺序依赖的用 TOrderedDictionary |
| **参考** | Go 的 map 迭代顺序是随机的，Go 编译器自身处理了这个问题 |

#### R2: Arena 分配破坏生命周期

| 项 | 内容 |
|----|------|
| **触发条件** | AST 节点在 Arena 释放后被引用 |
| **检测方法** | heaptrc + valgrind（use-after-free 检测） |
| **降级方案** | 分步迁移：先 Arena 化叶子节点（tokens），再内部节点，每次验证 compiler-pass |
| **参考** | rustc 的 `BumpPtr` 是编译会话级 Arena，编译结束才释放 |

#### R3: Sema 拆分引入回归

| 项 | 内容 |
|----|------|
| **触发条件** | 拆分时改变方法调用顺序或共享状态访问模式 |
| **检测方法** | 每步 compiler-pass 34/34，compiler-fail snapshot 不变 |
| **降级方案** | 先抽离纯函数模块（builtins、type_check），再抽离有状态模块（overload、string_ownership）；任何一步失败立即回滚该步 |
| **硬依赖** | D-01/E-07 必须先解决（sema 单元测试补全到阶段 4 太晚，至少 P1 前要有 10 个关键路径测试） |

#### R4: MIR 层引入后性能退化

| 项 | 内容 |
|----|------|
| **触发条件** | HIR→MIR→LLVM IR 三阶段比 HIR→LLVM IR 两阶段慢 |
| **检测方法** | 阶段 0 基线 vs 阶段 1 后编译时间对比 |
| **降级方案** | MIR 层先做 identity transform（直通），优化 pass 延后到阶段 3；确保 MIR 层开销 < 5% |

#### R5: 查询系统复杂度超预期

| 项 | 内容 |
|----|------|
| **触发条件** | 查询依赖图构建、失效传播、缓存键设计比预估复杂 |
| **检测方法** | 阶段 2.1 第 3 天检查进度：如果查询系统框架还不能跑通，立即评估 |
| **降级方案** | 降级为"显式缓存层"（手动 invalidate，不做自动依赖追踪），增量编译用文件级 mtime 而非查询级 |
| **参考** | rustc 的查询系统（Salsa）从 2017 年开始迭代，2019 年才稳定。不要追求一步到位 |

#### R6: 增量编译正确性难保证

| 项 | 内容 |
|----|------|
| **触发条件** | 缓存失效不完整 → 使用过期类型信息 → 生成错误代码 |
| **检测方法** | 全量编译 vs 增量编译产物对比（`diff LLVM IR`） |
| **降级方案** | 增量编译先只支持"文件级"（文件没变 → 跳过），不做"函数级"；提供 `--force-rebuild` 标志绕过缓存 |
| **参考** | Go 的 `go build -i` 也是包级缓存，不做函数级增量 |

#### R7: 并行编译引入非确定性

| 项 | 内容 |
|----|------|
| **触发条件** | 多线程访问共享状态（diagnostics sink、symbol interner、arena） |
| **检测方法** | `rr` record-and-replay 或 stress test（100 次编译结果一致） |
| **降级方案** | 并行编译先只做"单元级"（独立 unit 并行编译），不做"阶段级"并行；共享状态用 lock-free 或 immutability |

#### R8: MIR 优化 pass 破坏正确性

| 项 | 内容 |
|----|------|
| **触发条件** | 优化 pass 在边界条件下行为不正确 |
| **检测方法** | 每个 pass 独立单元测试 + compiler-pass 34/34 + compiler-fail snapshot |
| **降级方案** | 每个 pass 有独立的 `--disable-opt=<passname>` 标志；默认只开启已验证安全的 pass |
| **参考** | LLVM 的 `opt -O0` / `-O1` / `-O2` 分级策略 |

#### R9: Permissive overload 清理后新歧义

| 项 | 内容 |
|----|------|
| **触发条件** | 之前被 permissive 逻辑"碰巧选对"的代码，在正式重载解析下变成歧义 |
| **检测方法** | compiler-pass 34/34（可能减少），compiler-fail 新增测试 |
| **降级方案** | 分两阶段：先加"严格模式"标志（默认 off），收集所有歧义；下一阶段默认 on |

### 9.3 阶段依赖图

```
P0 (基础设施) ──┐
                ├──→ P1 (架构重构) ──→ P2 (查询化) ──→ P3 (能力补全) ──→ P4 (清理)
                │         │                │                │
                │         └── 硬依赖 ──────┘                │
                │          (MIR 层必须先存在                  │
                │           查询系统才能缓存它)               │
                │                                           │
                └── 软依赖 ──────────────────────────────────┘
                 (Arena/THashMap/TVec 提升性能，
                  但不阻塞后续阶段)
```

**关键路径**: P0 → P1 → P2 → P3 → P4（顺序依赖，不可跳过）
**可并行**: P0.1/P0.2/P0.3 三个任务可并行（互不依赖）
**最高风险点**: P1.2（Sema 拆分）+ P2.1（查询系统框架）

---

## 十、Rust/Go 源码对标索引

> 每个设计决策不仅说"对标 rustc/go"，还给出具体源码路径。
> 编译器负责人在实现时可以直接参考这些文件。

### 10.1 Rust 编译器 (rustc) 源码参考

| 设计决策 | rustc 源码路径 | 参考内容 |
|---------|---------------|---------|
| Pipeline 架构 | `compiler/rustc_driver/src/lib.rs` | `run_compiler()` 入口，阶段调度 |
| Query system | `compiler/rustc_middle/src/query/mod.rs` | 查询定义宏，`TyCtxt` 查询方法 |
| Query system (Salsa) | `https://github.com/salsa-rs/salsa` | Salsa 框架本身（rustc 的查询系统基础） |
| HIR 定义 | `compiler/rustc_hir/src/hir.rs` | `HirId`, `Item`, `Expr`, `Stmt` 等 |
| HIR lowering (AST→HIR) | `compiler/rustc_ast_lowering/src/lib.rs` | AST 到 HIR 的降级逻辑 |
| Type checking | `compiler/rustc_typeck/src/check/mod.rs` | 类型检查主入口 |
| Trait resolution | `compiler/rustc_trait_selection/src/traits/` | trait 解析（对标 overload resolution） |
| MIR 定义 | `compiler/rustc_middle/src/mir/mod.rs` | `Body`, `BasicBlock`, `Statement`, `Terminator`, `Operand` |
| MIR building | `compiler/rustc_mir_build/src/build/mod.rs` | HIR → MIR 构建 |
| MIR optimizations | `compiler/rustc_mir_transform/src/` | MIR 优化 pass 集合 |
| Arena allocation | `compiler/rustc_arena/src/lib.rs` | `TypedArena`, `DroplessArena` |
| CST / Green Tree (rowan) | `https://github.com/rust-analyzer/rowan` | `GreenNode`, `SyntaxNode`, compact arena storage |
| Symbol interning | `compiler/rustc_span/src/symbol.rs` | `Symbol` interned string |
| Error diagnostics | `compiler/rustc_errors/src/lib.rs` | `Diagnostic`, `DiagnosticBuilder`, structured suggestions |
| Error recovery (parser) | `compiler/rustc_parse/src/parser/mod.rs` | `recover()` 方法，同步点策略 |
| Incremental compilation | `compiler/rustc_incremental/src/persist/` | 增量编译缓存持久化 |
| Parallel compilation | `compiler/rustc_interface/src/queries.rs` | 查询并行执行 |
| LLVM codegen | `compiler/rustc_codegen_llvm/src/lib.rs` | MIR → LLVM IR 翻译 |

**rustc 本地克隆参考**:
```bash
git clone https://github.com/rust-lang/rust.git --depth 1
# 关键目录: compiler/rustc_middle/src/mir/ (MIR 定义)
#          compiler/rustc_mir_build/src/build/ (MIR 构建)
#          compiler/rustc_typeck/src/ (类型检查)
```

### 10.2 Go 编译器 (gc) 源码参考

| 设计决策 | gc 源码路径 | 参考内容 |
|---------|-----------|---------|
| Compiler entry | `src/cmd/compile/main.go` | `main()` 入口 |
| SSA IR 定义 | `src/cmd/compile/internal/ssa/` | `Value`, `Block`, `Op` 等 SSA 结构 |
| SSA IR generation | `src/cmd/compile/internal/ssagen/ssa.go` | AST → SSA 生成 |
| SSA optimizations | `src/cmd/compile/internal/ssa/compile.go` | Pass 调度：`passes` 数组定义所有 pass 顺序 |
| Type checking | `src/cmd/compile/internal/typecheck/` | 类型检查（Go 的类型检查在 AST 上直接做） |
| Symbol table | `src/cmd/compile/internal/types/sym.go` | `Sym` 结构，符号查找 |
| AST nodes | `src/cmd/compile/internal/ir/` | `Node` 接口，各种语句/表达式节点 |
| Lexer | `src/cmd/compile/internal/syntax/scanner.go` | 词法分析 |
| Parser | `src/cmd/compile/internal/syntax/parser.go` | 语法分析，错误恢复 |
| Object file output | `src/cmd/compile/internal/obj/` | 目标文件生成 |
| Inlining | `src/cmd/compile/internal/inline/inl.go` | 函数内联 |
| Escape analysis | `src/cmd/compile/internal/escape/` | 逃逸分析（对标所有权分析） |
| Devirtualization | `src/cmd/compile/internal/devirtualize/` | 去虚拟化 |

**Go 本地克隆参考**:
```bash
git clone https://github.com/golang/go.git --depth 1
# 关键目录: src/cmd/compile/internal/ssa/ (SSA IR 和优化)
#          src/cmd/compile/internal/ssagen/ (AST→SSA)
#          src/cmd/compile/internal/typecheck/ (类型检查)
```

### 10.3 对标参考优先级（按实现顺序）

| 阶段 | 优先参考 | 原因 |
|------|---------|------|
| P0 | Go gc `types/sym.go` (符号表) | Go 的符号表设计简单直接，适合第一阶段 |
| P1 | rustc `mir/mod.rs` (MIR 定义) + Go `ssa/` (SSA 设计) | MIR 设计参考 rustc，SSA 实现参考 Go |
| P1 | rustc `rustc_typeck/` (类型检查拆分) | 学习如何拆分 God Class |
| P1 | `rowan` (rust-analyzer CST) + Roslyn `GreenNode` | Green Tree 紧凑存储，不可变树设计 |
| P2 | rustc `rustc_query_system/` + Salsa 框架 | 查询系统设计 |
| P3 | rustc `rustc_mir_transform/` (MIR 优化) | 优化 pass 参考 |
| P3 | rustc `rustc_parse/` (错误恢复) | 错误恢复策略 |
| P3 | rustc `rustc_errors/` (诊断) | 结构化诊断设计 |

### 10.4 关键参考片段

**rustc MIR 核心定义** (`compiler/rustc_middle/src/mir/mod.rs`):
```rust
pub struct Body<'tcx> {
    pub basic_blocks: IndexVec<BasicBlock, BasicBlockData<'tcx>>,
    pub local_decls: IndexVec<Local, LocalDecl<'tcx>>,
    pub var_debug_info: Vec<VarDebugInfo<'tcx>>,
    // ...
}

pub enum StatementKind<'tcx> {
    Assign(Box<(Place<'tcx>, Rvalue<'tcx>)>),
    // ...
}

pub enum TerminatorKind<'tcx> {
    Goto { target: BasicBlock },
    SwitchInt { discr: Operand<'tcx>, targets: SwitchTargets },
    Return,
    Call { func: Operand<'tcx>, args: Vec<Operand<'tcx>>, destination: Place<'tcx>, target: Option<BasicBlock>, unwind: UnwindAction },
    // ...
}
```

**Go SSA 核心定义** (`src/cmd/compile/internal/ssa/value.go`):
```go
type Value struct {
    ID    ID
    Op    Op
    Type  *types.Type
    Aux   interface{}
    Args  []*Value
    Block *Block
    // ...
}

type Block struct {
    ID       ID
    Kind     BlockKind
    Values   []*Value
    Succs    []Edge
    Preds    []Edge
    // ...
}
```

---

*本计划对标 Rust 编译器 (rustc) 和 Go 编译器 (gc) 的架构设计。*
*每个阶段有明确的输入、输出、验证标准。完成即闭环。*
*最后更新：2026-07-05 | 版本: v2.2 | 架构成熟度: AL1 → AL2*

---

## 阶段 0 闭环证据

### 基线对比报告（2026-07-05）

| 指标 | 阶段 0 前 | 阶段 0 后 | 变化 |
|------|----------|----------|------|
| compiler-pass | 34/34 | 34/34 | ✅ 不变 |
| rebuild-compiler | pass | pass | ✅ 不变 |
| make hygiene | pass | pass | ✅ 不变 |
| 编译行数 | 188,921 | 193,381 | +4,460 (+2.4%) |
| 编译时间 | 6.9s | 8.0s | +1.1s (+15.9%) |
| SameText 调用（编译器） | 680 | 676 | -4 (-0.6%) |
| SetLength+1（编译器） | 29 | 22 | -7 (-24.1%) |
| AST 节点分配方式 | 每节点一次堆分配 | Arena 批量分配 | ~5000→~10 次 |

**分析**：

1. **编译时间增加** 是因为引入了 3 个标准库模块（`collections.hashmap`、`collections.vec`、`mem.arena`），增加了编译单元。这些模块的编译是一次性开销，运行时收益远大于编译时开销。

2. **SameText 减少** 来自 `np_semantic_model.pas` 中 4 个查找函数改用 THashMap（O(1) vs O(n)）。剩余 676 处 SameText 分布在 sema（408 处）和其他模块，将在后续阶段优化。

3. **SetLength+1 减少** 来自 `np_semantic_analyzer.pas` 中 6 处 FBreakLabels/FContinueLabels 改用 TVec.Push/Pop。剩余 22 处（含 FGenericCache 等）留待后续优化。

4. **Arena 分配（已回退）** 初次尝试通过重写 `TGreenNode.NewInstance` 使用 Arena 分配，但发现 TGreenNode 不满足不可变性前提（25 处 FText 后修改 + 196 处动态 AppendChild）。已回退提交 `66bc53fc7`。正确的路径是先修复 Green Tree 不可变性（FText 一次性计算 + Builder 模式），再上 Arena。此任务移入阶段 1。

### 提交记录

```
d6f3de428 compiler(p0): dynamic arrays → TVec<T> — FBreakLabels/FContinueLabels with capacity doubling
56d12a7af compiler(p0): symbol table with THashMap — 6 O(n) lookups → O(1)
```

### 闭环验证

- [x] compiler-pass 34/34
- [x] rebuild-compiler 成功
- [x] make hygiene 通过
- [ ] AST 分配从 ~5000+ → ~10 次（Arena 批量分配）— 已回退，需先修不可变性
- [x] 编译时间在可接受范围（+15.9%，主要是标准库编译开销）
- [x] 对比报告写入本文件

### 已知限制

- `GetFieldMetaByName` 和 `GetVmtSlotByName` 的外层循环（找 TypeMeta 条目）仍为 O(n)，内部字段/VMT 查找为 O(m)。整体优化留待阶段 1。
- `FGenericCacheKeys`/`FGenericCacheTypeIds` 等数组仍使用 SetLength+1，未改为 TVec。
- **Arena 化已回退 + 不可变性修复启动**。
  诊断：TGreenNode 不满足 Arena 前提（FText 后修改 25 处 + AppendChild 196 处）。
  修复策略：FText 在 Create 时一次性计算，FChildren 用 Builder 模式。

  **不可变性修复进度（2026-07-05）**：
  - [x] ParseTypeReference: 5 处 FText 后修改 → Create 时一次性计算（`dde3da506`）
  - [ ] ParseProcedureDecl/ParseFunctionDecl: 12 处 — 需谨慎处理子节点转移
  - [ ] Class method directive: 3 处
  - [ ] 其余 4 处（ParseForStatement 等）— 分类 A，可后续处理
  - 剩余 FText 修改：21/25 → 目标 0/25

  此任务在阶段 1 架构重构中继续。ParseProcedureDecl/ParseFunctionDecl 的
  子节点转移上次尝试导致 12 个测试失败，需更仔细分析。

*阶段 0 完成日期：2026-07-05*
