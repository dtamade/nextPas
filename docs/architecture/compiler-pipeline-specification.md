# nextPas 编译器流水线规范

用这份规范定义 nextPas 在第一阶段之后要逐步收紧的编译器内部流水线。它回答的不是
“编译器目录里有哪些模块”，而是“源码从进入系统到产出诊断或目标相关结果时，必须经过
哪些稳定边界、由谁拥有数据、哪些阶段允许变更、哪些阶段必须保持不可变，以及性能约束
应该从哪里开始生效”。

这份文档是 `compiler-specification.md` 的实现级补充。前者冻结模块所有权，这里冻结
数据流与阶段契约。如果你要看 `compiler <-> rtl/core/system/` 的启动与 helper 边界，
继续读 `runtime-bootstrap-specification.md`。如果你要看 `Typed HIR` 自身该承载哪些语义事实，
继续读 `semantic-model-specification.md`。如果你要看 unit identity、search path 和
`UnitGraph` 如何建模，继续读 `unit-resolution-specification.md`。如果你要看结构化诊断、
快照稳定性和 toolchain failure 如何冻结，继续读 `diagnostics-specification.md`。
如果你要看 open file overlays、incremental invalidation 和 semantic queries 怎样建立在这条
流水线之上，继续读 `language-service-specification.md`。
如果你要看 `MIR`、codegen adapter、assembler/linker 和产物落点怎样形成正式后端边界，
继续读 `backend-specification.md`。如果你要看 tool discovery、invocation plan、
sysroot-aware orchestration 和 developer-facing tool surface 怎样进入统一控制面，继续读
`toolchain-specification.md`。如果你要看这些设计到底在回应 FPC 真源码里的哪些历史耦合，
继续读 `fpc-source-grounding-specification.md`。

## 先把现代化、高性能、优雅翻成硬约束

nextPas 的编译器流水线要同时满足三件事：

- 现代：阶段边界清楚，数据结构分层明确，不再复用历史平铺式编译器树的偶然耦合。
- 高性能：性能模型前置写进设计，而不是等系统长大后再靠补丁式优化。
- 优雅：公开表面尽量小，内部层与层之间通过显式数据契约协作，而不是通过隐式副作用串接。

因此，这份流水线规范从第一天起就坚持以下规则：

- `syntax` 不直接修改语义层数据。
- `sema` 不回写语法树来隐藏语义结论。
- `targets` 不把平台规则散落回各个阶段。
- `diagnostics` 是结构化数据汇聚面，不是到处 `WriteLn` 的副产品。
- 同一个编译会话里的共享事实，优先以 `Id`、`interning` 与 arena-owned 数据表达。

## 用这条流水线作为唯一推荐方向

nextPas 推荐的内部流水线如下：

```text
Source text
  -> Source database
  -> Lexer
  -> Green CST
  -> AST facade
  -> Unit graph / name resolution
  -> Typed HIR
  -> MIR
  -> Codegen adapter
  -> Target-aware output path
```

这里的重点不是“名字看起来现代”，而是每一层都要有清晰输入、清晰输出和清晰失效边界。

## 把每一层的职责写死

| 阶段                     | 输入                              | 输出                                           | 第一阶段后的长期职责                                  |
| ------------------------ | --------------------------------- | ---------------------------------------------- | ----------------------------------------------------- |
| Source database          | 文件路径、unit 名、原始文本       | `FileId`、`UnitId`、不可变文本缓冲区、行列索引 | 统一管理源码身份、路径归一化与文本缓存                |
| Lexer                    | 不可变文本缓冲区                  | token 流、词法诊断                             | 做词法切分，不夹带语义判断                            |
| Green CST                | token 流                          | lossless、immutable 的 `Green CST`             | 保留完整语法形状，支持后续 cheap reparse              |
| AST facade               | `Green CST`                       | typed AST view                                 | 只做类型化访问，不持有独立树所有权                    |
| Name resolution          | AST、unit graph、symbol interning | 作用域、符号绑定、引用关系                     | 把名字解析和 unit 依赖关系稳定下来                    |
| Typed HIR                | 解析后的绑定结果                  | 带类型与语义结论的 `Typed HIR`                 | 承接可观察语义与后续 lowering 的稳定输入              |
| MIR                      | `Typed HIR`                       | target-neutral `MIR`                           | 做控制流与语义下沉，不直接泄露 target 细节            |
| Codegen adapter          | `MIR`、target facts               | 后端请求、宿主调用参数或产物描述               | 把公共中间层与具体代码生成路径隔开                    |
| Target-aware output path | target facts、发行布局语义        | 目标相关产物位置与构建元数据                   | 保持 `units/<target>/`、`bin/`、`lib/`、`share/` 对齐 |

