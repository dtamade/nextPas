# S4 Compatibility Facade Design

This document records the S4 compatibility boundary for `nextpas.core.system`.
It now distinguishes minimal live TypInfo, SysUtils (**40+ functions**) and Classes (**10 types**) facades. All live units are intentionally narrow; they do
not convert bootstrap RTL pressure into a broad public compatibility API.

## Current Decision Boundary

- `nextpas.core.system.errors` is a live facade re-exporting all 38 exception
  type aliases and 18 error-category constants from their canonical owners
  (`nextpas.core.exception`, `nextpas.core.base`, `nextpas.core.errors`).
- `nextpas.core.system.typinfo` has a minimal live unit for the seven-symbol
  pressure set.
- `nextpas.core.system.sysutils` has a minimal live **compatibility facade** ( **40+ functions**: `Format`, `SameText`, `IntToStr`, `Trim`, `StrToInt`, `FloatToStr`, `FileExists`, `ExtractFilePath`, `Now`, `Sleep`, `SysErrorMessage` …). **Text implementation owner is `nextpas.core.text.conv`** (and `path`/`fs`/`platform` for non-text slices); exception aliases own in `nextpas.core.exception`. Sysutils does not implement text APIs — it is a thin delegating facade.
- `nextpas.core.system.classes` is a **live facade** with **10 types**: `TSeekOrigin` (single source `nextpas.core.io.base`), `TStream`, `THandleStream`, `TMemoryStream`, `TFileStream`, `TList`, `TInterfaceList`, `TStringList`, `TDuplicates`, `TThread` (plus `fm*` constants and `IStream`/`IReader`/`IWriter` re-exports) — **stub-converged** via `nextpas.core.system.classes.impl` (no `uses Classes`, `bytes.ops` single source, `inline`/zero-copy, `Destroy`/`Close` resource release). Narrow, stream/container-owned subset, not full `Classes` sprawl.
- Deferred does not mean "undefined"; it means the broad public unit surface is
  not live yet and is guarded by docs plus source-contract.
- Any future broad compatibility facade still requires named consumer pressure,
  focused tests, and controller review.

## Bootstrap RTL Is Not The Same Thing As Core Facade

The repository already contains bootstrap-oriented RTL source-of-truth files:

| Path | Current role | Why it does not automatically become `nextpas.core.system.*` |
| --- | --- | --- |
| `rtl/core/sysutils/np_sysutils.pas` | minimal `SysUtils` subset for compiler bootstrap and Stage 2 self-hosting | bootstrap scope is "compiler can build", not "public core API is settled" |
| `rtl/core/classes/np_classes.pas` | minimal `Classes` subset with `TFileStream` and `TStringList` | current shape is pragmatic bootstrap RTL, not a reviewed owner-boundary facade |
| `compiler/tests/test_sysutils_createfmt_contract.pas` | proof that compiler bootstrap currently needs `Format`, `Exception.CreateFmt`, and `ExceptClass` behavior | pressure is enough for a minimal exception-formatting facade, but not for path, file, environment, time, or broad string-helper compatibility |
| compiler semantic and toolchain `SameText` uses | proof that case-insensitive identifier/config comparison is real pressure | pressure is enough for one tiny **sysutils facade re-export** of `SameText`; **owner remains `nextpas.core.text.conv`** (ASCII fold). Not enough for `CompareText`, path, file, environment, or time helpers |
| compiler/runtime diagnostic `IntToStr` uses | proof that numeric label, counter, and diagnostic conversion is real pressure | pressure is enough for one tiny delegating `IntToStr` facade, but not for parsing, case conversion, path, file, environment, or time helpers |
| compiler generic parameter token normalization | `compiler/sema/np_semantic_model.pas` uses `SameText(Trim(Copy(Params, ...)), AParamName)` | pressure is enough for one tiny delegating `Trim` facade, but not for case conversion, parsing, path, file, environment, or time helpers |
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
| exception formatting | `Format`, `Exception.CreateFmt`, `ExceptClass`, `EAssertionFailed` | real bootstrap/compiler pressure | minimal live facade delegates `Format` to `nextpas.core.text.conv` and exception aliases to `nextpas.core.exception` |
| path normalization | `ExpandFileName`, `ExtractFileDir`, `ExtractFileName`, `IncludeTrailingPathDelimiter`, `ExcludeTrailingPathDelimiter` | real toolchain/workspace pressure | path and filesystem semantics belong to `fs` / platform / process owners |
| file and environment discovery | `FileExists`, `DirectoryExists`, `ForceDirectories`, `FileSearch`, `GetEnvironmentVariable` | real toolchain pressure | keep implementation ownership outside system |
| string comparison | `SameText` | real compiler semantic/toolchain pressure | minimal live **sysutils facade delegates to `nextpas.core.text.conv.SameText`** (ASCII fold owned by text.conv); broad string helpers stay deferred |
| string conversion | `IntToStr` | real compiler/runtime diagnostic pressure | minimal live facade delegates to `nextpas.core.text.conv`; parsing and broad text helpers stay deferred |
| token normalization | `Trim` | real compiler generic-parameter matching pressure | minimal live facade delegates to `nextpas.core.text.conv`; case conversion and parsing stay deferred |
| string convenience | `LowerCase`, `UpperCase`, `StrToInt` | real compiler pressure, but mixed parsing/case policy | text/number helpers should stay explicit about owner and behavior |
| `CompareText` | no focused consumer pressure in this lane | keep deferred | do not unlock just because `SameText` is live |
| date/time convenience | `Now`, `FormatDateTime` | only incidental pressure today | belongs to time owner, not system |

### Current S4 stance (2026-08-31 alignment: live 40+ sysutils, 10-type classes)

