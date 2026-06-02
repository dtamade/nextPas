# C5-H static array target/address

**Goal:** Attach structured target/address expressions for direct static array element stores and addresses, building on C5-H0 bounds metadata and backing storage.

**Scope:** This slice covers direct static arrays such as `var arr: array[1..3] of Integer;` with `arr[i] := rhs` and `@arr[i]`. It preserves the legacy operand/blob fallback. It does not cover field arrays, array-of-record fields, class/object RHS special branches, or nested lvalue chains.

## Checklist

- [x] Confirm the current checkout and avoid the parallel toolchain/targets/stage0/verify lane.
- [x] Add RED coverage for static array store producer: LHS `TargetExprId` plus RHS `ExprId` while retaining old operand blob.
- [x] Add explicit coverage for static `@arr[i]` address producer.
- [x] Attach scalar RHS `ExprId` in the direct array element store runtime producer.
- [x] Run focused compiler tests, full rebuild, and all LLVM smoke tests.
- [x] Update goal tree, inbox, task/progress docs, and commit.

## Decisions

- `shekArrayElem` remains the element-address expression kind for both dynamic and static arrays.
- Static-vs-dynamic addressing stays data-driven through C5-H0 metadata (`arr_low`, `arr_len`, backing storage) rather than adding a new expression kind.
- `TargetExprId` remains the LHS address channel; `ExprId` is now also attached for direct array store RHS when scalar lowering supports it.
- Field arrays and nested lvalue chains are deferred to C5-I+.

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

## RED Evidence

- `test_semantic_hir_expr_producer` exited `246` before the producer change, proving direct static array store nodes had no structured RHS `ExprId`.

## Verification Evidence

- Focused:
  - 9 focused compiler tests ran with `focused_failed=0`.
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - `45934 lines compiled`.
- LLVM smoke:
  - `smoke_count=137 passed=137 failed=0`.
- Whitespace:
  - `git diff --check` clean.

## Next

After C5-H passes, continue with C5-I: field arrays, array-of-record-field, and nested lvalue chain structure.
