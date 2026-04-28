# nextPas `stage0` 驱动规范

用这份规范定义 `tools/stage0/nextpas.pas` 在第一阶段的公开行为。`stage0`
驱动入口不是“先随便做一个 CLI 再慢慢改”，而是 nextPas 第一条受控构建路径的
公开表面，因此必须先把命令范围、输入形式、失败行为和阶段边界写清楚。

如果你要看这条命令表面以后怎样接进更完整的 toolchain control plane，继续读
`toolchain-specification.md`。如果你要看 future workspace-aware command surface 应该建立在
什么对象边界上，继续读 `workspace-specification.md`。如果你要看 `build/test/pkg/fmt/doc/env/doctor/query`
怎样最终收敛到统一产品命令面，继续读 `developer-tooling-specification.md`。

## `stage0` 驱动入口当前服务四条最小公开路径

当前仓库已经承诺这四条明确的公开命令：

```text
nextpas build <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>] [--unit-root <dir>]... [--out-dir <dir>]
nextpas test --list-groups [--workspace <root>]
nextpas test --filter <group> [--workspace <root>]
nextpas env status --target linux-x86_64 [--toolchain-binding <id>]
nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
```

这四条命令的意义分别是：

- `build`
  - 让 FreePascal 托管的 `stage0` 路径在 Linux x86_64 上证明 nextPas 已经拥有最小但真实的
    build control surface
- `test`
  - 让现有 harness 通过同一个 `nextpas` 产品壳进入公开命令面，而不是继续只停留在 repo-local
    shell 入口
- `env status`
  - 让 shared target/binding/distribution/runtime truth 先以只读 surface 进入统一
    `nextpas` 产品壳，而不是继续散落在 support script 或手工 probe 里
- `doctor`
  - 让 environment / toolchain / workspace health inspection 先以只读 surface 进入统一
    `nextpas` 产品壳，而不是把健康判断混进 `env status` 或 support script

当前 `--target` 与 `--toolchain-binding` 是两条分开的输入轴：

- `--target` 继续定义目标语义
- `--toolchain-binding` 只允许在同一 host/target pair 下覆盖“谁来生产这些目标产物”
- 不显式传 binding 时，当前默认仍是 `linux-x86_64-to-linux-x86_64-gnu`
- 显式传 `linux-x86_64-to-linux-x86_64-llvm` 时，会切到 LLVM-heavy execution path

第一阶段当前除了这四条路径之外，不承诺更多子命令，也不承诺泛化的命令树。

这同样意味着：第一阶段除了只读 `env status` 与只读 `doctor` 之外，仍不承诺 `env bootstrap`、
channel switch、runtime SDK install 或其他 environment management verb。但 future 如果补上
这些能力，它们也必须继续挂在统一 `nextpas` 产品壳下，复用同一套 parser、global options 与
result envelope，而不是另外长出一个 installer 或 channel CLI 世界。

## 当前已经落地的 workspace / artifact contract

虽然 `stage0` 还不是完整 workspace-aware product surface，但当前仓库已经有一条真实、可验证的
最小 contract：

- `--workspace <root>` 显式给出时，workspace root 直接取这个目录
- 如果没有 `--workspace`，会从 source 所在目录向上优先寻找最近的 `nextpas.workspace.toml`
- 如果没有 workspace descriptor，再向上寻找最近的 `nextpas.package.toml`
- 两者都没有时，退回 source 所在目录
- `--unit-root <dir>` 可以重复出现，relative path 以 resolved workspace root 为基准
- `--out-dir <dir>` 也以 resolved workspace root 为基准解析 relative path

这条 contract 的 owner 现在已经不是 driver 私有 helper。当前 `stage0` 会先调用
`compiler/frontend/np_workspace_model.pas` 里的 `ResolveWorkspaceModel(...)`，再把 shared model
投影到 line-based output、`command-envelope=<json>` 与 `TCompilationSession`。

当前默认 artifact layout 也已经稳定：

```text
<workspace-root>/.nextpas/
  out/<target>/
  cache/backend/<target>/
  cache/host-fpc/<target>/
```

也就是说：

- 默认主产物进入 `<workspace-root>/.nextpas/out/linux-x86_64/<program>`
- 默认 GNU/native binding 会把 `.s/.o/<program>_link.res` 收口到
  `<workspace-root>/.nextpas/cache/backend/linux-x86_64/`
- 显式 LLVM binding 会把 `.ll/.bc/.o` 收口到同一个 backend cache root
- 宿主 FPC scratch `.ppu/.o` 进入 `<workspace-root>/.nextpas/cache/host-fpc/linux-x86_64/`
- source-adjacent output 不再是默认路径
- 如果 nearest package manifest 或 workspace descriptor 提供了 source roots，它们会先进入
  package source tier
- 当前 unit search precedence 已经是
  `root-source -> package-source-root -> explicit-unit-root -> target-installed`
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 当前已经显式冻结
  explicit workspace override、nearest package manifest 与 workspace member 三条 shared model 代表路径

## `tools/stage0/nextpas.pas` 的职责边界

