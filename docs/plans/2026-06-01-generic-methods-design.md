# Generic Methods — Full Architecture Design

> **Goal:** Support generic methods at all levels (top-level, class, interface) with FPC + Delphi dual syntax.

## Core Decision: Monomorphization + Call-site Instantiation + Cache Dedup

Each `specialize Foo<Integer>(42)` generates an independent function `Foo$Integer`.
Reuses existing generic class instantiation model for consistency.

## Syntax Support

| Mode | Declaration | Call |
|------|-------------|------|
| FPC | `generic function Foo<T>(X: T): T;` | `specialize Foo<Integer>(42)` |
| Delphi | `function Foo<T>(X: T): T;` | `Foo<Integer>(42)` |

## Instantiation Flow

1. Pass 1 (Declarations): Register generic method template (TypeParams + AST body ref)
2. Pass 2 (Statements): At call site, lookup template → check cache → instantiate if miss
3. Instantiation: verify arity → check constraints → substitute T→Integer → generate new function symbol

## Name Mangling

- Top-level: `Foo$Integer`
- Multi-param: `Pair$Integer$String`
- Class method: `TFoo.Bar$Integer`
- Generic class + generic method: `TContainer$Integer.Find$String`

## `<` Ambiguity Resolution (Delphi mode)

Contextual lookahead after `identifier <`:
- Scan for matching `>` containing only valid type-param content (identifiers, commas, nested `<>`)
- If `>` followed by `(` → generic call
- If `>` followed by `.`, `,`, `;` → generic type reference
- Otherwise → comparison operator

FPC mode: `specialize` keyword eliminates ambiguity.

## Class + Method Type Parameter Interaction

```pascal
generic TContainer<T> = class
  generic function Find<U>(Pred: TFunc<T, U, Boolean>): T;
end;
```

Instantiation applies class params first (T→Integer), then method params (U→String).

## Implementation Phases

### Phase 1: Top-level generic functions (FPC syntax)
- Parser: save `<T>` as gnkTypeParamList in function AST
- Sema: FGenericMethods array + InstantiateGenericMethod + cache
- Tests: basic instantiation + arity mismatch

### Phase 2: Delphi syntax + `<` disambiguation
- Parser: IsGenericCallAhead lookahead + expression branch
- Tests: Delphi call syntax + comparison not broken

### Phase 3: Class generic methods
- Sema: owner type params + method type params interaction
- HIR: self parameter forwarding for instantiated methods
- Tests: class method instantiation + constraint propagation

### Phase 4: Constraints + advanced features
- Constraint checking for method type params
- Multi-param methods
- Nested generic method calls

### Phase 5: Full LLVM codegen
- Each instantiation → independent LLVM function (internal linkage)
- Mangled name output
- End-to-end compile+run tests

## Files to Modify

| File | Changes | Phase |
|------|---------|-------|
| np_green_tree.pas | TypeParamList in func decl; IsGenericCallAhead | P1, P2 |
| np_semantic_analyzer.pas | TGenericMethodEntry; InstantiateGenericMethod; cache | P1, P3, P4 |
| np_semantic_model.pas | IsGenericTemplate symbol flag | P1 |
| np_hir_builder.pas | Instantiated method HIR generation | P5 |
| np_hir_llvm_emitter.pas | Mangled name; internal linkage | P5 |

## Data Structures

```pascal
TGenericMethodEntry = record
  Name: string;           // 'Foo' or 'TContainer.Find'
  TypeParams: string;     // 'T,U'
  Constraints: string;    // 'class,IComparable'
  Decl: TGreenNode;       // function declaration AST
  Body: TGreenNode;       // function body AST
  OwnerUnitId: string;
  OwnerTypeId: LongInt;   // 0 = top-level, >0 = owning class
  OwnerTypeParams: string; // class type params (if any)
end;
```

## Risks

- `<` lookahead: max 3 tokens, O(1) — negligible perf impact
- Recursive generic methods: reuse existing FInliningStack protection
- Code bloat: LLVM internal linkage + LTO eliminates unused instances
- Backward compat: Phase 1 only adds new paths, doesn't modify InstantiateGenericType
