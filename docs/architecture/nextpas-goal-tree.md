# nextPas 目标树

这份目标树用来回答一个简单问题：nextPas 到底要做成什么，以及每一轮开发正在推进哪一块。

`master-roadmap.md` 说明长期产品顺序，`compiler-roadmap.md` 说明编译器接管顺序，
`bootstrap-roadmap.md` 说明 `stage0 -> stage1 -> stage2` 的所有权迁移。这份目标树把它们收成一张
可执行的能力地图。后续每个批次都应能指向这里的一个或多个节点，否则就是方向不清。

## 北极星目标

nextPas 要成为 Pascal 世界的现代开发平台：

- 有自己的 Pascal 编译器主干，而不是长期依赖宿主工具链替它判断语义。
- 有 nextPas-owned RTL / core / framework，让应用、工具、IDE 与包生态共享同一套基础能力。
- 有统一 workspace、package、env、doctor、query、test、bench、doc、fmt 与 language service。
- 能认真兼容 FreePascal 生态，同时用更现代的架构、诊断、工具链和开发体验超过历史惯性。

优秀不是“功能名很多”，而是这些能力同时成立：

- 正确：语法、语义、类型、unit、ABI、代码生成和工具链失败都可解释。
- 先进：前端、语义模型、IR、toolchain、workspace、package 和 IDE 不各自维护私有真相。
- 优雅：每层有清楚 owner、truth object、projection、promotion gate 和诚实非目标。
- 可维护：新增能力优先复用现有 session/model/tooling，不把逻辑复制到 driver 或 shell。
- 高性能：数据结构、增量分析、代码生成和工具调用能支撑真实项目，不只支撑 smoke fixture。

## 当前全局位置

截至 2026-05-28，当前 live baseline 是：

- 当前完成批次、验证证据和提交点以 `progress.md` / `task_plan.md` 的最新记录为准。
- fresh `bash build/verify_local.sh` 是本地权威 gate；每轮收口必须重新跑并记录
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Stage1 已拥有真实 compiler/tooling 主干：source/session、lexer/parser、unit resolver、semantic model、
  HIR/MIR、native/LLVM backend、toolchain runner、query/env/pkg/doctor/test surfaces 都已经进入验证面。
- `core/` 已开始成为 nextPas 未来 RTL + framework 的独立基础设施，但当前由 core 负责人推进；
  非 core 开发不得直接修改 `core/` 代码，只能提出 compiler/tooling 侧需求或 review 意见。
- 最大未完成面仍在 compiler correctness，尤其是语义系统：完整 overload resolver、完整 type checking、
  imported/inherited member no-match、unknown callable/member、record/property/array/deref receiver、
  implicit conversion、default parameter lowering/ranking、visibility 与更完整 FPC 兼容语义。

## 使用规则

每一轮开发开始前，先回答：

- 本轮推进哪个目标节点？
- 当前缺口是什么？
- 本轮交付哪个真实代码或验证能力？
- 本轮明确不做什么？
- fresh verification 里如何证明它完成？

每一轮收口时，记录：

- 目标节点编号。
- 新增或更新的测试 / gate。
- 实现文件。
- 文档和持续记录。
- fresh `bash build/verify_local.sh` 结果。
- 下一轮最自然的目标节点。

## G0: 项目控制面和质量纪律

目标：让 nextPas 的开发节奏可追踪、可验证、可回滚。

完整能力：

- 所有主线能力都有目标节点、owner、truth object、projection 与 promotion gate。
- `task_plan.md`、`progress.md`、`findings.md` 只记录当前事实，不包装未完成能力。
- `build/verify_local.sh` 是本地权威 verification gate。
- 每个真实改动批次都小步提交，commit 能独立回滚。
- 工作树污染、生成物、临时证据和 stale docs 不进入提交。

当前状态：

