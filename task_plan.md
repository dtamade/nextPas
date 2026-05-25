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

## Addendum: 2026-05-25 Batch 60 Package Lock Snapshot Consistency

### Goal

把 Batch 59 已公开的 `[[snapshot]]` skeleton 从“字段可见”推进到“最小一致性可信”：
`nextpas.lock` 仍然只读，但 snapshot replay shape 不能再声明一个 lock entries 中不存在的
selection。

本批次新增并冻结：

- `package.lock.snapshot-selection-unmatched`
- `stage0PkgPlanLockSnapshotInvalidCheck`
- `tests/fixtures/package_lock_snapshot_invalid`

### Architecture Decision

本批次仍只在 lockfile v1 parser 内做 read-only validation：

- snapshot `selection` 必须匹配某个 `[[package]] name/version` 组合，即 `name@version`
- snapshot `digest` 目前只接受 `sha256:` scheme；空 digest 仍沿用 Batch 59 的 missing issue
- 同一 lockfile 内重复 snapshot target 会被标成 invalid issue
- 所有问题都进入 `package-lock-status=invalid` 与 `package-lock-invalid` preflight blocker
- 不做 resolver、version solving、target selection、fetch/install 或 lockfile write

### Status

Completed

### Planned Steps

- [x] RED：新增 snapshot invalid fixture 与 `stage0PkgPlanLockSnapshotInvalidCheck`
- [x] 实现 snapshot selection / digest / target 的最小 parser-side consistency validation
- [x] GREEN：focused fresh `bash build/verify_local.sh` 确认新增 gate 通过
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 必须先失败在
  `missing-stage0-pkg-plan-lock-snapshot-invalid-lock-status`
- GREEN: `tests/fixtures/package_lock_snapshot_invalid` 必须投影
  `package.lock.snapshot-selection-unmatched`，并停在 `package-lock-invalid`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockSnapshotInvalidCheck=pass`

### Non-goals

- 不做 dependency resolver 或 version solving
- 不选择或执行 target snapshot
- 不联网，不 fetch，不 install
- 不写入、重写或 migrate `nextpas.lock`

## Addendum: 2026-05-25 Batch 59 Package Lock Snapshot Skeleton

### Goal

把 `nextpas.lock` 的只读 detail 从 package entries 继续推进到最小 resolver snapshot
skeleton，让 CLI / IDE / automation 能看到 target-sensitive replay shape 的第一层事实，
但仍不执行 resolver、version solving、fetch/install 或 lockfile write：

- `package-lock-snapshot-count`
- `package-lock-snapshots`
- envelope `packageLockSnapshotCount`
- envelope `packageLockSnapshots`

### Architecture Decision

本批次只扩展 lockfile v1 的只读 parser 和 projection：

- `[[snapshot]]` 是 resolver snapshot 的最小可解释骨架，当前只读取
  `target`、`provenance`、`digest` 与 `selection`
- snapshot detail 只进入 package lock truth，不改变 install-plan preflight 的 ready /
  blocked / missing 判定
- 缺少 snapshot 的现有 v1 lockfile 仍然合法；有 `[[snapshot]]` 但缺必需字段时才进入
  `package-lock-invalid`
- `pkg inspect`、`pkg plan`、`pkg graph` 与 `doctor` 继续消费同一份
  `TPackageWorkflowTruth`

### Status

Completed

### Planned Steps

- [x] RED：扩展 `stage0PkgLockSnapshotCheck`，要求 lock snapshot count/detail line 与 envelope
- [x] 扩展 `np_package_lock.pas` 只读解析 `[[snapshot]]`
- [x] 扩展 package workflow truth 与 stage0 text/json projection
- [x] GREEN：focused rerun 确认 lock detail fixture 输出 snapshot，且现有 ready path 不被阻塞
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 必须先失败在缺少
  `package-lock-snapshot-count` / `package-lock-snapshots`
- GREEN: `tests/fixtures/package_lock_detail` 必须投影一个
  `target=linux-x86_64` 的 snapshot detail
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgLockSnapshotCheck=pass`

### Non-goals

- 不做 dependency resolver 或 version solving
- 不联网，不 fetch，不 install
- 不写入、重写或 migrate `nextpas.lock`
- 不把 snapshot skeleton 扩成完整 lock writer grammar

## Addendum: 2026-05-25 Batch 58 Manifest-Lock Mismatch Detail

### Goal

把 `package-lock-out-of-sync` 从一个裸 blocker 推进到可解释的 preflight detail：`pkg plan`
在 manifest package identity 与 lock entries 不一致时，必须同时公开 manifest 期望的
package name/version，以及当前 lockfile 实际 entries。

### Architecture Decision

本批次仍然只做 read-only preflight detail：

- `TPackageInstallPlanTruth` 在 out-of-sync blocker 上携带 expected package identity 与 lock entries
- stage0 line output 新增
  `package-install-plan-blocker-expected-package` 与
  `package-install-plan-blocker-lock-entries`
- command envelope 新增
  `packageInstallPlanBlockerExpectedPackage` 与
  `packageInstallPlanBlockerLockEntries`
- ready path 不输出 blocker detail，避免调用方把空 detail 误解成真实阻塞
- 不做 resolver、version solving、lockfile writer、lockfile rewrite 或 install mutation

### Status

Completed

### Planned Steps

- [x] RED：扩展 `stage0PkgPlanLockOutOfSyncCheck`，要求 expected package 与 lock entries detail
- [x] 在 install-plan truth 中携带 out-of-sync blocker detail
- [x] 扩展 stage0 text/json projection
- [x] focused GREEN：确认 out-of-sync path 有 detail，ready path 不带 blocker detail
- [x] 同步 package workflow / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused probe 确认旧输出没有
  `package-install-plan-blocker-expected-package` /
  `package-install-plan-blocker-lock-entries`
- GREEN: focused probe 确认 out-of-sync fixture 输出 expected manifest identity 与 actual lock entries，
  且 ready fixture 不输出 blocker detail
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockOutOfSyncCheck=pass`

### Non-goals

- 不做 resolver 或 version solving
- 不写入或重写 `nextpas.lock`
- 不把 lockfile skeleton 扩展成完整 target snapshot grammar

## Addendum: 2026-05-25 Batch 57 Manifest-Lock Consistency Preflight

### Goal

把 `pkg plan` 的 lockfile preflight 从“lockfile 可解析”继续推进到“manifest 与 lock 的最小
identity 一致”：当 `nextpas.package.toml` 声明的 package name/version 在 canonical
`nextpas.lock` entries 中找不到同名同版本 package 时，`pkg plan` 必须停在明确的
`package-lock-out-of-sync` blocker。

### Architecture Decision

本批次仍然只做 read-only preflight：

- `TPackageManifestInfo` 开始保存 `[package].version`，并通过 `WorkspaceModel` 传给
  `TPackageWorkflowTruth`
- `BuildPackageInstallPlanTruth` 在 lock status 为 `ready` 后检查 manifest package
  name/version 是否存在于 lock entries
- install-plan blocker 顺序更新为 manifest missing -> dependency invalid -> source roots missing ->
  lock invalid -> lock missing -> lock out of sync -> ready
- 不做 dependency resolution、version solving、lockfile writer、lockfile rewrite 或 install mutation

### Status

Completed

### Planned Steps

- [x] 新增 out-of-sync lock fixture，并把 ready lock fixtures 调整为当前 package identity
- [x] 新增 `stage0PkgPlanLockOutOfSyncCheck`，冻结 `package-lock-out-of-sync` blocker
- [x] 将 package manifest version 纳入 manifest/workspace/workflow truth
- [x] 在 install-plan preflight 中加入 manifest-lock identity match
- [x] 同步 package workflow / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused probe 确认 out-of-sync fixture 在实现前仍被误报为
  `package-install-plan-status=ready`
- GREEN: focused probe 确认 out-of-sync fixture 投影
  `package-install-plan-status=blocked` 与
  `package-install-plan-blocker-code=package-lock-out-of-sync`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockOutOfSyncCheck=pass`

### Non-goals

- 不做 resolver 或 version solving
- 不写入或重写 `nextpas.lock`
- 不把 lockfile skeleton 扩展成完整 target snapshot grammar

## Addendum: 2026-05-25 Batch 56 Package Lockfile v1 Read-only Detail

### Goal

把 canonical `nextpas.lock` 从“存在即 ready”的布尔事实推进到最小 v1 只读 detail：
CLI / IDE / automation 应能直接看到 lockfile format version、package entries 与 validation
issues，并且 `pkg plan` 在 lockfile 无效时必须停在明确的 `package-lock-invalid` blocker。

### Architecture Decision

本批次新增 `compiler/frontend/np_package_lock.pas`，但仍保持 read-only boundary：

- 当前只读取最小 TOML v1：`[lockfile] format-version = 1` 与 `[[package]] name/version`
- `package-lock-status` 扩展为 `missing|ready|invalid`
- install-plan blocker 顺序更新为 manifest missing -> dependency invalid -> source roots missing ->
  lock invalid -> lock missing -> ready
- 不做 resolver、fetch/install、publish、lockfile writer 或 lockfile mutation

### Status

Completed

### Planned Steps

