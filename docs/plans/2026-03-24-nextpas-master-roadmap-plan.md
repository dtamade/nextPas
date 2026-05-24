# nextPas 主路线图实施计划

> **执行提示：** 必须使用 `superpowers:executing-plans`，按批次执行这份计划。

- 状态：采用中
- 日期：2026-03-24
- 范围：phase1 收口之后，nextPas 当前主线批次的活动入口

## 用这份计划把“总控路线图”变成当前执行面

`docs/architecture/master-roadmap.md` 负责长期产品顺序，
`docs/architecture/compiler-roadmap.md` 负责 compiler execution spine，
这份计划负责当前 rolling window 里的执行批次。它不改写已完成的 phase1 历史，
也不把 support/evidence 升格成新的稳定边界。各批次里的 promotion gate /
已交付描述保留各自批次当时的局部事实；当前 production-path contract
以最新完成的 `Batch 47` 为准。

如果你要看已完成的 phase1 主计划与实施计划，继续读：

- `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
- `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`

如果你要看这一轮之后 nextPas 的长期架构主线，读：

- `docs/architecture/master-roadmap.md`
- `docs/architecture/compiler-roadmap.md`

## 当前状态

- phase1 自举与实施计划已经完成并冻结为历史入口。
- **Stage1 已完成**：nextPas 已接管前端、语义分析、IR、后端和工具链集成。
  FreePascal 仅作为宿主编译器构建 nextPas 自身。详见 `docs/architecture/stage1-completion-assessment.md`。
- `stage0 build`、`test harness` 与 `build/verify_local.sh` 的 envelope baseline 已真实落地。
- 当前 freshest verification evidence 是 fresh `bash build/verify_local.sh`，
  其中 `toolchainContractCheck=pass`、`semanticSmokeCheck=pass`、
  `toolchainFailureCheck=pass`、`assemblerFailureAttributionCheck=pass`、
  `linkerFailureAttributionCheck=pass`、`stage0EnvStatusCheck=pass`、
  `stage0DoctorCheck=pass`、`stage0DoctorPackageWorkspaceCheck=pass`、
  `stage0EnvUseCheck=pass`、
  `stage0DoctorWorkspaceMemberCheck=pass`、
  `stage0DoctorInvalidArgumentsCheck=pass`、
  `stage0QueryCheck=pass`、`stage0QueryInvalidArgumentsCheck=pass`、
  `stage0PkgCheck=pass`、`stage0PkgWorkspaceMemberCheck=pass`、
  `stage0PkgInvalidArgumentsCheck=pass`、
  `stage0EnvInvalidArgumentsCheck=pass`、`multipleMissingUnitsCheck=pass` 与
  `verify-local=pass` 已继续转绿；`env status`
  readiness evidence 已投影 `environmentStatus`、`toolchainBindingStatus` 与
  `distributionStatus`，`env use` 已把 workspace-local preferred binding selection 写入
  `ArtifactRootSet/env/selections` sidecar 并可被后续 `env status --workspace` 读取，`doctor`
  result contract 也已投影 `doctorFindings[]`、workspace
  readiness 与 binding readiness，并把 package workflow truth 与
  `doctor.package-workspace-missing` 这条 package/workspace coherence finding 一并纳入只读
  inspection，并用 package manifest fixture 与 workspace member fixture 冻结了 ready
  package workspace 不会误报 `doctor.package-workspace-missing`，`query symbols` 也已投影
  `analysisSource=compilation-session`、`queryResultCount`、session-owned symbol detail
  与可读 owner/scope/type metadata，并同步投影 session-owned `queryScopes` / `queryTypes`
  side tables，`pkg inspect` 也已投影
  `packageWorkflowStatus`、`packageManifestStatus`、`packageSourceRootCount`、
  `packageSourceRoots`、`packageDependencyCount`、`packageDependencies`、
  `packageDependencyValidationStatus`、`packageDependencyIssueCount`、`packageDependencyIssues`、
  `packageInstallPlanStatus`、`packageInstallPlanBlockerCode` 与
  `packageInstallPlanBlockerMessage`；`packageLockStatus` 现在根据 canonical lockfile 是否存在
  投影 `ready|missing`，`packageInstallPlanStatus` 继续作为只读 preflight truth，投影
  `ready|blocked|missing` 并在有阻塞时公开 blocker 详情；并继续冻结
  `packageWorkflowManifestPath`、`packageRootPath`、`packageName`、`packageLockStatus` 与
  `packageLockfilePath`；workspace member fixture 也已让
  `pkg inspect` 覆盖 workspace descriptor root 解析到 member package 的 ready 路径，declared
  dependencies fixture 也已让 `doctor` / `pkg inspect` 同时冻结 package manifest root 与
  workspace descriptor root + member package 的 dependency intent 投影。
- 这份计划从现在起接管”当前主线的批次顺序”。
- `Batch 1` 到 `Batch 46` 已完成。
- 当前滚动批次继续建立在已经存在的
  nextPas-native `rtl/core/base` + `rtl/core/mem` + `rtl/core/text` foundation，以及 refined
  `TargetFacts` / sysroot / LLVM / C interop control plane 之上；近期优先级继续保持
  convergence-first 收口：shared workspace truth 已经收口到 compiler-owned model，
  typed `TToolchainPlan` 已具备真实 execution contract，backend 也已经拥有 binding-aware
  intermediate artifact truth：默认 native binding 走
  `assembly-text/object-file/executable`，显式 LLVM binding 走
  `llvm-ir/llvm-bitcode/object-file/executable`；当前默认 production path 维持
  `bootstrap-native-assemble-link`，显式 LLVM binding 也已能真实切到
  `llvm-ir-opt-llc-link`，later-step failure attribution 与 success-path observability
  transcript 都已收口到完整 multi-step trace。`doctor` 的第一条只读 health inspection、
  最小 structured finding contract、`query symbols` 的第一条 compilation-session-backed
  semantic query 与 `pkg inspect` 的第一条 workspace-model-backed package workflow projection
  也已进入统一 command surface。`Batch 36` 又把 stage0 driver decomposition、
  projection helper ownership、malformed manifest graceful fallback、diagnostic record
  extensibility 与 resolver search-index staleness tracking 收成当前最新 verified baseline。
  `Batch 37` 继续把 `query symbols` 从 aggregate count 加固为 session-owned symbol detail
  projection，line-based `query-symbols` 与 envelope `querySymbols` 都来自同一份
  `TSemanticModel`。`Batch 38` 则继续把 raw ids 加固成可读 semantic metadata：
  `ownerUnitName` 来自同一份 `TUnitGraph`，`scopeKind` / `scopeName` 来自
  `TSemanticScope`，`typeName` / `typeKind` 来自 `TSemanticType`。`Batch 39` 再把
  `TSemanticScope` / `TSemanticType` graph 作为 normalized `queryScopes` / `queryTypes`
  side tables 投影出来，让调用方不用在 `querySymbols` 之外维护第二套 lookup。`Batch 40`
  则把 `doctor` 的只读 health inspection 继续接上 package/workspace truth：当 workspace
  没有 package truth 时，会同步投影 `package-workflow-status`、
  `package-manifest-status`、`package-lock-status`、
  `package-install-plan-status`、`package-install-plan-blocker-code`、
  `package-install-plan-blocker-message`、`package-source-root-count` 与
  `package-source-roots`，并给出
  `doctor.package-workspace-missing`。`Batch 41` 再把同一条 coherence contract 的正向样本
  纳入 gate：合法 package workspace 会稳定投影 package workflow ready，且不会误报
  `doctor.package-workspace-missing`。`Batch 42` 则把 ready contract 扩展到 workspace
  descriptor root + member package：explicit workspace root 会稳定投影 descriptor path、
  member package manifest/root/name/lockfile 与 source root count，且不会误报
  `doctor.package-workspace-missing`。`Batch 43` 再把同一条 workspace member ready
  contract 扩展到 `pkg inspect`：只读 package workflow projection 也会稳定投影 descriptor
  path、member package manifest/root/name/lockfile 与 source root count。`Batch 44` 继续把
  package workflow truth 已经持有的 `SourceRoots` 提升为 `package-source-roots` /
  `packageSourceRoots`，让 CLI、IDE 与 automation 不需要回头重读 manifest。`Batch 45` 再把
  `[dependencies]` declared intent 提升为 `package-dependency-count` /
  `package-dependencies` 与 envelope `packageDependencyCount` / `packageDependencies`，但仍不执行
  dependency resolution、fetch/install 或 lockfile write。`Batch 46` 则继续把 dependency
  requirement 的最小 comparator grammar 收进 manifest / workflow truth，并让 malformed
  dependency intent 通过 `package-dependency-validation-status`、
  `package-dependency-issue-count`、`package-dependency-issues` 与 envelope camelCase 字段
  在 `doctor` / `pkg inspect` 中可见、可解释，避免 IDE、CI 或 automation 消费不可信的
  package declaration。下一步优先继续 richer package workflow / richer query / richer env
  action 中最高价值的真实功能切片。

## 执行规则

- 继续使用 `docs/plans/2026-03-24-nextpas-iteration-mode-plan.md` 定义的批次推进模式。
- 每一批都必须同时收口：真实仓库实体、相关文档、验证命令、fresh evidence。
- 仍按文档权威顺序执行：`docs/adr/` > `docs/architecture/` > 本计划 > `docs/plans/support/` > `.sisyphus/evidence/`。
- 仍保持 Linux x86_64、FreePascal `stage0`、无新语法、`ABI compatibility is deferred` 这四条硬护栏。
- 在上一批 promotion gate 未通过前，不打开下一批的更深层实现。
- 允许先做文档和最小 skeleton，但不允许把“只有计划”当作批次完成。
- 当前 rolling window 虽然继续服务产品主路线，但 compiler 相关批次仍应优先服从
  `docs/architecture/compiler-roadmap.md` 的接管顺序。

## 先看当前 rolling window

```text
Batch 1 -> Batch 2 -> Batch 3 -> Batch 4 -> Batch 5 -> Batch 6 -> Batch 7 -> Batch 8 -> Batch 9
   |         |         |         |         |         |         |         |         |
   |         |         |         |         |         |         |         |         +-> rtl/core/text foundation + compiler integration
   |         |         |         |         |         |         |         +------------> rtl/core/base + rtl/core/mem foundation
   |         |         |         |         |         |         +----------------------> MIR / backend / toolchain boundary skeleton
   |         |         |         |         |         +--------------------------------> Semantic model / Typed HIR skeleton
   |         |         |         |         +------------------------------------------> UnitGraph / name resolution skeleton
   |         |         |         +----------------------------------------------------> Lexer / Green CST / AST facade skeleton
   |         |         +--------------------------------------------------------------> CompilationSession / Source database skeleton
   |         +------------------------------------------------------------------------> Control-surface conformance
   +---------------------------------------------------------------------------------> verify-local envelope baseline