| 组成                       | 第一阶段职责                                                                     |
| -------------------------- | -------------------------------------------------------------------------------- |
| `tools/stage0/nextpas.pas` | 解析公开命令、为 `build` 加载 shared workspace model / target facts / toolchain、为 `test` thin-wrap 现有 harness、为 `env status` 投影 target/binding/distribution/runtime state、为 `doctor` 投影最小只读健康检查 |
| `tools/stage0/README.md`   | 说明用法、退出码、范围约束和当前不支持的事项                                     |
| `examples/smoke/hello.pas` | 作为规范输入，证明驱动路径真实可走通                                             |

这意味着 `stage0` 驱动入口是“受约束的构建控制面”，不是第一阶段的完整工具链前端。

当前更细的 owner 边界是：

- workspace/package/artifact discovery 归 `compiler/frontend/np_workspace_model.pas`
- package manifest parser 与 typed root info 归 `compiler/frontend/np_package_manifest.pas`
- `stage0` 继续拥有 CLI surface、`--unit-root` / `--toolchain-binding` override 解析与最小 orchestration
- `TCompilationSession` 在创建后正式接管 shared model 的生命周期

## 必须保留的公开行为

第一阶段对 `stage0` 驱动入口至少承诺以下行为：

| 行为     | 要求                                                                                                      |
| -------- | --------------------------------------------------------------------------------------------------------- |
| 成功路径 | 能处理 `nextpas build <source> --target linux-x86_64 [--toolchain-binding ...] [--workspace ...] [--unit-root ...] [--out-dir ...]`、`nextpas test --list-groups|--filter <group> [--workspace ...]`、`nextpas env status --target linux-x86_64 [--toolchain-binding ...]` 与 `nextpas doctor --target linux-x86_64 [--toolchain-binding ...] [--workspace ...]` |
| 宿主关系 | 由 FreePascal 负责把驱动入口编译成可执行程序                                                              |
| 输出语义 | `build`、`test --filter <group|smoke>`、`env status` 与 `doctor` 都要给出清晰、可留证的结果，并投影 `command-envelope=<json>` |
| 未知命令 | 以非零状态退出，并打印清晰的 `unsupported-command` 消息                                                   |

这组行为既是任务 9 的验收接口，也是后续 `build/verify_local.sh` 与 Linux CI
会依赖的控制面。

## `stage0 env status` 只投影已解析 environment state

`env status` 当前是 `stage0` 上最小、只读的 environment surface。它的职责边界固定如下：

- 不修改 active selection、distribution、runtime SDK 或 channel state
- 复用同一份 target facts 与 toolchain binding resolution，解析 distribution bin/lib/share、
  runtime root 与 runtime libc locator
- 即使当前 environment 仍然不完整，也继续以 `status=success` / `result=success` 结束
- 真实环境状态通过 `environment-readiness` / `environment-status`、
  `runtime-sdk-status`、`toolchain-binding-status`、`distribution-status` 与
  `runtime-libc-present` 投影，而不是把“未就绪”误报成 command failure
- `environment-readiness` 当前保留为兼容字段，并与 `environment-status` 使用同一
  derived readiness vocabulary
- 为什么当前状态不适合 build/test/pkg/doc/query，属于当前最小 `doctor` 与后续更完整 health inspection 的诊断边界

## `stage0 doctor` 提供最小只读 health inspection

`doctor` 当前是 `stage0` 上第一条正式健康检查 surface。它的职责边界固定如下：

- 不修改 active selection、distribution、runtime SDK、channel state 或 workspace source
- 复用 `env status` 已使用的 target facts、toolchain binding、distribution 与 runtime locator
- 可选消费 `--workspace <root>`，只确认 workspace root 是否可解释为目录
- 即使发现 runtime SDK 缺失，也继续以 `status=success` / `result=success` 表示 inspection 本身完成
- 真实健康摘要通过 `doctor-workspace-status`、`doctor-toolchain-binding-status`、
  `doctor-status`、`doctor-check-count`、`doctor-finding-count` 与代表性
  `doctor-finding-*` 字段投影