- `verify_local` 已成为主门。
- 持续记录已存在，但最近路线图顶部状态有过 Batch 状态漂移。
- 当前新增本目标树，后续批次必须绑定目标节点。

下一步证据：

- docs-check 校验本文件存在。
- 后续 `task_plan.md` addendum 明确写出目标节点。

## G1: Pascal 编译器语言能力

目标：让 nextPas 真正理解 Pascal，而不是只把简单 fixture 送到宿主编译器。

### G1.1 Source / session ownership

完整能力：

- `CompilationSession` 拥有 source database、target facts、options、diagnostics 和 lifecycle。
- 公开 command surface 只做入口和 projection，不私自重扫源码或拼接语义。
- CLI、query、doctor、package、language service 都消费同一份 session truth。

当前状态：

- session/source database 已落地。
- query surface 已从 compilation session 投影 symbols、bindings、definitions、scopes、types。

下一步证据：

- richer query 不得绕过 `TCompilationSession`。
- language service 雏形必须复用 session/model。

### G1.2 Syntax frontend

完整能力：

- Lexer、Green CST、AST facade 覆盖 Pascal 主流语法。
- 语法错误进入 diagnostics sink。
- 前端结构支持 future cheap reparse 和 IDE 增量分析。

当前状态：

- lexer/parser smoke、bench 和若干 syntax fixtures 已通过。
- parser 已支持大量当前 smoke 所需语法，但不是完整 FPC 语法覆盖。

下一步证据：

- 每补一种语法形态，都要有 parser fixture 和 downstream smoke。
- 不把语法缺口伪装成 sema 或 backend 问题。

### G1.3 Unit resolution

完整能力：

- `UnitGraph` 正式持有 root/interface/implementation/imported/implicit-runtime edge。
- search path、source root、installed unit、workspace member 和 package source root 可解释。
- missing unit、ambiguous unit、cycle、duplicate import、requested-name mismatch 都有结构化错误。

当前状态：

- resolver 已覆盖 root implementation uses、requested-name mismatch、explicit `System` source upgrade、
  multiple missing units、source root precedence、unit root precedence。
- search index 仍保持 lazy session truth，避免 eager 扫描副作用。

下一步证据：

- workspace/package source roots 继续进入 shared model，不回退到 driver path guessing。
- resolver 新错误必须进入 diagnostics 和 verify gate。

### G1.4 Semantic model

完整能力：

- Symbol graph、scope graph、type graph、constant/value facts 和 `Typed HIR` 是语义 truth。
- procedure/function/class/record/interface/property/generic/exception 都有正式语义表达。
- semantic model 能支撑 build、query、language service 和 refactor，不只是统计数量。

当前状态：

- symbol/type/scope/binding/definition projection 已存在。
- class method/member-call 正向绑定已推进多批。
- 参数、变量、literal 与 root-owned 零参 function result 的部分稳定 type facts 已用于
  `sema.type-mismatch`。

下一步证据：

- 扩展任何语义事实前，必须说明它是否稳定、是否跨 unit、是否会误伤 imported RTL/helper。
- 不稳定事实必须保持 deferred，不注册错误 binding。

### G1.5 Call, member, and overload resolution

完整能力：

- bare call、member call、constructor-like call、inherited member、Self receiver、imported receiver 都进入统一 resolver。
- overload 支持 arity、typed signature、default parameters、implicit conversions、ranking、visibility 和 ambiguity。
- no-match、unknown callable、unknown member、type mismatch 都能准确诊断。

当前状态：

- 已完成 ambiguity、wrong argument count、root-owned stable no matching overload、部分 single-target
  type mismatch。
- 已完成 source-owned bare unknown callable 与 direct class unknown member 的第一条结构化诊断。
- `sema.unknown-member` 已推进到 class method body bare implicit-self、inherited class context，
  以及 imported `project-source` unit method body 的 owner-aware traversal。
- imported `project-source` unit method body 的 inherited bare implicit-self unknown-member 已进入
  official gate。