- [x] 新增 lock detail / invalid lock fixtures，并把既有 ready lock fixtures 升级为最小 v1 TOML
- [x] 新增 `np_package_lock` 只读 parser 与 validation issue model
- [x] 扩展 package workflow truth、line output 与 command envelope 的 lock detail 投影
- [x] 扩展 `build/verify_local.sh`，覆盖 lock detail ready path 与 invalid-lock blocked plan path
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh `bash build/verify_local.sh` 先失败在
  `missing-stage0-pkg-lock-detail-format-version`
- GREEN: fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgLockDetailCheck=pass`、
  `stage0PkgPlanLockInvalidCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不写入或重写 `nextpas.lock`
- 不把最小 v1 skeleton 扩展成完整 resolver snapshot grammar

## Addendum: 2026-05-25 Batch 55 Package Plan Blocker Matrix Gates

### Goal

把 `nextpas pkg plan` 的 install-plan preflight 从“三态已公开”继续推进到“关键 blocker
原因全覆盖”：同一条 `pkg plan` 专用只读面必须覆盖当前 `TPackageWorkflowTruth` 已经拥有的
四类终止原因，避免 CLI / IDE / automation 在 blocked 场景里还要绕回 `pkg inspect` 推断。

### Architecture Decision

本批次仍不新增 resolver、fetch、install 或第二套 planner。`pkg plan` 继续复用
`WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`；这轮只把剩余 blocker 纳入
promotion gate：

- malformed dependency fixture 必须投影 `blocked` 与 `package-dependencies-invalid`
- manifest / lock ready 但无 source roots 的 fixture 必须投影 `blocked` 与
  `package-source-roots-missing`

### Status

Completed

### Planned Steps

- [x] 新增 `package_manifest_no_source_roots` fixture，冻结 manifest / lock ready 但 source roots
      为空的 package truth
- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` dependency-invalid 与 source-roots-missing
      blocked 命令结果
- [x] 同步 tools README、package workflow / developer tooling spec、rolling roadmap 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认
  `stage0PkgPlanDependencyBlockedCheck=pass`、
  `stage0PkgPlanSourceRootsBlockedCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 install plan blocker 顺序
- 不改 lockfile write path

## Addendum: 2026-05-25 Batch 54 Package Plan Blocked/Missing Gates

### Goal

把 `nextpas pkg plan` 从只验证 ready path 推进到完整 preflight 状态边界：同一条公开面必须
直接覆盖 `ready`、`blocked` 与 `missing`，让 CLI / IDE / automation 不需要从
`pkg inspect` 或 `doctor` 间接推断 install plan 为什么不能继续。

### Architecture Decision

本批次不新增第二套 plan logic。`pkg plan` 继续复用 `WorkspaceModel` +
`TPackageManifestInfo` + `TPackageWorkflowTruth`；这轮只把现有 truth 的 blocked / missing
行为纳入 promotion gate：

- workspace member fixture 缺 canonical lockfile 时必须投影 `blocked` 与
  `package-lock-missing`
- package-free workspace 必须投影 `missing` 与 `package-manifest-missing`

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` blocked 与 missing 正向命令结果
- [x] 同步 tools README、package workflow / developer tooling / stage0 README 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgPlanBlockedCheck=pass`、
  `stage0PkgPlanMissingCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不新增 install planner；只冻结现有 preflight truth 的状态边界

## Addendum: 2026-05-25 Batch 53 Package Plan Read-only Surface

### Goal

把 package workflow 的 install plan preflight truth 公开成真实 `nextpas pkg plan` 面，
让 CLI / IDE / automation 直接消费 workspace-model-backed package install-plan truth，
而不是继续只在 `doctor` / `pkg inspect` 里间接看到它。

### Architecture Decision

`pkg plan` 只做 read-only projection，直接复用 `WorkspaceModel` + `TPackageManifestInfo` +
`TPackageWorkflowTruth`，不碰 resolver、fetch、install 或 lockfile write。install plan 语义
仍然维持 Batch 48 冻结下来的 `ready|blocked|missing` preflight truth；`pkg plan` 只是把同一份
truth 公开成一个专用只读面，而不是第二套 install planner。

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` 正向样本与负向参数 gate
- [x] 同步 stage0 / developer tooling / package workflow / stage0 driver 文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgPlanCheck=pass`、
  `stage0PkgPlanInvalidArgumentsCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不引入第二套 package install plan truth

## Addendum: 2026-05-25 Batch 52 Package Graph Read-only Surface

### Goal

把 package workflow 的只读 graph surface 收成真实 `nextpas pkg graph` 公开面，让 CLI / IDE /
automation 直接消费 workspace-model-backed package graph truth，而不是自己重拼 declared
dependency intent。

### Architecture Decision

graph 只做 read-only projection，直接复用 `WorkspaceModel` + `TPackageManifestInfo` +
`TPackageWorkflowTruth`，不碰 resolver、fetch、install 或 lockfile write。图语义固定为
package root node + declared-dependency nodes + `declared-dependency` edges；它只是同一份
package workflow truth 的另一种只读视图，不是第二套 graph engine。

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg graph` 正向样本与负向参数 gate
- [x] 同步 stage0 / developer tooling / package workflow / stage0 driver 文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgGraphCheck=pass`、
  `stage0PkgGraphInvalidArgumentsCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不引入第二套 package graph truth

## Addendum: 2026-05-24 Batch 51 Env Clean Workspace-Local Cache Cleanup

### Goal

把 `env` family 的最小维护面继续收口到 workspace-local cleanup：

- 新增 `nextpas env clean --target linux-x86_64 --workspace <root>`
- `env clean` 只删除 `<workspace>/.nextpas/env/selections/<target>.toml` 与
  `<workspace>/.nextpas/env/resolution/<target>.toml`
- 输出与 `command-envelope=<json>` 必须暴露 cleanup path / status / change /
  removed-count，方便 CLI、IDE 与 automation 判断清理范围

### Architecture Decision

本批次只清理 workspace-local selection / resolution sidecar，不下载、不解包、不安装 runtime SDK，
不改写 workspace descriptor、package manifest、lockfile 或公开 install result。`env clean` 是显式
maintenance surface，不是 `env gc`，也不承诺清掉更广义的 metadata/archive/staging bucket。

### Status

Completed

### Planned Steps

- [x] 确认 `env clean` 只接受 `--target` 与必须的 `--workspace`
- [x] 实现 `env clean` parser、workspace-local selection/resolution 删除与 line / envelope 投影
- [x] 扩展 `build/verify_local.sh`，覆盖首次 removed、二次 unchanged 与 invalid-arguments
- [x] 同步 stage0 / developer tooling / workspace file / distribution specs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env gc`
- 不下载、不解包、不安装 runtime SDK
- 不改写 workspace descriptor、package manifest、lockfile
- 不删除 `units/`、`lib/`、`share/` 或公开 install result

## Addendum: 2026-05-24 Batch 50 Env Sync Workspace Resolution Cache

### Goal

把 `env` family 从 selection mutation 继续推进到第一条 workspace-local sync 闭环：

- 新增 `nextpas env sync --target linux-x86_64 --workspace <root> [--toolchain-binding <id>]`
- `env sync` 在未显式传 `--toolchain-binding` 时读取 Batch 49 的 workspace selection
- 只写 `<workspace>/.nextpas/env/resolution/<target>.toml`，记录当前 resolved binding、distribution、runtime SDK readiness 与 selection 输入
- 公开输出与 `command-envelope=<json>` 必须暴露 resolution path / status / sync delta，方便 CLI、IDE 与 automation 判断本机环境 resolution 是否已经刷新

### Architecture Decision

本批次只 materialize ArtifactRootSet 管辖下的 machine-local environment resolution cache，
不下载、不解包、不安装 runtime SDK，不改写 `env/selections`、`nextpas.workspace.toml`、
`nextpas.package.toml` 或 `nextpas.lock`。`env sync` 是 workspace-local sync surface，
不是 `env bootstrap` 或完整 distribution installer。

### Status

Completed

### Planned Steps

