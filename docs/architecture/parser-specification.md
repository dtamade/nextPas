# nextPas Parser 规范

这份规范定义 nextPas 语法分析器（`compiler/syntax/np_green_tree.pas`）的契约边界。
它回答的不是 "parser 内部用什么递归下降策略"，而是 "parser 对其它层承诺产出什么
CST 结构、不承诺什么、何时应当报错、何时应当恢复"。

这份文档承接 `lexer-specification.md` 对 token 流的定义，并细化
`compiler-pipeline-specification.md` 中 Green CST 的位置。它的下游消费者包括：
AST facade (`syntax/np_ast_facade.pas`)、语义分析 (`sema/np_semantic_analyzer.pas`)、
诊断 sink (`diagnostics/np_diagnostics_sink.pas`，参见 `diagnostics-specification.md` 中
`Phase = syntax` 的定位约束)、未来的 IDE language server。

如果你要看 token 流如何产出，继续读 `lexer-specification.md`。
如果你要看 CST 之上如何构建 Typed HIR，继续读 `semantic-model-specification.md`。
如果你要看 parser 失败如何走结构化诊断，继续读 `diagnostics-specification.md`。
如果你要看 source database 如何提供输入、unit 系统如何关联 file id，继续读
`compiler-pipeline-specification.md`。

## 这份规范要解决的核心问题

当前 parser 把"能产出 GreenTree 对象"当作交付标准，但下游需要的能力远不止此。
这份规范冻结五个长期被忽略的边界，让 parser 从一次性原型变成可以承担 IDE / 自举 /
增量编译的基础设施：

- **CST 完整性**：Green CST 必须能无损重建源码（含 trivia），不仅是语义骨架
- **错误恢复语义**：语法错误必须以 `gnkError` 节点形式显式出现在树中，并能继续
  解析，否则 IDE 在用户每次按键时都会拿到不完整的 CST
- **节点类型稳定性**：`TGreenNodeKind` 枚举可以增加新成员，但已稳定的节点语义
  不能在 minor 版本里改变
- **位置信息传递**：每个 CST 节点必须能精确指向源码 byte range，支持 span-based
  诊断和 IDE 高亮
- **语法覆盖范围**：明确哪些 Object Pascal 语法形式属于 v1 必须支持、哪些延后

## Green CST 是 parser 唯一的对外契约

parser 的输入是 `TLexerResult`（token 流），输出是一棵 `TGreenTree`。

Green CST 的格式约束：

- 每棵树有且只有一个 root node，其 `NodeKind` 对应源文件的顶层形式
  （`gnkProgram` / `gnkUnit` / `gnkLibrary` / `gnkPackage`）
- 每个 `TGreenNode` 至少包含 `NodeKind`、`ByteOffset`、`ByteLength`、`Text`
  四个字段，以及零或多个有序子节点
- 树中的节点按源序排列（同层子节点的 ByteOffset 严格递增）
- 任何语法错误都必须以 `gnkError` 节点出现在树中，而不是抛异常或返回 nil 树
- `TGreenTree.IsValid` 为 True 当且仅当 `DiagnosticsSink` 中无 error 级诊断

不在契约里的：

- 节点内部内存布局（arena / 独立堆分配 / 引用计数都允许）
- 子节点数组的扩容策略（实现细节）
- parser 内部的 lookahead 深度（只要满足性能契约即可）

## 顶层形式的 EBNF

```ebnf
compilation-unit  = program-unit | unit-unit | library-unit | package-unit

program-unit      = "program" identifier ";" [ uses-clause ]
                    block-declarations
                    "begin" statement-list "end" "."

unit-unit         = "unit" identifier ";"
                    "interface" [ uses-clause ] interface-declarations
                    "implementation" [ uses-clause ] implementation-declarations
                    [ initialization-section ]
                    [ finalization-section ]
                    "end" "."

library-unit      = "library" identifier ";" [ uses-clause ]
                    block-declarations
                    [ "begin" statement-list ] "end" "."

package-unit      = "package" identifier ";"
                    [ requires-clause ] [ contains-clause ]
                    "end" "."
```

## uses 子句

```ebnf
uses-clause       = "uses" use-entry { "," use-entry } ";"
use-entry         = identifier [ "in" string-literal ]
```

