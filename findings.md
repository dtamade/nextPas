# Findings & Decisions

## Requirements

- 用户要求继续按路线图推进，但不能再停在碎片化“继续”循环里。
- 用户要求设计和实现都必须建立在真实代码之上，不能空谈现代化。
- 外部审查报告要求优先关闭 `P0` 验证失真，再关闭 `P1` resolver correctness 问题。
- 当前阶段的表述必须诚实：
  已经落地的能力可以明确写，仍然 host-backed 或尚未实现的部分不能包装成已完成。

## Research Findings

- 当前 `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 内部存在可恢复性 drift：
  顶部仍写当前 contract 以 `Batch 35` 为准，但同一文件后续已经记录 `Batch 36`
  driver decomposition + compiler core hardening 完成；这会误导下一轮“继续”的恢复点。
- 当前 `docs/architecture/architecture-principles-specification.md` 已把用户提出的长期质量目标
  固化为可执行门槛：每个切片都要明确 owner、truth object、projection、promotion gate、
  non-goal 与回退信号；这条规范应作为 `master-roadmap.md`、compiler 自举路线和后续 package /
  language-service / GUI / IDE 工作的共同约束。
- 当前 `query symbols` 的实现已经走 `ResolveWorkspaceModel(...)` 与 `TCompilationSession`，
  但 public projection 仍停在 `query-result-count` / `queryResultCount`；这让 CLI/IDE/automation
  只能知道 symbol graph 有结果，不能消费具体 symbol truth。
- 当前 `compiler/ir/np_hir_builder.pas` 里 `FEntryBlockId` 基础设施已经足够支持 late alloca hoist；
  真正缺的是 `EnsureAlloca(...)` 仍把 `hikAlloca` 发到 current block。
- 当前 `compiler/ir/np_hir_llvm_emitter.pas` 之前依赖 raw `%1/%2/...` 匿名数值 SSA 名，
  并用“按 block 首个 `ResultId` 排序”的方式迁就 LLVM 文本 IR 的顺序编号约束。
- 把 emitter 切到 `%vN` named SSA values 之后，entry-block hoist 可以安全落地，且 block 输出顺序
  可以回到 HIR 原始顺序，不再需要 `ResultId` 排序 hack。
- `tests/hir/test_hir_late_alloca_hoist.pas` + `build/verify_local.sh` 里的 `opt -disable-output`
  probe 已经把这条 contract 冻结下来：late slot 的 `alloca` 必须位于 entry block，生成 IR 也必须可解析。
- 外部审查报告对 `harness` 假绿风险的判断是成立的：
  旧路径确实更接近 fixture/snapshot inventory，而不是完整真实执行。
- 当前 `tests/harness/runner.pas` 已经补成真实执行模型：
  `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、`regression`
  都会真实执行，并显式投影 fixture-level 与 smoke-level 结果。
- 当前 `compiler/frontend/np_unit_resolver.pas` 已经补上三个关键 correctness 修正：
  根单元 implementation uses、requested-name mismatch、显式 `System` source upgrade。
- 当前 `compiler/frontend/np_unit_graph.pas` 的 `AddResolvedUnit(...)` 已支持用真实 source-backed
  unit 升级 placeholder 节点，这是显式 `System` 行为变正确的关键。
- 当前 `compiler/syntax/np_green_tree.pas` 已明确接受 `array of const` 这一形态；
  `compiler/sema/np_semantic_analyzer.pas` 的 `GetParamSignature(...)` 也已补上
  `TypeChild` nil guard，避免 `np_diagnostics_sink` 在参数签名抽取阶段 AV。
- `tests/parser/array_of_const_pass.pas` 已新增并纳入 parser smoke，`./tests/run_all_tests.sh --filter parser`
  与 fresh `bash build/verify_local.sh` 都已通过。
- `build/verify_local.sh` 当前已经把新 gate 纳入 promotion path：
  `root-implementation-check`、`requested-name-mismatch-check`、
  `explicit-system-check`、`package-manifest-source-root-check`、
  `workspace-member-source-root-check`、`package-manifest-source-precedence-check`、
  `harness-compiler-pass-check`、`smoke-check`。
- 当前 search path 模型已经不只剩 root source 和 target-installed：
  session 现在还会把 nearest `nextpas.package.toml` 的 source roots、workspace member
  package source roots 与 CLI explicit unit roots 纳入同一条 precedence path。
- 当前 precedence 已经固定为：
  `root-source -> package-source-root -> explicit-unit-root -> target-installed`。
- 当前 `tools/stage0/nextpas.pas` 已经把现有 workspace/package/artifact discovery 结果
  正式提升为 command truth：line-based output 会投影
  `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
  `package-manifest-path`、`artifact-root`、`output-dir`，
  `command-envelope=<json>.result` 也会同步带上 camelCase 版本字段。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小 `test` family：
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]` 都会走 stage0 CLI，
  但真正的 group execution 仍由 `tests/run_all_tests.sh` /
  `tests/harness/runner.pas` 持有。
