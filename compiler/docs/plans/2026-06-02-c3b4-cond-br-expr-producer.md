# C3-B4 Cond-Br Expression Producer Plan

**Goal:** Attach structured `ExprId` to runtime conditional branch nodes when the condition can be safely lowered as a boolean value.

**Scope:** `cond-br-runtime` nodes emitted for `if`, `while`, and `repeat` conditions. Keep the legacy condition blob in `Operand`. Do not migrate `for` loop conditions in this batch because they are currently hand-built from loop variable/end blobs rather than a single condition AST node.

## Task Checklist

- [x] Confirm current commit and `compiler/` cleanliness.
- [x] Re-read `cond-br-runtime` producer paths and builder `LowerNodeExprOrBlob` consumer.
- [x] Add a focused RED test for `if x > 0 then ...` requiring non-zero `ExprId`.
- [x] Add a sema helper that only attaches structured conditions proven to lower to bool/i1.
- [x] Wire `if`, `while`, and `repeat` condition producers through that helper.
- [x] Run focused producer/builder/model tests.
- [x] Run full rebuild and 137 LLVM smoke tests.
- [x] Update goal tree and commit compiler-only changes.

## Decisions

- Structured `cond-br` must not receive scalar `i64` values, because the LLVM emitter emits `br i1`.
- The helper accepts `shekCompareOp`, `not` over bool conditions, and `and/or` trees whose children are also bool conditions.
- Plain integer variables, `True`, `False`, function calls, string comparisons, `is/as`, and hand-built `for` conditions keep using blob fallback until the type/width and bool normalization work is ready.
- This keeps C3-B4 behavior-preserving while still removing blob parsing from common comparison-based runtime branches.

## Progress Log

- Started from commit `7eed6173`.
- RED: `test_semantic_hir_expr_producer.pas` was extended with `if x > 0 then Halt(1) else Halt(2)` and failed with `EXIT_CODE=33`, confirming `cond-br-runtime.ExprId` was still zero.
- GREEN: added `AttachRuntimeConditionExpr` and wired `if`, `while`, and `repeat` branch producers.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43739 lines compiled`; LLVM smoke reported `passed=137 failed=0`.

## Next Step

C3-B5 should migrate the remaining safe producer surface before C4. Candidates are assignment producer nodes that already flow through `LowerNodeExprOrBlob`, but the next batch should first map all `assign-runtime` creation paths and choose a narrow expression class to avoid pulling lvalue/address work forward from C5.
