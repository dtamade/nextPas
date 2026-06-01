# C3-B3 Ret Runtime Expression Producer Plan

**Goal:** Extend the sema producer migration by attaching structured `ExprId` to `ret-runtime` nodes.

**Scope:** Only `ret-runtime` nodes that return the current runtime return variable. Keep the legacy `Operand` blob unchanged. Do not reconstruct earlier `Result := ...` assignment trees in this batch, and do not migrate `cond-br` yet.

## Task Checklist

- [x] Confirm current commit and read the `ret-runtime` producer path.
- [x] Add a focused RED test for function return producer wiring.
- [x] Choose the smallest safe structured representation for return: symbol read of the current return variable.
- [x] Attach `ExprId` on both explicit `Exit;` returns and implicit function-end returns.
- [x] Run focused producer/builder/model tests.
- [x] Run full rebuild and 137 LLVM smoke tests.
- [x] Update goal tree and commit compiler-only changes.

## Decisions

- `ret-runtime` currently models "read the return slot now", not "replay the earlier source expression". C3-B3 therefore attaches a `shekSymbolValue` for the return variable instead of trying to recover the prior `Result := ...` expression tree.
- This keeps the migration aligned with current HIR semantics and avoids inventing backtracking logic inside sema.
- String returns stay on `ret-str-runtime` and are out of scope for this batch.
- Void/procedure `ret-runtime` fallback stays on the old blob path; this batch only upgrades return-variable reads.

## Progress Log

- Started from commit `ca309fb7`.
- RED: `test_semantic_hir_expr_producer.pas` was extended with a function-return case and failed with `EXIT_CODE=23`, confirming `ret-runtime.ExprId` was still zero.
- Implementation: added `AttachRuntimeReturnExpr`, which resolves the current return variable symbol and attaches a `shekSymbolValue` expression to the `ret-runtime` node.
- Coverage: explicit `Exit;` returns and implicit function-end returns now both attach structured `ExprId` when a runtime return variable exists.
- Verification: focused tests passed; `scripts/rebuild-compiler.sh` reported `43694 lines compiled`; LLVM smoke reported `passed=137 failed=0`.

## Next Step

C3-B4 should migrate `cond-br` producer wiring. That is the next meaningful consumer because builder fallback is already in place and branch conditions still pay the blob parse cost on every runtime conditional path.
