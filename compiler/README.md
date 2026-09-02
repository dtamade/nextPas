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

**生产代码生成路径（M2 L3 / gen-B 正确性）**：Typed HIR → LLVM IR（`compiler/src/nextpas.compiler.ir.hir.llvm_emitter*` + `np_hir_llvm_emitter*.inc`）→ `opt` / `llc` / `ld`。
**MIR + backend plan 为 experimental skeleton**：会话里会创建并投影计数，**不**作为 A→B closed 或优化正确性证据；在显式开关 + golden 之前不得把 gen-B 正确性绑到 MIR pass 族（见 findings F-012 / Wave0 冻结）。

`Batch 3/4/5/6/7` 的最小 skeleton 已通过 **P1-1 命名单轨** 全量收敛至 `compiler/src` 点分扁平单轨 `nextpas.compiler.<area>.<topic>`（66 生产单元收口至 121 pas 含 thin-alias + 80 inc，原 9 散布目录清空；旧 `np_*` 仅留兼容门面，`scripts/compiler-flat-contract.sh` 断言零残留；见 `docs/plans/compiler-modernization-refactor.md` N1-N6），并经 **P1-4 去全局 ActiveExpressionTree (threadvar)** 与 **P3 性能收口** 完成分层与文件清单收口（下列为当前 `compiler/src` 真相清单，目录即真相）：

- `src/nextpas.compiler.frontend.source_database.pas`
  - 提供 `TSourceDatabase`，统一 root source 与 resolved unit source 的 `FileId`、canonical path、source text 与 line-index state
- `src/nextpas.compiler.frontend.compilation_session.pas`
  - 提供 `TCompilationSession`，统一拥有 source db、target facts、diagnostics sink、compilation options、syntax / resolution / semantic / MIR / backend artifacts；经 `lower` 桥接不再直连 sema/ir（P1-1 分层收口，L2 frontend 不依赖 L3 ir）
- `src/nextpas.compiler.frontend.unit_graph.pas`
  - 提供 `TSearchPathSet`、`TResolvedUnit`、`TUnitGraph`，把 root/interface/implementation/implicit-runtime edge 收成显式对象
- `src/nextpas.compiler.frontend.unit_resolver.pas`
  - 提供 `TUnitResolver`，把最小 search path、name resolution、cycle detection 与 resolution diagnostics 接回 compiler session
- `src/nextpas.compiler.frontend.workspace_model.pas` / `package_manifest` / `package_lock` / `package_workflow` / `incremental_cache` / `file_change_detector` / `parallel_scheduler` / `symbol_cache` / `query_database` / `compiler_phase` / `phase_timing`
  - 补齐 workspace / package / 增量 / 并行 / 符号缓存与阶段计时等前端外延（P1-1 扩展清单，前端 L2）
- `src/nextpas.compiler.targets.facts.pas`
  - 提供 `TTargetFactsView`，承接 target id、config path、host facts、compiler executable，以及 object format / assembler flavor / linker flavor / LLVM triple / toolchain binding / backend family（L0 targets）
- `src/nextpas.compiler.diagnostics.sink.pas` / `enhanced` / `json` / `json_helpers`
  - 提供 `TDiagnosticsSink` 家族，承接 diagnostics policy、structured compile/toolchain diagnostics 与会话级计数（L0 diagnostics）
- `src/nextpas.compiler.syntax.lexer.pas`
  - 提供 `TLexerResult`，把 root source 切成 token 流（L1 syntax）
- `src/nextpas.compiler.syntax.green_tree.pas` + `green_tree.base` + `green_tree.core` + 7 `np_green_tree_*.inc`
  - 提供 immutable `TGreenTree` / `TGreenNode` 四件套；**P1-4 去全局**：`ActiveExpressionTree: TGreenTree` 全局/threadvar 已收口至 `green_tree.core` 单一真源，`TGreenNode.Create(ATree, ...)` 为显式单源 overload，旧 `Create(Kind...)` 仅作兼容委托（`ActiveExpressionTree` 转发）；解析入口 `ParseAnonymousRoutineExpression` / `ParseTypeReference` / `clone_type` 全量显式 `ATree` 透传，`FNodeCount` 等可变状态收口至 `ATree` 实例，语法层零全局竞态（`compiler/syntax/np_green_tree_core.pas:116` 与 `compiler/src/np_green_tree_core.inc:125`）
- `src/nextpas.compiler.syntax.ast_facade.pas` / `preprocessor` / `error_recovery`
  - `TAstFacade` typed view、预处理与错误恢复（L1 syntax）
- `src/nextpas.compiler.sema.semantic_model.pas`
  - 提供 `TSemanticModel`，统一 symbol/type/typed-hir/runtime-contract count、root name、semantic status 与 typed-hir iteration（L2 sema）
- `src/nextpas.compiler.sema.analyzer.pas` + `type_check` / `overload` / `builtins` / `name_set` / `runtime_vars` / `string_ownership` + 4 `vec` 家族
  - 提供 `TSemanticAnalyzer` 家族，把 builtin type、unit symbol、runtime contract seed 与 duplicate import semantic failure 接回 session；`np_sema_validation.inc` 经 **P3 性能收口** 缓存化（`HandlerVarCache`/`MethodSuffixCache` 单次构建替代逐 ident 全量扫描，`Ensure*` 惰性初始化、try/finally 释放，消除 `O(ident*symbols)` 热点；`ir.hir.builder` `TExprStack.Pop/PopTyped` 原子双栈对齐防 Values/Types 失步，`ownership_detect` 回退 `False` 收紧）
- `src/nextpas.compiler.lower.hir_lowering.pas` / `lower_query.pas` + 3 `hir_lowering` inc
  - `lower` 桥接层，承接 `TCompilationSession` 去直连，AST→HIR 下沉外延（L3 lower 仅依赖 sema/ir）
- `src/nextpas.compiler.ir.hir.types/model/builder/printer/verifier/to_mir/llvm_emitter/system_contracts` + `llvm_utils` + 15 `hir_*` inc
  - Typed HIR 完整链路（L3 ir）
- `src/nextpas.compiler.ir.mir.model/optimize/opt_level/to_llvm` + 12 `mir.pass.*`（`registry/constfold/cse/dce/deadarg/devirt/escape/inline_heuristic/inline/licm/strength_red/tailcall/vectorize`）
  - MIR 与优化 pass 族（L3 ir，skeleton 实验态，生产仍为 HIR→LLVM 直通）
- `src/nextpas.compiler.backend.plan.pas`
  - 提供 `TBackendPlan` 与 `TBackendPlanner`，把 `MIR + TargetFacts + SourcePath` 下沉成 output intent、primary artifact 与 host-compiler invocation plan（L3 backend）
- `src/nextpas.compiler.toolchain.plan/profiles/runner.pas` + 8 `np_toolchain_*.inc`
  - 工具链规划与执行（L4 toolchain）

分层契约：`compiler Ln` 仅依赖 `≤Ln`（0 base/diagnostics/targets → 1 syntax → 2 frontend/sema → 3 ir/lower/backend → 4 toolchain），`core` 能力天花板 L2 I/O 族（fs/json/io/process）仅 frontend/driver 或显式例外（见 `scripts/compiler-flat-contract.sh` 轴 A/B/C 与 `compiler/CLAUDE.md` 边界规则）；`P3` 后验证 `rebuild 434k lines` + `compiler-pass 59/59` + `hygiene pass` 保持。

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
