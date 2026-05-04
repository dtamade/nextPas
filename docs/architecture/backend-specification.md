# nextPas 后端规范

用这份规范定义 nextPas 第一阶段之后要逐步收紧的后端边界。它回答的不是
“以后要支持多少 ISA 或多少 object format”，而是“`Typed HIR` 之后哪些事实必须先冻结成
`MIR`，backend 可以消费什么、绝不能重做什么，target facts 应该怎样进入代码生成路径，
以及 assembler/linker/产物落点为什么必须成为显式管线，而不是一串历史副作用”。

这份文档承接 `compiler-specification.md` 对 `backend`、`ir` 与 `targets` 的职责定义，也细化
`compiler-pipeline-specification.md` 中已经冻结的 `MIR`、`Codegen adapter` 和
`Target-aware output path`。如果你要看 runtime helper 为什么必须先在语义层与 runtime contract
里变成显式事实，继续读 `runtime-bootstrap-specification.md`。如果你要看语义层应该先冻结哪些
symbol、type、intrinsic 和 overload 结论，继续读 `semantic-model-specification.md`。
如果你要看 host/target/toolchain/sysroot 如何决定 backend 选择，继续读
`cross-compilation-specification.md`。如果你要看 LLVM backend 为什么只是这条 contract 的一个实现，
继续读 `llvm-backend-specification.md`。如果你要看 C ABI、external symbol 和 C library linking
如何进入 backend，而不是被 backend 私自定义，继续读 `c-interop-specification.md`。
如果你要看 assembler、linker、archiver、resource compiler 与 tool invocation plan
怎样从 backend 外再收成一层正式控制面，继续读 `toolchain-specification.md`。
如果你要看这份设计具体在拆 FPC 哪些真实源码耦合，继续读
`fpc-source-grounding-specification.md`。

## 先承认 FPC 后端今天真实是怎样一条强耦合链

这份规范直接回应这些 FPC 真实源码事实：

- `compiler/node.pas`
  - `tnode` 同时承载 `expectloc`、`location`、`resultdef`、`fileinfo` 和
    `pass_1` / `pass_generate_code` 两条 pass 钩子
- `compiler/pass_1.pas`
  - `firstpass` 会在 typecheck、simplify、inlining 和 codegen error 状态之间来回切换
- `compiler/pass_2.pas`
  - `secondpass` 直接调用 `p.pass_generate_code`
  - 同时依赖 `cg.executionweight`、`current_asmdata.CurrAsmList` 和 `codegenerror`
- `compiler/cgbase.pas`
  - `TCGLoc`、`topcg`、`TOpCmp` 是 FPC 真实存在的 target-neutral codegen vocabulary
- `compiler/assemble.pas`
  - `GenerateAsm` 通过 `CAssembler[target_asm.id]` 选择 assembler 实现
  - `TInternalAssembler.MakeObject` 直接读取 `current_asmdata.asmlists`
- `compiler/link.pas`
  - linker 选择依赖 `target_info.link` / `target_info.linkextern`
  - object/static/shared inputs、smart/static/shared link 策略和外部进程执行都堆在同一层

这说明 FPC 已经证明“后端需要 target-neutral op vocabulary、assembler orchestration、
link orchestration、toolchain failure reporting”这些能力；nextPas 要做的不是删掉它们，
而是把它们从 node mutation 与全局状态里拆出来。

## 把后端写成显式分层，而不是 AST pass 的副作用串

nextPas 推荐的后端主骨架如下：

```text
Typed HIR
  -> MIR
  -> Codegen adapter
  -> asm/object emission
  -> link orchestration
  -> target-aware output path
```

这条链路的硬约束是：

- `Typed HIR` 负责可观察语言语义
- `MIR` 负责控制流、值流、cleanup 与 runtime contract 的 target-neutral 下沉
- `Codegen adapter` 负责把 `MIR` 映射到目标相关发射接口
- assembler/linker orchestration 负责把中间产物变成 object、archive、executable 或等价结果
- output path 负责把结果落到 `units/<target>/`、`bin/`、`lib/`、`share/` 的公开布局语义

任何一步都不应该再偷偷向上重做语义判断。

## `Typed HIR` 之后哪些事实必须已经冻结

backend 不是第二个语义分析器。进入 `MIR` 之前，至少这些事实必须已经稳定：

- 名字绑定已经结束
- overload resolution 已经结束
- constant evaluation 已经结束
- intrinsic 与 runtime contract 选择已经结束
- unit init/fini 需求已经以显式语义点表达
- diagnostics 中属于 syntax/resolution/sema 的失败已经分类完成