- imported `project-source` unit method body 的 bare implicit-self known field invalid-call-shape
  已进入 official gate。
- imported `installed-source` unit method body 的 bare implicit-self known field invalid-call-shape
  继续 deferred，并由 semantic harness 固定防误报。
- imported `project-source` unit method body 的 bare implicit-self known property invalid-call-shape
  已进入 official gate。
- imported `installed-source` unit method body 的 bare implicit-self known property invalid-call-shape
  继续 deferred，并由 semantic harness 固定防误报。
- imported `project-source` unit method body 的 inherited bare implicit-self known field
  invalid-call-shape 已进入 official gate。
- imported `installed-source` unit method body 的 inherited bare implicit-self known field
  invalid-call-shape 继续 deferred，并由 semantic harness 固定防误报。
- imported `project-source` unit method body 的 inherited bare implicit-self known property
  invalid-call-shape 已进入 official gate。
- imported `project-source` unit method body 的 bare implicit-self wrong-argument-count 已进入
  official gate。
- imported `project-source` unit method body 的 bare implicit-self same-unit function-result
  wrong-argument-count 已进入 official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self wrong-argument-count 已进入
  official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self type-mismatch 已进入
  official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self same-unit
  function-result wrong-argument-count 已进入 official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self same-unit
  function-result no-matching-overload 已进入 official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self same-unit
  function-result ambiguous-overload 已进入 official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self no-matching-overload 已进入
  official gate。
- imported `project-source` unit method body 的 inherited bare implicit-self ambiguous-overload 已进入
  official gate。
- imported `project-source` unit method body 的 bare implicit-self type-mismatch 已进入
  official gate。
- imported `project-source` unit method body 的 bare implicit-self no-matching-overload 已进入
  official gate。
- imported `project-source` unit method body 的 bare implicit-self ambiguous-overload 已进入
  official gate。
- 仍未完成完整 overload resolver、implicit conversion、default parameter lowering/ranking、
  imported/member target no-match、non-project-source imported target type mismatch，以及非 source-owned /
  typecast / function-pointer 等更复杂 callable 边界。

下一步证据：

- 近期最高价值切片是继续补 non-core sema diagnostics/resolution。
- 优先做 source-owned、稳定事实明确、误报风险可控的 imported callable / no-match / unknown 边界。

### G1.6 Diagnostics

完整能力：

- 每个编译错误都有 code、phase、source range、subject、summary 和可消费 projection。
- CLI、IDE、CI 看到同一份 diagnostics。
- 错误信息不泄露内部临时路径或无关实现细节。

当前状态：

- 多类 compiler/sema/toolchain/package/env 错误已有结构化 projection。
- `sema.unknown-callable` 已覆盖 source-owned bare callable name miss。
- `sema.unknown-member` 已覆盖 receiver type 已知的 direct class member-call name miss、class
  method body bare implicit-self name miss、inherited class context，以及 imported
  `project-source` unit method body。
- `sema.unknown-member` 已覆盖 imported `project-source` unit method body 沿 parent chain
  仍找不到 bare implicit-self member name 的场景。
- `sema.invalid-call-shape` 已覆盖 imported `project-source` unit method body 中 known field
  被 bare implicit-self 当作 callable 使用的场景。
- imported `installed-source` unit method body 中 known field 被 bare implicit-self 当作 callable
  使用时继续 deferred，不提前发 `sema.invalid-call-shape`。
- `sema.invalid-call-shape` 已覆盖 imported `project-source` unit method body 中 known property
  被 bare implicit-self 当作 callable 使用的场景。
- imported `installed-source` unit method body 中 known property 被 bare implicit-self 当作 callable
  使用时继续 deferred，不提前发 `sema.invalid-call-shape`。
- `sema.invalid-call-shape` 已覆盖 imported `project-source` unit method body 中沿 parent chain
  命中的 inherited known field 被 bare implicit-self 当作 callable 使用的场景。
