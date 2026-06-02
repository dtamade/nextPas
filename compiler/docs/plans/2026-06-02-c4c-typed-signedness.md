# C4-C typed signedness

**Goal:** Make already-typed integer expressions emit the correct signed or unsigned LLVM opcodes.

**Scope:** This slice keeps the semantic model and producer surface unchanged. It only teaches the LLVM emitter to choose signedness-sensitive opcodes from typed HIR operand types:

- unsigned integer `div/mod` -> `udiv/urem`
- unsigned ordered integer compare -> `ult/ule/ugt/uge`
- signed integer paths keep `sdiv/srem/slt/sle/sgt/sge`

It does not yet add sema-side promotion rules, new producer migrations, or `int -> bool` / pointer / float cast logic.

## Checklist

- [x] Add a RED test for typed unsigned `div/mod/<` emission.
- [x] Classify typed integer signedness in the LLVM emitter.
- [x] Keep signed integer emission unchanged.
- [x] Keep blob fallback and existing structured producer paths unchanged.

## Decisions

- C4-C first cuts at the last stage that still hardcoded signed semantics: LLVM emission.
- Signedness truth comes from the typed HIR operand type already created by C4-A/C4-B. The emitter does not infer from literals or source syntax.
- This round intentionally does not invent new HIR kinds. Existing `hikDiv` / `hikMod` / `hikCmpLt..Ge` stay generic; the emitter chooses the concrete LLVM opcode.
- Promotion and cast insertion still belong to sema and remain the next C4 slice.

## Verification

- Focused fresh tests:
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_structured_signedness`
  - `test_hir_builder_expr_fallback`
  - `test_hir_builder_structured_expr`
  - `test_semantic_hir_expr_producer`
- Full compiler rebuild: `44352 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

The remaining C4 work is sema-side promotion truth:

1. decide common result types for mixed-width scalar expressions
2. materialize explicit `shekCast` nodes in sema
3. widen producer coverage without regressing blob fallback safety