```

前九批是当前最小但连续的执行链。它们共同对应 `master-roadmap.md` 的产品主线，
也对齐 `compiler-roadmap.md` 的前四段，并把 `toolchain-first RTL`
的第一层实体纳入当前执行面：

- 先把控制面收紧
- 再把 compiler session 骨架立住
- 然后进入 syntax / resolution / semantic core 的最小可执行骨架
- 再把 `Typed HIR` 下游的 `MIR` / backend / toolchain 边界立住
- 再把 compiler/toolchain 后续真正要复用的 `rtl/core/base` / `rtl/core/mem` foundation
  落成 nextPas 自己的仓库资产
- 再把 `rtl/core/text` 真正接进 compiler 前端和 diagnostics vocabulary

## 用编译器路线图看当前批次

如果你现在主要关心 compiler execution spine，而不是产品总路线，可以先按下面这张表读
当前 rolling window：

| 编译器路线图阶段                                  | 当前批次映射                       | 当前状态                | 读取说明                                                                                                                                                                               |
| ------------------------------------------------- | ---------------------------------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Control Surface and Session Foundation         | `Batch 1` - `Batch 3`              | 已完成                  | `Batch 1` / `Batch 2` 先把 machine-readable command surface 收紧，`Batch 3` 把 `CompilationSession` 与 `Source database` 真正落地                                                      |
| 2. Syntax Frontend                                | `Batch 4`                          | 已完成                  | 当前最小 lexer、`Green CST` 与 `AST facade` skeleton 已就位                                                                                                                            |
| 3. Unit Resolution and Semantic Core              | `Batch 5` - `Batch 6`              | 已完成                  | `UnitGraph`、name resolution、semantic model 与最小 `Typed HIR` 已进入真实编译路径                                                                                                     |
| 4. Typed HIR / MIR / Backend / Toolchain Boundary | `Batch 7`、`Batch 11` - `Batch 24` | 已完成当前最小闭环      | 这里要按“toolchain boundary 长链条”理解：`MIR`/backend plan、tool diagnostics、build trace、status event、runner contract、native assemble/link production path 都属于这一段的持续收口 |
| 5. Target / Cross / LLVM / C Interop              | `Batch 10`、`Batch 25`、`Batch 26` | 已完成当前最小 contract | `TargetFacts`、LLVM binding、sysroot policy 与最小 external `cdecl` foreign binding contract 已进入正式控制面                                                                          |
| 6. Workspace and Developer Tooling Integration    | `Batch 18` 起                      | 已启动，仍在继续        | `Batch 18` 已把 shared workspace truth 收口到 compiler-owned model；后续 workspace/package/developer tooling 仍应继续沿这一段推进                                                      |

当前有两类批次需要额外说明：

- `Batch 8` - `Batch 9`
  这两批是 nextPas-native `toolchain-first RTL` foundation。它们服务 compiler 与 toolchain，
  但不改写上面六段的主顺序；阅读时把它们当成编译器主线的共享基础层，而不是单独第七段。
- 当前 `归属路线段` 文案
  这份计划现在优先使用 `docs/architecture/compiler-roadmap.md` 的六段口径；只有 `Batch 8` -
  `Batch 9` 继续额外保留“共享基础层”的说明，用来表达它们同时服务多个编译器阶段。

## Batch 1: verify-local envelope bridge

- 状态：完成
- 归属路线段：Control Surface and Session Foundation

### 这一批要解决什么

把 `stage0 build`、`test harness` 和 `build/verify_local.sh` 最小命令面收敛到真实的
`command-envelope=<json>` bridge 上，避免后续 compiler kernel 工作继续依赖 shell 文本猜测。

### 这一批已经交付了什么

- `stage0 build` envelope 已存在
- `test harness` envelope 已存在
- `build/verify_local.sh` 会显式断言 build/test 两条 envelope
- fresh evidence 已写入 `.sisyphus/evidence/batch-harness-envelope.txt`

### 这一批为什么排第一

因为如果命令面还不稳定，后面的 compiler session、syntax、resolution skeleton 即使做出来，
也没有统一对外验证壳。

## Batch 2: control-surface conformance batch

- 状态：完成
- 归属路线段：Control Surface and Session Foundation

### 这一批要解决什么

把 `nextpas build`、`tests/run_all_tests.sh`、`build/verify_local.sh` 和相关架构文档进一步
收成同一套控制面词汇、失败类别和 target/command/context/result 口径。

### 这批的范围

- 对齐 `stage0 driver`、`test harness`、`verify_local` 的公开术语
- 收紧 `CommandIntent`、`CommandExecutionContext`、`CommandResultEnvelope` 的文档与实现映射
- 保持 thin entrypoint，不提前打开 package manager、LLVM backend、GUI 或 IDE 实现

### 预期交付物

- `tools/stage0/nextpas.pas` 及相关 README/spec 的控制面口径对齐
- `tests/run_all_tests.sh`、`tests/harness/README.md` 与 test-harness spec 的口径对齐
- `build/verify_local.sh`、`build/README.md` 与 developer-tooling spec 的口径对齐
- fresh conformance evidence

### Promotion gate

- 同一类 command failure 不再用多套命名
- target id、command id、result envelope 字段口径一致
- `build`、`test`、`verify` 三条最小命令面可以被同一类机器消费逻辑解释

### 这一批已经交付了什么

- `stage0 build` 现在会显式投影 `selector`、`status`、`result` 与 `failure-kind`
- `test harness` 成功、失败与 bootstrap failure 路径现在都显式投影 `target=linux-x86_64`
- `build/verify_local.sh` 现在也会输出自己的 `command-envelope=<json>`
- `tests/run_all_tests.sh` 与 `build/verify_local.sh` 的脚本路径解析已去掉对外部 `dirname` 的依赖
- fresh evidence 已写入 `.sisyphus/evidence/batch-control-surface-conformance.txt`

## Batch 3: compiler session + source database skeleton

- 状态：完成
- 归属路线段：Control Surface and Session Foundation

### 这一批要解决什么

在 `compiler/` 下建立最小 `CompilationSession` 骨架，让一次编译的 source、target、
diagnostics 和生命周期归属不再漂浮在未来实现里。

### 这批的范围

- 建立 `CompilationSession` 或等价对象
- 建立 `Source database` skeleton
- 建立 target facts view、compilation options、diagnostics sink 的最小拥有关系
- 明确会话级 / unit 级 / 阶段级生命周期边界

### 预期交付物

- `compiler/` 下可扫描的 session/source-db skeleton
- 与 compiler / pipeline / diagnostics 文档一致的命名
- 能被命令面或最小 smoke path 实际创建的 session baseline

### Promotion gate

- 后续 syntax/resolution 层不需要新引入全局 mutable singleton
- session 能解释自己拥有的 source、target 与 diagnostics truth
- skeleton 已落到真实仓库实体，而不是只停在架构文档

### 这一批已经交付了什么

- `compiler/frontend/np_source_database.pas` 已提供最小 `TSourceDatabase`
- `compiler/frontend/np_compilation_session.pas` 已提供最小 `TCompilationSession`
- `compiler/targets/np_target_facts.pas` 与 `compiler/diagnostics/np_diagnostics_sink.pas` 已把 target/diagnostics ownership 落成真实实体
- `tools/stage0/nextpas.pas` 的 `build` path 现在会实际创建 session skeleton，并投影 `session-id`、`source-db-file-count`、`diagnostics-count` 与 lifecycle summary
- `build/verify_local.sh` 现在把 compiler skeleton 输入与 session/source-db projection 一起纳入 promotion gate
- fresh evidence 已写入 `.sisyphus/evidence/batch-compiler-session-skeleton.txt`

## Batch 4: lexer -> green CST -> AST facade skeleton

- 状态：完成
- 归属路线段：Syntax Frontend

### 这一批要解决什么

把 parser 前半段从空目录推进到最小可执行骨架，明确 nextPas 不走“直接 mutable AST + 到处塞语义结论”的老路。

### 这批的范围

- 建立 lexer skeleton
- 建立 immutable `Green CST` skeleton
- 建立 `AST facade` skeleton
- 把 syntax failure 接入 diagnostics sink

### 预期交付物

- `compiler/syntax/` 下的最小 front skeleton
- 可对 smoke 级输入执行的 token / CST / AST facade baseline
- 对语法失败的结构化 diagnostics baseline

### Promotion gate

- lexer、green tree、AST facade 都挂在 `CompilationSession` 上，而不是私有全局状态
- `Green CST` 不依赖 AST 原地回写才可被下游消费
- syntax failure 已进入统一 diagnostics sink

### 这一批已经交付了什么

- `compiler/syntax/np_lexer.pas` 已提供最小 `TLexerResult`
- `compiler/syntax/np_green_tree.pas` 已提供最小 immutable `TGreenTree`
- `compiler/syntax/np_ast_facade.pas` 已提供最小 `TAstFacade`
- `compiler/frontend/np_source_database.pas` 现在真实持有 root source text
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在真实持有 structured syntax diagnostics
- `compiler/frontend/np_compilation_session.pas` 现在会实际运行 `AnalyzeSyntax`
- `tools/stage0/nextpas.pas` 的 `build` path 现在会先跑 syntax analyze，再投影
  `syntax-status`、`lexer-token-count`、`green-node-count`、`ast-root-kind`
- `stage0 build tests/compiler/fail/missing_semicolon_fail.pas --target linux-x86_64`
  现在会以 `syntax-analysis-failed` + `parser.syntax-error` 失败
- fresh evidence 已写入 `.sisyphus/evidence/batch-lexer-green-ast-skeleton.txt`

## Batch 5: unit graph + name resolution skeleton

- 状态：完成
- 归属路线段：Unit Resolution and Semantic Core

### 这一批要解决什么

把 unit/module 行为从路径习惯推进成正式编译器对象，让后续 semantic model、Typed HIR 和 runtime bootstrap 有稳定前提。

### 这批的范围

- 建立 `UnitId`、`ResolvedUnit`、`SearchPathSet`、`UnitGraph`
- 建立最小 name resolution skeleton
- 先支持 smoke 级 unit/module 解析
- 让 missing unit、ambiguous unit、cycle failure 进入结构化 diagnostics

### 预期交付物

- `compiler/frontend/` 或 `compiler/sema/` 下可扫描的 resolution skeleton
- root/interface/implementation/implicit-runtime edge 的最小图模型
- 对 unit failure 的 structured diagnostics baseline

### Promotion gate

- unit 解析结果进入 `UnitGraph`，不再只停留在路径字符串
- init/fini 相关前提开始能被 graph 显式表达
- 解析失败类别可以被 harness / diagnostics baseline 留证

### 这一批已经交付了什么

- `compiler/frontend/np_unit_graph.pas` 已提供最小 `TSearchPathSet`、`TResolvedUnit` 与 `TUnitGraph`
- `compiler/frontend/np_unit_resolver.pas` 已提供最小 `TUnitResolver`
- `compiler/frontend/np_compilation_session.pas` 现在会真实运行 `ResolveUnits`
- `tools/stage0/nextpas.pas` 现在会在调用宿主 FPC 之前运行 resolution，并显式传入
  target-aware `-Fu<units_dir>`
- `stage0 build examples/smoke/hello_with_units.pas --target linux-x86_64` 现在会显式投影
  `resolution-status=ready`、`resolved-unit-count=4`、`unit-graph-edge-count=4`
- `tests/compiler/fail/missing_unit_fail.pas`、`ambiguous_unit_fail.pas`、
  `unit_cycle_fail.pas` 现在会以 `unit-resolution-failed` + resolver diagnostics 失败
- `build/verify_local.sh` 现在已经把 resolution smoke、missing unit、ambiguous unit、
  unit cycle 四类 gate 纳入 promotion path
- fresh evidence 已写入 `.sisyphus/evidence/batch-unit-graph-resolution-skeleton.txt`

## Batch 6: semantic model + `Typed HIR` skeleton

- 状态：完成
- 归属路线段：Unit Resolution and Semantic Core

### 这一批要解决什么

把 `sema` 从文档名词推进成 session 内的真实阶段，让 `stage0 build` 在 resolution 之后
实际运行最小 semantic analysis，把 symbol/type/typed-hir/runtime-contract truth 收进
`CompilationSession`，并把 duplicate import semantic failure 作为第一条正式语义失败路径。

### 这批的范围

- 建立 `TSemanticModel` 与 `TSemanticAnalyzer`
- 让 `TCompilationSession` 真实拥有 semantic model 并调用 `AnalyzeSemantics`
- 让 `stage0 build` 投影 semantic status / counts / typed-hir root
- 把 duplicate import failure 接进 diagnostics sink 与 command result bridge
- 把 semantic smoke / semantic failure 接进 `build/verify_local.sh`

### 预期交付物

- `compiler/sema/` 下可扫描的 semantic skeleton
- 可由 `stage0 build` 直接投影的最小 `Typed HIR` / runtime contract baseline
- 对 duplicate import 的 structured semantic diagnostics baseline

### Promotion gate

- semantic truth 进入 `CompilationSession`，不再停留在 driver 级临时状态
- `stage0 build` 成功路径显式投影 `semantic-status=ready`
- `examples/smoke/hello_with_units.pas` 显式投影 `symbol-count=4`、`type-count=3`、
  `typed-hir-node-count=7` 与 `runtime-contract-count=2`
- `tests/compiler/fail/duplicate_unit_import_fail.pas` 以
  `semantic-analysis-failed` + `sema.duplicate-declaration` 失败
- `build/verify_local.sh` 把 semantic smoke / duplicate import gate 纳入 promotion path

### 这一批已经交付了什么

- `compiler/sema/np_semantic_model.pas` 已提供最小 `TSemanticModel`
- `compiler/sema/np_semantic_analyzer.pas` 已提供最小 `TSemanticAnalyzer`
- `compiler/frontend/np_compilation_session.pas` 现在会真实运行 `AnalyzeSemantics`
- `tools/stage0/nextpas.pas` 现在会在 resolution 之后投影
  `semantic-status`、`symbol-graph-status`、`type-graph-status`、`typed-hir-status`、
  `symbol-count`、`type-count`、`typed-hir-node-count`、`runtime-contract-count`
- `tests/compiler/fail/duplicate_unit_import_fail.pas` 现在会以
  `semantic-analysis-failed` + `sema.duplicate-declaration` 失败
- `build/verify_local.sh` 现在已经把 semantic smoke、duplicate import gate 纳入 promotion path
- fresh evidence 已写入 `.sisyphus/evidence/batch-semantic-model-typed-hir-skeleton.txt`

## Batch 7: `MIR` / backend / toolchain boundary skeleton

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

把 `Typed HIR` 之后的所有权从空白愿景推进成 session 内的真实阶段，让 `stage0 build`
在 semantic analysis 之后真实拥有最小 `MIR`、backend artifact/tool invocation plan、
toolchain binding identity 与 target/backend metadata。

### 这批的范围

- 建立 `TMirModel` / `TMirLowerer`
- 建立 `TBackendPlan` / `TBackendPlanner`
- 扩展 `TTargetFactsView` 与 `tools/stage0/target_config.pas`
- 为 `linux-x86_64` 写入正式 `toolchain binding` 文件
- 让 `stage0 build` 与 `build/verify_local.sh` 真实投影和 gate 这些字段

### 预期交付物

- `compiler/ir/` 下可扫描的最小 `MIR` skeleton
- `compiler/backend/` 下可扫描的最小 backend artifact/tool invocation plan skeleton
- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
- 可由 `stage0 build` 直接投影的 `mir-*` / `backend-*` / toolchain/target metadata baseline

### Promotion gate

- `TCompilationSession` 真实拥有 `MIR` model 与 backend plan，不再把 `Typed HIR` 之后的 truth 留在 driver 级空白区
- `stage0 build examples/smoke/hello.pas --target linux-x86_64` 显式投影
  `mir-status=ready`、`mir-block-count=1`、`mir-operation-count=6`、
  `backend-plan-status=ready` 与 `toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu`
- `stage0 build examples/smoke/hello_with_units.pas --target linux-x86_64` 显式投影
  `mir-operation-count=8`、`backend-output-kind=executable`、
  `backend-primary-artifact-path=examples/smoke/hello_with_units`、
  `backend-family=native`、`target-object-format=elf`、`target-assembler-flavor=gnu-as`、
  `target-linker-flavor=gnu-ld`、`tool-invocation-count=1`
- `build/verify_local.sh` 把 `compiler/ir/`、`compiler/backend/`、`build/toolchains/` 与
  MIR/backend/toolchain smoke assertions 纳入 promotion path

### 这一批已经交付了什么

- `compiler/ir/np_mir_model.pas` 已提供最小 `TMirModel` 与 `TMirLowerer`
- `compiler/backend/np_backend_plan.pas` 已提供最小 `TBackendPlan` 与 `TBackendPlanner`
- `compiler/sema/np_semantic_model.pas` 现在已暴露 typed-hir iteration，供 lowering 使用
- `compiler/targets/np_target_facts.pas` 现在已提供 object format、assembler flavor、
  linker flavor、LLVM triple、toolchain binding id 与 backend family
- `tools/stage0/target_config.pas` 现在会真实读取并校验
  `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
