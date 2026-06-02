# C5-D pointer field address slice

**Goal:** Add the first structured field offset chain for `P^.Field`.

**Scope:** This slice supports pointer-dereference field addresses such as `@p^.Value`. The structured path is `shekAddressOf -> shekField -> shekDeref -> shekSymbolValue`. The field node is an address node; value use is handled by `LowerExprValue` loading that address.

## Checklist

- [x] Add RED builder coverage for `shekField` address lowering from a pointer-deref base.
- [x] Add RED producer coverage for `@p^.Field`.
- [x] Allow aggregate `shekDeref` nodes to lower as addresses even when their pointee TypeId has no scalar HIR type.
- [x] Lower `shekField` through base address + field index `gep_i64`.
- [x] Track `^Type` pointee metadata for runtime pointer variables.
- [x] Add temporary blob fallback token `field_ref` for field addresses.
- [x] Generate `shekAddressOf -> shekField -> shekDeref -> shekSymbolValue` from sema for `@p^.Field`.
- [x] Run focused C3/C4/C5 tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update the compiler goal tree and `docs/inbox.md`.

## Decisions

- `shekField` carries one child: the base address expression. `LiteralInt` is the field slot index, `LiteralStr` is the field name, `TypeId` is the field value type, and `ValueClass` is `shvcAddress`.
- `shekDeref` may now carry a non-scalar pointee TypeId when it is used as an address base. Direct value lowering still requires a concrete field/scalar type before load.
- Pointer pointee metadata is tracked locally in sema for runtime `^Type` variables. This avoids changing the builtin `Pointer` type model during this slice.
- `field_ref` is a temporary fallback blob token. It keeps the dual-track contract intact, but structured field lowering is the architecture direction.

## Verification

- RED:
  - `test_hir_builder_structured_address` exited `2` before implementation because `shekField` fell back to the old `int 0` blob.
  - `test_semantic_hir_expr_producer` exited `192` before implementation because `ip := @p^.Value` had no fallback operand or structured expression.
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
- Full compiler rebuild: `45252 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

Continue C5 with the remaining lvalue chain pieces: field stores, ordinary `record.field` / `class.field` structured producers, nested field chains, static arrays, and array stores.
