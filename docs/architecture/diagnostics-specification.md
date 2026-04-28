# nextPas 诊断规范

用这份规范定义 nextPas 第一阶段之后要逐步收紧的诊断边界。它回答的不是
“命令行最后打印什么字符串”，而是“编译器如何把失败、警告和可留证上下文表达成稳定数据，
哪些信息必须进入结构化诊断，哪些内容属于格式化层，哪些失败根本不该继续伪装成诊断”。

这份文档承接 `compiler-specification.md` 对 `diagnostics` 模块的职责定义，也细化
`compiler-pipeline-specification.md` 中已经冻结的 `DiagnosticCode`、`Severity`、`Phase`、
`PrimarySpan` 和 `RelatedSpans`。如果你要看语义层本身应该产出哪些失败类别，继续读
`semantic-model-specification.md`。如果你要看运行时失败为什么不能回写成伪造的编译期错误，
继续读 `runtime-bootstrap-specification.md`。如果你要看这份边界具体在拆 FPC 哪些真实源码耦合，
继续读 `fpc-source-grounding-specification.md`。如果你要看 tool discovery、invocation plan、
status event 与 build tool profiles 为什么要先单列控制面，继续读
`toolchain-specification.md`。
如果你要看这些结构化 diagnostics 怎样以 stream / snapshot 形式进入 IDE、CLI 和 future
protocol adapters，继续读 `language-service-specification.md`。

## 先看 FPC 真源码为什么会把诊断揉成一团

这份规范不是凭空发明的，它直接回应这些 FPC 真实源码事实：

- `compiler/cmsgs.pas`
  - `TMessage` 同时持有消息文本、索引、状态和 `$1` 形式的参数替换逻辑
  - `SetVerbosity` / `ResetStates` 让 catalog 状态和当前 module 的 warning 开关纠缠在一起
- `compiler/verbose.pas`
  - `Message*`、`MessagePos*`、`CGMessage*` 一边查 catalog，一边计算 error count、
    warning count、verbosity、fatal stop 和 `codegenerror`
  - `Msg2Comment` 直接从消息前缀里的 `_E_`、`_W_`、`_N_`、`_H_` 推导 severity 和停止行为
- `compiler/msg/errore.msg`
  - 既包含真正的错误，也包含 `general_i_fatal`、`general_i_error` 这类前缀消息
  - 还混入了 `exec_i_assembling`、`exec_t_using_assembler` 这类进度型输出
  - `parser_e_syntax_error=03000_E_...`、`exec_e_error_while_linking=09013_E_...`
    说明消息编号、severity、子系统和文本现在被编码在同一条 catalog 字符串里

nextPas 不否认这些能力需求，但必须把“消息目录”“结构化诊断”“CLI 渲染”“进度日志”
拆开，否则后续所有语义层、后端层和测试层都会继续绑在一个全局 `verbose` 风格入口上。

## 把诊断系统拆成三层，而不是一个全局输出模块

nextPas 第一阶段先冻结三层边界：

- catalog metadata
  - 负责定义稳定 `DiagnosticCode`、默认 `Severity`、默认模板和文档注释
- structured diagnostics sink
  - 负责收集结构化诊断记录、汇总会话统计、驱动退出语义和快照输入
- renderers
  - 负责把结构化诊断渲染成 CLI、快照文本或其他输出形式

这三层的分工必须明确：

- catalog 不直接写 stdout/stderr
- diagnostics sink 不直接决定 ANSI 样式、分页或颜色
- renderer 不重新发明错误分类，也不偷偷修改 `Severity` 或 `Phase`

这样做的目的很简单：把“失败是什么”和“最后怎么展示”彻底分开。

## `DiagnosticCode` 必须稳定，但不继续复刻 FPC 的编号耦合

FPC 现有 catalog 把数值槽位、severity 和子系统硬编码进一条消息标识里。nextPas 第一阶段
不沿用这种主键结构。