`in` 子句指定 unit 的物理文件路径，仅在 program 的 uses 中合法。parser 不做
语义校验（那是 sema 的事），但必须能正确切分 `in` 后的 string-literal。

## 声明区

```ebnf
block-declarations     = { declaration-section }
declaration-section    = var-section | const-section | type-section
                       | label-section | procedure-decl | function-decl

interface-declarations = { interface-decl }
interface-decl         = var-section | const-section | type-section
                       | procedure-header | function-header

implementation-declarations = { implementation-decl }
implementation-decl    = var-section | const-section | type-section
                       | procedure-decl | function-decl
```

### var 声明

```ebnf
var-section       = "var" var-decl { var-decl }
var-decl          = identifier-list ":" type-reference [ "=" expression ] ";"
identifier-list   = identifier { "," identifier }
```

### const 声明

```ebnf
const-section     = "const" const-decl { const-decl }
const-decl        = identifier [ ":" type-reference ] "=" expression ";"
```

### type 声明

```ebnf
type-section      = "type" type-decl { type-decl }
type-decl         = identifier "=" type-definition ";"

type-definition   = simple-type | structured-type | pointer-type
                  | string-type | procedural-type | class-type
                  | interface-type | enum-type | subrange-type
                  | set-type | file-type | type-alias

simple-type       = ordinal-type | real-type
structured-type   = record-type | array-type | object-type
pointer-type      = "^" type-reference
string-type       = "string" [ "[" expression "]" ]
procedural-type   = ( "procedure" | "function" ) [ formal-params ]
                    [ ":" type-reference ] [ "of" "object" ]
```

### record 类型

```ebnf
record-type       = "record" [ field-list ] "end"
                  | "packed" "record" [ field-list ] "end"
field-list        = field-decl { ";" field-decl } [ ";" variant-part ]
field-decl        = identifier-list ":" type-reference
variant-part      = "case" [ identifier ":" ] type-reference "of"
                    variant { ";" variant }
variant           = const-expression { "," const-expression } ":"
                    "(" [ field-list ] ")"
```

### array 类型

```ebnf
array-type        = "array" "[" index-type { "," index-type } "]"
                    "of" type-reference
                  | "array" "of" type-reference
                  | "array" "of" "const"
index-type        = ordinal-type | subrange-type
```

### class 类型（v1 基线）

```ebnf
class-type        = "class" [ class-heritage ]
                    { class-member-section }
                    "end"
                  | "class" "(" type-reference ")"
class-heritage    = "(" type-reference { "," type-reference } ")"
class-member-section = visibility-specifier { class-member }
visibility-specifier = "public" | "private" | "protected" | "published"
                     | "strict" "private" | "strict" "protected"
class-member      = field-decl ";"
                  | method-decl
                  | property-decl
```

### 枚举与子范围

```ebnf
enum-type         = "(" identifier { "," identifier } ")"
                  | "(" identifier "=" expression
                    { "," identifier "=" expression } ")"
subrange-type     = expression ".." expression
set-type          = "set" "of" ordinal-type
```

## 过程与函数声明

```ebnf
procedure-decl    = procedure-header ";" procedure-body ";"
function-decl     = function-header ";" function-body ";"

procedure-header  = "procedure" qualified-name [ formal-params ]
                    [ calling-convention ]
function-header   = "function" qualified-name [ formal-params ]
                    ":" type-reference [ calling-convention ]

qualified-name    = identifier [ "." identifier ]

procedure-body    = block | "forward" | external-directive
function-body     = block | "forward" | external-directive

block             = [ block-declarations ] "begin" statement-list "end"

external-directive = "external" [ string-literal ]
                     [ "name" string-literal ]
                   | "external" [ string-literal ]
                     [ "index" expression ]

calling-convention = "cdecl" | "stdcall" | "pascal" | "register"
                   | "safecall"
```

### 形参列表

```ebnf
formal-params     = "(" [ param-group { ";" param-group } ] ")"
param-group       = [ param-modifier ] identifier-list ":" type-reference
                  | [ param-modifier ] identifier-list
param-modifier    = "var" | "const" | "out" | "constref"
```

## 语句