- [x] 确认当前 `env` 已有 `status/use` 和 workspace selection sidecar，但没有 `sync` 入口
- [x] 实现 `env sync` parser、resolution sidecar write、line output 与 command envelope projection
- [x] 扩展 `build/verify_local.sh`，覆盖首次 materialized 与二次 unchanged
- [x] 同步 stage0 / developer tooling / workspace file / distribution specs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env bootstrap`、下载、解包、archive cache、metadata channel resolver 或 runtime SDK 安装
- 不让 `env sync` 改写 selection sidecar；切换 binding 仍由 `env use` 负责
- 不回写 workspace descriptor、package manifest 或 lockfile
- 不让 `build` / `doctor` / `pkg` 在本批次隐式消费 resolution cache

## Addendum: 2026-05-24 Batch 49 Env Use Workspace Selection Sidecar

### Goal

把 `env` family 从纯只读 `status` 推进到第一条真实但最小的 mutation verb：

- 新增 `nextpas env use --target linux-x86_64 --toolchain-binding <id> --workspace <root>`
- `env use` 只写 workspace-local machine state：
  `<workspace>/.nextpas/env/selections/<target>.toml`
- `env status --target <target> --workspace <root>` 在没有显式
  `--toolchain-binding` 时读取该 selection，并继续复用同一份 target / binding /
  distribution / runtime projection
- 公开输出与 `command-envelope=<json>` 必须暴露 selection path / status / target /
  selected binding，方便 CLI、IDE 与 automation 判断当前机器选择

### Architecture Decision

本批次只让 `env use` 改变 ArtifactRootSet 管辖下的 machine-local selection sidecar，不改
`nextpas.workspace.toml`、`nextpas.package.toml`、`nextpas.lock`、target config 或 toolchain
binding config。显式 `--toolchain-binding` 继续高于 selection；`env sync` / `env bootstrap`
仍然不开启下载、解包、runtime SDK materialize 或 install result mutation。

### Status

Completed

### Planned Steps

- [x] 确认当前 `env` 入口只有只读 `status`，且文档已把
      `env/selections` 归入 ArtifactRootSet machine-local sidecar
- [x] 实现 `env use` parser、selection sidecar write，以及
      `env status --workspace` selection read
- [x] 扩展 line-based output、command envelope 与 `build/verify_local.sh` gate
- [x] 同步 stage0 / developer tooling / workspace 文件层文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env sync`、`env bootstrap`、下载、解包或 runtime SDK 安装
- 不让 `build` / `doctor` 在本批次隐式消费 workspace selection
- 不把 active selection 写进 workspace descriptor、package manifest 或 lockfile
- 不新增 channel / distribution resolver；本批次只冻结 preferred binding selection

## Addendum: 2026-05-24 Batch 48 Package Install Plan Preflight Truth

### Goal

把 package workflow 里还停在 `deferred` 的 install plan truth 收成真正可消费的只读预检结果，
让 CLI / automation 能直接判断“现在能不能进入 install plan 生成前置阶段”，而不是只看到一条
没有解释力的占位状态：

- `package-install-plan-status` 继续作为公开 surface，但状态语义改为 `ready|blocked|missing`
- `missing` 只表示 package workflow 本身不可用，或没有可解释的 package truth
- `blocked` 表示 package truth 已存在，但仍有明确阻塞，必要时补 `package-install-plan-blocker-code`
  与 `package-install-plan-blocker-message`
- `ready` 表示 install plan preflight 已满足，仍不代表真正执行 resolver / install / write-back
- `doctor` / `pkg inspect` 继续共享同一份 package workflow truth，不分裂成两套解释

### Architecture Decision

install plan preflight 只负责回答“能否进入下一步”，不提前打开任何 resolver、fetch、install、
lockfile write 或 mutation path。它的状态边界会按 package workflow truth 的现有层级做最小派生：

- manifest 不存在时，install plan 直接 `missing`
- manifest 存在但被 dependency validation、lock presence 或 source-root completeness 阻塞时，install plan
  投影为 `blocked`
- 只有 manifest、lock、dependency 与 source-root 前置条件都满足时，才投影为 `ready`

### Status

Completed

### Planned Steps

- [x] 确认当前 install-plan 投影仍然固定为 `deferred`，并定位相关 truth / projection / verify
      代码路径
- [x] 在 `compiler/frontend/np_package_workflow.pas` 落 install plan preflight truth 与 blocker 详情
- [x] 同步 `tools/stage0` 投影、`tests/toolchain/toolchain_contract_smoke.pas`、`build/verify_local.sh`
      与相关文档
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，最终输出 `verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolver
- 不做 install plan writer
- 不做 lockfile mutation
- 不改 `nextpas.lock` 文件语法或 registry 语义

## Addendum: 2026-05-24 Batch 47 Package Lockfile Presence Truth

### Goal

把 package workflow 里仍然固定为 deferred 的 lock truth 收成真实只读事实：

- `package-lock-status` 继续只读投影 canonical `nextpas.lock` 的存在性
- lockfile 存在时投影 `ready`
- lockfile 不存在时投影 `missing`
- `package-install-plan-status` 继续保持 deferred，本批次不打开 install plan 生成、resolver、
  write-back 或 lockfile mutation
- `doctor` / `pkg inspect` 继续共享同一份 package workflow truth，不再让 lock truth 被固定成
  失真的默认值

### Architecture Decision

lock truth 现在属于 package workflow 的最小可见状态，不再只靠“path 已知但 status deferred”
来表达。我们只读观察 canonical lockfile 是否存在，先让 CLI / automation 能区分“有锁”和“没锁”，
不提前打开真正的 lock write。

### Status

Completed

### Acceptance

- ready package fixture 必须稳定投影 `package-lock-status=ready`
- 没有 lockfile 的 workspace / package root 必须稳定投影 `package-lock-status=missing`
- `command-envelope=<json>.result` 必须同步投影 `packageLockStatus`
- `package-install-plan-status` 仍然保持 deferred
- fresh `bash build/verify_local.sh` 必须通过

### Non-goals

- 不做 lockfile writer
- 不做 dependency resolution
- 不做 install plan generation
- 不改变现有 package manifest / dependency validation grammar

### Planned Steps

- [x] 确认当前 lock truth 与 verify gate 的现状
- [x] 实现 lockfile presence truth 并补 package fixture lockfile
- [x] 同步 verify gate、文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 46 Dependency Requirement Grammar Validation

### Goal

把 Batch 45 已经公开的 declared dependency intent 从“字符串被投影”推进到“格式可信、
违规可解释”的最小 deterministic contract：

- `[dependencies]` 继续只接受 keyed inline table 形状：
  `"package.name" = { version = ">=0.1.0" }`
- dependency requirement string 第一阶段只支持 comparator grammar：`=`、`>`、`>=`、`<`、`<=`
- 多 comparator 用逗号表达 intersection，例如 `>=0.1.0, <0.2.0`
- invalid dependency requirement 不能静默消失；`doctor` / `pkg inspect` 必须能暴露可解释的
  malformed dependency intent
- read-only inspection command 可以继续成功返回，但 package workflow truth 必须把 invalid
  manifest/dependency state 投影给 IDE、CI 与 automation

### Architecture Decision

本批次不打开 resolver。dependency requirement validation 属于 manifest / workflow truth 的输入
可信度边界，先挡住不可信 declaration 进入后续 lock、solver、IDE package view 或 CI automation。

第一阶段明确不支持 union range、feature flag、optional dependency、target-specific dependency
table 或 solver annotation；这些属于 future schema / resolver batch，而不是本批次的 parser
扩张。

### Status

Completed

### Acceptance

- valid examples 必须保留为 declared dependency intent：
  `=0.1.0`、`>0.1.0`、`>=0.1.0`、`<0.2.0`、`<=0.2.0`、
  `>=0.1.0, <0.2.0`
- invalid examples 必须被稳定暴露为 malformed dependency intent，而不是被忽略：
  `^0.1.0`、`~>0.1`、`>=`、`>=0.1.0 || <0.2.0`、empty requirement
- `doctor --workspace` 与 `pkg inspect` 至少一条公开 projection surface 能显示 dependency
  validation status / malformed dependency detail；理想路径是两者共享同一份 package workflow truth
- `build/verify_local.sh` 必须新增 malformed dependency fixture gate，并在最终 envelope 暴露
  对应 check pass 字段
- fresh `bash build/verify_local.sh` 必须通过

### Non-goals

- 不做 dependency resolution、version selection、registry lookup、fetch/install 或 lockfile write
- 不做 semantic version ordering / compatibility solving；本批次只验证 requirement syntax shape
- 不把 target-specific dependency table、optional dependency 或 feature flag 写进当前 grammar
- 不把 diagnostics contract 大重构塞进本批次；只补足本批次需要的 deterministic invalid state

### Planned Steps

- [x] focused probe 当前 parser 对 malformed dependency 的行为，确认 `^0.1.0` 会作为 raw string
      投影且没有 invalid signal
- [x] 设计 manifest/workflow 层的 validation result 承载方式，避免 CLI 两侧各自解析
- [x] 新增 malformed dependency fixture，覆盖 invalid requirement 不静默消失
- [x] 先把 `build/verify_local.sh` gate 写成 RED，冻结 `doctor` / `pkg inspect` 预期
- [x] 实现最小 comparator grammar validation 与 projection
- [x] 同步 stage0 README、workspace/package workflow specs、rolling plan 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 45 Declared Dependencies Projection

### Goal

把 package manifest 的 `[dependencies]` declared intent 接入 shared package workflow truth，并
通过 `doctor --workspace` / `pkg inspect` 做只读投影：

- manifest parser 支持当前规范已冻结的 keyed inline table 形状：
  `"package.name" = { version = ">=0.1.0" }`
- `TPackageManifestInfo`、`TWorkspaceModel.PackageRef` 与 `TPackageManifestTruth` 持有
  declared dependency name / requirement
- line-based output 新增 `package-dependency-count` 与 `package-dependencies=<json-array>`
- `command-envelope=<json>.result` 同步新增 `packageDependencyCount` 与 `packageDependencies`
- non-goal：不做 dependency resolution、solver、fetch/install、lockfile write、target-specific
  dependencies 或 feature flags

### Status

Completed

### Planned Steps

- [x] 确认当前 parser/workflow 只持有 package identity 与 source roots
- [x] 扩展 manifest parser、workspace model 与 workflow truth
- [x] 扩展 package projection text/json 输出
- [x] 加严 `build/verify_local.sh` 的 doctor / pkg inspect declared dependency gate
- [x] 同步必要文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 44 Package Source Roots Projection

### Goal

把 package workflow truth 中已经存在的 `SourceRoots` 从内部事实提升为公开只读投影，避免
IDE、CI 或 automation 只能拿到 `package-source-root-count` 后再回头解析 manifest：

- `pkg inspect` 与 `doctor --workspace` 必须继续复用同一份 `PackageWorkflowTruth`
- line-based output 在 `package-source-root-count` 之外新增
  `package-source-roots=<json-array>`
- `command-envelope=<json>.result` 同步新增 `packageSourceRoots`
- 缺少 package truth 时投影 `package-source-roots=[]`，与
  `package-source-root-count=0` 保持一致
- non-goal：不做 package resolution、fetch、install、lockfile write 或 manifest 格式扩展

### Status

Completed

### Planned Steps

- [x] 扩展 `TPackageProjectionContext`，承载 `SourceRootsJson`
- [x] 在 `CapturePackageProjectionFromWorkflowTruth(...)` 中从
      `ManifestTruth.SourceRoots` 生成 JSON array
- [x] 扩展 line-based output 与 command envelope
- [x] 加严 `build/verify_local.sh` 的 doctor / pkg inspect package roots detail gate
- [x] 同步最小文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 43 Pkg Inspect Workspace Member Contract

### Goal

把 Batch 42 已冻结的 workspace descriptor root + member package ready contract，从 `doctor`
同步扩展到只读 `pkg inspect`：

- `pkg inspect --workspace <workspace descriptor root>` 必须复用 shared `WorkspaceModel` /
  `PackageWorkflowTruth`
- workspace descriptor root 必须稳定解析到 member package manifest
  `app/nextpas.package.toml`
- package workflow 正向字段必须投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 member
  manifest/root/name/lockfile detail fields
- `command-envelope=<json>.result` 必须同步保留 workspace descriptor path 与 member
  package detail fields
- non-goal：不修改 `pkg inspect` 实现、不做 package resolution/fetch/install、不打开
  lockfile write、publish workflow 或 package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/workspace_member_source_root` 下 `pkg inspect` 已经返回
      workspace descriptor + member package ready
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-pkg-workspace-member-check`
- [x] 同步 verify-local success envelope，新增 `stage0PkgWorkspaceMemberCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 42 Doctor Workspace Member Package Contract