- 当前 `nextpas test` 的 thin wrapper 会显式把 `NEXTPAS_STAGE0`、
  `NEXTPAS_WORKSPACE_ROOT` 与 `NEXTPAS_REPO_ROOT` 传给 harness；
  driver-side test parse failure 则会继续诚实投影成
  `command=test`、`selector=test` 与 `failure-kind=invalid-arguments`。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `env` surface：
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]` 会复用现有
  target/toolchain/distribution/runtime truth，显式投影
  `toolchain-binding-path`、distribution dirs、`runtime-root`、`runtime-libc`、
  `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`。
- 当前 `env status` 已明确和 `doctor` 分层：即使当前仓库缺少
  `lib/nextpas/runtime/linux-x86_64/libc.so`，命令也继续保持
  `status=success` / `result=success`，把 `environment-readiness=incomplete`、
  `runtime-sdk-status=missing` 与 `runtime-libc-present=false` 当成 state truth，而不是
  command failure。
- 当前 `env status` 已继续补齐 readiness evidence：line-based output 与 envelope 都会投影
  `environment-status` / `environmentStatus`、`toolchain-binding-status` /
  `toolchainBindingStatus` 与 `distribution-status` / `distributionStatus`。
- 当前 `environment-readiness` 保留为兼容字段，并与 `environment-status` 使用同一 derived
  readiness vocabulary；`doctor` 的 binding readiness 也复用同一份 environment projection。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `doctor` surface：
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
  会复用 `env status` 已经使用的 target/toolchain/distribution/runtime truth，并额外投影
  `doctor-status`、`doctor-check-count` 与 `doctor-finding-count`。
- 当前 `doctor` 已明确和 `env sync` / `env use` / `env bootstrap` 分层：即使当前仓库缺少
  `lib/nextpas/runtime/linux-x86_64/libc.so`，inspection 也继续保持
  `status=success` / `result=success`，把健康问题写进
  `doctor-status=warning` 与 `doctor-finding-count=1`，而不是修改环境或把 runtime 缺失误报成
  command execution failure。
- 当前 `doctor` 的 result contract 已从 aggregate summary 继续加固：
  line-based output 会投影 `doctor-workspace-status=ready`、
  `doctor-toolchain-binding-status=ready`、`doctor-finding-code=doctor.runtime-sdk-missing`
  与 `doctor-finding-severity=warning`。
- 当前 `command-envelope=<json>.result.doctorFindings[]` 会保留同一条 finding 的
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`；这属于
  health inspection result，不替代 compiler diagnostics sink。
- 当前 `build/verify_local.sh` 的 toolchain contract probe 已经不再把
  `tests/toolchain/toolchain_contract_smoke` 与 `.o` 写回源码树：它现在会编译到临时
  `mktemp -d` build dir，并在执行后显式断言源码树里不存在这两个生成物。
- 当前 `build/verify_local.sh` 也已经把 `nextpas test` 的
  `list-groups`、`invalid-arguments`、`unknown-group`、`compiler-pass` 与 `smoke`
  五条 contract 纳入 promotion path，因此 developer tooling 的最小 test 入口不再只靠
  手工运行留证。
- 当前 `build/verify_local.sh` 也已经把 `nextpas env status` 的 success path 与 bare
  `nextpas env` 的 invalid-arguments contract 纳入 promotion path，因此最小 `env`
  公开面不再只靠手工 probe 留证。
- 当前 `build/verify_local.sh` 也已经把 `nextpas doctor` 的 success path 与 bare
  `nextpas doctor` 的 invalid-arguments contract 纳入 promotion path，因此最小 `doctor`
  健康检查入口不再只靠手工 probe 留证。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `query symbols` surface：
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
  会复用 shared workspace model、target facts 与 `TCompilationSession`，只执行 syntax、
  unit resolution 与 semantic analysis。
- 当前 `query symbols` 已明确和完整 language service 分层：它输出
  `analysis-source=compilation-session`，不宣称拥有 `LanguageServiceSession`、open document
  overlay、incremental invalidation、references、rename preflight 或 completion。
- 当前 `query symbols` 成功路径会投影 `query-kind=symbols`、`query-status=success` 与
  `query-result-count=<count>`，并让 `command-envelope=<json>.result` 同步保留
  `queryKind`、`queryStatus`、`analysisSource` 与 `queryResultCount`。
- 当前 `build/verify_local.sh` 也已经把 `nextpas query symbols` 的 success path 与 bare
  `nextpas query` 的 invalid-arguments contract 纳入 promotion path，因此最小 `query`
  公开面不再只靠手工 probe 留证。
- 当前 `compiler/frontend/np_package_workflow.pas` 已经存在，并把 package workflow 的第一批
  compiler-owned truth 收成 `TPackageManifestTruth`、`TPackageLockTruth`、
  `TPackageInstallPlanTruth` 与 `TPackageWorkflowTruth`。
- 当前这批 package workflow truth 仍然严格 non-executing：manifest truth 只消费
  `TPackageManifestInfo` 的 manifest/package/source-root 事实，lock/install truth 只冻结
  canonical path/provenance 与 `deferred` 状态，不执行 registry lookup、fetch、solver、
  install placement 或 lockfile write。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  也已经把最小 package workflow contract 纳入真实 gate：
  `package-workflow-manifest-status=ready`、`package-workflow-lock-status=deferred`、
  `package-install-plan-status=deferred` 与 `package-workflow-source-root-count=<non-zero>`；
  这让 package workflow skeleton 不再只靠文档留证。
- 当前 `pkg inspect` 的 detail contract 也已进入 promotion path：line-based output 与
  `command-envelope=<json>.result` 会同时投影 workflow-owned manifest path、package root、
  package name、lock status 与 canonical lockfile path；这仍然是只读 truth projection，
  不执行 fetch、install、dependency resolution、lockfile write 或 publish workflow。
- 当前 `tests/run_all_tests.sh` 的 stage0 bootstrap failure 已不再把关键回放线索吞掉：
  失败输出会继续带上 `bootstrap-step`、`bootstrap-command`、
  `bootstrap-stderr-file`，并在 stderr 文件非空时直接回显原始 stderr evidence。
- 当前 build/workspace/artifact 相关 truth 已经开始从平铺字段收口：
  `tools/stage0/nextpas.pas` 使用 `TBuildCommandContext` 持有 command-level build context，
  `compiler/frontend/np_compilation_session.pas` 则用 `TBuildContext` 持有
  session-owned build context。
- 当前 `tools/stage0/nextpas.pas` 的 diagnostics/toolchain/build-trace projection
  也已继续从平铺字段收口：
  `TDiagnosticProjectionContext` / `TToolchainProjectionContext` 现在不仅负责
  clear/capture/envelope，也已经覆盖 `PrintSessionProjection(...)` 的
  stdout/stderr mirror；旧 `ActiveDiagnostic*` / `ActiveToolchain*` 残留引用已清除。