如果后端还要重新猜“这是不是某个重载”“这是不是某个 helper”“这个 unit 需不需要 init”，
说明前后端边界没有立住。

## `MIR` 必须是稳定的 backend 输入，而不是新的语义游乐场

`compiler-pipeline-specification.md` 已经说明 `MIR` 只做必要 lowering。这里进一步冻结：

`MIR` 至少要显式表达：

- basic block / control-flow graph
- terminators、branch 条件与可达性
- typed values、temporaries 与 lifetime boundary
- explicit load/store/address computation
- call site shape、result passing 和 cleanup point
- runtime contract call
- target-neutral aggregate move/init/destroy intent

`MIR` 不负责：

- 再做名字解析
- 再做类型推断
- 再决定 runtime helper 名称
- 再从源码字符串猜语义
- 再自己长出一套独立 target policy

`MIR` 是 backend 的输入契约，不是继续拖延语义收敛的缓冲区。

## generic op vocabulary 必须有限、显式，并且 target-neutral

FPC 的 `cgbase.pas` 已经证明，后端需要一套不直接等于具体 ISA 指令的通用 vocabulary。
`TCGLoc`、`topcg`、`TOpCmp` 就是在承担这件事。

nextPas 第一阶段也必须冻结类似边界，但表达方式更干净：

- value/storage class
  - register-like、stack/reference-like、constant-like、flag/jump-like 结果类别必须显式
- arithmetic and bitwise ops
  - add/sub/mul/div/and/or/xor/shift/rotate 这类 family 必须先是 generic op
- compare and branch ops
  - signed/unsigned compare 与 branch intent 必须显式分开
- memory and address ops
  - load/store/address-of/field-offset 等必须是 formal op，而不是临时拼字符串
- call/runtime ops
  - normal call、indirect call、runtime contract call、return 必须区分

这里的重点不是把 `cgbase.pas` 原样翻译成 Rust 枚举，而是保留它背后已经被证明必要的抽象层。

## `Codegen adapter` 只消费 `MIR + TargetFacts`

nextPas 第一阶段要求 `Codegen adapter` 的唯一正式输入是：

- `MIR`
- `TargetFacts`
- output intent

它不允许额外偷偷依赖：

- 原始 AST 或 `Typed HIR`
- unit search path 细节
- runtime 侧的字符串 helper 表
- driver 里的临时全局变量

这条边界是现代化和高性能的关键。只有这样，后续 target 增长、cache 设计和 emission 验证
才不会重新被上游语义实现绑死。

## `TargetFacts` 必须单点注入，不在 backend 内重新发明

FPC 的 `target_info`、`target_asm`、`target_info.link`、`target_info.linkextern`
说明：后端必然要消费目标事实。

nextPas 的约束是：

- pointer size、endianness、object format、assembler kind、linker kind 来自 `TargetFacts`
- calling convention 支持面、relocation 限制、section/layout 规则来自 `TargetFacts`
- backend 不维护第二套 host/target 推导逻辑
- 第一阶段仍只服务 `linux-x86_64`

如果某条后端逻辑无法说明它依赖的是哪一项 target fact，就说明它仍然在靠隐式平台假设运作。
更细的 host/target/toolchain/sysroot 分层由 `cross-compilation-specification.md` 定义。

## LLVM backend 只是这条 contract 的一个 specialization

LLVM backend 当然重要，但它在 nextPas 里必须服从同一条 backend 主骨架：

- LLVM backend 仍然消费 `MIR + TargetFacts + output intent`
- LLVM triple / data layout 仍然来自 target facts
- LLVM backend 不能把 upstream `MIR` 改造成 LLVM-only 结构
- LLVM backend 不能绕开统一 diagnostics sink 与 output path

更细的 LLVM-specific lowering、toolchain orchestration 和 non-goals 由
`llvm-backend-specification.md` 定义。

## backend 必须显式产出产物类型与下游依赖

FPC 的 `assemble.pas` 与 `link.pas` 证明：代码生成不是“吐一段文本然后看缘分”。

nextPas 第一阶段至少要让 backend/output path 能显式表达：

- 当前单元产出的是 asm、object、archive、executable，还是 installed unit artifact
- 当前链接步骤需要哪些 object/static/shared inputs
- 哪些输入来自 unit output，哪些来自 runtime/other libraries
- 最终产物应该落到哪个 target-aware path

也就是说，后端要输出的是“可解释的产物计划”，而不是让 driver 去重新扫描临时目录猜结果。

## 当前 Batch 7 已经落下的最小真实骨架

这份规范现在不只是方向约束。当前仓库里，`Batch 7` 已经把最小但真实的 backend spine
落成实体：

