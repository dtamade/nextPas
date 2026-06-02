# C5-G array store target slice

**Goal:** Use the independent structured LHS target channel for ordinary dynamic array element stores.

**Scope:** This slice covers simple runtime dynamic array stores such as `arr[i] := rhs` where `arr` is a runtime `array of Integer`. The builder prefers `TargetExprId` for the element address and keeps the old operand/blob path as fallback. Sema attaches `TargetExprId` for the ordinary integer array-store producer. This does not migrate static arrays, field arrays (`self.arr[i]`), array-of-record field stores, nested lvalue chains, or object-construction RHS branches.

## Checklist

- [x] Add RED builder coverage proving a bad legacy array target is bypassed when `TargetExprId` is present.
- [x] Add RED producer coverage proving `arr[i] := rhs` gets a `shekArrayElem` target expression.
- [x] Lower ordinary `assign-arr-elem-runtime` targets through `LowerExprAddress(TargetExprId)` before falling back to legacy operand parsing.
- [x] Attach sema target expressions for ordinary dynamic array element stores.
- [x] Run focused tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update the compiler goal tree and `docs/inbox.md`.

## Decisions

- `TargetExprId` remains the only LHS address channel. `ExprId` is still the RHS value channel and is not repurposed for stores.
- Ordinary dynamic array element targets use `shekArrayElem` with `ValueClass=shvcAddress`; the index child remains a scalar expression, usually `shekSymbolValue`.
- The builder only takes the structured target path after it has parsed enough of the legacy operand to find the RHS blob. It does not parse the legacy index when `TargetExprId` succeeds.
- Stores continue to use the existing legacy slot ABI: typed integer RHS values are normalized to the legacy integer store type; pointer RHS values still store as pointer.
- Field arrays, static arrays, array-of-record fields, and class/object special RHS paths stay on the old path until the next C5 slices give them precise address/type metadata.

## Verification

- RED:
  - `test_hir_builder_structured_address` exited `6` before implementation because the old array-store path parsed the bad legacy index `const:99`.
  - `test_semantic_hir_expr_producer` exited `233` before implementation because `assign-arr-elem-runtime.TargetExprId` was still `0`.
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
- Full compiler rebuild: `45618 lines compiled`
- LLVM smoke: `smoke_count=137 passed=137 failed=0`

## Next

Continue C5 with static array targets and nested lvalue chains. The next slice should decide whether static array addressing reuses `shekArrayElem` with richer base metadata or needs a distinct semantic shape before adding more producers.
