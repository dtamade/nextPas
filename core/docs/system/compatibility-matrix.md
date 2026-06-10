# S4 Compatibility Matrix

This matrix turns current S4 pressure into concrete review inputs. TypInfo has
a minimal live unit, SysUtils has a minimal live exception-formatting plus
`SameText`, `IntToStr`, and `Trim` facade, and Classes plus broader reflection
remain deferred.

| Capability | Live evidence | Current provider | Recommended nextPas stance | Current S4 decision | Future unlock gate |
| --- | --- | --- | --- | --- | --- |
| `Format`, `Exception.CreateFmt`, `ExceptClass`, `EAssertionFailed` | `compiler/tests/test_sysutils_createfmt_contract.pas` | minimal live `nextpas.core.system.sysutils` plus bootstrap `SysUtils` | keep exception taxonomy in `nextpas.core.exception`; delegate `Format` to `nextpas.core.text.conv` | minimal live exception-formatting facade | system sysutils minimal gate plus compiler contract test |
| `SameText` | `compiler/sema/np_semantic_model.pas`, `compiler/sema/np_semantic_analyzer.pas`, `compiler/toolchain/np_toolchain_runner.pas` | minimal live `nextpas.core.system.sysutils` plus bootstrap `SysUtils` | delegate comparison semantics to `nextpas.core.text.compare`; keep broad text ownership outside system | minimal live string-comparison facade | system sysutils minimal gate and source-contract dependency guard |
| `IntToStr` | `compiler/sema/np_semantic_analyzer.pas`, core diagnostics and address/port formatting paths | minimal live `nextpas.core.system.sysutils` plus bootstrap `SysUtils` | delegate numeric conversion semantics to `nextpas.core.text.conv`; keep parsing and broad string ownership outside system | minimal live string-conversion facade | system sysutils minimal gate and source-contract dependency guard |
| `Trim` | `compiler/sema/np_semantic_model.pas` generic parameter matching uses `SameText(Trim(Copy(...)), AParamName)` | minimal live `nextpas.core.system.sysutils` plus bootstrap `SysUtils` | delegate whitespace normalization semantics to `nextpas.core.text.conv`; keep case conversion and parsing outside system | minimal live token-normalization facade | system sysutils minimal gate and source-contract compiler-pressure guard |
| path normalization | `compiler/toolchain/np_toolchain_runner.pas`, `compiler/frontend/np_workspace_model.pas` | bootstrap `SysUtils` | delegate to fs/platform/process owners if ever surfaced | no live path surface in `nextpas.core.system.sysutils` | focused compiler/toolchain compile/test gate |
| filesystem discovery helpers | `FileExists`, `DirectoryExists`, `ForceDirectories`, `FileSearch` in compiler toolchain/workspace code | bootstrap `SysUtils` | keep implementation outside system | no live filesystem surface in `nextpas.core.system.sysutils` | toolchain/workspace consumer gate |
| string convenience | `LowerCase`, `UpperCase`, `StrToInt` in compiler semantic code | bootstrap `SysUtils` | stay explicit about text/number ownership | no live broad string-helper surface in `nextpas.core.system.sysutils` | semantic-model and analyzer consumer gate |
| `CompareText` | no focused consumer pressure in this lane | historical `SysUtils` surface only | keep deferred unless a real consumer appears | do not add | focused consumer gate proving exact need |
| `PTypeInfo`, `TTypeKind`, `TypeInfo` | `compiler/tests/test_typinfo_contract.pas`, `core/src/nextpas.core.collections.element_manager.pas`, `core/src/nextpas.core.collections.hashmap.swiss.pas` | minimal live `nextpas.core.system.typinfo` plus compiler/System compile-truth | keep as identity and kind truth only; no property layout promise | minimal live unit | focused RTTI/collections + compiler contract gate |
| TTypeKind collections coverage | `core/src/nextpas.core.collections.base.pas` | minimal live `nextpas.core.system.typinfo` kind aliases | expose kind names used by comparer/equality dispatch without exposing metadata layout | live within `TTypeKind` contract | system TypInfo kind alias gate with heaptrc proof |
| `InitializeArray`, `CopyArray`, `FinalizeArray` | `compiler/tests/test_typinfo_contract.pas`, `core/src/nextpas.core.collections.element_manager.pas` | minimal live `nextpas.core.system.typinfo` wrappers over `System` helpers | treat as runtime-managed lifetime ABI, not reflection sugar | minimal live unit | leak-sensitive managed-array gate |
| `GetTypeKind` | `core/src/nextpas.core.collections.hashmap.swiss.pas`, `core/src/nextpas.core.collections.btree.pas`, `core/src/nextpas.core.collections.concurrent.hashmap.pas` | compiler/System compile-truth imported with the minimal facade | keep tied to compiler/runtime type truth; do not fake a wrapper | minimal live compile-truth contract | collection contract gate proving stable type-kind semantics |
| TypInfo minimal pressure audit | `core/docs/system/typinfo-minimal-pressure.md` | minimal live unit plus source-contract guard | seven-symbol set only; no property reflection | accepted by minimal live unlock | compiler TypInfo contract + collections managed-lifetime + heaptrc gate |
| `TFileStream` | `compiler/toolchain/np_toolchain_runner.pas`, multiple TLS/context units | bootstrap `Classes` | if ever surfaced, treat as IO-facing compatibility seam only | no live `nextpas.core.system.classes` unit | toolchain + file IO consumer gate with leak proof |
| `TStringList` | `rtl/core/classes/np_classes.pas`, compiler/tooling and TLS helpers | bootstrap `Classes` | consider only as a narrow compatibility subset, not container ownership | no live `nextpas.core.system.classes` unit | focused consumer gate proving exact subset |
| file mode constants | `fmCreate`, `fmOpenRead`, `fmShareDenyNone` in stream users | bootstrap `Classes` | keep coupled to any future `TFileStream` review, not standalone expansion | no live `nextpas.core.system.classes` unit | same gate as `TFileStream` |
| `TObject.Free` compatibility | compiler semantic model around object/class truth | compiler/runtime System truth, not core facade | keep under compiler/runtime and `nextpas.core.system` root contract | already documented at root; not a `classes` starter API | compiler/runtime integration gate |
| property reflection helpers | no focused consumer pressure in this lane | historical `TypInfo` surface | out of scope until compiler-backed RTTI model exists | do not add | dedicated reflection design review |
| `TComponent` / `TPersistent` / streaming framework | no focused consumer pressure in this lane | historical `Classes` surface | explicitly out of scope | do not add | separate architecture plan required |

