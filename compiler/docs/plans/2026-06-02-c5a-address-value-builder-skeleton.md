# C5-A address/value builder skeleton

**Goal:** Start C5 by making structured expression lowering distinguish lvalue addresses from scalar values.

**Scope:** This slice is builder-only. It supports the first address/value structured expression forms already present in `TSemanticHirExprKind`: `shekSymbolAddress`, `shekAddressOf`, and `shekDeref`. It does not migrate sema producers yet, and it does not implement field or array element address chains.

## Checklist

- [x] Audit existing `ValueClass`, `THIRExprResult.AddressValueId`, `LowerExprValue`, and `LowerExprAddress` behavior.
- [x] Add RED coverage for `y := (@x)^` built from structured address/value nodes.
- [x] Implement builder address lowering for symbol addresses, address-of, and dereference.
- [x] Keep unsupported field/array/string address nodes on the blob fallback path.
- [x] Run focused C5/C4 tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update `compiler-goal-tree.md`, keep `docs/inbox.md` current, and commit this slice.

## Decisions

- `shekSymbolAddress` is an lvalue node. Its `TypeId` is the pointee/value type, `ValueClass` is `shvcAddress`, and lowering fills `AddressValueId`.
- `shekAddressOf` converts an lvalue child into a scalar pointer value. Its child must lower as an address.
- `shekDeref` is naturally an lvalue. Address lowering returns the pointer value produced by its child; value lowering loads from that address.
- C5-A deliberately avoids sema producer migration. The producer layer can start attaching these nodes only after builder behavior is stable and tested.

## Verification

- RED:
  - `test_hir_builder_structured_address` exited `2` before builder address/value lowering because `y := (@x)^` fell back to the legacy `int 0` blob.
- Focused fresh tests:
  - `test_hir_builder_structured_address`
  - `test_semantic_scalar_facts`
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_structured_signedness`
  - `test_hir_builder_expr_fallback`
  - `test_hir_builder_structured_expr`
  - `test_semantic_hir_expr_producer`
- Full compiler rebuild: `44709 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

Migrate one sema producer slice that naturally creates address nodes. The likely next candidate is `@x` / `P^` scalar pointer expressions, before field and array chains.
