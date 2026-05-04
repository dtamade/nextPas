# nextPas 编译器规范

用这份规范定义 nextPas 第一阶段 `compiler/` 的稳定边界。它回答的不是“编译器以后可以
做得多大”，而是“在当前以 FreePascal 为 `stage0` 的基线上，哪些编译器职责必须先被
明确分层，哪些模块需要保留显式所有权，哪些内容继续延后”。

## 先把 `compiler/` 当作稳定边界，而不是历史源码树的镜像

nextPas 保留 `compiler/` 作为外部可识别边界，是为了延续 FreePascal 生态中熟悉的
仓库形状；但它不应该把 FPC 现有的平铺式编译器树直接复制过来。

`/home/dtamade/projects/fpc/compiler` 已经证明，上游编译器目录同时承载了目标平台、
驱动、消息、代码生成与大量历史单元。nextPas 第一阶段要保留的是“编译器是一等系统边界”
这一事实，而不是照搬这种组织方式。

因此，`compiler/` 的首要职责是把语言前端、语义、诊断、目标约束和驱动控制面分清，
让后续 `stage1` 接管时有明确落点。

如果你要看比“模块职责”更深一层的数据流、所有权和性能约束，继续读
`docs/architecture/compiler-pipeline-specification.md`。如果你要看编译器如何与
`rtl/core/system/` 做显式启动握手，继续读 `docs/architecture/runtime-bootstrap-specification.md`。
如果你要看 `sema` 如何把 symbol、scope、type 和 `Typed HIR` 收成正式语义核心，继续读
`docs/architecture/semantic-model-specification.md`。
如果你要看 `diagnostics` 如何把结构化分类、快照留证和 toolchain failure 收成稳定边界，
继续读 `docs/architecture/diagnostics-specification.md`。
如果你要看 host/target/toolchain/sysroot 怎样在当前单目标基线上仍保持正式分离，继续读
`docs/architecture/cross-compilation-specification.md`。
如果你要看 nextPas 为什么不只是 compiler、以及 build tools 和 developer-facing tools
怎样共享同一套控制面，继续读 `docs/architecture/toolchain-specification.md`。
如果你要看 `backend` 如何消费 `MIR`、`TargetFacts` 和 output path，而不是重做语义判断，
继续读 `docs/architecture/backend-specification.md`。
如果你要看 LLVM backend 怎样作为正式 adapter 接到同一条 backend contract 上，继续读
`docs/architecture/llvm-backend-specification.md`。
如果你要看 C ABI、external symbol 与 C library linking 如何形成正式编译器事实，继续读
`docs/architecture/c-interop-specification.md`。
如果你要看 unit identity、search path 和 `UnitGraph` 如何被正式建模，继续读
`docs/architecture/unit-resolution-specification.md`。

## 把八个子模块的职责先冻结下来

第一阶段对 `compiler/` 内部至少保留以下子模块边界：

| 子模块        | 第一阶段职责                                                | 不做什么                                    |
| ------------- | ----------------------------------------------------------- | ------------------------------------------- |
| `frontend`    | 建立编译会话、摄取源码输入、组织 unit 查找与编译上下文      | 不把语义和代码生成逻辑混进输入编排          |
| `syntax`      | 接受受支持的 FreePascal 源码形式，并把词法/语法结果交给下游 | 不自行定义新语法表面                        |
| `sema`        | 承接类型检查、符号解析、可观察正确性的语义判断              | 不把目标平台或运行时策略写成隐式副作用      |
| `ir`          | 作为语义分析与后续代码生成之间的内部表示边界                | 不在第一阶段承诺固定外部 IR 格式            |
| `backend`     | 承接语义分析下游的代码生成所有权区域                        | 不在 `stage0` 就承诺 nextPas 已自有完整后端 |
| `targets`     | 定义目标平台限制、布局假设和与编译器相关的目标能力视图      | 不绕开外置目标规格私自维护另一套平台事实    |
| `driver`      | 负责编译控制流、命令意图落地和对子模块的高层调度            | 不扩张成包管理器或泛化工具入口              |
| `diagnostics` | 提供确定性的错误分类、稳定输出规则和留证友好的诊断表面      | 不把所有失败都压成模糊基础设施错误          |

这八个边界的目的，是让 nextPas 能逐步接管编译器职责，同时维持对外兼容承诺的可解释性。

## 编译器控制流必须保持可分层