```ebnf
statement-list    = [ statement { ";" statement } ]

statement         = [ label ":" ] simple-statement
                  | [ label ":" ] structured-statement

simple-statement  = assignment-statement
                  | procedure-call-statement
                  | goto-statement
                  | inherited-statement
                  | raise-statement

structured-statement = compound-statement
                     | conditional-statement
                     | loop-statement
                     | with-statement
                     | try-statement
```

### 赋值与调用

```ebnf
assignment-statement     = designator ":=" expression
                         | designator "+=" expression
                         | designator "-=" expression
                         | designator "*=" expression
                         | designator "/=" expression

procedure-call-statement = designator [ "(" argument-list ")" ]

designator               = identifier { designator-suffix }
designator-suffix        = "." identifier
                         | "[" expression-list "]"
                         | "^"
                         | "(" argument-list ")"

argument-list            = [ expression { "," expression } ]
```

### 条件语句

```ebnf
if-statement      = "if" expression "then" statement
                    [ "else" statement ]

case-statement    = "case" expression "of"
                    case-selector { ";" case-selector }
                    [ ";" ] [ "else" statement-list [ ";" ] ]
                    "end"
case-selector     = case-label { "," case-label } ":" statement
case-label        = expression [ ".." expression ]
```

### 循环语句

```ebnf
while-statement   = "while" expression "do" statement
repeat-statement  = "repeat" statement-list "until" expression
for-statement     = "for" identifier ":=" expression
                    ( "to" | "downto" ) expression "do" statement
for-in-statement  = "for" identifier "in" expression "do" statement
```

### 异常处理

```ebnf
try-statement     = try-except | try-finally
try-except        = "try" statement-list
                    "except" exception-handlers "end"
try-finally       = "try" statement-list
                    "finally" statement-list "end"
exception-handlers = exception-handler { ";" exception-handler }
                   | statement-list
exception-handler  = "on" [ identifier ":" ] type-reference "do" statement
```

### 其它结构语句

```ebnf
with-statement    = "with" expression { "," expression } "do" statement
raise-statement   = "raise" [ expression [ "at" expression ] ]
goto-statement    = "goto" label
inherited-statement = "inherited" [ identifier [ "(" argument-list ")" ] ]
```

## 表达式

```ebnf
expression        = simple-expression [ rel-op simple-expression ]
rel-op            = "=" | "<>" | "<" | ">" | "<=" | ">=" | "in" | "is" | "as"

simple-expression = [ sign ] term { add-op term }
add-op            = "+" | "-" | "or" | "xor"
sign              = "+" | "-"

term              = factor { mul-op factor }
mul-op            = "*" | "/" | "div" | "mod" | "and" | "shl" | "shr"

factor            = designator
                  | unsigned-constant
                  | "(" expression ")"
                  | "not" factor
                  | "@" factor
                  | set-constructor
                  | type-cast

unsigned-constant = integer-literal | real-literal | string-literal
                  | char-literal | "nil" | "true" | "false"

set-constructor   = "[" [ set-element { "," set-element } ] "]"
set-element       = expression [ ".." expression ]

type-cast         = type-reference "(" expression ")"
```

## CST 节点类型

nextPas parser 把 CST 节点分成六个互斥类别：

- **顶层节点**：`gnkProgram` / `gnkUnit` / `gnkLibrary` / `gnkPackage`。每棵树
  有且只有一个顶层节点作为 root
- **结构节点**：`gnkInterfaceSection` / `gnkImplementationSection` /
  `gnkBeginBlock` / `gnkEndBlock` / `gnkUsesClause` / `gnkUseEntry` /
  `gnkStatementList` / `gnkParameterList` / `gnkParameterDecl` / `gnkFieldList`
- **声明节点**：`gnkVarSection` / `gnkConstSection` / `gnkTypeSection` /
  `gnkVarDecl` / `gnkConstDecl` / `gnkTypeDecl` / `gnkProcedureDecl` /
  `gnkFunctionDecl` / `gnkForeignProcedureDecl` / `gnkClassDecl` /
  `gnkInterfaceDecl` / `gnkPropertyDecl` / `gnkMethodDecl`
