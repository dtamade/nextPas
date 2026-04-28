# Task Plan: P0/P1 verification fidelity + unit resolution correctness

## Goal

按外部审查报告的优先级收口当前批次，把“看起来完整”推进到“结果可信、边界诚实、核心路径更正确”。

这轮收口标准不是再扩一批新架构名词，而是先把当前仓库最危险的两类问题关掉：

- `harness` / CI 不能再给出容易误导的假绿结果
- unit resolver 不能再漏掉根单元 implementation uses、错绑 unit 名，或让 synthetic
  `System` 遮蔽真实源码

同时，这轮还要把文档、规划文件和仓库卫生同步到真实实现状态。

说明：下面的 addendum 按时间保留当时的批次范围；当前 reality 以最新 addendum 与
fresh `bash build/verify_local.sh` 为准。

## Addendum: 2026-04-29 Minimal Query Symbols Surface

### Goal

把 developer tooling 里的第一条 semantic query surface 收成最小但真实的统一 `nextpas`
命令入口，同时继续守住“query / language service / build execution”的分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `query` family，至少支持
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- `query symbols` 只负责只读 semantic query，不承担 LSP、open document overlay、
  incremental invalidation、references、rename 或 completion
- 当前 query 必须复用 compilation session 的 syntax / resolution / semantic truth，
  并显式投影 `analysis-source=compilation-session`
- `build/verify_local.sh` 必须新增 `nextpas query symbols` 的 success gate 与 bare
  `nextpas query` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批不执行 MIR、backend 或 toolchain

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为
      `nextpas query symbols examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace <repo>`
      与 bare `nextpas query` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `query` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `query` command parse/usage 与 `symbols`
      selector，支持可选 `--toolchain-binding <id>` 与 `--workspace <root>`
- [x] 让 `query symbols` 复用 `ResolveWorkspaceModel(...)`、target facts 与
      `TCompilationSession`，只执行 syntax、unit resolution 与 semantic analysis
- [x] 新增最小 query projection，把 `query-kind`、`query-status`、`analysis-source`
      与 `query-result-count` 投影到 line-based output 和 `command-envelope=<json>.result`
- [x] 同步回写 `tools/stage0/README.md`、`tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/language-service-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0QueryCheck`、
      `stage0QueryInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-29 Stage0 Doctor Minimal Read-only Health Surface

### Goal

把 developer tooling 里下一条最小但真实的 health inspection surface 收成统一 `nextpas`
命令壳，同时继续守住“状态解析 / 健康诊断 / 环境修改”分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `doctor` family，至少支持
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- `doctor` 只负责只读 inspection，不承担 `env sync` / `env use` / `env bootstrap`
  这类环境修改
- 当前 environment 即使仍不完整，命令也应保持 execution-successful；真实健康摘要通过
  `doctor-status`、`doctor-check-count` 与 `doctor-finding-count` 投影
- `build/verify_local.sh` 必须新增 `nextpas doctor` 的 success gate 与 bare
  `nextpas doctor` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批故意不把 richer finding taxonomy /
  suggested action / `query` / package workflow 伪装成已落地能力

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为
      `nextpas doctor --target linux-x86_64 --workspace <repo>` 与 bare
      `nextpas doctor` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `doctor` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `doctor` command parse/usage 与最小
      `doctor` selector，支持可选 `--toolchain-binding <id>` 与 `--workspace <root>`
- [x] 让 `doctor` 复用现有 target/toolchain/distribution/runtime truth 与可选 workspace root，
      投影 `runtime-libc-present`、`environment-readiness`、`runtime-sdk-status`、
      `doctor-status`、`doctor-check-count` 与 `doctor-finding-count`
- [x] 保持 `doctor` 为只读 health inspection：即使当前 runtime libc 缺失，也继续以
      `status=success` / `result=success` 完成，并把“不健康”写进 doctor fields
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0DoctorCheck`、
      `stage0DoctorInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-29 Doctor Result Contract Hardening

### Goal

把 `doctor` 从 aggregate health summary 继续加固成可被 CLI、CI 与 future IDE adapter
稳定消费的结构化 result contract，同时不把 health finding 误放进 compiler diagnostics sink：

- `build/verify_local.sh` 必须冻结 `doctor-workspace-status` 与
  `doctor-toolchain-binding-status`
- runtime SDK 缺失必须输出代表性 finding：
  `doctor-finding-code=doctor.runtime-sdk-missing` 与
  `doctor-finding-severity=warning`
- `command-envelope=<json>.result.doctorFindings[]` 必须同步保留
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 加入 focused RED gate，确认 fresh
      `bash build/verify_local.sh` 失败于缺少 `doctor-workspace-status`
- [x] 在 `tools/stage0/nextpas.pas` 引入最小 `TDoctorFinding` 与扩展后的
      `TDoctorProjectionContext`，保留 first finding line projection 与 envelope array
- [x] 继续保持 `doctor` 为只读 inspection：当前 runtime SDK 缺失仍返回
      `status=success` / `result=success`，健康问题写进 `doctorFindings`
- [x] 同步回写 `docs/architecture/diagnostics-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、`task_plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认结构化 finding contract 与
      `verify-local=pass`

## Addendum: 2026-04-29 Richer Env Status Readiness Evidence

### Goal

把 `env status` 的只读 state projection 从路径与 runtime 状态继续加固到可供
`doctor` 与 future `env sync` 复用的 readiness evidence：

- `environment-readiness` 保留为兼容字段，但与新增 `environment-status` 使用同一
  derived readiness vocabulary
- `runtime-sdk-status` 继续表达 runtime SDK 是否 ready / missing
- 新增 `toolchain-binding-status` 与 `distribution-status`
- `command-envelope=<json>.result` 必须同步保留 `environmentStatus`、
  `runtimeSdkStatus`、`toolchainBindingStatus` 与 `distributionStatus`

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 加入 focused RED gate，确认 fresh
      `bash build/verify_local.sh` 失败于缺少 `environment-status`
- [x] 扩展 `tools/stage0/nextpas.pas` 的 `TEnvironmentProjectionContext`，
      从既有 target/binding/distribution/runtime truth 推导 environment、runtime SDK、
      binding 与 distribution readiness
- [x] 保持 `env status` 为 execution-successful 的只读 projection：当前 runtime SDK /
      distribution 仍不完整时继续返回 `status=success` / `result=success`
- [x] 让 `doctor` 复用同一份 `toolchain-binding-status`，避免 doctor/env 各自推导
      binding readiness
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/developer-tooling-specification.md`、`task_plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 readiness evidence 与
      `verify-local=pass`

## Addendum: 2026-04-26 Stage0 Env Status Read-only Projection

### Goal

把 developer tooling 里下一条最小但真实的 environment surface 收成统一 `nextpas` 命令壳，
但继续守住“状态解析”和“健康诊断/环境修改”分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `env` family，至少支持
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]`
- `env status` 只负责解析 target / binding / distribution / runtime state，不承担
  `doctor` 诊断，也不提前引入 `env use` / `env sync` / `env bootstrap`
