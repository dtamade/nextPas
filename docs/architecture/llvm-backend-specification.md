# nextPas LLVM 后端规范

用这份规范定义 nextPas 第一阶段之后要逐步收紧的 LLVM backend 边界。它回答的不是
“要不要顺手支持一下 LLVM”，而是“LLVM 在 nextPas 里属于哪一层、必须消费哪些正式输入、
哪些能力只能由 LLVM adapter 负责、哪些事实绝不能再从 AST 或命令行字符串里偷取”。

这份文档承接 `backend-specification.md` 中已经冻结的 `MIR -> Codegen adapter` 边界。
如果你要看 host/target/toolchain/sysroot 如何建立 cross target profile，继续读
`cross-compilation-specification.md`。如果你要看 C ABI、external symbol 和 library binding
如何进入 LLVM emission，继续读 `c-interop-specification.md`。如果你要看 LLVM executables、
tool discovery 和 invocation orchestration 如何进入统一 toolchain control plane，
继续读 `toolchain-specification.md`。

## 先看 FPC 真源码已经把 LLVM 当成什么层次

这份规范直接回应这些 FPC 真实源码事实：

- `compiler/hlcgobj.pas`
  - 抽象 high level code generator 明确写出：higher level targets such as LLVM 需要
    override 默认 lowering 行为
  - `g_ptrtypecast_reg`、`g_ptrtypecast_ref`、`g_undefined_ok` 这些钩子都点名了
    “type-aware platforms like LLVM”
- `compiler/llvm/hlcgllvm.pas`
  - `thlcgllvm` 继承 `thlcgobj`，重写 call、memory、pointer cast、proc entry/exit、
    external proc handling、overflow、unreachable 等大量高层 emission 钩子
- `compiler/globtype.pas`
  - 已经有 `triplet_llvm` / `triplet_llvmrt` 这样的 LLVM toolchain 概念
- `compiler/systems/i_linux.pas`
  - 各 target info 直接带 `llvmdatalayout`

这些事实说明：LLVM 不是“再加一种汇编输出格式”那么简单，它是一个需要正式 target profile 和
高层 codegen adapter 的后端族。

## LLVM backend 必须是 `Codegen adapter` 的一个实现

nextPas 第一阶段冻结：

- LLVM backend 属于 `backend` 层，不属于 `sema`
- LLVM backend 的正式输入仍然是 `MIR + TargetFacts + output intent`
- LLVM backend 只是 `Codegen adapter` 的一个实现，不是第二套编译器主管线
- 引入 LLVM backend 不能要求上游 `Typed HIR` 或 `MIR` 改成 LLVM-only 结构

也就是说，LLVM backend 必须服从 nextPas 的主骨架，而不是反过来把主骨架改造成 LLVM 的附庸。

## LLVM target profile 必须来自 `TargetFacts`

LLVM backend 至少需要这些 target facts：

- target triple
- data layout string
- object format / relocation model
- exception / unwind model
- calling convention mapping
- symbol visibility rules

这些信息必须来自 `TargetFacts`，而不是由 LLVM backend 私自拼出来。

这也是为什么：

- `llvmdatalayout` 必须是 target facts 的一部分
- LLVM triple 不应该和 backend executable path 混成一条字符串
- LLVM runtime library naming 如果需要，也属于 target facts / toolchain binding 的显式字段

## `MIR` 到 LLVM IR 的下沉必须保持 target-neutral 上游

LLVM backend 的职责是把已经冻结的 `MIR` 下沉成 LLVM IR，而不是重新解释 Pascal 语义。

因此 LLVM backend 可以负责：

- block / terminator 到 LLVM basic block 的映射
- target-aware pointer cast 与 address model
- overflow / unreachable / constrained fp 等 target-aware IR 构造
- LLVM IR module、function、global、metadata emission

LLVM backend 不允许负责：

- overload resolution
- constant evaluation
- runtime helper 选择
- unit init/fini 规划
- C ABI 规则再定义一遍

LLVM backend 只负责 codegen，不负责补齐前端没做好的事。

## pointer、undef 与 type-aware lowering 需要单列成正式职责

FPC `hlcgobj.pas` 和 `hlcgllvm.pas` 已经证明，LLVM 这种 type-aware backend 与普通
assembler-style backend 的差异，不在“有没有 `opt` 命令”，而在 lowering 细节。

因此 nextPas 明确：

- pointer cast 不能只是 byte-level hack，必须经过 LLVM-aware lowering
- undefined-but-masked value 之类语义必须显式建模
- external wrapper、proc entry/exit、unreachable 等 IR 构造属于 LLVM adapter 职责
- 这些 LLVM-specific lowering 只能消费 `MIR` 中已经显式存在的意图，不得回看 AST 猜语义

