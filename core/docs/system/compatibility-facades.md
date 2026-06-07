# S4 Compatibility Facade Design

This document records the S4 compatibility boundary for `nextpas.core.system`.
It now distinguishes one minimal live TypInfo facade from the still-deferred
SysUtils and Classes facades. The live TypInfo unit is intentionally narrow; it
does not convert bootstrap RTL pressure into a broad public compatibility API.

## Current Decision Boundary

- `nextpas.core.system.typinfo` has a minimal live unit for the seven-symbol
  pressure set.
- `nextpas.core.system.sysutils` and `nextpas.core.system.classes` remain
  deferred.
- Deferred does not mean "undefined"; it means the public unit surface is not
  live yet and is guarded by docs plus source-contract.
- Any future broad compatibility facade still requires named consumer pressure,
  focused tests, and controller review.

## Bootstrap RTL Is Not The Same Thing As Core Facade

The repository already contains bootstrap-oriented RTL source-of-truth files:

| Path | Current role | Why it does not automatically become `nextpas.core.system.*` |
| --- | --- | --- |
| `rtl/core/sysutils/np_sysutils.pas` | minimal `SysUtils` subset for compiler bootstrap and Stage 2 self-hosting | bootstrap scope is "compiler can build", not "public core API is settled" |
| `rtl/core/classes/np_classes.pas` | minimal `Classes` subset with `TFileStream` and `TStringList` | current shape is pragmatic bootstrap RTL, not a reviewed owner-boundary facade |
| `compiler/tests/test_sysutils_createfmt_contract.pas` | proof that compiler bootstrap currently needs `Format`, `Exception.CreateFmt`, and `ExceptClass` behavior | pressure is real, but it is pressure on bootstrap RTL first, not proof that a `nextpas.core.system.sysutils` namespace is ready |
| `compiler/tests/test_typinfo_contract.pas` | proof that compiler/runtime contracts already need `PTypeInfo`, `TypeInfo`, `InitializeArray`, `CopyArray`, and `FinalizeArray` | this proves RTTI lifecycle pressure, but also proves ABI/layout truth must stay compiler/runtime-led |

S4 therefore must distinguish two concerns:

1. `plain RTL units needed today for bootstrap/self-hosting`
2. `nextpas.core.system.* compatibility facades that become public nextPas API`

Those are related, but they are not the same decision.

## `nextpas.core.system.sysutils`

### What current consumers really want

Live evidence today is concentrated in compiler/toolchain/bootstrap code:

- `compiler/toolchain/np_toolchain_runner.pas`
- `compiler/toolchain/np_toolchain_profiles.pas`
- `compiler/frontend/np_workspace_model.pas`
- `compiler/frontend/np_unit_resolver.pas`
- `compiler/sema/np_semantic_model.pas`
- `compiler/tests/test_sysutils_createfmt_contract.pas`

The pressure clusters into a few narrow capability families:

| Capability family | Example symbols | Current pressure | Owner stance |
| --- | --- | --- | --- |
| exception formatting | `Format`, `Exception.CreateFmt`, `ExceptClass`, `EAssertionFailed` | real bootstrap/compiler pressure | exception taxonomy already lives in `nextpas.core.exception`; formatting should not automatically become `system.sysutils` ownership |
| path normalization | `ExpandFileName`, `ExtractFileDir`, `ExtractFileName`, `IncludeTrailingPathDelimiter`, `ExcludeTrailingPathDelimiter` | real toolchain/workspace pressure | path and filesystem semantics belong to `fs` / platform / process owners |
| file and environment discovery | `FileExists`, `DirectoryExists`, `ForceDirectories`, `FileSearch`, `GetEnvironmentVariable` | real toolchain pressure | keep implementation ownership outside system |
| string convenience | `Trim`, `SameText`, `LowerCase`, `UpperCase`, `IntToStr`, `StrToInt` | real compiler pressure | text/number helpers should stay explicit about owner and behavior |
| date/time convenience | `Now`, `FormatDateTime` | only incidental pressure today | belongs to time owner, not system |

### Current S4 stance

- No live `nextpas.core.system.sysutils` unit yet.
- Do not create a mirror of FPC `SysUtils`.
- Do not move filesystem, environment, time, or formatting ownership into
  `system`.
- If reopened, the only acceptable `system.sysutils` shape is a tiny,
  consumer-proven compatibility facade delegating to existing owners.

### Candidate minimum if this unit is ever reopened

Only after review, a minimal surface could be considered for:

- exception-formatting compatibility that complements
  `nextpas.core.system.Exception` rather than shadowing it;
- path normalization entry points needed by compiler/runtime integration;
- bootstrap-stable string helpers whose owner boundary is already explicit.

It should not start with:

- `Now` / `FormatDateTime`;
- broad file APIs;
- process control;
- collection helpers;
- historical convenience overload sprawl.

## `nextpas.core.system.typinfo`

The detailed minimal pressure audit for this unit lives in
`typinfo-minimal-pressure.md`. That document narrows the candidate set to
`PTypeInfo`, `TTypeKind`, `TypeInfo`, `GetTypeKind`, `InitializeArray`,
`FinalizeArray`, and `CopyArray`.

### What current consumers really want

Live pressure is concentrated around compiler/runtime-managed type truth:

- `compiler/tests/test_typinfo_contract.pas`
- `core/src/nextpas.core.collections.element_manager.pas`
- `core/src/nextpas.core.collections.hashmap.swiss.pas`
- `core/src/nextpas.core.collections.btree.pas`
- `core/src/nextpas.core.collections.concurrent.hashmap.pas`

The actual symbols in use are much narrower than historical `TypInfo`:

- `PTypeInfo`
- `TTypeKind`
- `TypeInfo`
- `GetTypeKind`
- `InitializeArray`
- `FinalizeArray`
- `CopyArray`

### Why the live unit stays minimal

This is the strongest real S4 pressure, but it is also the highest-risk area:

- `TypInfo` is where compiler-emitted metadata, managed lifetime, and runtime
  helper ABI truth meet.
- `core/src/nextpas.core.collections.element_manager.pas` already uses
  `system.TypeInfo(T)`, `InitializeArray`, `FinalizeArray`, and `CopyArray`;
  a premature facade would freeze semantics before compiler/runtime metadata is
  fully specified.
- `core/src/nextpas.core.collections.hashmap.swiss.pas` depends on
  `GetTypeKind(K)` for specialization decisions; that is runtime truth, not
  cosmetic reflection.

### Current S4 stance

- A minimal live `nextpas.core.system.typinfo` unit exists.
- The live surface is a narrow runtime-truth facade, not string-based
  reflection sugar.
- The unit exposes `PTypeInfo`, `TTypeKind`, the kind constants used by live
  consumers, and the managed-array helper wrappers.
- `TypeInfo` and `GetTypeKind` remain compiler/System compile-truth symbols;
  consumers use them unqualified after importing the facade, not as ordinary
  `nextpas.core.system.typinfo.TypeInfo(...)` wrapper functions.
- The minimal pressure audit and implementation record live in
  `../plans/2026-06-07-system-typinfo-minimal-unlock-review.md`.
- Property reflection, dynamic method lookup, and metadata mutation stay out of
  scope until a compiler-backed RTTI model exists.

### Current live minimum

The live contract is exactly:

- `PTypeInfo`
- `TTypeKind`
- `TypeInfo`
- `GetTypeKind`
- `InitializeArray`
- `FinalizeArray`
- `CopyArray`

Anything larger should trigger `Needs Review`.

## `nextpas.core.system.classes`

### What current consumers really want

Pressure today is mostly bootstrap/tooling/file-handling pressure:

- `compiler/toolchain/np_toolchain_runner.pas` uses `TFileStream`
- `compiler/toolchain/np_toolchain_profiles.pas` uses `Classes`
- many TLS and Windows-backed units use `TFileStream` or `TStringList`
- `rtl/core/classes/np_classes.pas` currently implements `TFileStream`,
  `TStringList`, and file mode constants

### Why this is not enough for a live facade

`Classes` is historically huge and stateful. Current evidence only supports a
very small subset:

- `TFileStream`
- `TStringList`
- file mode constants such as `fmCreate`, `fmOpenRead`, `fmShareDenyNone`

That does not justify:

- `TComponent`
- `TPersistent`
- ownership trees
- streaming framework compatibility
- designer/runtime component semantics

### Current S4 stance

- No live `nextpas.core.system.classes` unit yet.
- Treat current bootstrap `Classes` as proof of narrow subset pressure, not as
  proof that the full namespace boundary is decided.
- Any future live facade must keep IO/container ownership explicit.

## Migration Risks

### Risk 1: Freezing bootstrap shortcuts as permanent public API

If S4 simply wraps `rtl/core/sysutils/np_sysutils.pas` and
`rtl/core/classes/np_classes.pas`, nextPas would hard-freeze bootstrap
tradeoffs as long-term public core API.

### Risk 2: Losing owner boundaries

If `system.sysutils` absorbs file, environment, time, formatting, and process
helpers, consumers will stop knowing whether a behavior is owned by `system`,
`fs`, `platform`, `time`, `io`, or `text`.

### Risk 3: Freezing RTTI ABI too early

If `system.typinfo` expands beyond the seven-symbol bridge before
compiler-emitted metadata contracts are settled, the project will likely lock in
the wrong `PTypeInfo` / `TTypeKind` / managed-array semantics.

### Risk 4: Recreating historical `Classes` sprawl

If `system.classes` starts from "make FPC code compile", it will quickly become
the same compatibility junk drawer this lane is explicitly trying to avoid.

## Reopen Criteria

S4 should only reopen as `Needs Review` for SysUtils, Classes, or broader
TypInfo reflection when all of the following are true:

1. A named consumer cannot move forward without a stable `nextpas.core.system.*`
   namespace path rather than plain bootstrap RTL units.
2. The exact symbols needed are listed as a minimal surface.
3. Delegation ownership is explicit for every symbol.
4. Focused verification exists for the named consumer.
5. Leak-sensitive or metadata-sensitive gates exist where required.

## Minimum Review Packet For `Needs Review`

If real pressure forces early unlock, the review packet must list:

- consumer file(s)
- exact API names needed
- why bootstrap RTL units are insufficient
- owner boundary for each symbol
- migration risk if the wrong surface is exposed
- focused verification gate to prove the minimal surface
