# nextPas 编译器架构计划
> 目标：打造先进、优雅的 Pascal 编译器，对标 Rust/Go 编译器架构
> 版本：v1.0 | 日期：2026-07-05
> 原则：每个阶段有明确的输入、输出、验证标准。完成即闭环。
---
## 一、目标架构
对标 Rust 编译器 (rustc) 和 Go 编译器 (gc) 的核心设计原则，结合 Pascal 语言特性，
定义 nextPas 编译器的目标架构。
### 1.1 阶段化 Pipeline（对标 rustc）
```
                     ┌──────────┐
  Source Files ─────→│  Lexer   │──→ Token Stream
                     └──────────┘
                          │
                     ┌──────────┐
                     │  Parser  │──→ Concrete Syntax Tree (CST)
                     └──────────┘
                          │
                     ┌──────────┐
                     │  AST     │──→ Abstract Syntax Tree (类型无关)
                     │  Lower   │
                     └──────────┘
                          │
                     ┌──────────┐
                     │  Sema    │──→ Typed AST (HIR)
                     │  (Typeck)│    每个节点有确定类型
                     └──────────┘
                          │
                     ┌──────────┐
                     │  MIR     │──→ Mid-level IR (控制流图)
                     │  Lower   │    虚拟寄存器，无限SSA
                     └──────────┘
                          │
                     ┌──────────┐
                     │  MIR     │──→ 优化后的 MIR
                     │  Optimize│    内联、常量折叠、死代码消除...
                     └──────────┘
                          │
                     ┌──────────┐
                     │  Codegen │──→ LLVM IR / 原生代码
                     └──────────┘
```
**关键设计决策**：
1. **CST ≠ AST** — Parser 产出 Concrete Syntax Tree（保留所有语法细节），
   然后 Lower 到 Abstract Syntax Tree（去掉分号、括号等语法噪音）。
   Rust 用这个模式（`rustc_parse` → `rustc_ast_lowering`）。
2. **HIR = Typed AST** — Sema 阶段产出类型化 AST，每个表达式节点有确定的类型。
   这是编译器中最丰富的信息层，IDE 功能（跳转、补全）基于 HIR。
3. **MIR = 控制流图** — 从 HIR 降级到 Mid-level IR，引入基本块、SSA、虚拟寄存器。
   所有优化在 MIR 上做。MIR 是类型擦除的。
   Rust 的 MIR 是这个设计的最佳参考。
4. **MIR → LLVM IR** — 最后一步，MIR 翻译到 LLVM IR。
   如果以后想支持其他后端（Cranelift、GCC），只需写新的 MIR→X 翻译器。
