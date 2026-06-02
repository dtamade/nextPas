# C5-K0 constructor arg classification redpoint

**Goal:** Fix the LLVM verifier redpoint where `TRect.Create(P.GetX, P.GetY)` passed integer method results as `ptr` constructor arguments.

**Scope:** This is a narrow regression fix in constructor call lowering. It does not migrate a new producer, does not change generic nested method-call lowering, and keeps blob fallback intact.

## Checklist

- [x] Confirm checkout safety and avoid `core/` plus the parallel toolchain/targets/stage0/verify lane.
- [x] Reproduce `test_obj_compose` and capture the bad LLVM call shape.
- [x] Compare `test_nested_method` to prove generic nested method-call lowering still works.
- [x] Add RED coverage for constructor arguments sourced from nested integer method calls.
- [x] Fix `ProcessClassNew` argument classification to preserve the typed blob result instead of re-inferring type from receiver/internal lines.
- [x] Run focused compiler tests, full rebuild, and all LLVM smoke tests.
- [x] Update goal tree, inbox, task/progress docs, and commit.

## Decisions

- The fix stays in `THIRBuilder.ProcessClassNew`; sema and emitter are unchanged.
- `ProcessClassNew` now consumes the final `TypeId` produced by blob parsing, so constructor arguments reuse the same typed stack truth already used inside `ParseIntBlob`.
- A direct pointer variable still lowers as a pointer argument.
- A nested call blob such as `var P` followed by `call/vcall ...` is classified by its final typed call result, not by the receiver line.

## RED Evidence

- `examples/smoke/test_obj_compose.pas` failed in `opt` at `test_obj_compose.ll:24`:
  `TRect.Create` was called as `ptr, ptr, ptr` while the definition is `ptr, i64, i64`.
- `test_semantic_hir_expr_producer` exited `148`, proving the new focused test saw `, ptr ` in the `TRect.Create` argument list.

## Verification Evidence

- RED/GREEN:
  - RED `test_semantic_hir_expr_producer` exit `148`.
  - GREEN `test_semantic_hir_expr_producer` exit `0`.
- Added focused regression for pointer-return ordinary member-call constructor args:
  `THolder.Create(Second.NextNode)` must still lower as `ptr`.
- Focused:
  - 7 focused compiler tests ran with `focused_failed=0`.
- Redpoint:
  - `test_obj_compose` now emits `call i64 @TRect.Create(ptr ..., i64 ..., i64 ...)`.
  - `test_nested_method` still emits `call i64 @TCalc.AddTo(ptr ..., i64 ...)`.
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - `46258 lines compiled`.
- LLVM smoke:
  - `smoke_total=137 passed=137 failed=0 build_failed=0 run_failed=0`.

## Next

Continue C5 with a separate narrow slice for deeper field chains (`arr[i].A.B`) or field-array value loads (`Result := FItems[i]`).