## LLVM backend 必须和 cross compilation 用同一套 target truth

LLVM backend 不能成为 cross compilation 的第二套 target system。

因此：

- triple / data layout / object format 来自 `TargetFacts`
- LLVM 工具链可执行文件、版本与宿主调用路径来自 `ToolchainBinding`
- sysroot 与 target runtime library search 来自 cross compilation control plane
- LLVM backend 不重新发明自己的 host/target split

如果 LLVM backend 无法在 `HostFacts + TargetFacts + ToolchainBinding + Sysroot` 下工作，
说明它的边界就写错了。

## C interop 不能在 LLVM backend 里各自搞一套

LLVM backend 最容易偷跑的地方，就是把 calling convention、symbol prefix、external name
和 shared library 处理写成 LLVM 私货。

nextPas 明确禁止这样做：

- `cdecl` / `cppdecl` / sysv / ms ABI 的选择来自 `c-interop-specification.md`
- symbol import/export 名称来自已经冻结的 interop contract
- LLVM backend 只负责把这些 contract 映射成 LLVM-level callconv、linkage、visibility 和 extern decl
- LLVM backend 不单独定义第二套 C ABI 命名规则

## LLVM backend 在 final link 之前就必须停下

FPC 的 `agllvm.pas` 会写 `target datalayout` 和 `target triple`，但 `link.pas` 仍然继续负责
`AddStaticCLibrary`、`AddSharedCLibrary`、import symbol 和最终 linker orchestration。

这说明即使引入 LLVM，final link ownership 也没有消失，只是换了某些执行工具。

因此 nextPas 明确：

- LLVM backend 可以产出 textual IR、bitcode、object file 或等价 codegen artifact
- 最终 shared/static/runtime/C library resolution 仍然属于 `ToolchainBinding + LinkerProfile + Sysroot`
- 即使 binding 选择 `clang`、`lld`、`llvm-ar` 或其他 LLVM utility，final argv serialization 也属于
  toolchain control plane，不属于 LLVM adapter
- LLVM backend 不直接写 `-l`、`-L`、`--sysroot`、dynamic linker 或 framework ordering 这类
  tool-flavor-specific invocation detail

这条规则非常关键，因为它保证 LLVM backend 只是 codegen specialization，而不是新的 link driver
世界观。

## LLVM 输出必须支持多种 emission 结果，但不承诺文本稳定

LLVM backend 在 nextPas 内至少要能区分以下 emission intent：

- textual LLVM IR
- bitcode
- object file

但同时必须明确：

- textual `.ll` 主要用于调试、证据和 backend investigation
- nextPas 不承诺 `.ll` 是对外稳定接口
- 真正稳定的上游 contract 仍然是 `MIR`
- 最终公开产物布局仍然服从 `distribution-layout-specification.md`

这能避免“有了 LLVM IR，就顺手把它当对外 IR 协议”的架构漂移。

## LLVM toolchain orchestration 必须进入正式 diagnostics

LLVM backend 至少要稳定这些失败类别：

- `backend.llvm-target-profile-missing`
- `backend.llvm-data-layout-missing`
- `backend.llvm-toolchain-missing`
- `backend.llvm-ir-emission-failed`
- `backend.llvm-object-emission-failed`

每条失败至少要保留：

- target id
- requested emission kind
- relevant LLVM triple / data layout
- failing tool or failing pipeline stage

LLVM backend 失败不能被压成一个模糊的“backend failed”总错误。

## `stage0`、`stage1` 与 `stage2` 如何接这条边界

- `stage0`
  - 先冻结 LLVM backend contract，但不要求它成为当前默认后端
  - 当前宿主路径继续以 FreePascal 为主
- `stage1`
  - 可以把 LLVM backend 作为受控 sidecar backend 调查对象
  - 但必须继续服从同一条 `MIR` 与 diagnostics contract
- `stage2`
  - 只有当 LLVM backend、native backend、cross compilation 与 C interop 都能共享 target truth，
    才允许把 LLVM backend 拉进更强的正式支持面

## 第一阶段非目标

- 不把 LLVM backend 当成新的前端或新 IR 主导层
- 不承诺所有 target 都必须先有 LLVM backend
- 不把 textual LLVM IR 写成公开稳定接口
- 不在这一阶段引入 JIT、ORC 或动态编译服务
- 不允许 LLVM backend 吞掉 C interop 或 cross compilation 的控制面职责

第一阶段真正要交付的是：一份把 LLVM 明确放回 `Codegen adapter` 层、并且和 target facts、
cross compilation、C interop 共用同一套正式输入的后端规范。