nextPas 冻结的主键是稳定 ASCII `DiagnosticCode`，推荐格式：

```text
<domain>.<name>
```

例如：

- `parser.syntax-error`
- `resolver.unit-not-found`
- `resolver.unit-cycle`
- `sema.ambiguous-overload`
- `lowering.unsupported-intrinsic-lowering`
- `toolchain.assembler-exec-failed`
- `toolchain.linker-exec-failed`

这样设计的约束是：

- `DiagnosticCode` 本身不编码 `Severity`
- `DiagnosticCode` 本身不编码 CLI 文本前缀
- `DiagnosticCode` 不因为 catalog 排序、消息文件重排或 snapshot 重写而变化
- 如果未来需要维护 FPC 兼容映射，它应作为 catalog metadata，而不是 nextPas 内部主键

这让代码稳定性和展示策略不再互相绑死。

## `Severity` 必须是显式字段，不再从消息前缀倒推

nextPas 第一阶段冻结以下 severity 集合：

- `fatal`
- `error`
- `warning`
- `note`
- `hint`

并且明确：

- `fatal` 表示当前编译会话无法继续安全推进
- `error` 表示当前编译结果无效，但不等于必须立刻终止整个会话
- `warning`、`note`、`hint` 是可配置的非致命诊断类别
- warning-as-error 是 sink/driver 层策略，不是 catalog 文本技巧

这份规范故意不把“进度信息”塞进 severity 集合里。像 FPC `exec_i_assembling`、
`exec_t_using_assembler` 这类输出，在 nextPas 应归入 driver/status event，而不是结构化诊断。

## `Phase` 必须能解释失败来自哪一层

为了让 `tests/compiler/fail/`、`tests/diagnostics/` 和后续问题回放都能看懂失败来源，
nextPas 第一阶段要求每条诊断显式带有 `Phase`。

推荐阶段集合如下：

- `lexer`
- `syntax`
- `resolution`
- `sema`
- `lowering`
- `backend`
- `toolchain`
- `driver`

解释规则如下：

- source text 本身的切分失败属于 `lexer`
- 语法结构失败属于 `syntax`
- unit/name 解析失败属于 `resolution`
- 类型、重载、常量求值与可见性失败属于 `sema`
- 从 `Typed HIR` 向 `MIR` 或 runtime contract 下沉时的失败属于 `lowering`
- 目标相关代码生成内部失败属于 `backend`
- assembler、linker、archiver、resource compiler 等外部工具失败属于 `toolchain`
- CLI 输入、target 选择、构建意图冲突属于 `driver`

`Phase` 是分类字段，不是 renderer 文案装饰。

## `PrimarySpan` 必须覆盖源码、unit 逻辑点和产物位置

编译器诊断不能只支持“某一行某一列”的理想情况。FPC 源码里已经证明，缺失 unit、
PPU/产物读取失败、assembler/linker 失败并不总有一个单纯的 token 位置。

因此 nextPas 冻结以下定位能力：

- source-origin diagnostics
  - `PrimarySpan` 指向 `FileId` + byte range，行列信息由 source database 派生
- unit-level diagnostics
  - `PrimarySpan` 至少能表达 `UnitId`、import edge 或 logical section，而不是退化成裸字符串
- artifact/toolchain diagnostics
  - `PrimarySpan` 至少能表达相关产物路径、工具名或目标阶段

与此同时：

- `RelatedSpans` 用于补充 involved units、候选定义、冲突声明或相关 artifact
- 如果没有真正的源码定位，也不能伪造 line/column；应保留逻辑定位或 artifact 定位
- snapshot 和 CLI 都应从同一定位模型派生，而不是各自重新猜位置

## `Message` 可以懒生成，但结构必须先冻结

`compiler-pipeline-specification.md` 已经把 `Message` 写成诊断字段。这里补充细化：

