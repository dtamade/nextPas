# Bootstrap Dual-Surface Adapter Contract

This document records the next step after the bootstrap dual-surface memo. It
turns the principle into a small source-contract that can guide future slices
without creating new public units or runtime implementation.

## Invariant

`FPC-compatible source` is a build constraint. It is not semantic authority and
it is not nextPas target ABI.

The semantic authority for System-facing behavior is the nextPas-owned
`np.system.*` contract vocabulary plus the compiler/runtime metadata that feeds
those contracts. FPC fallback behavior may keep stage0 builds moving, but it
must not freeze object lifetime, managed lifetime, RTTI metadata layout, unit
lifecycle, exported symbol names, or helper ABI.

Source-contract guard tokens:

- `fpc-compatible-source-is-stage0-build-vehicle`
- `fpc-compatibility-is-not-semantic-authority`
- `np-system-contracts-own-semantic-authority`
- `dual-surface-adapter-one-semantic-authority`
- `fpc-adapter-must-not-define-runtime-semantics`
- `compat-facade-must-not-own-system-semantics`
- `typeinfo-facade-does-not-freeze-metadata-abi`
- `lifecycle-contracts-match-live-typinfo-status`
- `compiler-consumes-nextpas-core-system-contract`
- `fpc-host-path-is-implementation-not-authority`

## Surfaces

| Surface | Role | Boundary |
| --- | --- | --- |
| stage0 host adapter | lets FPC build bootstrap System-facing source | may call FPC-compatible helpers, but must stay a fallback path |
| `nextpas.core.system.contracts` | compact nextPas contract vocabulary | FPC path is not semantic authority or target helper ABI |
| nextPas contract path | lowers System-facing behavior to `np.system.*` | owns semantic truth with compiler/runtime |
| public facade | `nextpas.core.system.*` API consumed by core modules | exposes only reviewed, minimal, owner-delegating names |
| bootstrap RTL units | `rtl/core/system`, `rtl/core/sysutils`, `rtl/core/classes` | prove bootstrap pressure, not public facade approval |

The adapter seam is the only place where host fallback and nextPas target truth
may differ. Conditional compilation belongs at that seam, not inside broad
owner modules or high-level facade logic.

S5 keeps that seam explicit: the FPC host path is implementation, not
authority. The compiler can bootstrap through FPC-compatible source, but its
long-term System-facing contract must be `nextpas.core.system` vocabulary
inside `nextpas.core`, not a private fallback ABI.

## Current Consumer Pressure

| Consumer pressure | Current status | Adapter rule |
| --- | --- | --- |
| `TObject.Free` / object release | compiler/runtime System truth | lower through `np.system.object_free`; do not expose as a Classes starter API |
| `PTypeInfo`, `TTypeKind`, `TypeInfo`, `GetTypeKind` | minimal live TypInfo bridge | do not freeze host FPC metadata layout as nextPas target layout |
| `InitializeArray`, `FinalizeArray`, `CopyArray` | minimal live managed-array bridge | require leak-sensitive runtime evidence before widening |
| `Format`, `SameText`, `IntToStr` | minimal live SysUtils facade | keep SameText system-local and delegate conversion/formatting to narrow owner modules; no broad SysUtils clone |
| `TFileStream`, `TStringList`, file mode constants | bootstrap Classes pressure only | no live `nextpas.core.system.classes` until a focused review packet exists |
| path, file, environment, time helpers | real bootstrap/toolchain pressure | owner modules decide semantics before any system facade |

`compiler/tests/test_sysutils_createfmt_contract.pas` remains bootstrap fallback
evidence for the historical `SysUtils` namespace. It must not be read as proof
that raw FPC `SysUtils` is the public nextPas authority.

## Unlock Rules

A future adapter or facade slice can proceed only when all of these are true:

1. The consumer is named and the exact symbol list is smaller than the proposed
   facade unit.
2. The owner boundary is explicit for every symbol.
3. The FPC path is described as stage0 host adapter or fallback, not as target
   ABI.
4. The nextPas path names the relevant `np.system.*` contract or owner module.
5. Focused source-contract or runtime tests cover the consumer.
6. Metadata-sensitive and leak-sensitive surfaces carry matching evidence.

If any item fails, the correct report is `Needs Review`, not an implicit public
API expansion.

## Non-Goals

- Do not create `nextpas.core.system.classes` from bootstrap `Classes` pressure
  alone.
- Do not expose raw `rtl/core/*` helper names as public core facade ABI.
- Do not treat FPC `TypeInfo` layout, managed-array helper behavior, or object
  release behavior as nextPas target ABI.
- Do not use FPC compatibility to bypass `nextpas.core.mem`, `text`, `fs`,
  `platform`, `time`, `io`, or collections ownership.