- **语句节点**：`gnkIfStatement` / `gnkWhileStatement` / `gnkForStatement` /
  `gnkRepeatStatement` / `gnkWithStatement` / `gnkCaseStatement` /
  `gnkAssignmentStatement` / `gnkProcedureCallStatement` / `gnkGotoStatement` /
  `gnkBreakStatement` / `gnkContinueStatement` / `gnkExitStatement` /
  `gnkTryExceptStatement` / `gnkTryFinallyStatement` / `gnkRaiseStatement` /
  `gnkInheritedStatement` / `gnkForInStatement`
- **表达式节点**：`gnkIdentifier` / `gnkStringLiteral` / `gnkIntegerLiteral` /
  `gnkRealLiteral` / `gnkCharLiteral` / `gnkBinaryExpression` /
  `gnkUnaryExpression` / `gnkDotAccess` / `gnkArrayAccess` /
  `gnkFunctionCall` / `gnkDereference` / `gnkAddressOf` / `gnkSetConstructor` /
  `gnkTypeCast` / `gnkRangeExpression`
- **类型节点**：`gnkRecordType` / `gnkArrayType` / `gnkPointerType` /
  `gnkClassType` / `gnkInterfaceType` / `gnkEnumType` / `gnkSetType` /
  `gnkSubrangeType` / `gnkProceduralType` / `gnkStringType` / `gnkFileType`
- **错误节点**：`gnkError`。任何无法正确解析的片段都必须产出此节点

### 节点子结构约束

每种节点对子节点的数量和类型有明确约束。以下列出关键节点的子结构：

| 节点类型                    | 子节点结构                                                    |
| --------------------------- | ------------------------------------------------------------- |
| `gnkProgram`                | identifier, [uses-clause], {decl}, begin-block                |
| `gnkUnit`                   | identifier, interface-section, implementation-section, end     |
| `gnkIfStatement`            | condition-expr, then-stmt, [else-stmt]                        |
| `gnkWhileStatement`         | condition-expr, body-stmt                                     |
| `gnkForStatement`           | var-ident, start-expr, end-expr, body-stmt                    |
| `gnkRepeatStatement`        | statement-list, condition-expr                                |
| `gnkCaseStatement`          | selector-expr, {case-selector}, [else-stmts]                  |
| `gnkAssignmentStatement`    | [rhs-expr]（Text 字段存 LHS 标识符名）                       |
| `gnkProcedureCallStatement` | {argument-expr}（Text 字段存被调用名）                        |
| `gnkBinaryExpression`       | left-expr, right-expr（Text 字段存操作符 lexeme）             |
| `gnkUnaryExpression`        | operand-expr（Text 字段存操作符 lexeme）                      |
| `gnkFunctionCall`           | callee-ident, {argument-expr}                                 |
| `gnkVarDecl`                | [type-node]（Text 字段存变量名）                              |
| `gnkProcedureDecl`          | [param-list], [begin-block]（Text 字段存过程名）              |
| `gnkFunctionDecl`           | [param-list], [return-type], [begin-block]（Text 字段存函数名）|
| `gnkRecordType`             | {field-decl}                                                  |
| `gnkArrayType`              | [index-type], element-type                                    |
| `gnkClassType`              | [heritage], {member-section}                                  |

## 错误恢复策略

当前 parser 在遇到语法错误时倾向于提前退出（返回 False 或 nil）。本规范冻结的
策略要求 parser 在错误后继续解析，产出尽可能完整的 CST：

### 恢复原则

1. **永不崩溃**：任何输入（包括空文件、纯垃圾字节）都必须产出一棵 GreenTree，
   不抛异常
2. **错误节点标记**：无法解析的片段包装为 `gnkError` 节点，保留原始 byte range
3. **同步点恢复**：跳过 token 直到遇到同步集合中的 token，然后恢复正常解析
4. **最大化有效节点**：错误恢复的目标是让错误之后的正确代码仍然能被正确解析

### 同步集合定义

不同上下文使用不同的同步集合：

| 上下文                | 同步集合                                                              |
| --------------------- | --------------------------------------------------------------------- |
| 顶层声明              | `var`, `const`, `type`, `procedure`, `function`, `begin`, `end`, EOF  |
| 语句列表              | `;`, `end`, `until`, `else`, `finally`, `except`, EOF                 |
| 表达式                | `;`, `)`, `]`, `,`, `end`, `then`, `do`, `of`, `to`, `downto`, EOF   |
| 形参列表              | `)`, `;`, EOF                                                         |
| record 字段           | `;`, `end`, EOF                                                       |
| class 成员            | `public`, `private`, `protected`, `published`, `end`, EOF             |

