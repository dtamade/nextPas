# C5-E field store RHS slice

**Goal:** Let existing field-store nodes consume structured RHS expressions while preserving the old target operand contract.

**Scope:** This slice migrates the RHS value path for `field-store-runtime` and `record-field-store-runtime`. It covers ordinary scalar class/self field stores and record field stores such as `FValue := AInit + 1` and `p.X := y + 5`. The LHS target still comes from the existing node kind plus legacy operand text; this slice does not add a target/address ExprId field.

## Checklist

- [x] Add RED builder coverage proving `field-store-runtime.ExprId` is consumed instead of fallback `int 0`.
- [x] Add RED producer coverage for class/self field store RHS.
- [x] Add RED producer coverage for record field store RHS.
- [x] Lower field-store RHS through `LowerNodeExprOrBlobTyped`.
- [x] Normalize typed integer RHS values back to the current legacy i64 field-slot ABI.
- [x] Attach RHS `ExprId` to existing field-store and record-field-store producers where `BuildRuntimeScalarHirExpr` supports the RHS.
- [x] Run focused C3/C4/C5 tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update the compiler goal tree and `docs/inbox.md`.

## Decisions

- `TTypedHirNode.ExprId` remains the RHS expression for this slice. It is not reused as an LHS target/address channel.
- Field targets stay encoded by `field-store-runtime` / `record-field-store-runtime` operands. This keeps C5-E small and avoids changing the typed HIR node contract before nested lvalue chains are designed.
- Builder field stores now try structured RHS lowering first and fall back to `ParseIntBlob` when `ExprId` is absent or unsupported.
- Non-pointer field slots still store through the legacy i64 ABI. Typed i32/i8/etc. RHS values are widened/truncated in builder before store, instead of relying on emitter guesses.

## Verification

- RED:
  - `test_hir_builder_structured_address` exited `2` before implementation because `field-store-runtime` still parsed fallback `int 0`.
  - `test_semantic_hir_expr_producer` exited `203` before implementation for record field store RHS with no `ExprId`.
  - `test_semantic_hir_expr_producer` exited `213` before implementation for class/self field store RHS with no `ExprId`.
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
- Full compiler rebuild: `45316 lines compiled`
- LLVM smoke: `smoke_count=137 passed=137 failed=0`

## Next

Continue C5 with the real LHS target model: ordinary `record.field` / `class.field` as structured address expressions, nested field chains, array stores, and static array addresses. The next slice should introduce target/address structure deliberately instead of overloading RHS `ExprId`.