- `compiler/frontend/np_compilation_session.pas` 现在会真实运行 `LowerToMir` 与 `PlanBackend`
- `tools/stage0/nextpas.pas` 现在会投影 `mir-*`、`backend-*`、toolchain 与 target metadata
- `build/verify_local.sh` 现在已经把 MIR/backend/toolchain smoke gate 纳入 promotion path
- fresh evidence 已写入 `.sisyphus/evidence/batch-mir-backend-toolchain-skeleton.txt`

## Batch 7 之后怎么继续

`Batch 7` 完成后，不是重新回到碎片式“继续”，而是先把 `toolchain-first RTL` 的第一批
nextPas-native 实体落下来，再继续滚动下一组批次。

## Batch 8: toolchain-first RTL foundation (`rtl/core/base` + `rtl/core/mem`)

- 状态：完成
- 归属路线段：Control Surface and Session Foundation / Typed HIR / MIR / Backend / Toolchain Boundary（共享基础层）

### 这一批要解决什么

让 nextPas 不再只在架构文档里说“compiler/toolchain 与 future public RTL 共享同一套 core runtime”，
而是先把最小但高频的 shared runtime truth 真正落到仓库里。

### 这批的范围

- 建立 `rtl/core/base/README.md` 与 `rtl/core/base/np_base_types.pas`
- 建立 `rtl/core/mem/README.md` 与 `rtl/core/mem/np_allocator.pas`
- 对齐 `rtl/README.md`、`rtl/core/README.md`、`rtl-specification.md` 与
  `runtime-bootstrap-specification.md`
- 保持范围严格收在 `status/result/span` 与 allocator/arena discipline，不提前扩成大标准库

### 预期交付物

- `rtl/core/base/` 可扫描、可编译的最小 support types skeleton
- `rtl/core/mem/` 可扫描、可编译的最小 allocator / bump arena skeleton
- 能把这两个目录解释成 compiler/toolchain-first RTL 的真实起点，而不是文档补注

### Promotion gate

- `rtl/core/base` 与 `rtl/core/mem` 已在仓库里拥有真实 Pascal 单元，而不是只有 README
- 宿主 FPC 可以直接编译这些最小单元
- 当前路线图与架构文档明确写出：cross / LLVM / C interop 继续建立在 nextPas-native core RTL 之上，
  而不是反过来要求 core RTL 永远追着后端私有 helper 补洞

### 这一批已经交付了什么

- `rtl/core/base/README.md` 与 `rtl/core/base/np_base_types.pas` 已把最小
  `status/result` vocabulary、stable id 与 span support types 落成真实仓库实体
- `rtl/core/mem/README.md` 与 `rtl/core/mem/np_allocator.pas` 已把最小
  `TCoreAllocator` contract 与 `TBumpArena` 落成真实仓库实体
- `rtl/README.md`、`rtl/core/README.md`、`docs/architecture/rtl-specification.md`、
  `docs/architecture/runtime-bootstrap-specification.md` 与本计划已同步写清：
  nextPas-native core RTL 的第一批实现切片先从 `base` / `mem` 起步
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-rtl-core-base-unit.txt`
  - `.sisyphus/evidence/batch-rtl-core-mem-unit.txt`
  - `.sisyphus/evidence/batch-rtl-core-foundation.txt`

## Batch 8 之后怎么继续

`Batch 8` 收口后，继续按 `master-roadmap.md` 滚动下一组批次：

## Batch 9: toolchain-first RTL text foundation (`rtl/core/text`) + compiler integration

- 状态：完成
- 归属路线段：Control Surface and Session Foundation（共享基础层）

### 这一批要解决什么

让 nextPas 的 path/identity/text ingestion 不再散落在 `SourceDatabase`、resolver 和
compiler 私有 helper 里，而是开始收敛到共享的 `rtl/core/text`。

### 这批的范围

- 建立 `rtl/core/text/README.md` 与 `rtl/core/text/np_text_primitives.pas`
- 让 `np_source_database.pas` 复用 shared text/path ingestion
- 让 `np_unit_graph.pas` 与 `np_unit_resolver.pas` 复用 shared identity/path normalization
- 让 `np_diagnostics_sink.pas` 升到 shared `PrimarySpan` vocabulary
- 让 `build/verify_local.sh` 对 `tests/rtl/core_text_smoke.pas` 建正式 gate

### 预期交付物

- `rtl/core/text/` 可扫描、可编译的最小 text/path primitive skeleton
- compiler 前端开始真实吃到 shared text/path helper，而不是继续各写各的 normalization
- diagnostics 结构开始建立在 shared span vocabulary 上

### Promotion gate

- 宿主 FPC 可以直接编译并运行 `tests/rtl/core_text_smoke.pas`
- `build/verify_local.sh` 显式通过 `core-text-smoke-check`
- `stage0` build 命令面显式把 `rtl/core/base` 与 `rtl/core/text` 当成正式依赖路径，而不是依赖偶然缓存

### 这一批已经交付了什么

- `rtl/core/text/README.md` 与 `rtl/core/text/np_text_primitives.pas` 已把 path/identity
  normalization 与 text file ingestion 落成真实仓库实体
- `compiler/frontend/np_source_database.pas` 现在通过 shared text contract 读取和规范化 source
- `compiler/frontend/np_unit_graph.pas` 与 `compiler/frontend/np_unit_resolver.pas` 现在复用 shared
  identity/path normalization
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在已经把 source location 收进 shared
  `PrimarySpan` vocabulary
- `build/verify_local.sh` 与 `tools/stage0/README.md` 现在显式把 `rtl/core/base` /
  `rtl/core/text` 纳入 `stage0` compile path
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-rtl-core-text-red.txt`
  - `.sisyphus/evidence/batch-rtl-core-text-green.txt`
  - `.sisyphus/evidence/batch-rtl-core-text-foundation.txt`

## Batch 10: target facts / sysroot / LLVM / C interop refinement

- 状态：完成
- 归属路线段：Target / Cross / LLVM / C Interop

### 这一批要解决什么

把 `TargetFacts` 从“已经有最小 backend metadata”推进到真正能承接下一轮 cross / LLVM /
C interop 设计的正式字段集合，让 `stage0 build`、`verify_local` 和架构文档都不再把
runtime layout、sysroot policy、C naming 与 LLVM data layout 留在未来想象里。

### 这批的范围

- 扩展 `build/targets/linux-x86_64.toml`
- 扩展 `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
- 扩展 `TTargetFactsView`、`target_config`、`TBackendPlan`
- 让 `TCompilationSession` 与 `stage0 build` 投影新的 target/toolchain/sysroot fields
- 让 `build/verify_local.sh` 真实 gate 这些 refinement fields

### Promotion gate

- `stage0 build examples/smoke/hello.pas --target linux-x86_64` 显式投影
  `host-id=linux-x86_64`、`target-runtime-layout-key=target-sdk-split`、
  `sysroot-mode=runtime-sdk`、`runtime-sdk-id=linux-x86_64`、`allow-host-fallback=false`
- `stage0 build examples/smoke/hello_with_units.pas --target linux-x86_64` 显式投影
  `target-c-library-naming=lib-prefix-so-a`、`target-llvm-triple=x86_64-unknown-linux-gnu`、
  `target-llvm-data-layout=...` 与空的 `target-c-symbol-prefix=`
- `command-envelope=<json>` 也必须带上同一批 host/target/sysroot/C/LLVM fields
- `build/verify_local.sh` 必须把这些字段纳入 `stage0-smoke` 与 `semantic-smoke` gate

### 这一批已经交付了什么

- `build/targets/linux-x86_64.toml` 现在已显式写出
  `runtime_layout_key=target-sdk-split`、`c_symbol_prefix=""`、
  `c_library_naming=lib-prefix-so-a` 与 Linux x86_64 的 `llvm_data_layout`
- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml` 现在已显式写出
  `sysroot_mode=runtime-sdk`、`runtime_sdk=linux-x86_64` 与 `allow_host_fallback=false`
- `compiler/targets/np_target_facts.pas` 现在已把 host id、runtime layout、C naming、LLVM data
  layout、sysroot mode 与 runtime SDK 收进统一 `TargetFacts`
- `tools/stage0/target_config.pas` 现在会真实读取并校验这些 target/toolchain/sysroot fields
- `compiler/backend/np_backend_plan.pas` 与 `compiler/frontend/np_compilation_session.pas`
  现在会继续携带并暴露这批 refinement metadata
- `tools/stage0/nextpas.pas` 现在会把这些字段投影到 line-based output 与
  `command-envelope=<json>`
- `build/verify_local.sh` 现在已经把 host/target/sysroot/C/LLVM refinement fields 纳入 gate
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-target-facts-refinement-red.txt`
  - `.sisyphus/evidence/batch-target-facts-refinement-green.txt`
  - `.sisyphus/evidence/batch-target-facts-refinement-foundation.txt`

## Batch 11: tool invocation profile + stage0 host-compiler failure mapping

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

把当前单一 host-compiler invocation 从“只有 tool role 和 count”推进到真正可承接
toolchain diagnostics 的最小 profile/step/failure contract，让 `stage0 build`、
`verify_local` 与 command envelope 不再把宿主 compiler step 继续当成一段 driver 私有字符串。

### 这批的范围

- 扩展 `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
- 扩展 `TTargetFactsView`、`target_config`、`TBackendPlan` 与 `TCompilationSession`
- 让 `stage0 build` 投影 primary tool profile / step / logical executable / sysroot / failure mapping
- 把宿主 compiler launch / exit failure 对齐到 `toolchain.host-compiler-exec-failed`
- 让 `build/verify_local.sh` 在 `stage0-smoke` 与 `semantic-smoke` 上真实 gate 这些字段
- 继续以 FPC `systems.pas` / `systems/t_linux.pas` 的 host-target-tool 分层为 grounding，
  但把当前最小 truth 收进 nextPas 自己的 typed metadata

### Promotion gate

- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml` 必须显式写出
  `host_compiler_profile=fpc-stage0-host`
- `stage0 build examples/smoke/hello.pas --target linux-x86_64` 与
  `examples/smoke/hello_with_units.pas --target linux-x86_64` 都必须显式投影
  `primary-tool-profile-id=fpc-stage0-host`、`primary-tool-step-id=host-fpc-compile`、
  `primary-tool-logical-executable=fpc`、
  `primary-tool-sysroot-ref=runtime-sdk:linux-x86_64` 与
  `primary-tool-failure-mapping=toolchain.host-compiler-exec-failed`
- `command-envelope=<json>` 也必须带上同一批 `primaryTool*` 字段
- 宿主 compiler execute step 的 launch / exit failure 必须走
  `toolchain.host-compiler-exec-failed`，而不是继续暴露 `compiler-launch-failed` /
  `build-failed`
- `build/verify_local.sh` 必须把这批 line-based 和 envelope fields 纳入 gate

### 这一批已经交付了什么

- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml` 现在已显式写出
  `host_compiler_profile=fpc-stage0-host`
- `compiler/targets/np_target_facts.pas`、`tools/stage0/target_config.pas`、
  `compiler/backend/np_backend_plan.pas` 与 `compiler/frontend/np_compilation_session.pas`
  现在会把 host compiler profile、primary tool step、logical executable、sysroot ref 与
  failure mapping 收进同一条 plan/session projection
- `tools/stage0/nextpas.pas` 现在会把这批字段投影到 line-based output 与
  `command-envelope=<json>`，并把宿主 compiler execute failure 对齐到
  `toolchain.host-compiler-exec-failed`