- `command-envelope=<json>.result.doctorFindings[]` 保存同一条 finding 的
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`

当前 `doctor` 已冻结最小 structured finding contract；package/workspace coherence 检查与更完整的
health taxonomy 应在后续批次继续加固。

## `stage0 build` 的结果语义也必须朝统一 envelope 收敛

第一阶段虽然只公开一条 `build` 命令，但它的结果表面不能再长成另一套私有协议。

`developer-tooling-specification.md` 已经冻结 `CommandResultEnvelope`，而
`toolchain-specification.md` 也已经把 `status event`、`build trace` 和 `diagnostic`
拆成三条不同表面。`stage0` 这里必须直接对齐这套边界。

因此 nextPas 继续冻结：

- `stage0 build` 的成功与失败都应能被解释成同一类 `CommandResultEnvelope`
- 当前 CLI 即使暂时继续输出 line-based key/value，也只应被看作 envelope 的 human projection
- canonical truth 不是那几行文本本身，而是它们表达的结构化结果语义
- `stage0` 不允许再为 smoke build 重新发明另一套只服务 shell 的结果模型

第一阶段推荐先收敛这些最小结果字段：

- command family
- selector
- source locator
- target id
- status
- result
- optional failure kind
- compiler identity
- artifact or result locator
- build outcome
- diagnostics summary
- optional build trace ref
- human summary

进入 `Batch 3` 之后，`stage0 build` 还必须承担一件更重要但仍然很小的职责：它要能真实创建
最小 `CompilationSession` skeleton，而不是继续把 source / target / diagnostics ownership
留在未来实现里。

当前仓库里，这至少意味着：

- `stage0 build` 在成功路径上会实例化 `TCompilationSession`
- 这个 session 真实拥有 `TSourceDatabase`、`TTargetFactsView`、`TDiagnosticsSink` 与 compilation options
- 当前 CLI projection 会额外暴露 `session-id`、`root-file-id`、`source-db-file-count`、
  `diagnostics-count`、warning/error split 计数，以及三类 lifecycle summary
- 这些字段不是在承诺最终 compiler UI，而是在证明 session skeleton 已进入真实执行路径

进入 `Batch 4` 之后，这条 build path 还要继续往前接一小步，但必须是真实现而不是演示壳：

- `stage0 build` 要在调用宿主 FPC 之前，先通过 `TCompilationSession.AnalyzeSyntax` 跑最小 syntax front
- 成功路径要额外暴露 `syntax-status`、`lexer-token-count`、`green-node-count`、
  `ast-root-kind`、`ast-declared-name`
- syntax failure 要先进统一 diagnostics sink，再以 `failure-kind=syntax-analysis-failed`
  退出，而不是把 parser failure 混成宿主 compiler failure
- 当前 failure projection 至少要能暴露 `diagnostic-code=parser.syntax-error` 与
  `diagnostic-phase=syntax`

进入 `Batch 5` 之后，这条 build path 继续往前接的最小真实落点是 unit resolution，而不是
把 unit 查找继续留给宿主 FPC 的路径习惯：

- `stage0 build` 要在调用宿主 FPC 之前，通过 `TCompilationSession.ResolveUnits` 真实运行
  `SearchPathSet` / `UnitGraph` / name resolution skeleton
- 成功路径要额外暴露 `resolution-status`、`unit-graph-status`、`search-path-count`、
  `resolved-unit-count`、`unit-graph-edge-count` 与 `unit-graph-root-name`
- resolution failure 要先进统一 diagnostics sink，再以
  `failure-kind=unit-resolution-failed` 退出
- 当前 failure projection 至少要能暴露
  `diagnostic-code=resolver.unit-not-found|resolver.ambiguous-unit-source|resolver.unit-cycle-detected`
  与 `diagnostic-phase=resolution`
- 宿主 FPC compile step 必须显式带上 target-aware `-Fu<units_dir>`，证明
  `units/<target>/` 已进入真实 build path

进入 `Batch 6` 之后，这条 build path 继续往前接的最小真实落点是 semantic model /
`Typed HIR` skeleton，而不是把语义判断继续留给宿主 FPC 或 future backend：

- `stage0 build` 要在 resolution 之后，通过 `TCompilationSession.AnalyzeSemantics`
  真实运行最小 `TSemanticAnalyzer`
- 成功路径要额外暴露 `semantic-status`、`symbol-graph-status`、`type-graph-status`、
  `typed-hir-status`、`symbol-count`、`type-count`、`typed-hir-node-count`、
  `runtime-contract-count` 与 `typed-hir-root-name`
- semantic failure 要先进统一 diagnostics sink，再以
  `failure-kind=semantic-analysis-failed` 退出
- 当前 failure projection 至少要能暴露 `diagnostic-code=sema.duplicate-declaration`
  与 `diagnostic-phase=sema`

进入 `Batch 7` 之后，这条 build path 继续往前接的最小真实落点是 `MIR` / backend plan /
toolchain binding skeleton，而不是继续让 `Typed HIR` 之后的 truth 停留在文档里：

- `stage0 build` 要在 semantic analysis 之后，通过 `TCompilationSession.LowerToMir` 与
  `TCompilationSession.PlanBackend` 真实运行最小 `TMirLowerer` / `TBackendPlanner`
- 成功路径要额外暴露 `mir-status`、`mir-block-count`、`mir-operation-count`、
  `mir-entry-block`、`mir-root-name`
- 成功路径要额外暴露 `backend-plan-status`、`backend-output-kind`、
  `backend-primary-artifact-kind`、`backend-primary-artifact-path`、
  `backend-artifact-count`、`backend-artifacts`、
  `toolchain-plan-status`、`toolchain-plan-family`、`tool-profile-root`、
  `logical-link-request-status`、`logical-link-request-output-kind`、
  `logical-link-request-library-count`、`logical-link-request`、
  `llvm-toolchain-status`、`llvm-executable-set-id`、`llvm-executable-set`、
  `tool-invocation-count`、`primary-tool-role`、`primary-tool-profile-id`、
  `primary-tool-step-id`、`primary-tool-logical-executable`、
  `primary-tool-sysroot-ref`、`primary-tool-failure-mapping`、
  `tool-run-status`、`tool-run-step-count` 与 `primary-tool-run-status`
- 成功路径要额外暴露 `toolchain-binding-id`、`backend-family`、
  `assembler-profile-id`、`linker-profile-id`、`archiver-profile-id`、
  `resource-tool-profile-id`、`target-object-format`、`target-assembler-flavor`、
  `target-linker-flavor`、`tool-root-kind`、`runtime-root-kind`、
  `response-file-policy` 与 `link-script-policy`
- 当前这条 backend plan 仍允许宿主 FPC 继续负责真实编译执行，但 `stage0` 不能再假装
  自己不知道 `Typed HIR` 之后准备产生什么 artifact、依赖什么 toolchain identity
- 当前默认 `bootstrap-native-assemble-link` path 与显式
  `llvm-ir-opt-llc-link` path 都必须复用
  `TCompilationSession.ExecuteToolchain(...) -> ExecuteToolchainPlan(...)`，
  而不是长期保留 driver 私有 `TProcess` 执行路径

当前这条 bootstrap-native path 会直接调用
`TCompilationSession.ExecuteToolchain(GetEnvironmentVariable('PATH'))`，先由
`host-fpc-emit-asm` 把根程序和 source-backed units 的 `.s` 与确定性的
`<program>_link.res` 写进 backend cache，再依次执行 `native-assemble` 与 `native-link`。
`ExecuteToolchainPlan(...)` 的 `TToolchainRunResult` 由 session 持有，`tool-run-status` /
`tool-run-step-count` / `primary-tool-run-status` 等字段会同时投影到 line-based output 和
`command-envelope=<json>` 的 `toolRunStatus` / `toolRunStepCount` /
`primaryToolRunStatus`，`build/verify_local.sh` 的 success / semantic-smoke /
toolchain-failure gate 也确认这些字段在各种路径都能出现，从而把多步 production path 送进
真实执行面。

显式 LLVM binding 时，同一套 session-owned runner 也必须切到
`llvm-ir-opt-llc-link`，并按 `llvm-opt-bitcode -> llvm-llc-object -> llvm-link` 执行，
同时把 `llvm-toolchain-status`、`llvm-executable-set-*` 与 LLVM-specific
`primaryTool*` truth 投影到同一份 result envelope。

当前还必须把剩余限制写明：`compiler/frontend/np_compilation_session.pas` 现在已经会把
`native-assemble` / `native-link` failure 对齐到真实失败 step，later-step failure attribution
不再回退到 `host-fpc-emit-asm`。`build/verify_local.sh` 也已用
`assembler-failure-attribution-check` 与 `linker-failure-attribution-check` 冻结这条 contract。
这条 observability gap 现在也已经收口：success 情况下的 build trace / status event
会把全部 executed steps 按顺序投影出来，并统一使用 plan-level
`build-trace-ref=trace-<session-id>-toolchain-plan`。当前要继续守住的边界是 event/step
数量由真实执行面决定，不能再被 `stage0` 或调用方冻结成固定常量。

这条规则的目的很直接：`stage0` 今天是最小路径，但它不能成为以后统一产品壳里的语义异类。

## `stage0` 只投影 toolchain status / trace，不重造第二套日志系统

`toolchain-specification.md` 现在已经有正式的 `ToolchainStatusEvent` 和 `ToolchainBuildTrace`。
`stage0` 作为 command surface，不应该再把它们揉回一份模糊 stdout 日志。

因此：

- progress 类信息，例如“正在 assembling / linking”，属于 status event，不属于 diagnostic
- 失败后的 step、artifact、sidecar、diagnostic relation，属于 build trace，不属于 `stage0`
  自己拼的一段回放文本
- `stage0` 可以把 status event 以 human-friendly 方式投影到 CLI
- 但它不重新定义 event kind、step identity 或 trace schema

推荐的最小结果形状可以是：

```json
{
  "command": "build",
  "exitCode": 0,
  "result": {
    "source": "examples/smoke/hello.pas",
    "target": "linux-x86_64",
    "workspaceRoot": "<workspace-root>",
    "workspaceDiscoveryKind": "explicit-workspace-override",
    "artifactRoot": "<workspace-root>/.nextpas",
    "outputDir": "<workspace-root>/.nextpas/out/linux-x86_64",
    "compiler": "fpc",
    "artifact": "<workspace-root>/.nextpas/out/linux-x86_64/hello",
    "buildResult": "success",
    "backendArtifactCount": 3,
    "backendArtifacts": [{ "...": "assembly/object/executable artifacts" }],
    "toolchainPlanFamily": "bootstrap-native-assemble-link",
    "toolRunStatus": "success",
    "toolRunStepCount": 3,
    "primaryToolRunStatus": "success"
  },
  "diagnostics": [],
  "buildTraceRef": "<optional-trace-locator>",
  "buildTrace": { "...": "optional typed trace payload" },
  "toolInvocationPlanRef": "<optional-plan-locator>",
  "toolInvocationPlan": { "...": "optional typed plan payload" },
  "toolStatusEvents": [{ "...": "optional status event snapshot" }],
  "humanSummary": "build succeeded"
}
```

这里的字面量示例描述的是默认 GNU/native binding。显式
`--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 时，同一份 result shape 仍成立，
但 `compiler`、`backendArtifactCount/backendArtifacts`、`toolchainPlanFamily`、
`primaryTool*` 与 LLVM executable-set 相关字段会切到 LLVM-heavy truth。