- 当前 environment 即使仍不完整，命令也应保持 execution-successful；真实 readiness 继续通过
  `environment-readiness`、`runtime-sdk-status` 与 `runtime-libc-present` 投影
- `build/verify_local.sh` 必须新增 `nextpas env status` 的 success gate 与
  bare `nextpas env` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批故意不把 mutation verbs / `doctor` /
  `query` 伪装成已落地能力

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `nextpas env status --target linux-x86_64` 与
      bare `nextpas env` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `env` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `env` command parse/usage 与最小
      `status` selector，支持可选 `--toolchain-binding <id>`
- [x] 让 `tools/stage0/nextpas.pas` 复用现有 target/toolchain/distribution/runtime truth，
      投影 `toolchain-binding-path`、distribution dirs、`runtime-root`、`runtime-libc`、
      `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`
- [x] 保持 `env status` 为只读 state projection：即使当前 runtime libc 缺失，也继续以
      `status=success` / `result=success` 完成，并把“不完整”写进 readiness fields
- [x] 同步回写 `tools/stage0/README.md`、
      `tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0EnvStatusCheck`、
      `stage0EnvInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-05 Workspace Model Shared Truth Convergence
asd
### Goal

把当前已经存在但仍散落在 `tools/stage0/nextpas.pas` driver helper 与 session 选项字段里的
workspace/package/artifact discovery，收口成 compiler-owned shared model，同时保持现有
公开 line-based output、`command-envelope=<json>`、resolver precedence 与 early-failure
behavior 不漂移：

- 新增最小 `WorkspaceModel` / `PackageRef` / `TargetSelection` / `ArtifactRootSet`
  Pascal 实体，承接当前真实存在的 workspace root、package refs、source roots、
  artifact root、output dir 与 host-fpc cache root truth
- `TCompilationSession` 正式拥有这份 model，不再只持有一组散落的 workspace/build 字段
- `tools/stage0/nextpas.pas` 只保留 CLI override 与 orchestration，不再自己维护
  workspace discovery、package roots 与 artifact placement 规则
- `build/verify_local.sh` 与 focused smoke 必须继续全绿，证明这次是 ownership convergence，
  不是 surface drift

### Status

Completed

### Completed Steps

- [x] 先在 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
      写出 shared workspace model 的 RED contract，覆盖 explicit workspace、
      nearest package manifest 与 workspace member 三条代表路径
- [x] 新增 `compiler/frontend/np_workspace_model.pas`，最小落地
      `WorkspaceModel` / `PackageRef` / `TargetSelection` / `ArtifactRootSet`
- [x] 让 `np_package_manifest.pas` 提供 workspace model 所需的 typed inputs，
      保留 parser 职责但不再承担最终 ownership
- [x] 让 `TCompilationSession` 正式拥有 workspace model，并让 session getters /
      resolver roots 从 model 读取，而不是从 driver 拼装字段读取
- [x] 把 `tools/stage0/nextpas.pas` 的 workspace/package/artifact discovery
      切到 shared model，保持 line/envelope/early-failure 契约不变
- [x] 运行 fresh `bash build/verify_local.sh`，并同步回写文档、路线图与持续记录

## Addendum: 2026-04-05 Toolchain Plan Runner Execution Contract

### Goal

把 `Batch 16` / `Batch 17` 已冻结的 typed `TToolchainPlan` 从“可投影对象”推进到
“可真实执行 contract”，但继续守住当前 backend truth 的边界：

- 新增通用 runner，按 step 顺序真实执行 ready `TToolchainPlan`
- runner 必须负责当前已落地的 sidecar kinds：
  `response-file`、`resource-list-script`、`archive-command-script`
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  必须真实执行 fake `as` + `ld` 的 `native-assemble-link` plan，
  验证 object/output 生成、response capture 与 `delete-on-success` cleanup
- 仍不把 `stage0 build` 伪装成已经切到 native assembler/linker production path；
  `compiler/backend/np_backend_plan.pas` 还没有正式拥有 assembly/object
  intermediate artifact truth

### Status

Completed

### Completed Steps

- [x] 审查 `compiler/backend/np_backend_plan.pas`、
      `compiler/toolchain/np_toolchain_plan.pas` 与
      `tests/toolchain/toolchain_contract_smoke.pas`，确认当前最小真实推进点是
      generic runner，而不是强行让 `PlanFromBackend` 改选 `native-assemble-link`
- [x] 新增 `compiler/toolchain/np_toolchain_runner.pas`，提供
      `ExecuteToolchainPlan(...)` 与 per-step `TToolchainRunResult`
- [x] 在 `compiler/toolchain/np_toolchain_plan.pas` 暴露 `StepAt(...)`，
      让 runner / contract smoke 能读取 typed step truth
- [x] 把 `tests/toolchain/toolchain_contract_smoke.pas` 与
      `build/verify_local.sh` 扩成 fake `as` / `ld` 的真实 multi-step execution gate，
      覆盖 response sidecar materialize、capture 与 delete-on-success cleanup
- [x] 运行 fresh `bash build/verify_local.sh`，确认 `native-run-*` contract、
      `toolchainContractCheck=pass` 与整套 `verify-local=pass`

## Addendum: 2026-04-05 Host-compiler Runner Reuse + Tool Run Projection

### Goal

把刚落地的 generic `TToolchainPlan` runner 真正接回当前 one-step host-compiler
production path，避免 `stage0 build` 继续维护第二套手写 `TProcess` 执行路径：

- `tools/stage0/nextpas.pas` 不再手工 `ResolveCompilerExecutable + TProcess`
- 当前 host-compiler production path 必须复用 `compiler/toolchain/np_toolchain_runner.pas`
- session / CLI / envelope 需要显式投影真实 execution result：
  `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
- fresh `bash build/verify_local.sh` 必须继续全绿，证明 runner reuse 没有破坏现有
  tool invocation plan、status event、build trace 与 failure diagnostic contract

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `stage0-smoke`、`semantic-smoke` 与
      `toolchain-failure` 写出 `tool-run-*` RED gate，并 fresh 运行确认失败点正好落在
      新增 execution-result fields 缺失
