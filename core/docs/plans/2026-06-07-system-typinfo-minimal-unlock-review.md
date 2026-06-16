# System TypInfo Minimal Unlock Review

## Status

- `Implemented minimal live unlock`

## Review question

Do these seven symbols now have enough real pressure to move
`nextpas.core.system.typinfo` from pure `deferred` design audit into a minimal
live unlock slice?

- `PTypeInfo`
- `TTypeKind`
- `TypeInfo`
- `GetTypeKind`
- `InitializeArray`
- `FinalizeArray`
- `CopyArray`

## Decision

Yes for minimal live unlock.

The correct current state is:

- `nextpas.core.system.typinfo` exists as a minimal live unit;
- the seven-symbol surface is the complete live contract for this slice;
- broader `nextpas.core.system.sysutils`, `nextpas.core.system.classes`, and
  broader `TypInfo` reflection remain deferred;
- any next expansion must still be a focused reviewed facade slice, not a broad
  `TypInfo` compatibility import.

This file records the review packet that justified the live unlock and the
implementation guardrails that must remain true for landing.

## Real pressure

### Compiler contract pressure

`compiler/tests/test_typinfo_contract.pas` proves that compiler/runtime truth
already depends on:

- `PTypeInfo`
- `TypeInfo(AnsiString)`
- `TTypeKind` value `tkAString`
- `InitializeArray`
- `CopyArray`
- `FinalizeArray`

This is not reflection-only pressure. The test exercises managed-array
lifecycle and metadata identity.

### Collections lifecycle pressure

`core/src/nextpas.core.collections.element_manager.pas` stores `PTypeInfo`,
captures `system.TypeInfo(T)`, and uses `InitializeArray`, `FinalizeArray`,
and `CopyArray` for generic managed-element lifetime, including overlap
handling.

This is the strongest core-framework pressure because a wrong facade would
directly risk leaks, double-finalization, refcount corruption, or overlap-copy
misbehavior.

### Collections specialization pressure

`core/src/nextpas.core.collections.hashmap.swiss.pas`,
`core/src/nextpas.core.collections.btree.pas`, and
`core/src/nextpas.core.collections.concurrent.hashmap.pas` all branch on
`GetTypeKind(K)` to decide specialization for ordinal and string-like keys.

This is semantic pressure, not just optimization pressure:

- hashing path selection changes;
- equality/ordering path selection changes;
- the rule for when custom hash/equality callbacks are required changes.

## Exact public symbol list

The public contract for this live unlock is exactly:

- `PTypeInfo`
- `TTypeKind`
- `TypeInfo`
- `GetTypeKind`
- `InitializeArray`
- `FinalizeArray`
- `CopyArray`

The `TTypeKind` part of the contract includes only compiler/System-proven kind
names required by live consumers and focused tests. Structured kind aliases such
as `tkInterface`, `tkClass`, `tkClassRef`, `tkSet`, `tkProcVar`, `tkArray`, and
`tkRecord` remain kind-name coverage inside `TTypeKind`; they do not expose
metadata layout.

Anything outside this contract is out of scope for the first unlock slice,
including:

- property reflection;
- method/property table access;
- RTTI mutation;
- string-based reflection helpers;
- any `SysUtils` or `Classes` carry-in.

## Exact owner boundary

| Symbol | Public meaning | Real owner boundary |
| --- | --- | --- |
| `PTypeInfo` | minimal pointer identity for type metadata | compiler/runtime own emitted layout truth; system may only name the contract |
| `TTypeKind` | minimal type-family classification | compiler/runtime own enum truth and grouping semantics |
| `TypeInfo` | static type identity lookup | compiler/System compile-truth; the facade must not fake an ordinary wrapper |
| `GetTypeKind` | convenience classification for generic specialization | compiler/System compile-truth over metadata; collections remain consumers |
| `InitializeArray` | initialize repeated managed elements | runtime-managed lifetime helper; `mem` remains allocator owner |
| `FinalizeArray` | release repeated managed elements | runtime-managed lifetime helper; leak and ordering rules stay runtime-owned |
| `CopyArray` | copy repeated managed elements | runtime-managed lifetime helper; overlap and refcount semantics stay runtime-owned |

Owner-boundary rules for the first unlock:

- do not move metadata ownership into `core`;
- do not make collections the source of TypInfo truth;
- do not treat host FPC `TypInfo` layout as nextPas target ABI;
- do not blur runtime helper semantics into general-purpose reflection API.

## Remaining blockers before expansion

These are not blockers for the minimal live unit. They are blockers for any
broader TypInfo API:

1. Compiler/runtime ABI is still not frozen enough to promise a stable
   `PTypeInfo` layout beyond identity and `Kind`.
2. Metadata layout is still host-shaped today; nextPas must not accidentally
   freeze FPC layout details as target truth.
3. Managed-array lifecycle semantics still need explicit publication for nil,
   zero-count, overlap copy, partial initialization, and refcount ordering.
4. `TypeInfo` and `GetTypeKind` remain compiler/System internal symbols, not
   unit-owned functions.

## Exact minimal file set for this unlock slice

The implementation batch stays limited to:

- create `core/src/nextpas.core.system.typinfo.pas`
- create `core/tests/nextpas.core.system/test_system_typinfo_minimal/Makefile`
- create `core/tests/nextpas.core.system/test_system_typinfo_minimal/test_system_typinfo_minimal.lpr`
- update `core/tests/nextpas.core.system/Makefile`
- update `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`
- update `core/docs/system/typinfo-minimal-pressure.md`
- update `core/docs/system/compatibility-facades.md`
- update `core/docs/system/compatibility-matrix.md`
- switch real collections TypInfo consumers to `nextpas.core.system.typinfo`

Keep these as rerun-only evidence in the first live unlock:

- `compiler/tests/test_typinfo_contract.pas`
- `core/tests/nextpas.core.collections/test_contracts`
- `core/tests/nextpas.core.collections/test_swisstable`
- `core/tests/nextpas.core.collections/test_btreemap`
- `core/tests/nextpas.core.collections/test_concurrent_hashmap`

The first unlock does not require compiler/runtime implementation edits. If a
future expansion does, stop and reopen review instead of stretching this slice.

## Focused verification plan

Minimum verification for the first live unlock:

1. `make -C core/tests/nextpas.core.system/test_system_typinfo_minimal clean test`
2. `make -C core/tests/nextpas.core.system clean test`
3. `make -C core/tests/nextpas.core.collections/test_contracts clean test`
4. `make -C core/tests/nextpas.core.collections/test_swisstable clean test`
5. `make -C core/tests/nextpas.core.collections/test_btreemap clean test`
6. `make -C core/tests/nextpas.core.collections/test_concurrent_hashmap clean test`
7. the compiler contract runner wired into `test_system_typinfo_minimal`
8. `git diff --check`
9. `make hygiene`

Gate expectations:

- managed-lifetime tests must end with heaptrc `0 unfreed memory blocks`;
- source-contract must still prove broader `SysUtils` and `Classes` stay
  deferred;
- the compiler-facing gate must prove the seven-symbol contract without
  importing broader FPC `TypInfo` behavior.

## Explicit non-goals

- do not expand `nextpas.core.system.sysutils` beyond focused live pressure
- do not create `nextpas.core.system.classes`
- do not add property reflection
- do not add method/property table readers
- do not add compiler/runtime implementation in the first unlock slice
- do not re-export host FPC `TypInfo` as if it were frozen nextPas ABI

## Recommendation

Keep `nextpas.core.system.typinfo` live and narrow. The next controller decision
should only reopen this area if a broader RTTI consumer names the missing API,
the minimum interface, and the verification gate.
