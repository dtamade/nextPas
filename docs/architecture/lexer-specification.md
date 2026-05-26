# nextPas Lexer 规范

这份规范定义 nextPas 词法分析器（`compiler/syntax/np_lexer.pas`）的契约边界。
它回答的不是 "lexer 内部用什么算法"，而是 "lexer 对其它层承诺产出什么、不承诺什么、
何时应当停下"。

这份文档承接 `compiler-specification.md` 对 `syntax/np_lexer` 模块的职责定义，并细化
`compiler-pipeline-specification.md` 中 token 流的位置。它的下游消费者包括：
parser (`syntax/np_green_tree.pas`)、AST facade (`syntax/np_ast_facade.pas`)、
诊断 sink (`diagnostics/np_diagnostics_sink.pas`，参见 `diagnostics-specification.md` 中
`Phase = lexer` 的定位约束)、未来的 IDE language server。

如果你要看 token 流之上如何聚合 CST，继续读 `compiler-specification.md` 的 syntax 章节。
如果你要看哪些 lexer 失败应该走结构化诊断而不是悄悄丢弃，继续读 `diagnostics-specification.md`。
如果你要看 source database 如何提供输入字节、unit 系统如何关联 file id，继续读
`compiler-pipeline-specification.md`。

## 这份规范要解决的核心问题

当前 lexer 把"能产出 token 数组"当作交付标准，但下游需要的能力远不止此。这份规范冻结
四个长期被忽略的边界，让 lexer 从一次性玩具变成可以承担 IDE / 自举 / 增量编译的基础设施：

- **位置信息精度**：每个 token 必须能精确指向人类可读的 (line, column)，不仅是 byte
  offset
- **错误恢复语义**：未闭合的 string、注释、非法字符必须以 `tkError` token 形式显式出现，
  并能继续扫描，否则 IDE 在用户每次按键时都会拿到不完整的 token 流
- **trivia 处理**：whitespace 和注释必须可以被结构化保留，否则 IDE 重构 / 文档关联 /
  格式化都无法做
- **token 流稳定性**：lexer 输出可以增加新字段、新 token 种类，但已稳定的 lexeme/位置
  语义不能在 minor 版本里改变

## token 流是 lexer 唯一的对外契约

lexer 的输入是字节序列（来自 source database），输出是按源序排列的 token 流，
以 `tkEOF` token 结尾。

token 流的格式约束：

- 每个 token 是一个 `TToken` 记录，至少包含 `Kind`、`Lexeme`、`ByteOffset`、
  `Line`、`Column` 五个字段
- token 之间是源序的（按 ByteOffset 严格递增，除非两个 token 共享同一 offset 是
  bug）
- 末尾必须有且只有一个 `tkEOF` token
- 任何错误都必须以一个或多个 `tkError` token（详见错误恢复一节）出现在流里，而不是抛
  异常或返回空数组

不在契约里的：

- 词法回溯接口（lexer 是单遍的，下游想多次访问 token 用的是 token 流数组本身）
- token 内部内存结构（lexeme 是引用计数 string 还是 slice 是实现细节）
- 关键字识别使用的内部表示（hash table / trie / if-else 都允许）

## 五大类 token

nextPas lexer 把 token 分成五个互斥类别：

- **关键字 token**：`tkProgramKeyword` ... `tkRequiresKeyword` 等。每个 Pascal 关键字
  对应一个独立 kind。识别规则：先按 identifier 切出 lexeme，再用大小写不敏感比对
  关键字表
- **identifier token**：`tkIdentifier`。所有不属于关键字的标识符落入此类
- **字面量 token**：`tkIntegerLiteral` / `tkRealLiteral` / `tkCharLiteral` /
  `tkStringLiteral`
- **操作符与标点 token**：`tkSemicolon`、`tkAssign`、`tkPlus` 等
- **结构 token**：`tkCompilerDirective`、`tkEOF`、`tkError` 等

`tkUnknown` **不是合法的产出**——当前实现把它作为"未识别字符的回退"使用，是历史包袱。
本规范要求这个 kind 在错误恢复落地后被 `tkError` 替换。

`True` 与 `False` **不是关键字**。Pascal 标准把它们定义为预定义的 boolean identifier。
当前实现把 `True` / `False` 单独识别成 `tkTrueKeyword` / `tkFalseKeyword` 是 bug，本
规范要求它们以 `tkIdentifier` 形式产出，由 sema 层根据预定义符号表解析。