- [x] 在 `compiler/frontend/np_compilation_session.pas` 增加 generic runner 执行入口，
      让 session 正式拥有 `tool run` status / step count / primary-step status
- [x] 把 `tools/stage0/nextpas.pas` 的 host-compiler production path 切到
      `Session.ExecuteToolchain(...)`，去掉 hand-written execute path 与 duplicated state update
- [x] 把 `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
      接进 line-based projection 与 `command-envelope=<json>.result`
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与持续记录文件
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `tool-run-*` contract 与
      整套 `verify-local=pass`

## Addendum: 2026-04-05 Backend Intermediate Artifact Truth + Logical Object Input

### Goal

把 backend 对 artifact truth 的 ownership 从“只有 final executable”推进到
`assembly-text/object-file/executable` 三类正式 artifacts，同时继续保持当前 production path
仍是 host-compiler single-step execution：

- `compiler/backend/np_backend_plan.pas` 必须正式拥有 target-aware `.s/.o/<program>`
  artifact truth，并把 `.s/.o` 收口到 `<artifact-root>/cache/backend/<target>/`
- `compiler/frontend/np_compilation_session.pas` 与 `tools/stage0/nextpas.pas`
  必须把这份 truth 投影成 `backend-artifact-count`、`backend-artifacts` 与 camelCase
  `backendArtifactCount`、`backendArtifacts`
- `compiler/toolchain/np_toolchain_plan.pas` 的 `logical-link-request.objectInputs`
  必须开始消费 backend-owned `object-file` artifact
- `PlanFromBackend` 仍不提前切到 `native-assemble-link`；下一批才处理合法 production-path
  selection

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `backend-artifact-count`、`backend-artifacts`、
      `logical-link-request.objectInputs` 与 camelCase envelope fields 写出 RED gate，
      并 fresh 运行确认失败点落在新 truth 缺失
- [x] 扩展 `compiler/backend/np_backend_plan.pas`，让 backend plan 固定持有
      `assembly-text`、`object-file` 与 `executable` 三类 artifacts，并补齐 helper /
      backend cache root 计算
- [x] 扩展 `compiler/frontend/np_compilation_session.pas` 与
      `tools/stage0/nextpas.pas`，把 backend artifact count / artifact JSON 接进 session、
      line-based projection 与 `command-envelope=<json>.result`
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让
      `logical-link-request.objectInputs` 开始引用 backend-owned `.o`
- [x] 同步回写架构规范、路线图与持续记录，并重新运行 fresh
      `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-04-05 Bootstrap-native Assemble/Link Production Path

### Goal

把已经落地的 backend-owned `assembly-text/object-file/executable` truth 真正接进当前
production path，让 `PlanFromBackend` 不再停留在 single-step host-compiler execution：

- `compiler/toolchain/np_toolchain_plan.pas` 必须合法选择
  `bootstrap-native-assemble-link`
- 当前真实执行面必须改成
  `host-fpc-emit-asm -> native-assemble -> native-link`
- 根程序与 source-backed units 的 `.s`、backend-owned `.o` 和确定性的
  `<program>_link.res` 必须进入 backend cache 并被真实消费
- `build/verify_local.sh`、README、架构规范、路线图与持续记录必须全部同步到这条新 reality
- 当批次结束时仍要诚实标注残余风险：later-step failure attribution 当时还是
  primary-step-centric（已在 2026-04-06 addendum 收口）

### Status

Completed

### Completed Steps

- [x] 先在 `compiler/toolchain/np_toolchain_plan.pas` 审核当前 backend artifact / profile /
      runner 前提，确认最小安全切换点已经具备，不再需要继续停在
      `host-compiler` single-step selection
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 `PlanFromBackend` 直接选择
      `PlanBootstrapNativeAssembleLink(...)`，并真实生成
      `host-fpc-emit-asm`、`native-assemble`、`native-link`
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，收集 source-backed units 的额外
      assembly base names，使 explicit unit root / 多文件场景能够继续追加
      `native-assemble-<unit>` steps
- [x] 扩展 `build/verify_local.sh`，把
      `toolchain-plan-family=bootstrap-native-assemble-link`、
      `tool-invocation-count=3`、`tool-run-step-count=3`、
      `primary-tool-step-id=host-fpc-emit-asm`、
      `build-trace-ref=...-host-fpc-emit-asm` 与 extra native-assemble step contract
      纳入 promotion path
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `verify-local=pass` 与 `human-summary=local verification passed`

## Addendum: 2026-04-06 Later-step Failure Attribution for bootstrap-native assemble/link

### Goal

把当前 `bootstrap-native-assemble-link` production path 的 later-step failure attribution
从“真实执行但仍锚定 primary step”推进到“失败 metadata 跟随真实失败 step”：

- `native-assemble` / `native-link` failure 必须分别投影
  `toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed`
- `compiler/frontend/np_compilation_session.pas` 必须把 failure diagnostic、build trace、
  status event 与 `buildTraceRef` 对齐到真实失败 step，而不是继续锚定
  `host-fpc-emit-asm`
- `tools/stage0/nextpas.pas` 必须优先使用 session 产出的真实 diagnostic code，
  不能再把 later-step failure 回退成 primary-tool failure mapping
- `build/verify_local.sh` 必须新增 fake `as` / `ld` 负路径 gate，并在 success envelope
  暴露 `assemblerFailureAttributionCheck` / `linkerFailureAttributionCheck`
- 文档与持续记录必须同步成当前 reality，并诚实注明这批收口时留下的
  success-path transcript gap；该缺口已在紧随其后的 transcript addendum 收口

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 写出 fake `as` / `ld` 的 RED gate，确认 later-step failure
      还没有按真实 step 归位
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 invocation steps 显式持有
      `toolRole/profileId/sysrootRef`，并为 `native-assemble` / `native-link` 写入 step context
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，让 tool status event、diagnostic、
      build trace 与 `buildTraceRef` 在 failure path 上跟随真实失败 step
- [x] 扩展 `tools/stage0/nextpas.pas`，让 runner failure 优先使用 `Session.LastDiagnosticCode`
      作为公开 failure kind
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `assembler-failure-attribution-check=pass`、
      `linker-failure-attribution-check=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-06 Stage0 Test Command Thin Wrapper

### Goal

把 developer tooling 里最容易失真的 `nextpas test` 入口收成最小真实公开面，但继续保持
`tests/run_all_tests.sh` / `tests/harness/runner.pas` 为 execution owner：

- `tools/stage0/nextpas.pas` 必须新增最小 `test` family，至少支持
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]`
- `stage0` 只负责参数解析、workspace root 选择与 thin wrapper；不重写 harness 分组、
  snapshot policy、fixture execution 或 bootstrap diagnostics
