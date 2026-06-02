# C5-F field store target slice

**Goal:** Add an independent structured LHS target channel for field stores without changing the old blob fallback behavior.

**Scope:** This slice introduces `TTypedHirNode.TargetExprId` and uses it for `field-store-runtime` / `record-field-store-runtime` target addresses. It covers ordinary `record.field := rhs`, method `self.field := rhs`, and method `obj.field := rhs`. RHS still uses `ExprId`; array stores, static arrays, and nested field chains remain future work.

## Checklist

- [x] Add RED model coverage for `TargetExprId`.
- [x] Add RED builder coverage proving bad legacy field-store targets can be bypassed by structured target lowering.
- [x] Add RED producer coverage for record field store targets.
- [x] Add RED producer coverage for self/class field store targets.
- [x] Add RED producer coverage for ordinary object field store targets inside a method.
- [x] Add `TTypedHirNode.TargetExprId` and a semantic model setter.
- [x] Lower field-store targets through `LowerExprAddress(TargetExprId)` before falling back to legacy operand parsing.
- [x] Attach sema target expressions for record, self, and object field stores.
- [x] Run focused tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update the compiler goal tree and `docs/inbox.md`.

## Decisions

- `ExprId` remains the RHS value channel. `TargetExprId` is a separate LHS address channel so future nested lvalue chains do not overload RHS semantics.
- Record field targets are encoded as `shekField -> shekSymbolAddress`.
- Class and self field targets are encoded as `shekField -> shekDeref -> shekSymbolValue`.
- Aggregate `shekSymbolAddress` may lower as an address even when its semantic TypeId has no scalar HIR type. Value lowering still requires a concrete scalar type before load.
- Class field indexes follow the existing object layout: slot 0 is object metadata/VMT, so the first user field is index 1.

## Verification

- RED:
  - `test_semantic_hir_expr` failed to compile before implementation because `SetTypedHirNodeTargetExprId` and `TargetExprId` did not exist.
  - `test_hir_builder_structured_address` failed to compile before implementation because `SetTypedHirNodeTargetExprId` did not exist.
  - `test_semantic_hir_expr_producer` failed to compile before implementation because `TargetExprId` did not exist.
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
- Full compiler rebuild: `45545 lines compiled`
- LLVM smoke: `smoke_count=137 passed=137 failed=0`

## Next

Continue C5 by migrating array store targets and nested lvalue chains. The next slice should keep `TargetExprId` as the LHS address channel and avoid adding more string target encodings.