### 1.2 查询化编译（对标 rustc）
rustc 的核心架构创新是 **查询系统 (query system)**：
```
传统：main() { lex(); parse(); sema(); codegen(); }  // 顺序执行
查询：type_of(def_id) → 如果没算过就算，算过就返回缓存  // 按需计算 + 自动缓存
```
查询系统的优势：
- **增量编译天然支持** — 输入变了，只重算依赖该输入的查询
- **并行编译天然支持** — 无依赖的查询可以并行执行
- **IDE 支持天然支持** — IDE 只查询当前文件需要的类型信息
Go 编译器没有查询系统（Go 的编译单位是 package，比较简单），
但 Rust、Swift、Scala 3 都用了这个模式。
**nextPas 应该实现查询化编译。** 这是"先进"的核心体现。
### 1.3 中间表示层（对标 Go gc）
Go 编译器有一个清晰的 IR 演进：
```
Go:   AST → SSA (多阶段) → 机器码
      没有 HIR/MIR 之分，直接在 AST 上做类型检查，然后生成 SSA
```
Go 的做法更简单，但 AST 和 SSA 之间的跨度太大。
**nextPas 用三层 IR**，每层有明确的职责：
| 层 | 名称 | 对标 | 职责 |
|----|------|------|------|
| HIR | High-level IR | rustc HIR | 类型化 AST，保留所有语法结构 |
| MIR | Mid-level IR | rustc MIR | 控制流图，SSA，类型擦除 |
| LIR | Low-level IR | LLVM IR | 目标代码，寄存器分配 |
### 1.4 错误恢复与诊断（对标 rustc）
rustc 的错误诊断是业界标杆：
- **错误恢复**：Parser 遇到错误后继续解析，尽可能多地报告错误
- **跨度 (Span)**：每个 AST 节点带源码位置，错误信息精确到字符
- **建议 (Suggestion)**：不仅报告错误，还给出修复建议（`help: consider borrowing here`）
- **结构化输出**：JSON 格式，IDE 可以直接消费
**nextPas 应该达到这个水平。** 当前一个错误就停止，差距很大。
### 1.5 目标架构总结
| 维度 | 当前 nextPas | 目标 nextPas | 对标 |
|------|-------------|-------------|------|
| Pipeline | 隐式，sema 做所有事 | 显式 6 阶段，每阶段独立 | rustc |
| IR 层数 | 1 (HIR) | 3 (HIR→MIR→LIR) | rustc |
| 编译模式 | 顺序全量 | 查询化，按需 + 缓存 | rustc |
| 增量编译 | 无 | 查询缓存，指纹匹配 | rustc |
| 并行编译 | 无 | 查询无依赖并行 | rustc |
| 错误恢复 | 无 | Parser 恢复 + 多错误报告 | rustc |
| 诊断 | 纯文本 | 结构化 JSON + 修复建议 | rustc |
| AST 内存 | class 堆分配 | Arena + 索引 | Go gc |
| 符号查找 | O(n) SameText | 哈希表 O(1) | Go gc |
---
## 二、当前架构差距
对标目标架构，当前编译器存在以下结构性差距：
### 差距 1：没有 MIR 层
当前 HIR → LLVM IR 直接翻译，中间没有任何优化层。
导致：(a) 无法做跨函数优化 (b) 无法做控制流优化 (c) LLVM 后端绑定太紧。
### 差距 2：Sema 是一个 God Class
279 方法混在一起，类型检查、重载解析、HIR 生成、字符串所有权全在一个 class 里。
对标：rustc 的 typeck 拆为 10+ 个 crate。
### 差距 3：没有查询系统
每次编译从 lexer 开始全量重来。没有缓存、没有增量、没有并行。
### 差距 4：Parser 没有错误恢复
一个语法错误就停止。IDE 场景完全不可用。
### 差距 5：AST 内存模型低效
每个 token 一个 class 实例堆分配。对标：Go 的 gc 用 Arena，rustc 用 BumpPtr。
### 差距 6：编译器不用标准库
标准库有 THashMap、TVec、TFastArena。编译器全部自己重新实现。
对标：rustc 重度使用 std，Go 的 gc 重度使用 Go 标准库。
---
## 三、分阶段实施计划
每个阶段有明确的输入、输出、验证标准、对标参考。完成即闭环。
---
### 阶段 0：基础设施（2 周）
**目标**：编译器成为标准库的客户。不改架构，只换实现。
#### 0.1 符号表用 THashMap（2 天）
输入：`np_semantic_model.pas` 中 6 个 O(n) 查找函数
输出：全部改为 THashMap，O(1) 查找
验证：compiler-pass 34/34 + rebuild-compiler 成功
对标：Go gc 的符号表用 `map[string]*Sym`
#### 0.2 动态数组改 TVec（2 天）
输入：145 处 `SetLength(arr, Length(arr)+1)` 逐元素扩容
输出：高频增长的数组改为 TVec
验证：compiler-pass 34/34 + rebuild-compiler 成功
对标：rustc 用 `IndexVec`、`ArenaVec`
#### 0.3 AST 节点用 Arena 分配（3 天）
输入：`TGreenNode = class`，每个 token 一次堆分配
输出：TGreenTree 持有 IArena，所有节点 Arena 分配，编译结束一次性释放
验证：heaptrc 报告 AST 分配从 5000+ 降到 ~10 次
对标：Go gc 的 `Node` 结构体用 Arena
#### 0.4 测量基线（1 天）
输入：阶段 0 前的编译时间、内存峰值
输出：阶段 0 后的编译时间、内存峰值，对比报告
验证：性能不退化，内存显著下降
**阶段 0 闭环标准**：compiler-pass 34/34，rebuild-compiler 成功，内存峰值下降 50%+。
---
### 阶段 1：架构重构（4 周）
**目标**：God Class 拆分 + Pipeline 显式化。对标 rustc 的模块划分。
#### 1.1 定义 Pipeline 接口（2 天）
输入：当前隐式的编译流程
输出：
```pascal
type
  ICompilerPhase = interface
    function Run(AInput: IPhaseInput): IPhaseOutput;
    function Name: string;
  end;
```
每个阶段是独立的 `ICompilerPhase` 实现。
验证：现有流程不改行为，只是包了一层接口。
对标：rustc 的 `Compiler::enter(|queries| ...)` 模式。
#### 1.2 拆分 Sema（15 天）
输入：`TSemanticAnalyzer`（279 方法，12,255 行）
输出：6 个独立模块
```
sema/
├── np_sema_builtins.pas           ~500 行  内置函数注册表
├── np_sema_string_ownership.pas   ~2000 行 字符串所有权分析
├── np_sema_overload.pas           ~1500 行 重载解析
├── np_sema_type_check.pas         ~1500 行 类型检查/推导
├── np_sema_hir_lowering.pas       ~3000 行 AST→HIR 降级
└── np_semantic_analyzer.pas       ~3700 行 协调器（剩余）
```
每步验证：compiler-pass 34/34
对标：rustc 的 `rustc_typeck`、`rustc_trait_selection`、`rustc_mir_build`
#### 1.3 引入 MIR 层（10 天）
输入：当前 HIR 直接到 LLVM IR
输出：
```
ir/
├── np_mir_model.pas       MIR 数据结构（基本块、SSA、虚拟寄存器）
├── np_hir_to_mir.pas      HIR → MIR 降级
├── np_mir_optimize.pas    MIR 优化 pass 框架
└── np_mir_to_llvm.pas     MIR → LLVM IR 翻译
```
MIR 的核心数据结构：
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
      ...
  end;
  TOperand = record
    case Kind: TOpKind of
      okCopy: (Val: TLocal);
      okMove: (Val: TLocal);
      okConst: (Val: TConst);
  end;
