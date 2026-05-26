# nextPas 语义分析规范

这份规范定义 nextPas 语义分析器（`compiler/sema/np_semantic_analyzer.pas`）的契约边界。
它回答的不是 "sema 内部用什么算法做名字绑定"，而是 "sema 对其它层承诺产出什么
语义事实、不承诺什么、何时应当报错"。

这份文档承接 `compiler-pipeline-specification.md` 中 Typed HIR 的位置，并细化
`semantic-model-specification.md` 中对 symbol graph / type graph / Typed HIR 的要求。
它的上游输入是 Green CST（来自 `syntax/np_green_tree.pas`）和 unit graph
（来自 `frontend/np_unit_graph.pas`）。它的下游消费者包括：
MIR lowering (`ir/np_mir_model.pas`)、backend codegen、诊断 sink、未来的 IDE
language server。

## 这份规范要解决的核心问题

当前 sema 把"能产出 symbol count 和 typed-hir-node count"当作交付标准，但下游
需要的能力远不止此。这份规范冻结四个长期被忽略的边界：

- **名字绑定精度**：每个标识符引用必须能精确指向其声明的 SymbolId，不仅是
  字符串匹配
- **类型推断完整性**：每个表达式必须有确定的 TypeId，不仅是"看起来像 Integer"
- **作用域层级**：名字查找必须通过显式 scope 层级，不是递归搜索习惯
- **诊断质量**：语义错误必须能说明"在哪个 scope 查找失败"、"期望什么类型但
  得到什么类型"

## 语义模型是 sema 唯一的对外契约

sema 的输入是 `TAstFacade`（Green CST 的类型化视图）+ `TUnitGraph`（已解析的
unit 依赖图），输出是一个 `TSemanticModel`。

语义模型的格式约束：

- 每个声明产出一个 `TSemanticSymbol`（含 SymbolId、Name、Kind、OwnerUnitId、
  TypeId、ByteOffset）
- 每个类型产出一个 `TSemanticType`（含 TypeId、Name、Kind）
- 每个语义节点产出一个 `TTypedHirNode`（含 HirNodeId、Kind、DisplayName、
  SymbolId、TypeId、Operand）
- `TSemanticModel.Status` 为 `'ready'` 当且仅当无 error 级诊断

## Symbol Kind 清单

v1 阶段必须支持的 symbol kind：

| Kind         | 含义                           | 产出时机                    |
| ------------ | ------------------------------ | --------------------------- |
| `unit`       | 编译单元                       | unit graph 解析后           |
| `type`       | 类型声明                       | type section 中的 type decl |
| `variable`   | 变量声明                       | var section 中的 var decl   |
| `constant`   | 常量声明                       | const section 中的 const decl |
| `procedure`  | 过程声明                       | procedure decl              |
| `function`   | 函数声明                       | function decl               |
| `parameter`  | 形参                           | parameter list 中的 param decl |
| `field`      | record/class 字段              | record/class 字段声明       |
| `property`   | 属性声明                       | property decl               |
| `enum-value` | 枚举值                         | enum type 中的标识符        |

## Builtin Type 清单

v1 阶段冻结的 builtin canonical types：

- 整数族：`Byte`, `ShortInt`, `Word`, `SmallInt`, `LongWord`, `LongInt`,
  `Int64`, `QWord`
- 浮点族：`Single`, `Double`, `Extended`, `Currency`, `Comp`
- 布尔族：`Boolean`, `ByteBool`, `WordBool`, `LongBool`
- 字符族：`Char`, `AnsiChar`, `WideChar`
- 字符串族：`ShortString`, `AnsiString`, `WideString`, `UnicodeString`
- 指针族：`Pointer`
- 特殊：`Variant`, `OleVariant`, `Text`
- 别名：`Integer` = `LongInt`, `Cardinal` = `LongWord`, `String` = `AnsiString`

## Typed HIR Node Kind 清单

v1 阶段必须支持的 HIR node kind：

