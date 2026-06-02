# C5-C array element address slice

**Goal:** Add the first structured lvalue chain for dynamic array element addresses.

**Scope:** This slice supports source-level `@arr[i]` for runtime `array of Integer` variables. It lowers the array element as an address with `shekArrayElem`, then wraps it with `shekAddressOf` when the source expression takes its address. It does not migrate record/class fields, array element stores, static arrays, generic pointee metadata, or `P^.Field`.

## Checklist

- [x] Confirm C5-B `@x` / `p^` producer baseline.
- [x] Add RED builder coverage for `shekArrayElem` address lowering.
- [x] Add RED producer coverage for `p := @arr[i]`.
- [x] Lower `shekArrayElem` through existing `arr$ptr` storage and `gep_i64`.
- [x] Add temporary blob fallback token `arr_elem_ref` for array element addresses.
- [x] Generate `shekArrayElem -> shekAddressOf` from sema for `@arr[i]`.
- [x] Run focused C3/C4/C5 tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update the compiler goal tree and `docs/inbox.md`.

## Decisions

- `shekArrayElem` carries `SymbolId` for the array variable and one child for the index expression. Its `TypeId` is the element type for this slice (`Integer`), and its `ValueClass` is `shvcAddress`.
- Builder lowering loads `arr$ptr`, normalizes the index to the legacy i64 runtime index type, emits `gep_i64`, and returns the resulting element address.
- `@arr[i]` produces `shekAddressOf` over the `shekArrayElem` address. Existing C5-B `p^` then consumes the pointer value as before.
- `arr_elem_ref` is a temporary fallback blob token so old-path lowering remains available if structured lowering cannot run. It should not become the primary architecture.

## Verification

- RED:
  - `test_hir_builder_structured_address` exited `2` before implementation because `shekArrayElem` fell back to the old `int 0` blob.
  - `test_semantic_hir_expr_producer` exited `182` before implementation because `p := @arr[i]` had no fallback operand or structured expression.
- Focused fresh tests:
  - `test_semantic_hir_expr`
  - `test_hir_builder_structured_expr`
  - `test_hir_builder_expr_fallback`
  - `test_semantic_scalar_facts`
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_structured_signedness`
  - `test_hir_builder_structured_address`
  - `test_semantic_hir_expr_producer`
  - Result: `focused_failed=0`
- Full compiler rebuild: `44967 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

Continue C5 with the field side of the lvalue chain, most likely `P^.Field`. That needs field offset metadata in the structured expression path, while preserving fallback for unsupported record/class cases.