- 结构化记录必须先冻结 `DiagnosticCode`、`Severity`、`Phase`、定位和参数载荷
- `Message` 可以在 emission 阶段懒生成，而不是在热路径里立即拼完整字符串
- renderer 可以选择使用 catalog 模板 + 参数载荷生成最终文本
- snapshot renderer 与 CLI renderer 必须共享同一份结构化记录，而不是各自再跑一次分类逻辑

这样做同时满足：

- 高性能：避免在分析热路径里提前格式化大量最终字符串
- 优雅：分类逻辑只做一次
- 可测试：结构与文本都可以稳定留证

## 会话级计数必须由 diagnostics sink 直接拥有

nextPas 当前不再把“到底有几个 warning / error”留给 renderer 或 driver 事后猜。
这层 contract 现在已经先收紧成 sink-owned accounting：

- `TDiagnosticsSink.ErrorCount` 表示当前会话里真正落入 error bucket 的诊断数量
- `TDiagnosticsSink.WarningCount` 表示当前会话里仍保持 warning severity 的诊断数量
- `TDiagnosticsSink.TotalCount` 表示最终收集到的结构化 diagnostic record 数量
- `TDiagnosticsSink.Summary` 继续从同一份结构化记录派生，而不是额外维护一套文本状态

这条规则现在还有一个必须明确写下的细节：warning-as-error 政策改变的是 emission 结果，
不是 renderer 文案。

也就是说：

- 同一条 `EmitWarning(...)` 在默认策略下会产出 `severity=warning`
- `SetWarningAsError(true)` 之后，再发出的同类 warning 会产出 `severity=error`
- promoted warning 会计入 `ErrorCount`，而不会继续留在 `WarningCount`
- `PolicyName` 仍然表达当前策略名，但不会回写已经产出的历史 record

这让 line-based projection、`command-envelope=<json>`、tests snapshot 和 future IDE adapter
都能消费同一份 accounting truth，而不是每个表面再各自推导一次“是不是算 warning”。

## 诊断状态开关属于策略层，不属于单条消息实现细节

FPC 里 `$WARN`、local/global state 与具体消息条目的存储状态耦合很深。nextPas 第一阶段先收紧为：

- warning/hint/note 的启停规则由 compilation session 中的 diagnostics policy 决定
- 单条诊断记录只表达“实际产出了什么”，不反向持有 policy 状态
- policy 切换影响后续 emission，不回写历史 diagnostic record
- warning-as-error 的结果要体现在最终 `Severity` 或会话退出判定里，而不是靠 renderer 再猜

这样既保留可配置性，也避免 catalog 结构被 session 状态污染。

## 编译期失败与运行期失败必须在这里分界

nextPas 第一阶段要求：

- 编译器阶段失败通过结构化 diagnostics sink 报告
- runtime failure 通过 runtime contract 或进程结果留证，不回写成伪造的 compile diagnostic
- 如果 lowering/backend 发现“无法生成合法 runtime 调用”，这是编译期 diagnostic
- 如果已生成程序在执行时触发 `np.system.runtime_fault`，这是运行期失败，不属于编译器 diagnostic

这条边界必须和 `runtime-bootstrap-specification.md` 保持一致，否则 snapshot 会把 compile failure
和 runtime failure 混成同一种文本事故。

## assembler/linker/archiver/resource 失败必须是正式 toolchain diagnostics

FPC 的 `exec_e_error_while_assembling`、`exec_e_error_while_linking` 说明：后端外部工具失败
是编译器必须认真建模的结果，而不是“shell 命令返回非零”。

nextPas 第一阶段至少要稳定这些 toolchain 失败类别：

- `toolchain.host-compiler-exec-failed`
- `toolchain.assembler-not-found`
- `toolchain.assembler-exec-failed`
- `toolchain.archiver-not-found`
- `toolchain.archiver-exec-failed`
- `toolchain.linker-not-found`
- `toolchain.linker-exec-failed`
- `toolchain.resource-compiler-not-found`
- `toolchain.resource-exec-failed`
- `toolchain.sidecar-write-failed`

