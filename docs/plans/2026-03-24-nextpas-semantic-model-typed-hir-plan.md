# nextPas Semantic Model / Typed HIR Skeleton Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 建立 nextPas 的最小 `sema` / `Typed HIR` 可执行骨架，让 `stage0 build` 在 resolution 之后真实运行 semantic analysis，并把最小 semantic truth 投影到 command envelope。

**Architecture:** 当前批次不直接做完整 Pascal 语义系统，而是先落一个最小但真实的 semantic spine：`UnitGraph -> SemanticAnalyzer -> SemanticModel -> Typed HIR projection`。这个骨架先固定 symbol/type/HIR identity、runtime contract seed、duplicate import semantic failure 与 session/stage0 的 owned truth，再为后续常量求值、调用绑定和 lowering 铺路。

**Tech Stack:** FreePascal (`objfpc`), `compiler/sema/`, existing `CompilationSession`, `TDiagnosticsSink`, `TUnitGraph`, `stage0 build`, smoke/fail fixtures, snapshot baseline.

---

### Task 1: Define the semantic batch boundary

**Files:**
- Create: `docs/plans/2026-03-24-nextpas-semantic-model-typed-hir-plan.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Write the failing red gate assumptions**

- Batch 6 需要至少新增：
  - `compiler/sema/np_semantic_model.pas`
  - `compiler/sema/np_semantic_analyzer.pas`
- `verify_local` 要增加：
  - semantic smoke projection
  - duplicate unit import semantic failure projection

**Step 2: Record the minimal semantic scope**

- symbol graph 先只表达 unit-level symbol identity
- type graph 先只表达 builtin canonical types
- `Typed HIR` 先只表达 compilation root、resolved unit refs 与 runtime contract refs
- 当前最小 semantic failure 先落 `sema.duplicate-declaration`

**Step 3: Commit checkpoint**

```bash
git add docs/plans/2026-03-24-nextpas-semantic-model-typed-hir-plan.md task_plan.md findings.md progress.md
git commit -m "docs: define semantic model skeleton batch"
```

### Task 2: Write the semantic model skeleton

**Files:**
- Create: `compiler/sema/np_semantic_model.pas`
- Test: `build/verify_local.sh`

**Step 1: Write the failing test**

- `verify_local` required path check must fail until `np_semantic_model.pas` exists.

**Step 2: Run test to verify it fails**

Run: `./build/verify_local.sh`
Expected: FAIL with `missing-required-path: compiler/sema/np_semantic_model.pas`

**Step 3: Write minimal implementation**

- Define:
  - `TSymbolGraph`
  - `TTypeGraph`
  - `TTypedHir`
  - `TSemanticModel`
- Keep ownership small:
  - symbol count
  - type count
  - hir node count
  - runtime contract count
  - root name
  - status

**Step 4: Run compile check**

Run: `fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema tools/stage0/nextpas.pas`
Expected: compile still fails later on missing analyzer/session wiring, not on missing model unit

### Task 3: Write the semantic analyzer skeleton

**Files:**
- Create: `compiler/sema/np_semantic_analyzer.pas`
- Modify: `compiler/frontend/np_unit_graph.pas`
- Modify: `compiler/syntax/np_ast_facade.pas`

**Step 1: Write the failing test**

- semantic smoke projection should fail until analyzer exists and session calls it

**Step 2: Run test to verify it fails**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: missing semantic projection fields

**Step 3: Write minimal implementation**

- `TUnitGraph` 暴露 resolved unit iteration
- `TSemanticAnalyzer`:
  - seeds builtin types
  - seeds unit symbols from `UnitGraph`
  - seeds runtime contracts for program/library/package roots
  - builds minimal `Typed HIR` counts
  - emits `sema.duplicate-declaration` on duplicate imported unit names

**Step 4: Run compile check**

Run: `fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema tools/stage0/nextpas.pas`
Expected: compile reaches session/driver integration gaps only

### Task 4: Integrate sema into the compilation session

**Files:**
- Modify: `compiler/frontend/np_compilation_session.pas`
- Modify: `compiler/README.md`
- Modify: `docs/architecture/compiler-specification.md`
- Modify: `docs/architecture/compiler-pipeline-specification.md`
- Modify: `docs/architecture/semantic-model-specification.md`

**Step 1: Write the failing test**

- semantic projection fields stay absent until session owns semantic model

**Step 2: Run test to verify it fails**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: no `semantic-status=` line

**Step 3: Write minimal implementation**

- `TCompilationSession` owns:
  - semantic model
  - semantic status
  - symbol count
  - type count
  - typed hir node count
  - runtime contract count
  - typed hir root name
- `AnalyzeSemantics` runs after `ResolveUnits`
- semantic failures stay in diagnostics sink and set `semantic-analysis-failed` precondition

**Step 4: Run focused verification**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: semantic projection fields appear and show `semantic-status=ready`

### Task 5: Integrate sema into `stage0 build` and failure handling

**Files:**
- Modify: `tools/stage0/nextpas.pas`
- Modify: `tools/stage0/target_config.pas`
- Modify: `tools/stage0/README.md`
- Modify: `docs/architecture/stage0-driver-specification.md`

**Step 1: Write the failing test**

- build succeeds without semantic projection/failure kind until driver is wired

**Step 2: Run test to verify it fails**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: semantic projection absent or `sema` stage remains deferred

**Step 3: Write minimal implementation**

- `stage0 build` calls `AnalyzeSemantics`
- projection adds:
  - `semantic-status`
  - `symbol-graph-status`
  - `type-graph-status`
  - `typed-hir-status`
  - `symbol-count`
  - `type-count`
  - `typed-hir-node-count`
  - `runtime-contract-count`
  - `typed-hir-root-name`
- semantic failure exits early with `failure-kind=semantic-analysis-failed`

**Step 4: Run focused verification**

Run: `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
Expected: semantic projection present in stdout and envelope