当前仓库中的最小 bridge 已经进一步收敛为：

```text
command-envelope=<json>
```

也就是说，`stage0` 现在继续保留 line-based key/value 作为 human projection，但结构化结果对象
已经以单行 JSON 的方式真实出现在命令输出里。当前实现里的最小公共控制面字段已经对齐到：

- `command=build`
- `selector=build`
- `target=linux-x86_64`
- `status=success|failure`
- `result=success|failure`
- `command-outcome=success|failure`
- `failure-kind=<kind>`（仅失败路径）
- `human-summary=<summary>`

而在当前 `Batch 3/4/5/6/7` 落地之后，成功的 `build` path 还会暴露这些 compiler-kernel-facing 字段：

- `session-id=<id>`
- `root-file-id=<id>`
- `source-db-file-count=<count>`
- `source-db-line-index=<state>`
- `unit-state-count=<count>`
- `diagnostics-count=<count>`
- `diagnostics-error-count=<count>`
- `diagnostics-warning-count=<count>`
- `diagnostics-policy=<policy>`
- `workspace-root=<path>`
- `workspace-discovery-kind=explicit-workspace-override|nearest-workspace-descriptor|nearest-package-manifest|source-directory-fallback`
- `workspace-descriptor-path=<path>`（有值时）
- `package-manifest-path=<path>`（有值时）
- `artifact-root=<path>`
- `output-dir=<path>`
- `syntax-status=ready|failure`
- `lexer-token-count=<count>`
- `green-node-count=<count>`
- `ast-root-kind=<kind>`
- `ast-declared-name=<name>`
- `resolution-status=ready|failure|deferred`
- `unit-graph-status=ready|failure|deferred`
- `search-path-count=<count>`
- `search-index-status=deferred|partial|ready|empty`
- `indexed-search-root-count=<count>`
- `search-index-scan-count=<count>`
- `resolved-unit-count=<count>`
- `unit-graph-edge-count=<count>`
- `unit-graph-root-name=<name>`
- `semantic-status=ready|failure|deferred`
- `symbol-graph-status=ready|failure|deferred`
- `type-graph-status=ready|failure|deferred`
- `typed-hir-status=ready|failure|deferred`
- `symbol-count=<count>`
- `type-count=<count>`
- `typed-hir-node-count=<count>`
- `runtime-contract-count=<count>`
- `typed-hir-root-name=<name>`
- `mir-status=ready|failure|deferred`
- `mir-block-count=<count>`
- `mir-operation-count=<count>`
- `mir-entry-block=<label>`
- `mir-root-name=<name>`
- `backend-plan-status=ready|failure|deferred`
- `backend-output-kind=<kind>`
- `backend-primary-artifact-kind=<kind>`
- `backend-primary-artifact-path=<path>`
- `backend-artifact-count=<count>`
- `backend-artifacts=<json>`
- `toolchain-binding-id=<binding-id>`
- `backend-family=<family>`
- `assembler-profile-id=<profile-id>`
- `linker-profile-id=<profile-id>`
- `archiver-profile-id=<profile-id>`
- `resource-tool-profile-id=<profile-id>`
- `host-id=<host-id>`
- `target-object-format=<format>`
- `target-assembler-flavor=<flavor>`
- `target-linker-flavor=<flavor>`
- `target-runtime-layout-key=<layout-key>`
- `target-c-symbol-prefix=<prefix-or-empty>`
- `target-c-library-naming=<naming-key>`
- `target-llvm-triple=<triple>`
- `target-llvm-data-layout=<data-layout>`
- `sysroot-mode=<mode>`
- `runtime-sdk-id=<sdk-id>`
- `allow-host-fallback=<true|false>`
- `tool-root-kind=<resolution-kind>`
- `runtime-root-kind=<resolution-kind>`
- `response-file-policy=<policy>`
- `link-script-policy=<policy>`
- `toolchain-plan-status=<status>`
- `toolchain-plan-family=<family>`
- `tool-profile-root=<path>`
- `logical-link-request-status=<status>`
- `logical-link-request-output-kind=<kind>`
- `logical-link-request-library-count=<count>`
- `logical-link-request=<json>`
- `llvm-toolchain-status=<status>`
- `llvm-executable-set-id=<id>`（有值时）
- `llvm-executable-set=<json>`（有值时）
- `tool-invocation-count=<count>`
- `primary-tool-role=<role>`
- `primary-tool-profile-id=<profile-id>`
- `primary-tool-step-id=<step-id>`
- `primary-tool-logical-executable=<logical-executable>`
- `primary-tool-sysroot-ref=<sysroot-ref>`
- `primary-tool-failure-mapping=<failure-kind>`
- `tool-run-status=success|failure`
- `tool-run-step-count=<count>`
- `primary-tool-run-status=success|failed`
- `diagnostics-summary=<summary>`
- `lifecycle-session=<summary>`
- `lifecycle-unit=<summary>`
- `lifecycle-stage=<summary>`

