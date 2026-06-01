# C3-B6 Inc/Dec Expression Producer Plan

**Goal:** Finish one more low-risk scalar producer slice by attaching structured `ExprId` to `Inc` / `Dec` synthetic `assign-runtime` nodes.

**Scope:** Plain scalar variable `Inc(x)`, `Inc(x, n)`, `Dec(x)`, and `Dec(x, n)` paths that already lower to an `assign-runtime` blob. This batch does not migrate field `Inc/Dec`, `for` loop init/step blobs, `call-runtime` argument blobs, pointer/lvalue assignments, or any string/array/record/class ownership case.

## Task Checklist

- [x] Confirm current commit and scoped cleanliness for `compiler/` / `docs/inbox.md`.
- [x] Map remaining scalar-looking producer paths and choose `Inc/Dec` as the only low-risk C3-B6 cut.
- [x] Add a focused RED test for `Inc(x, 4)` requiring non-zero `ExprId`.
- [x] Add focused coverage for `Dec(x, 2)`.
- [x] Preserve existing synthetic assignment blobs while attaching structured `var x +/- delta` expressions.
- [x] Run focused producer/builder/model tests.
- [x] Run full rebuild and 137 LLVM smoke tests.
- [x] Update goal tree, inbox, and commit this batch.

## Decisions

- `call-runtime` remains out of scope because it needs a structured argument-list representation; one `TTypedHirNode.ExprId` is not enough to represent multiple argument blobs.
- `for` init/step remains out of scope because those blobs are hand-built control-flow fragments rather than direct source expressions.
- `Inc/Dec` is safe because the RHS is still a single scalar value: current variable value plus or minus a scalar delta.
- The producer creates a `shekSymbolValue` for the destination, a scalar delta expression, then a `shekBinaryOp` root. Legacy blob remains present.

## Progress Log

- Started from commit `cf3100c6`.
- RED: `test_semantic_hir_expr_producer.pas` was extended with `Inc(x, 4)` and failed with `EXIT_CODE=53`, confirming the synthetic `assign-runtime` node had no structured expression.
- GREEN: added `AddIncDecAssignRuntimeNode` and explicit `add/sub` to `+/-` mapping inside `WalkHaltCalls`.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43803 lines compiled`; LLVM smoke reported `passed=137 failed=0`.

## Next Step

C3 has covered the safe single-expression runtime producer surface needed before C4. The next batch should start C4: replace the global `i64` scalar assumption with typed scalar width facts and explicit cast/sign behavior.