每条这类诊断至少要保留：

- tool identity
- binding/profile/step identity
- relevant target
- exit code if available
- primary artifact or command target
- whether compilation can continue

这也是为什么 `toolchain` 需要成为正式 `Phase`。

## toolchain diagnostics 必须能落到具体 step，而不是只会说“link failed”

`toolchain-specification.md` 现在已经把 `ToolInvocationPlan` 冻结成带 `steps` 的结构，并且让
每个 step 自己持有 `failureMapping`。诊断层也必须接住这条边界，否则 structured diagnostic
最后还是会退回一条模糊文本。

因此 nextPas 继续冻结：

- toolchain diagnostic 必须能引用 `bindingId`
- toolchain diagnostic 必须能引用 `profileId`
- toolchain diagnostic 必须能引用 `stepId`
- toolchain diagnostic 必须能引用 `logicalExecutable`
- 如果失败发生在 sidecar 物化阶段，还必须能引用 `sidecar.kind` 与 `sidecar.path`

推荐的最小 payload 形状可以是：

```json
{
  "code": "toolchain.resource-exec-failed",
  "phase": "toolchain",
  "bindingId": "linux-x86_64-to-linux-x86_64-gnu",
  "profileId": "windres+fpcres-coff",
  "stepId": "res-to-obj",
  "logicalExecutable": "fpcres",
  "resolvedPath": "/toolchains/bin/fpcres",
  "primaryArtifact": {
    "kind": "resource-object",
    "path": "app.o"
  },
  "relatedArtifacts": [{ "kind": "binary-resource", "path": "app.res" }],
  "exitCode": 1
}
```

当前仓库里的最小真实落点已经不再只是文档示意。`tools/stage0/nextpas.pas` 在宿主
compiler execute step 非零退出时，已经会产出一条 `toolchain.host-compiler-exec-failed`
diagnostic，并把这些字段真实投影到 `command-envelope=<json>` 的 `diagnostics` 数组里：

- `id=diag-0001`
- `bindingId=linux-x86_64-to-linux-x86_64-gnu`
- `profileId=fpc-stage0-host`
- `stepId=host-fpc-emit-asm`
- `logicalExecutable=fpc`
- `sysrootRef=runtime-sdk:linux-x86_64`
- `resolvedPath=<resolved-host-fpc-path>`
- `primaryArtifact.kind=executable`
- `primaryArtifact.path=examples/smoke/hello`
- `exitCode=<non-zero>`

同一次 failure 现在还会继续补出：

- `build-trace-ref=trace-<session-id>-toolchain-plan`
- `build-trace.steps[0].stepId=host-fpc-emit-asm`
- `build-trace.steps[0].diagnosticRefs=["diag-0001"]`

也就是说，当前真实仓库里的最小 host-compiler failure 已经不再只是“有一条 toolchain diagnostic”，
而是已经具备 `diagnostic id -> build trace ref -> diagnosticRefs` 这条可回放关联链。

这条 baseline 现在已经覆盖 `bootstrap-native-assemble-link` production path 的真实 failure
step：宿主 FPC failure 继续落在 `host-fpc-emit-asm`，而 assembler/linker failure 会分别
落在 `native-assemble` / `native-link`，`stepId/build-trace-ref/diagnosticRefs` 会跟着
真实失败 step 走。`build/verify_local.sh` 已用 fake `fpc` / `as` / `ld` 负路径冻结这条
contract。success path observability 这一侧也已经补齐：成功时的
`buildTrace.steps[]` 会留下完整 multi-step transcript，并与同一条
plan-level `build-trace-ref`、`tool-status-events` 一起描述整轮执行事实。当前 diagnostics
层要继续守住的边界是：只有真实失败的 step 才应带上 `diagnosticRefs`，success-only step
不应被伪装成 diagnostic carrier。