同一条 `command-envelope=<json>.result` 当前也必须继续同步带上这些 execution-result 的
camelCase 版本，至少包括 `toolchainPlanStatus`、`toolchainPlanFamily`、
`toolProfileRoot`、`logicalLinkRequestStatus`、`logicalLinkRequestOutputKind`、
`logicalLibraryRequestCount`、`logicalLinkRequest`、`llvmToolchainStatus`、
`llvmExecutableSetId`、`llvmExecutableSet`、`toolRunStatus`、`toolRunStepCount` 与
`primaryToolRunStatus`。

这里还要冻结一条当前已经落地的失败边界：`workspace-root`、
`workspace-discovery-kind`、`workspace-descriptor-path`、`package-manifest-path`、
`artifact-root`、`output-dir` 属于 command-level build context，不属于 session-owned state。
所以像 `invalid-unit-root` 这类在 `TCompilationSession` 创建前就失败的路径，当前也会继续投影
这批已知字段；同一条 `command-envelope=<json>.result` 还会继续带上 `source`、`target` 与
对应 camelCase 字段。但这不等于引入第二套 pseudo-session：`stage0` 不会为 early failure
伪造 `session-id`、`diagnostics-count`、`syntax-status` 等 session-owned projection。

`build/verify_local.sh` 与 Linux CI 应直接复用这条桥，而不是再为 smoke build 发明另一套
shell-only 成功判定。
这同样意味着围绕这条桥的 verify/harness 编排也不能再靠 source-adjacent scratch 输出取巧：
toolchain contract probe 应落到临时 build dir，并在 harness bootstrap failure 时保留
`bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file` 和原始 stderr evidence，
否则 surrounding automation 仍然无法稳定回放失败。