- `build/verify_local.sh` 现在已经把这批 fields 纳入 `stage0-smoke` 与 `semantic-smoke` gate
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-tool-invocation-profile-red.txt`
  - `.sisyphus/evidence/batch-tool-invocation-profile-green.txt`
  - `.sisyphus/evidence/batch-tool-invocation-profile-foundation.txt`

## Batch 12: host-compiler structured toolchain diagnostic skeleton

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

把 `Batch 11` 里已经固定的 `profile/step/failureMapping` 从结果字段推进成真正的
structured diagnostic skeleton，让宿主 compiler failure 不再只有 `failure-kind`，而是
开始具备可被 CLI、CI、future IDE 与 build trace 关联的 toolchain diagnostic payload。

### 这批的范围

- 扩展 `tools/stage0/nextpas.pas` 的 failure projection
- 让 host-compiler failure 覆盖 `diagnostics-count/summary/json` 与 last diagnostic fields
- 让 `command-envelope=<json>` 的 `diagnostics` 数组带上最小 toolchain payload
- 让 `build/verify_local.sh` 增加 fake `fpc` negative path，真实 gate toolchain diagnostic
- 更新 diagnostics / stage0 / build / compiler 文档，把这条 failure baseline 说成正式 contract

### Promotion gate

- fake `fpc` 负路径必须以 `failure-kind=toolchain.host-compiler-exec-failed` 退出
- 同一条失败输出必须显式投影
  `diagnostics-count=1`、`diagnostics-summary=toolchain.host-compiler-exec-failed`、
  `diagnostic-code=toolchain.host-compiler-exec-failed`、`diagnostic-phase=toolchain`
- line-based output 必须带上
  `diagnostic-binding-id=linux-x86_64-to-linux-x86_64-gnu`、
  `diagnostic-profile-id=fpc-stage0-host`、`diagnostic-step-id=host-fpc-compile`、
  `diagnostic-logical-executable=fpc`、`diagnostic-sysroot-ref=runtime-sdk:linux-x86_64`
- `command-envelope=<json>` 的 `diagnostics[0]` 必须至少带上
  `bindingId/profileId/stepId/logicalExecutable/sysrootRef/resolvedPath/primaryArtifact/exitCode`
- `build/verify_local.sh` 必须把这条 negative path 纳入公开 gate

### 这一批已经交付了什么

- `tools/stage0/nextpas.pas` 现在会在 host-compiler failure 时生成一条
  `phase=toolchain` 的 structured diagnostic，并同步更新
  `diagnostics-count`、`diagnostics-summary`、`diagnostic-code`、`diagnostic-phase` 与
  `command-envelope=<json>`
- 当前最小 payload 已真实携带
  `bindingId`、`profileId`、`stepId`、`logicalExecutable`、`sysrootRef`、`resolvedPath`、
  `primaryArtifact` 与 `exitCode`
- `build/verify_local.sh` 现在已经加入 fake `fpc` negative path，并真实 gate 这条
  toolchain diagnostic skeleton
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-toolchain-diagnostic-skeleton-red.txt`
  - `.sisyphus/evidence/batch-toolchain-diagnostic-skeleton-green.txt`
  - `.sisyphus/evidence/batch-toolchain-diagnostic-skeleton-foundation.txt`

## Batch 13: toolchain diagnostics sink integration

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

把 `Batch 12` 的 host-compiler structured diagnostic 从 `stage0` 局部拼装推进成
`diagnostics sink + compilation session` 正式 ownership，避免同一类结构化失败长期停留在
driver 私有 helper 里。

### 这批的范围

- 扩展 `compiler/diagnostics/np_diagnostics_sink.pas`
- 扩展 `compiler/frontend/np_compilation_session.pas`
- 让 `tools/stage0/nextpas.pas` 改为消费 session-owned diagnostic projection
- 保持 `build/verify_local.sh` 的 toolchain failure negative path 全绿
- 更新 compiler / architecture / roadmap / stage0 / build 文档

### Promotion gate

- `np_diagnostics_sink.pas` 必须提供正式 toolchain diagnostic emission 能力
- `np_compilation_session.pas` 必须提供 session-owned toolchain failure recording 与 last diagnostic metadata getters
- `tools/stage0/nextpas.pas` 不再本地构造 toolchain diagnostic JSON payload
- fake `fpc` 负路径仍必须保持 `toolchain.host-compiler-exec-failed` 的全部 line-based 与 envelope assertions
- `./build/verify_local.sh` 必须继续通过

### 这一批已经交付了什么

- `compiler/diagnostics/np_diagnostics_sink.pas` 现在已把
  `bindingId/profileId/stepId/logicalExecutable/sysrootRef/resolvedPath/primaryArtifact/exitCode`
  收进正式 diagnostic record / JSON projection
- `compiler/frontend/np_compilation_session.pas` 现在已提供
  `RecordToolchainFailure(...)`，并把 toolchain diagnostic metadata 暴露成正式 getter
- `tools/stage0/nextpas.pas` 现在只消费 session-owned diagnostics，不再本地拼装
  toolchain diagnostic JSON
- `build/verify_local.sh` 与 fake `fpc` focused evidence 继续保持全绿
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-toolchain-diagnostic-sink-integration-red.txt`
  - `.sisyphus/evidence/batch-toolchain-diagnostic-sink-integration-green.txt`
  - `.sisyphus/evidence/batch-toolchain-diagnostic-sink-integration-foundation.txt`

## Batch 14: build trace / diagnostic refs integration

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

这一批把 `Batch 13` 已经接进 `diagnostics sink + compilation session` 的
host-compiler failure，继续收成一条最小但真实的
`diagnostic id -> build trace ref -> diagnosticRefs` 闭环。

### Promotion gate

- `np_diagnostics_sink.pas` 必须给每条 structured diagnostic 分配稳定 `diagnostic id`
- `np_compilation_session.pas` 必须正式拥有 host-compiler failure 的最小 build trace ref / payload
- `tools/stage0/nextpas.pas` 只能做 trace projection，不能回退成 driver 本地重拼 diagnostic / trace truth
- fake `fpc` 负路径必须真实断言
  `diagnostic-id`、`build-trace-ref`、`build-trace=<json>` 与
  `diagnosticRefs=["diag-0001"]`
- `./build/verify_local.sh` 必须继续通过

### 这一批已经交付了什么

- `compiler/diagnostics/np_diagnostics_sink.pas` 现在会为每条 diagnostic 分配
  `diag-0001` 这类稳定 id，并把 `id` 投影进 `diagnostics` JSON
- `compiler/frontend/np_compilation_session.pas` 现在正式拥有最小 host-compiler failure build trace，
  当前 payload 已真实携带
  `traceKind/sessionId/planId/bindingId/hostId/targetId/result/steps[].diagnosticRefs`
- `tools/stage0/nextpas.pas` 现在会在 host-compiler failure 时投影
  `diagnostic-id`、`build-trace-ref`、`build-trace=<json>`，
  并把 `buildTraceRef/buildTrace` 写进 `command-envelope=<json>`
- `build/verify_local.sh` 现在已经把
  `diagnostic id + build trace ref + diagnosticRefs linkage` 纳入 fake `fpc` negative path gate
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-toolchain-build-trace-linkage-red.txt`
  - `.sisyphus/evidence/batch-toolchain-build-trace-linkage-green.txt`
  - `.sisyphus/evidence/batch-toolchain-build-trace-linkage-foundation.txt`

## Batch 14 之后怎么继续

`Batch 14` 收口后，继续按 `master-roadmap.md` 滚动下一组批次：

- workspace / package / developer tooling
- GUI framework / IDE

其中最优先的下一批建议是：

- semantic diagnostics contract，从“已有 failure kind”继续收成 warning / warning-as-error 等最小正式行为
- workspace / package source-root truth，先减少 resolver 对目录重扫与 driver 猜测的依赖
- LLVM / C interop execution-side contract，继续建立在同一份 refined `TargetFacts`、
  backend contract 与 nextPas-native core RTL foundation 上

但这些后续批次必须建立在前十四批真实收口之后，而不是提前平行开工。

## Batch 15: toolchain status event spine

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

这一批把 `Batch 14` 已经收起来的 failure-only build trace，继续扩成 success/failure 都可用的
session-owned trace，并补上最小 `ToolchainStatusEvent` spine。

### Promotion gate

- success path 不能再输出 `build-trace-ref=none`
- `np_compilation_session.pas` 必须正式拥有当前 host-compiler step 的 status event collection
- `tools/stage0/nextpas.pas` 只能做 status/trace projection，不能回退成 driver 私有日志拼接
- 这一批最初由 `build/verify_local.sh` 在 success 与 fake `fpc` failure 两条路径上同时 gate：
  一条 four-event status baseline、`tool-status-events=<json>`、`build-trace-ref` 与
  `build-trace=<json>`；当前 contract 已在 `Batch 24` 升级为 full transcript +
  plan-level `build-trace-ref=trace-<session-id>-toolchain-plan`
- `./build/verify_local.sh` 必须继续通过

### 这一批已经交付了什么

- `compiler/frontend/np_compilation_session.pas` 现在会正式持有最小
  `ToolchainStatusEvent` 集合，并以 session-owned JSON 形式暴露出去
- 当时唯一真实的 host-compiler step 会留下四个 status events：
  `toolchain.tool-selected`、`toolchain.step-started`、
  `toolchain.step-finished`、`toolchain.plan-finished`
- 这条初始 baseline 后续又在 `Batch 24` 被扩成完整 multi-step transcript；当前 success path
  会产出 `buildTraceRef=trace-<session-id>-toolchain-plan`，并把全部 executed steps 写进
  `buildTrace.steps[]`
- `tools/stage0/nextpas.pas` 现在会把 `toolStatusEvents` 写进 `command-envelope=<json>` 顶层，
  同时保留 line-based `tool-status-events=<json>` human projection
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-toolchain-status-event-spine-red.txt`
  - `.sisyphus/evidence/batch-toolchain-status-event-spine-green.txt`
  - `.sisyphus/evidence/batch-toolchain-status-event-spine-foundation.txt`

## Batch 15 之后怎么继续

`Batch 15` 收口后，继续按 `master-roadmap.md` 滚动下一组批次：

- workspace / package / developer tooling
- GUI framework / IDE

其中最优先的下一批建议是：

- semantic diagnostics contract，从“已有 failure kind”继续补上 warning policy、promotion rule 和 verify gate
- workspace / package source-root truth，继续把 search root ownership 收回 shared model，而不是扩更多 driver-side projection
- LLVM / C interop execution-side contract，继续建立在同一份 refined `TargetFacts`、
  backend contract 与 nextPas-native core RTL foundation 上

但这些后续批次必须建立在前十五批真实收口之后，而不是提前平行开工。

## Batch 16: typed tool invocation plan projection

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

这一批把 `Batch 15` 已经立住的 status event / build trace spine，继续补成真正可执行对象的
最小 projection：当前唯一真实的 host-compiler step 不再只暴露 count 和 role，而是正式暴露
一份 typed `ToolInvocationPlan`。

### Promotion gate

- `compiler/backend/np_backend_plan.pas` 必须正式拥有当前 host-compiler step 的
  `steps[] / argv / envDelta / workingDirectory / inputs / outputs / sidecars`
- `compiler/frontend/np_compilation_session.pas` 必须把这份 plan 暴露成
  session-owned `toolInvocationPlanRef/toolInvocationPlan`
- `tools/stage0/nextpas.pas` 只能做 plan projection，不能本地重拼另一份 tool invocation truth
- `build/verify_local.sh` 必须在 success 与 fake `fpc` failure 两条路径上同时 gate：
  `tool-invocation-plan-ref`、`tool-invocation-plan=<json>` 与 envelope 顶层
  `toolInvocationPlanRef/toolInvocationPlan`
- `./build/verify_local.sh` 必须继续通过

### 这一批已经交付了什么

- `compiler/backend/np_backend_plan.pas` 现在会为当前唯一真实的 host-compiler step 持有
  typed `ToolInvocationPlan` payload，最小字段已经覆盖
  `steps[0].argv/envDelta/workingDirectory/inputs/outputs/sidecars`
- `compiler/frontend/np_compilation_session.pas` 现在会把 plan 以
  `toolInvocationPlanRef=plan-<session-id>-primary-tool` 与
  `toolInvocationPlan=<json>` 暴露出去，并把 resolved host compiler path 收进 plan step
- `tools/stage0/nextpas.pas` 现在会把 `toolInvocationPlanRef/toolInvocationPlan` 写进
  `command-envelope=<json>` 顶层，同时保留 line-based `tool-invocation-plan=<json>` projection
- `build/verify_local.sh` 现在已经在 success、semantic smoke 与 fake `fpc` failure 三条路径上
  gate typed invocation plan
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-tool-invocation-plan-typed-projection-red.txt`
  - `.sisyphus/evidence/batch-tool-invocation-plan-typed-projection-green.txt`
  - `.sisyphus/evidence/batch-tool-invocation-plan-typed-projection-foundation.txt`

## Batch 17: toolchain binding profile + resolution policy projection

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

这一批把 `Batch 16` 已经立住的 typed invocation object，再往前推进到真正可承接
assembler/linker/resource/LLVM/C interop orchestration 的 binding contract：当前代码必须正式
携带并投影 `ToolchainBinding` 的 profile ids 与 resolution policy，而不是继续只停在
`bindingId + backendFamily + sysroot` 这层最小标签。

### Promotion gate

- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml` 必须显式采用
  `[binding] / [profiles] / [sysroot] / [resolution]` skeleton
- `tools/stage0/target_config.pas`、`compiler/targets/np_target_facts.pas`、
  `compiler/backend/np_backend_plan.pas` 与 `compiler/frontend/np_compilation_session.pas`
  必须正式携带
  `AssemblerProfileId / LinkerProfileId / ArchiverProfileId / ResourceToolProfileId`
  与
  `ToolRootKind / RuntimeRootKind / ResponseFilePolicy / LinkScriptPolicy`
- `tools/stage0/nextpas.pas` 必须把这批字段投影到 line-based output 与
  `command-envelope=<json>.result`
- `build/verify_local.sh` 必须在 success / semantic smoke / fake `fpc` failure 路径上真实 gate：
  `assembler-profile-id`、`linker-profile-id`、`archiver-profile-id`、
  `resource-tool-profile-id`、`tool-root-kind`、`runtime-root-kind`、
  `response-file-policy` 与 `link-script-policy`
- `./build/verify_local.sh` 必须继续通过

### 这一批已经交付了什么

- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml` 现在已切成
  `[binding] / [profiles] / [sysroot] / [resolution]`，并显式写出
  `gnu-as / gnu-ld / gnu-ar / none` 与
  `distribution-helper-root / distribution-runtime-root / auto / when-required`