## 让前端数据尽量不可变

为了同时满足性能和可维护性，nextPas 约束前半段流水线如下：

- 源文本进入 `Source database` 后，不再被原地修改。
- `Green CST` 必须是 immutable 结构，允许共享子树，不依赖 parent pointer 作为核心事实。
- AST 只是 facade，不应该复制整个树，也不应该把语法树重新物化成第二份大对象图。
- 词法与语法阶段的结构优先使用 arena allocation，避免细粒度堆分配把吞吐打碎。
- 标识符、unit 名、常用路径片段优先采用 `string interning` 或等价策略，避免整条流水线重复持有相同字符串。

这一段的目标是：一次 parse 产生的结构，后续阶段可以稳定复用、稳定引用、稳定回放。

## 把语义层当成真正的编译器核心

`Typed HIR` 是 nextPas 后续架构的核心落点。原因很简单：兼容性矩阵里的
`Core semantics`、unit/module 行为、诊断预期，都要在这一层被正式表达，而不是继续
散落在 driver、runtime 或临时 backend 逻辑里。

更细的 symbol、scope、type、intrinsic 和 `Typed HIR` 规则由
`semantic-model-specification.md` 定义。

因此 `Typed HIR` 必须满足：

- 所有名字绑定都已经落到显式引用，而不是继续保留“等后面再查一次”的字符串查找。
- 所有会影响正确性的类型判断、可见性、重载解析和常量求值结论，都已经在这一层稳定存在。
- 运行时需要的显式语义点，例如初始化、清理、内建过程调用、隐式运行时协助，必须通过
  明确节点或明确 intrinsic 表达，而不是靠 magic string。
- 语义错误在进入 `MIR` 之前就应该可被稳定分类；`MIR` 不负责重新发明前端错误。

换句话说，后续实现应该把“真正的 Pascal 语义世界”放在 `Typed HIR`，而不是放在某个
隐式耦合的后端分支里。

## `MIR` 只做必要 lowering，不偷走语言语义

nextPas 需要 `MIR`，但不应该为了“看起来高级”把一切都提早压平。

`MIR` 的职责是：

- 把 `Typed HIR` 中已经明确的语义结论转换成更适合控制流、数据流和后续代码生成消费的形式。
- 让 control flow、临时值、生存期、显式 cleanup point 等结构变得可分析。
- 让后续 backend 或宿主 codegen adapter 不需要重新理解 Pascal 级名字绑定。

`MIR` 不负责：

- 重新做名字解析。
- 重新解释类型系统。
- 接管 target policy。
- 隐式补全本该在 `Typed HIR` 就被建模的运行时行为。

这也是为什么这份规范只把 `MIR` 定义为 internal representation，而不是稳定外部格式。
更细的 backend layering、generic op vocabulary 和 output orchestration 规则由
`backend-specification.md` 定义。

## 把 `driver`、`targets` 与流水线解耦

`driver` 负责建立编译会话，不拥有语言分析本体。`targets` 负责提供 target facts，
不拥有前端阶段。

推荐的责任拆分是：

- `driver`
  - 解析命令意图
  - 建立 compilation session
  - 调度各阶段
  - 汇总 diagnostics 与 exit behavior
- `targets`
  - 描述 `linux-x86_64` 能力与限制
  - 提供 `units/<target>/`、layout、ABI 延后等约束视图
  - 为 `MIR` 和 codegen adapter 暴露显式 target facts

不允许的反模式是：

- 在 `syntax`/`sema` 里散落 host/target 条件判断
- 在 `driver` 里直接做语义判定
- 在 backend 里重新维护第二套 target database

## 用 compilation session 管整个生命周期

现代、高性能、优雅的 nextPas 编译器，不应该用一堆游离全局变量拼起来。推荐统一使用
`CompilationSession` 或等价对象作为一次编译会话的总拥有者。

这个 session 至少要持有：

- `Source database`
- target facts view
- `UnitGraph`
- symbol interner
- 各阶段 arena
- diagnostics sink
- compilation options

而且要明确三类生命周期：