## 字面量的完整 EBNF

`tkIntegerLiteral` 必须接受以下四种形式：

```ebnf
integer-literal  = decimal-int | hex-int | octal-int | binary-int
decimal-int      = digit { digit }
hex-int          = "$" hex-digit { hex-digit }
octal-int        = "&" octal-digit { octal-digit }
binary-int       = "%" binary-digit { binary-digit }
digit            = "0" | "1" | ... | "9"
hex-digit        = digit | "A".."F" | "a".."f"
octal-digit      = "0" | "1" | ... | "7"
binary-digit     = "0" | "1"
```

当前实现只覆盖 `decimal-int` 和 `hex-int`。`octal-int` / `binary-int` 缺失，是 P1 缺陷。

`tkRealLiteral` 形式：

```ebnf
real-literal     = digit { digit } "." digit { digit } [ exponent ]
                 | digit { digit } exponent
exponent         = ("e" | "E") [ "+" | "-" ] digit { digit }
```

`x.y` 中如果 `.` 后是另一个 `.`（例如 `1..3`），`.` 必须按 `tkDotDot` 切分而不是吃进
real-literal——当前实现在这里是正确的。

`tkCharLiteral` 是 Pascal 字符代码字面量：

```ebnf
char-literal     = char-code { char-code | quoted-string }
char-code        = "#" decimal-int
                 | "#" "$" hex-int-body
                 | "^" control-char
control-char     = uppercase-letter | "@" | "[" | "\" | "]" | "^" | "_"
quoted-string    = "'" { quoted-string-char | "''" } "'"
```

当前实现支持 `#65` 和 `#$41`，**不支持 `^A` 控制字符语法**，**不支持
`'Hello'#10'World'` 形式的字面量拼接**。这两条都是 P1 缺陷。

`tkStringLiteral` 是 Pascal 单引号字符串：

```ebnf
string-literal   = quoted-string { char-code | quoted-string }
```

注意：lexer 必须把 `'a'#10'b'` 识别为**单一** `tkStringLiteral`，而不是切成三个 token。
这与 `char-literal` 共享 EBNF 重叠：开头是 `'` 走 string-literal，开头是 `#` 或 `^` 走
char-literal，但两种 token 都允许后续追加 char-code 或 quoted-string 段。

## 注释与编译器指令

nextPas 接受三种注释语法：

- `{ ... }` — brace 注释
- `(* ... *)` — paren-star 注释
- `// ...` — 行注释（终止于 LF/CR/EOF）

如果 `{` 或 `(*` 紧跟一个 `$`，整个注释体替换为 `tkCompilerDirective` token，lexeme
保留完整原文（含起止符号 `{$ ... }` 或 `(*$ ... *)`）。

**嵌套注释**：FPC 的 `{$NESTEDCOMMENTS ON}` 模式下 `{ a { b } c }` 是合法的（`{ b }`
被当作内层注释）。当前实现不支持嵌套，是 P1 缺陷。本规范要求嵌套注释在默认模式下
启用。

跨行注释必须正确更新行号——见下一节位置信息契约。

## 位置信息契约

每个 token 必须携带 `(ByteOffset, Line, Column)` 三元组，意义如下：

- `ByteOffset`：0-based，token 第一字节在源文件中的字节偏移量
- `Line`：1-based 源行号
- `Column`：1-based **字节列号**。column 1 表示 "源文件第一字节" 或 "最近一次行终止符
  之后的第一字节"

行终止符识别规则：

- LF（`#10`）作为单字节行终止符
- CR（`#13`）作为单字节行终止符
- CRLF（`#13#10`）作为单一行终止符（不是两次换行）
- 出现在 brace 注释、paren-star 注释、行注释、字符串字面量内部时，同样按上述规则
  累加行号

字节列号的限制：UTF-8 多字节字符按字节宽度计算列。这意味着对纯 ASCII 源码（当前所有
fixture 与绝大多数实际 Pascal 源码），字节列等于视觉列；对含 multi-byte UTF-8 字符的
源码，字节列大于视觉列。这是当前实现的简化策略，也是 P3 缺陷的一部分。Visual column
等于字符宽度的契约推迟到 Unicode identifier 一并落地的批次。