- 当前 `compiler/frontend/np_workspace_model.pas` 已经存在，并把 workspace root、
  discovery kind、package refs、project unit root infos、artifact root、output dir、
  host-fpc cache root 与 target selection 收成 compiler-owned `TWorkspaceModel`。
- 当前 `compiler/frontend/np_package_manifest.pas` 现在会为 shared workspace model 提供 typed
  `TPackageManifestInfoArray`、workspace member package info 与 project unit root info；
  parser 职责仍保留在 manifest layer，不再承担最终 workspace ownership。
- 当前 `compiler/frontend/np_compilation_session.pas` 现在会正式拥有并释放
  `WorkspaceModel`；resolver 与 toolchain planner 改为从 model 读取
  `ProjectUnitRootInfos` / `ProjectUnitRoots`。
- 当前 `tools/stage0/nextpas.pas` 现在会先调用 `ResolveWorkspaceModel(...)`，
  从 model 捕获 pre-session build context，并在创建 `TCompilationSession` 后把 ownership
  交给 session；旧 driver-side workspace discovery / artifact placement helper 已被收缩掉。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已经把 explicit workspace、nearest package manifest 与 workspace member 的
  workspace model contract 纳入真实 gate；fresh `bash build/verify_local.sh`
  继续得到 `toolchainContractCheck=pass` 与 `verify-local=pass`。
- 当前 `compiler/toolchain/np_toolchain_runner.pas` 已存在，并能顺序执行 ready
  `TToolchainPlan` 的 steps：它会准备 working/output/sidecar 目录、解析 executable path、
  物化 `response-file` / `resource-list-script` / `archive-command-script`，真实调用外部进程，
  再按 `delete-on-success` 回收 sidecar，并留下 per-step status / exit code。
- 当前 `compiler/frontend/np_compilation_session.pas` 也已把 generic runner 正式接回
  当前 `bootstrap-native-assemble-link` production path：`ExecuteToolchain(...)` 现在直接复用
  `ExecuteToolchainPlan(...)`，并让 session 正式拥有 `tool-run-status`、
  `tool-run-step-count` 与 `primary-tool-run-status`。
- 当前 `tools/stage0/nextpas.pas` 已不再手写 `ResolveCompilerExecutable + TProcess`
  执行宿主 FPC；`stage0 build` 现在通过
  `Session.ExecuteToolchain(GetEnvironmentVariable('PATH'))` 走统一 runner，并把真实
  execution result 同步投影到 line-based output 与 `command-envelope=<json>.result`。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  已把 fake `as` + `ld` 的 `native-assemble-link` execution contract 纳入 promotion path：
  `native-run-status`、assemble/link step status、object/output existence、
  response sidecar cleanup、captured response 与 object-path presence 都已被真实 gate。
- 当前 `compiler/toolchain/np_toolchain_plan.pas` 已让 `PlanFromBackend`
  直接选择 `bootstrap-native-assemble-link` production path：
  `host-fpc-emit-asm -> native-assemble -> native-link` 已经进入真实执行面，而不是继续停留在
  single-step host compile。
- 当前主 smoke success path 已被 verify 冻结为
  `toolchain-plan-family=bootstrap-native-assemble-link`、
  `tool-invocation-count=3`、`tool-run-step-count=3`、
  `primary-tool-step-id=host-fpc-emit-asm`、
  `tool-status-event-count=10` 与
  `build-trace-ref=...-toolchain-plan`；显式 source-backed unit 场景还会继续追加
  `native-assemble-<unit>` step，并让 step/event 数量继续增长。
- 当前 `bootstrap-native-assemble-link` production path 的 later-step failure attribution
  已经收口：如果 failure 发生在 `native-assemble` / `native-link`，
  `compiler/frontend/np_compilation_session.pas` 现在会把
  `diagnostic-step-id`、`diagnostic-profile-id`、`diagnostic-logical-executable`、
  `build-trace-ref=trace-<session-id>-toolchain-plan` 与 `tool-status-events` 的
  step metadata 对齐到真实失败 step；
  `build/verify_local.sh` 也已用 fake `as` / `ld` 负路径冻结
  `toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed` contract。
- 当前 success/failure observability 已整体收口：
  `compiler/frontend/np_compilation_session.pas` 现在会把 `buildTrace.steps[*]` 与
  `tool-status-events` 都扩成完整 multi-step transcript，只让真实失败 step 携带
  `diagnosticRefs`。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  也已把 runner sidecar truth 收进正式 gate：`native-run-transcript` 会冻结
  `materialized=true|false` 与 `cleanupStatus=deleted|retained|not-requested`。
- 当前 `tools/stage0/nextpas.pas` 的 build/session projection writer 也已从
  双分支镜像收敛到统一 helper：
  `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)`
  不再各自维护 stdout/stderr 两套 `WriteLn(...)` 实现，而是复用同一组
  text/integer/boolean projection writer。
- 当前 `tools/stage0/nextpas.pas` 的剩余 session/syntax/resolution/semantic/mir/backend
  projection state 也已继续从平铺 `Active*` 收口到分组 record：
  `TSessionProjectionContext`、`TSyntaxProjectionContext`、
  `TResolutionProjectionContext`、`TSemanticProjectionContext`、
  `TMirProjectionContext`、`TBackendProjectionContext` 现在已经覆盖
  `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
  `CaptureSessionContext(...)` 与 `PrintSessionProjection(...)`；
  旧 `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` /
  `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 残留引用已清除。
- 当前 `tools/stage0/nextpas.pas` 也已把剩余的分组 projection 序列化 / 输出细节继续收敛到
  helper：
  `BuildCommandEnvelopeJson(...)` 现在通过一组
  `Append*ProjectionJsonFields(...)` helper 拼接 result 字段，
  `PrintSessionProjection(...)` 现在通过一组
  `Print*Projection...(...)` helper 输出 line-based projection；
  fresh `bash build/verify_local.sh` 已确认字段顺序、启停条件和
  pre-session/session-owned 边界没有漂移。