如果失败不是发生在进程退出，而是发生在 sidecar 资产生成阶段，推荐改用：

- `toolchain.sidecar-write-failed`
- `toolchain.sidecar-read-failed`
- `toolchain.response-file-nesting-unsupported`

这类诊断至少要额外保留：

- `sidecar.kind`
- `sidecar.path`
- `ownerStepId`
- `materializationTiming`

这条规则直接回应 FPC 里的真实情况：

- `link.pas` 会单独生成 `ResName`、`ScriptName`、symbol order file
- `comprsrc.pas` 会单独生成 resource list script，并以 `@file` 驱动后续执行
- `errore.msg` 也已经明说 nested response file 是一类正式失败，而不是普通 stderr 噪声

换句话说，nextPas 的 toolchain diagnostics 必须能说明“哪一步、哪类 sidecar、哪类 artifact”
出了问题，而不是只会给出一句最终命令失败。

## status event 和 build trace 不能反向伪装成 diagnostics

`toolchain-specification.md` 已经把 status event 和 build trace 从 toolchain diagnostics 里拆出来。
诊断层这里继续把边界钉死。

像 FPC 的这些输出：

- `exec_i_assembling`
- `exec_t_using_assembler`
- `exec_i_linking`
- `exec_i_compilingresource`
- `exec_i_closing_script`

在 nextPas 都不进入结构化 diagnostics sink。它们属于：

- 实时进度时，进入 status event stream
- 事后留证时，进入 build trace

因此 nextPas 继续冻结：

- status event 不拥有 `DiagnosticCode`
- status event 不拥有 `Severity`
- build trace 不重新定义错误分类
- diagnostics sink 不重复保存整条 progress stream

三者的衔接只通过正式关联键完成，最小集合推荐为：

- `sessionId`
- `planId`
- `stepId`
- `diagnosticRefs`

这组关联键的意义是：

- CLI 可以一边显示进度，一边在失败后跳到正式 diagnostic
- IDE 可以在 build panel 里显示 step 状态，同时在 problems panel 里显示结构化错误
- harness 和 CI 可以分别保存 snapshot 与 trace，而不会把两种表面混成一份文本

也就是说，status event 负责过程可见性，build trace 负责执行回放，diagnostics 负责失败分类。
它们必须可关联，但绝不能重新合并成一个“万能日志接口”。

## `env` 失败不新增 `Phase`，继续收敛到 `driver` / `toolchain`

nextPas 现在已经把 `env` family 收进统一命令面，但这不等于诊断系统也要再长出一个
`env` phase。

FPC 的 `fppkg.cfg`、mirror/repository 选择、`FPCDIR` / `CROSSBINDIR` / `RCPROG` /
`ARPROG` 推导已经说明：environment/bootstrap 的问题，本质上仍然是在“请求是否合法”和
“工具链环境能否被正确解析/物化”之间分层。

因此 nextPas 继续冻结：

- 不新增 `env` phase
- `env` 请求本身不合法，继续归 `driver`
- distribution metadata、binding、runtime SDK、activation 解析失败，继续归 `toolchain`

第一阶段至少要稳定这些 env-related failure 类别：

- `driver.env-unknown-channel`
- `driver.env-conflicting-selection`
- `driver.env-workspace-selection-conflict`
- `toolchain.distribution-metadata-not-found`
- `toolchain.distribution-metadata-invalid`
- `toolchain.host-not-supported`
- `toolchain.binding-not-available`
- `toolchain.runtime-sdk-not-available`
- `toolchain.environment-activation-failed`

这里最关键的边界是：

- `env status` 成功时返回的是 environment state，不是 diagnostic
- `env use` 成功时返回的是 selection/result delta，不是 diagnostic
- 只有当环境请求非法，或环境解析/物化真的失败时，才进入结构化 diagnostics sink

这样 phase 数量不会膨胀，但 environment failure 仍然有正式、稳定、可留证的分类。