对当前最小 pre-session failure baseline，`stage0 build` 还必须满足：

- `invalid-unit-root` 这类在 session 创建前就失败的路径，仍要继续投影
  `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`
- 同一条 `command-envelope=<json>.result` 仍要带上 `failureKind`、`source`、`target`、
  `workspaceRoot`、`workspaceDiscoveryKind`、`artifactRoot`、`outputDir`
- 但这条 early failure 不能伪造 `session-id`、`diagnostics-count`、`syntax-status` 等
  session-owned 字段

对当前最小 syntax failure baseline，`stage0 build` 还必须满足：

- diagnostics array 出现在 `command-envelope=<json>` 里，而不是固定空数组
- `parser.syntax-error` 的 phase 为 `syntax`
- syntax failure 会阻止宿主 FPC compile step 启动

对当前最小 unit resolution baseline，`stage0 build` 还必须满足：

- `resolver.unit-not-found`、`resolver.ambiguous-unit-source`、`resolver.unit-cycle-detected`
  的 phase 都为 `resolution`
- resolution failure 会阻止宿主 FPC compile step 启动
- `examples/smoke/hello_with_units.pas` 必须能通过 `root-source -> target-installed`
  解析出 4 个 resolved units 和 4 条 graph edges
- 显式 `--unit-root` 必须拥有高于 `target-installed`、低于 `root-source` 的 precedence

对当前最小 semantic baseline，`stage0 build` 还必须满足：

- `sema.duplicate-declaration` 的 phase 为 `sema`
- semantic failure 会阻止宿主 FPC compile step 启动
- `examples/smoke/hello_with_units.pas` 必须能显式投影
  `semantic-status=ready`、`symbol-count=4`、`type-count=3`、`typed-hir-node-count=7`
  与 `runtime-contract-count=2`

对当前最小 `MIR` / backend / toolchain baseline，`stage0 build` 还必须满足：

- `examples/smoke/hello.pas` 必须能显式投影 `mir-status=ready`、`mir-block-count=1`、
  `mir-operation-count=6`、`backend-plan-status=ready`、
  `host-id=linux-x86_64`、`toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu`、
  `assembler-profile-id=gnu-as`、`linker-profile-id=gnu-ld`、
  `archiver-profile-id=gnu-ar`、`resource-tool-profile-id=none`、
  `target-runtime-layout-key=target-sdk-split`、`sysroot-mode=runtime-sdk`、
  `tool-root-kind=distribution-helper-root`、`runtime-root-kind=distribution-runtime-root`、
  `response-file-policy=auto` 与 `link-script-policy=when-required`
- 同一条最小 smoke path 当前还会诚实暴露 lazy resolver index truth：
  `search-index-status=deferred`、`indexed-search-root-count=0`、
  `search-index-scan-count=0`
