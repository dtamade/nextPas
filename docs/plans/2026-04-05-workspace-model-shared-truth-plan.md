# nextPas Workspace Model Shared Truth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把当前已经存在的 workspace/package/artifact discovery 从 `stage0` driver helper 提升成 compiler-owned shared model，并保持公开 line-based output、`command-envelope=<json>` 与 verify 行为不变。

**Architecture:** 新增 `compiler/frontend/np_workspace_model.pas`，把 `WorkspaceModel`、`PackageRef`、`TargetSelection`、`ArtifactRootSet` 与最小 loader 固定成 compiler-owned truth。`tools/stage0/nextpas.pas` 只保留 CLI override 与 orchestration，workspace discovery、package roots、artifact/output/cache placement 全部改为消费 shared model；`TCompilationSession` 则正式拥有这份 model，并从它投影 workspace/build truth。

**Tech Stack:** FreePascal / Pascal units, shell verification (`build/verify_local.sh`), existing stage0 + toolchain contract smoke.

**Status:** completed

**Fresh evidence:** fresh `bash build/verify_local.sh` 继续得到 `toolchainContractCheck=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

---

### Task 1: Add RED contract for shared workspace model

**Files:**

- Modify: `tests/toolchain/toolchain_contract_smoke.pas`
- Modify: `build/verify_local.sh`

**Step 1: Write the failing test**

- 在 `tests/toolchain/toolchain_contract_smoke.pas` 增加 shared workspace model contract probe。
- 覆盖三条当前已经存在的真实路径：
  - explicit workspace override
  - nearest package manifest
  - nearest workspace descriptor member root
- 输出最小 contract：
  - workspace root / discovery kind / descriptor path / package manifest path
  - package ref count
  - source root count
  - artifact root / output dir / host-fpc cache root

**Step 2: Run test to verify it fails**

Run:

```bash
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Fucompiler/backend -Fucompiler/toolchain -Futools/stage0 -Furtl/core/base -Furtl/core/text -FE.sisyphus/tmp/toolchain_contract_red -FU.sisyphus/tmp/toolchain_contract_red tests/toolchain/toolchain_contract_smoke.pas
```

Expected: FAIL because `np_workspace_model` does not exist yet.

### Task 2: Implement minimal shared workspace model

**Files:**

- Create: `compiler/frontend/np_workspace_model.pas`
- Modify: `compiler/frontend/np_package_manifest.pas`

**Step 1: Write minimal implementation**

- 新增 `TWorkspaceModel`、`TPackageRef`、`TTargetSelection`、`TArtifactRootSet`。
- 提供最小 loader，负责：
  - workspace discovery
  - nearest package manifest / workspace member package refs
  - source root info aggregation
  - artifact root / output dir / host-fpc cache root placement
- 保留 `np_package_manifest.pas` 的 parser 职责，但让它为 workspace model 提供 typed inputs。

**Step 2: Run focused test**

Run the same compile command as Task 1.

Expected: compile PASS.

### Task 3: Move session ownership to workspace model

**Files:**

- Modify: `compiler/frontend/np_compilation_session.pas`
- Modify: `compiler/frontend/np_unit_resolver.pas`

**Step 1: Write failing test**

- 扩展 `toolchain_contract_smoke` / verify 断言，要求 session-facing getters 继续给出完全相同的 workspace/package/artifact truth。

**Step 2: Write minimal implementation**

- `TCompilationOptions` 增加 `WorkspaceModel`。
- `TCompilationSession` 正式拥有并释放 model。
- workspace/package/artifact getters 从 model 读取。
- resolver 继续消费 typed root infos，但来源改为 workspace model，而不是 driver 拼出来的散落数组。

**Step 3: Run focused test**

Run:

```bash
bash build/verify_local.sh
```

Expected: FAIL only where stage0 still uses old helper path or projections drift.

### Task 4: Move stage0 build path onto shared model

**Files:**

- Modify: `tools/stage0/nextpas.pas`

**Step 1: Write minimal implementation**

- 删除/收缩 driver 里的 workspace/package/artifact discovery helper。
- `HandleBuild` 改为先加载 `TWorkspaceModel`，再从 model 填充 pre-session build context、session options 与 projection capture。
- 保持 public line/envelope field、early-failure behavior 与 search-root precedence 不变。

**Step 2: Run verification**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS.

### Task 5: Sync docs and planning records

**Files:**

- Modify: `docs/architecture/workspace-specification.md`
- Modify: `docs/architecture/stage0-driver-specification.md`
- Modify: `docs/architecture/compiler-specification.md`
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Capture evidence and update docs**

- 回写 shared workspace model 的最小 ownership 边界。
- 记录 `stage0` 已从 driver helper 改成消费 compiler-owned model。
- 同步当前 rolling window 的批次方向与验证证据。

**Step 2: Run full verification again**

Run:

```bash
bash build/verify_local.sh
```

Expected: PASS with fresh evidence.