- imported `installed-source` unit method body 中沿 parent chain 命中的 inherited known field
  被 bare implicit-self 当作 callable 使用时继续 deferred，不提前发 `sema.invalid-call-shape`。
- `sema.invalid-call-shape` 已覆盖 imported `project-source` unit method body 中沿 parent chain
  命中的 inherited known property 被 bare implicit-self 当作 callable 使用的场景。
- `sema.wrong-argument-count` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self arity miss。
- `sema.wrong-argument-count` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self same-unit function-result arity miss。
- `sema.wrong-argument-count` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self target 后的 arity miss。
- `sema.type-mismatch` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self target 后的 stable literal mismatch。
- `sema.type-mismatch` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self target 后的 same-unit function-result mismatch。
- `sema.wrong-argument-count` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self target 后的 same-unit function-result arity miss。
- `sema.no-matching-overload` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self overload set 后的 same-unit function-result no-match。
- `sema.ambiguous-overload` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self overload set 后的 same-unit function-result ambiguity。
- `sema.no-matching-overload` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self overload set 后的 stable literal no-match。
- `sema.ambiguous-overload` 已覆盖 imported `project-source` unit method body 沿 parent chain
  找到 inherited bare implicit-self overload set 后的 stable literal ambiguity。
- `sema.type-mismatch` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self stable literal mismatch。
- `sema.type-mismatch` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self same-unit function-result mismatch。
- `sema.no-matching-overload` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self same-unit function-result no-match。
- `sema.ambiguous-overload` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self same-unit function-result ambiguity。
- `sema.no-matching-overload` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self stable literal no-match。
- `sema.ambiguous-overload` 已覆盖 imported `project-source` unit method body 的 bare
  implicit-self stable literal ambiguity。
- 语义错误覆盖仍不完整。

下一步证据：

- 每个新语义错误都要有 fail fixture、snapshot 或 stage0 gate。

## G2: IR、backend 和 toolchain

目标：让 nextPas 自己能从语义 truth 产出可靠可执行程序。

完整能力：

- `Typed HIR -> MIR -> backend -> artifact plan -> toolchain runner` 分层清楚。
- Native backend 和 LLVM backend 消费同一份 semantic / MIR truth。
- Object、assembly、LLVM IR、bitcode、executable、installed unit artifact 都有显式 plan。
- Toolchain failure 有 step attribution、trace、status events 和 diagnostics。
- ABI、calling convention、layout、debug info 和 optimization 有逐步冻结路线。

当前状态：

- HIR/MIR/backend/toolchain 链路已真实存在。
- native 和 LLVM smoke 很多都已进入 `verify_local`。
- later-step failure attribution、tool invocation plan、build trace 已收口。
- ABI compatibility 仍 deferred。

下一步证据：

- backend 不得重新做 sema/resolver 工作。
- 新 backend 能力必须通过 MIR/TargetFacts/ToolchainPlan 接入。

## G3: RTL、core 和 framework

目标：形成 nextPas-owned 标准库和应用框架，而不是长期依赖宿主 RTL。

完整能力：

- Base、mem、text、time、io、fs、process、thread、sync、net、http、json、crypto、logging、testing。
- Platform abstraction、error model、resource lifetime、allocator strategy 和 package layout 清楚。
- Future GUI/runtime/framework 与 compiler/tooling 共享基础层。

当前状态：

- 旧 `rtl/core/base`、`rtl/core/mem`、`rtl/core/text` 已服务 compiler/toolchain-first foundation。
- `rtl/core/system/` 已明确为 nextPas-owned 最小 `System` 平替落点；它要先支撑自举代码、
  `TObject`/对象生命周期和 `core` 框架的最低依赖，而不是继续依赖宿主 FPC `System`。