- `stage0` 调起 harness 时必须显式传入
  `NEXTPAS_STAGE0`、`NEXTPAS_WORKSPACE_ROOT`、`NEXTPAS_REPO_ROOT`
- `build/verify_local.sh` 必须新增 `nextpas test` 的
  `list-groups`、`invalid-arguments`、`unknown-group`、`compiler-pass`、`smoke`
  五条 contract
- 文档与持续记录必须同步成当前 reality，并明确这批故意不提前把
  `doctor` / `env` / `query` 拉进来

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas`、`tests/run_all_tests.sh` 与
      `tests/harness/runner.pas`，确认这批最小真实推进点是 stage0 thin wrapper，而不是
      再发明一套 driver-owned test runner
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `test` command parse/usage，
      支持 `--list-groups`、`--filter <group>` 与可选 `--workspace <root>`，并把
      driver-side test parse failure 映射成 `selector=test`
- [x] 在 `tools/stage0/nextpas.pas` 中通过 `/usr/bin/env` thin-wrap
      `tests/run_all_tests.sh`，显式传入 `NEXTPAS_STAGE0`、
      `NEXTPAS_WORKSPACE_ROOT` 与 `NEXTPAS_REPO_ROOT`
- [x] 扩展 `build/verify_local.sh`，把 `nextpas test` 的 list-groups、
      invalid-arguments、unknown-group、compiler-pass 与 smoke contract
      纳入正式 gate
- [x] 同步回写 `tools/stage0/README.md`、
      `tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `nextpas test` gate 与
      整套 `verify-local=pass`

## Addendum: 2026-04-06 Success-path Toolchain Observability Transcript Hardening

### Goal

把当前 `bootstrap-native-assemble-link` production path 的 success-path observability
从“仍有单步摘要残留”推进到“success/failure 都暴露完整 executed-step
transcript”：

- `compiler/toolchain/np_toolchain_runner.pas` 必须把 executed sidecar truth 收进正式
  transcript，至少暴露 `materialized` 与 `cleanupStatus`
- `compiler/frontend/np_compilation_session.pas` 必须让 success/failure 两侧都按全部
  executed steps 投影 `tool-status-events` 与 `buildTrace.steps[*]`
- `buildTraceRef` 必须统一升级成 plan-level
  `trace-<session-id>-toolchain-plan`，而不是继续随某个 step 变化
- `build/verify_local.sh` 必须冻结 success-path `tool-status-event-count=10`、
  later-step failure 的 plan-level trace ref，以及 `native-run-transcript` 的
  sidecar cleanup truth
- 文档与持续记录必须同步成当前 reality，把“success path 仍是单步摘要”的旧说法
  全部清掉

### Status

Completed

### Completed Steps

- [x] 扩展 `compiler/toolchain/np_toolchain_runner.pas`，把 executed sidecar truth 收进
      `TToolchainExecutedStep`
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，让 success/failure 两侧都按全部
      executed steps 投影 `tool-status-events` / `buildTrace.steps[*]`，并把
      `buildTraceRef` 升级成 plan-level locator
- [x] 扩展 `tests/toolchain/toolchain_contract_smoke.pas`，新增
      `native-run-transcript=<json>` 输出，冻结 sidecar execution truth
- [x] 扩展 `build/verify_local.sh`，把 success-path transcript、plan-level trace ref、
      later-step failure transcript 与 `native-run-transcript` sidecar cleanup truth
      纳入 promotion path
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`toolchainFailureCheck=pass`、
      `assemblerFailureAttributionCheck=pass`、`linkerFailureAttributionCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Clear/Capture Helper Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection ownership 收紧，但仍不改公开
line-based output / `command-envelope=<json>` 契约：

- `ClearSessionContext(...)` 不应继续直接维护一整段跨多个 projection record 的字段清理逻辑
- `CaptureSessionContext(...)` 不应继续直接维护一整段跨多个 projection record 的字段复制逻辑
- `ClearBuildCommandContext(...)` / `CaptureBuildCommandContext(...)` 也应对齐到同样的 helper
  形状，避免 clear/capture 路径继续半收口半内联
- fresh `verify_local` 必须继续全绿，证明这次只是 clear/capture helper convergence，
  不是行为或契约漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 `ClearBuildCommandContext(...)`、
      `ClearSessionContext(...)`、`CaptureBuildCommandContext(...)`、
      `CaptureSessionContext(...)` 的剩余大块字段搬运，确认最小安全边界是按现有
      build/session/diagnostics/syntax/resolution/semantic/mir/backend/toolchain record
      抽 helper，而不是改输出 surface
- [x] 新增按 record 分组的 clear helper 与 capture helper，并让上述四个入口统一调 helper，
      保持字段来源、更新时机和 pre-session/session-owned 边界不变
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Helper Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection 实现收紧，但仍不改公开
line-based output / `command-envelope=<json>` 契约：

- `BuildCommandEnvelopeJson(...)` 不应继续内联维护一整段分组字段拼接逻辑
- `PrintSessionProjection(...)` 不应继续内联维护按 group 展开的 line-based projection 细节
- fresh `verify_local` 必须继续全绿，证明这次只是 helper convergence，不是字段顺序、
  启停条件或 pre-session/session-owned 边界漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 `BuildCommandEnvelopeJson(...)` /
      `PrintSessionProjection(...)` 的剩余内联 projection 逻辑，确认最小安全边界是抽出
      JSON helper 与 print helper，而不是继续改公开字段
- [x] 新增按 build/session/syntax/resolution/semantic/mir/backend/toolchain 分组的 JSON helper，
      并新增 session identity / diagnostics / syntax / resolution / semantic / MIR /
      backend / toolchain / diagnostics detail / build trace / lifecycle 的 print helper，
      再把 `BuildCommandEnvelopeJson(...)` 与 `PrintSessionProjection(...)` 改成统一调 helper
- [x] 核对 helper 化后的字段顺序与启停条件，特别确认
      `diagnosticCount` / `diagnosticErrorCount` / `diagnosticWarningCount` /
      `diagnosticsPolicy` 仍位于 `sessionLifetime` / `unitLifetime` / `stageLifetime` 之前
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Owner Context Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection state 收口到一致的 owned shape，
但仍不改公开 line-based output / `command-envelope=<json>` 契约：

- 剩余的 `ActiveSession*`、`ActiveSyntax*`、`ActiveResolution*`、
  `ActiveSemantic*`、`ActiveMir*`、`ActiveBackend*` 不应继续散落成平铺全局
- `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
  `CaptureSessionContext(...)`、`PrintSessionProjection(...)` 应统一走分组 record
