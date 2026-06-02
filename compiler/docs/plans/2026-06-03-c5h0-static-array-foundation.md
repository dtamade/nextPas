# C5-H0 static array foundation

**Goal:** Give static arrays preserved bounds, semantic metadata, and real backing storage before migrating static-array target/address lowering.

**Scope:** This slice handles direct static arrays such as `array[0..2] of Integer` and `array[1..3] of Integer`. It should keep the existing `arr$ptr` / `arr$len` access path alive while making that path point at real storage for static arrays. It does not migrate nested lvalue chains, field arrays, array-of-record fields, or new producer shapes beyond the metadata needed for static arrays.

## Checklist

- [x] Add RED tests for static-array bounds metadata and static-array backing/index normalization.
- [x] Preserve `array[lo..hi] of T` bounds in `gnkArrayType` without breaking dynamic `array of T`.
- [x] Extend semantic array metadata with static/dynamic shape, lower bound, high bound, and length.
- [x] Register direct static array declarations with static metadata while preserving legacy `var-decl-arr-runtime` compatibility.
- [x] Lower static array declarations to real backing storage and initialize existing `arr$ptr` / `arr$len` channels.
- [x] Normalize static array indexes by subtracting the recorded lower bound in builder array-address paths.
- [x] Run focused tests, full compiler rebuild, and all LLVM smoke tests.
- [x] Update `compiler/docs/compiler-goal-tree.md` and `docs/inbox.md`.

## Decisions

- `C5-H` is split. Direct structured static-array target/address is deferred until after static arrays have correct semantic shape and backing storage.
- Parser should preserve bounds as an extra child on `gnkArrayType`; dynamic arrays keep only the element type child.
- Static arrays may initially reuse `var-decl-arr-runtime` and the legacy `arr$ptr` / `arr$len` runtime channel. The operand can be enriched with tab-separated static metadata because the builder already consumes `Operand`.
- Static-array storage can be allocated in the builder's current declaration lowering path and then stored into `arr$ptr`. This avoids adding global array emitter support in the same slice.
- `TargetExprId` remains the LHS address channel. `ExprId` remains RHS value only.
- `shekArrayElem` remains the array element address expression kind for now; static vs dynamic addressing is decided by semantic metadata on the symbol/base.

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

## Verification Evidence

- RED:
  - `test_hir_builder_structured_address` exited `6`.
  - `test_semantic_hir_expr_producer` exited `241`.
- Focused:
  - 9 focused compiler tests ran with `focused_failed=0`.
- Full rebuild:
  - `bash scripts/rebuild-compiler.sh`
  - `45932 lines compiled`.
- Runtime probes:
  - `static_array_global.pas` exit `42`.
  - `static_array_local.pas` exit `42`.
- LLVM smoke:
  - `smoke_count=137 passed=137 failed=0`.
- Final rerun after formatting cleanup:
  - Focused tests: `focused_failed=0`.
  - Full rebuild: `45932 lines compiled`.
  - LLVM smoke: `smoke_count=137 passed=137 failed=0`.
  - `git diff --check`: clean.

## Next

After C5-H0 passes, continue with C5-H proper: attach structured target/address expressions for static array stores and addresses, then expand to field arrays and nested lvalue chains.