第一阶段不要求 nextPas 立即拥有完整自有编译器，但要求编译器控制流具备清晰的责任拆分：

1. `driver` 接收公开构建意图，并把输入与目标约束转成一次受控编译会话。
2. `frontend` 负责建立会话、处理源码入口、组织 unit/module 查找。
3. `syntax` 负责把受支持源码形式转成可被下游消费的结构化结果。
4. `sema` 负责做出影响正确性的语义判断，并把失败送入 `diagnostics`。
5. `ir`、`backend` 与 `targets` 负责承接下游表示、目标约束和生成路径。
6. `diagnostics` 负责把失败分类、输出和快照留证规则稳定下来。

这条链路先冻结意图，再允许实现逐步填充。第一阶段真正需要的是“责任顺序稳定”，
而不是把每个内部数据结构都提前写死。

## 把 `stage0` 和 `stage1` 的编译器所有权分开

`compiler/` 规范必须同时服务当前 `stage0` 基线和后续 `stage1` 接管，因此要把
阶段边界说清：

- `stage0`：公开命令表面由 `tools/stage0/nextpas.pas` 承担，FreePascal 继续托管
  实际编译宿主角色。此时 `compiler/` 更像 nextPas 预留和冻结的所有权地图，而不是
  已完整接管的实现目录。
- `stage1`：nextPas 开始优先接管 `frontend`、`syntax`、`sema`、`driver` 和
  `diagnostics` 这些直接决定源码兼容、语义判断和诊断稳定性的模块。
- `stage2`：只有在兼容性证据足够成熟时，才允许继续调查更深的自托管或后端替换路径。

这意味着 `backend`、`ir` 和更深的目标细节在第一阶段可以先保持受约束的演进状态，
但 `frontend`、`sema`、`driver` 和 `diagnostics` 的职责边界必须提前写清。

## 当前仓库里已经落地的 Batch 3/4/5/6/7 skeleton

`Batch 3/4` 的目标不是再补一份 session 愿景，而是把最小拥有关系和 syntax front baseline
一起落到真实仓库实体里。
当前实现已经把这些对象写进 `compiler/`：

- `compiler/frontend/np_source_database.pas`
  - `TSourceDatabase`
- `compiler/frontend/np_compilation_session.pas`
  - `TCompilationSession`
- `compiler/frontend/np_workspace_model.pas`
  - `TWorkspaceModel`、`TPackageRef`、`TTargetSelection`、`TArtifactRootSet`
- `compiler/frontend/np_package_manifest.pas`
  - `TPackageManifestInfo`、`TProjectUnitRootInfo` 与 workspace model 所需的 typed inputs
- `compiler/frontend/np_unit_graph.pas`
  - `TSearchPathSet`、`TResolvedUnit`、`TUnitGraph`
- `compiler/frontend/np_unit_resolver.pas`
  - `TUnitResolver`
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

这组实体当前的职责故意很小：

- `TSourceDatabase` 先统一 root source 与 resolved unit source 的 `FileId`、canonical path、
  source text 和 line-index state
- `TWorkspaceModel` 先统一 workspace root / discovery、package refs、project source roots、
  artifact root / output dir / host-fpc cache root 与 target selection
- `np_package_manifest.pas` 现在继续保留 parser 职责，但已经为 shared workspace model
  提供 typed package/root info 输入
- `TTargetFactsView` 先统一 target id、config path、host facts、compiler executable，以及
  object format / assembler flavor / linker flavor / runtime layout key /
  C symbol prefix / C library naming / LLVM triple / LLVM data layout /
  toolchain binding / host compiler profile / sysroot mode / runtime SDK / backend family
- `TDiagnosticsSink` 先统一 diagnostics policy、session-level count，以及 split
  error/warning accounting 和 structured compile/toolchain diagnostics
- `TCompilationSession` 先把这些 owned truth 收到同一个 build session 下，并显式暴露
  session-level / unit-level / stage-level lifecycle summary、diagnostics error/warning split，
  以及 syntax / resolution / semantic / MIR / backend 状态与 resolution search-index state；
  当前它也正式拥有 `WorkspaceModel`，resolver 与 toolchain planner 都从 model 读取
  `ProjectUnitRootInfos` / `ProjectUnitRoots`
- `TSearchPathSet`、`TResolvedUnit` 与 `TUnitGraph` 先把最小 unit identity、search roots 和
  root/interface/implementation/implicit-runtime edge 收成显式对象