- fresh `verify_local` 必须继续全绿，证明这次只是 owner-context convergence，
  不是 surface 变化

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中剩余 session/syntax/resolution/semantic/mir/backend
      平铺 `Active*` 状态，确认最小安全边界是按 projection 分组收口，而不是再改输出 helper
- [x] 引入 `TSessionProjectionContext`、`TSyntaxProjectionContext`、
      `TResolutionProjectionContext`、`TSemanticProjectionContext`、
      `TMirProjectionContext`、`TBackendProjectionContext`，并同步替换
      `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
      `CaptureSessionContext(...)`、`PrintSessionProjection(...)` 的消费点
- [x] 用搜索确认 `tools/stage0/nextpas.pas` 中已不再残留这批旧
      `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` /
      `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 平铺字段
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Convergence-first Verification Hygiene + Build-context Compaction

### Goal

把当前 rolling window 的优先级继续收回到“已落地路径的收敛质量”，而不是继续向外扩 richer
toolchain 表面：

- `verify_local` 不能再让 toolchain contract smoke 的二进制 / `.o` 落回源码树
- `harness` bootstrap failure 不能再吞掉关键回放线索
- `stage0` / `CompilationSession` 共享的 build truth 要继续从散落字段收口到更小的 owned shape
- 文档、路线图和持续记录必须同步这条 convergence-first 取向

### Status

Completed

### Completed Steps

- [x] 把 `build/verify_local.sh` 的 toolchain contract smoke 改成编译到临时 `mktemp -d`
      build dir，并显式断言源码树里不存在
      `tests/toolchain/toolchain_contract_smoke` 与
      `tests/toolchain/toolchain_contract_smoke.o`
- [x] 让 `tests/run_all_tests.sh` 在 stage0 bootstrap failure 时稳定投影
      `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file`，并在 stderr 文件存在内容时回显原始 evidence
- [x] 在 `tools/stage0/nextpas.pas` 用 `TBuildCommandContext` 收拢 command-level build truth，
      并在 `compiler/frontend/np_compilation_session.pas` 用 `TBuildContext` 收拢 session-owned build context