### Goal

把 Batch 41 的 ready package workspace gate 从单包 manifest root 扩展到 workspace descriptor
root + member package 的真实形态：

- `doctor --workspace <workspace descriptor root>` 必须复用 shared `WorkspaceModel`
- workspace descriptor root 必须稳定解析到 member package manifest
  `app/nextpas.package.toml`
- package workflow 正向字段必须投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 member
  manifest/root/name/lockfile detail fields
- 正向样本仍可因为当前 runtime SDK 缺失而有 `doctor.runtime-sdk-missing`，但不能出现
  `doctor.package-workspace-missing`
- `command-envelope=<json>.result` 必须同步保留 workspace descriptor path 与 member
  package detail fields
- non-goal：不修改 `doctor` 实现、不做 package resolution/fetch/install、不打开
  `env sync` 或 package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/workspace_member_source_root` 下 `doctor` 已经返回
      workspace descriptor + member package ready，且没有 `doctor.package-workspace-missing`
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-doctor-workspace-member-check`
- [x] 同步 verify-local success envelope，新增 `stage0DoctorWorkspaceMemberCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 41 Doctor Package Workspace Positive Contract

### Goal

把 Batch 40 已接入的 `doctor` package/workspace coherence 从“只冻结缺失路径”推进到
“ready 与 missing 两侧都被 promotion gate 保护”：

- `doctor --workspace <package root>` 必须复用同一份 `WorkspaceModel` / `PackageWorkflowTruth`
- package workspace 正向样本必须稳定投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 manifest/root/name/lockfile
  detail fields
- 正向样本仍可因为当前 runtime SDK 缺失而有 `doctor.runtime-sdk-missing`，但不能出现
  `doctor.package-workspace-missing`
- `command-envelope=<json>.result` 必须同步保留同一批 package detail fields
- non-goal：不修改 `doctor` 实现、不执行 fetch/install/resolution、不进入 `env sync` 或
  package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/package_manifest_source_root` 下 `doctor` 已经返回
      package workflow ready，且没有 `doctor.package-workspace-missing`
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-doctor-package-workspace-check`
- [x] 同步 verify-local success envelope，新增 `stage0DoctorPackageWorkspaceCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 40 Doctor Package/Workspace Coherence

### Goal

把 `doctor` 的只读 health inspection 再往 package/workspace truth 收拢：在有 `--workspace`
时复用 `ResolvePackageInspectionSourcePath(...)` + `ResolveWorkspaceModel(...)`，打印
`PackageProjection`，并在缺少 package workspace truth 时投影
`doctor.package-workspace-missing`；以 repo root 缺少 package descriptor 作为负向样本，
但继续保持 `doctor` 不是 `env sync`、`env use` 或 `env bootstrap`。

- owner 继续是 `tools/stage0/nextpas_command_doctor.pas` 与
  `tools/stage0/nextpas_projection_context.pas`
- truth objects 是 `TEnvironmentProjectionContext`、`TPackageProjectionContext` 与
  `TDoctorProjectionContext`
- line-based output 与 command envelope 同步投影 package workflow truth
- promotion gate 继续落在 `build/verify_local.sh` 的 `stage0-doctor-check`
- non-goal：不把 `doctor` 变成 package manager 执行面，也不修改环境状态

### Status

Completed

### Planned Steps

- [x] 先确认 `doctor` 的 package/workspace coherence 仍然是只读 inspection，而不是执行面
- [x] 在 `tools/stage0/nextpas_command_doctor.pas` 中有 `--workspace` 时复用 package inspection
      source path 与 workspace model，并打印 `PackageProjection`
- [x] 在 `tools/stage0/nextpas_projection_context.pas` 中加入
      `doctor.package-workspace-missing` finding，并把 package workflow truth 纳入 doctor check count
- [x] 扩展 `build/verify_local.sh` 的 `stage0-doctor-check`，冻结 repo root 的 package truth
      缺失边界与 envelope finding
- [x] 同步 `tools/stage0/README.md`、architecture specs、roadmap、`task_plan.md`、
      `progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 39 Query Semantic Graph Side Tables

### Goal

把 `query symbols` 从“每个 symbol 都携带可读 metadata”继续推进到可被 CLI、automation
和 future IDE adapter 直接消费的 normalized semantic graph projection：

- owner 继续是 `TCompilationSession`；`stage0` CLI 不重扫源码、不解析 stdout、不维护第二套
  semantic lookup
- truth objects 是同一份 `TSemanticModel` 的 `TSemanticSymbol`、`TSemanticScope` 与
  `TSemanticType`
- line-based output 在 `query-symbols` 之外新增 `query-scopes=<json-array>` 与
  `query-types=<json-array>`，让 `scopeId` / `typeId` 可以通过同一份 query result 回查
- `command-envelope=<json>.result` 同步新增 `queryScopes` 与 `queryTypes`
- promotion gate 新增 `stage0-query-symbols-semantic-graph-check`，用 `var_halt.pas`
  冻结 unit scope `VarHalt` 与 builtin type `Integer` side table
- non-goal：不新增 LSP / language service session，不做 overlay、incremental invalidation、
  references、rename、completion，也不执行 MIR/backend/toolchain

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-semantic-graph-check` 写成 RED gate
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel` 暴露 `ScopesJson` 与
      `TypesJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `var_halt.pas` 的 scope/type side tables 与 symbol metadata 同步
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 38 Query Symbols Semantic Metadata

### Goal

把 Batch 37 已经公开的 `query-symbols` 从 raw ids 继续推进到可被 CLI、future IDE adapter
和 automation 直接消费的 semantic metadata projection，同时继续守住 query 只读边界：

- owner 继续是 `TCompilationSession`；`stage0` CLI 不从 stdout、源码文本或 build output
  反推 symbol metadata
- truth objects 是同一份 `TSemanticModel` 的 `TSemanticSymbol` / `TSemanticScope` /
  `TSemanticType`，以及同一份 `TUnitGraph` 的 owner unit truth
- `querySymbols[]` 在保留 raw `ownerUnitId`、`scopeId`、`typeId` 的同时，补充
  `ownerUnitName`、`scopeKind`、`scopeName`、`scopeParentId`、`typeName`、`typeKind`
  与 `typeParentId`
- promotion gate 继续落在 `build/verify_local.sh` 的 query check，新增 `var_halt.pas`
  focused probe，冻结变量符号 `x` 的 owner/scope/type metadata
