# C3-B5 Assign Expression Producer Plan

**Goal:** Attach structured `ExprId` to the safest `assign-runtime` producer slice while keeping the legacy assignment blob authoritative.

**Scope:** Ordinary scalar variable assignment such as `x := x + 4`. This batch does not migrate pointer dereference assignment, field stores, array element stores, string assignment, record/class assignment, `Inc/Dec` synthetic blobs, or `for` loop init/step blobs.

## Task Checklist

- [x] Confirm current commit and keep `compiler/` / `docs/inbox.md` scoped.
- [x] Map all `assign-runtime` creation paths and confirm builder `ProcessAssign` already uses `LowerNodeExprOrBlob`.
- [x] Add a focused RED test for scalar `assign-runtime.ExprId`.
- [x] Add a local sema helper that preserves the old blob and attaches `ExprId` only for plain scalar destinations.
- [x] Run focused producer/builder/model tests.
- [x] Run full rebuild and 137 LLVM smoke tests.
- [x] Update goal tree, inbox, and commit this batch.

## Decisions

- Builder needed no change in this batch: `ProcessAssign` already routes through `LowerNodeExprOrBlob`.
- The producer helper attaches `ExprId` only after the old `assign-runtime` node has been created, preserving fallback behavior.
- Destination filtering deliberately excludes dotted names, strings, arrays, records, and class/interface variables. Those cases need the C5 address/lvalue model or separate ownership semantics.
- Only the ordinary scalar assignment branch is wired. Other `assign-runtime` producers keep `ExprId = 0`.

## Progress Log

- Started from commit `61fd7ad6`.
- RED: `test_semantic_hir_expr_producer.pas` was extended with `x := x + 4` and failed with `EXIT_CODE=43`, confirming the selected `assign-runtime` node had no structured expression.
- GREEN: added `AddScalarAssignRuntimeNode` inside `WalkHaltCalls` and wired the final plain scalar assignment path through it.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43753 lines compiled`; LLVM smoke reported `passed=137 failed=0`.

## Next Step

C3-B6 should decide whether to finish another safe scalar producer slice or stop C3 and move to C4. The main remaining debt before C4 is that some scalar-looking assignment producers are still synthetic blobs (`Inc/Dec`, `for` init/step), and all address/lvalue cases must remain for C5.