- [x] 回写 `build/README.md`、`tests/harness/README.md`、
      `docs/architecture/test-harness-specification.md`、
      `docs/architecture/stage0-driver-specification.md`、`tools/stage0/README.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与持续记录文件
- [x] 运行 fresh `bash build/verify_local.sh`，确认
      `toolchainContractCheck=pass`、`harnessBootstrapDiagnosticsCheck=pass` 与整套
      `verify-local` 继续全绿

## Addendum: 2026-04-02 Stage0 Projection Context Compaction Closure

### Goal

把上一轮已经开始的 `stage0` 内部状态收口继续做完，但只限于实现内部，不改公开
line-based output / `command-envelope=<json>` 契约：

- `tools/stage0/nextpas.pas` 不应再在 projection record 已落地后，继续混用残留的
  `ActiveDiagnostic*` / `ActiveToolchain*` 平铺全局
- `PrintSessionProjection(...)` 必须和 `BuildCommandEnvelopeJson(...)`、
  `ClearSessionContext(...)`、`CaptureSessionContext(...)` 一样，统一走 owned context
- fresh `verify_local` 必须继续全绿，证明这次只是内部 compaction，不是行为漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 diagnostics/toolchain projection 的剩余旧引用，
      确认遗留点集中在 `PrintSessionProjection(...)`
- [x] 把 stdout/stderr session projection 中残留的旧平铺字段访问全部改为
      `ActiveDiagnosticsProjection` / `ActiveToolchainProjection`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Writer Convergence

### Goal

继续收紧 `tools/stage0/nextpas.pas` 的内部实现形状，但仍不改公开 CLI / envelope 契约：

- `PrintBuildContextProjection(...)` 与 `PrintSessionProjection(...)` 不应继续维护
  stdout/stderr 两套大段镜像逻辑
- projection 输出路径应收敛到一组统一 helper，降低后续继续 compaction 时的漏改风险
- fresh `verify_local` 必须继续全绿，证明只是 writer convergence，不是 surface 变化

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 build/session projection 的 stdout/stderr
      双分支重复，确认最小安全边界只需要收敛 writer helper，不需要改字段本身
- [x] 引入统一 projection writer helper，并把
      `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)`
      改成单一路径输出，保持字段名、顺序和条件不变
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-03-27 Toolchain Contract Hardening + Roadmap Review

### Goal

把上一轮审查里价值最高、且已经能在当前仓库落地的几项建议直接收口成代码和文档：

- 让 `session-id`、`tool-invocation-plan-ref`、`build-trace-ref` 改成每次 build 唯一
- 给 diagnostics sink 补上最小 warning / warning-as-error contract
- 给 unit resolver 补上可复用的 root index，避免重复全量重扫 search roots
- 回写路线图与实现计划，把近期优先级从“继续堆 toolchain projection”调回
  semantic/workspace truth

### Status

Completed

### Completed Steps

- [x] 先把 `build/verify_local.sh` 和 `tests/toolchain/toolchain_contract_smoke.pas`
      扩成会先对唯一 locator、warning contract 和 resolver index 提出 RED
- [x] 在 `np_compilation_session.pas` 里把 build session locator 改成带 timestamp + nonce 的唯一值
- [x] 在 `np_diagnostics_sink.pas` 里补齐 `EmitWarning`、`WarningCount`、
      `SetWarningAsError`
- [x] 在 `np_unit_resolver.pas` 里补齐最小 per-root search index，并暴露 index status /
      indexed root count / scan count contract
- [x] 回写 `master-roadmap.md`、`stage0-driver-specification.md`、
      `toolchain-specification.md`、`diagnostics-specification.md`、
      `tools/stage0/README.md` 与 master roadmap plan
- [x] 运行 fresh `./build/verify_local.sh`，确认整套 verify-local 继续全绿

## Addendum: 2026-03-27 Diagnostics Accounting + Search-index Projection Sync

### Goal

把上一轮已经落地的两条最小 contract 写成正式、持续一致的仓库 truth：

- diagnostics 不再只写 total count，而要明确 split error/warning accounting
- resolver search index 不再只留在 resolver 内部，而要作为 session-owned projection
  被公开说明
- 路线图与持续记录要明确这条 search index 仍然是 lazy contract，而不是假装“总该 ready”

### Status

Completed

### Completed Steps

- [x] 回看 `np_diagnostics_sink.pas`、`np_compilation_session.pas`、
      `np_unit_resolver.pas`、`tools/stage0/nextpas.pas`、
      `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`，
      确认真实 contract 已经在代码和 verify path 中生效
- [x] 回写 `compiler-specification.md`，把 diagnostics split accounting 与
      search-index projection 写成 compiler-owned truth
- [x] 回写 `diagnostics-specification.md`，把 `ErrorCount` / `WarningCount` /
      warning-as-error promotion contract 写清楚
- [x] 回写 `unit-resolution-specification.md`，把 per-root lazy search index 与
      `deferred -> ready` 投影行为写清楚
- [x] 回写 `task_plan.md`、`findings.md` 与 `progress.md`，同步这轮已验证结论
- [x] 重新运行 fresh `./build/verify_local.sh`，确认 docs/planning sync 之后整套 verify-local 继续全绿

## Addendum: 2026-03-27 Partial Search-index Contract Hardening

### Goal

把 resolver search-index 的第三种真实状态 `partial` 正式冻结进 promotion path，避免后续
precedence 路径悄悄退化成 eager 全扫描或丢失 scan accounting。

### Status

Completed

### Completed Steps

- [x] 用 focused probe 确认 `explicit_unit_root`、`package_manifest_source_precedence`、
      `root_source_precedence`、`unit_root_precedence` 四类成功路径都会稳定投影
      `search-index-status=partial`
- [x] 在 `build/verify_local.sh` 为上述 representative precedence 路径补齐
      line-based 与 envelope 两层 `searchIndexStatus` / `indexedSearchRootCount` /
      `searchIndexScanCount` 断言
- [x] 回写 `unit-resolution-specification.md` 与 `tools/stage0/README.md`，
      说明 `partial` 表示“高优先级 root 提前命中后，低优先级 tiers 未被继续扫描”
- [x] 回写 `task_plan.md`、`findings.md` 与 `progress.md`，记录这次 verify hardening
- [x] 重新运行 fresh `./build/verify_local.sh`，确认新增 partial-state gate 后整套 verify-local 继续全绿

## Current Phase

Completed

## Phases

### Phase 1: Review Report Against Codebase Reality

- [x] 逐条对照外部审查报告与当前代码
- [x] 确认优先级切到 `P0` 验证失真，再到 `P1` resolver correctness
- [x] 锁定当前最小收口范围：
      harness truthfulness、resolver correctness、docs sync、repo hygiene、fresh verification
- **Status:** completed

### Phase 2: Harness Truthfulness

- [x] 修正 `tests/harness/runner.pas`，让 fixture 收集只接收符合 group 契约的 `.pas`
- [x] 让 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、`regression`
      都走真实执行路径，而不是只统计 fixture / snapshot
- [x] 为 group 与 smoke 补齐真实执行投影：
      `fixture-result`、`executed-fixture-count`、`passed-fixture-count`、
      `failed-fixture-count`、`smoke-group ... executed=<n>`
- [x] 让 snapshot-bearing groups 比较 canonical actual text，并在 mismatch / missing 时写出
      diff evidence
- [x] 把 runner bootstrap 产物从源码树移到 `.sisyphus/tmp/harness/bootstrap/runner`
- **Status:** completed

### Phase 3: Resolver Correctness

- [x] 修正 `ResolveRoot(...)`，让根单元也解析 `implementation uses`
- [x] 修正 `ResolveDependency(...)`，要求 requested unit name 与文件内部声明名一致
- [x] 新增 `resolver.unit-name-mismatch` failure baseline 与对应 fixture/snapshot
- [x] 修正 synthetic `System` 行为：
      implicit runtime placeholder 可以存在，但显式 `uses System` 仍必须尝试加载真实源码
- [x] 让 `TUnitGraph.AddResolvedUnit(...)` 支持从 placeholder 升级为真实 source-backed unit
- **Status:** completed

### Phase 4: Docs, Hygiene, and Planning Sync

- [x] 更新 `.gitignore`，把 `.sisyphus/`、FPC 生成物、runner/bootstrap 产物、snapshot
      diff evidence 和当前已知 smoke/example 产物统一排除
- [x] 清理源码树里的历史 runner/fixture 生成物与过期 diff
- [x] 更新 `tests/harness/README.md`、`tests/README.md`
- [x] 更新 `test-harness-specification.md` 与 `unit-resolution-specification.md`
- [x] 更新 `task_plan.md`、`findings.md` 与 `progress.md`
- **Status:** completed

### Phase 5: Fresh Verification

- [x] 运行 fresh `./tests/run_all_tests.sh --filter smoke`
- [x] 运行 fresh `./build/verify_local.sh`
- [x] 记录当前收口结论时，明确区分“真实 resolution / harness gate”与“仍 host-backed 的外层编译路径”
- **Status:** completed

### Phase 6: Workspace Discovery Truth Projection

- [x] 为 `build/verify_local.sh` 补齐 workspace/artifact discovery projection gate：
      `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
      `package-manifest-path`、`artifact-root`、`output-dir`，以及 envelope 对应 camelCase 字段
- [x] 为 `TCompilationOptions` / `TCompilationSession` 补齐最小 discovery metadata owned fields
- [x] 让 `tools/stage0/nextpas.pas` 复用现有 nearest workspace/package helper，
      把当前真实 workspace/package/artifact 事实投影到 line-based output 与
      `command-envelope=<json>`
- [x] 运行 fresh `bash build/verify_local.sh`，确认 stage0 smoke、
      package manifest fixture 与 workspace member fixture 全部转绿
- **Status:** completed

### Phase 7: Pre-session Build Context Projection

- [x] 为 `build/verify_local.sh` 的 `invalid-unit-root-check` 补齐 early failure gate：
      line-based output 至少要保留 `workspace-root`、`workspace-discovery-kind`、
      `artifact-root`、`output-dir`，而 envelope 继续带上
      `failureKind`、`source`、`target`、`workspaceRoot`、`workspaceDiscoveryKind`、
      `artifactRoot`、`outputDir`
- [x] 在 `tools/stage0/nextpas.pas` 里把 source/target/workspace/artifact/output
      这批 command-level truth 提前 capture 到 `Active...` context，
      不再等 session 创建后才可见
- [x] 让 `PrintSessionProjection(...)` 先打印 build context，再只在有 `session-id`
      时继续打印 session-owned fields，避免伪造 pseudo-session