- 最小 source-backed `System.pas` / `TObject` truth 已落地：implicit runtime 语义层会读取
  target-installed `System.pas`，普通 class 默认继承 `System.TObject`，`Obj.Free` 可绑定到
  真实 `TObject.Free` method symbol；no-fold typed HIR 也会把继承路径上的 `Free` lowering 到
  当前有效 `Destroy` runtime call，并产生 `np.system.object_free` contract，记录 nil guard 与
  heap release intent。`THIRBuilder` 已把该 contract 投影成 HIR `np.system.object_free`
  intrinsic marker，保留 receiver pointer 与 effective `Destroy` target；紧随其后的匹配
  `Destroy` lowering 会标记成 `np.system.object_free.destroy` owned marker，而不是裸
  ordinary call；`heap-release true` 会继续成为 `np.system.object_free.release` marker。
  LLVM HIR emitter 已把这个 lifecycle group lowering 成 receiver nil branch，让 `Destroy`
  call 与 `@np_object_free_release` hook 位于非空 `objectfree.destroy.*` 分支并汇合到
  `objectfree.end.*`。class allocation lowering 也已从直接 `@np_alloc` 改为先调用
  `@np_object_alloc(i64 size)`；该 helper 当前申请 16-byte header + payload，在 header 里写
  payload size 与 magic，再返回 payload pointer。`@np_object_free_release` 会从 payload pointer
  回退读取 header 并校验 magic：合法 header 进入 `release:` 占位块，非法 header 进入
  `invalid:` 并调用 `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 后汇合到
  `done:`；invalid helper 当前会调用 `@llvm.trap()` 并发出 `unreachable`。`release:` 当前调用
  `@np_object_release_valid(ptr %raw, i64 %size)`，把已验证的 header raw pointer 与 payload size 交给
  compiler-owned release boundary；该 helper 当前会把 header magic 清零，使重复释放同一 payload
  pointer 后续进入 invalid-release trap。当前这仍只是最小 ownership contract，不是 allocator free、
  结构化 diagnostics / Pascal exception 或完整 validation runtime。
  显式 `uses System` 仍可升级到 explicit source provenance。
- 新 `core/` 已开始 L0/L1 基础设施。
- 当前协作边界：core 由 core 负责人写，非 core 批次不直接修改 `core/`。

下一步证据：

- 继续扩展 `System` source truth：把 `np_object_alloc` / `np_object_free_release` helper 从 header
  ownership + magic validation + release poison + invalid-release trap 接到 allocator free、结构化
  diagnostics、完整 dynamic dispatch 与 backend/runtime helper，并推进 unit init/fini。
- compiler/tooling 侧只提出 core 需求和 integration contract。
- 需要 core 改动时，先形成 review/suggestion，不直接落 core 代码。

## G4: Workspace 和 package system

目标：让项目、包、依赖、target、artifact 和 install plan 有统一 truth。

完整能力：

- Workspace descriptor、package manifest、lockfile、dependency resolver、source graph、target graph。
- `pkg inspect/plan/graph/fetch/install/publish` 按阶段进入。
- Package manager 不绕过 workspace/toolchain/distribution truth。
- Artifact root、cache root、source root、install root 分明。

当前状态：

- `pkg inspect / pkg plan / pkg graph` 是只读 truth surface。
- install plan 是 preflight truth，支持 ready/blocked/missing 和 blocker detail。
- 尚未实现 resolver/fetch/install/publish。

下一步证据：

- 短期不打开完整 package manager。
- 先继续补齐 package/workspace truth 的只读和 preflight 边界。

## G5: Developer tools

目标：让 nextPas 日常开发可用、可诊断、可自动化。

完整能力：

- `nextpas build/test/query/doctor/env/pkg/fmt/doc/bench` 共享 command surface。
- 所有工具输出 line-based human projection 和 machine-readable envelope。
- `doctor` 解释健康问题，`env` 处理本机环境选择，`pkg` 处理包图，`query` 处理编译器语义查询。

当前状态：

- `build/test/query/doctor/env/pkg` 的最小面已存在。
- `fmt/doc` 尚未成为主线。
- `query` 受当前 sema 完整度限制。

下一步证据：

- richer tool 先复用 shared model，不创建第二套 project truth。
- 新工具必须能进入 `verify_local` 或 dedicated test gate。

## G6: Language service、IDE 和 GUI

目标：让 nextPas 形成 compiler-backed IDE，而不是编辑器插件和 CLI 各写一套分析器。

完整能力：

- Diagnostics、completion、hover、goto definition、references、rename、semantic highlighting。
- Incremental source overlay、workspace graph、package graph、target-aware analysis。
- IDE workbench 建立在 nextPas GUI/runtime/framework 上。

当前状态：

- `query symbols/bindings/definitions/scopes/types` 是 language service 的前置事实。
- 尚未实现真正 LSP、open document overlay、incremental invalidation 或 IDE。

下一步证据：

- 先补 sema/query truth，再开 LSP。
- IDE 不得拥有第二套 parser、workspace model 或 package graph。

## G7: FreePascal compatibility 和生态迁移

目标：认真兼容 FPC 生态，同时明确 nextPas 自己的现代边界。

完整能力：

- FPC 源码取证驱动设计，而不是只靠记忆复刻。
- 建立 compatibility matrix，区分 supported、partial、deferred、not planned。
- 能编译逐步变大的真实 Pascal 项目。
- 提供迁移指南、错误解释、包生态和标准库对照。

当前状态：

- docs 已要求以 `/home/dtamade/projects/fpc` 作为兼容性取证来源。
- 当前仍主要依赖 curated fixtures 和 smoke programs。

下一步证据：

- 每次声称兼容 FPC 行为，都要能指向真实源码取证或 dedicated fixture。
- 不把“能过当前 smoke”说成“已完整兼容”。

## G8: Performance、scalability 和 reliability

目标：让 nextPas 不只正确，还能支撑真实项目规模。

完整能力：

- Lexer/parser/sema/query 有可追踪性能基线。
- Incremental analysis、lazy index、artifact reuse、cache invalidation 有清楚策略。
- Toolchain runner 能可靠处理中断、失败、sidecar cleanup 和并发。
- 大项目不会因为 eager scanning、重复物化 AST 或私有 cache 爆炸。

当前状态：

- lexer/parser/sema bench 已在 `verify_local` 中使用 process CPU timing。
- search index 采用 lazy truth。
- 并发和大型 workspace 还不是主线完成项。

下一步证据：

- 每个性能相关改动先保正确性，再补 benchmark gate。
- 不为“看起来完整”引入 eager 全量扫描。

## 当前优先级

P0：保持项目控制面真实。

- 所有新批次绑定目标节点。
- `verify_local` 必须 fresh pass。
- 不碰 `core/` 代码。

P1：补 compiler semantic correctness。

- 继续推进 G1.4 / G1.5 / G1.6。
- 近期优先做 source-owned、稳定事实明确的 call/member diagnostics。

P2：巩固 workspace/package/query。

- 等 sema truth 更稳后，继续推进 G4/G5 的只读 truth 和 preflight。
- 暂不打开完整 package manager。

P3：强化 backend/toolchain。

- 在 sema/resolver 不拖后腿后，继续扩 G2 的 ABI、layout、debug info、optimization。

P4：对接 core/framework。

- core 团队推进实现。
- 编译器侧保持 integration requirements、verification hooks 和 compatibility feedback。

## 每轮报告格式

后续每轮开始时，用这五行报告：

```text
目标节点：
当前缺口：
本轮交付：
验证方式：
本轮不做：
```

后续每轮结束时，用这五行复盘：

```text
完成节点：
新增能力：
验证结果：
剩余风险：
下一节点：
```

这就是节奏控制面。只要每轮都能填清楚，就不会再回到“继续了很多轮但不知道离目标多远”的状态。