- non-goal：不实现 references、rename、completion、open document overlay、incremental
  invalidation，也不执行 MIR/backend/toolchain

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-semantic-metadata-check` 写成 RED gate
- [x] 在 `TCompilationSession.SymbolsJson` 中从 session-owned model / unit graph 补 semantic metadata
- [x] focused probe 确认 `var_halt.pas` 的变量符号输出 `ownerUnitName`、scope metadata 与 type metadata
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 37 Query Symbols Detail Projection

### Goal

把已经存在的只读 `query symbols` 从“只给 aggregate count”推进到可被 CLI、IDE adapter
和 automation 直接消费的结构化 symbol detail projection，同时继续守住它不是完整
language service / LSP 的边界：

- owner 继续是 `TCompilationSession` / `TSemanticModel`，不在 stage0 CLI 旁路重扫源码或解析输出
- truth object 是当前 semantic symbol graph 中的 `TSemanticSymbol`
- line-based output 必须新增 `query-symbols=<json-array>`，与 `query-result-count` 表达同一批结果
- `command-envelope=<json>.result` 必须新增 `querySymbols`，字段来自同一份 session-owned JSON
- promotion gate 继续落在 `build/verify_local.sh` 的 `stage0-query-symbols-check`
- non-goal：不实现 LSP server、open document overlay、incremental invalidation、references、
  rename preflight、completion 或 backend/toolchain execution

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-check` 写成 RED gate，要求 line/envelope 两层 symbol detail
- [x] 在 `TCompilationSession` 暴露 session-owned `SymbolsJson`
- [x] 扩展 `TQueryProjectionContext`、text/json projection helper 与 `RunQuerySymbols`
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Rolling Plan Batch 36 Truth Sync

### Goal

把当前 rolling plan 的入口状态同步到真实最新基线，避免后续恢复时误以为 production-path
contract 仍停在 `Batch 35`：

- `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 顶部必须写明当前最新完成批次是
  `Batch 36`
- 当前状态段必须把 stage0 driver decomposition、projection ownership、malformed manifest
  fallback、diagnostic record extensibility 与 resolver search-index staleness tracking 写成
  `Batch 36` 已验证 baseline
- `build/verify_local.sh` docs-check 必须要求当前 rolling plan 存在，避免活动主线入口从验证入口漂走
- 同步 `task_plan.md`、`progress.md`、`findings.md`，让下一次“继续”从真实最新批次恢复

### Status

Completed

### Planned Steps

- [x] 同步 rolling plan 顶部状态到 `Batch 36`
- [x] 将 rolling plan 纳入 docs-check
- [x] 同步持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Architecture Principles and Quality Bar

### Goal

把“打造 FreePascal 领域一流现代 Pascal 开发环境”的高阶目标固化为可引用、可验证、
可执行的架构原则，而不是停留在愿景口号：

- 新增 `docs/architecture/architecture-principles-specification.md`，明确正确性、shared truth、
  thin entrypoint、性能前置、可维护性、统一词汇与兼容性诚实这些长期门槛
- 让 `overview.md`、`master-roadmap.md`、仓库 README 与架构目录都把这份规范作为后续设计入口
- 将新规范纳入 `build/verify_local.sh` 的 docs-check，避免架构质量门槛从仓库验证入口漂走
- 同步 `task_plan.md`、`progress.md`、`findings.md`，让后续“继续”能直接沿该质量门槛推进

### Status

Completed

### Completed Steps

- [x] 新增 `docs/architecture/architecture-principles-specification.md`
- [x] 同步 README、架构目录、总览、主路线图与 docs-check
- [x] 同步 `task_plan.md`、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`，确认新规范进入 docs-check 且整套
      `verify-local=pass`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 `pkg inspect` package workflow detail hardening

### Goal

把已经存在的 package workflow truth 从 aggregate status 继续推进到可消费的只读细节投影，
同时继续守住 non-executing package manager 边界：

- `pkg inspect` 必须继续复用 `WorkspaceModel` / `PackageWorkflowTruth`，不执行 fetch、install、
  dependency resolution、lockfile write 或 publish workflow
- line-based output 必须冻结 workflow-owned manifest path、package root、package name、
  lock status 与 canonical lockfile path
- `command-envelope=<json>.result` 必须同步带上 `packageWorkflowManifestPath`、
  `packageRootPath`、`packageName`、`packageLockStatus` 与 `packageLockfilePath`
- `build/verify_local.sh` 必须把这批 detail fields 纳入 `stage0-pkg-inspect-check`

### Status

Completed

### Completed Steps

- [x] 扩展 `tools/stage0/nextpas_projection_text.pas`，新增
      `package-workflow-manifest-path`
- [x] 扩展 `tools/stage0/nextpas_projection_json.pas`，新增
      `packageWorkflowManifestPath`
- [x] 加严 `build/verify_local.sh` 的 `stage0-pkg-inspect-check`，冻结
      manifest path、package root、package name、lock status 与 lockfile path 的 line/envelope
      contract
- [x] 同步回写 `tools/stage0/README.md`、package workflow / roadmap docs 与持续记录
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Installed-source Extra Assemble Boundary Closure

### Goal

把这轮 Stage2 / semantic smoke follow-up 从“linked root 缺少 source-backed unit `.o`”和
“unit root 被误扩成 transitive extra assemble”两侧一起收口，形成更诚实的最小边界：

- `compiler/diagnostics/np_diagnostics_sink.pas` 必须能稳定解析同目录
  `nextpas_json_helpers`，不再依赖偶然 search path
- `units/linux-x86_64/SysUtils.pas` 必须补齐当前 compiler path 真实需要的
  `IntToHex(Value: Int64; Digits: Integer)`
- `compiler/frontend/np_compilation_session.pas` 的
  `CollectAdditionalAssemblyBaseNames()` 必须只在 `program|library|package` 这类 linked root
  上收集额外 assemble base name，并允许 `installed-source` units 进入集合
- `unit` root 必须继续停留在 `host-fpc-emit-asm -> native-assemble`，不能为 transitive deps
  伪造 extra assemble steps
- `build/verify_local.sh` 必须把 `hello_with_units` 的 semantic-smoke reality 冻结为
  `typed-hir-node-count=8`、`tool-invocation-count=5`、`tool-run-step-count=5`、
  `tool-status-event-count=16`

### Status

Completed

### Completed Steps

- [x] 先复现 `hello_with_units` link failure，确认真实缺口是
      `Stage0Greeter.o` / `Stage0GreeterImpl.o` 没有物化，而不是 link command 本身错误
- [x] 在 `compiler/diagnostics/np_diagnostics_sink.pas` 补上 `{$UNITPATH .}`，让同目录
      `nextpas_json_helpers` 成为明确依赖
- [x] 在 `units/linux-x86_64/SysUtils.pas` 补上
      `IntToHex(Value: Int64; Digits: Integer)`，消除当前 compiler/self-host path 的 RTL 缺口
- [x] 调整 `CollectAdditionalAssemblyBaseNames()`：
      `unit` root 直接返回空集合；linked root 只跳过 `implicit-runtime`，不再错误排除
      `installed-source`
- [x] 回写 `build/verify_local.sh` 的 semantic-smoke contract，固定
      `hello_with_units` 为 5-step / 16-event，并把 `typedHirNodeCount` 改回真实 `8`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Stage2 Self-compile Coverage Parity

### Goal

把 Stage2 compiler-module self-compile 的记录与 promotion path 对齐：上一批 notes 已经把
`np_workspace_model` 写成 fresh 成功，但 `build/verify_local.sh` 只 gate 了
`np_diagnostics_sink` 与 `np_source_database`。这批不扩大 self-hosting 语义，只把已经成立的
`np_workspace_model` unit-root object-file contract 固化进 verify。

### Status

Completed

### Completed Steps

- [x] 核对当前记录与 `build/verify_local.sh`，确认 drift 只在
      `np_workspace_model` 是否进入 promotion path
- [x] 在 `build/verify_local.sh` 增加
      `compiler/frontend/np_workspace_model.pas` self-compile probe
- [x] 复用 unit-root contract：`backend-output-kind=object-file`、
      `toolchain-plan-family=bootstrap-native-assemble`、
      `logical-link-request-status=deferred`
- [x] 额外冻结 `tool-invocation-count=2` / `tool-run-step-count=2` 与 no-`native-link`，
      防止 unit root 漂回 transitive extra assemble 或 link
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Stage2 unit self-compile boundary

### Goal

把 Stage2 自编译从“卡在 target-installed `SysUtils` parser failure”和“把 `unit` 误当成
`executable` 去 link”的混合失败，收口成一个真实、可验证、可持续的最小成功边界：

- target-installed / compiler source 里的 `= class(Exception);` shorthand 改成 parser 已稳定支持的
  `class(Exception) ... end;`
- `compiler/backend/np_backend_plan.pas` 改为按 root kind 区分输出：
  `program|library|package -> executable`，`unit -> object-file`
- `compiler/toolchain/np_toolchain_plan.pas` 为 unit roots 走
  `bootstrap-native-assemble`（`host-fpc-emit-asm -> native-assemble`），不再伪造
  `native-link`
- `build/verify_local.sh` 纳入 compiler-module self-compile gate，冻结
  `np_diagnostics_sink`、`np_source_database` 与 `np_workspace_model` 的 object-file self-host
  contract

### Status

Completed

### Completed Steps

- [x] 重现并定位 `parser.syntax-error: "IMPLEMENTATION" expected but "END" found`
      到 `SysUtils` / compiler units 中的 `class(Exception);` shorthand
