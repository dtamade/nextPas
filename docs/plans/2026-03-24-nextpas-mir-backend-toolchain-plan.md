# nextPas MIR / Backend / Toolchain Boundary Skeleton Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 建立 nextPas 的最小 `Typed HIR -> MIR -> backend artifact/tool invocation plan` 可执行骨架，让 `stage0 build` 在 semantic analysis 之后真实拥有 IR / backend / toolchain truth，并把它们投影到 command envelope。

**Architecture:** 当前批次不直接做真实 codegen，而是先落一条最小但真实的 backend spine：`SemanticModel -> MIRLowerer -> BackendPlanner -> ToolInvocationPlan projection`。这条骨架先固定 `MIR` 的最小 block/op identity、backend artifact/output intent、toolchain binding identity 与 target/backend metadata，再为后续真实 lowering、assembler/linker orchestration 和 LLVM/native backend adapter 铺路。

**Tech Stack:** FreePascal (`objfpc`), `compiler/ir/`, `compiler/backend/`, existing `CompilationSession`, `TTargetFactsView`, `stage0 build`, `build/targets/`, `build/toolchains/`, smoke verification gate.

---

### Task 1: Define the MIR/backend batch boundary

**Files:**
- Create: `docs/plans/2026-03-24-nextpas-mir-backend-toolchain-plan.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Record the minimal batch scope**

- `MIR` 先只表达单 entry block 与 target-neutral op list
- backend 先只表达 output intent、primary artifact 与 tool invocation plan
- toolchain 先只表达单一 host-to-target binding skeleton
- 当前不做真实 assembler/linker 执行接管，继续让 host FPC 托管实际编译

**Step 2: Record the red gate**

- `verify_local` 需要新增：
  - `compiler/ir/np_mir_model.pas`
  - `compiler/backend/np_backend_plan.pas`
  - `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
  - `mir-status` / `backend-plan-status` / toolchain projection

### Task 2: Write the MIR skeleton

**Files:**
- Create: `compiler/ir/np_mir_model.pas`
- Modify: `compiler/sema/np_semantic_model.pas`

**Step 1: Write the failing test**

- `verify_local` required path check must fail until `np_mir_model.pas` exists.

**Step 2: Run test to verify it fails**

Run: `./build/verify_local.sh`
Expected: FAIL with `missing-required-path: compiler/ir/np_mir_model.pas`

**Step 3: Write minimal implementation**

- `TSemanticModel` 暴露 typed HIR iteration
- 定义：
  - `TMirBlock`
  - `TMirOperation`
  - `TMirModel`
  - `TMirLowerer`
- 先支持：
  - one entry block
  - one op per typed-hir node
  - one explicit `return` op

**Step 4: Run compile check**

Run: `fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir tools/stage0/nextpas.pas`
Expected: compile still fails later on backend/session wiring, not on missing MIR unit

### Task 3: Write the backend artifact/toolchain plan skeleton

**Files:**
- Create: `compiler/backend/np_backend_plan.pas`
- Modify: `compiler/targets/np_target_facts.pas`
- Modify: `tools/stage0/target_config.pas`
- Modify: `build/targets/linux-x86_64.toml`
- Create: `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`

**Step 1: Write the failing test**

- semantic smoke projection should still miss `mir-status` / backend/toolchain fields until planner exists

**Step 2: Run test to verify it fails**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: missing MIR / backend projection fields

**Step 3: Write minimal implementation**

- `TTargetFactsView` 扩展：
  - object format
  - assembler flavor
  - linker flavor
  - LLVM triple
  - toolchain binding id
  - backend family
- target config 读取这些字段，并解析最小 toolchain binding skeleton
- `TBackendPlan` 先表达：
  - output kind
  - primary artifact kind/path
  - tool invocation count
  - primary tool role
- `TBackendPlanner` 先从 `MIR + TargetFacts + SourcePath` 生成一条 host-compiler invocation plan

**Step 4: Run compile check**

Run: `fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Fucompiler/backend tools/stage0/nextpas.pas`
Expected: compile reaches session/driver integration gaps only

### Task 4: Integrate MIR/backend planning into the compilation session

**Files:**
- Modify: `compiler/frontend/np_compilation_session.pas`
- Modify: `compiler/README.md`
- Modify: `docs/architecture/compiler-specification.md`
- Modify: `docs/architecture/compiler-pipeline-specification.md`
- Modify: `docs/architecture/backend-specification.md`

**Step 1: Write the failing test**

- MIR/backend projection fields stay absent until session owns the new models

**Step 2: Run test to verify it fails**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: no `mir-status=` or `backend-plan-status=` lines

**Step 3: Write minimal implementation**

- `TCompilationSession` owns:
  - MIR model
  - backend plan
  - MIR/backend status and count getters
- session stage order becomes:
  - `AnalyzeSyntax`
  - `ResolveUnits`
  - `AnalyzeSemantics`
  - `LowerToMir`
  - `PlanBackend`
- stage lifetime summary includes real `ir:<status>` and `backend:<status>`

**Step 4: Run focused verification**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: MIR/backend projection fields appear and show `mir-status=ready`

### Task 5: Integrate MIR/backend/toolchain projection into `stage0 build`

**Files:**
- Modify: `tools/stage0/nextpas.pas`
- Modify: `tools/stage0/README.md`
- Modify: `docs/architecture/stage0-driver-specification.md`
- Modify: `build/README.md`

**Step 1: Write the failing test**

- build succeeds without MIR/backend/toolchain projection until driver is wired

**Step 2: Run test to verify it fails**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: MIR/backend/toolchain fields absent from stdout and envelope

**Step 3: Write minimal implementation**

- `stage0 build` calls:
  - `LowerToMir`
  - `PlanBackend`
- projection adds:
  - `mir-status`
  - `mir-block-count`
  - `mir-operation-count`
  - `mir-entry-block`
  - `mir-root-name`
  - `backend-plan-status`
  - `backend-output-kind`
  - `backend-primary-artifact-kind`
  - `backend-primary-artifact-path`
  - `toolchain-binding-id`
  - `backend-family`
  - `target-object-format`
  - `target-assembler-flavor`
  - `target-linker-flavor`
  - `tool-invocation-count`
  - `primary-tool-role`

**Step 4: Run focused verification**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: MIR/backend/toolchain projection present in stdout and envelope

### Task 6: Add MIR/backend/toolchain smoke gate

**Files:**
- Modify: `build/verify_local.sh`

**Step 1: Write the failing test**

- `verify_local` should fail until MIR/backend/toolchain fields are live

**Step 2: Run test to verify it fails**

Run: `./build/verify_local.sh`
Expected: MIR/backend/toolchain smoke assertion fails

**Step 3: Write minimal implementation**

- success smoke now verifies `mir-status=ready` / `backend-plan-status=ready`
- semantic smoke verifies exact MIR/backend/toolchain counts on `hello_with_units`

**Step 4: Run full verification**

Run: `./build/verify_local.sh`
Expected: PASS

### Task 7: Refresh roadmap and evidence

**Files:**
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`
- Create: `.sisyphus/evidence/batch-mir-backend-toolchain-skeleton.txt`

**Step 1: Capture verified command outputs**

- `fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Fucompiler/backend tools/stage0/nextpas.pas`
- `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
- `./build/verify_local.sh`

**Step 2: Write evidence and update roadmap**

- mark Batch 7 as completed if gate is green
- record next batch candidate after MIR/backend/toolchain skeleton