- `TUnitResolver` 先把 missing / ambiguous / cycle 三类正式 resolution failure 接回
  compiler session
- `TSemanticModel` 先把 unit-level symbol count、builtin type count、typed-hir node count、
  runtime contract count、root name 与 semantic status 固定下来
- `TSemanticAnalyzer` 先把 builtin canonical type、resolved unit symbol、runtime contract seed
  和 duplicate import semantic failure 接回 compiler session
- `TMirModel` 与 `TMirLowerer` 先把 typed-hir nodes 下沉成 one-entry-block、target-neutral op list
  与显式 `return`
- `TBackendPlan` 与 `TBackendPlanner` 先把 `MIR + TargetFacts + SourcePath` 下沉成 output intent、
  primary artifact 与 host-compiler invocation plan，并显式携带 primary tool
  profile / step / logical executable / sysroot / failure mapping
- `TLexerResult`、`TGreenTree` 与 `TAstFacade` 先提供最小语法前端基线，不把 mutable AST 或
  临时 parser state 塞回 driver

当前 compiler / driver 的 workspace owner 边界也已经开始真实收口：

- `tools/stage0/nextpas.pas` 现在会先调用 `ResolveWorkspaceModel(...)`
- `TCompilationSession` 在创建后正式接管 model 生命周期
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 当前已经把
  explicit workspace、nearest package manifest 与 workspace member 的 shared model contract
  纳入真实 verification path

更关键的是：这套 skeleton 已经被 `tools/stage0/nextpas.pas` 的 `build` path 实际创建，
而不是只在 `compiler/README.md` 或本规范里作为名词存在。`stage0 build` 现在已经会先跑
syntax analyze 与 unit resolution，再把 `syntax-status`、`lexer-token-count`、
`green-node-count`、`ast-root-kind`、`resolution-status`、`unit-graph-status`、
`diagnostics-count`、`diagnostics-error-count`、`diagnostics-warning-count`、
`search-path-count`、`search-index-status`、`indexed-search-root-count`、
`search-index-scan-count`、`resolved-unit-count`、`unit-graph-edge-count`、`semantic-status`、
`symbol-graph-status`、`type-graph-status`、`typed-hir-status`、`symbol-count`、
`type-count`、`typed-hir-node-count`、`runtime-contract-count`、`typed-hir-root-name`、
`mir-status`、`mir-block-count`、`mir-operation-count`、`mir-entry-block`、`mir-root-name`、
`backend-plan-status`、`backend-output-kind`、`backend-primary-artifact-kind`、
`backend-primary-artifact-path`、`host-id`、`toolchain-binding-id`、`backend-family`、
`target-object-format`、`target-assembler-flavor`、`target-linker-flavor`、
`target-runtime-layout-key`、`target-c-symbol-prefix`、`target-c-library-naming`、
`target-llvm-triple`、`target-llvm-data-layout`、`sysroot-mode`、`runtime-sdk-id`、
`allow-host-fallback`、
`tool-invocation-count`、`primary-tool-role`、`primary-tool-profile-id`、
`primary-tool-step-id`、`primary-tool-logical-executable`、
`primary-tool-sysroot-ref`、`primary-tool-failure-mapping` 和
`parser.syntax-error|resolver.unit-not-found|resolver.ambiguous-unit-source|resolver.unit-cycle-detected`
失败路径投影到统一 command result bridge 上。对当前最小语义失败输入，driver 也会先经由
session 产出 `sema.duplicate-declaration`，再以 `semantic-analysis-failed` 退出。
当前宿主 compiler execute step 也开始对齐 backend plan 派生的
`toolchain.host-compiler-exec-failed`，而不是继续停留在 driver 私有的
`compiler-launch-failed` / `build-failed` 文本。
而且这条 host-compiler failure 现在已经不再只是 `failure-kind`：它还会作为一条
`phase=toolchain` 的 structured diagnostic 进入 envelope，并携带
`bindingId/profileId/stepId/logicalExecutable/sysrootRef/resolvedPath/primaryArtifact/exitCode`。

这也意味着当前编译器 skeleton 已经开始对“会话拥有的事实”给出更细粒度但诚实的投影：

- `TDiagnosticsSink` 当前不只提供 total count，还显式区分 `ErrorCount` 与
  `WarningCount`
- `warning-as-error` 当前不会再把 promoted warning 留在 warning bucket；
  它会以 `severity=error` 进入 structured diagnostic，并计入 error count