- `tools/stage0/target_config.pas` 现在会真实解析并校验这批 profile / resolution fields
- `compiler/targets/np_target_facts.pas`、`compiler/backend/np_backend_plan.pas` 与
  `compiler/frontend/np_compilation_session.pas` 现在会把这批 richer binding metadata 收进同一条
  typed projection 链
- `tools/stage0/nextpas.pas` 现在会把
  `assembler-profile-id`、`linker-profile-id`、`archiver-profile-id`、
  `resource-tool-profile-id`、`tool-root-kind`、`runtime-root-kind`、
  `response-file-policy` 与 `link-script-policy` 同步写入 line-based output 和
  `command-envelope=<json>.result`
- `build/verify_local.sh` 现在已经把这批 line-based 与 envelope fields 纳入真实 gate
- fresh evidence 已写入：
  - `.sisyphus/evidence/batch-toolchain-binding-profile-resolution-red.txt`
  - `.sisyphus/evidence/batch-toolchain-binding-profile-resolution-green.txt`
  - `.sisyphus/evidence/batch-toolchain-binding-profile-resolution-foundation.txt`

## Batch 17 之后怎么继续

`Batch 17` 收口后，继续按 `master-roadmap.md` 滚动下一组批次：

- workspace / package / developer tooling
- GUI framework / IDE

其中最优先的下一批建议是：

- multi-step assembler/linker/resource orchestration，继续建立在同一份 typed plan 上
- richer assembler/linker/archive/resource profiles
- LLVM / C interop execution-side contract，继续建立在同一份 refined `TargetFacts`、
  backend contract、typed invocation plan 与 nextPas-native core RTL foundation 上

但这些后续批次必须建立在前十七批真实收口之后，而不是提前平行开工。

## Batch 18: workspace model shared truth convergence

- 状态：完成
- 归属路线段：Workspace and Developer Tooling Integration

### 这一批要解决什么

把当前已经存在的 workspace/package/artifact discovery 从
`tools/stage0/nextpas.pas` 的 driver helper 与 session 散落字段，收口成 compiler-owned
shared model，让当前真实 build path、resolver search roots 和 artifact placement 有单一 owner。

### 这批的范围

- 新增 `compiler/frontend/np_workspace_model.pas`
- 让 `np_package_manifest.pas` 提供 workspace model 所需的 typed package/root info
- 让 `TCompilationSession` 正式拥有 `WorkspaceModel`
- 让 `stage0 build` 改成消费 shared model，而不是继续自己维护 discovery / placement helper
- 让 `toolchain_contract_smoke` 与 `build/verify_local.sh` 冻结 explicit workspace、
  nearest package manifest 与 workspace member 三条 contract

### Promotion gate

- workspace root、discovery kind、package refs、source roots、artifact root、output dir 与
  host-fpc cache root 必须进入同一个 compiler-owned model
- `stage0` 只保留 CLI override 与 orchestration，不再直接拥有
  workspace/package/artifact discovery 规则
- `TCompilationSession`、resolver 与 toolchain planner 必须从 shared model 读取
  roots / artifact truth
- `bash build/verify_local.sh` 必须继续 fresh PASS

### 这一批已经交付了什么

- `compiler/frontend/np_workspace_model.pas` 已提供最小
  `TWorkspaceModel` / `TPackageRef` / `TTargetSelection` / `TArtifactRootSet` 与
  `ResolveWorkspaceModel(...)`
- `compiler/frontend/np_package_manifest.pas` 已提供
  `TPackageManifestInfoArray`、`ResolveWorkspaceMemberPackageInfos(...)` 与
  `ResolveWorkspacePackageManifestInfos(...)`
- `compiler/frontend/np_compilation_session.pas` 现在会正式持有并释放 `WorkspaceModel`，
  resolver 与 toolchain planner 也改为从 model 读取
  `ProjectUnitRootInfos` / `ProjectUnitRoots`
- `tools/stage0/nextpas.pas` 现在会先加载 shared model，再从 model 填充 pre-session
  build context、session options 与 artifact/output paths
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 现在已经把
  explicit workspace、nearest package manifest 与 workspace member 三条 workspace model contract
  纳入真实 gate
- fresh `bash build/verify_local.sh` 继续得到
  `toolchainContractCheck=pass` 与 `verify-local=pass`

## Batch 19: toolchain plan runner execution contract

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

把 `Batch 16` / `Batch 17` 已经冻结的 typed `ToolInvocationPlan` 从“可投影对象”推进到
“可真实执行 contract”，但继续保持边界诚实：

- 当前 ready `TToolchainPlan` 必须能按 step 顺序真实执行
- response file / resource list / archive command 这类 sidecar 不能继续只存在于 JSON 草图里
- `toolchain_contract_smoke` 与 `build/verify_local.sh` 必须真实跑通 fake
  `native-assemble-link` plan
- `stage0 build` 仍不能被包装成已经切到真实 assembler/linker production path；
  backend 还没有正式拥有 assembly/object intermediate artifact truth

### 这批的范围

- 新增 `compiler/toolchain/np_toolchain_runner.pas`
- 在 `compiler/toolchain/np_toolchain_plan.pas` 暴露按 index 读取 step 的入口
- 把 `tests/toolchain/toolchain_contract_smoke.pas` 扩成 fake `as` / `ld` 的真实执行 contract
- 把 `build/verify_local.sh` 扩成会 gate `native-run-*` 与 runner file existence

### Promotion gate

- ready `TToolchainPlan` 必须能被 generic runner 顺序执行
- 当前 sidecar kinds 必须支持真实 materialize 与 `delete-on-success` cleanup
- `native-assemble-link` contract 必须真实验证 object/output 产出、response capture 与 cleanup
- `bash build/verify_local.sh` 必须继续 fresh PASS

### 这一批已经交付了什么

- `compiler/toolchain/np_toolchain_runner.pas` 现在已提供
  `ExecuteToolchainPlan(...)` 与 `TToolchainRunResult`，负责 step directory 准备、
  executable resolution、外部进程执行、sidecar 物化与 cleanup
- `compiler/toolchain/np_toolchain_plan.pas` 现在已暴露 `StepAt(...)`，
  让 runner / contract smoke 能读取 typed step truth
- `tests/toolchain/toolchain_contract_smoke.pas` 现在会在临时 fake toolchain bin 下
  真实执行 `PlanNativeAssembleLink(...)` 生成的两步 plan，并验证
  `native-run-status=success`、assemble/link step status、object/output existence、
  response capture 与 sidecar cleanup
- `build/verify_local.sh` 现在已经把 `compiler/toolchain/np_toolchain_runner.pas`
  和 `native-run-*` contract 纳入 promotion path
- fresh `bash build/verify_local.sh` 继续得到
  `toolchainContractCheck=pass` 与 `verify-local=pass`

## Batch 20: host-compiler runner reuse + tool run projection

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

- 让 `stage0 build` 上当前唯一的 host-compiler execution path 复用
  `compiler/toolchain/np_toolchain_runner.pas`，避免在 `tools/stage0/nextpas.pas`
  里维护手工 `TProcess` 路径。同时继续保持 `stage0` 还不是 native
  assembler/linker production path：backend 仍只交付 final executable artifact truth。
- 让 `TCompilationSession` 正式拥有并重置 `tool-run-status`、`tool-run-step-count`
  与 `primary-tool-run-status`，并把这些状态投影到 line-based output 与
  `command-envelope=<json>` 中。
- 让 `build/verify_local.sh` 继续 fresh 通过，并在 success/failure gate 里验证
  `tool-run-*` 字段保持同步。

### 这批的范围

- 在 `compiler/frontend/np_compilation_session.pas` 引入 `ExecuteToolchain(...)`，记录 runner
  选择/启动/成功/失败，并替代原来粗暴的 `TProcess` 辅助逻辑。
- 把 `tools/stage0/nextpas.pas` 的 host-compiler production path 切到
  `Session.ExecuteToolchain(GetEnvironmentVariable('PATH'))`，去掉 `ResolveCompilerExecutable`
  与 `RunPrimaryToolProcess` 的手写代码。