- A minimal live `nextpas.core.system.sysutils` unit exists — **40+ functions** (see § Current live minimum; `core/src/nextpas.core.system.sysutils.pas` 583 lines, `Format`/`SameText`/`IntToStr`/`Trim` + `StrToInt`/`FloatToStr`/`FileExists`/`ExtractFile*`/`Now`/`Sleep`/`SysErrorMessage` etc., all delegating to `text.conv`/`path`/`fs`/`platform`).
- A minimal live `nextpas.core.system.classes` unit exists — **10 types** (`TSeekOrigin`, `TStream`, `THandleStream`, `TMemoryStream`, `TFileStream`, `TList`, `TInterfaceList`, `TStringList`, `TDuplicates`, `TThread`; plus `fmCreate`/`fmOpen*`/`fmShare*` and `IStream` re-exports) as narrow bootstrap shim; `TComponent`/`TPersistent` remain deferred.
- Do not create a mirror of FPC `SysUtils`/`Classes`.
- Do not move filesystem, environment, time, or text ownership into `system`; classes does not own container/thread ownership beyond the 10-type shim.
- Any further `system.sysutils`/`system.classes` shape must stay tiny and consumer-proven; do not pull broad text, filesystem, environment, or time ownership into system.

### Current live minimum

The live contract includes 40+ functions:

- `Format`, `SameText`, `IntToStr`, `Trim`
- `StrToInt`, `StrToInt64`, `StrToFloat` (numeric parsing)
- `FloatToStr`, `CurrToStr` (numeric formatting)
- `DateTimeToStr`, `DateToStr`, `TimeToStr` (date/time formatting)
- `Now`, `Date`, `Time` (date/time access)
- `FileExists`, `DirectoryExists` (filesystem checks)
- `CreateDir`, `RemoveDir`, `ForceDirectories` (directory ops)
- `DeleteFile`, `RenameFile`, `CopyFile` (file ops)
- `ExtractFilePath`, `ExtractFileName`, `ExtractFileExt` (path ops)
- `ChangeFileExt`, `IncludeTrailingPathDelimiter` (path manipulation)
- `GetCurrentDir`, `SetCurrentDir` (working directory)
- `ParamCount`, `ParamStr` (command line)
- `GetEnvironmentVariable` (environment)
- `Sleep` (timing)
- `SysErrorMessage`, `GetLastOSError` (error handling)
- `Exception`, `ExceptClass`, `EConvertError`, `EAssertionFailed`

Anything larger should trigger `Needs Review`, including:

- path normalization entry points;
- bootstrap-stable string helpers other than the current `SameText`,
  `IntToStr`, and `Trim` slices;
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
- `PPropInfo`, `PPropList`
- `TypeInfo`
- `GetTypeKind`
- `GetPropInfo`, `GetPropList`
- `GetEnumName`, `GetEnumValue`
- `InitializeArray`
- `FinalizeArray`
- `CopyArray`

### Why the live unit stays minimal

This is the strongest real S4 pressure, but it is also the highest-risk area:

- `TypInfo` is where compiler-emitted metadata, managed lifetime, and runtime
  helper ABI truth meet.
- `core/src/nextpas.core.collections.element_manager.pas` already uses
  `system.TypeInfo(T)`, `InitializeArray`, `FinalizeArray`, and `CopyArray`;
  a premature broad facade or host TypInfo mirror would freeze semantics before
  compiler/runtime metadata is fully specified.
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

`TTypeKind` includes the aliases required by live collections consumers,
including ordinal, string, float, variant, method, pointer, interface, and
dynamic-array kind names. This is kind coverage inside the existing `TTypeKind`
contract, not a broader reflection API.

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

### Current S4 stance (live 10-type shim, 2026-08-31)

- A live `nextpas.core.system.classes` unit exists — **10 types** (`TSeekOrigin`, `TStream`, `THandleStream`, `TMemoryStream`, `TFileStream`, `TList`, `TInterfaceList`, `TStringList`, `TDuplicates`, `TThread`; `fmCreate`/`fmOpenRead`/`fmShareDenyNone` etc.) as narrow bootstrap shim; `TComponent`/`TPersistent`/ownership trees/streaming framework remain deferred.
- Treat live 10-type shim as proof of narrow subset pressure, not as proof that the full `Classes` boundary is decided.
- Any future broader `system.classes` must keep IO/container/thread ownership explicit and stay guarded by source-contract (the 10-type shim is the current live surface).

## Migration Risks

### Risk 1: Freezing bootstrap shortcuts as permanent public API

If S4 simply wraps `rtl/core/sysutils/np_sysutils.pas` and
`rtl/core/classes/np_classes.pas`, nextPas would hard-freeze bootstrap
tradeoffs as long-term public core API.

### Risk 2: Losing owner boundaries

If `system.sysutils` absorbs file, environment, time, process, or broad text
helpers, consumers will stop knowing whether a behavior is owned by `system`,
`fs`, `platform`, `time`, `io`, or `text`. The current live `Format` helper is
kept as a delegating exception-formatting seam, not a transfer of text
ownership.

### Risk 3: Freezing RTTI ABI too early

If `system.typinfo` expands beyond the seven-symbol bridge before
compiler-emitted metadata contracts are settled, the project will likely lock in
the wrong `PTypeInfo` / `TTypeKind` / managed-array semantics.

### Risk 4: Recreating historical `Classes` sprawl

If `system.classes` starts from "make FPC code compile", it will quickly become
the same compatibility junk drawer this lane is explicitly trying to avoid.

## Reopen Criteria

S4 should only reopen as `Needs Review` for broader SysUtils, Classes, or
broader TypInfo reflection when all of the following are true:

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