### Task 6: Add semantic smoke + failure gate

**Files:**
- Modify: `build/verify_local.sh`
- Create: `tests/compiler/fail/duplicate_unit_import_fail.pas`
- Create: `tests/snapshots/compiler-fail-duplicate_unit_import.stderr.txt`
- Modify: `build/README.md`

**Step 1: Write the failing test**

- new duplicate import fixture should fail verify_local until sema is live

**Step 2: Run test to verify it fails**

Run: `./build/verify_local.sh`
Expected: semantic smoke or duplicate import check fails

**Step 3: Write minimal implementation**

- verify semantic smoke on `examples/smoke/hello_with_units.pas`
- verify semantic failure:
  - `failure-kind=semantic-analysis-failed`
  - `diagnostic-code=sema.duplicate-declaration`
  - `diagnostic-phase=sema`

**Step 4: Run full verification**

Run: `./build/verify_local.sh`
Expected: PASS

### Task 7: Refresh roadmap and evidence

**Files:**
- Modify: `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`
- Create: `.sisyphus/evidence/batch-semantic-model-typed-hir-skeleton.txt`

**Step 1: Capture verified command outputs**

- `fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema tools/stage0/nextpas.pas`
- `./tools/stage0/nextpas build examples/smoke/hello_with_units.pas --target linux-x86_64`
- `./tools/stage0/nextpas build tests/compiler/fail/duplicate_unit_import_fail.pas --target linux-x86_64`
- `./build/verify_local.sh`

**Step 2: Write evidence and update roadmap**

- mark Batch 6 as completed if gate is green
- record next batch candidate after semantic skeleton

**Step 3: Commit checkpoint**

```bash
git add docs/plans/2026-03-24-nextpas-master-roadmap-plan.md task_plan.md findings.md progress.md .sisyphus/evidence/batch-semantic-model-typed-hir-skeleton.txt
git commit -m "docs: capture semantic model skeleton evidence"
```