### 冻结的诊断码（命名空间 `parser.*`）

- `parser.syntax-error`：通用语法错误（expected X but found Y）
- `parser.unclosed-block`：`begin` 无匹配 `end`
- `parser.unclosed-paren`：`(` 无匹配 `)`
- `parser.unclosed-bracket`：`[` 无匹配 `]`
- `parser.missing-semicolon`：缺少分号
- `parser.missing-identifier`：期望标识符
- `parser.unexpected-eof`：意外的文件结束
- `parser.duplicate-section`：重复的 interface/implementation 段
- `parser.invalid-root-keyword`：文件不以 program/unit/library/package 开头

## 位置信息契约

每个 `TGreenNode` 必须携带 `(ByteOffset, ByteLength)` 二元组：

- `ByteOffset`：0-based，节点第一个 token 的第一字节在源文件中的字节偏移量
- `ByteLength`：节点覆盖的总字节数（从第一个 token 首字节到最后一个 token 末字节）

当前实现中 `ByteLength` 大量为 0，这是 P2 缺陷。本规范要求：

- 叶节点（identifier、literal）的 `ByteLength` 必须等于其 lexeme 的字节长度
- 复合节点的 `ByteLength` 应当覆盖从首子节点到末子节点的完整 span
- `gnkError` 节点的 `ByteLength` 必须覆盖被跳过的所有 token

精确的 span 信息是 IDE 高亮、诊断 underline、重构 rename 的基础。

## v1 语法覆盖范围

本规范把 Object Pascal 语法分为三个优先级：

### P0：v1 必须完整支持

