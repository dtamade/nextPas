# C2 Structured Expression Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the C2 structured semantic expression table and HIR builder dual-track lowering entry while preserving existing blob behavior.

**Architecture:** `TSemanticModel` owns a typed expression table made of compact records and stable integer ids. `TTypedHirNode.ExprId` links a typed HIR node to a structured expression, with `0` meaning legacy blob lowering. `THIRBuilder` gets a `LowerExpr` entry that can dispatch on the structured expression kind and fall back to `ParseIntBlob` when no structured form exists or lowering declines the node.

**Tech Stack:** FreePascal 3.3.1, Object Pascal records/dynamic arrays, existing `compiler/sema` and `compiler/ir` units, focused FPC tests, full `scripts/rebuild-compiler.sh`, LLVM smoke examples.

---

### Task 1: Semantic Model Expression Table

**Files:**
- Modify: `compiler/sema/np_semantic_model.pas`
- Create: `compiler/tests/test_semantic_hir_expr.pas`

- [x] Add a focused compiler-domain test in `compiler/tests/test_semantic_hir_expr.pas` that creates one semantic expression through `SemaModel.AddHirExpr`, checks `HirExprCount`, `HirExprAt`, `Kind`, `TypeId`, `SymbolId`, `LiteralInt`, `LiteralStr`, `Op`, `SourceOffset`, `ValueClass`, and verifies typed HIR node `ExprId` linking.

- [x] Run:

```bash
fpc -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text \
  -FE.sisyphus/tmp/c2-tests -FU.sisyphus/tmp/c2-tests \
  compiler/tests/test_semantic_hir_expr.pas
```

Expected: compile fails because `AddHirExpr`, `HirExprCount`, `HirExprAt`, `TSemanticHirExprKind`, and `TSemanticHirValueClass` do not exist yet.

- [x] In `compiler/sema/np_semantic_model.pas`, add `TSemanticHirValueClass`, `TSemanticHirExprKind`, `TSemanticHirExpr`, `FhirExprs`, `AddHirExpr`, `HirExprCount`, and `HirExprAt`. Keep ids one-based and return a zeroed invalid record for out-of-range access.

- [x] Add `ExprId: LongInt` to `TTypedHirNode` and initialize it to `0` in `AddTypedHirNode` and invalid `TypedHirNodeAt`.

- [x] Run the same focused FPC command. Expected: compile succeeds.

### Task 2: Builder LowerExpr Skeleton And Legacy Fallback

**Files:**
- Modify: `compiler/ir/np_hir_builder.pas`
- Modify: `compiler/tests/test_semantic_hir_expr.pas`
- Create: `compiler/tests/test_hir_builder_expr_fallback.pas`

- [x] Extend the focused tests so one typed HIR node is given a non-zero `ExprId` via `SetTypedHirNodeExprId`, and builder `LowerExpr` exposes a fallback-only seam for unsupported structured expressions.

- [x] Run the focused command. Expected before implementation: compile fails because `SetTypedHirNodeExprId` is missing.

- [x] Add `SetTypedHirNodeExprId` to `TSemanticModel`, with bounds checks and no effect for invalid ids.

- [x] In `np_hir_builder.pas`, add `THIRExprResult` and helpers `LowerExpr`, `LowerExprValue`, `LowerExprAddress`, and `LowerNodeExprOrBlob`. For C2, `LowerExpr` reads the semantic expression, returns `False` for `shekInvalid` or unsupported kinds, and never emits instructions yet. `LowerNodeExprOrBlob` tries `ExprId > 0` first and calls `ParseIntBlob` on failure.

- [x] Replace direct `ParseIntBlob` calls only at simple expression-valued node boundaries where this is mechanically safe for C2: `ProcessAssign`, `ProcessHaltCall`, `ProcessCondBr`, `ProcessSwitch`, `ProcessRetRuntime`, and `ProcessWriteInt`. Leave string/array/field specialized multi-blob parsers on legacy paths for later migration.

- [x] Run the focused FPC command and executable. Expected: test passes and existing output remains blob-driven.

### Task 3: Goal Tree Status And Verification

**Files:**
- Modify: `compiler/docs/compiler-goal-tree.md`

- [x] Update C2 status to completed and add a change-log entry explaining that C2 introduced the structured expression skeleton without producer migration.

- [x] Run `scripts/rebuild-compiler.sh`. Expected: output includes `40000+ lines compiled`, not `481 lines compiled`.

- [x] Run the 137 LLVM smoke tests with `.sisyphus/tmp/stage0-bootstrap/nextpas`; every produced executable must exit `42`.

- [x] Run `git status --short` and confirm only intended `compiler/` files and this plan are modified, plus intentional compiler-domain tests if touched. Do not stage or modify `core/`.