- 在 projection context 与 envelope 输出里清晰加入
  `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
  以及对应的 camelCase `toolRunStatus`/`toolRunStepCount`/`primaryToolRunStatus`。
- 让 `build/verify_local.sh` 既在 success gate，也在模拟 failure gate
  （例如 `stage0-smoke`、`semantic-smoke`、`toolchain-failure`）里断言这些字段。

### Promotion gate

- `bash build/verify_local.sh` 运行仍需 fresh pass，输出里必须包含
  `tool-run-status`、`tool-run-step-count` 与 `primary-tool-run-status`（success
  与 failure 两种 case 均可验证）。
- `stage0 build` 在 CLI、envelope 和 diagnostics projection 里必须继续展示
  workspace/truth fields，Runner reuse 不能破坏已有 contract。

### 这一批已经交付了什么

- `compiler/frontend/np_compilation_session.pas` 现在提供 `ExecuteToolchain(...)`，并在
  `TToolchainRunResult` 上归一化非零退出 code 的 failure text（`compiler exit code N`）。
- `tools/stage0/nextpas.pas` 已切到 `Session.ExecuteToolchain(GetEnvironmentVariable('PATH'))`，
  老的手写 helper `ResolveCompilerExecutable`/`EnsureBuildDirectories`/`RunPrimaryToolProcess`
  都已移除。
- `tools/stage0/nextpas.pas` 的 `PrintToolchainProjection(...)` 与 envelope 现在都会
  输出 `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status` 以及 camelCase counterpart。
- `build/verify_local.sh` 现在在 `stage0-smoke`、`semantic-smoke`、`toolchain-failure`
  gate 中断言这三个字段，并 fresh `bash build/verify_local.sh` 仍得
  `toolchainContractCheck=pass` 与 `verify-local=pass`。

## Batch 21: backend intermediate artifact truth + logical object input

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

- 让 `compiler/backend/np_backend_plan.pas` 不再只拥有 final output 的最小 truth，而是正式按顺序
  持有 `assembly-text`、`object-file` 与 `executable` 三类 artifact truth，并把 `.s/.o`
  固定落到 `<artifact-root>/cache/backend/<target>/`。
- 让 `TCompilationSession` 与 `tools/stage0/nextpas.pas` 把这份 backend-owned truth
  投影成正式 machine-readable surface：line-based `backend-artifact-count` /
  `backend-artifacts`，以及 envelope `backendArtifactCount` / `backendArtifacts`。
- 让 `logical-link-request.objectInputs` 开始真实引用 backend-owned `object-file` artifact，
  为 future native link selection 先冻结 object-level input truth。
- 继续守住边界：production path 仍保持 host-compiler single-step execution，不把这一批包装成
  已切到 native assembler/linker。

### 这批的范围

- 扩展 `compiler/backend/np_backend_plan.pas`，为 backend plan 增加 typed artifact inventory、
  artifact lookup helper 与 backend cache root 计算。
- 扩展 `compiler/frontend/np_compilation_session.pas`，把 backend artifact count / artifact JSON
  收成 session-owned projection。
- 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让当前 logical link request 的
  `objectInputs` 开始消费 backend-owned `.o`。
- 扩展 `tools/stage0/nextpas.pas` 与 `build/verify_local.sh`，把
  `backend-artifact-count`、`backend-artifacts`、`logical-link-request.objectInputs` 与
  camelCase envelope counterpart 纳入真实 promotion gate。

### Promotion gate

- fresh `bash build/verify_local.sh` 必须继续 pass。
- `stage0 build` 的成功输出里必须出现 `backend-artifact-count=3` 与
  `backend-artifacts=<json>`。
- `logical-link-request.objectInputs` 必须真实包含 backend-owned `object-file` path，而不是空数组
  或 driver 猜测出来的路径。
- `command-envelope=<json>.result` 必须同步带上 `backendArtifactCount` 与
  `backendArtifacts`。

### 这一批已经交付了什么

- `compiler/backend/np_backend_plan.pas` 现在已固定按顺序持有
  `assembly-text -> object-file -> executable` 三类 artifact truth，并让 backend cache
  layout 收口到 `<artifact-root>/cache/backend/<target>/`。
- `compiler/frontend/np_compilation_session.pas` 现在已把
  `backendArtifactCount` / `backendArtifacts` 暴露成 session-owned projection。
- `compiler/toolchain/np_toolchain_plan.pas` 现在会把 backend-owned `object-file`
  artifact 接进 `logicalLinkRequest.objectInputs`。
- `tools/stage0/nextpas.pas` 与 `build/verify_local.sh` 现在已真实投影并 gate
  `backend-artifact-count`、`backend-artifacts`、`backendArtifactCount`、
  `backendArtifacts`，以及 logical object input truth。
- fresh `bash build/verify_local.sh` 继续得到 `toolchainContractCheck=pass` 与
  `verify-local=pass`。

## Batch 22: bootstrap-native assemble/link production path

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

- 让 `PlanFromBackend` 不再停留在 single-step host-compiler execution，而是合法选择
  `bootstrap-native-assemble-link` production path。
- 让当前 `stage0 build` 的真实执行面改成三步 bootstrap-native 路径：
  `host-fpc-emit-asm -> native-assemble -> native-link`。
- 让根程序和 source-backed units 的 `.s`、backend-owned `.o` 与确定性的
  `<program>_link.res` 都真正进入 backend cache ownership，而不是继续停留在“future native path”
  的文档前置描述。
- 保持当批次交付时的可观测性边界诚实：production path 已经切换，但 later-step
  failure attribution 当时仍未完成（现已在 `Batch 23` 收口）。

### 这批的范围

- 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 `PlanFromBackend` 直接选择
  `PlanBootstrapNativeAssembleLink(...)`。
- 在 `compiler/frontend/np_compilation_session.pas` 收集 source-backed units 的额外 assembly
  base name，让 toolchain planner 能为这些单元追加 `native-assemble-<unit>` steps。
- 扩展 `build/verify_local.sh`，真实 gate
  `toolchain-plan-family=bootstrap-native-assemble-link`、
  `tool-invocation-count=3`、`tool-run-step-count=3`、
  `primary-tool-step-id=host-fpc-emit-asm`、`build-trace-ref=...-host-fpc-emit-asm`
  与 `logical-link-request.objectInputs=[backend-owned <program>.o]`。
- 回写 `tools/stage0/README.md`、架构规范、路线图与持续记录，避免文档继续宣称 production path
  仍待切换。

### Promotion gate

- fresh `bash build/verify_local.sh` 必须继续 pass。
- `stage0 build examples/smoke/hello.pas --target linux-x86_64` 必须显式投影
  `toolchain-plan-family=bootstrap-native-assemble-link`、
  `tool-invocation-count=3`、`tool-run-step-count=3`、
  `primary-tool-step-id=host-fpc-emit-asm` 与
  初始 success trace locator；当前公开 contract 已在 `Batch 24` 升级为
  `build-trace-ref=trace-<session-id>-toolchain-plan`。
- `stage0 build examples/smoke/hello_with_units.pas --target linux-x86_64` 必须继续走同一条
  bootstrap-native path，并保持 `logical-link-request.objectInputs` 指向 backend-owned `.o`。
- source-backed unit root 场景必须能额外规划并成功执行 `native-assemble-<unit>` step，而不是再让
  真正的多文件 smoke 停在根程序单步假绿。

### 这一批已经交付了什么

- `compiler/toolchain/np_toolchain_plan.pas` 现在已让 `PlanFromBackend` 直接选择
  `bootstrap-native-assemble-link`，并生成
  `host-fpc-emit-asm -> native-assemble -> native-link` 的 production-path plan。
- 当前 emit-asm step 已真实使用 `fpc -st -Aas -FE<backend-cache> -FU<backend-cache> ...`，
  把根程序集成物和确定性的 `<program>_link.res` 写进 backend cache。
- 当前 native link step 已真实使用 `ld.bfd` 通过 backend-owned `<program>_link.res`
  链出最终 executable。
- `compiler/frontend/np_compilation_session.pas` 现在会为 source-backed units 收集额外
  assembly base names，使 explicit unit root / multi-file 场景能够继续追加
  `native-assemble-<unit>` step。
- `build/verify_local.sh` 现在已把 success / semantic-smoke / toolchain-failure 三条代表路径
  的 `bootstrap-native-assemble-link` contract 纳入真实 gate。
- `tools/stage0/README.md`、`docs/architecture/stage0-driver-specification.md`、
  `docs/architecture/toolchain-specification.md`、
  `docs/architecture/diagnostics-specification.md`、本路线图与持续记录文件都已同步改成当前事实。
- fresh `bash build/verify_local.sh` 继续得到 `verify-local=pass` 与
  `human-summary=local verification passed`。

## Batch 23: later-step failure attribution for bootstrap-native assemble/link

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

- 让 `native-assemble` / `native-link` failure 不再被 primary step `host-fpc-emit-asm`
  吞掉，而是真实投影为 assembler/linker 自己的 failure kind。
- 让 `diagnostic-step-id`、`diagnostic-profile-id`、`diagnostic-logical-executable`、
  `build-trace-ref` 与 status-event step metadata 对齐到真实失败 step。
- 让 `stage0` 的公开 `failure-kind` 优先使用 session 的真实 diagnostic code，
  不再把 later-step failure 回退成 primary-tool failure mapping。
- 让 `build/verify_local.sh` 新增 fake `as` / `ld` negative path gate，并把
  `assemblerFailureAttributionCheck` / `linkerFailureAttributionCheck` 收进 success envelope。

### 这批的范围

- 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 invocation steps 显式携带
  `toolRole/profileId/sysrootRef` 并为 `native-assemble` / `native-link` 写入 step context。
- 扩展 `compiler/frontend/np_compilation_session.pas`，让 diagnostics / build trace /
  status event / `buildTraceRef` 在 failure path 上跟随真实失败 step。
- 调整 `tools/stage0/nextpas.pas` 的 runner failure projection，优先使用 session 的
  `LastDiagnosticCode`。
- 扩展 `build/verify_local.sh`，新增
  `assembler-failure-attribution-check` 与 `linker-failure-attribution-check`。
- 同步回写 README、架构规范、路线图与持续记录；这批收口时留下的 success-path summary
  residual risk 已在后续 `Batch 24` 关闭。

### Promotion gate

- fresh `bash build/verify_local.sh` 必须继续 pass。
- fake `as` 负路径必须显式投影 `toolchain.assembler-exec-failed`，
  并把 `diagnostic-profile-id=gnu-as`、`diagnostic-step-id=native-assemble`、
  `diagnostic-logical-executable=as`、`build-trace-ref=trace-<session-id>-toolchain-plan`、
  `tool-run-step-count=2` 与 `primary-tool-run-status=success` 固定下来。
- fake `ld.bfd` 负路径必须显式投影 `toolchain.linker-exec-failed`，
  并把 `diagnostic-profile-id=gnu-ld`、`diagnostic-step-id=native-link`、
  `diagnostic-logical-executable=ld.bfd`、`build-trace-ref=trace-<session-id>-toolchain-plan`、
  `tool-run-step-count=3` 与 `primary-tool-run-status=success` 固定下来。
- `command-envelope=<json>` 与 line-based output 必须对同一条 later-step failure
  使用一致的 `diagnostic/buildTrace/toolRun` truth。

### 这一批已经交付了什么

- `compiler/toolchain/np_toolchain_plan.pas` 现在让 `TToolInvocationStep` 持有
  `ToolRole`、`ProfileId` 与 `SysrootRef`，并对 `native-assemble` / `native-link`
  写入真实 step context。
- `compiler/frontend/np_compilation_session.pas` 现在会在 failure path 上定位真实失败 step，
  并让 `diagnostic-step-id`、`diagnostic-profile-id`、
  `diagnostic-logical-executable`、`build-trace-ref`、`tool-status-events` 与
  `buildTrace.steps[*].diagnosticRefs` 跟随失败 step 走。
- `tools/stage0/nextpas.pas` 现在会优先把 `Session.LastDiagnosticCode` 投影成公开
  `failure-kind`，从而让 assembler/linker failure 不再退回
  `toolchain.host-compiler-exec-failed`。
- `build/verify_local.sh` 现在已新增
  `assembler-failure-attribution-check`、`linker-failure-attribution-check`，
  success envelope 也已带上 `assemblerFailureAttributionCheck` 与
  `linkerFailureAttributionCheck`。
- `tools/stage0/README.md`、`docs/architecture/stage0-driver-specification.md`、
  `docs/architecture/toolchain-specification.md`、
  `docs/architecture/diagnostics-specification.md`、本路线图与持续记录文件都已同步改成
  当前 reality：later-step failure attribution 已完成；后续 `Batch 24` 进一步把
  success-path transcript 也做成完整 multi-step trace。
- fresh `bash build/verify_local.sh` 继续得到 `verify-local=pass` 与
  `human-summary=local verification passed`。

## Batch 24: success-path toolchain observability transcript hardening

- 状态：完成
- 归属路线段：Typed HIR / MIR / Backend / Toolchain Boundary

### 这一批要解决什么

- 让 success path 的 `tool-status-events` 不再只输出单步摘要，而是完整暴露
  `host-fpc-emit-asm -> native-assemble -> native-link` 的 executed-step transcript。
- 让 `build-trace-ref` 从 step-anchored locator 升级为统一的
  `trace-<session-id>-toolchain-plan`，并让 success / failure 两侧都对齐同一条 plan-level
  trace。
- 让 `buildTrace.steps[*]` 对 success/failure 都保留全部 executed steps，只有真实失败 step
  才继续带上 `diagnosticRefs`。
- 让 runner sidecar 也进入正式 observability contract，暴露 `materialized` 与
  `cleanupStatus` truth，而不是只靠最终文件是否存在来猜。

### 这批的范围

- 扩展 `compiler/toolchain/np_toolchain_runner.pas`，把 executed sidecar truth 收进
  `TToolchainExecutedStep`。
- 扩展 `compiler/frontend/np_compilation_session.pas`，让 status event / build trace 对
  success path 也按全部 executed steps 投影，并把 `buildTraceRef` 固定到 plan-level locator。
- 扩展 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`，
  冻结 `native-run-transcript`、success-path event count、plan-level trace ref 与
  full-step `buildTrace.steps[*]` contract。
- 同步回写 README、架构规范、路线图与持续记录文件，清理“success path 仍是
  单步摘要”的旧表述。

### Promotion gate

- fresh `bash build/verify_local.sh` 必须继续 pass。
- `stage0 build examples/smoke/hello.pas --target linux-x86_64` 必须显式投影
  `tool-status-event-count=10`、`build-trace-ref=trace-<session-id>-toolchain-plan`，
  并让 `tool-status-events`、`buildTrace.steps[*]` 按顺序覆盖
  `host-fpc-emit-asm`、`native-assemble`、`native-link`。
- fake `as` / `ld` 负路径也必须继续使用同一条
  `build-trace-ref=trace-<session-id>-toolchain-plan`，同时把失败 attribution 仍落在
  `native-assemble` / `native-link`。
- `tests/toolchain/toolchain_contract_smoke.pas` 必须显式产出 `native-run-transcript=<json>`，
  其中 sidecar truth 要包含 `materialized=true|false` 与
  `cleanupStatus=deleted|retained|not-requested`。

### 这一批已经交付了什么

- `compiler/toolchain/np_toolchain_runner.pas` 现在会把 executed sidecar truth 收进
  runner transcript，link step sidecar 还能暴露真实 `cleanupStatus`。
- `compiler/frontend/np_compilation_session.pas` 现在会在 success/failure 两侧都产出完整的
  executed-step transcript，并统一使用
  `buildTraceRef=trace-<session-id>-toolchain-plan`。
- `buildTrace.steps[*]` 现在会按执行顺序留下 `stepId/profileId/toolRole/status`、
  `logicalExecutable/sysrootRef/resolvedPath`、`primaryOutputs`、`sidecars`，并只在失败 step
  上带 `diagnosticRefs`。
- `build/verify_local.sh` 现在已把 success-path `tool-status-event-count=10`、
  plan-level trace ref、later-step failure 的 plan-level trace ref、以及
  `native-run-transcript` sidecar cleanup truth 全部收进正式 gate。
- `tools/stage0/README.md`、`docs/architecture/stage0-driver-specification.md`、
  `docs/architecture/toolchain-specification.md`、
  `docs/architecture/diagnostics-specification.md`、本路线图与持续记录文件都已同步改成
  当前 reality。
- fresh `bash build/verify_local.sh` 继续得到 `verify-local=pass` 与
  `human-summary=local verification passed`。

## Batch 25: explicit toolchain binding override + LLVM execution path

- 状态：完成
- 归属路线段：Target / Cross / LLVM / C Interop

### 这一批要解决什么

- 让 `stage0 build` 把 target 选择与 toolchain binding 选择正式分开：`--target` 继续定义
  目标语义，`--toolchain-binding` 只在同一 host/target pair 下覆盖执行绑定。
- 让同一个 `linux-x86_64 -> linux-x86_64` target 能在默认 GNU/native binding 与显式
  LLVM-heavy binding 之间切换，而不是再把 backend family 写死在 target config 里。
- 让 backend artifact truth 与 toolchain plan family 开始随 binding family 变化：
  native 继续是 `assembly-text/object-file/executable`，
  LLVM 则升级成 `llvm-ir/llvm-bitcode/object-file/executable`。
- 让 `build/verify_local.sh` 与 toolchain contract smoke 对这条显式 LLVM path 建立真实 gate，
  而不是只靠文档声称“未来可切换”。

### 这批的范围

- 扩展 `tools/stage0/target_config.pas` 与 `tools/stage0/nextpas.pas`，正式接入
  `--toolchain-binding <id>`。
- 新增 LLVM binding config 与 `ld.lld` linker profile，让同一 target 能被另一条 binding
  托管。
- 扩展 `compiler/backend/np_backend_plan.pas` 与
  `compiler/toolchain/np_toolchain_plan.pas`，让 toolchain plan 按 backend family 分流到
  native 或 LLVM execution path。