- [x] 将 `SysUtils`、compiler/toolchain/frontend 相关 unit 里的 shorthand class 统一改为
      显式空 body 形式
- [x] 让 backend plan 按 root kind 选择 `object-file` / `executable`
- [x] 让 toolchain plan 为 unit roots 选择 `bootstrap-native-assemble`
- [x] 移除遗留 `DBG-FALL:` stderr 调试输出
- [x] `build/verify_local.sh` 新增 compiler-module self-compile gate
- [x] fresh `bash build/verify_local.sh` 通过，确认 `verify-local=pass`

### Notes

- 这批不是宣称 nextPas 已经能把 compiler units “完整链接成可执行”，而是把当前真实 ownership
  诚实地推进到“能把 compiler units 编译成 object-file 并经过 native assemble”
- `np_diagnostics_sink` / `np_source_database` / `np_workspace_model` 现在都已在
  `backend-output-kind=object-file`、`toolchain-plan-family=bootstrap-native-assemble` 下进入
  fresh verify gate
- `array of const` 这一合法参数形态已补入 parser，并在 `TSemanticAnalyzer.GetParamSignature(...)`
  里补了 nil guard；`tests/parser/array_of_const_pass.pas` 已加入 parser smoke，fresh verify 通过

## Addendum: 2026-05-23 HIR LLVM alloca hoisting safety

### Goal

把 HIR LLVM emitter 的 SSA 命名从匿名数值寄存器切到稳定 named values，并让
`THIRBuilder.EnsureAlloca(...)` 真正写入函数 entry block。这样晚到的 slot materialization
不再受 LLVM 文本 IR 顺序编号约束，也不会再依赖 emitter 按 `ResultId` 重新排序 block。

- 修改 `compiler/ir/np_hir_builder.pas`：`EnsureAlloca(...)` 在函数上下文中直接调用
  `FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)`，把 fallback alloca hoist 到 entry block
- 修改 `compiler/ir/np_hir_llvm_emitter.pas`：新增 `ValueRef(...)`，把 raw `%` + 数值引用统一发射为
  `%vN` named SSA values（覆盖定义、使用与 function params）
- 去掉 `EmitFunction(...)` 中按首个 `ResultId` 重新排序 block 的 hack，恢复按 HIR block 原始顺序发射
- 新增 `tests/hir/test_hir_late_alloca_hoist.pas` focused probe：构造“非 entry block 首次 materialize
  late slot” 的 synthetic HIR，断言生成 IR 既能过 `opt` 解析，又把 `alloca` 放在 entry block
- 扩展 `build/verify_local.sh`：正式纳入上述 focused probe，并冻结 `%vN` named-value evidence

### Status

Completed

### Completed Steps

- [x] `THIRBuilder.EnsureAlloca(...)` 改为 entry-block insertion
- [x] `THIRLlvmEmitter` 新增 `ValueRef(...)` 并切换 raw numeric SSA refs 到 `%vN`
- [x] `EmitFunction(...)` 改为按 HIR block 原始顺序发射，不再按 `ResultId` 排序
- [x] 新增 `tests/hir/test_hir_late_alloca_hoist.pas`
- [x] `build/verify_local.sh` 纳入 focused hoist gate，并用 `opt -disable-output` 验证 IR
- [x] fresh `bash build/verify_local.sh` 通过，确认 LLVM/host 路径无回退

### Notes

- 这批不是扩 LLVM 语义面，而是把既有 HIR path 的文本 IR 稳定性补齐，为后续更多 late alloca /
  synthetic slot 场景扫掉结构性约束
- `%arralloc.*`、`%abs.*`、`%is.*`、`%callstr.*` 这类已有显式命名 helper SSA 名继续保留；
  变化的是原先裸 `%1/%2/...` 的 result / operand / param 引用现在统一成为 `%vN`

## Addendum: 2026-05-17 Sema Const Identifier Resolution — Halt(MyConst) → exit(42)

### Goal

把 sema 折叠器从"只折常量字面量表达式"推进到"能解析 const 声明的标识符引用"。
上一批次让 `Halt(40 + 2)` 折叠为 42；这一批让 `const FortyTwo = 42; begin Halt(FortyTwo); end.`
也能正确退出 42。

- 扩展 `compiler/sema/np_semantic_model.pas` 加 `TSemanticConstValue` record 与
  `FConstValues: array of TSemanticConstValue`；新增 `AddConstValue(name, value)` 与
  `LookupConstValue(name, out value): Boolean`
- 扩展 `EvaluateIntegerConstant` 加 `gnkIdentifier` 分支：从 `FModel.LookupConstValue`
  查表，命中即返回常量值
- 改造 `ProcessConstSection`：每个 `gnkConstDecl` 子节点尝试 `EvaluateIntegerConstant`
  折叠值，命中即 `AddConstValue(name, value)` 注册到表
- 新增 `examples/smoke/halt_const.pas`：`program HaltConst; const FortyTwo = 42; begin Halt(FortyTwo); end.`
- 新增 `build/verify_local.sh` 的 `llvm-halt-const-program` gate：用真 opt/llc/ld 编译
  halt_const.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] sema model 加 `TSemanticConstValue` 与 `FConstValues` 数组，constructor 初始化
- [x] sema model 加 `AddConstValue` / `LookupConstValue`（大小写不敏感名称比对，重复 name 覆盖旧值）
- [x] `EvaluateIntegerConstant` 新增 `gnkIdentifier` case，从 `LookupConstValue` 查表
- [x] `ProcessConstSection` 遍历每个 `gnkConstDecl` 子节点尝试折叠并 `AddConstValue` 注册
- [x] 新增 `examples/smoke/halt_const.pas` fixture
- [x] `build/verify_local.sh` 加 `LLVM_HALT_CONST_PROGRAM_OUTPUT` /
      `LLVM_HALT_CONST_PROGRAM_OUT_DIR` 临时文件，新增 `llvm-halt-const-program` gate，
      success envelope 加 `llvmHaltConstProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| const 表用大小写不敏感名称比对 | Pascal 标识符传统大小写不敏感；与 `WalkHaltCalls` 的 `SameText('Halt')` 一致 |
| ProcessConstSection 折叠失败时只跳过 AddConstValue，不报诊断 | const 声明可能是非整数（字符串、记录），折叠失败不代表错；当前批次只关心整数常量；非整数 const 引用在 EvaluateIntegerConstant 自动失败回到 fallback |
| const 表挂在 `TSemanticModel` 而不是 `TSemanticAnalyzer` | 与现有 `FSymbols` / `FTypes` 等 model-owned 数据保持一致；分析器只负责填充，model 持有真实数据 |
| 重复名称覆盖而不是报错 | 当前 sema 还没有完整 redeclaration 检查；先静默覆盖避免假诊断，等真正的 symbol-redecl 检查批次再加 |

### Notes

- 这是 sema 第一次跨节点引用解析：表达式折叠器从纯 AST-recursive 升级到 model-aware
- 当前 const 表只支持整数类型；string / 浮点 / 数组 const 值仍属未来批次
- `verify-local` 现在含四条 LLVM 端到端 gate：`llvmEmptyProgram`（exit 0）、
  `llvmHaltProgram`（exit 42 from literal）、`llvmHaltExprProgram`（exit 42 from 40+2）、
  `llvmHaltConstProgram`（exit 42 from const FortyTwo = 42）

## Addendum: 2026-05-17 Sema Integer Constant Folding — Halt(40 + 2) → exit(42)

### Goal

把 nextPas 的 sema 从"只接受 Halt 直接字面量参数"推进到"折叠任意整数常量表达式"。
上一批次 `Halt(N)` 走 LLVM 退出 N，但 `Halt(40 + 2)` 会因 sema 仅匹配 `gnkIntegerLiteral`
直接子节点而退化到默认 0。这一批让 sema 在编译期完成整数常量折叠，
让 `Halt(N op M)` / `Halt(-N)` 等表达式也能正确决定退出码。

- 扩展 `compiler/sema/np_semantic_analyzer.pas` 新增 `EvaluateIntegerConstant(Node, out Value)`：
  递归折叠 `gnkIntegerLiteral` / `gnkUnaryExpression`(+/-) /
  `gnkBinaryExpression`(+/-/*/div/mod)；除零返回 false；非整数节点或未识别 op 返回 false
- 改造 `WalkHaltCalls`：把"只匹配 `gnkIntegerLiteral`"换成 `EvaluateIntegerConstant`，
  折叠成功才发射 `halt-call` HIR 节点；失败时 operand 默认 `0`
- 新增 `examples/smoke/halt_expr.pas`：`program HaltExpr; begin Halt(40 + 2); end.`
- 新增 `build/verify_local.sh` 的 `llvm-halt-expr-program` gate：用真 opt/llc/ld 编译
  halt_expr.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] sema 加 `EvaluateIntegerConstant` 折叠器（unary +/-、binary +/-/*/div/mod、字面量）
- [x] `WalkHaltCalls` 改用 `EvaluateIntegerConstant` 替代直接 `gnkIntegerLiteral` 匹配
- [x] 新增 `examples/smoke/halt_expr.pas` fixture
- [x] `build/verify_local.sh` 加 `LLVM_HALT_EXPR_PROGRAM_OUTPUT` /
      `LLVM_HALT_EXPR_PROGRAM_OUT_DIR` 临时文件，新增 `llvm-halt-expr-program` gate，
      success envelope 加 `llvmHaltExprProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| 折叠器在 sema 层而非 MIR lowerer | 折叠产生的整数常量需要进 HIR 的 `Operand` 字段以传给 MIR；MIR lowerer 只读 HIR 操作数；当前没有 typed value system，sema 是唯一能消费 AST 表达式形态的层 |
