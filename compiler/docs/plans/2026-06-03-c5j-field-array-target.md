# C5-J field array target

**Goal:** Lower field-array stores such as `self.FItems[i] := rhs` through the structured address/value contract.

**Scope:** This slice covers class method field arrays whose element type metadata is available from the class field declaration. It preserves the legacy `__field_arr__` operand/blob fallback. It does not cover deeper field chains such as `arr[i].A.B`, field-array value loads, object-array RHS special branches, or allocator/runtime ownership.

## Checklist

- [x] Confirm checkout safety and avoid the parallel toolchain/targets/stage0/verify lane.
- [x] Add RED coverage for field-array producer target structure.
- [x] Add RED builder coverage for base-address `shekArrayElem`.
- [x] Preserve class field array type nodes in the parser, including comma field lists.
- [x] Record class array field element metadata in sema.
- [x] Add structured field-array target producer while keeping RHS `ExprId` and LHS `TargetExprId` separate.
- [x] Teach builder `shekArrayElem` both symbol-backed and base-address-backed forms.
- [x] Ensure `__field_arr__` fallback defers blob parsing until structured target lowering fails.
- [x] Cover explicit `Self.FItems[i]` and inherited field-array metadata after read-only review.
- [x] Run focused compiler tests, full rebuild, and all LLVM smoke tests.
- [x] Update goal tree, inbox, task/progress docs, and commit.

## Decisions

- No new expression kind is needed. `shekArrayElem` remains the element-address kind.
- Existing direct arrays keep `SymbolId > 0` and one index child.
- Field arrays use `SymbolId = 0`, child 0 as the array slot address expression, and child 1 as the index expression.
- Class array field slots are typed as `Pointer` in semantic metadata because the field slot stores the dynamic array buffer pointer.
- The builder must not parse legacy field-array index/value blobs before attempting `TargetExprId`; parsing first emits stale constants even when structured lowering succeeds.
- Parser comma field lists need cloned type nodes per field so sema can attach metadata to every declared field.
- Explicit `Self.FItems[i]` is a different CST shape from implicit `FItems[i]`; producer matching must normalize both to the same current-class field-array target.

## RED Evidence

- `test_hir_builder_structured_address` exited `6`, proving base-address `shekArrayElem` fell through to the legacy `int 99` blob.
- `test_semantic_hir_expr_producer` exited `148`, proving `FItems[i] := y + 1` lacked the expected structured field-array target.
- Read-only review RED: `test_semantic_hir_expr_producer` exited `62`, proving explicit `Self.FItems[i] := y + 1` was not covered.

## Verification Evidence

- Changed tests:
  - `test_hir_builder_structured_address` exits `0`.
  - `test_semantic_hir_expr_producer` exits `0`.
- Focused:
  - 9 focused compiler tests ran with `focused_failed=0`.
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - `46248 lines compiled`.
- LLVM smoke:
  - `smoke_count=137 passed=137 failed=0`.
- Whitespace:
  - `git diff --check` clean before final commit.

## Next

Continue C5 with a separate narrow slice for deeper field chains (`arr[i].A.B`) or field-array value loads (`Result := FItems[i]`).