- program / unit / library 顶层形式
- uses 子句（含 `in` 路径）
- var / const / type 声明段
- 基本类型：integer types, real types, string, char, boolean, pointer
- record 类型（含 variant part）
- array 类型（静态、动态、open array）
- enum 类型、subrange 类型、set 类型
- procedure / function 声明与实现（含 forward）
- 形参列表（var / const / out 修饰符）
- 所有语句：if/while/for/repeat/with/case/goto/break/continue/exit
- 复合语句（begin..end）
- 赋值（含 +=/-=/*=//= 复合赋值）
- 过程调用
- 表达式（完整优先级：关系 > 加法 > 乘法 > 一元 > 后缀）
- external 声明（cdecl + external 'lib' name 'sym'）
- 编译器指令（作为 trivia 或结构 token 透传）

### P1：v1 应当支持（阻塞 stage1 自举）

- class 类型（含继承、visibility、method、property）
- interface 类型（含 GUID、method）
- constructor / destructor
- try..except / try..finally
- raise 语句
- inherited 调用
- as / is 操作符
- for..in 循环
- 方法限定名（`TFoo.Bar`）
- operator overloading 声明
- class method / class property
- initialization / finalization 段

### P2：v1 可延后

- generics（`TList<T>`）
- anonymous functions / closures
- advanced records（methods on record）
- helper types（class helper / record helper）
- inline 变量声明（`var X := 42;`）
- attributes（`[Attribute]`）

### P3：不在 v1 范围

- Objective-C 桥接语法
- C++ class 桥接
- 平台特定的 asm 块内部解析（`asm..end` 作为不透明块处理）

## 性能契约

第一阶段冻结的性能约束：

- 递归下降，无回溯。parser 在任何决策点的 lookahead 不超过 2 个 token
  （当前实现的 foreign procedure decl 使用 lookahead cursor 是允许的特例，
  但必须在常数步内决定）
- 时间复杂度 `O(t)`，t 为 token 数
- 空间复杂度 `O(n)`，n 为 CST 节点数。节点数与 token 数线性相关
- 子节点数组的扩容必须使用 capacity / length 分离策略
- 吞吐量基线：在调试构建下不低于 20 MB/s（按 source 字节计），release 构建
  不低于 50 MB/s。这两个数字将来由独立的 parser-bench gate 持续守护；gate 使用
  process CPU time 计量，并投影 `parser-bench-timing-source=process-cpu`，避免宿主负载
  把验证结果误判为 parser 退化

当前实现的性能反模式（`SetLength(FChildren, n+1)` 每次 O(n) 拷贝）属于 P3 缺陷。

## 接口稳定性

`TGreenTree` 类的公开 API 在 v1 阶段冻结：

- `function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId): TGreenTree`
- `property RootKind: TGreenRootKind`
- `property DeclaredName: string`
- `property NodeCount: LongInt`
- `property IsValid: Boolean`
- `property RootNode: TGreenNode`
- `function InterfaceUseCount / InterfaceUseAt`
- `function ImplementationUseCount / ImplementationUseAt`

`TGreenNode` 的公开 API 在 v1 阶段冻结：

- `property NodeKind: TGreenNodeKind`
- `property ByteOffset: LongInt`
- `property ByteLength: LongInt`
- `property Text: string`
- `function ChildCount: LongInt`
- `function ChildAt(const AIndex: LongInt): TGreenNode`

新字段（如 `Parent` 指针、`Flags` 位域）只能新增，不能修改已有字段语义。

未来的非破坏性扩展位（**不在 v1 契约中**）：

- 增量重解析接口（编辑后只重建受影响的子树）
- Red CST（带 parent 指针的 immutable facade，用于 IDE 导航）
- CST → source text 的无损重建（依赖 trivia 模型完整落地）

## 与 Lexer 规范的边界

parser 消费 lexer 产出的 token 流，但不对 lexer 内部行为做假设：

- parser 通过 `TLexerResult.TokenAt(index)` 访问 token，不直接操作 lexer 状态
- parser 不跳过 `tkCompilerDirective` token——它们作为结构 token 出现在 token 流中，
  parser 当前忽略它们（不建 CST 节点），但不消费它们的语义
- parser 不处理 trivia——trivia 附着在 token 上，由 CST → Red CST 转换时重建
- `tkError` token 在 parser 看来等同于非法输入，触发错误恢复

## 与 Diagnostics 规范的边界

parser 通过 `TDiagnosticsSink` 报告所有语法错误：

- Phase 固定为 `'syntax'`
- 每条诊断必须包含 `DiagnosticCode`（`parser.*` 命名空间）、`FileId`、
  `ByteOffset` 和人类可读消息
- parser 不决定诊断的严重级别策略——所有语法错误都以 `EmitError` 报告
- parser 不做诊断去重——如果同一位置触发多次错误恢复，每次都独立报告

## 与 AST Facade 的边界

`np_ast_facade.pas` 是 Green CST 的类型化视图层：

- AST facade 不修改 Green CST，只提供类型安全的访问器
- AST facade 可以跳过 `gnkError` 节点，只暴露有效节点
- AST facade 负责把 `Text` 字段解码为语义值（如 string literal 的 escape 处理）
- parser 不为 AST facade 预计算任何派生数据

## 当前实现与规范的差距（缺陷清单）

| 缺陷 ID | 优先级 | 描述                                                    |
| -------- | ------ | ------------------------------------------------------- |
| P-001    | P0     | 缺少 case 语句完整解析                                  |
| P-002    | P0     | 缺少 for..in 循环                                       |
| P-003    | P1     | 缺少 class 类型解析                                     |
| P-004    | P1     | 缺少 interface 类型解析                                 |
| P-005    | P1     | 缺少 try..except / try..finally                         |
| P-006    | P1     | 缺少 raise 语句                                         |
| P-007    | P1     | 缺少 inherited 调用                                     |
| P-008    | P1     | 缺少 constructor / destructor 声明                      |
| P-009    | P1     | 缺少 initialization / finalization 段                   |
| P-010    | P0     | 错误恢复不完整——遇错即退出而非插入 gnkError 继续        |
| P-011    | P2     | ByteLength 大量为 0                                     |
| P-012    | P2     | 子节点数组无 capacity 预分配                            |
| P-013    | P0     | designator 链不完整（缺少 `.field`、`[index]`、`^`）    |
| P-014    | P1     | property 声明                                           |
| P-015    | P1     | operator overloading                                    |
| P-016    | P0     | 缺少 set constructor `[a, b..c]`                        |
| P-017    | P0     | 缺少 type cast `Integer(x)`                             |
| P-018    | P1     | 缺少 uses..in 路径语法                                  |
| P-019    | P3     | 子节点扩容 O(n) 性能反模式                              |
| P-020    | P0     | 缺少 label 声明段                                       |