- 会话级：同一轮 build 共享的只读事实与缓存
- unit 级：某个 unit 解析、绑定、typed lowering 的中间产物
- 阶段级：某一阶段内部可被丢弃的临时工作集

这样做的目的，是让内存、增量失效和诊断留证都有清晰归属。

当前仓库在 `Batch 3/4/5/6/7` 的最小真实落点是：

- `compiler/frontend/np_compilation_session.pas`
  - `TCompilationSession`
- `compiler/frontend/np_source_database.pas`
  - `TSourceDatabase`
- `compiler/targets/np_target_facts.pas`
  - `TTargetFactsView`
- `compiler/diagnostics/np_diagnostics_sink.pas`
  - `TDiagnosticsSink`
- `compiler/syntax/np_lexer.pas`
  - `TLexerResult`
- `compiler/syntax/np_green_tree.pas`
  - `TGreenTree`
- `compiler/syntax/np_ast_facade.pas`
  - `TAstFacade`
- `compiler/sema/np_semantic_model.pas`
  - `TSemanticModel`
- `compiler/sema/np_semantic_analyzer.pas`
  - `TSemanticAnalyzer`
- `compiler/ir/np_mir_model.pas`
  - `TMirModel`、`TMirLowerer`
- `compiler/backend/np_backend_plan.pas`
  - `TBackendPlan`、`TBackendPlanner`
- `compiler/frontend/np_unit_graph.pas`
  - `TSearchPathSet`、`TResolvedUnit`、`TUnitGraph`
- `compiler/frontend/np_unit_resolver.pas`
  - `TUnitResolver`

它们现在已经把 first-stage compiler spine 的第一条真实链路接进 session：

- source truth：root source 的 `FileId`、canonical path、source text、line-index state
- target truth：target id、target config path、host facts、compiler executable、object format、
  assembler flavor、linker flavor、LLVM triple、toolchain binding 与 backend family
- diagnostics truth：policy、aggregate count 与最小 structured syntax diagnostics
- syntax truth：token stream、immutable green tree 与 AST facade
- resolution truth：root source dir + `units/<target>/` search roots、explicit `UnitGraph`、
  `resolver.unit-not-found|resolver.ambiguous-unit-source|resolver.unit-cycle-detected`
- semantic truth：builtin canonical types、unit-level symbol graph、typed-hir root /
  resolved-unit / runtime-contract nodes，以及 `sema.duplicate-declaration`
- MIR truth：one entry block、one lowered op per typed-hir node、explicit `return`
- backend truth：output kind、primary artifact path、host-compiler tool invocation plan、
  toolchain binding id 与 target/backend metadata

同时，当前 `stage0 build` 已经会把这些 session 事实投影为 `session-id`、
`source-db-file-count`、`diagnostics-count`、`syntax-status`、`lexer-token-count`、
`green-node-count`、`ast-root-kind`、`resolution-status`、`unit-graph-status`、
`search-path-count`、`resolved-unit-count`、`unit-graph-edge-count`、
`unit-graph-root-name`、`semantic-status`、`symbol-graph-status`、`type-graph-status`、
`typed-hir-status`、`symbol-count`、`type-count`、`typed-hir-node-count`、
`runtime-contract-count`、`typed-hir-root-name`、`mir-status`、`mir-block-count`、
`mir-operation-count`、`mir-entry-block`、`mir-root-name`、`backend-plan-status`、
`backend-output-kind`、`backend-primary-artifact-kind`、`backend-primary-artifact-path`、
`toolchain-binding-id`、`backend-family`、`target-object-format`、
`target-assembler-flavor`、`target-linker-flavor`、`tool-invocation-count`、
`primary-tool-role`、`lifecycle-session`、`lifecycle-unit`、`lifecycle-stage` 和对应
envelope fields。对语法失败输入，driver 也已经会先经由 session 产出
`parser.syntax-error`，再以 `syntax-analysis-failed` 退出；对 unit resolution 失败输入，
driver 也会先经由 session 产出 `resolver.unit-not-found`、
`resolver.ambiguous-unit-source` 或 `resolver.unit-cycle-detected`，再以
`unit-resolution-failed` 退出；对当前最小语义失败输入，driver 也会先经由 session 产出
`sema.duplicate-declaration`，再以 `semantic-analysis-failed` 退出。这样 syntax、
resolution、sema、IR 和 backend plan 都已经直接挂到 session 上，而不是重新退回
driver 级全局状态。

## `unit` 解析必须是显式图，而不是路径拼接习惯