- [x] 运行 fresh `bash build/verify_local.sh`，确认 `invalid-unit-root` 这类
      pre-session failure 也能稳定投影已知 build context，且 verify-local 全绿
- **Status:** completed

### Phase 8: Pre-session Failure Gate Expansion

- [x] 先做 focused probe，确认 `invalid-out-dir` 与 `invalid-artifact-root`
      当前已经真实复用同一条 pre-session build-context projection，
      不需要再改 `tools/stage0/nextpas.pas`
- [x] 为 `build/verify_local.sh` 增加 `invalid-out-dir-check`，冻结
      `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`
      及 envelope 对应 camelCase 字段
- [x] 为 `build/verify_local.sh` 增加 `invalid-artifact-root-check`，冻结同一批
      pre-session build context fields
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 gate 全绿，
      且 `invalid-unit-root` / `invalid-out-dir` / `invalid-artifact-root`
      三条 early failure baseline 同时受保护
- **Status:** completed

### Phase 9: Source-directory-fallback Verify Coverage

- [x] 先做 focused probe，确认不传 `--workspace`、且 source 周围没有 workspace/package marker 时，
      当前真实行为已经是 `workspace-discovery-kind=source-directory-fallback`
- [x] 为 `build/verify_local.sh` 增加 `source-directory-fallback-check`，冻结
      `workspace-root`、`workspace-discovery-kind=source-directory-fallback`、
      `artifact-root`、`output-dir`、artifact 默认落点、tool plan argv 与 envelope 对应字段
- [x] 额外断言这条路径不会投影 `workspace-descriptor-path` / `package-manifest-path`
- [x] 同步补齐 `verify-local` success envelope，把
      `sourceDirectoryFallbackCheck`、`invalidOutDirCheck`、`invalidArtifactRootCheck`
      正式写进结构化结果
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 gate 与整套 verify-local 全绿
- **Status:** completed

### Phase 10: Verify-local Success Envelope Parity

- [x] 对照 `build/verify_local.sh` 的 `*=pass` gate 集合与最终
      `command-envelope=<json>.result`，确认结构化结果仍缺
      `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、
      `packageManifestSourcePrecedenceCheck`
- [x] 在 `build/verify_local.sh` 补齐上述三条 success field，保持 verify-local 的
      machine-readable result 与真实 promotion path 同步
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这次 envelope parity 修补
- [x] 运行 fresh `bash build/verify_local.sh`，确认 success envelope 扩充后整套 verify-local 继续全绿
- **Status:** completed

### Phase 11: Success-path Envelope Coverage Hardening

- [x] 对 `explicit-unit-root`、`out-dir-override`、`package-manifest-source-precedence`、
      `root-source-precedence`、`unit-root-precedence` 做 focused probe，确认当前真实输出
      已经在 `command-envelope=<json>.result` 中带上 `outputDir`、`artifact`、`searchPathCount`
      与 `searchPaths`
- [x] 在 `build/verify_local.sh` 为上述 gate 补齐最小 machine-readable 断言，
      冻结 success path 的 envelope search-path/output truth，而不改 stage0 实现
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 verify hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 envelope 断言后整套 verify-local 继续全绿
- **Status:** completed

### Phase 12: Descriptor/Manifest Presence Contract Hardening

- [x] 对 `stage0-smoke`、`package-manifest-source-root`、
      `package-manifest-source-precedence`、`source-directory-fallback`、
      `invalid-unit-root`、`invalid-out-dir`、`invalid-artifact-root`
      做 focused probe，确认 `workspaceDescriptorPath` / `packageManifestPath`
      当前真实行为是“按需出现、否则省略”，而不是投影成空字段
- [x] 在 `build/verify_local.sh` 为上述代表性路径补齐出现/缺失断言，冻结
      line-based output 与 `command-envelope=<json>.result` 的 presence-vs-absence contract
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 absence hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认 descriptor/manifest absence 断言加入后整套 verify-local 继续全绿
- **Status:** completed

### Phase 13: Explicit-workspace Omission Coverage Expansion

- [x] 对 `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
      `root-source-precedence`、`unit-root-precedence`、`toolchain-failure`
      做 focused probe，确认这些 remaining explicit-workspace 路径也都会稳定省略
      `workspaceDescriptorPath` / `packageManifestPath`
- [x] 在 `build/verify_local.sh` 为上述路径补齐 line/envelope absence 断言，
      把 explicit-workspace omission contract 从“代表性覆盖”扩成“主要路径全覆盖”
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 omission coverage expansion
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 absence gate 后整套 verify-local 继续全绿
- **Status:** completed

### Phase 14: Summary Surface Contract Hardening

- [x] 对 `stage0-smoke`、`semantic-smoke`、`syntax-failure`、`missing-unit`、
      `duplicate-import`、`toolchain-failure` 与显式 workspace 的 pre-session failure
      做 focused probe，确认当前真实输出已经稳定携带
      line-based `diagnostics-summary` / `human-summary`，以及 envelope 中的
      `diagnosticsSummary` / `humanSummary`
- [x] 在 `build/verify_local.sh` 为上述代表性 success / sessionful failure /
      pre-session failure 路径补齐 summary-surface 断言，不改 `tools/stage0/nextpas.pas`
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 summary contract hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 summary 断言后整套 verify-local 继续全绿
- **Status:** completed

## Decisions Made

| Decision                                                                                          | Rationale                                                                                          |
| ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------- |
| 先修验证失真，再谈更多架构扩张                                                                    | 假绿会污染后续所有判断，先修它才能让路线图有可信地基                                               |
| harness 继续只保留 6 个稳定 group，`smoke` 保持为 cross-group minimal view                        | 保持公开 surface 少而硬，不增加无必要实体                                                          |
| `compiler-fail` / `diagnostics` 统一改成 canonical actual text compare                            | 让 snapshot baseline 对比真正基于执行结果，而不是文件存在性                                        |
| synthetic `System` 只保留为 implicit runtime edge 的 placeholder，不再遮蔽真实 source             | 同时保留 graph 显式性与正确 provenance                                                             |
| 当前文档必须诚实写出 host-backed 边界和 search path 限制                                          | 避免对内排期和对外表述高估现状                                                                     |
| pre-session failure 要投影已知 command truth，但不能伪造 session-owned state                      | 让 early failure 更诚实，同时保持 session ownership 边界                                           |
| 对已存在的 early-failure 行为，优先先补 verify gate，再决定是否需要改实现                         | 保持批次 grounded，避免为“也许存在的问题”过早改结构                                                |
| verify 脚本自己的 success envelope 也必须跟上真实 gate 集合                                       | 避免 shell gate 已扩充，但结构化 verify 结果仍落后                                                 |
| `diagnostics-summary` / `human-summary` 也要被当成共享 command contract，而不是 incidental stdout | 规格已经把它们列为最小结果表面，verify 应同时保护 line/envelope 两层 mirror                        |
| resolver search index 继续保持 lazy，并把 `deferred                                               | partial                                                                                            | ready` 当成真实 session truth | 避免为了看起来“更完整”而引入 eager 扫描副作用，反而模糊真实 ownership |
| precedence success path 上的 `partial` 必须进入 verify gate，而不只停在手工 probe                 | 这能防止 resolver 以后命中高优先级 root 后仍去全扫低优先级 tiers，或者丢掉 indexed/scan accounting |

