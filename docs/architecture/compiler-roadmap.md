# nextPas 编译器路线图

用这份路线图把 nextPas 的编译器主线单独收紧出来。它回答的不是整个产品最终会长成什么，
也不是 `stage0 -> stage1 -> stage2` 的 bootstrap ownership，而是：

- 编译器能力应该按什么顺序接管
- 哪些边界必须先冻结
- 哪些 promotion gate 通过后，下一段才允许打开

如果你要看 nextPas 作为整套开发环境的长期产品顺序，继续读 `master-roadmap.md`。
如果你要看谁来拥有构建路径，继续读 `bootstrap-roadmap.md`。如果你要看当前 rolling
window 里的批次怎样映射到这六段，继续读
`../plans/2026-03-24-nextpas-master-roadmap-plan.md` 里的“用编译器路线图看当前批次”。
这份文档只负责 compiler execution spine。

## 先把这份路线图的职责说清

这份路线图继续受这些已接受事实约束：

- Linux x86_64 仍是当前唯一宿主与目标基线。
- FreePascal 仍是当前 `stage0` 宿主工具链。
- 第一阶段不发明新 Pascal 语法。
- `ABI compatibility is deferred`。
- 文档、tests、harness、smoke 与 verification evidence 必须一起推进。

因此，这份路线图不会把 GUI、IDE、package manager 或 language service 写成编译器计划本身，
也不会把“更丰富的 transcript”误当成比 `syntax`、`resolution`、`sema` 更高的近期优先级。

## 用一条编译器主线看 nextPas

nextPas 当前推荐的编译器推进顺序如下：

```text
Compiler execution spine:
  Control Surface and Session Foundation
    -> Syntax Frontend
    -> Unit Resolution and Semantic Core
    -> Typed HIR / MIR / Backend / Toolchain Boundary
    -> Target / Cross / LLVM / C Interop
    -> Workspace and Developer Tooling Integration
```

这里的重点不是把每个专题都塞进一张表，而是确保编译器真正依赖的拥有关系按顺序收口。

## 1. Control Surface and Session Foundation

这一段的目标，是把编译器先收成一个可调用、可验证、可留证的受控系统，而不是一串 helper。

这一段至少要冻结这些事实：

- `nextpas build` 是 compiler-facing 的正式公开入口。
- `CompilationSession` 或等价对象是一轮编译的统一拥有者。
- `Source database`、target facts、diagnostics sink 与 compilation options 有明确所有者。
- build/test/verify 的结果能稳定进入 machine-readable envelope，而不是靠 shell 文本猜测。

进入下一段前，这一段的 promotion gate 至少包括：

- build/test/verify 三条最小命令面都有稳定 envelope。
- session skeleton 已真实落地，不依赖新的全局 mutable singleton。
- 编译输入、target facts 与 diagnostics 汇聚面已经能被同一条编译路径稳定拥有。

出现这些情况时必须回退：

- source/target/diagnostics 重新漂回全局状态。
- 命令成功或失败又需要依赖文本抓取来判断。
- 后续层必须绕过 session 才能工作。

## 2. Syntax Frontend

这一段的目标，是把源码前端收成现代、可分层的结构，而不是继续沿用历史平铺解析习惯。

这一段至少要冻结这些事实：

- `Source database -> Lexer -> Green CST -> AST facade` 是唯一推荐的前端主骨架。
- 源文本进入 session 后不再被原地修改。
- `Green CST` 是 immutable 结构，AST 只是 facade，不持有第二份树所有权。
- 词法和语法失败会进入结构化 diagnostics，而不是停留在 CLI 文本输出。

进入下一段前，这一段的 promotion gate 至少包括：

- 最小 lexer、green tree 与 AST facade skeleton 已能对 smoke 输入稳定工作。
- 语法错误已经能形成结构化 failure kind，并被 tests/snapshots 长期消费。
- 前端数据结构的生命周期边界已经可解释，而不是“以后再整理”。

出现这些情况时必须回退：