- `compiler/ir/np_mir_model.pas`
  - `TMirModel` 当前先固定 one entry block、one lowered op per typed-hir node 与显式 `return`
- `compiler/backend/np_backend_plan.pas`
  - `TBackendPlan` 当前已经按 backend family 持有正式 artifact truth：
    native binding 走
    `assembly-text -> object-file -> executable`，
    LLVM binding 走
    `llvm-ir -> llvm-bitcode -> object-file -> executable`；
    backend-owned intermediate artifacts 默认都落到
    `<artifact-root>/cache/backend/<target>/`，final executable 继续落到
    target-aware output dir；
    它仍继续携带 `output kind`、`primary artifact kind/path`、
    `tool invocation count`、`primary tool role`，并继续携带
    `AssemblerProfileId / LinkerProfileId / ArchiverProfileId / ResourceToolProfileId`、
    `ToolRootKind / RuntimeRootKind / ResponseFilePolicy / LinkScriptPolicy`；
    下游 typed `ToolInvocationPlan` 现在已能按 binding family 选择
    `bootstrap-native-assemble-link` 或 `llvm-ir-opt-llc-link`，并把
    `steps[] / argv / envDelta / workingDirectory / inputs / outputs / sidecars`
    保留成统一 payload
- `compiler/frontend/np_compilation_session.pas`
  - 当前会在 `AnalyzeSemantics` 之后真实运行 `LowerToMir` 与 `PlanBackend`，并把
    `backendArtifactCount/backendArtifacts`、
    `toolInvocationPlanRef/toolInvocationPlan` 与上述 richer toolchain binding metadata
    暴露成 session-owned projection
- `compiler/targets/np_target_facts.pas`
  - 当前会把 object format、assembler flavor、linker flavor、LLVM triple、
    toolchain binding id、backend family、assembler/linker/archiver/resource profile ids、
    sysroot/runtime SDK policy，以及 tool/runtime root 与 sidecar policy 收进统一
    `TargetFacts`
