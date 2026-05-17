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
sema 已具备整数常量表达式编译期折叠、const 标识符引用解析、多参数 string-literal
`WriteLn` 捕获与 `WriteLn(int-const)` 编译期格式化能力。`compiler/syntax/np_green_tree.pas`
的 procedure-call 解析器已支持逗号分隔多参数列表。`compiler/sema/np_semantic_analyzer.pas`
的 `WalkHaltCalls` 在遇到 `WriteLn`/`Write` 时迭代所有参数：`gnkStringLiteral` 经
`DecodePascalStringLiteral` 解码（`''` → `'`）后追加；可被 `EvaluateIntegerConstant`
折叠的整数表达式经 `IntToStr` 追加；`WriteLn` 在尾部追加 `\n`，最终拼成单个
`'write-call'` HIR 节点。`EvaluateIntegerConstant` 在 sema 层折叠 `gnkIntegerLiteral`
/ `gnkIdentifier`(查 const 表) / `gnkUnaryExpression`(+/-) / `gnkBinaryExpression`
(+/-/*/div/mod)；`ProcessConstSection` 为每个 `gnkConstDecl` 折叠并注册到 const 表。
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
→ stdout 输出两行后 exit 7。`build/verify_local.sh` 的 `llvmEmptyProgram`、
`llvmHaltProgram`、`llvmHaltExprProgram`、`llvmHaltConstProgram`、`llvmWritelnProgram`、
`llvmWritelnIntProgram`、`llvmWritelnMultiProgram`、`llvmWritelnMixedProgram`、
`llvmHelloThenHaltProgram` gate 都已纳入 promotion path。默认 binding 仍是
`linux-x86_64-to-linux-x86_64-gnu`（`bootstrap-native-assemble-link`），LLVM 通过
`--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 显式选择。当前 emitter 仍只生成
单 `_start` + 顺序 syscall 序列；扩展 IR 表达力（变量赋值 / 运行期表达式 / 控制流 /
函数调用 / `Write(integer)` 在运行期数值格式化）属于下一批次。

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