- 当前 `tools/stage0/nextpas.pas` 的 clear/capture 路径也已继续收敛到按 record 分组的
  helper：
  `ClearBuildCommandContext(...)`、`ClearSessionContext(...)`、
  `CaptureBuildCommandContext(...)`、`CaptureSessionContext(...)`
  不再各自内联维护大段字段搬运，而是统一调 build/session/diagnostics/syntax/
  resolution/semantic/mir/backend/toolchain 分组 helper；fresh
  `bash build/verify_local.sh` 已确认行为无漂移。
- 当前 `invalid-unit-root` 这类在 session 创建前就失败的路径，也已经不再退回成只有
  `failureKind` 的贫血结果：已知的 `workspace-root` / `artifact-root` / `output-dir`
  等 build context 会继续出现在 line-based output，而
  `command-envelope=<json>.result` 仍保留 `source`、`target` 与 camelCase 对应字段。
- focused probe 已确认同一条 pre-session projection 也真实覆盖
  `invalid-out-dir` 与 `invalid-artifact-root`；这一批不需要继续改
  `tools/stage0/nextpas.pas`，只需要把 verify gate 补齐。
- focused probe 也确认：当 source 周围不存在 `nextpas.workspace.toml` /
  `nextpas.package.toml`，且 CLI 不传 `--workspace` 时，当前真实行为已经是
  `workspace-discovery-kind=source-directory-fallback`，workspace root 退回 source 所在目录，
  默认 artifact 则进入 `<source-dir>/.nextpas/out/linux-x86_64/`。
- 对 `build/verify_local.sh` 做 focused audit 后确认：虽然
  `package-manifest-source-root-check`、`workspace-member-source-root-check`、
  `package-manifest-source-precedence-check` 都已经在真实 promotion path 里跑通，但
  `verify-local` 最终 success envelope 之前还没有同步它们的 camelCase result field。
- focused probe 也确认：`explicit-unit-root`、`out-dir-override`、
  `package-manifest-source-precedence`、`root-source-precedence`、
  `unit-root-precedence` 这些成功路径，当前真实的 `command-envelope=<json>.result`
  已经带有 `outputDir`、`artifact`、`searchPathCount` 与 `searchPaths`；缺口只是
  verify 之前还没有把这批 machine-readable truth 冻结下来。
- focused probe 还确认：`workspaceDescriptorPath` / `packageManifestPath`
  当前不是“总是带字段，有时为空”，而是按 discovery truth 按需出现：
  `stage0-smoke`、`source-directory-fallback`、`invalid-unit-root`、
  `invalid-out-dir`、`invalid-artifact-root` 都不会投影这两个字段；
  `package-manifest-source-root` 与 `package-manifest-source-precedence`
  会只带 `packageManifestPath`，不带 `workspaceDescriptorPath`；
  `workspace-member-source-root` 则会同时带上两者。
