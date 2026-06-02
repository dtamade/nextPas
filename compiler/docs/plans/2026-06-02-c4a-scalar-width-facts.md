# C4-A scalar width facts

**Goal:** Start C4 by making semantic scalar width facts explicit and letting typed structured expressions lower to real HIR scalar types.

**Scope:** This slice covers semantic facts, builder TypeId-to-HIR mapping, typed structured scalar lowering, and the minimal LLVM emitter fixes needed for compare/zext output. It does not migrate existing sema producers to non-zero expression TypeIds for all scalar forms, and it does not implement implicit casts, integer promotion, or unsigned arithmetic predicates.

## Checklist

- [x] Add a RED test for semantic scalar facts.
- [x] Add a RED test for typed structured lowering of `Byte`, `Integer`, and `Boolean`.
- [x] Add `TSemanticScalarTypeFact` and scalar fact APIs to `TSemanticModel`.
- [x] Seed FPC-compatible facts for builtin scalar types, including `LongWord` and `Cardinal`.
- [x] Map semantic TypeIds to HIR types in `THIRBuilder`.
- [x] Lower structured int literals, symbol values, arithmetic, compare, and bool logic using typed HIR values.
- [x] Keep TypeId-less structured expressions on the safe fallback path.
- [x] Emit typed `icmp` and `zext` instead of hardcoded `i64`.

## Decisions

- `TSemanticModel` is the source of scalar width truth. The builder consumes facts; it does not infer widths from type names.
- `GetIntType` remains the legacy blob integer type and still returns signed i64. New typed lowering uses `SemanticTypeIdToHirTypeId`.
- `Expr.TypeId = 0` or a missing scalar fact makes structured lowering decline the expression, so existing blob behavior remains authoritative.
- C4-A intentionally avoids implicit casts. If binary operands do not already have the same HIR type, lowering fails and falls back.
- `Boolean` maps to HIR bool (`i1`), `Byte`/`Word`/`LongWord`/`QWord` preserve unsigned facts, and `Integer`/`LongInt` map to signed i32.

## Verification

- Focused TDD tests cover semantic facts and typed structured lowering.
- Full compiler rebuild and LLVM smoke are required before closing the round.

## Next

C4-B should add explicit cast/extend/trunc nodes and sema promotion rules. C4-C should split signed and unsigned integer operations for `div`, `mod`, and ordered comparisons.
