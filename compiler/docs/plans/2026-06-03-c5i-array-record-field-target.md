# C5-I array record field target

**Goal:** Lower the first nested lvalue chain for array-of-record fields: `arr[i].Field := rhs`.

**Scope:** This slice covers direct runtime arrays whose element type is a record and whose field store target is a single field access over an array element. It preserves legacy operand/blob fallback. It does not cover field arrays such as `self.Items[i]`, deeper chains such as `arr[i].A.B`, array-of-record values as first-class values, or class/object RHS special branches.

## Checklist

- [x] Confirm the current checkout and avoid the parallel toolchain/targets/stage0/verify lane.
- [x] Add RED coverage for `arr[i].Field := rhs` target structure and RHS scalar `ExprId`.
- [x] Let `shekArrayElem` carry the semantic array element type instead of hard-coded `Integer`.
- [x] Allow aggregate array elements to lower as addresses, while value loads still require concrete HIR scalar type.
- [x] Build `shekField -> shekArrayElem -> index` for array-of-record field stores.
- [x] Add builder coverage proving nested target lowering bypasses legacy index blobs.
- [x] Run focused compiler tests, full rebuild, and all LLVM smoke tests.
- [x] Update goal tree, inbox, task/progress docs, and commit.

## Decisions

- No new expression kind is needed for `arr[i].Field`; `shekField` can compose over `shekArrayElem`.
- `shekArrayElem` remains an address expression. For aggregate element types, builder may carry `TypeId=0` at HIR level for address-only use; attempting to load it as a scalar value still fails and falls back.
- This is the first C5 nested lvalue chain slice. Field arrays and deeper field chains remain separate C5 follow-ups.

## RED Evidence

- `test_semantic_hir_expr_producer` exited `173`, proving `arr[i].Y := y + 1` had no structured `TargetExprId`.

## Verification Evidence

- Changed tests:
  - `test_hir_builder_structured_address` and `test_semantic_hir_expr_producer` ran with `changed_failed=0`.
- Focused:
  - 9 focused compiler tests ran with `focused_failed=0`.
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - `46013 lines compiled`.
- LLVM smoke:
  - `smoke_count=137 passed=137 failed=0`.
- Whitespace:
  - `git diff --check` clean.

## Verification Plan

- Focused compiler tests:
  - `test_semantic_hir_expr`
  - `test_hir_builder_structured_expr`
  - `test_hir_builder_expr_fallback`
  - `test_semantic_scalar_facts`
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_structured_signedness`
  - `test_hir_builder_structured_address`
  - `test_semantic_hir_expr_producer`
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - Must show `40000+ lines compiled`.
- Full smoke:
  - All `examples/smoke/llvm_*.pas`
  - Each executable must exit `42`.

## Next

After C5-I passes, continue with field arrays (`self.Items[i]`) or deeper nested field chains (`arr[i].A.B`) as separate slices.