```
验证：HIR → MIR → LLVM IR 全流程跑通，compiler-pass 34/34
对标：rustc MIR（`rustc_middle::mir`）
**阶段 1 闭环标准**：Pipeline 显式化，Sema 拆分为 6 模块，MIR 层可用，compiler-pass 34/34。
---
### 阶段 2：查询化编译（3 周）
**目标**：实现查询系统，天然支持增量编译和并行编译。对标 rustc 的 query system。
#### 2.1 查询系统框架（5 天）
输入：当前 `TSemanticModel` 是顺序构建的
输出：
```pascal
type
  TQueryKey = string;  // e.g. 'type_of(MyUnit.MyType)'
  TQueryResult = record ... end;
  TQueryFunc = function(Key: TQueryKey): TQueryResult;
  TQueryDatabase = class
    function Get(Key: TQueryKey; Compute: TQueryFunc): TQueryResult;
    procedure Invalidate(Key: TQueryKey);
  end;
```
核心机制：
- `Get` 检查缓存，命中返回，未命中调用 `Compute` 并缓存
- `Invalidate` 标记缓存失效（源文件变化时触发）
- 依赖追踪：`Compute` 执行中调用了其他查询 → 自动记录依赖图
验证：编译全量 core/，查询缓存命中率 > 80%
对标：rustc 的 `TyCtxt` + `queries` 模块，Salsa 框架
#### 2.2 增量编译（5 天）
输入：查询系统框架
输出：
- 文件变化检测（mtime + hash）
- 查询失效传播（沿依赖图）
- 热编译：修改 1 个文件 → 只重算受影响的查询
验证：
```
冷编译（全量）: ~6s（不变）
热编译（改 1 行）: < 1s（目标）
```
对标：rustc 的 incremental compilation
#### 2.3 并行编译（5 天）
输入：查询依赖图
输出：无依赖的查询并行执行
```pascal
// 查询系统内部：
for each Query in ReadyQueue do
  ThreadPool.Spawn(Query);
