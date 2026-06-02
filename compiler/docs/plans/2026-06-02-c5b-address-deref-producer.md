# C5-B address/deref sema producer slice

**Goal:** Migrate the first C5 sema producer slice for scalar pointer expressions while keeping the old blob path intact.

**Scope:** This slice attaches structured `ExprId` for source-level `@x` and `p^` in runtime scalar assignment expressions. It does not add field, array element, class/record address chains, or precise pointer pointee metadata.

## Checklist

- [x] Confirm C5-A builder address/value skeleton is the current baseline.
- [x] Add RED producer coverage for `p := @x; y := p^;`.
- [x] Keep legacy `Operand` blobs (`varref`, `deref`) unchanged.
- [x] Generate `shekSymbolAddress -> shekAddressOf` for `@identifier`.
- [x] Generate `shekDeref` with a `Pointer` scalar child for pointer dereference reads.
- [x] Run focused C3/C4/C5 tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update the compiler goal tree and `docs/inbox.md`.

## Decisions

- `@identifier` is only structured when the identifier is a runtime variable with an addressable scalar semantic type. The structured root is `shekAddressOf` with `shvcScalar` and `Pointer` type; its child is `shekSymbolAddress` with `shvcAddress`.
- `p^` is structured as `shekDeref` with `shvcAddress`. Builder value lowering remains responsible for loading from that address when the expression is consumed as a scalar value.
- Pointer variables in this slice are represented by the builtin `Pointer` type fact. Exact pointee metadata is not introduced here; `p^` is limited to the scalar `Integer` read path covered by the producer test and existing smoke suite.
- The old string blob remains authoritative fallback. If structured lowering cannot prove support, `LowerNodeExprOrBlobTyped` still falls back to `ParseIntBlob`.

## Verification

- RED:
  - `test_semantic_hir_expr_producer` exited `153` before implementation because `p := @x` had no structured `ExprId`.
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
- Full compiler rebuild: `44805 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

Continue C5 with address-chain nodes for field and array element paths. The next likely slice is to model one lvalue chain at a time, starting from either `@Arr[i]` or `P^.Field`, while preserving blob fallback for unsupported chains.