- `TCompilationSession` 当前会把 diagnostics split 继续投影成
  `diagnostics-error-count`、`diagnostics-warning-count` 与 envelope 对应 camelCase 字段
- `TCompilationSession` 当前还会把 resolver 的 lazy search-index 状态投影成
  `search-index-status`、`indexed-search-root-count` 与 `search-index-scan-count`
- 因此 `examples/smoke/hello.pas` 这类不需要额外 unit lookup 的路径，当前如实表现为
  `search-index-status=deferred`；而 `examples/smoke/hello_with_units.pas` 这类真实消费
  search roots 的路径，则会表现为 `search-index-status=ready`

## `unit`、语义和诊断是编译器规范的硬边界

根据兼容性矩阵和 ADR，以下三类事项在编译器规范中必须被视为硬边界：

- `Source syntax`：`syntax` 需要围绕受支持的 FreePascal 源码形式建立清晰边界。
- `Core semantics`：`sema` 需要承接类型、控制流、符号解析和其他可观察语义判断。
- 单元/模块行为：`frontend` 与 `sema` 共同负责让 unit 命名、查找和依赖关系保持可解释。

与此同时，`diagnostics` 也必须被当作硬边界，而不是附属输出：

- 诊断分类要足够稳定，能被 `tests/diagnostics/` 和快照机制长期消费。
- 失败语义要与 `compiler-pass`、`compiler-fail`、`diagnostics` 三类测试桶对齐。
- 编译器失败不能只表现为“命令失败了”，而要有便于留证和回放的确定性表面。

如果这三块边界没有先被文档化，后续实现就会把兼容性、`unit` 行为和诊断输出重新混回
单个工具入口里。

## 编译器规范必须和目标规格、运行时、测试一起工作

`compiler/` 不是孤立系统，它至少要与下面几份规范保持一致：

- `stage0-driver-specification.md`：`driver` 负责承接公开构建意图，但不重复定义 CLI。
- `target-platform-specification.md`：`targets` 负责消费目标事实，而不是发明第二套平台配置。
- `semantic-model-specification.md`：`sema` 负责哪些核心对象、哪些语义结论，以及
  `Typed HIR` 应该长成什么样。
- `diagnostics-specification.md`：`diagnostics` 如何冻结分类、定位、snapshot 和
  toolchain failure。
- `cross-compilation-specification.md`：host/target/toolchain/sysroot 如何保持正式分离，
  而不破坏当前单目标基线。
- `toolchain-specification.md`：assembler/linker/archiver/resource tool 与 developer-facing
  tool surface 如何收敛到同一套 toolchain control plane。
- `unit-resolution-specification.md`：`frontend` 与 `sema` 如何共享 unit identity、
  search path 和 `UnitGraph`。
- `runtime-bootstrap-specification.md`：`frontend`、`sema`、`ir` 与 runtime helper 的交界
  必须保持显式。
- `backend-specification.md`：`ir`、`backend`、`targets` 和产物路径如何形成正式 contract。
- `llvm-backend-specification.md`：LLVM backend 如何作为 `Codegen adapter` 的一种实现工作。
- `c-interop-specification.md`：foreign ABI、symbol naming 与 C library linking 如何冻结。
- `rtl-specification.md` 与 `crt-specification.md`：`frontend`、`sema` 和运行时约束要能解释
  unit/运行期边界如何配合。
- `test-harness-specification.md`：编译器成功、失败和诊断路径都必须能进入现有测试分桶。

这也是为什么编译器规范要强调“接口边界”，而不是只列模块名。

## 第一阶段不把编译器写成这些东西

- 不把 `compiler/` 写成 FPC 平铺目录的逐文件镜像。
- 不把 `driver` 扩展成包管理器、IDE 或 LSP 入口。
- 不把 `targets` 变成多平台矩阵系统；第一阶段仍只服务 Linux x86_64。
- 不在 `syntax` 或 `sema` 中引入 `No new syntax` 之外的新语言表面。
- 不把 `ir`、`backend` 的当前设计写成已经对外承诺的稳定二进制接口。
- 不把编译器内部边界写成“等实现时再决定”的占位话术。

第一阶段要交付的是一份能约束 `stage1` 接管顺序、测试接口和诊断稳定性的编译器规范，
而不是一份试图提前描述完整自托管编译器的愿景稿。
