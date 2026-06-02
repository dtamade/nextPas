# C4-B structured scalar casts

**Goal:** Add structured scalar cast nodes so typed HIR lowering can express width changes without collapsing back to blob text.

**Scope:** This slice adds `shekCast`, builder cast classification/lowering, and LLVM emitter support for `trunc` / `zext` / `sext`. It does not migrate new sema producers yet, and it does not implement signed/unsigned arithmetic or compare opcode splits.

## Checklist

- [x] Add a RED test for structured `zext` / `sext` / `trunc`.
- [x] Add `shekCast` to the semantic HIR expression model.
- [x] Teach the HIR builder to classify safe scalar casts and lower them to typed HIR instructions.
- [x] Keep unsupported structured casts on the blob fallback path.
- [x] Emit typed `trunc` and `sext` in LLVM IR.

## Decisions

- `shekCast` is an explicit semantic node. The builder consumes it; it does not invent implicit promotions for mixed-width arithmetic.
- C4-B only covers scalar width-changing casts that are locally unambiguous:
  - `bool -> int` uses `zext`
  - `unsigned int widen` uses `zext`
  - `signed int widen` uses `sext`
  - `int narrow` uses `trunc`
- `int -> bool`, pointer casts, float casts, and signed/unsigned arithmetic predicate splits remain out of scope here. They must still fall back until later C4 slices land.
- Existing producers remain unchanged. `ExprId = 0` and unsupported casts continue to defer to legacy blob lowering.

## Verification

- Focused fresh tests:
  - `test_semantic_scalar_facts`
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_expr_fallback`
  - `test_hir_builder_structured_expr`
  - `test_semantic_hir_expr_producer`
- Full compiler rebuild: `44265 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

C4-C should move signedness truth into typed lowering: `sdiv/udiv`, `srem/urem`, signed/unsigned `icmp`, and the sema-side promotion rules that decide when to materialize `shekCast`.