```
验证：多核利用率 > 50%，编译时间线性下降
对标：rustc 的 parallel compiler（`-Z threads=N`）
**阶段 2 闭环标准**：查询系统运行，增量编译 < 1s，并行编译可用，compiler-pass 34/34。
---
### 阶段 3：能力补全（4 周）
**目标**：MIR 优化 + 错误恢复 + 诊断。对标业界最佳实践。
#### 3.1 MIR 优化 Pass（10 天）
输入：MIR 层
输出：至少 6 个优化 pass
```
1. 常量折叠 (Constant Folding)
2. 死代码消除 (Dead Code Elimination)
3. 强度削减 (Strength Reduction)
4. 函数内联 (Inlining)
5. 公共子表达式消除 (CSE)
6. 无用参数消除 (Dead Argument Elimination)
```
验证：每个 pass 有独立测试，编译结果正确，性能基准不退化
对标：rustc 的 MIR optimization passes
#### 3.2 错误恢复（5 天）
输入：Parser 遇到错误就停止
输出：Parser 错误恢复 + 多错误报告
```pascal
// 错误恢复策略：
// 1. 遇到错误 → 记录诊断
// 2. 跳过 token 直到同步点（';', 'end', 'begin'）
// 3. 继续解析
// 4. 限制：最多报告 100 个错误
```
验证：语法错误的文件报告多个错误（不是只有第一个）
对标：rustc 的 error recovery（`rustc_parse`）
#### 3.3 结构化诊断（5 天）
输入：纯文本错误输出
输出：JSON 诊断 + 修复建议
```json
{
  "message": "unknown identifier 'foo'",
  "span": {"file": "test.pas", "line": 10, "col": 5, "end_line": 10, "end_col": 8},
  "level": "error",
  "suggestions": [
    {"message": "did you mean 'foobar'?", "replacement": "foobar"}
  ]
}
```
验证：`nextpas build --diagnostics=json` 输出有效 JSON
对标：rustc 的 `--error-format=json`
**阶段 3 闭环标准**：6 个 MIR 优化 pass，错误恢复可用，JSON 诊断输出，compiler-pass 34/34。
---
### 阶段 4：清理与打磨（2 周）
**目标**：清理技术债，达到可维护状态。
#### 4.1 清理 Permissive Overload（5 天）
输入：14 处 `{ Permissive: ... }` 妥协
输出：标准重载解析（精确匹配 → 类型提升 → 歧义报错）
验证：compiler-pass 34/34 + compiler-fail 新增歧义错误
#### 4.2 清理 Blob* 遗留代码（3 天）
输入：HIR Builder 中 284 处 `Blob*` 调用
输出：确认是活跃代码还是遗留。遗留则删除，活跃则重命名
验证：compiler-pass 34/34
#### 4.3 单元测试补全（2 天）
输入：sema 0 个直接单元测试
输出：每个 sema 子模块至少 5 个测试
验证：`make test TEST_FILTER=compiler-sema` 全绿
**阶段 4 闭环标准**：Permissive overload 清除，Blob 清理，sema 有单元测试。
---
## 四、闭环验证矩阵
每个阶段结束时，以下检查全部通过才算闭环：
| 检查项 | 阶段 0 | 阶段 1 | 阶段 2 | 阶段 3 | 阶段 4 |
|--------|--------|--------|--------|--------|--------|
| compiler-pass 34/34 | ✅ | ✅ | ✅ | ✅ | ✅ |
| compiler-fail snapshot | ✅ | ✅ | ✅ | ✅ | ✅ |
| rebuild-compiler | ✅ | ✅ | ✅ | ✅ | ✅ |
| make hygiene | ✅ | ✅ | ✅ | ✅ | ✅ |
| 内存峰值下降 | ✅ | — | — | — | — |
| 热编译 < 1s | — | — | ✅ | — | — |
| 并行编译可用 | — | — | ✅ | — | — |
| JSON 诊断输出 | — | — | — | ✅ | — |
| sema 单元测试 | — | — | — | — | ✅ |
| Permissive 清零 | — | — | — | — | ✅ |
---
## 五、对标清单
每个设计决策都有对标依据：
| 设计 | nextPas 目标 | Rust 对标 | Go 对标 |
|------|-------------|----------|--------|
| CST → AST Lowering | ✅ | `rustc_ast_lowering` | N/A (Go 直接到 AST) |
| HIR (Typed AST) | ✅ | `rustc_hir` | N/A |
| MIR (CFG + SSA) | ✅ | `rustc_mir` | `ssa` package |
| 查询系统 | ✅ | `rustc_query_system` / Salsa | N/A |
| 增量编译 | ✅ | incremental compilation | `go build -i` (简单) |
| 并行编译 | ✅ | `-Z threads=N` | `go build -p N` |
| Arena 分配 | ✅ | `BumpPtr` / `TypedArena` | `Node` struct on Arena |
| 错误恢复 | ✅ | `rustc_parse` error recovery | `scanner.ErrorCount` |
| 结构化诊断 | ✅ | `--error-format=json` | `go vet -json` |
| 编译器用标准库 | ✅ | rustc 用 std | gc 用 Go std |
---
## 六、总时间线
```
Week 1-2:  阶段 0 — 基础设施（接入标准库）
Week 3-6:  阶段 1 — 架构重构（Pipeline + Sema + MIR）
Week 7-9:  阶段 2 — 查询化编译（增量 + 并行）
Week 10-13: 阶段 3 — 能力补全（优化 + 诊断 + 错误恢复）
Week 14-15: 阶段 4 — 清理打磨（Permissive + Blob + 测试）
```
**总计：15 周（约 4 个月）**
---
*本计划对标 Rust 编译器 (rustc) 和 Go 编译器 (gc) 的架构设计。*
*每个阶段有明确的输入、输出、验证标准。完成即闭环。*
*最后更新：2026-07-05*
