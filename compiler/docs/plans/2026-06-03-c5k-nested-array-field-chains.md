# C5-K nested array-backed field chains

**Goal:** Lower deeper array-backed store targets such as `arr[i].A.B := rhs` and
`Self.FItems[i].A.B := rhs` through the structured address/value contract.

**Scope:** This slice covers nested field chains rooted in direct arrays and current-class
field arrays. It keeps `ExprId` as RHS-only, keeps `TargetExprId` as LHS-only, and preserves
legacy blob fallback by flattening array-backed field offsets into the old slot-index form.
It does not migrate value-side loads such as `x := arr[i].A.B` or `Result := FItems[i]`.

## Checklist

- [x] Confirm checkout safety and avoid `core/` plus the parallel toolchain/targets/stage0/verify lane.
- [x] Add RED producer coverage for `arr[i].A.B := rhs` and `Self.FItems[i].A.B := rhs`.
- [x] Add RED builder coverage for aggregate intermediate `shekField` addresses.
- [x] Generalize sema target construction from one-level helpers to a recursive address builder.
- [x] Generalize array-backed field-store producer routing so deeper chains still build runtime nodes.
- [x] Keep legacy fallback meaningful by flattening nested field offsets into the old array slot-index blob.
- [x] Let builder lower aggregate intermediate `shekField` nodes as address-only results while preserving scalar-load guards.
- [x] Run changed tests, focused compiler tests, full rebuild, and all LLVM smoke tests.
- [x] Update goal tree, inbox, task/progress docs, and commit.

## Decisions

- No new expression kind is needed. Nested chains are represented by repeated `shekField` over an address-producing base.
- `BuildTargetAddressExpr` becomes the shared sema seam for direct arrays, field arrays, record vars, class vars, and nested dot chains.
- `assign-arr-elem-runtime` remains the runtime node kind for array-backed field stores; the structured path carries the true target address and the fallback operand keeps the old flattened slot-index shape.
- Builder `shekField` now allows aggregate intermediate addresses with semantic `TypeId` but no concrete scalar HIR type. Value loads still require a concrete lowered type, so aggregate-as-value remains guarded.

## RED Evidence

- `test_hir_builder_structured_address` exited `6`, proving nested targets still fell through to legacy `const:99/123` poison.
- `test_semantic_hir_expr_producer` exited `222`, proving `arr[i].A.B := y + 1` did not yet even build the expected `assign-arr-elem-runtime` node.

## Verification Evidence

- Changed tests:
  - `test_hir_builder_structured_address` exits `0`.
  - `test_semantic_hir_expr_producer` exits `0`.
- Focused:
  - 9 focused compiler tests ran with `focused_failed=0`.
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - `46508 lines compiled`.
- LLVM smoke:
  - `smoke_total=137 passed=137 failed=0 build_failed=0 run_failed=0`.

## Next

Continue C5 with the value side of the same contract: array/field-array value loads and remaining class/object RHS special branches.