- `examples/smoke/hello_with_units.pas` 必须能显式投影 `mir-status=ready`、
  `mir-operation-count=8`、`backend-output-kind=executable`、
  `backend-primary-artifact-path=<workspace-root>/.nextpas/out/linux-x86_64/hello_with_units`、
  `backend-family=native`、`target-object-format=elf`、`target-assembler-flavor=gnu-as`、
  `target-linker-flavor=gnu-ld`、`target-c-library-naming=lib-prefix-so-a`、
  `target-llvm-triple=x86_64-unknown-linux-gnu`、`runtime-sdk-id=linux-x86_64`、
  `allow-host-fallback=false`、`tool-root-kind=distribution-helper-root`、
  `runtime-root-kind=distribution-runtime-root`、`response-file-policy=auto`、
  `link-script-policy=when-required`、`toolchain-plan-family=bootstrap-native-assemble-link`、
  `logical-link-request.objectInputs=[backend-owned <program>.o]`、
  `llvm-toolchain-status=disabled`、`llvm-executable-set-id=llvm-stable`、
  `tool-invocation-count=3`、
  `primary-tool-role=host-compiler`、
  `primary-tool-profile-id=fpc-stage0-host`、`primary-tool-step-id=host-fpc-emit-asm`、
  `primary-tool-logical-executable=fpc`、
  `primary-tool-sysroot-ref=runtime-sdk:linux-x86_64` 与
  `primary-tool-failure-mapping=toolchain.host-compiler-exec-failed`、
  `tool-run-status=success`、`tool-run-step-count=3` 与
  `primary-tool-run-status=success`
- 这条发生真实 unit lookup 的 success path 当前还必须显式投影
  `search-index-status=ready`、`indexed-search-root-count=2` 与
  `search-index-scan-count=2`
- 同一条 success path 当前还必须显式投影
  `tool-invocation-plan-ref=plan-<session-id>-primary-tool`、
  `tool-invocation-plan.planKind=tool-invocation`、
  `tool-invocation-plan.planFamily=bootstrap-native-assemble-link`、
  `tool-invocation-plan.steps[*].stepId=host-fpc-emit-asm/native-assemble/native-link`、
  `tool-invocation-plan.steps[0].argv=["-st","-Aas","-FE<backend-cache>","-FU<backend-cache>","-Fu<units-dir>","<abs-source-path>"]`、
  `tool-invocation-plan.steps[0].inputs[0].kind=pascal-source`、
  `tool-invocation-plan.steps[0].outputs[0].kind=assembly-text`、
  `tool-invocation-plan.steps[0].outputs[1].kind=linker-script`
