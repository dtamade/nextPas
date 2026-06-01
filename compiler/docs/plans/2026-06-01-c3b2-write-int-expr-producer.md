# C3-B2 Write-Int Expression Producer Plan

**Goal:** Extend the sema producer migration by attaching structured `ExprId` to `write-int-runtime` nodes for simple scalar expressions.

**Scope:** Only `Write/WriteLn` runtime integer arguments that already produce `write-int-runtime`. Keep `TTypedHirNode.Operand` as the legacy blob. Do not migrate assignment, return, conditional branches, string writes, or lvalue/address forms in this batch.

## Task Checklist

- [x] Confirm current commit and `compiler/` cleanliness.
- [x] Re-read `write-int-runtime` creation points and the C3-B1 producer helper.
- [x] Add a focused RED test for `WriteLn(x + 4)` requiring non-zero `ExprId` while preserving `Operand`.
- [x] Reuse `BuildRuntimeScalarHirExpr` instead of adding new expression kinds or builder behavior.
- [x] Wire all current `write-int-runtime` creation paths through a local helper that sets `ExprId` when possible.
- [x] Run focused producer/builder/model tests.
- [x] Run full rebuild and 137 LLVM smoke tests.
- [x] Update goal tree and commit compiler-only changes.

## Decisions

- C3-B2 keeps the same dual-track contract as C3-B1: the blob remains present and authoritative for unsupported expressions or future fallback.
- The producer helper is reused exactly as-is. Runtime variables stay `shekSymbolValue`; this preserves runtime expression identity even when sema knows a previous var-init value.
- `IntToStr(expr)` writes attach the structured expression for the inner integer expression, not for the wrapper call, because the emitted HIR node is still `write-int-runtime`.
- Dot-access virtual-call integer writes are routed through the same helper, but unsupported forms keep `ExprId = 0` through the helper's failure path.

## Progress Log

- Started from commit `a187086d` after C3-B1.
- `compiler/` was clean before this batch; unrelated dirty files under `.claude/`, `.worktrees/`, and `core/` were ignored.
- RED: `test_semantic_hir_expr_producer.pas` was extended with `WriteLn(x + 4)` and failed with `EXIT_CODE=13`, confirming `write-int-runtime.ExprId` was still zero.
- GREEN: `WalkHaltCalls` now uses a local `AddWriteIntRuntimeNode` helper for all three `write-int-runtime` creation paths. The helper preserves the legacy blob and sets `ExprId` when `BuildRuntimeScalarHirExpr` succeeds.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43668 lines compiled`; LLVM smoke reported `passed=137 failed=0`.

## Next Step

C3-B3 should migrate the next single-expression runtime producer with the same pattern. Recommended candidates are `ret-runtime` or conditional branch producers; choose the one with the smallest existing `LowerNodeExprOrBlob` surface and add RED tests before wiring sema.