- `tools/stage0/target_config.pas`
  - 当前会从 `build/targets/linux-x86_64.toml` 读取 target truth，并在默认
    `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml` 与显式
    `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 之间解析同一 host/target pair
    下的 binding override，真实加载 `[profiles]`、`[sysroot]`、`[resolution]`
    与 LLVM executable-set metadata
- `tools/stage0/nextpas.pas`
  - 当前会把 `mir-status`、`mir-block-count`、`mir-operation-count`、
    `backend-plan-status`、`backend-output-kind`、`backend-artifact-count`、
    `backend-artifacts`、`toolchain-binding-id`、
    `assembler-profile-id/linker-profile-id/archiver-profile-id/resource-tool-profile-id`、
    `tool-root-kind/runtime-root-kind/response-file-policy/link-script-policy`、
    `target-object-format`、`llvm-toolchain-status/llvm-executable-set-*`、
    `tool-invocation-count` 与
    `toolInvocationPlanRef/toolInvocationPlan` 投影到 command envelope

当前 toolchain plan 无论走 native 还是 LLVM path，都已经把 backend-owned `object-file`
artifact 送进 `logical-link-request.objectInputs`，让 toolchain control plane 至少先消费
object-level truth，而不是继续从空数组起步。

这条骨架当前故意只承诺三件事：

- `MIR` 还是 target-neutral 最小 lowering，不假装已经是完整 codegen IR
- backend plan 已经拥有 binding-aware intermediate truth，但仍只承诺 native 与 LLVM 这两条
  最小 execution family，不假装已经接管完整 assembler/linker/c-interop matrix
- toolchain binding matrix 仍然很小：当前只有 `linux-x86_64 -> linux-x86_64` 这一组 target
  被正式实现，但同一 pair 已经同时允许 GNU/native 与 LLVM-heavy 两个 binding variant

但它已经足够证明 nextPas 不再把 `Typed HIR -> backend intent` 留在未来想象里。

## assembler 与 linker orchestration 必须是正式层，不是 shell 拼接习惯

nextPas 第一阶段冻结以下原则：

- assembler 选择来自 target facts 与 backend output kind
- linker 选择来自 target facts 与 output intent
- assembler/linker 参数组装有显式输入，不从全局状态隐式抓取
- 外部工具失败必须进入 structured diagnostics，而不是只剩一个非零 exit code
- 如果当前阶段需要保留宿主适配层，这层适配应待在 orchestration 边界，不反向污染 `MIR`

这正是把 FPC `GenerateAsm -> MakeObject -> DoExec` 这条链，拆成现代化控制面的原因。

## backend 不能重做这些事情

为了防止历史耦合回流，nextPas 明确禁止 backend：

- 重新做 overload resolution
- 重新猜类型、可见性或名字绑定
- 重新扫描 unit 依赖来决定 init/fini
- 自己私下发明 runtime helper 名
- 自己维护第二套 diagnostics 分类
- 直接绕过 output path 规则随意落文件

backend 的职责是消费已冻结事实，不是补写上游没有做好的工作。

## C interop 与外部链接只能复用统一 foreign contract

backend 层不允许再各自维护一套 `cdecl`、symbol prefix、shared/static C library 规则。

明确要求如下：

- calling convention 来自语义层与 `c-interop-specification.md`
- symbol naming 来自 target facts + external binding contract
- C library resolution 来自 target-aware link model 与 sysroot
- LLVM backend 与 native backend 必须消费同一套 foreign contract

这能挡住“native backend 能调 C，LLVM backend 另写一套名字规则”这种架构倒退。

## diagnostics 在 backend 层必须继续结构化

后端仍然会产生失败，但这些失败必须是后端/工具链失败，而不是重新覆盖前端分类。

backend 层至少允许这些诊断来源：

- illegal or unsupported lowering after `MIR`
- target fact conflict
- assembler selection failure
- assembler execution failure
- linker selection failure
- linker execution failure
- output artifact write failure

而且每条诊断都必须继续走统一 diagnostics sink，带有：

- `DiagnosticCode`
- `Severity`
- `Phase`
- relevant source span or artifact location
- related target/tool context

这样 `tests/diagnostics/` 才能覆盖 backend，而不是只覆盖 parser/sema。

## runtime bootstrap 与 backend 的职责分界必须保持稳定

`runtime-bootstrap-specification.md` 已经冻结了 runtime contract name 与 init/fini 边界。
backend 在这里允许做的只有：

- 根据 target facts 选择合适的调用落点或 calling convention 映射
- 把显式 runtime contract call 变成目标相关 emission
- 在 entry/shutdown path 中保留既定的 runtime invocation order

backend 不允许做的事：

- 自己决定还需要哪些 runtime helper
- 把 runtime contract 名重新替换成散落 magic string
- 在不同 target/backend 各自偷偷生成不同语义

## output path 必须服从发行布局，不再是后端私有目录规则

后端完成 emission 后，产物落点必须继续服从：

- `units/<target>/`
- `bin/`
- `lib/`
- `share/`

也就是说：

- unit/object/installable compiler artifacts 不应绕开 `units/<target>/`
- executable output 不应绕开发行布局另起私有目录语义
- shared docs/assets 不是 backend 自己的责任范围

这条规则把后端和 `distribution-layout-specification.md`、`target-platform-specification.md`
绑成同一条公开交付链。

## 性能模型必须从 backend 边界就开始生效

高性能后端不是“最后再优化”的借口。第一阶段先冻结这些原则：

- `MIR` 到 backend 的数据传递优先保持 arena-friendly 和 batch-friendly
- 后端不重新回看大对象 AST
- target facts 单次读取、会话级缓存
- emission 优先做顺序写出，不让路径推导散落各处重复计算
- assembler/linker orchestration 尽量消费显式产物列表，而不是多次扫描文件系统
- backend diagnostics 继续延迟格式化，避免热路径字符串拼接

## `stage0`、`stage1` 与 `stage2` 如何接这条边界

- `stage0`
  - 先冻结并真实跑通最小 `Typed HIR -> MIR -> backend plan -> output path` 这条 contract
  - 允许真实编译宿主仍由 FreePascal 托管
  - 但文档、target facts、toolchain binding 与测试必须向这条分层收敛
- `stage1`
  - nextPas 开始真实接管 `MIR`、lowering、backend diagnostics 与 target-aware emission 边界
  - assembler/linker orchestration 逐步从宿主 glue code 收回控制面
- `stage2`
  - 只有当 backend contract、runtime contract、toolchain diagnostics 和 output path 都稳定后，
    才允许继续调查更深的自托管或 target 扩展

## 第一阶段非目标

- 不在这一阶段承诺完整多目标 backend 矩阵
- 不把 `MIR` 对外承诺成稳定公共文件格式
- 不逐类翻译 FPC 现有 node pass 和 assembler/linker 类层次
- 不让 backend 直接吸收 runtime、driver 或 unit resolver 的职责
- 不把 object/asm/link 的控制流继续维持成全局可变状态网络

第一阶段真正要交付的是：一条从 `Typed HIR` 到产物落点都可解释、可验证、可扩展、
并且不再要求 backend 重做语义分析的现代后端边界。