`tkEOF` 的位置是 "最后一字节之后的位置"，即 `ByteOffset = Length(source)`，`Line` 与
`Column` 反映源末尾。

## 错误恢复策略

当前 lexer 没有错误恢复机制。本规范冻结的策略如下：

任何无法切出合法 token 的输入都必须产出一个 `tkError` token，并在 `Lexeme` 字段中
保留导致错误的字节序列（用于诊断引用），同时让 `DiagnosticsSink` 收到一条
`Phase = lexer` 的结构化诊断（参见 `diagnostics-specification.md` 中
`PrimarySpan` 与 `DiagnosticCode` 的约束）。

冻结的诊断码（命名空间 `lexer.*`）：

- `lexer.unterminated-string-literal`
- `lexer.unterminated-brace-comment`
- `lexer.unterminated-paren-star-comment`
- `lexer.unterminated-compiler-directive`
- `lexer.invalid-char-code`
- `lexer.invalid-control-char`
- `lexer.invalid-numeric-literal`
- `lexer.illegal-character`

错误恢复点的语义：

- **未闭合 string**：扫到 LF / CR 或 EOF 即终止字符串，发出 `tkError`，恢复点是
  下一行第一字节
- **未闭合 brace 注释**：扫到 EOF 即终止，发出 `tkError`，恢复点是 EOF
- **未闭合 paren-star 注释**：同上
- **未闭合 compiler-directive**：同 brace 注释处理
- **非法 char code**（`#` 后非 digit/`$` 或 `^` 后非合法 control-char）：发出 `tkError`，
  恢复点是 `#` 或 `^` 后第一字节
- **非法数字**（如 `$` 后无 hex-digit）：发出 `tkError`，恢复点是非法首字节后
- **非法字符**（不属于任何已知 token 起始字符）：发出 `tkError`，恢复点是该字节后

`tkError` 的产出**不能**让后续扫描静默回退到 `tkUnknown`。`tkUnknown` 在错误恢复
落地后从 token 集合中移除。

## Trivia 处理

当前 lexer 把所有 whitespace 和注释静默吞掉，这意味着：

- IDE 重构（rename）会丢失原始格式
- 文档注释（`{** ... *}` / `/// ...` / `//! ...`）无法关联到下一个声明
- `gofmt` 风格的格式化工具无法基于 token 流重建源码

本规范冻结的 trivia 模型：

- whitespace（spaces, tabs, line terminators）和注释统称 trivia
- trivia 不作为独立 token 出现在主 token 流里
- 每个非 trivia token 携带两份 trivia slice：`LeadingTrivia`（位于该 token 之前、
  上一个非 trivia token 之后的连续 trivia）和 `TrailingTrivia`（位于该 token 之后、
  下一个非 trivia token 之前、且与该 token 在同一逻辑行的 trivia）
- 跨越行终止符的 trivia 一律归入下一 token 的 `LeadingTrivia`
- `tkCompilerDirective` 不是 trivia——它是结构 token

trivia slice 的形式（以 byte range 为主，原文延迟构造）：

```pascal
TTriviaPiece = record
  Kind: TTriviaKind;          // whitespace / line-comment / brace-comment / paren-star-comment
  ByteOffset: LongInt;
  Length: LongInt;
end;
```

trivia 是 P2 缺陷。当前实现完全没有 trivia 模型，本规范要求在 trivia 落地之前，
任何 IDE 集成工作（rename、format、文档关联）暂缓。

## 编码契约

第一阶段冻结：

- **输入编码**：UTF-8。源数据库读取字节后不做编码转换
- **BOM 处理**：源文件开头如果是 UTF-8 BOM（`EF BB BF`），lexer 必须跳过这 3 个字节
  且不影响行号与列号（首字节仍报告 line=1, column=1）
- **identifier 字符集**：当前为 ASCII（`A-Z` / `a-z` / `_` / `0-9`）。Unicode
  identifier 推迟到独立批次，与字节列号 / 视觉列号 / Unicode 规范化一并处理
- **字符串字面量字节**：原样保留。lexer 不解码字符串内容；Pascal-escape 的解释由
  sema 层负责

不接受的编码：UTF-16、UCS-4、ANSI 代码页。源文件出现 BOM 之外的 0xFE / 0xFF 等会
被识别为 `lexer.illegal-character`。