## Notes

- 工作区不是 Git 仓库。
- 当前 `build/verify_local.sh` 已经把以下 gate 纳入 promotion path：
  `missing-unit-check`、`ambiguous-unit-check`、
  `root-implementation-check`、`requested-name-mismatch-check`、
  `explicit-system-check`、`package-manifest-source-root-check`、
  `workspace-member-source-root-check`、`package-manifest-source-precedence-check`、
  `source-directory-fallback-check`、`invalid-unit-root-check`、`invalid-out-dir-check`、
  `invalid-artifact-root-check`、`harness-compiler-pass-check`、`smoke-check`
- 最小 package/workspace-declared source roots 已真实落地：
  nearest `nextpas.package.toml` 的 `[sources].roots` 与
  `nextpas.workspace.toml` 的 member package source roots 已进入
  `TCompilationOptions` / `TSearchPathSet` / verify path。
- 当前 stage0 CLI / envelope 也已把最小 workspace discovery truth 正式投影出来：
  `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
  `package-manifest-path`、`artifact-root`、`output-dir`，以及
  `workspaceRoot`、`workspaceDiscoveryKind`、`workspaceDescriptorPath`、
  `packageManifestPath`、`artifactRoot`、`outputDir`。
- 当前 `invalid-unit-root` 这类在 `TCompilationSession` 创建前就失败的路径，也会继续投影
  已知的 build command context：line-based output 至少保留 `target`、
  `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`，
  `command-envelope=<json>.result` 则继续带上 `source`、`target` 与对应 camelCase
  build-context 字段。
- 当前同一类 pre-session build-context projection 也已经被 verify gate 扩到
  `invalid-out-dir` 与 `invalid-artifact-root`，所以 workspace/artifact/output truth
  不再只在一条 `invalid-unit-root` 路径上被保护。
- 当前 `source-directory-fallback` 成功路径也已经有 verify gate：
  不传 `--workspace` 时，workspace root 会退回 source 所在目录，artifact 默认进入
  `<source-dir>/.nextpas/out/<target>/`，并且不会凭空投影
  `workspace-descriptor-path` / `package-manifest-path`。
- 当前 `verify-local` 的 success envelope 也已经和真实 gate 集合对齐：
  `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、
  `packageManifestSourcePrecedenceCheck` 不再只存在于 shell 输出里，而会进入最终
  `command-envelope=<json>.result`。
- 当前 success path 上与 search precedence / out-dir override 相关的 gate，
  也已经不只冻结 line-based output：`explicit-unit-root`、`out-dir-override`、
  `package-manifest-source-precedence`、`root-source-precedence`、
  `unit-root-precedence` 现在都会额外断言 `command-envelope=<json>.result` 中的
  `outputDir`、`artifact`、`searchPathCount` 与 `searchPaths`。
- 当前 `workspace-descriptor-path` / `package-manifest-path` 的出现边界也已经被 verify
  冻结到“出现与缺失”两个方向：
  `stage0-smoke`、`source-directory-fallback` 与显式 workspace 的 pre-session failure
  不会误投影这两个字段；`package-manifest-source-root` 与
  `package-manifest-source-precedence` 则会继续稳定表现为“只有 manifest，没有 descriptor”。
- 当前 explicit-workspace 主路径上的 omission contract 也已经从代表性 case 扩成主要路径全覆盖：
  `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
  `root-source-precedence`、`unit-root-precedence` 与 `toolchain-failure`
  也都会显式验证 descriptor/manifest 字段不会误投影。
- 当前 summary surface 也不再只靠实现自觉：
  `stage0-smoke` / `semantic-smoke` 会稳定验证 `diagnostics-summary=none` 与
  `human-summary=build succeeded`，而 representative sessionful failure /
  pre-session failure 也会同时验证 line-based summary 与 envelope
  `diagnosticsSummary` / `humanSummary` mirror。
- 当前 diagnostics accounting 也已经不是只有 total count：
  `diagnostics-error-count`、`diagnostics-warning-count` 与 envelope 对应的
  `diagnosticErrorCount`、`diagnosticWarningCount` 已进入 `stage0-smoke`、
  `semantic-smoke` 与 `toolchain-contract` gate。
- 当前 resolver search index 也已经作为 session-owned truth 进入 verify path：
  `examples/smoke/hello.pas` 会稳定表现为 `search-index-status=deferred`、
  `indexed-search-root-count=0`、`search-index-scan-count=0`；
  `examples/smoke/hello_with_units.pas` 则会稳定表现为
  `search-index-status=ready`、`indexed-search-root-count=2`、
  `search-index-scan-count=2`。
- 当前 `partial` 也已经不再只靠 focused probe 留证：
  `explicit-unit-root`、`package-manifest-source-precedence`、
  `root-source-precedence`、`unit-root-precedence` 现在都会额外断言
  `search-index-status=partial` 与对应 `indexedSearchRootCount` /
  `searchIndexScanCount`，其中 root-source precedence 稳定为 `1/1`，
  explicit/package precedence 代表路径稳定为 `2/2`。
- 这批只补“当前命令级 truth 的稳定投影”，不宣称完整 `WorkspaceModel`、
  richer package/workspace graph 或 target default persistence 已落地。
- `resolver.unit-not-found` 与 `resolver.ambiguous-unit-source` 当前也已经消费
  `TSearchPathSet` 的 typed metadata，在 diagnostic message 中投影
  `scope` / `provenance` / `root`，并在 candidate 场景额外投影 `path`。
- 当前仍未完成的更大项不是这轮收口内容：
  完整 multi-root workspace model、更丰富的 package/workspace provenance 与
  nextPas 完整脱离宿主 FPC 的最终 codegen
