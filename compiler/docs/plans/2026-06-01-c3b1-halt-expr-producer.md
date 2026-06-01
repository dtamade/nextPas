# C3-B1 Halt Expression Producer Plan

**Goal:** Migrate the first sema producer slice by attaching structured `ExprId` to `halt-call-runtime` nodes for simple scalar expressions.

**Scope:** Only `Halt(expr)` in no-fold/runtime lowering. Keep the legacy blob in `TTypedHirNode.Operand`. Do not migrate assignment, return, write-int, or conditional branches in this batch.

## Task Checklist

- [x] Confirm current commit and `compiler/` cleanliness.
- [x] Re-read C3-A builder contract and C3 target.
- [x] Identify the lowest-risk producer consumer pair: `Halt(expr)` -> `ProcessHaltCall`.
- [x] Add focused tests that fail until sema can attach `ExprId` for simple halt expressions.
- [x] Implement a small sema structured-expression encoder for literals, runtime vars, arithmetic, comparisons, and bool operators.
- [x] Wire only `halt-call-runtime` creation to set `ExprId` when encoder succeeds.
- [x] Run focused tests.
- [x] Run full rebuild and 137 LLVM smoke tests.
- [x] Update goal tree and commit compiler-only changes.

## Decisions

- C3-B is split into smaller slices. C3-B1 migrates only `Halt(expr)` to keep the producer blast radius small.
- The blob stays authoritative as fallback and as behavior parity material.
- Unsupported expressions keep `ExprId = 0`; supported structured expressions still carry the old `Operand` blob.
- Runtime variables are preserved as `shekSymbolValue` even when sema has a known var-init value. This keeps the structured expression faithful to the runtime expression and avoids reintroducing blob-era type/value flattening.

## Progress Log

- Started from commit `137343fd` after C3-A.
- `compiler/` was clean before this batch; non-compiler dirty files are ignored.
- Added `test_semantic_hir_expr_producer.pas`, which runs lexer -> green tree -> sema and verifies `Halt(x + 4)` produces a `halt-call-runtime` node with non-zero `ExprId` while retaining the legacy blob operand.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43662 lines compiled`; LLVM smoke reported `passed=137 failed=0`.
