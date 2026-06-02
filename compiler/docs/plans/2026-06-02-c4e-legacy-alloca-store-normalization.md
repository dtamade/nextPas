# C4-E legacy alloca store normalization

**Goal:** Close the immediate C4-D hazard where typed scalar values could be stored at their expression width into a legacy i64 alloca slot.

**Scope:** This slice only normalizes structured typed scalar assignment values to the existing alloca store type. It does not switch `var-decl-runtime` allocas to true width, and it does not migrate lvalue/address, function-call, or return ABI behavior.

## Checklist

- [x] Add RED coverage for `Integer` function-result assignment writing a typed i32 value into a legacy i64 alloca.
- [x] Generalize runtime i64 normalization into a target-type scalar normalization helper.
- [x] Make normal `assign-runtime` alloca stores choose the alloca slot type first, then cast the structured value to that target type.
- [x] Preserve blob fallback if structured normalization cannot classify the cast.
- [x] Keep varparam and indirect `*name` assignments on their current behavior for this slice.
- [x] Run focused C4 tests, full compiler rebuild, and all LLVM smoke tests.

## Decisions

- Existing storage type wins over expression type at the store boundary. A typed i32 expression assigned to a legacy i64 slot must become `sext/zext/trunc` plus `store i64`, not `store i32`.
- The builder owns this compatibility normalization because the old blob path and runtime ABI are still i64. Sema should keep describing the expression truth; storage compatibility is a lowering boundary.
- `var-decl-runtime` true-width alloca switching stays delayed. Moving storage width globally before C5 would mix old blob writes, typed lvalue loads, and address expressions without a complete address/value model.
- Unsupported structured normalization still falls back to the old blob operand. This keeps the C2 dual-track contract intact.

## Verification

- RED:
  - `test_semantic_hir_expr_producer` exited `142` before the store normalization fix because generated IR still contained `store i32`.
- Focused fresh tests:
  - `test_semantic_scalar_facts`
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_structured_signedness`
  - `test_hir_builder_expr_fallback`
  - `test_hir_builder_structured_expr`
  - `test_semantic_hir_expr_producer`
- Full compiler rebuild: `44547 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

Enter C5. The next architectural slice should introduce the lvalue/address model (`EmitAddress` vs `EmitValue`) instead of continuing to patch address-like blob strings one case at a time.