| Kind                    | 含义                                    |
| ----------------------- | --------------------------------------- |
| `compilation-root`      | 编译单元根节点                          |
| `resolved-unit`         | 已解析的 unit 引用                      |
| `procedure-decl`        | 过程声明                                |
| `function-decl`         | 函数声明                                |
| `var-decl-runtime`      | 运行时变量声明                          |
| `const-decl`            | 常量声明                                |
| `assignment-runtime`    | 运行时赋值                              |
| `call-runtime`          | 运行时过程/函数调用                     |
| `if-runtime`            | 运行时条件分支                          |
| `while-runtime`         | 运行时 while 循环                       |
| `for-runtime`           | 运行时 for 循环                         |
| `block-label-runtime`   | 控制流标签                              |
| `br-runtime`            | 无条件跳转                              |
| `br-cond-runtime`       | 条件跳转                                |
| `halt-call`             | Halt 调用                               |
| `runtime-contract`      | 运行时契约（init/fini）                 |

## 常量求值契约

sema 必须能在编译期求值以下常量表达式：

- 整数字面量
- 整数算术（+, -, *, div, mod）
- 整数比较（=, <>, <, >, <=, >=）
- 布尔运算（and, or, not, xor）
- 字符串字面量
- 字符串拼接（+）
- 已声明常量的引用
- `Ord`, `Chr`, `Length`（对字符串字面量）
- `Low`, `High`（对枚举和子范围类型）
- `SizeOf`（对已知大小的类型）

无法在编译期求值的表达式必须标记为 runtime，由 Typed HIR 的 runtime 节点承载。

## 诊断码清单（命名空间 `sema.*`）

- `sema.duplicate-declaration`：同一 scope 中重复声明
- `sema.undeclared-identifier`：标识符未声明
- `sema.type-mismatch`：类型不匹配
- `sema.unknown-callable`：调用目标不是当前可解析的 procedure/function 或内建 callable
- `sema.incompatible-assignment`：赋值类型不兼容
- `sema.wrong-argument-count`：实参数量与形参不匹配
- `sema.ambiguous-overload`：同名同参数个数 callable 候选无法唯一消歧
- `sema.circular-dependency`：循环依赖
- `sema.unresolved-unit`：unit 无法解析
- `sema.duplicate-unit-import`：重复导入同一 unit
- `sema.constant-overflow`：常量溢出
- `sema.division-by-zero`：编译期除零

## 性能契约

- 时间复杂度 `O(n)`，n 为 CST 节点数（单遍遍历 + 常量求值）
- 空间复杂度 `O(s + t + h)`，s 为 symbol 数、t 为 type 数、h 为 HIR 节点数
- symbol 查找必须 O(1) 或 O(log n)（当前 O(n) 线性扫描是 P3 缺陷）

## 接口稳定性

`TSemanticModel` 的公开 API 在 v1 阶段冻结：

- `function SymbolCount / SymbolAt / FindSymbolByName`
- `function TypeCount / FindTypeByName`
- `function TypedHirNodeCount / TypedHirNodeAt`
- `function RuntimeContractCount`
- `function ForeignProcedureBindingCount / ForeignProcedureBindingAt`
- `function LookupConstValue / LookupStringConstValue`
- `function Status / RootName`

`TSemanticAnalyzer` 的公开 API：

- `constructor Create(ARootAst, AUnitGraph, ADiagnostics, ARootFileId, ANoFold)`
- `procedure Analyze`
- `function DetachModel: TSemanticModel`
- `function Status: string`

## 当前实现与规范的差距（缺陷清单）

| 缺陷 ID | 优先级 | 描述                                                    |
| -------- | ------ | ------------------------------------------------------- |
| S-001    | P0     | 无 scope 模型——所有 symbol 在同一平面                   |
| S-002    | P0     | 无 type 声明注册——用户定义类型不进入 type graph         |
| S-003    | P0     | 无 parameter symbol 注册                                |
| S-004    | P0     | 无 field symbol 注册                                    |
| S-005    | P1     | 无名字绑定——标识符引用不指向 SymbolId                   |
| S-006    | P1     | 无表达式类型推断                                        |
| S-007    | P1     | 无 duplicate declaration 检测（除 unit import）         |
| S-008    | P1     | 无 undeclared identifier 检测                           |
| S-009    | P2     | symbol 查找 O(n) 线性扫描                               |
| S-010    | P2     | 无 overload resolution                                  |
| S-011    | P2     | 无 class/interface 继承链分析                           |
| S-012    | P0     | 无 enum value symbol 注册                               |