## `doctor` findings 是结果 contract，不替代 diagnostics sink

`doctor` 的职责是只读 health inspection。它会解释当前 workspace / toolchain /
runtime state 为什么可能不适合继续执行 build/test/pkg/doc/query，但这类健康 finding
不应自动塞进 compiler diagnostics sink。

当前 `stage0` 已先冻结最小 result contract：

- line-based projection 会输出代表性 finding，例如
  `doctor-finding-code=doctor.runtime-sdk-missing` 与
  `doctor-finding-severity=warning`
- `command-envelope=<json>.result.doctorFindings[]` 会保存同一条 finding 的
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`
- workspace root 与 toolchain binding readiness 通过 `doctorWorkspaceStatus` /
  `doctorToolchainBindingStatus` 表达

这里的 `doctor.*` code 是 health-finding code，不是编译期 `DiagnosticCode`。
只有当 doctor/env 请求本身非法，或 toolchain/distribution 解析真的失败，才应进入正式
driver/toolchain diagnostic path。

## 快照稳定性要建立在结构化字段上，而不是 ANSI 文本偶然性上

为了让 `tests/diagnostics/` 和 `tests/snapshots/` 长期稳定，nextPas 冻结以下原则：

- snapshot 主要比较 `DiagnosticCode`、`Severity`、`Phase`、定位和 canonical message text
- ANSI 颜色、分页、终端宽度、自适应路径缩写不属于主稳定表面
- CLI renderer 可以更友好，但 canonical snapshot renderer 必须更保守、更确定
- 同一条诊断在 CLI 和 snapshot 中允许排版不同，但核心字段不得变化
- `harness` 与 CI-facing projection 至少要能稳定指出 snapshot key、baseline path 和 diff locator，
  这样失败调查不会退化成“这次到底是哪份 baseline 在参与比较”的猜谜
- status event stream 与 build trace 默认不进入 diagnostics snapshot，除非某个测试显式声明自己要验证
  trace contract

换句话说，稳定的是诊断记录，不是终端魔法。

## 性能模型必须直接约束 diagnostics

现代化、高性能、优雅的诊断系统，不应该在热路径里反复做字符串与输出开销。

nextPas 第一阶段坚持：

- diagnostics 优先 batch emission，而不是阶段中到处即时 `println`
- `DiagnosticCode`、`Phase` 和常用 payload key 优先使用 cheap-to-compare 表示
- 行列映射从 source database 派生，不重复扫描整份源码
- renderer 只在真正输出时做格式化
- toolchain subprocess 输出如果要截取，也应以受控摘要方式进入 diagnostics，而不是整段无结构拼接

## `stage0`、`stage1` 与 `stage2` 如何接这层边界

- `stage0`
  - 先冻结 `DiagnosticCode`、`Severity`、`Phase`、定位模型和 snapshot 语义
  - 允许最外层宿主仍由 FreePascal 托管
  - 但 nextPas 文档、测试分桶和后续实现必须向这套边界收敛
- `stage1`
  - nextPas 开始真实接管 resolution/sema/lowering/backend diagnostics 的结构化产出
  - driver 与 test harness 消费统一 diagnostics sink
- `stage2`
  - 只有当 compile diagnostics、runtime failure 留证和 toolchain diagnostics 都稳定后，
    才值得继续调查更深的 self-hosting 与 backend 替换

## 第一阶段非目标

- 不承诺完全复刻 FPC 的消息编号体系与原始文本格式
- 不把进度日志、trace 输出和 structured diagnostics 混成一个接口
- 不在这一阶段引入本地化消息系统或多语言 renderer
- 不把 runtime failure 伪装成 compile diagnostic
- 不让每个编译阶段自己维护一套私有字符串错误风格

第一阶段真正要交付的是：一套能把错误分类、定位、快照留证、toolchain 失败和 CLI 渲染
彻底拆开的现代诊断边界。