- `examples/smoke/hello.pas --toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 也必须能
  显式投影 `compiler=opt`、
  `toolchain-binding-id=linux-x86_64-to-linux-x86_64-llvm`、`backend-family=llvm`、
  `linker-profile-id=lld-elf`、`backend-artifact-count=4`、
  `backend-artifacts=[llvm-ir,llvm-bitcode,object-file,executable]`、
  `toolchain-plan-family=llvm-ir-opt-llc-link`、`llvm-toolchain-status=ready`、
  `llvm-executable-set-id=llvm-stable`、`tool-invocation-count=3`、
  `primary-tool-profile-id=llvm-stable`、
  `primary-tool-step-id=llvm-opt-bitcode`、
  `primary-tool-logical-executable=opt`
- 同一条 LLVM success path 还必须显式投影
  `tool-invocation-plan.planFamily=llvm-ir-opt-llc-link`、
  `tool-invocation-plan.steps[*].stepId=llvm-opt-bitcode/llvm-llc-object/llvm-link`、
  `logical-link-request.objectInputs=[backend-owned <program>.o]` 与
  `build-trace.steps[*].status=success`
- 成功路径当前还必须显式投影
  `tool-status-event-count=10`、`tool-status-events=<json>`、
  `build-trace-ref=trace-<session-id>-toolchain-plan` 与
  `build-trace.steps[*].status=success`
- 这条 success path 当前还必须体现“production path 已复用 generic runner”这件事，
  至少通过 `tool-run-status=success`、`tool-run-step-count=3` 与
  `primary-tool-run-status=success` 把 runner result 暴露出来
- 如果 success path 里还包含 source-backed unit，当前 plan 还允许继续追加
  `native-assemble-<unit>` steps，因此 `tool-invocation-count` 在特定场景下也可能是 `4+`
- 其中 `session-id`、`tool-invocation-plan-ref` 与 `build-trace-ref` 当前都必须是每次 build
  唯一的 locator；verify gate 要保护“同一轮输出内一致、不同 build 之间不复用”，而不是把
  某个固定字面量当成契约
- 一旦宿主 compiler execute step 抛出 `EOSError` 或以非零状态退出，失败路径应直接使用
  `toolchain.host-compiler-exec-failed`，而不是 `stage0` 私有的
  `compiler-launch-failed` / `build-failed`
- 当前最小 host-compiler failure baseline 还必须显式投影
  `diagnostics-count=1`、`diagnostics-summary=toolchain.host-compiler-exec-failed`、
  `diagnostic-id=diag-0001`、`diagnostic-code=toolchain.host-compiler-exec-failed`、
  `diagnostic-phase=toolchain`、
  `diagnostic-binding-id=linux-x86_64-to-linux-x86_64-gnu`、
  `diagnostic-profile-id=fpc-stage0-host`、`diagnostic-step-id=host-fpc-emit-asm`、
  `diagnostic-logical-executable=fpc`、`diagnostic-sysroot-ref=runtime-sdk:linux-x86_64`、
  `build-trace-ref=trace-<session-id>-toolchain-plan`、
  `tool-run-status=failure`、`tool-run-step-count=1` 与
  `primary-tool-run-status=failed`
- 同一条 failure envelope 的 `diagnostics[0]` 还必须能引用
  `id/bindingId/profileId/stepId/logicalExecutable/sysrootRef/resolvedPath/primaryArtifact/exitCode`
- 同一条 failure trace 还必须能通过
  `buildTraceRef + buildTrace.steps[0].diagnosticRefs=["diag-0001"]`
  指回正式 diagnostic，而不是只给一条自由文本回放
- 同一条 failure envelope 当前还必须继续暴露
  `toolInvocationPlanRef` 与 `toolInvocationPlan`，这样 CI/IDE/harness 可以在失败时直接拿到
  真正执行计划，而不是再从 build trace 或 stdout 文本里反推 argv / working directory /
  typed inputs / outputs / sidecars
- success path 当前还必须显式留下完整 executed-step transcript：主三步路径至少包含
  `host-fpc-emit-asm`、`native-assemble`、`native-link` 各自的
  `tool-selected/step-started/step-finished`，最后再补一条
  `toolchain.plan-finished`；对 `hello.pas` 当前因此固定为 `10` 个 event
- 当前 verify 也已把 later-step failure baseline 收进正式 contract：fake `as` / `ld`
  负路径必须分别投影 `toolchain.assembler-exec-failed` /
  `toolchain.linker-exec-failed`，并把
  `diagnostic-profile-id`、`diagnostic-step-id`、`diagnostic-logical-executable`、
  `build-trace-ref=trace-<session-id>-toolchain-plan` 与 status-event step metadata
  对齐到真实失败的 `native-assemble` / `native-link`
- 当前 verify 也已把 success path transcript 收进正式 contract：`buildTrace.steps[*]`
  必须保留全部 executed steps，`diagnosticRefs` 只允许出现在失败 step 上，额外 sidecars
  则通过 runner transcript 暴露 `materialized/cleanupStatus` truth
- 当前 verify 也已把显式 LLVM binding smoke 收进正式 contract：fake
  `opt` / `llc` / `ld.lld` 路径必须投影
  `compiler=opt`、`backend-artifact-count=4`、
  `toolchain-plan-family=llvm-ir-opt-llc-link` 与三步 LLVM transcript
- `lifecycle-stage` 必须能区分 `syntax`、`resolution`、`sema`、`ir`、`backend` 五个阶段，
  而不是继续把 `Typed HIR` 之后的生命周期压成 `deferred`

这份 shape 当前主要回答：

- 命令最终成功还是失败
- 成功时产出了什么
- 失败时应该去哪里找 diagnostic 和 trace
- CLI、CI、IDE、harness 消费的是同一份 command result truth

它继续明确不回答这些内容：

- 不把实时 status event stream 整段嵌进 result envelope 当主稳定表面
- 不把 build trace 退化成一段 console transcript
- 不把 toolchain diagnostic 改写成 `stage0` 私有错误码

换句话说，`stage0` 是统一 command surface 的最小入口，不是统一可观测性 contract 的例外。

## 驱动入口与目标规格必须解耦

`stage0` 驱动入口不应该把 Linux x86_64 的所有规则直接硬编码在主文件里。
它必须把目标相关假设委托给外置的目标规格边界，让命令行驱动、目标模型和发行布局
保持可解释的分层。

因此，`nextpas` 的公开语义应该满足：

- 命令入口负责解析与流程编排。
- `build/targets/linux-x86_64.toml` 负责目标平台事实。
- 运行时与测试路径通过 `harness` 和 smoke 样例来证明行为。
- command result、diagnostics、status event 与 build trace 继续服从统一控制面，而不是由 `stage0`
  额外定义一次。

## `stage0` 与后续阶段的关系

- `stage0`：先建立由 FreePascal 托管的 nextPas 命令行控制面。
- `stage1`：nextPas 可以逐步接管更多内部逻辑，但应尽量保持已公开命令表面稳定。
- `stage2`：即使调查更深的自托管路径，也必须保留回退到最后一个可工作 `stage0`
  命令入口的能力。

阶段升级可以改变内部所有权，但不能把已经对外承诺的最小命令行行为再次变成
隐式约定。

## 这个驱动入口不是什么

第一阶段明确不把 `stage0` 驱动入口写成以下东西：

- 不是包管理器入口。
- 不是格式化工具、LSP 或 IDE 集成点。
- 不是独立 installer / channel manager 产品壳。
- 不是跨平台矩阵控制器。
- 不是立即支持多子命令的大而全 CLI。
- 不是绕开 `harness` 与目标规格的临时 shell 包装器。

第一阶段要得到的是“可编译、可调用、可留证的 `stage0` 构建入口”，而不是一个
接口过宽、边界过松的命令行愿景。