- `syntax` 直接回写语义层状态。
- 语法树被重复物化成多份长期对象图。
- parser failure 只能通过命令失败字符串观察。

## 3. Unit Resolution and Semantic Core

这一段的目标，是把 nextPas 从“有前端壳”推进到“有真正 compiler core”。

这一段至少要冻结这些事实：

- `UnitId`、`ResolvedUnit`、`SearchPathSet` 与 `UnitGraph` 是 unit/module 行为的正式真相。
- `Typed HIR`、symbol graph、type graph 与结构化 diagnostics 开始成为语义层真相。
- interface / implementation、missing unit、ambiguous unit、unit cycle、duplicate import
  都进入正式失败类别。
- 可观察正确性在 `sema` 层被决定，不把语义结论下沉到 backend 猜测。

进入下一段前，这一段的 promotion gate 至少包括：

- name resolution 结果进入 `UnitGraph`，不再只是路径拼接副作用。
- 语义失败稳定进入 diagnostics sink，并对齐 `compiler-fail` 与 `diagnostics` 测试桶。
- `Typed HIR` 已开始承接真正的语义结论，而不是只做中间命名占位。

出现这些情况时必须回退：

- unit 解析重新退回“多扫几个目录再猜”的路径习惯。
- backend 或 runtime 需要重新猜 unit/init/semantic facts。
- 语义错误直到 `MIR` 或 toolchain 阶段才第一次变得可见。

## 4. Typed HIR / MIR / Backend / Toolchain Boundary

这一段的目标，是把编译器下游从隐式副作用拆成显式 contract。

这一段至少要冻结这些事实：

- `Typed HIR -> MIR -> Codegen adapter -> target-aware output path` 是正式下游链路。
- backend 只消费 `MIR + TargetFacts + output intent`。
- assembler、linker、archiver 与 resource tool 属于独立 orchestration 层。
- artifact plan、tool invocation plan、status event、build trace 都是显式结果。

进入下一段前，这一段的 promotion gate 至少包括：

- `MIR` 已经成为正式 backend input contract。
- toolchain failure 拥有稳定分类和 attribution。
- object / executable / installed unit artifact 的落点不再依赖目录扫描副作用。

出现这些情况时必须回退：

- `MIR` 重新承载前端语义判断。
- backend 开始拥有第二套 target policy。
- toolchain failure 又被压平成“构建失败”这一类模糊错误。

## 5. Target / Cross / LLVM / C Interop

这一段的目标，是在不推翻现有主骨架的前提下，把 target-aware compilation 收成统一 contract。

这一段至少要冻结这些事实：

- `HostFacts + TargetFacts + ToolchainBinding + Sysroot` 是统一主键。
- LLVM backend 只是 `Codegen adapter` 的一个 specialization，而不是第二套前端。
- calling convention、external symbol、library binding 与 link ordering 属于统一 foreign contract。
- native backend 与 LLVM backend 消费同一套 `MIR` 和 target facts。

