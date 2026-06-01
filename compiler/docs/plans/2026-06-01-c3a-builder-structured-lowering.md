# C3-A Builder Structured Lowering Plan

**Goal:** Teach `THIRBuilder.LowerExpr` to lower the first scalar structured expressions while keeping sema producers and blob fallback unchanged.

**Scope:** Builder-only support for integer literals, scalar symbol values, unary operators, binary arithmetic, comparisons, and bool-shaped `not`/`and`/`or` patterns. No producer migration in this batch.

## Task Checklist

- [x] Confirm global dirty state is outside `compiler/` and will not be touched.
- [x] Read C2 semantic expression model and builder fallback seam.
- [x] Add focused RED tests for structured scalar lowering.
- [x] Implement minimal builder lowering for C3-A expression kinds.
- [x] Run focused tests.
- [x] Run full compiler rebuild and 137 LLVM smoke tests.
- [x] Update goal tree or plan status, commit compiler-only changes, and report.

## Findings

- C2 wired `ProcessAssign`, `ProcessHaltCall`, `ProcessCondBr`, `ProcessSwitch`, `ProcessRetRuntime`, and `ProcessWriteInt` through `LowerNodeExprOrBlob`.
- `LowerExpr` currently returns `False` for all non-invalid expression kinds, so C3-A can be tested through the real build path by assigning `ExprId` to typed HIR nodes.
- The builder still has global cached type ids (`GIntType`, `GBoolType`, `GStringType`, `GPtrType`), which is existing C4-era debt. C3-A tests should avoid comparing ids across builders.
- Structured lowering must be all-or-fallback at the expression boundary. `CanLowerExpr` preflights the tree so unsupported child expressions do not leave partial HIR instructions before blob fallback.

## Progress Log

- Started C3-A after C2 commit `8ff3b143`.
- Scope is intentionally builder-only to keep existing sema behavior stable before producer migration.
- Added `test_hir_builder_structured_expr.pas` for structured int literal, symbol value, arithmetic, compare, boolean operations, and cond-br.
- Extended fallback test to cover partial structured tree failure: unsupported children must fall back to blob without emitting the supported prefix.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43526 lines compiled`; LLVM smoke reported `passed=137 failed=0`.
