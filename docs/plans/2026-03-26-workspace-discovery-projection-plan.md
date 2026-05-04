# Workspace Discovery Projection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 stage0 已经真实存在的 workspace/package/artifact discovery 结果提升成正式 command truth，并同时投影到 line-based output 与 `command-envelope=<json>`。

**Architecture:** 保持当前 root discovery / artifact placement 逻辑不变，只补一条最小 typed projection 通路。`tools/stage0/nextpas.pas` 负责解析 discovery 结果，`TCompilationOptions` / `TCompilationSession` 负责持有并暴露这些字段，CLI 与 envelope 只做稳定投影，不引入完整 `WorkspaceModel` 或新的 package/workspace graph。

**Tech Stack:** FreePascal/Object Pascal, `tools/stage0/nextpas.pas`, `compiler/frontend/np_compilation_session.pas`, existing package-manifest helpers, shell verification in `build/verify_local.sh`.

---

### Task 1: 写 RED gate，冻结最小 workspace discovery truth surface

**Files:**
- Modify: `build/verify_local.sh`

**Step 1: Write the failing test**

为现有 verify case 增加最小断言：
- stage0 smoke：`workspace-root`、`workspace-discovery-kind=explicit-workspace-override`、`artifact-root`、`output-dir`
- package manifest fixture：`workspace-discovery-kind=nearest-package-manifest`、`package-manifest-path`
- workspace member fixture：`workspace-discovery-kind=nearest-workspace-descriptor`、`workspace-descriptor-path`、`package-manifest-path`
- `command-envelope=<json>.result` 也必须同步带上 camelCase 版本字段

**Step 2: Run test to verify it fails**

Run: `bash build/verify_local.sh`
Expected: FAIL，因为当前这些 discovery facts 只在 stage0 内部被消费，还没有稳定投影。

**Step 3: Confirm failure is the expected RED**

确认失败落在新增的 workspace discovery projection assertions，而不是无关 gate。

### Task 2: 在 session options 中正式持有 discovery metadata

**Files:**
- Modify: `compiler/frontend/np_compilation_session.pas`
- Modify: `tools/stage0/nextpas.pas`

**Step 1: Add minimal owned fields**

为 `TCompilationOptions` 补齐：
- `WorkspaceDiscoveryKind`
- `WorkspaceDescriptorPath`
- `PackageManifestPath`

保留现有：
- `WorkspaceRootPath`
- `ArtifactRootPath`
- `OutputDirPath`

**Step 2: Expose getters / projection helpers**

让 `TCompilationSession` 能稳定暴露：
- workspace root
- discovery kind
- workspace descriptor path
- package manifest path
- artifact root
- output dir

**Step 3: Keep architecture small**

不要在这一批引入完整 `WorkspaceModel`、member graph、target default persistence 或 lockfile 对象；只把当前真实 command truth 收进 session/options。

### Task 3: 让 stage0 解析并投影 discovery truth

**Files:**
- Modify: `tools/stage0/nextpas.pas`
- Optionally modify: `compiler/frontend/np_package_manifest.pas`

**Step 1: Build minimal discovery context**

在 stage0 现有 helper 上补最小 discovery metadata：
- explicit workspace override
- nearest workspace descriptor
- nearest package manifest
- source directory fallback

并复用现有 package manifest helper 计算 nearest package manifest path，避免重复发明第二套规则。

**Step 2: Project to line-based output**

新增稳定字段：
- `workspace-root=`
- `workspace-discovery-kind=`
- `workspace-descriptor-path=`（有值时）
- `package-manifest-path=`（有值时）
- `artifact-root=`
- `output-dir=`

**Step 3: Project to command envelope**

在 `command-envelope=<json>.result` 中新增 camelCase 字段：
- `workspaceRoot`
- `workspaceDiscoveryKind`
- `workspaceDescriptorPath`
- `packageManifestPath`
- `artifactRoot`
- `outputDir`

保持现有 `artifact`、`backendPrimaryArtifactPath`、`toolInvocationPlan` 等字段不变。

### Task 4: 运行 verify 并同步文档/规划文件

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`
- Optionally modify: `docs/architecture/stage0-driver-specification.md`
- Optionally modify: `tools/stage0/README.md`

**Step 1: Run full verification**

Run: `bash build/verify_local.sh`
Expected: PASS。

**Step 2: Sync persistent notes**

记录：
- 这批只做 discovery truth projection，不宣称完整 workspace model 已落地
- 当前 CLI/envelope 已经能解释 workspace root、artifact root 与 nearest descriptor/manifest 来源
- 完整 workspace truth / package graph / target default persistence 仍留在后续批次