当前 reality（截至 2026-05-17）：LLVM 路径已经从 skeleton 推进到 MIR-driven 闭环，
sema 已具备整数常量表达式编译期折叠、const 标识符引用解析、单赋值变量常量传播、
多参数 string-literal `WriteLn` 捕获与 `WriteLn(int-const)` 编译期格式化能力。
`compiler/syntax/np_green_tree.pas` 的 procedure-call 解析器已支持逗号分隔多参数列表。
`compiler/sema/np_semantic_analyzer.pas` 的 `WalkHaltCalls` 在遇到 `WriteLn`/`Write`
时迭代所有参数：`gnkStringLiteral` 经 `DecodePascalStringLiteral` 解码（`''` → `'`）
后追加；可被 `EvaluateIntegerConstant` 折叠的整数表达式经 `IntToStr` 追加；`WriteLn`
在尾部追加 `\n`，最终拼成单个 `'write-call'` HIR 节点。`EvaluateIntegerConstant` 在
sema 层折叠 `gnkIntegerLiteral` / `gnkIdentifier`(先查 const 表，再 fallback 到
var-init 表) / `gnkUnaryExpression`(+/-) / `gnkBinaryExpression`(+/-/*/div/mod)；
`ProcessConstSection` 为每个 `gnkConstDecl` 折叠并注册到 const 表；
`WalkAssignmentStatements` 在通过类型检查后，对 RHS 调用 `EvaluateIntegerConstant`，
若可折叠则把 LHS 名字 + 折叠值注册到 model 的 var-init 表（重复赋值会先 Remove
再 Add，保持表只反映最近一次成功折叠的值）。
MIR lowerer 把 `halt-call` 映射为 `halt`、`write-call` 映射为 `write-line` MIR op。
`compiler/backend/np_llvm_emitter.pas` 为程序发射真实 `.ll`，扫描 MIR 中的 `halt` 与
`write-line` operation：`write-line` 在入口处发射 `@.str.N = private constant` 字符串
常量并通过 `movq $$1, %rax; syscall` (sys_write to stdout) 写入；`halt` 在末尾发射
`movq $$60, %rax; syscall` (sys_exit)。每条 syscall 把 syscall number 烘焙进 inline asm
字符串并 clobber `~{rax}`，以保证 LLVM 在多 syscall 序列里为每条调用重新加载 rax
（先前 `{rax}` 输入约束在多写场景下会让第二次 syscall 拿到上一次的返回值，导致只发
首条 sys_write 然后误执行 `mmap`）。`opt → llc → ld` 真实执行并产出可执行：
`Halt(42)` → exit 42；`Halt(40 + 2)` → exit 42；`const FortyTwo = 42; Halt(FortyTwo)`
→ exit 42；`WriteLn('hello from nextpas llvm')` → stdout 输出该行 + exit 0；
`WriteLn(42)` → stdout 输出 "42\n"；`WriteLn('hello', ' ', 'world')` → "hello world\n"；
`WriteLn('answer: ', 42)` → "answer: 42\n"；`WriteLn('starting'); WriteLn('done'); Halt(7)`
→ stdout 输出两行后 exit 7；`var x: Integer; x := 42; Halt(x)` → exit 42；
`var n: Integer; n := 7; WriteLn(n)` → stdout 输出 "7\n"；
`var a, b: Integer; a := 10; b := a + 5; Halt(b)` → exit 15（链式常量传播：a=10
进 var-init 表后被 EvaluateIntegerConstant 折叠 a+5=15，再写回 b）。
`build/verify_local.sh` 的 `llvmEmptyProgram`、`llvmHaltProgram`、
`llvmHaltExprProgram`、`llvmHaltConstProgram`、`llvmWritelnProgram`、
`llvmWritelnIntProgram`、`llvmWritelnMultiProgram`、`llvmWritelnMixedProgram`、
`llvmHelloThenHaltProgram`、`llvmVarHaltProgram`、`llvmVarWritelnProgram`、
`llvmVarChainProgram`、`llvmIfHaltProgram`、`llvmIfElseHaltProgram`、
`llvmIfVarProgram`、`llvmForWritelnProgram`、`llvmForSumHaltProgram`、
`llvmForDowntoProgram`、`llvmIfNotProgram`、`llvmIfTrueProgram`、
`llvmWhileCountProgram`、`llvmWhileSumProgram`、
`llvmRepeatCountProgram`、`llvmRepeatHaltProgram`、
`llvmConstStringProgram`、`llvmStringConcatProgram`、
`llvmProcGreetProgram`、`llvmProcTwoProgram`、
`llvmFnConstHaltProgram`、`llvmFnComposeProgram`、`llvmFnCallHaltProgram`、
`llvmFnCallChainProgram`、`llvmProcArgProgram`、`llvmFnSquareProgram`
gate 都已纳入 promotion path。

sema 还具备编译期可折叠条件的 `if-then-else` 分支选择能力：
`EvaluateIntegerConstant` 的 `gnkBinaryExpression` 分支扩展支持关系运算
(=/<>/</>/<=/>=) 与逻辑 (and/or)，结果以 0/1 形式返回；`gnkUnaryExpression`
分支同时支持 `not` 一元运算（`Ord(Parsed = 0)`）；`gnkIdentifier` 分支识别
`true`/`false` (case-insensitive) 字面量并优先于 const/var-init 表查询。
`WalkAssignmentStatements` 与 `WalkHaltCalls` 在遇到 `gnkIfStatement` 子节点时，
若条件可被 `EvaluateIntegerConstant` 折叠则只递归进入选中分支
（true → then，false → else，无 else 时跳过整个 if），否则降级递归整个
if 子树。验证：`if 1 < 2 then Halt(11); Halt(99)` → exit 11；
`if 5 = 4 then Halt(1) else Halt(22)` → exit 22；
`var n; n := 7; if n >= 5 then Halt(n)` → exit 7（条件由 var-init 折叠后选 then）；
`if not (1 > 5) then Halt(11); Halt(99)` → exit 11（not 折叠 (1>5)=0 → 1）；
`if true then Halt(22); Halt(99)` → exit 22（true 字面量直接折叠为 1）。

sema 还具备编译期可展开的 `for` 循环：当 start/end 表达式皆可折叠且方向已知
（`to`/`downto`）时，`UnrollAssignmentForLoop` 与 `UnrollHaltForLoop` 把循环体在
sema 层迭代 N 次（每轮把 `i` 按当前值写入 var-init 表后递归 walk 循环体），让
循环体中的赋值与 `Halt`/`WriteLn` 都能在编译期被折叠。MaxIterations 上限 1024
以防意外失控。验证：`for i := 1 to 3 do WriteLn(i)` → stdout "1\n2\n3\n"；
`sum := 0; for i := 1 to 5 do sum := sum + i; Halt(sum)` → exit 15（每次迭代
sum 都通过 var-init 链式折叠重新计算）；`for i := 3 downto 1 do WriteLn(i)`
→ stdout "3\n2\n1\n"。

sema 还具备编译期可展开的 `while` 循环：当条件表达式可被
`EvaluateIntegerConstant` 折叠时，`UnrollAssignmentWhileLoop` 与
`UnrollHaltWhileLoop` 在 sema 层反复求值条件 + walk body，直到条件折叠为 0
或达到 MaxIterations=1024。`WalkHaltCalls` 镜像 `WalkAssignmentStatements`
的 `gnkAssignmentStatement` 处理：把可折叠 RHS 写入 var-init 表，让循环体
里的赋值在两次 walk 间保持同步。验证：`var i; i := 3; while i > 0 do begin
WriteLn(i); i := i - 1 end` → stdout "3\n2\n1\n"；`var i, sum; sum := 0;
i := 1; while i <= 5 do begin sum := sum + i; i := i + 1 end; Halt(sum)`
→ exit 15。

sema 还具备编译期可展开的 `repeat-until` 循环：与 `while` 对称，但执行顺序
反过来 —— `UnrollAssignmentRepeatLoop` 与 `UnrollHaltRepeatLoop` 在 sema 层
先 walk body，再求值终止条件，循环条件折叠为非 0（true）时退出，
否则继续迭代直到 MaxIterations=1024。验证：
`var i; i := 1; repeat WriteLn(i); i := i + 1; until i > 3` → stdout "1\n2\n3\n"；
`var x; x := 0; repeat x := x + 5; until x >= 20; Halt(x)` → exit 20。

sema 还具备编译期字符串常量折叠：`TSemanticModel` 增加并列的字符串常量表
（`AddStringConstValue` / `LookupStringConstValue`），新增 `EvaluateStringConstant`
递归折叠 `gnkStringLiteral`（经 `DecodePascalStringLiteral` 解码）/ `gnkIdentifier`
（查字符串常量表）/ `gnkBinaryExpression` with op `+`（拼接两个折叠结果）。
`ProcessConstSection` 对每个 `gnkConstDecl` 先尝试整数折叠，失败再尝试字符串折叠
并写入字符串常量表。`WalkHaltCalls` 的 WriteLn 参数循环在 `gnkStringLiteral` 直
解码之后、整数折叠之前先尝试 `EvaluateStringConstant`，让 `WriteLn(MyStringConst)`
与 `WriteLn(MyStringConst + ', world')` 在编译期得到拼好的字符串。验证：
`const Greeting = 'hello'; WriteLn(Greeting)` → stdout "hello\n"；
`const Greeting = 'hello'; WriteLn(Greeting + ', world')` → stdout "hello, world\n"。

sema 还具备零参数过程的编译期内联：`TSemanticAnalyzer` 维护 `FProcedureBodies`
表（procedure 名 → gnkBeginBlock 节点引用）与 `FInliningStack`（防止递归展开）；
`ProcessProcedureDecl` 在登记 procedure 符号时一并定位 body 节点并调用
`RegisterProcedureBody`；`WalkHaltCalls` 跳过顶层的 `gnkProcedureDecl` /
`gnkFunctionDecl` 子节点（避免把声明体当作普通语句重复展开），遇到
`gnkProcedureCallStatement` 时若名字匹配已注册的 procedure 体且不在内联栈中，
就把 body 当成内联序列递归 walk，使 caller 处直接得到等价的 typed-HIR 序列。
验证：`procedure Greet; begin WriteLn('hi') end; begin Greet end.` → stdout "hi\n"；
`procedure A; begin WriteLn('a') end; procedure B; begin WriteLn('b') end;
begin A; B end.` → stdout "a\nb\n"。

sema 进一步把零参数函数（带返回值）也纳入同一个 `FProcedureBodies` 表：
`ProcessFunctionDecl` 在登记 function 符号后同样定位 `gnkBeginBlock` 并调用
`RegisterProcedureBody`。`EvaluateIntegerConstant` 的 `gnkIdentifier` 分支在
const/var-init 表都未命中时会查 `FProcedureBodies`，命中且不在内联栈中就
`PushInlining`、`WalkAssignmentStatements(body)`（让函数体内部 `name := expr`
形式的赋值通过现有 var-init 机制把折叠后的返回值落到 `name` 槽位）、
重新 `LookupVarInitValue(name)` 拿到结果、`PopInlining`，由此让 `Halt(GetVal)`
等表达式在 sema 层得到函数返回值。验证：
`function GetVal: Integer; begin GetVal := 42 end; Halt(GetVal)` → exit 42；
`function Base: Integer; begin Base := 7 end; function Doubled: Integer;
begin Doubled := Base * 2 end; Halt(Doubled)` → exit 14（内联栈阻止递归，
且嵌套函数调用通过 var-init 链式折叠）。

`EvaluateIntegerConstant` 同时支持显式 `gnkFunctionCall`（即带括号的 `f()`
调用形式）：当节点的 `ChildCount = 1`（仅函数名子节点）时，按 `gnkIdentifier`
路径走同样的 `FProcedureBodies` 内联流程，让 `Halt(GetVal())` 与 bare
`Halt(GetVal)` 等价。
验证：`function GetVal: Integer; begin GetVal := 42 end; Halt(GetVal())`
→ exit 42；`function Base: Integer; ... ; function Doubled: Integer;
begin Doubled := Base() * 2 end; function Tripled: Integer;
begin Tripled := Doubled() + Base() end; Halt(Tripled())` → exit 15
（嵌套带括号调用通过同一内联栈和 var-init 链式折叠）。

参数化过程/函数：`TProcedureBodyEntry` 同时存 body 和 decl 节点，让
内联点能拿到 `gnkParameterList`。新增 `BindCallArgs` 在内联前折叠每个实参
表达式并把值写入 var-init 表（保留 prior snapshot），`RestoreCallArgs`
在内联后逆序还原；`gnkFunctionCall`（child[1..]） / `gnkIdentifier`（无 args）
/ `gnkProcedureCallStatement`（child[0..]）三个内联点共享这套机制。
验证：`procedure ShowVal(n: Integer); begin WriteLn(n) end; ShowVal(42)`
→ stdout "42\n"；`function Square(x: Integer): Integer;
begin Square := x * x end; Halt(Square(7))` → exit 49（参数 x 在内联期间
被绑定为 7，函数体内 `x * x` 通过 var-init 折叠为 49 并写回 Square）。

附带的 parser 修复：`ParseStatementList` 在 `;` 已是 ATerminatorSet 成员时不再
吞掉它（旧行为是无条件 `Inc(ACursor)`），让 `if/while/for body; following`
的 body 真正在 `;` 处停止，避免后继语句被贪婪并入 body 而引发错误。
`ParseAssignmentOrCall` 同时增加复合赋值脱糖：`x += y` / `x -= y` /
`x *= y` / `x /= y` 在 green tree 里直接展开为 `x := x op y`，与之前的
平铺 `x := x + 1` 行为等价。

默认 binding 仍是
`linux-x86_64-to-linux-x86_64-gnu`（`bootstrap-native-assemble-link`），LLVM 通过
`--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 显式选择。当前 emitter 仍只生成
单 `_start` + 顺序 syscall 序列；变量目前只在编译期 const-propagated（所有可见赋值
都必须可折叠为常量），if/else 的分支选择也只在条件可折叠时奏效，扩展 IR 表达力
（运行期变量 alloca/store/load / 运行期控制流 / 函数调用 / `Write(integer)`
在运行期数值格式化）属于下一批次。

进入下一段前，这一段的 promotion gate 至少包括：

- cross target、LLVM target 与 C interop 不再各维护一套名字系统。
- target library、runtime lookup 与 final link request 已有统一解释面。
- success path 和 failure path 都能进入同一套 toolchain evidence surface。

出现这些情况时必须回退：

- LLVM backend 要求第二套上游 IR。
- cross 行为散落回 driver、shell wrapper 或 ad hoc backend branch。
- C interop 直接退化成 raw linker args 拼接。

## 6. Workspace and Developer Tooling Integration

这一段虽然超出狭义 compiler kernel，但仍属于编译器主线的外延，因为这些工具必须建立在同一套
compiler truth 之上。

这一段至少要冻结这些事实：

- workspace、package manifest、artifact root、source root 与 target selection 建立在 compiler-owned truth 上。
- build/test/pkg/query 等开发者入口继续复用 compiler session、diagnostics 与 toolchain control plane。
- IDE、language service 与 package tooling 不各自维护私有 project model。

进入下一段前，这一段的 promotion gate 至少包括：

- workspace discovery 与 package source-root 规则已进入 shared model。
- developer-facing command surface 不复制 target/toolchain/workspace 推导逻辑。
- compiler truth 能被上层 tooling 稳定复用，而不是被重新包装成第二套规则。

出现这些情况时必须回退：

- 新工具必须复制一套 compiler/workspace 解释逻辑才能运行。
- build/test/query 对同一个 workspace 得出不同 source-root 结论。
- tooling surface 反向改写 compiler 的硬边界。

## 当前推荐优先级

结合当前仓库状态，这条编译器路线图的近期排期纪律应继续保持：

- 在 front-end semantic truth、resolver ownership 与 shared workspace truth 仍需收口时，
  不继续把主要精力放在 richer success-path transcript 上。
- 在 tool invocation plan、status event 与 build trace 已有最小闭环后，优先回到
  `resolution -> diagnostics -> sema -> workspace` 的可解释性。
- 在 `Typed HIR`、`MIR`、backend 与 toolchain contract 已有骨架后，继续用 tests、snapshots
  和 smoke 去逼近真实语义边界，而不是只扩充术语表面。

## 这份路线图故意不做什么

- 不改写 `master-roadmap.md` 的产品目标顺序。
- 不改写 `bootstrap-roadmap.md` 的阶段所有权定义。
- 不把 GUI framework、IDE、package manager 直接写成 compiler milestone。
- 不把编译器内部 contract 写成已经对外承诺的稳定二进制接口。
- 不把“文档里提到过”误当成“已经是当前执行优先级”。

这份路线图真正要交付的是：一条能约束 nextPas 编译器接管顺序、边界冻结和 promotion gate 的
正式主线。