- 扩展 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`，把显式
  LLVM binding smoke、plan family 与 transcript truth 纳入 promotion gate。
- 同步回写 README、架构规范、路线图与持续记录，避免公开文档继续把当前 reality 描述成
  “只有 native path”。

### Promotion gate

- fresh `bash build/verify_local.sh` 必须继续 pass。
- `stage0 build examples/smoke/hello.pas --toolchain-binding linux-x86_64-to-linux-x86_64-llvm`
  必须显式投影 `compiler=opt`、
  `toolchain-binding-id=linux-x86_64-to-linux-x86_64-llvm`、`backend-family=llvm`、
  `linker-profile-id=lld-elf`、`backend-artifact-count=4`、
  `toolchain-plan-family=llvm-ir-opt-llc-link`、`llvm-toolchain-status=ready` 与
  `primary-tool-step-id=llvm-opt-bitcode`。
- 同一条 LLVM success path 必须继续显式投影
  `tool-invocation-plan.steps[*].stepId=llvm-opt-bitcode/llvm-llc-object/llvm-link`、
  `logical-link-request.objectInputs=[backend-owned <program>.o]` 与
  `build-trace.steps[*].status=success`。
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 必须一起冻结
  native/default binding 与 explicit LLVM binding 两条 execution family，而不是让任一方
  再退回单一路径假设。

### 这一批已经交付了什么

- `tools/stage0/target_config.pas` 现在允许加载同一 host/target pair 下的 binding override，
  并对 host/target/compiler mismatch 给出结构化拒绝。
- `tools/stage0/nextpas.pas` 现在已正式支持 `--toolchain-binding <id>`，usage 已同步更新，
  `RunBuild(...)` 会把 binding override 送进 target config 解析，而且 line-based
  `compiler=` 现在会如实投影 active build context，所以 LLVM smoke 会看到 `compiler=opt`。
- `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml` 与
  `build/tool-profiles/linkers/lld-elf.toml` 已把显式 LLVM binding 与 `ld.lld` profile
  落成真实仓库实体。
- `compiler/backend/np_backend_plan.pas` 现在会按 backend family 产出 binding-aware artifact
  truth：native 保持 `assembly-text/object-file/executable`，LLVM 改成
  `llvm-ir/llvm-bitcode/object-file/executable`。
- `compiler/toolchain/np_toolchain_plan.pas` 现在会让 `PlanFromBackend` 按 backend family
  选择 execution path：默认 native 继续走 `bootstrap-native-assemble-link`，显式 LLVM
  binding 走 `llvm-ir-opt-llc-link`，并执行
  `llvm-opt-bitcode -> llvm-llc-object -> llvm-link`，最终通过 `ld.lld` 产出 executable。
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 现在已把显式
  LLVM binding smoke 纳入公开 gate，真实断言 LLVM artifacts、plan family、step ids 与
  transcript truth。
- fresh `bash build/verify_local.sh` 继续得到 `toolchainContractCheck=pass`、
  `semanticSmokeCheck=pass`、`toolchainFailureCheck=pass`、
  `assemblerFailureAttributionCheck=pass`、`linkerFailureAttributionCheck=pass` 与
  `verify-local=pass`。

## Batch 26: minimal external cdecl foreign binding contract

- 状态：完成
- 归属路线段：Target / Cross / LLVM / C Interop

### 这一批要解决什么

- 把第一条最小 C interop declaration shape 正式接进当前 compiler spine，而不是继续让
  `external 'c'` 只在宿主 FPC/linker script 里隐式生效。
- 让 `procedure <id>; cdecl; external 'c' name '<symbol>';` 开始在 syntax / sema /
  backend / toolchain 上形成一条稳定事实链。
- 让缺少显式 `name '<symbol>'` 的 external declaration 在语义层直接失败，而不是拖到
  later link failure 或宿主工具链偶然行为。

### 这批的范围

- 扩展 `compiler/syntax/np_lexer.pas`、`compiler/syntax/np_green_tree.pas` 与
  `compiler/syntax/np_ast_facade.pas`，识别最小 `procedure ... cdecl; external 'c' ...`
  declaration shape。
- 扩展 `compiler/sema/np_semantic_model.pas` 与
  `compiler/sema/np_semantic_analyzer.pas`，产出 typed `foreign-procedure-binding` 与
  logical library request，并新增 `sema.missing-external-symbol-name` baseline。
- 扩展 `compiler/backend/np_backend_plan.pas`、
  `compiler/frontend/np_compilation_session.pas` 与
  `compiler/toolchain/np_toolchain_plan.pas`，把 semantic-owned logical library request
  正式带进 backend/toolchain control plane。
- 扩展 `build/verify_local.sh`、`tests/compiler/fail/` snapshot baseline、
  `tests/harness/runner.pas` 与 `examples/smoke/external_cdecl_smoke.pas`，把正反两条 gate
  纳入公开验证面。
- 同步回写 C interop 规范、`stage0` README 与本路线图，确保公开文档不再把这条边界描述成
  “尚未接入实现”。

### Promotion gate

- fresh `bash build/verify_local.sh` 必须继续 pass。
- `stage0 build examples/smoke/external_cdecl_smoke.pas --target linux-x86_64` 必须显式投影
  `logical-link-request-library-count=1`，且
  `logical-link-request.libraryRequests[]` 必须带上
  `{logicalId:"c", linkageKind:"shared", strength:"strong"}`。
- 同一条 success path 的 `command-envelope=<json>` 也必须带上同一条
  `logicalLinkRequest.libraryRequests[]` truth。
- `stage0 build tests/compiler/fail/missing_external_symbol_name_fail.pas --target linux-x86_64`
  必须以 `failure-kind=semantic-analysis-failed` 失败，并显式投影
  `diagnostic-code=sema.missing-external-symbol-name` / `diagnostic-phase=sema`。
- `tests/run_all_tests.sh --filter compiler-fail` 必须把
  `compiler-fail-missing_external_symbol_name.stderr.txt` 稳定到 ready，而不是继续接受
  `unexpected-build-success` 或 later linker noise。

### 这一批已经交付了什么

- `compiler/syntax/np_lexer.pas`、`compiler/syntax/np_green_tree.pas` 与
  `compiler/syntax/np_ast_facade.pas` 现在已能收口最小
  `procedure <id>; cdecl; external 'c' name '<symbol>';` declaration，green tree 会把它保存成
  typed foreign declaration fact，而不是继续整段忽略。
- `compiler/sema/np_semantic_model.pas` 与
  `compiler/sema/np_semantic_analyzer.pas` 现在已把这条 declaration 变成
  `foreign-procedure-binding` + logical library request，并在缺少显式 `name` 时直接产出
  `sema.missing-external-symbol-name`。
- `compiler/backend/np_backend_plan.pas`、
  `compiler/frontend/np_compilation_session.pas` 与
  `compiler/toolchain/np_toolchain_plan.pas` 现在会把 semantic-owned C library request
  继续带进 `logical-link-request.libraryRequests[]`，所以 `stage0 build` 的 line-based output
  与 `command-envelope=<json>` 都开始显式拥有这条 truth。
- `build/verify_local.sh`、`examples/smoke/external_cdecl_smoke.pas`、
  `tests/compiler/fail/missing_external_symbol_name_fail.pas`、
  `tests/snapshots/compiler-fail-missing_external_symbol_name.stderr.txt` 与
  `tests/harness/runner.pas` 现在已把正向 `logical library request` 与反向 semantic fail
  都纳入公开 gate。
- fresh `./tests/run_all_tests.sh --filter compiler-fail` 已重新回到 `status=ready` /
  `result=pass`。

## Batch 26 之后怎么继续

`Batch 27` 继续把上一批只停留在 projection 的 C library request 推进到 direct-link
execution contract，但仍严格守住当前 ownership 边界：

- `compiler/toolchain/np_toolchain_plan.pas` 现在会在
  `native-assemble-link` 与 `llvm-ir-opt-llc-link` 两条 direct-link plan 上，
  先把 `logical-link-request.libraryRequests[]` 里的最小
  `{logicalId:"c", linkageKind:"shared", strength:"strong"}` 解析到
  repo-local `lib/nextpas/runtime/<runtime-sdk>/libc.so`，再把 `-L<runtime-root>` 与 `-lc`
  序列化进真实 linker argv。
- 同一批现在也冻结了缺失 runtime libc 的 planning-side failure：
  当 direct-link plan 请求 `logicalId="c"` 但当前 `distribution-runtime-root`
  下没有 `libc.so` 时，planner 会直接失败并产出
  `toolchain.c-library-not-found`，而不是继续把问题拖到 later linker noise。
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已把 native direct-link、LLVM direct-link 与 missing-libc negative
  一起收进真实 gate，确认 direct-link linker argv 已带上 runtime-root / libc truth。
- 这批故意不接管默认 `bootstrap-native-assemble-link` 的宿主
  `*_link.res` ownership；host FPC 仍然可以继续决定那条路径里的 `SEARCH_DIR(...)` /
  `GROUP(-lc)` 细节，避免这批同时把宿主 linker script 改写权也吞进来。

`Batch 27` 收口后，继续按 `master-roadmap.md` 滚动下一组批次：

- workspace / package / developer tooling
- GUI framework / IDE

`Batch 28` 当前先把 developer tooling 里最容易失真的一段收成真实公开面：

- `tools/stage0/nextpas.pas` 现在新增最小 `test` family，支持
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]`
- 这批故意不重写 `tests/run_all_tests.sh` / `tests/harness/runner.pas`，而是把它们作为
  execution owner 保留下来；`stage0` 只负责参数解析、workspace root 选择与 thin wrapper
- `build/verify_local.sh` 现在把 `nextpas test` 的 list-groups、invalid-arguments、
  unknown-group、compiler-pass 与 smoke 五条 contract 一起收进真实 gate
- 这批故意不提前把 `doctor` / `env` / `query` 拉进来，也不把 GUI / IDE 提前伪装成当前实现面

`Batch 29` 当前再把 `env` family 的第一条只读 surface 收成真实公开面：

- `tools/stage0/nextpas.pas` 现在新增
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]`
- 这批故意只做 read-only environment projection：当前会显式投影
  `toolchain-binding-path`、distribution bin/lib/share、`runtime-root`、`runtime-libc`、
  `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`
- 这批继续冻结 `env status` 不是 `doctor`：即使 environment 仍不完整，也保持
  `status=success` / `result=success`，把 readiness truth 留在结果字段里
- `build/verify_local.sh` 现在把 `stage0EnvStatusCheck` 与
  `stage0EnvInvalidArgumentsCheck` 收进真实 gate
- 这批故意不提前把 `env use` / `env sync` / `env bootstrap` / `doctor` / `query`
  拉进来，也不把 GUI / IDE 提前伪装成当前实现面

`Batch 30` 当前把 `doctor` family 的第一条只读 surface 收成真实公开面：

- `tools/stage0/nextpas.pas` 现在新增
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- 这批故意只做 aggregate health inspection：当前会复用 `env status` 的
  target/binding/distribution/runtime truth，并额外投影 `doctor-status`、
  `doctor-check-count` 与 `doctor-finding-count`
- 这批继续冻结 `doctor` 不是 `env sync`：即使 runtime SDK 仍缺失，inspection 本身也保持
  `status=success` / `result=success`，把健康问题写进 doctor fields
- `build/verify_local.sh` 现在把 `stage0DoctorCheck` 与
  `stage0DoctorInvalidArgumentsCheck` 收进真实 gate
- 这批故意不提前把完整 finding taxonomy、suggested action、`env use` /
  `env sync` / `env bootstrap`、`query` 或 package workflow 伪装成当前实现面

`Batch 31` 当前把 `doctor` result contract 从 aggregate summary 加固成可消费的最小
structured finding surface：

- `tools/stage0/nextpas.pas` 现在新增最小 `TDoctorFinding`，并让 `doctor` 输出
  `doctor-workspace-status` 与 `doctor-toolchain-binding-status`
- runtime SDK 缺失会稳定输出 `doctor-finding-code=doctor.runtime-sdk-missing` 与
  `doctor-finding-severity=warning`
- `command-envelope=<json>.result.doctorFindings[]` 现在保存同一条 finding 的
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`
- 这批继续冻结 `doctorFindings` 是 health inspection result，不替代 compiler diagnostics sink
- 这批仍不把 package/workspace coherence、environment mutation verbs、`query` 或 package workflow
  伪装成当前实现面

`Batch 32` 当前把 `env status` readiness evidence 从 runtime-only projection 加固成可被
`doctor` 与 future `env sync` 复用的最小 state contract：

- `tools/stage0/nextpas.pas` 现在让 `TEnvironmentProjectionContext` 同时持有
  `environment-status`、`toolchain-binding-status` 与 `distribution-status`
- `environment-readiness` 继续保留为兼容字段，并与 `environment-status` 使用同一
  derived readiness vocabulary
- `command-envelope=<json>.result` 现在同步投影 `environmentStatus`、
  `toolchainBindingStatus` 与 `distributionStatus`
- 当前 environment 不完整时，`env status` 仍保持 `status=success` / `result=success`，
  把未就绪事实留在 state fields，而不是伪装成 command failure
- 这批继续冻结 `env status` 不承担 `env sync` / `env use` / `env bootstrap`

`Batch 33` 当前把 `query` family 的第一条只读 semantic surface 收成真实公开面：

- `tools/stage0/nextpas.pas` 现在新增
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- 这批故意只做 compilation-session-backed semantic query：当前会复用 shared workspace model、
  target facts、unit resolution 与 semantic model，并投影 `query-kind=symbols`、
  `query-status=success`、`analysis-source=compilation-session` 与
  `query-result-count=<count>`
- 这批继续冻结 `query symbols` 不是完整 language service：它不提供 LSP server、open document
  overlay、incremental invalidation、references、rename preflight 或 completion
- `build/verify_local.sh` 现在把 `stage0QueryCheck` 与
  `stage0QueryInvalidArgumentsCheck` 收进真实 gate
- 这批不执行 MIR、backend 或 toolchain；成功 transcript 会如实停在
  `ir:deferred,backend:deferred,toolchain:deferred`

`Batch 34` 当前把 `pkg` family 的第一条只读 package workflow surface 收成真实公开面：

- `tools/stage0/nextpas.pas` 现在新增
  `nextpas pkg inspect --workspace <root> --target linux-x86_64 [--toolchain-binding <id>]`
