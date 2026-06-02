# C4-D sema promotion casts

**Goal:** Move integer mixed-width promotion decisions into sema and materialize explicit `shekCast` nodes for structured scalar expressions.

**Scope:** This slice updates the structured expression producer for already-migrated runtime scalar surfaces. It keeps old blob operands in place and does not retag `var-decl-runtime` allocas yet.

## Checklist

- [x] Add RED coverage for mixed-width sema promotion and explicit `shekCast` materialization.
- [x] Give runtime scalar literals, variables, unary expressions, binary integer expressions, and comparisons concrete semantic `TypeId`s where facts are available.
- [x] Promote mixed integer operands to a common semantic type before lowering.
- [x] Insert `shekCast` children when operands need `zext`, `sext`, or `trunc` in the builder.
- [x] Normalize typed runtime arguments for legacy i64 helpers (`Halt`, `Write/WriteLn` integer output).
- [x] Preserve blob fallback for unsupported or unsafe structured expressions.

## Decisions

- `var-decl-runtime` TypeIds stay on the legacy path for now. Old blob stores still produce legacy i64 values, so switching allocas to i8/i16/i32 too early would make mixed old/new stores harder to reason about.
- Promotion is sema-owned. The builder lowers explicit `shekCast` nodes; it does not guess common types from operand syntax.
- Mixed signed/unsigned integer promotion uses the next signed width when the signed side cannot already represent the unsigned side. Cases with no safe wider signed integer still fall back to blob.
- Runtime helpers that still expose an i64 ABI are normalized in the HIR builder, not by weakening the typed expression tree back to i64.

## Verification

- RED:
  - `test_semantic_hir_expr_producer` exited `75` before sema promotion implementation.
  - `test_semantic_hir_expr_producer` exited `122` before typed `Halt(Integer)` i64 normalization.
  - `test_semantic_hir_expr_producer` exited `132` before typed `WriteLn(Integer)` i64 normalization.
- Focused fresh tests:
  - `test_semantic_scalar_facts`
  - `test_hir_builder_structured_widths`
  - `test_hir_builder_structured_casts`
  - `test_hir_builder_structured_signedness`
  - `test_hir_builder_expr_fallback`
  - `test_hir_builder_structured_expr`
  - `test_semantic_hir_expr_producer`
- Full compiler rebuild: `44536 lines compiled`
- LLVM smoke: `passed=137 failed=0`

## Next

Before entering C5, do a short C4-E audit of the remaining legacy i64 boundaries:

1. scalar return/function-call ABI surfaces
2. typed alloca timing for `var-decl-runtime`
3. string/int conversion helpers that still deliberately parse old blob operands
