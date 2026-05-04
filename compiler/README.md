# nextPas compiler/

`compiler/` 是 nextPas 第一阶段的稳定编译器边界。这里保留的是语言前端、语义、IR、
目标约束、诊断和驱动控制面的所有权，而不是对 FPC 历史平铺源码树的逐目录镜像。

如果你要看冻结后的长期边界，先读
`docs/architecture/compiler-specification.md` 和
`docs/architecture/directory-structure-specification.md`。

## 当前子目录职责

- `frontend/`：源码摄取、编译会话建立、unit 查找与高层输入编排
- `syntax/`：受支持 FreePascal 源码形式的词法与语法分析
- `sema/`：类型检查、符号解析与可观察正确性的语义判断
- `ir/`：语义分析与后续代码生成之间的内部表示边界
- `backend/`：语义分析下游的代码生成所有权区域
- `targets/`：与编译器相关的目标平台能力视图
- `driver/`：编译控制流、命令意图落地和子模块调度
- `diagnostics/`：稳定的错误分类、输出规则和留证友好表面

## 第一阶段这里先做什么

- 先把编译器职责拆清，让 `stage0` 与后续 `stage1` 接管顺序有明确落点。
- 保持 `unit`/模块行为、核心语义和诊断输出可解释、可验证。
- 继续只服务 Linux x86_64，并把目标事实留给 `build/targets/` 外置规格处理。

当前阶段里，FreePascal 仍是 `stage0` 宿主编译器，所以 `compiler/` 先是 nextPas 的
所有权地图和实现落点，而不是已经完成接管的完整自有编译器。

## 当前已经落地的最小 skeleton

`Batch 3/4/5/6/7` 已经把最小但真实的 compiler session、syntax front、unit resolution、
semantic model，以及 `Typed HIR -> MIR -> backend plan` skeleton 落进仓库：

- `frontend/np_source_database.pas`
  - 提供 `TSourceDatabase`，统一 root source 与 resolved unit source 的 `FileId`、canonical path、source text 与 line-index state
- `frontend/np_compilation_session.pas`
  - 提供 `TCompilationSession`，统一拥有 source db、target facts、diagnostics sink、compilation options、syntax / resolution / semantic / MIR / backend artifacts
- `frontend/np_unit_graph.pas`
  - 提供 `TSearchPathSet`、`TResolvedUnit`、`TUnitGraph`，把 root/interface/implementation/implicit-runtime edge 收成显式对象
- `frontend/np_unit_resolver.pas`
  - 提供 `TUnitResolver`，把最小 search path、name resolution、cycle detection 与 resolution diagnostics 接回 compiler session
- `targets/np_target_facts.pas`
  - 提供 `TTargetFactsView`，承接 target id、config path、host facts、compiler executable，以及 object format / assembler flavor / linker flavor / LLVM triple / toolchain binding / backend family
- `diagnostics/np_diagnostics_sink.pas`
  - 提供 `TDiagnosticsSink`，承接 diagnostics policy、structured compile/toolchain diagnostics 与会话级计数
- `syntax/np_lexer.pas`
  - 提供最小 `TLexerResult`，把 root source 切成 token 流
- `syntax/np_green_tree.pas`
  - 提供最小 immutable `TGreenTree`，固定 root kind、declared name 与 node count
- `syntax/np_ast_facade.pas`
  - 提供最小 `TAstFacade`，从 green tree 暴露 typed syntax view
- `sema/np_semantic_model.pas`
  - 提供最小 `TSemanticModel`，统一 symbol/type/typed-hir/runtime-contract count、root name、semantic status 与 typed-hir iteration
- `sema/np_semantic_analyzer.pas`
  - 提供最小 `TSemanticAnalyzer`，把 builtin type、unit symbol、runtime contract seed 与 duplicate import semantic failure 接回 session
- `ir/np_mir_model.pas`
  - 提供最小 `TMirModel` 与 `TMirLowerer`，把 typed-hir nodes 下沉成 one-entry-block、target-neutral op list 与显式 `return`
- `backend/np_backend_plan.pas`
  - 提供最小 `TBackendPlan` 与 `TBackendPlanner`，把 `MIR + TargetFacts + SourcePath` 下沉成 output intent、primary artifact 与 host-compiler invocation plan

这套 skeleton 现在已经被 `tools/stage0/nextpas.pas` 在 `build` 成功路径上实际创建，
并通过 `session-id`、`source-db-file-count`、`diagnostics-count`、`syntax-status`、
`resolution-status`、`unit-graph-status`、`search-path-count`、`resolved-unit-count`、
`unit-graph-edge-count`、`unit-graph-root-name`、`semantic-status`、
`symbol-graph-status`、`type-graph-status`、`typed-hir-status`、`symbol-count`、
`type-count`、`typed-hir-node-count`、`runtime-contract-count`、`typed-hir-root-name`、
`mir-status`、`mir-block-count`、`mir-operation-count`、`mir-entry-block`、
`mir-root-name`、`backend-plan-status`、`backend-output-kind`、
`backend-primary-artifact-kind`、`backend-primary-artifact-path`、
`toolchain-binding-id`、`backend-family`、`target-object-format`、
`target-assembler-flavor`、`target-linker-flavor`、`tool-invocation-count`、
`primary-tool-role` 与 `lifecycle-session` / `lifecycle-stage` 等字段投影到当前命令结果里。
对失败输入，`stage0 build` 现在会在调用宿主 FPC 之前提前退出：

- 语法失败：`syntax-analysis-failed` + `parser.syntax-error`
- unit resolution 失败：`unit-resolution-failed` +
  `resolver.unit-not-found|resolver.ambiguous-unit-source|resolver.unit-cycle-detected`
- 语义失败：`semantic-analysis-failed` + `sema.duplicate-declaration`

## 这里现在不做什么

- 不复制 FPC `compiler/` 的历史平铺树形。
- 不在 `syntax/` 或 `sema/` 中引入 `No new syntax` 之外的新语言表面。
- 不把 `driver/` 扩张成包管理器、IDE 或 LSP 入口。
- 不把多平台矩阵写进当前目录；第一阶段仍只支持 `linux-x86_64`。