## 性能契约

第一阶段冻结的性能约束：

- 单遍扫描，无回溯。任何在 token 内部使用的 lookahead 不超过常数（当前实现的 `..`、
  `<>`、`<=`、`>=`、`+=`、`-=` 等都是 1 字符 lookahead）
- 时间复杂度 `O(n)`，n 为源字节数
- 空间复杂度 `O(t)`，t 为产出 token 数；token 数组的扩容必须使用 capacity / length
  分离策略，避免每次 `SetLength(arr, n+1)` 触发 `O(n)` 拷贝
- 吞吐量基线：在调试构建下不低于 50 MB/s（按 source 字节计），release 构建不低于
  100 MB/s。这两个数字属于稳定 perf 环境里的 release 目标；当前 `verify-local` 的
  `lexer-bench` 是保守 smoke floor，不替代正式 perf gate
- bench 计量必须使用 process CPU time，并投影 `lex-bench-timing-source=process-cpu`，避免宿主
  调度等待把验证结果误判为 lexer 退化

当前实现的两条性能反模式（`Lexeme + ASourceText[i]` 反复 string 分配，`SetLength(FTokens, n+1)`
每 token O(n) 拷贝）属于 P3 缺陷。

## 接口稳定性

`TLexerResult` 类的公开 API 在 v1 阶段冻结：

- `constructor Create(const ASourceText: string)`：单次词法化，参数为已读入内存的
  源字节
- `function TokenCount: LongInt`
- `function TokenAt(const AIndex: LongInt): TToken`：越界访问返回 `tkEOF` 占位

`TToken` 的字段在 v1 阶段冻结：`Kind`、`Lexeme`、`ByteOffset`、`Line`、`Column`。
新字段（如 `LeadingTrivia` / `TrailingTrivia`）只能新增，不能修改已有字段语义。

未来的非破坏性扩展位（**不在 v1 契约中**）：

- 增量重词法化接口（IDE 编辑器只改一行后不应重扫整个文件）
- 多份并发 lexer 实例（语言服务器的批量分析场景）
- 流式 lexer（边读边产 token，避免源全部进内存）

## 演进路线

将 lexer 从当前状态推进到符合本规范的目标状态需要的批次（按优先级）：

1. **B1 ✅**：行号 / 列号字段（已落地，commit `dbc928d`）
2. **B2 ✅**：本规范文档（即本文）
3. **B3**：True / False 改为 identifier，移除 `tkTrueKeyword` / `tkFalseKeyword`
4. **B4**：错误恢复 + `tkError` + 8 条 `lexer.*` 诊断码
5. **B5**：BOM 处理
6. **B6**：字符串字面量拼接 / `^A` 控制字符 / `&oct` / `%bin` 数字
7. **B7**：嵌套注释
8. **B8**：trivia 模型（`LeadingTrivia` / `TrailingTrivia`）
9. **B9**：性能修复（capacity/length 分离 / lexeme slice / 关键字 hash）
10. **B10**：lexer-bench gate（吞吐量基线）
11. **B11**（不在 v1）：Unicode identifier + 视觉列号

每个批次都必须以 `bash build/verify_local.sh` 全绿收尾，对应的 spec 段落更新与
golden file 一并提交。

## 不在 v1 范围内的能力

明确推迟到 v2 的能力：

- 增量重词法化（IDE 集成需要时再做）
- 多编码源码（出 Linux 时再做）
- Unicode identifier（产品阶段再做）
- 流式 / 异步 lexer
- 词法宏（FPC 没有，nextPas 也不规划）

明确**不做**的能力：

- UTF-16 源码
- 词法层条件编译消化（`{$IFDEF}` 由更上层 directive evaluator 处理，lexer 只产出
  `tkCompilerDirective`）

## 这份规范如何执行

每次修改 lexer 都必须遵循以下顺序：

1. **更新本规范**：先描述新行为
2. **更新 golden file**：先表达期望（在 `tests/lexer/*.tokens` 中改预期，不必先有
   实现）
3. **修改实现**：让实现产出与新 golden 一致
4. **`bash build/verify_local.sh` 全绿**：lexer-conformance gate 验证
5. **commit**：spec 改动、golden 改动、实现改动、相关 fixture 增改在同一 commit

这套流程让 lexer 永远以 spec 为先，避免实现与意图脱节。