| 用 `Int64` 内部计算 | 避免 Pascal 整数子集分歧；Halt 退出码最终被截到 8 位（POSIX `_exit` 语义），但中间表达式可以触及 64 位范围 |
| 折叠失败默认 0，不发诊断 | 当前批次专注 Halt 表达式折叠路径；非常量表达式（变量、未支持运算）应进入下一批的真实 codegen，不该在此批次假装"已支持但 silently 错"。先静默 fallback、保留 0 行为，等 typed expression codegen 落地再加诊断 |
| 折叠器涵盖 +/-/*/div/mod 而非仅 +/- | 这五个 op 是 Pascal 整数常量表达式核心子集；新增成本 ~每 op 5 行，但避免下次再来一批 "MUL 折叠" |

### Notes

- 这是 sema 第一次具备**编译期求值**能力。不是完整 const-eval 系统，但已经能把
  `Halt(40 + 2)` 这类整数常量表达式正确折叠到运行时退出码
- 当前 emitter 仍只看 MIR `halt` op 的 operand 字段；变量、函数返回值、
  字符串等非常量参数仍属下一批次（需要真实 LLVM 表达式 codegen）
- `verify-local` 现在含三条 LLVM 端到端 gate：`llvmEmptyProgram`（exit 0）、
  `llvmHaltProgram`（exit 42 from literal）、`llvmHaltExprProgram`（exit 42 from 40+2）

## Addendum: 2026-05-17 MIR-driven LLVM Codegen — Halt(N) → exit(N)

### Goal

把 nextPas 的 LLVM 路径从"无论源代码写什么都 exit 0"推进到"程序退出码由源代码决定"。
这是首个 **MIR 真实决定运行时行为** 的批次：MIR operand 不再恒为空字符串，
LLVM emitter 不再发射固定 empty shell。

- 扩展 `compiler/ir/np_mir_model.pas` 的 `TMirOperation` 加 `Operand: string` 字段，
  `AddOperation` 多一个 operand 参数，新增 `OperationAt(Index)` 让 emitter 能读取 ops
- 扩展 `compiler/sema/np_semantic_model.pas` 的 `TTypedHirNode` 同样加 `Operand: string`
  字段，`AddTypedHirNode` 多一个 operand 参数
- 扩展 `compiler/sema/np_semantic_analyzer.pas` 新增 `WalkHaltCalls` + `SeedHaltCalls`：
  遍历 program body 找 `gnkProcedureCallStatement` 文本为 `Halt`，捕获第一个
  `gnkIntegerLiteral` 子节点作为 operand，发射 `halt-call` HIR 节点
- 扩展 `TMirLowerer.MirKindForTypedHirNode` 把 `halt-call` HIR 翻译为 `halt` MIR op，
  operand 透传
- 扩展 `compiler/backend/np_llvm_emitter.pas`：扫 MIR ops 找 `halt` 提取 operand（默认 0），
  发射 `_start` 时把 syscall arg 写为该 operand 值；emitter 不再写死 `xorl %edi, %edi`
- 新增 `examples/smoke/halt_42.pas` fixture：`program HaltFortyTwo; begin Halt(42); end.`
- 修复 `tests/toolchain/toolchain_contract_smoke.pas` 的 `MirModel.AddOperation` 调用
  对齐新签名
- 新增 `build/verify_local.sh` 的 `llvm-halt-program` gate：用真 opt/llc/ld 编译
  halt_42.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] `TMirOperation` + `AddOperation` 加 Operand 字段，新增 `OperationAt(Index)` accessor
- [x] `TTypedHirNode` + `AddTypedHirNode` 加 Operand 字段；6 处现有调用点全部跟进
- [x] `TSemanticAnalyzer` 新增 `WalkHaltCalls` + `SeedHaltCalls`，挂进 `Analyze`
      末尾在 `SeedRuntimeContracts` 之后
- [x] `TMirLowerer.MirKindForTypedHirNode` 加 `halt-call -> halt` 分支；
      lowerer 主循环把 HIR operand 透传给 MIR `AddOperation`
- [x] `TLlvmEmitter.ResolveExitCode` 扫 MIR ops 找 `halt`，从 operand 解析整数
      （Val 解析失败默认 0）；`EmitToFile` 发射 syscall arg 为该值
- [x] 新增 `examples/smoke/halt_42.pas`
- [x] 修复 `tests/toolchain/toolchain_contract_smoke.pas:536` 的 `AddOperation` 4 参签名
- [x] `build/verify_local.sh` 加 `LLVM_HALT_PROGRAM_OUTPUT` / `LLVM_HALT_PROGRAM_OUT_DIR`
      临时文件，新增 `llvm-halt-program` gate（IR 含 marker、可执行 exit 42），
      success envelope 加 `llvmHaltProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| 用 `string` 字段载 operand，而不是引入 typed `TMirValue` 联合体 | 当前只需透传字面量给 emitter；引入 value system 会牵动 MIR/HIR/sema/emitter 四层，扩展面太大；string 可后续被 typed value 替换而不破坏调用接口 |
| `halt-call` HIR 节点直接挂在 typed-hir 序列尾部，不进 block-structured CFG | 当前 MIR 仍是平铺 op 序列、单 entry block；引入 control-flow 应单独批次 |
| emitter `ResolveExitCode` 解析失败默认 0，不报 diagnostic | sema 已经只在捕获到 `gnkIntegerLiteral` 时才发 operand，emitter 收到非数字 operand 是内部 bug 不是用户错误；先静默 fallback，等 typed value 再加诊断 |
| `WalkHaltCalls` 做大小写不敏感比对（`SameText`） | Pascal 标识符传统大小写不敏感；与 `gnkProcedureCallStatement.Text` 保留原 lexeme 一致 |

### Notes

- 这是 MIR 第一次真实决定运行时行为：之前 MIR 即使存在也只是路径占位符，
  `verify-local` 里 empty-program 和 halt-program 现在是两条**结果不同**的真实测试
- 当前 emitter 仍只生成 `_start` + 单条 syscall；多条 `Halt(N)` 会让最后一条赢，
  control-flow / function call / multiple statements 仍属下一批次
- `halt_42.pas` 通过 LLVM binding 编译运行 exit 42，但默认 binding (gnu) 走宿主 FPC，
  那条路径仍由宿主决定行为；这是预期的，因为只有 LLVM 路径走 nextPas 自有 codegen
- 这一批不替换历史 addendum；下一批次自然入口是把 MIR 操作扩到包含
  整数 const / 二元运算 / 简单条件，让 `Halt(2 + 3)` 类表达式也能正确 lower

## Addendum: 2026-05-17 LLVM Backend First Codegen — Empty Program End-to-end

### Goal

把 nextPas 从“所有编译成功都是宿主 FPC 干的”推进到“nextPas 自己拥有 codegen ownership 的最小真实链路”。
之前 `compiler/ir/np_mir_model.pas` 是字符串占位符、`compiler/backend/np_backend_plan.pas` 90% 在算路径
0% 生成代码，所有 `.s` 都来自 `host-fpc-emit-asm`。这一批让 nextPas 自己写出 `.ll` 文件并由 LLVM
工具链产出真实可执行：

- 新增 `compiler/backend/np_llvm_emitter.pas`：从 `TMirModel` + `TTargetFactsView` 发射文本 LLVM IR
  到磁盘；当前批次只发射最小 empty-program shell（`define void @_start` + inline syscall exit(0)），
  绕开缺失的 distribution runtime libc，让 nextPas 真正拥有 entry point
- 让 `TBackendPlanner.Plan` 在 `BackendFamily='llvm'` 时调用 emitter 真实写 `.ll`，
  而不是只注册 artifact 路径
- 把 `compiler/toolchain/np_toolchain_plan.pas` 的 `PlanLlvmIrOptObjectLink` link step 从硬编码的
  `ExecutableSet.Lld` 切到 `LinkerProfile.DriverCandidates`，使 LLVM binding 复用 linker profile
- 把 `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml` 的 linker 从 `lld-elf` 切到 `gnu-ld`，
  不引入新依赖（系统未安装 `ld.lld`，但 `ld` 与 native binding 已在用）
- 默认 backend 不变（`bootstrap-native-assemble-link`），LLVM 路径通过
  `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 显式选择

### Status

Completed

### Completed Steps

- [x] 摸清现有 LLVM skeleton：`PlanLlvmIrOptObjectLink`、`PrepareLlvmContract`、`TBackendPlan`
      LLVM 字段已就位；缺口是 (a) 没有 IR emitter，(b) link step 写死 `ld.lld`，(c) binding 配置
      指向未安装的 `ld.lld`
- [x] 手工验证最小 LLVM 链路（`opt → llc → ld` + 自写 `_start` syscall exit(0)）能产出 exit 0
      可执行，确认 IR 模板可行
- [x] 新增 `compiler/backend/np_llvm_emitter.pas`，提供 `TLlvmEmitter.EmitToFile`，按
      target triple/data layout 发射 IR header，再发射 empty-program shell
- [x] 修改 `compiler/backend/np_backend_plan.pas`：在 `BackendFamily='llvm'` 分支调用
      `Emitter.EmitToFile`，`ForceDirectories` 后再发射；失败时 `MarkFailure`
- [x] 修改 `compiler/toolchain/np_toolchain_plan.pas:1394` link step：从 `ExecutableSet.Lld`
      改为 `FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld')`
- [x] 修改 `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml`：linker 从 `lld-elf`
      切到 `gnu-ld`
- [x] 修改 `build/verify_local.sh` 的现有 `llvm-binding-smoke` gate：fake stub 从 `ld.lld`
      改名为 `ld`，`linker-profile-id` 断言从 `lld-elf` 改为 `gnu-ld`
- [x] 在 `build/verify_local.sh` 新增 `llvm-empty-program` gate：用真 `opt`/`llc`/`ld` 编译
      `examples/smoke/hello.pas`，断言 `toolchain-plan-family=llvm-ir-opt-llc-link`、
      `backend-artifact-count=4`、`.ll` 文件存在并含 `@_start`、可执行 exit 0
- [x] 把 `llvmBindingSmoke`/`llvmEmptyProgram` 加进 verify-local success envelope
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| LLVM linker 切到系统 `ld`（gnu-ld），不装 `ld.lld` | 与 native binding 对称、零新依赖；后续如果引入 `ld.lld` 可独立切回 |
| Empty program 自写 `_start` + inline syscall exit(0)，不依赖 libc/_start | 当前 distribution runtime SDK 缺 `lib/nextpas/runtime/linux-x86_64/libc.so`；自写 `_start` 顺带让 nextPas 拥有 entry point ownership，与"独立 RTL"长期方向一致 |
| 默认 backend 保持 `bootstrap-native-assemble-link`，LLVM 通过 `--toolchain-binding` 显式选择 | 现有 40+ verify gate 全围绕 native 默认路径；一次性切默认会大面积翻车，不该和 codegen 引入混在一批 |
| 这一批 emitter 只发射 empty-program shell，不消费 MIR operations | 当前 MIR 是字符串占位符（`Kind: string` + `DisplayName`），还没有 value semantics；先把"自有 codegen 链路"打通，再分批扩 IR 表达力 |

### Notes

- 这是 nextPas 第一次真实生成代码：之前任何 `.s` 都来自 `host-fpc-emit-asm`，现在 `.ll` 由
  `TLlvmEmitter` 自己写
- 当前 LLVM 路径的真实功能只覆盖 `program X; begin end.` 这一种程序：任何带 `WriteLn`、表达式、
  类型、调用的程序都会发射同样的 empty shell（IR 中只有 `_start`+syscall），运行时仍 exit 0
  但实际语义被丢失。下一批次需要在 emitter 中开始消费 MIR operation
- LLVM 路径仍不能 self-host：MIR 还没有 value/type/control-flow，所以 nextPas 自己的 compiler module
  不能用 LLVM backend 编译；这与 `docs/plans/2026-05-02-stage2-feasibility-assessment.md` 的判断一致
- `compiler-roadmap.md` 第 5 段 “Target / Cross / LLVM / C Interop” 的 LLVM 部分从“skeleton 已就位”
  正式进入“最小真实闭环已就位”
- 这一批不替换历史 addendum，也不动 `bootstrap-native-assemble-link` 路径

## Addendum: 2026-05-17 Repo Hygiene + Classes RTL Source-of-truth Convergence

### Goal

把这次会话前发现的两类工作树级问题一次收口，并把下一批次入口明确转向 RTL Classes 实现，
而不是继续在 verify gate 上叠 addendum：

- 工作树污染：`core.997688`（22MB FPC core dump）、四个空 `crash_*.txt`、`ppas.sh`、
  `tools/stage0/nextpas_*.s`（5 个 ~250KB 残留汇编中间产物）必须从 untracked 状态清掉，
  并在 `.gitignore` 中通过 `core.*` / `crash_*.txt` / `ppas.sh` / `tools/stage0/*.s`
  正式 ignore，避免下一次崩溃或中断重新污染
- RTL Classes 必须收敛到与 SysUtils 一致的 source-of-truth 模式：
  `rtl/core/classes/np_classes.pas` 是唯一源，checked-in `Classes.pas` / `Classes.o` /
  `Classes.ppu` 一律由 build 派生并通过 `.gitignore` 排除；删掉之前与 `np_classes.pas`
  字节级一致的 `Classes.pas` 重复源
- 这一批不引入新代码、不改公开 line-based output / `command-envelope=<json>` 契约；
  fresh `bash build/verify_local.sh` 必须继续全绿

### Status

Completed

### Completed Steps

- [x] 删除工作树污染文件：`core.997688`、`crash_err.txt`、`crash_out.txt`、
      `crash_output.txt`、`crash_stdout.txt`、`ppas.sh`、
      `tools/stage0/nextpas_command_envelope.s`、`tools/stage0/nextpas_json_helpers.s`、
      `tools/stage0/nextpas_projection_json.s`、`tools/stage0/nextpas_projection_text.s`、
      `tools/stage0/nextpas_projection_types.s`
- [x] 删除 `rtl/core/classes/Classes.pas`（与 `np_classes.pas` 字节级一致的重复源），
      并清理其残留 `Classes.o` / `Classes.ppu`
- [x] 扩展 `.gitignore`，新增
      `rtl/core/classes/Classes.pas`、`rtl/core/classes/Classes.o`、
      `rtl/core/classes/Classes.ppu`、`core.*`、`crash_*.txt`、`ppas.sh`、
      `tools/stage0/*.s`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision                                                                        | Rationale                                                                                                |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Classes 收敛到 `np_classes.pas` 唯一源 + ignore 派生 `Classes.{pas,o,ppu}`      | 与 `rtl/core/sysutils/` 已建立的模式一致；checked-in 重复源会让 source-of-truth 漂移并误导下游 contributor |
| 工作树污染统一通过 `.gitignore` 模式封堵，不靠每次手动清理                      | FPC 崩溃 core dump、`ppas.sh` 中断脚本、`tools/stage0/*.s` 汇编中间产物都是已知会复现的工件             |
| 这一批不动 `np_classes.pas` 内容，也不实现 Classes 容器                         | 先把 source-of-truth 边界定清楚，再进入 RTL Classes 实现批次；避免一次混入两个方向                       |

### Notes

- 下一批次入口正式转向 RTL Classes 实现：`np_classes.pas` 当前只暴露最小 `TFileStream`
  shape，离 compiler module 真正能 `uses Classes` 还差容器类（`TStringList`、`TList`）；
  这与 `docs/plans/2026-05-02-stage2-feasibility-assessment.md` 列出的 Stage2 阻塞项一致
- 这一批不替换历史 addendum，也不改架构规范；`docs/plans/2026-05-02-rtl-implementation-plan.md`
  仍然是 RTL 推进的 owning plan，本 addendum 只负责把仓库卫生与 source-of-truth 模式
  同步到 task_plan 顶层，避免下一轮恢复时再被这批工件分散注意力

## Addendum: 2026-04-29 Package Workflow Truth Skeleton

### Goal

把 package workflow 的第一批 shared truth 从文档语义推进到 compiler-owned 最小实体，同时继续
守住“只读 truth / 非执行 workflow / 不伪装完整 package manager”这条边界：

- 新增 `compiler/frontend/np_package_workflow.pas`，至少拥有
  `TPackageManifestTruth`、`TPackageLockTruth`、`TPackageInstallPlanTruth` 与
  `TPackageWorkflowTruth`
- 这批 truth 必须消费 `np_package_manifest.pas` 已有的 `TPackageManifestInfo`，不重新发明 parser
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 必须冻结
  `package-workflow-manifest-status=ready`、`package-workflow-lock-status=deferred`、
  `package-install-plan-status=deferred` 与 `package-workflow-source-root-count=<non-zero>`
- 文档与持续记录必须同步成当前 reality，并明确这批不做 registry、fetch、install、solver
  或 lockfile write

### Status

Completed

### Completed Steps

- [x] 先在 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
      写出 package workflow truth 的 RED contract，并 fresh 运行确认失败点正好落在
      `np_package_workflow` unit 尚未存在
- [x] 新增 `compiler/frontend/np_package_workflow.pas`，最小落地
      `TPackageManifestTruth`、`TPackageLockTruth`、`TPackageInstallPlanTruth` 与
      `TPackageWorkflowTruth`
- [x] 让 manifest truth 消费 `TPackageManifestInfo` 的 manifest/package/source-root 事实；
      让 lock/install truth 只暴露 canonical path/provenance，并继续保持 `deferred`
- [x] 同步回写 `docs/architecture/package-workflow-specification.md`、
      `docs/architecture/workspace-file-format-specification.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 package workflow contract 与
      整套 `verify-local=pass`

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