## Interpretation

- Real pressure exists today for bootstrap `SysUtils`, `TypInfo`, and a small
  `Classes` subset.
- SysUtils pressure is enough for a minimal exception-formatting plus
  `SameText`, `IntToStr`, and `Trim` unit, but not for path, file,
  environment, time, parsing, case conversion, or broad string-helper
  compatibility.
- The pressure is not yet proof that a public `nextpas.core.system.classes`
  unit should exist.
- `TypInfo` has the strongest architectural pressure, so it now has a minimal
  live unit, but it also has the highest ABI risk.
- The TypInfo candidate is narrowed in `typinfo-minimal-pressure.md`; the live
  unit is limited to seven symbols and does not include property reflection or
  metadata layout guarantees.
- `SysUtils` has the broadest consumer count, but most of that pressure still
  belongs to owner modules or bootstrap RTL rather than `system` ownership.
- `Classes` pressure is narrow and concrete, but narrow pressure is exactly why
  the future unit must stay narrow if it is ever approved.

## Recommendation

Keep the current TypInfo live surface narrow. If future S4 pressure appears,
prefer:

1. broader `system.typinfo` only after a dedicated RTTI metadata review
2. `system.classes` file/stream subset only if a named consumer needs
   the namespace path
3. broader `system.sysutils` last, and only as a tiny delegating compatibility layer