兼容性矩阵已经把 unit/module 行为写成硬目标，所以 nextPas 不能把 unit 解析继续当成
“driver 里顺手拼一下路径”的实现细节。

这份流水线规范要求：

- unit 关系以 `UnitGraph` 或等价结构显式表达。
- unit identity 优先由规范化的 `UnitId` 表达，而不是重复依赖大小写不稳定的原始字符串。
- import/use edge 必须可回放、可诊断、可缓存。
- 变更一个 unit 时，失效范围按 dependency edge 传播，而不是默认整仓重编。

第一阶段不需要一次做完完整增量编译器，但必须先把依赖图和失效模型设计清楚。
更细的 unit identity、search path 和 graph 规则由 `unit-resolution-specification.md` 定义。

## 诊断是结构化产品，不是副作用

为了让 `tests/diagnostics/`、快照、CI 和手工回放复用同一套结果语义，nextPas 推荐把
每条诊断都建模成结构化记录：

| 字段             | 说明                                                              |
| ---------------- | ----------------------------------------------------------------- |
| `DiagnosticCode` | 稳定错误代码或类别标识                                            |
| `Severity`       | `error` / `warning` / `note`                                      |
| `Phase`          | 诊断来自 lexer、syntax、resolution、sema、lowering 或 target path |
| `PrimarySpan`    | 主定位                                                            |
| `RelatedSpans`   | 相关定位集合                                                      |
| `Message`        | 面向人的主消息                                                    |
| `Notes`          | 附加说明、修复提示或上下文                                        |

这不要求第一阶段就冻结最终输出样式，但要求内部先冻结“诊断是数据”的事实。
更细的分类、定位、renderer 和 snapshot 规则由 `diagnostics-specification.md` 定义。

## 让运行时握手点保持显式

编译器流水线最终一定会和 `rtl/core/system/` 握手，但这种握手不应该靠隐式约定。

这份规范先冻结三个原则：

- 编译器引用的运行时协助点，优先通过显式 intrinsic 或显式 runtime contract 名称表达。
- `System` 启动、退出、初始化/清理相关语义，不应该散落在 backend 专用分支里。
- 如果某个 lowering 需要运行时参与，必须能说明它依赖的是哪一类 `rtl/core/` 行为，而不是
  模糊地“反正 runtime 会处理”。

更细的 `compiler <-> runtime` 握手边界由 `runtime-bootstrap-specification.md` 定义；
这里先把隐式耦合挡住。

## 把性能模型前置写清

nextPas 的性能设计不应该等系统做大后再补。至少要从一开始坚持这些策略：

- arena allocation 优先于跨阶段碎片化对象分配
- `string interning` / symbol interning 优先于重复拷贝字符串
- immutable `Green CST` 优先于可变语法树
- 单次 parse 结果优先复用，不做无意义重 parse
- unit 级失效优先于整仓级失效
- diagnostics batch emission 优先于阶段中散落输出
- target facts 单点读取，避免每个阶段自己推导 host/target 规则

如果未来某个实现选择违反这些规则，必须能明确证明收益，而不是因为“先写快一点”。

## `stage0`、`stage1` 与 `stage2` 如何接这条流水线

- `stage0`
  - 冻结公开 CLI、target facts、验证入口和最小 smoke 路径
  - 允许内部流水线还没有全部接管真实编译工作
  - 但新设计必须以这条 pipeline 为收敛方向
- `stage1`
  - 优先接管 `Lexer -> Green CST -> AST facade -> name resolution -> Typed HIR`
  - 同时把 diagnostics sink 从临时输出提升为核心数据面
- `stage2`
  - 在 `Typed HIR`、`MIR`、runtime handshake 和 target path 已稳定后，再调查更深的
    backend / self-hosting 接管

这意味着 pipeline doc 不是否定 `stage0`，而是给 `stage1` 和 `stage2` 画出不走回头路的骨架。

## 这条流水线故意不做什么

- 不把历史 FPC 内部结构原样翻译成新名字。
- 不在第一阶段承诺外部稳定 IR 格式。
- 不提前引入多目标 backend 矩阵。
- 不把运行时语义偷偷塞回 codegen 特例。
- 不把 diagnostics 继续留在命令行字符串拼接层。
- 不把性能优化留到“以后有性能问题再说”。

这份规范真正要交付的是：一条能承载 modern architecture、data-oriented performance 和
low-coupling elegance 的编译器主骨架。
