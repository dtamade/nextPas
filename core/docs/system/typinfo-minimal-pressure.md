# S4 TypInfo Minimal Pressure Audit

This is a design/source-contract slice for the narrow S4 TypInfo question. It
does not approve or create a live `nextpas.core.system.typinfo` unit.

The audit is intentionally limited to these symbols:

- `PTypeInfo`
- `TTypeKind`
- `TypeInfo`
- `GetTypeKind`
- `InitializeArray`
- `FinalizeArray`
- `CopyArray`

Anything outside that list is out of scope for this slice.

## Current Decision

`nextpas.core.system.typinfo` remains deferred.

Deferred is still the correct state because the pressure is real but the
compiler/runtime ABI is not yet settled enough to freeze a public facade. The
current repository still consumes FPC `TypInfo` and compiler built-ins for
runtime type identity, type-kind classification, and managed-array lifecycle
operations. A nextPas-native facade would become public API and would therefore
freeze semantics that currently still depend on compiler-emitted metadata and
runtime helper design.

This is not a blocker. It is a design checkpoint for the smallest credible S4
unlock candidate.

## Real Consumer Pressure

### Compiler contract pressure

`compiler/tests/test_typinfo_contract.pas` is the strongest explicit compiler
pressure. It proves that the current compiler/runtime story needs:

- `PTypeInfo`
- `TypeInfo(AnsiString)` identity
- `TTypeKind` value `tkAString`
- `InitializeArray`
- `CopyArray`
- `FinalizeArray`

This test is metadata-sensitive and lifetime-sensitive. It is not merely a
reflection convenience test; it proves that array initialization, copy, and
finalization semantics need a stable runtime truth.

### Collections lifecycle pressure

`core/src/nextpas.core.collections.element_manager.pas` is the strongest core
consumer. It uses:

- `PTypeInfo` as stored element metadata
- `system.TypeInfo(T)` to capture generic element type truth
- `InitializeArray` to initialize multiple elements
- `FinalizeArray` to release multiple managed elements
- `CopyArray` to copy managed elements, including overlap-sensitive paths

This consumer makes TypInfo pressure real for managed lifetime. A wrong facade
would risk leaks, double-finalization, stale references, or incorrect overlap
copy behavior.

### Collections specialization pressure

`core/src/nextpas.core.collections.hashmap.swiss.pas`,
`core/src/nextpas.core.collections.btree.pas`, and
`core/src/nextpas.core.collections.concurrent.hashmap.pas` use `GetTypeKind(K)`
to choose specialized paths for ordinal and string-like keys.

This pressure is performance-adjacent but still semantic: type-kind
classification affects hashing, equality, ordering, and whether a caller must
provide a custom hash function.

### Type identity pressure

`core/src/nextpas.core.collections.base.pas`,
`core/src/nextpas.core.collections.arr.pas`, and
`core/src/nextpas.core.collections.hashmap.pas` use `TypeInfo(T)` or
`PTypeInfo^.Kind` for internal dispatch.

These consumers need stable type identity, not property reflection.

## Owner Boundary

| Symbol | Current role | Boundary |
| --- | --- | --- |
| `PTypeInfo` | pointer to compiler/runtime type metadata | compiler emits identity/layout truth; runtime consumes it; system may later name the facade |
| `TTypeKind` | minimal type family classification | compiler/runtime-owned enum truth; public facade must not invent extra values |
| `TypeInfo` | type identity lookup for static type `T` | compiler intrinsic today; future facade must remain a thin contract over emitted metadata |
| `GetTypeKind` | type family lookup used by generic collections | runtime/helper convenience over compiler metadata; must stay deterministic for generic specialization |
| `InitializeArray` | initialize repeated elements using type metadata | managed lifetime helper over runtime + mem owner boundary |
| `FinalizeArray` | release repeated managed elements using type metadata | managed lifetime helper; must be leak-safe and reverse-safe where required |
| `CopyArray` | copy repeated elements using type metadata | managed lifetime helper; must preserve reference counts and overlap semantics |

Implementation ownership must not move into a broad compatibility unit:

- compiler owns emitted metadata, generic specialization truth, and intrinsic
  lowering;
- runtime/system owns the vocabulary and helper contract;
- `nextpas.core.mem` owns allocation and release mechanisms;
- collections are consumers, not TypInfo owners.

## ABI Risks

### `PTypeInfo` layout risk

Freezing a public `PTypeInfo` shape too early would couple nextPas to an
unstable metadata layout. The current consumers mostly need identity and
`Kind`; that is not proof that property tables, method tables, generic metadata,
or binary layout should be exposed.

### `TTypeKind` compatibility risk

`GetTypeKind(K)` users branch on values such as `tkInteger`, `tkAString`,
`tkLString`, `tkUString`, `tkWString`, `tkEnumeration`, `tkInt64`, and
`tkQWord`. If nextPas changes these names or grouping semantics, collection
hashing and ordering behavior can change without visible type errors.

### Managed-array lifecycle risk

`InitializeArray`, `FinalizeArray`, and `CopyArray` touch string/interface and
other managed values. A premature facade could lock in wrong behavior for:

- nil and zero-length inputs;
- partially initialized arrays after allocation failure;
- overlapping copy;
- reference-count ordering;
- finalization after partial copy failure;
- interaction with `nextpas.core.mem` allocation failures.

### Compiler/runtime split risk

If `nextpas.core.system.typinfo` simply forwards to host FPC `TypInfo`, it may
make host-compiler behavior look like nextPas target-runtime truth. That would
be wrong for cross-target compilation and future self-hosting.

## Minimal Unlock Conditions

Opening a live `nextpas.core.system.typinfo` unit requires `Needs Review` unless
all conditions below are already satisfied by a controller-approved slice:

1. The consumer is named and cannot move forward using current bootstrap/FPC
   TypInfo or compiler intrinsic paths.
2. The proposed public surface is limited to the seven symbols in this audit.
3. `PTypeInfo` and `TTypeKind` semantics are documented as minimum identity and
   kind truth only; no property reflection is implied.
4. `TypeInfo` and `GetTypeKind` behavior is covered for the kinds used by
   collections.
5. `InitializeArray`, `FinalizeArray`, and `CopyArray` have focused
   managed-lifetime tests with heaptrc zero-leak evidence.
6. The implementation route does not freeze host FPC metadata as nextPas target
   ABI.
7. Source-contract tests continue to prove that SysUtils and Classes facades
   are not reopened by the TypInfo slice.

## Minimum Verification Gate For A Future Unlock

The first live TypInfo slice, if approved, should include at least:

- a compiler contract gate based on `compiler/tests/test_typinfo_contract.pas`;
- a collections managed-lifetime gate around
  `nextpas.core.collections.element_manager`;
- collection specialization coverage for `GetTypeKind`-driven hash/tree paths;
- heaptrc zero-leak evidence for managed string arrays;
- source-contract proof that no property reflection or Classes/SysUtils surface
  leaked into the unit.

## Deferred Reason

The correct current state is still `deferred` because the pressure is precise
but not yet an unlock command:

- consumers prove the seven-symbol minimal set matters;
- consumers do not prove a public `nextpas.core.system.typinfo` namespace must
  exist today;
- ABI and metadata ownership are not yet settled enough to expose a stable
  facade;
- the safe next action is preserving the audit and contract guard, not creating
  a public unit.

