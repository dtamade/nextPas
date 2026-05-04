# Backend Intermediate Artifact Truth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让 backend/session/stage0 真实拥有并投影 assembly/object/executable 三类 artifact truth，同时继续保持当前 production path 为 host-compiler runner reuse。

**Architecture:** 保持 `PlanFromBackend` 继续选择当前 bootstrap host-compiler path，不提前切到 native assembler/linker。先把 `compiler/backend/np_backend_plan.pas` 扩成拥有 typed intermediate artifacts，再让 `compiler/toolchain/np_toolchain_plan.pas` 和 `tools/stage0/nextpas.pas` 消费这份 truth：toolchain 的 logical link request 开始引用 backend-owned object artifact，CLI/envelope 则通过最小 `backend-artifact-count` / `backend-artifacts` projection 暴露这批中间产物。

**Tech Stack:** FreePascal, existing `build/verify_local.sh` promotion gate, `TCompilationSession`, `TBackendPlan`, `TToolchainPlan`.

---

### Task 1: Write failing verification gate

**Files:**
- Modify: `build/verify_local.sh`

**Step 1: Write the failing test**

- 为 `stage0-smoke`、`semantic-smoke` 与 `toolchain-failure` 增加新 gate：
  - `backend-artifact-count=3`
  - `backend-artifacts=<json>` 至少包含 `assembly-text`、`object-file`、`executable`
  - envelope `result.backendArtifactCount=3`
  - envelope `result.backendArtifacts` 至少包含同三类 artifact
  - `logical-link-request` / envelope `logicalLinkRequest` 至少包含 backend-owned `object-file`

**Step 2: Run test to verify it fails**

Run: `bash build/verify_local.sh`
Expected: fail on the new `backend-artifact-*` or logical object-input gates.

### Task 2: Add backend-owned intermediate artifact truth

**Files:**
- Modify: `compiler/backend/np_backend_plan.pas`
- Modify: `compiler/frontend/np_compilation_session.pas`

**Step 1: Write minimal implementation**

- `TBackendPlan` 增加最小读取能力：
  - `ArtifactAt(...)`
  - `ArtifactsJson`
- `TBackendPlanner` 接收 artifact root，生成稳定的 backend intermediate paths：
  - `<artifact-root>/cache/backend/<target>/<program>.s`
  - `<artifact-root>/cache/backend/<target>/<program>.o`
  - `<output-dir>/<program>`
- `Plan` 中按固定顺序加入：
  - `assembly-text`
  - `object-file`
  - `executable`
- `TCompilationSession` 增加：
  - `BackendArtifactCount`
  - `BackendArtifactsJson`

**Step 2: Run focused verification**

Run: `bash build/verify_local.sh`
Expected: 先前新增的 `backend-artifact-*` gate 通过，若仍失败则只剩 projection/toolchain side。

### Task 3: Rewire toolchain/logical-link projection to consume backend truth

**Files:**
- Modify: `compiler/toolchain/np_toolchain_plan.pas`
- Modify: `tools/stage0/nextpas.pas`

**Step 1: Write minimal implementation**

- `TToolchainPlanner.PlanBootstrapHostCompiler` 从 backend-owned artifacts 中吸收 `object-file`
  到 `LogicalLinkRequest.ObjectInputs`
- `tools/stage0/nextpas.pas` 新增 backend projection：
  - `backend-artifact-count`
  - `backend-artifacts`
  - envelope `backendArtifactCount`
  - envelope `backendArtifacts`

**Step 2: Run full verification**

Run: `bash build/verify_local.sh`
Expected: full pass with `verify-local=pass`.

### Task 4: Sync truth back to docs

**Files:**
- Modify: `tools/stage0/README.md`
- Modify: `docs/architecture/backend-specification.md`
- Modify: `docs/architecture/stage0-driver-specification.md`
- Modify: `docs/architecture/toolchain-specification.md`
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Document exact boundary**

- backend 现在已拥有 intermediate artifact truth
- toolchain logical link request 已开始消费 backend-owned object artifact
- `stage0 build` 仍未切到 native assembler/linker production path

**Step 2: Re-run verification after docs sync**

Run: `bash build/verify_local.sh`
Expected: still pass.