- focused probe 进一步确认：剩余 explicit-workspace 主路径
  `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
  `root-source-precedence`、`unit-root-precedence` 与 sessionful failure 的
  `toolchain-failure` 也都稳定省略 `workspaceDescriptorPath` /
  `packageManifestPath`；之前缺的只是更广覆盖的 verify 断言。
- 恢复会话后 fresh rerun `bash build/verify_local.sh` 继续得到
  `verify-local=pass`，说明这批 explicit-workspace omission 断言已经与当前实现一致，
  不需要再改 `tools/stage0/nextpas.pas`。
- focused probe 还确认：当前 `tools/stage0/nextpas.pas` 已经把
  `diagnostics-summary` / `human-summary` 当成共享 summary surface 稳定发出：
  success path 会给出 `diagnostics-summary=none` / `human-summary=build succeeded`，
  syntax / resolution / sema / toolchain failure 会给出对应的 diagnostic summary 与阶段级
  human summary，而显式 workspace 的 pre-session failure 也会继续镜像 envelope 顶层
  `humanSummary`；缺口只是 verify 之前没有把这层 contract 明确冻结。
- 当前 `compiler/frontend/np_unit_resolver.pas` 的 missing/ambiguous diagnostics
  已经不再只输出裸路径：`SearchRootsSummary` 与 `CandidateSummary` 现在会消费
  `TSearchPathEntry`，把 `scope` / `provenance` / `root`（以及 candidate `path`）
  一起投影进 diagnostic message。
- 新一轮 focused verification 已确认：`session-id`、`tool-invocation-plan-ref`、
  `build-trace-ref` 现在都已改成每次 build 唯一；`verify_local.sh` 已从“固定字面量断言”
  切到“同轮一致、跨轮不复用”的真实 contract。
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在已拥有最小 warning contract：
  `EmitWarning` 会产出 severity=`warning` 的 structured diagnostic，
  `SetWarningAsError(true)` 会把同类 warning 提升为 severity=`error`。
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在也已把 split accounting 固定下来：
  promoted warning 会进入 `ErrorCount`，而不会继续留在 `WarningCount`。
- `compiler/frontend/np_compilation_session.pas` 现在已把 diagnostics split 继续投影到
  session / stage0 result：
  line-based output 有 `diagnostics-error-count`、`diagnostics-warning-count`，
  `command-envelope=<json>.result` 也有 `diagnosticErrorCount`、
  `diagnosticWarningCount`。
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已把上述 warning / warning-as-error 行为，以及 resolver search index 的
  `deferred -> ready` 状态、indexed root count 与 scan count 收进 promotion path。
- `compiler/frontend/np_unit_resolver.pas` 现在已引入最小 per-root search index，
  同一 root 的 candidate lookup 不再每次调用都重新全量扫描目录。
- `compiler/frontend/np_compilation_session.pas` 与 `tools/stage0/nextpas.pas`
  现在已把 resolver search index 公开成 session-owned projection：
  `search-index-status`、`indexed-search-root-count`、`search-index-scan-count`
  会跟随真实 lookup 行为变化，而不是总被伪装成 `ready`。
- fresh rerun `./build/verify_local.sh` 已确认：
  `examples/smoke/hello.pas` 继续如实表现为
  `search-index-status=deferred` / `0` / `0`，
  `examples/smoke/hello_with_units.pas` 则如实表现为
  `search-index-status=ready` / `2` / `2`。
- 新一轮 focused probe 也确认：
  `explicit_unit_root`、`package_manifest_source_precedence`、
  `root_source_precedence` 与 `unit_root_precedence` 这些 precedence 成功路径
  都会稳定投影 `search-index-status=partial`，而且 indexed root / scan count
  会随着命中 tier 变化：
  - root-source precedence：`1 / 1`
  - explicit/package precedence 代表路径：`2 / 2`
- `build/verify_local.sh` 现在已把这批 `partial` 行为纳入 promotion path，
  不再只靠手工 probe 留证。
- 当前“编译成功”仍然有明确 bootstrap-host 边界：
  resolution/graph/diagnostics 与 native assemble/link 已进入 nextPas 控制面，但第一步
  `host-fpc-emit-asm` 仍依赖宿主 `fpc` 发射汇编。
- 当前 Stage2 compiler-module self-compile 的首个真实 parser blocker 不是 `FreeAndNil`、
  `Format` 或 `SysUtils` 尾部缺 `implementation`，而是
  `class(Exception);` 这种 shorthand 派生类声明；nextPas parser 对
  `class(Exception) ... end;` 稳定，但对 shorthand 仍会把失败拖到 EOF 才报
  `"IMPLEMENTATION" expected`。
- 当前 `compiler/backend/np_backend_plan.pas` / `compiler/toolchain/np_toolchain_plan.pas`
  原先无条件把 root source 当成 `executable`，这对 compiler units 是错误模型；
  把 `unit` roots 明确降成 `object-file`，并让 toolchain 只走
  `bootstrap-native-assemble`，才能让 self-hosting 成功边界和真实产物形状对齐。
- `build/verify_local.sh` 现在已经把 compiler-module self-compile 纳入 promotion path：
  `np_diagnostics_sink`、`np_source_database` 与 `np_workspace_model` 必须在
  `backend-output-kind=object-file`、
  `toolchain-plan-family=bootstrap-native-assemble`、
  `logical-link-request-status=deferred` 下稳定成功，而且不得偷偷退回 `native-link`。
- `np_workspace_model` 这条 self-compile contract 还额外冻结
  `tool-invocation-count=2` / `tool-run-step-count=2`，防止 unit root 被误扩成 transitive
  extra assemble 或 native link。

## Technical Decisions

| Decision                                                                                                                               | Rationale                                                                                                               |
| -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------- | ----------------------------------------------------------------------------- |
| 先把 `smoke` 和 CI 变成真实 gate，再继续扩功能                                                                                         | 没有可信验证，后续所有阶段都会被假进展污染                                                                              |
| harness 只按 group 契约收集 `.pas` fixture                                                                                             | 让测试输入和源码树生成物彻底解耦                                                                                        |
| snapshot-bearing groups 统一对比 canonical actual text                                                                                 | 降低输出噪声，提高 baseline 的稳定性和可回放性                                                                          |
| `resolver.unit-name-mismatch` 进入正式 failure model                                                                                   | 防止“文件名像是对的”却静默绑定错误 unit                                                                                 |
| implicit `System` 保留 graph 语义，但显式 `uses System` 必须继续解析真实源码                                                           | 同时保留 runtime edge 显式性和 source provenance correctness                                                            |
| 文档只写当前已验证事实，并明确标注 search path / host-backed 限制                                                                      | 避免把设计目标误写成当前能力                                                                                            |
| `stage0 test` 继续做 thin wrapper，而不是重写 harness                                                                                | harness 已经是 execution owner；driver 只该负责 CLI parse、workspace root 选择与 env bridge                           |
| planning files 与架构文档必须同步最小 package/workspace source root 现状                                                               | 避免下一轮恢复时被过时的“project roots 未落地”表述误导                                                                  |
| 长期质量目标必须先落成 `architecture-principles-specification.md`，再继续扩局部能力                                                   | 防止“现代、高性能、优雅、一流框架”只停留在口号；后续切片要围绕 owner、truth object、projection、promotion gate 和 non-goal 做取舍 |
| 当前 rolling plan 必须进入 docs-check                                                                                                  | 它是后续“继续”恢复当前生产路径的活动入口，不能只靠人工记忆避免 Batch 状态漂移                                           |
| `query symbols` detail 必须由 `TCompilationSession` 投影，而不是由 CLI 重扫源码或 scrape build output                                  | 这样 future IDE/automation 可以复用同一份 semantic symbol graph，同时保持 `stage0` 只是 thin entrypoint                 |
| `.sisyphus/`、FPC 中间产物、runner/bootstrap 产物、snapshot diff evidence 和已知 smoke/example 产物统一进入 ignore                     | 降低源码树污染，避免历史生成物继续影响测试与工作区判断                                                                  |
| resolution diagnostics 继续沿用现有 message 通路，只在 formatter 层接入 typed search-path provenance                                   | 保持改动面最小，同时把 consulted root / candidate origin 变成 verify-able output                                        |
| workspace discovery 这一批只做“已有 truth 的稳定投影”，不提前引入完整 workspace model                                                  | 保持变更 grounded 在当前实现上，同时让 CLI / envelope 更诚实                                                            |
| early failure 继续复用 `Active...` command context，而不是再发明 session-less pseudo model                                             | 保持 ownership 边界不变，同时避免 pre-session failure 丢掉已知 build truth                                              |
| 如果 focused probe 已证明行为存在，下一步先补 verify gate 而不是先改实现                                                               | 让增量更小，也让 promotion path 尽快覆盖真实已落地行为                                                                  |
| verify-local 的 success envelope 也要同步新增 gate 名称                                                                                | 避免结构化 verify 结果落后于 shell gate 现状                                                                            |
| `diagnostics-summary` / `human-summary` 既然已被规范列为最小结果表面，就应一起进入 verify gate                                         | 避免共享 summary surface 继续只靠实现自觉，而没有 promotion-path 保护                                                   |
| session / plan / trace locator 的契约应是“唯一且一致”，不是固定字面量                                                                  | 避免 verify 和文档把实现细节误冻结成错误的公开协议                                                                      |
| 继续扩 toolchain projection 前，先补 semantic diagnostics 和 workspace/source-root truth                                               | 当前最需要的是 ownership 变真实，而不是再增加更多外层投影字段                                                           |
| resolver search index 继续保持 lazy，并把 `deferred                                                                                    | partial                                                                                                                 | ready` 当成有效结果 | 这比强行 eager 扫描更诚实，也更符合 session 当前真实消费过的 search-root 状态 |
| `partial` 必须被当成 precedence 命中的正常成功状态，而不是模糊中间态                                                                   | 只有把它正式 gate 住，后续才能防止高优先级命中后又退化回低价值的全量扫描                                                |
| toolchain contract smoke 必须在临时 build dir 里编译，并显式证明源码树没有被生成物污染                                                 | 否则 verify 自己会继续制造 source-adjacent output，削弱 hygiene contract                                                |
| harness bootstrap failure 必须保留 step/command/stderr locator 和原始 stderr evidence                                                  | 否则 CI 或本地回放仍只看到模糊 failure kind，无法快速定位 bootstrap 失败点                                              |
| internal compaction 必须保持在 owned-shape 层完成，而不是一半 record 一半平铺全局                                                      | 否则后续维护仍要同时理解两套 state surface，增加实现漂移风险                                                            |
| projection writer 也必须收敛到单一路径，而不是 stdout/stderr 各维护一套镜像 `WriteLn(...)`                                             | 否则任何字段调整都容易只改到一边，重新制造 surface drift                                                                |
| 剩余 session/syntax/resolution/semantic/mir/backend projection 也应按阶段 record 化，而不是继续让四条主路径直接消费散落 `Active*` 字段 | 这样才能让 owner shape 一致，同时保持 envelope / CLI surface 不变                                                       |
| 分组 projection 的 JSON 拼接与 line-based 输出细节也应继续收敛到 helper，而不是长期留在两个大函数里                                    | 这样后续再做 compaction 时更容易守住字段顺序、启停条件和 ownership 边界                                                 |
| clear/capture 路径也应按 record helper 收敛，而不是继续把字段清理和复制集中在两个超长入口里                                            | 这样 owner shape 才能在 capture、clear、envelope、print 四条主路径上同时一致                                            |
| 在 backend 还没有 assembly/object intermediate truth 之前，不把 `stage0 build` 伪装成 multi-step native assembler/linker               | 否则会把 typed plan、backend artifact truth 与真实 production path 说错；先落通用 runner 和 contract gate 更诚实        |
| `TToolchainPlan` runner 继续只消费 typed `steps/inputs/outputs/sidecars`，不接受退化回 shell string 的执行模型                         | 这样 future assembler/linker/resource/archiver 复用同一份 plan ownership，而不是重新逃回临时脚本拼接                    |
| 当前 host-compiler production path 也必须复用同一套 runner，而不是继续保留 driver 私有 `TProcess` 路径                                 | 这样 `stage0 build` 的 selection/start/success/failure bookkeeping、CLI projection 与 execution contract 才不会长期分叉 |

## Issues Encountered

| Issue                                                                                                                                                                                              | Resolution                                                                                                                                                                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 历史 runner、fixture 二进制和 `.o/.ppu` 直接留在源码树里                                                                                                                                           | 补齐 `.gitignore`，并清理已确认的历史生成物、过期 diff 与 fresh verify 产物                                                                                                                                                                    |
| 旧文档仍在描述 inventory-style harness                                                                                                                                                             | 全面回写 `tests/` README 与架构规范，改成真实执行语义                                                                                                                                                                                          |
| `unit-resolution` / `stage0` 文档与 planning files 落回了旧 search path 说法                                                                                                                       | 改回“当前已支持最小 package/workspace source roots，并继续诚实标注非完整 workspace truth”                                                                                                                                                      |
| 容易把当前绿灯误解成“nextPas 已经独立编译全部路径”                                                                                                                                                 | 在 README、架构规范和 planning files 里明确标注 host-backed 边界                                                                                                                                                                               |
| missing / ambiguous unit diagnostics 仍只显示裸路径，无法说明候选来源                                                                                                                              | 在 resolver formatter 层复用 `TSearchPathEntry`，补齐 `scope` / `provenance` / `root` / `path`                                                                                                                                                 |
| workspace / artifact discovery 真实存在，但 CLI / envelope 之前没有把它们当正式 command truth 投影出来                                                                                             | 在 `TCompilationOptions` / `TCompilationSession` 补最小 metadata，并让 stage0 输出/结构化结果同步带上这些字段                                                                                                                                  |
| `invalid-unit-root` 会在 session 创建前失败，导致 failure envelope 一度丢掉已知的 workspace/artifact/output truth                                                                                  | 继续沿用 `Active...` command context，并让 `PrintSessionProjection(...)` 先投影 build context，再按 `session-id` 决定是否打印 session-owned fields                                                                                             |
| `invalid-out-dir` / `invalid-artifact-root` 已经有正确行为，但 promotion path 之前没有 gate 覆盖                                                                                                   | 先用 focused probe 确认现状，再把两条 early-failure baseline 收进 `build/verify_local.sh`                                                                                                                                                      |
| `source-directory-fallback` 行为已在位，但 verify 之前没有冻结这条成功路径的 workspace/artifact contract                                                                                           | 用临时 source-dir probe 确认现状后，补齐 `source-directory-fallback-check` 与 verify-local success envelope 字段                                                                                                                               |
| 三条 package/workspace source-root gate 已经存在，但 verify-local success envelope 仍漏掉对应 machine-readable 字段                                                                                | 先做 gate/result 对照，再把 `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、`packageManifestSourcePrecedenceCheck` 补进最终 `command-envelope=<json>.result`                                                               |
| 多条 success path 虽然已在 envelope 里投影 `outputDir` / `artifact` / `searchPaths`，但 verify 仍主要只看 line-based output                                                                        | 先做 focused probe 确认 truth 已在位，再为 `explicit-unit-root`、`out-dir-override` 与几条 precedence gate 补齐 envelope 断言                                                                                                                  |
| descriptor / manifest projection 的“缺失边界”之前主要靠实现自觉，verify 只冻结了部分 presence case                                                                                                 | 先做 focused probe 确认按需省略已在位，再把代表性 success / failure 路径的 line/envelope absence contract 补进 `build/verify_local.sh`                                                                                                         |
| remaining explicit-workspace 主路径虽然也稳定省略 descriptor / manifest 字段，但 verify 之前只做了代表性 absence 覆盖                                                                              | 继续对 `semantic-smoke`、`explicit-unit-root`、几条 precedence / override 成功路径与 `toolchain-failure` 做 focused probe，并补齐 absence 断言                                                                                                 |
| `diagnostics-summary` / `human-summary` 虽然已由共享输出路径稳定发出，但 verify 之前只零散覆盖少数 failure 文本                                                                                    | 先对 success、sessionful failure 与 pre-session failure 做 focused probe，再把 representative summary line/envelope contract 补进 `build/verify_local.sh`                                                                                      |
| 旧文档把 `plan-build-linux-x86_64-file-1-*` / `trace-build-linux-x86_64-file-1-*` 写成固定示例，已经和实现不符                                                                                     | 全面改成 `plan-<session-id>-...` / `trace-<session-id>-...`，并在规范里明确“唯一且一致”才是正式契约                                                                                                                                            |
| 路线图近期建议一度偏向 richer toolchain projection，容易掩盖 semantic/workspace truth 仍待补强的现实                                                                                               | 在 master roadmap 和 master roadmap plan 里把近期优先级改回 warning contract、resolver/workspace truth，再谈更丰富的 toolchain 外层投影                                                                                                        |
| parser 当前对 shorthand `class(Exception);` 不稳定，而 compiler RTL / frontend/toolchain source 恰好大量使用这种写法                                                                               | 把 shorthand 统一降格为显式 `class(Exception) ... end;`，先把语法形态收敛到已验证路径，避免 Stage2 自编译继续卡在 parser 假象上                                                                                                                |
| compiler unit roots 没有 entry point，但 backend/toolchain 之前仍无条件产出 `executable` 并计划 `native-link`                                                                                      | 把 root kind 接入 backend/toolchain；`unit -> object-file`、`program|library|package -> executable`，让产物模型与真实 Pascal root semantics 对齐                                                                                               |
| `compiler/diagnostics` / `compiler` / `unit-resolution` 规范与 planning files 还没有写出 split diagnostics accounting 和 lazy search-index projection                                              | 依据已通过的 toolchain contract 与 smoke verification，把这两条 contract 回写到架构说明和持续记录里                                                                                                                                            |
| precedence 成功路径上的 `partial` search-index 行为之前只在手工 probe 里可见，promotion path 没有正式保护                                                                                          | 在 `build/verify_local.sh` 为 representative precedence 路径补齐 line/envelope 两层 partial-state 断言，并同步 README/架构规范                                                                                                                 |
| `build/verify_local.sh` 的 toolchain contract probe 之前会把 `tests/toolchain/toolchain_contract_smoke` 与 `.o` 留在源码树                                                                         | 改成临时 build dir，并在 verify 里显式断言源码树中不存在这两个生成物                                                                                                                                                                           |
| `tests/run_all_tests.sh` 的 stage0 bootstrap failure 之前只暴露模糊的 `stage0-build-failed`                                                                                                        | 在 bootstrap failure 输出里补齐 `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file`，并回显原始 stderr evidence                                                                                                                     |
| `tools/stage0/nextpas.pas` 在引入 projection record 之后，`PrintSessionProjection(...)` 仍残留旧平铺全局字段访问                                                                                   | 把 stdout/stderr session projection 统一切到 `ActiveDiagnosticsProjection` / `ActiveToolchainProjection`，并用 fresh `bash build/verify_local.sh` 确认行为不变                                                                                 |
| `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)` 之前仍各自维护 stdout/stderr 双分支，任何字段调整都要同步改两遍                                                                 | 引入统一 projection writer helper，把 build/session projection 收敛到单一路径，并用 fresh `bash build/verify_local.sh` 确认输出契约未变                                                                                                        |
| `tools/stage0/nextpas.pas` 里剩余的 `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` / `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 仍是散落平铺状态，导致 owner shape 半收口半悬空 | 引入六个 projection context record，并让 envelope、clear/capture 与 session projection 全部改走分组 context，再用 fresh `bash build/verify_local.sh` 确认无行为漂移                                                                            |
| `BuildCommandEnvelopeJson(...)` / `PrintSessionProjection(...)` 虽然已经吃分组 context，但分组字段的具体 JSON 拼接与 line-based 输出仍集中在两个大函数里，后续容易把顺序或启停条件改偏             | 抽出 `Append*ProjectionJsonFields(...)` 与 `Print*Projection...(...)` helper，并用 fresh `bash build/verify_local.sh` 确认 contract 继续稳定                                                                                                   |
| `ClearSessionContext(...)` / `CaptureSessionContext(...)` 以及 build-context 对应入口仍直接维护跨多个 record 的大段字段清理/复制，后续继续 compaction 时容易漏改某一组 projection                  | 抽出按 record 分组的 clear/capture helper，并用 fresh `bash build/verify_local.sh` 确认公开行为继续稳定                                                                                                                                        |
| workspace/package/artifact truth 仍散落在 driver helper、session 字段与 manifest parser 之间，owner boundary 不够诚实                                                                              | 新增 `compiler/frontend/np_workspace_model.pas`，让 `TCompilationSession` 正式拥有 model，并让 `stage0` 改成 shared model consumer                                                                                                             |
| success-path build trace/status-event 之前仍是单步摘要，later-step failure trace ref 也还是 step-anchored                                                                                          | 扩 `compiler/frontend/np_compilation_session.pas` 与 runner transcript，让 success/failure 全部对齐 plan-level `build-trace-ref=trace-<session-id>-toolchain-plan`，并用 fresh `bash build/verify_local.sh` 冻结 full-step transcript contract |
| 当前多步 production path 已经真实执行 root/native steps，但显式 source-backed unit 还需要额外 assemble step 才能保持 smoke 全绿                                                                    | 在 `TCompilationSession` 收集 source-backed unit 的额外 assembly base name，并让 planner 追加 `native-assemble-<unit>` steps，再用 `build/verify_local.sh` 冻结这条 contract                                                                   |

## 2026-05-23 Follow-up Findings

- `compiler/diagnostics/np_diagnostics_sink.pas` 当前必须显式带 `{$UNITPATH .}`，否则同目录
  `nextpas_json_helpers` 不会稳定进入 compiler-module self-compile 的解析面。
- `units/linux-x86_64/SysUtils.pas` 当前还缺一条真实 compiler dependency；
  `IntToHex(Value: Int64; Digits: Integer)` 补齐后，Stage2 / diagnostics path 才重新闭合。
- `compiler/frontend/np_compilation_session.pas` 的 extra-assemble 边界现在已经明确：
  `unit` root 不追加 transitive deps；linked root 会收集 source-backed units，包括
  `installed-source`，但继续跳过 `implicit-runtime`。
- `examples/smoke/hello_with_units.pas` 在 `run_stage0_build_capture` 的 `--fold` 语境下，
  当前真实 contract 已冻结为 `typed-hir-node-count=8`、
  `tool-invocation-count=5`、`tool-run-step-count=5`、
  `tool-status-event-count=16`；先前看到的 `20` 是 verify 脚本期望漂移，不是实现回归。
- fresh `bash build/verify_local.sh` 已再次拿到 `verify-local=pass`，说明这轮修复没有引入
  新的 toolchain / semantic / self-host contract 漂移。
- 后续接手时不要再把 `np_workspace_model` 当作“只在 notes 里成功”的灰色项：它现在已经和
  `np_diagnostics_sink`、`np_source_database` 一起进入 `compiler-module-self-compile-check`。

## Resources

- [runner.pas](/home/dtamade/projects/nextPas/tests/harness/runner.pas)
- [snapshot_support.pas](/home/dtamade/projects/nextPas/tests/harness/snapshot_support.pas)
- [run_all_tests.sh](/home/dtamade/projects/nextPas/tests/run_all_tests.sh)
- [np_unit_resolver.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_unit_resolver.pas)
- [np_unit_graph.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_unit_graph.pas)
- [np_compilation_session.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_compilation_session.pas)
- [np_workspace_model.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_workspace_model.pas)
- [np_diagnostics_sink.pas](/home/dtamade/projects/nextPas/compiler/diagnostics/np_diagnostics_sink.pas)
- [np_ast_facade.pas](/home/dtamade/projects/nextPas/compiler/syntax/np_ast_facade.pas)
- [verify_local.sh](/home/dtamade/projects/nextPas/build/verify_local.sh)
- [nextpas.pas](/home/dtamade/projects/nextPas/tools/stage0/nextpas.pas)
- [np_toolchain_plan.pas](/home/dtamade/projects/nextPas/compiler/toolchain/np_toolchain_plan.pas)
- [np_toolchain_runner.pas](/home/dtamade/projects/nextPas/compiler/toolchain/np_toolchain_runner.pas)
- [toolchain_contract_smoke.pas](/home/dtamade/projects/nextPas/tests/toolchain/toolchain_contract_smoke.pas)
- [tests/harness/README.md](/home/dtamade/projects/nextPas/tests/harness/README.md)
- [tests/README.md](/home/dtamade/projects/nextPas/tests/README.md)
- [test-harness-specification.md](/home/dtamade/projects/nextPas/docs/architecture/test-harness-specification.md)
- [unit-resolution-specification.md](/home/dtamade/projects/nextPas/docs/architecture/unit-resolution-specification.md)
- [stage0-driver-specification.md](/home/dtamade/projects/nextPas/docs/architecture/stage0-driver-specification.md)
- [compiler-specification.md](/home/dtamade/projects/nextPas/docs/architecture/compiler-specification.md)
- [diagnostics-specification.md](/home/dtamade/projects/nextPas/docs/architecture/diagnostics-specification.md)
- [toolchain-specification.md](/home/dtamade/projects/nextPas/docs/architecture/toolchain-specification.md)
- [stage0 README](/home/dtamade/projects/nextPas/tools/stage0/README.md)
- [verify_local.sh](/home/dtamade/projects/nextPas/build/verify_local.sh)
- [pre-session-build-context-projection-plan.md](/home/dtamade/projects/nextPas/docs/plans/2026-03-26-pre-session-build-context-projection-plan.md)
- [workspace-model-shared-truth-plan.md](/home/dtamade/projects/nextPas/docs/plans/2026-04-05-workspace-model-shared-truth-plan.md)

## Visual/Browser Findings

- 本轮未使用图片或浏览器结果