- 这批故意只做 workspace-model-backed package workflow projection：当前会复用 shared
  workspace model、target facts 与 toolchain binding，并投影 `package-workflow-status=ready|missing`、
  `package-manifest-status=ready|missing`、`package-lock-status=ready|missing`、
  `package-workflow-manifest-path=<path>`、`package-root-path=<path>`、`package-name=<name>`、
  `package-lockfile-path=<path>`、`package-source-root-count=<count>`、
  `package-source-roots=<json-array>` 与
  `package-install-plan-status=ready|blocked|missing`、
  `package-install-plan-blocker-code` 与
  `package-install-plan-blocker-message`
- `compiler/frontend/np_package_workflow.pas` 现在补齐
  `BuildPackageWorkflowTruthFromWorkspaceModel`，让 package workflow truth 可以直接消费
  `WorkspaceModel` 并投影 manifest/lock/install plan status
- 这批继续冻结 `pkg inspect` 不是完整 package manager：它不执行 fetch、install、
  dependency resolution、lockfile write 或 publish workflow
- `build/verify_local.sh` 现在把 `stage0PkgCheck` 与
  `stage0PkgInvalidArgumentsCheck` 收进真实 gate
- 这批不把 registry lookup、mirror selection、package graph resolution、install placement
  或 render asset preprocessing 伪装成当前实现面

`Batch 35` 当前把 resolver error recovery 收成真实编译器核心加固：

- `compiler/frontend/np_unit_resolver.pas` 现在修改 `ResolveDependencyList`，从”遇到第一个
  失败就退出”改为”累积所有失败并继续处理剩余 dependencies”
- 当多个 units 缺失时，resolver 现在会报告所有缺失的 units，而不是只报告第一个
- `tests/compiler/fail/multiple_missing_units_fail.pas` 新增测试用例，包含两个缺失的 units
- `build/verify_local.sh` 新增 `multiple-missing-units-check`，验证 `diagnostics-count=2`
  且两个 unit-not-found 错误都被报告
- `docs/architecture/unit-resolution-specification.md` 新增”resolver 在部分失败时继续处理
  并累积所有错误”章节，文档化错误恢复策略及其对 future language service 的意义
- 这批故意只做 resolver error recovery，不改变 workspace discovery 或 diagnostics 结构：
  当前 workspace model 对 malformed manifest 的处理已在后续 glm51 分支继续加固（`TryResolveWorkspaceModel`
  会在 manifest 格式错误时发诊断但继续 workspace-root-only 模型），diagnostics 结构扩展
  （RelatedInformation、SuggestedFix）也已在 glm51 分支加入 `TDiagnosticRecord`

在接下来的滚动周期里，已经完成的 bootstrap-native production path、later-step failure
attribution、success-path transcript hardening、显式 LLVM binding execution path，以及
这次 direct-link C library resolution contract，再加上 `nextpas test` 与最小
`nextpas env status` / `nextpas doctor` / `doctorFindings` / env readiness evidence /
`nextpas query symbols` / `nextpas pkg inspect`，以及 resolver error recovery，已经让
`PlanFromBackend`、backend artifact truth、generic runner、logical link request、
execution-side link serialization、最小 developer tooling state surface / health inspection、
semantic query surface、package workflow projection 与 compiler core robustness
真正接成一条更完整的控制链；
下一批不应该再回头补”library request 有没有进入 argv”、”env state 能不能被只读投影”、
“doctor 能不能作为 command surface 执行”、”runtime SDK finding 能不能结构化输出”、
“env readiness evidence 能不能稳定输出”、”query symbols 能不能走 compilation session”、
“query symbols 能不能投影具体 symbol detail”、”pkg inspect 能不能投影 package workflow status”或”resolver 能不能累积多个错误”
这类已闭环问题，
而应该转回 richer developer tooling 与更高层控制面。

但这些后续批次必须建立在前面已完成批次的真实收口之上，而不是提前平行开工。

## 这份计划故意不做什么

- 不改写已完成 phase1 文档的任务编号和历史状态。
- 不把 packages sidecar、GUI 规范或 IDE 规范伪装成当前默认实现批次。
- 不把 master roadmap 写成“本轮一次性做完 1-7 全部路线段”的承诺。
- 不允许新的批次脱离当前仓库真实实现面，重新回到空谈。

这份计划真正要交付的是：一条可执行、可验证、可留证的 post-phase1 主线入口。

## Batch 36: driver decomposition + compiler core hardening (glm51 branch)

- 状态：完成
- 归属路线段：Control Surface and Session Foundation / Unit Resolution and Semantic Core

### 这一批要解决什么

把 `tools/stage0/nextpas.pas` 从 4140 行单体驱动拆分为纯 CLI 解析 + 命令分发（372 行），
消除所有 Active* 全局变量，统一 TNextPasState 参数传入，消除 4 处重复 JSON helper，
并继续加固编译器核心：malformed manifest 优雅降级、诊断模型扩展、搜索索引 staleness tracking。

### 这一批已经交付了什么

- `tools/stage0/nextpas.pas` 从 4140 行降至 372 行，只保留 CLI 解析 + 命令分发 + 主程序体
- 提取 13 个专注单元：projection_types, json_helpers, projection_json, projection_text,
  projection_context, command_envelope, command_build, command_test, command_env,
  command_doctor, command_query, command_pkg
- 消除所有 13 个 Active* 全局变量，改为 TNextPasState record 参数传入
- 消除 4 处重复 JsonEscape/JsonString/AppendJsonField，统一到 nextpas_json_helpers
- `compiler/frontend/np_package_manifest.pas` 新增 `TryLoadPackageManifestInfo`，
  manifest 解析失败时返回空 info + 错误文本
- `compiler/frontend/np_workspace_model.pas` 新增 `TryResolveWorkspaceModel`，
  manifest 解析失败时发诊断但继续 workspace-root-only 模型
- `compiler/diagnostics/np_diagnostics_sink.pas` 扩展 TDiagnosticRecord：
  添加 TRelatedInformation + TSuggestedFix record 类型和对应数组字段
- `compiler/frontend/np_unit_resolver.pas` 添加 staleness tracking：
  TRootSearchIndex.LastScanTimestamp + SearchIndexLastScanTimestamp accessor
- fresh `bash build/verify_local.sh` 继续得到 verify-local=pass

### Promotion gate

- nextpas.pas 行数 ~300-400（仅 CLI 解析 + 命令分发）
- 所有命令表面输出不变
- `grep -c '^var$' nextpas.pas` 全局 var 块消失
- `grep -rl 'function JsonEscape' compiler/ tools/` 只返回 nextpas_json_helpers
- verify-local=pass

## Batch 37: `query symbols` detail projection

- 状态：完成
- 归属路线段：Workspace and Developer Tooling Integration / Unit Resolution and Semantic Core

### 这一批要解决什么

把已经存在的只读 `query symbols` 从”只告诉调用方有多少 symbol”推进到可消费的结构化
symbol detail projection，让 CLI、future IDE adapter 与 automation 能消费同一份 semantic
symbol graph，而不是从 stdout 或 build output 里反推。

### 这一批已经交付了什么

- `compiler/frontend/np_compilation_session.pas` 新增 `SymbolsJson`，从 session-owned
  `TSemanticModel.SymbolAt(...)` 生成 query result JSON
- `tools/stage0/nextpas_projection_types.pas` 的 `TQueryProjectionContext` 新增
  `SymbolsJson`
- `tools/stage0/nextpas_projection_text.pas` 新增 line-based `query-symbols=<json-array>`
- `tools/stage0/nextpas_projection_json.pas` 新增 envelope field `querySymbols`
- `tools/stage0/nextpas_command_query.pas` 继续只执行 syntax / resolution / semantic analysis，
  并把 `Session.SymbolsJson` 投影成 query result；不执行 MIR、backend 或 toolchain
- `build/verify_local.sh` 的 `stage0-query-symbols-check` 现在会冻结 line/envelope 两层
  symbol detail，并继续断言 query path 的 MIR / backend / toolchain 状态保持 `deferred`

### Promotion gate

- `nextpas query symbols examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace <repo>`
  必须输出 `query-symbols=[...]`
- `command-envelope=<json>.result.querySymbols` 必须存在
- 代表性结果必须包含 `HelloWithUnits`、`Stage0Greeter` 与 `Stage0GreeterImpl` 三个
  `kind=unit` symbols
- `analysis-source=compilation-session` 必须保持不变
- `mir-status=deferred`、`backend-plan-status=deferred` 与 `toolchain-plan-status=deferred`
  必须保持不变
- fresh `bash build/verify_local.sh` 必须继续得到 `verify-local=pass`

## Batch 38: `query symbols` semantic metadata projection

- 状态：完成
- 归属路线段：Workspace and Developer Tooling Integration / Unit Resolution and Semantic Core

### 这一批要解决什么

Batch 37 已经让 `query symbols` 输出结构化 symbol detail，但结果仍偏 raw id：调用方能看到
`ownerUnitId`、`scopeId` 与 `typeId`，却还要自己回查 semantic model 才能展示“这个 symbol
属于哪个 unit / scope / type”。对 CLI、future IDE adapter 和 automation 来说，这会诱导它们
在 query 之外重扫源码或维护第二套 lookup。

这一批把 query result 继续收紧成 session-owned semantic metadata projection：raw ids 继续保留，
但可读 metadata 由同一份 compilation session 补齐。

### 这一批已经交付了什么

- `compiler/frontend/np_compilation_session.pas` 的 `SymbolsJson` 现在会在每个 symbol detail 中，
  从 `FUnitGraph` 补出 `ownerUnitName`
- 同一函数会从 `TSemanticModel.ScopeAt(...)` 补出 `scopeKind`、`scopeName` 与 `scopeParentId`
- 同一函数会从 `TSemanticModel.TypeAt(...)` 补出 `typeName`、`typeKind` 与可用时的
  `typeParentId`
- `build/verify_local.sh` 新增 `stage0-query-symbols-semantic-metadata-check`，用
  `examples/smoke/var_halt.pas` 冻结变量 symbol `x` 的 owner/scope/type metadata
- 这批继续保持 `query symbols` 只执行 syntax / resolution / semantic analysis，不执行 MIR、
  backend 或 toolchain

### Promotion gate

- `nextpas query symbols examples/smoke/var_halt.pas --target linux-x86_64 --workspace <repo>`
  必须输出变量 symbol `x`
- 该 symbol 必须同时带有 `ownerUnitName=VarHalt`、`scopeKind=unit`、`scopeName=VarHalt`、
  `typeName=Integer` 与 `typeKind=builtin`
- line-based `query-symbols=<json-array>` 与 envelope `querySymbols[]` 必须同步带上这批 metadata
- `analysis-source=compilation-session` 必须保持不变
- `mir-status=deferred`、`backend-plan-status=deferred` 与 `toolchain-plan-status=deferred`
  必须保持不变
- fresh `bash build/verify_local.sh` 必须继续得到 `verify-local=pass`

## Batch 39: `query symbols` semantic graph side-table projection

- 状态：完成
- 归属路线段：Workspace and Developer Tooling Integration / Unit Resolution and Semantic Core

### 这一批要解决什么

Batch 38 已经让每个 `querySymbols[]` 条目带上可读 owner/scope/type metadata，但如果 future
IDE adapter 或 automation 想按 `scopeId` / `typeId` 建立稳定索引，仍然缺少同一份 query result
里的 normalized side tables。长期看，这会诱导调用方在 CLI 之外重扫源码或自己缓存半套
semantic model。

这一批把 `TSemanticScope` 与 `TSemanticType` graph 作为 session-owned side tables 同步投影：
`querySymbols[]` 继续保留 inline metadata 方便 shell / human inspection，`queryScopes[]` 与
`queryTypes[]` 则提供可按 id 回查的 normalized truth。

### 这一批已经交付了什么

- `compiler/frontend/np_compilation_session.pas` 新增 `ScopesJson` 与 `TypesJson`，都从同一份
  `TSemanticModel` 生成 query result JSON
- `tools/stage0/nextpas_projection_types.pas` 的 `TQueryProjectionContext` 新增
  `ScopesJson` 与 `TypesJson`
- `tools/stage0/nextpas_projection_text.pas` 新增 line-based `query-scopes=<json-array>` 与
  `query-types=<json-array>`
- `tools/stage0/nextpas_projection_json.pas` 新增 envelope field `queryScopes` 与
  `queryTypes`
- `tools/stage0/nextpas_command_query.pas` 继续只执行 syntax / resolution / semantic analysis，
  并把 `Session.ScopesJson` / `Session.TypesJson` 投影成 query side tables；不执行 MIR、
  backend 或 toolchain
- `build/verify_local.sh` 新增 `stage0-query-symbols-semantic-graph-check`，用
  `examples/smoke/var_halt.pas` 冻结 unit scope `VarHalt` 与 builtin type `Integer` side table

### Promotion gate

- `nextpas query symbols examples/smoke/var_halt.pas --target linux-x86_64 --workspace <repo>`
  必须输出 `query-scopes=[...]` 与 `query-types=[...]`
- `queryScopes[]` 必须包含 `scopeId=2`、`kind=unit`、`name=VarHalt` 与 `parentScopeId=1`
- `queryTypes[]` 必须包含 `typeId=2`、`name=Integer` 与 `kind=builtin`
- `command-envelope=<json>.result.queryScopes` 与 `queryTypes` 必须同步带上这批 side tables
- `analysis-source=compilation-session` 必须保持不变
- `mir-status=deferred`、`backend-plan-status=deferred` 与 `toolchain-plan-status=deferred`
  必须保持不变
- fresh `bash build/verify_local.sh` 必须继续得到 `verify-local=pass`
