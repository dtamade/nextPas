# S4 Compatibility Matrix

This matrix turns current S4 pressure into concrete review inputs. The point is
to record live evidence and a recommended boundary, not to pre-approve a public
unit.

| Capability | Live evidence | Current provider | Recommended nextPas stance | Current S4 decision | Future unlock gate |
| --- | --- | --- | --- | --- | --- |
| `Format`, `Exception.CreateFmt`, `ExceptClass`, `EAssertionFailed` | `compiler/tests/test_sysutils_createfmt_contract.pas` | bootstrap `SysUtils` plus `nextpas.core.exception` re-export | keep exception taxonomy in `nextpas.core.exception`; any compatibility surface must stay narrow | no live `nextpas.core.system.sysutils` unit | compiler contract test plus exception taxonomy gate |
| path normalization | `compiler/toolchain/np_toolchain_runner.pas`, `compiler/frontend/np_workspace_model.pas` | bootstrap `SysUtils` | delegate to fs/platform/process owners if ever surfaced | no live `nextpas.core.system.sysutils` unit | focused compiler/toolchain compile/test gate |
| filesystem discovery helpers | `FileExists`, `DirectoryExists`, `ForceDirectories`, `FileSearch` in compiler toolchain/workspace code | bootstrap `SysUtils` | keep implementation outside system | no live `nextpas.core.system.sysutils` unit | toolchain/workspace consumer gate |
| string convenience | `SameText`, `Trim`, `LowerCase`, `UpperCase`, `IntToStr`, `StrToInt` in compiler semantic code | bootstrap `SysUtils` | stay explicit about text/number ownership | no live `nextpas.core.system.sysutils` unit | semantic-model and analyzer consumer gate |
| `PTypeInfo`, `TTypeKind`, `TypeInfo` | `compiler/tests/test_typinfo_contract.pas`, `core/src/nextpas.core.collections.element_manager.pas`, `core/src/nextpas.core.collections.hashmap.swiss.pas` | FPC `TypInfo` today | this is the most credible future `system.typinfo` slice | design pressure recorded, but no live unit | focused RTTI/collections + compiler contract gate |
| `InitializeArray`, `CopyArray`, `FinalizeArray` | `compiler/tests/test_typinfo_contract.pas`, `core/src/nextpas.core.collections.element_manager.pas` | FPC `TypInfo` today | treat as runtime-managed lifetime ABI, not reflection sugar | no live `nextpas.core.system.typinfo` unit | leak-sensitive managed-array gate |
| `GetTypeKind` | `core/src/nextpas.core.collections.hashmap.swiss.pas`, `core/src/nextpas.core.collections.btree.pas`, `core/src/nextpas.core.collections.concurrent.hashmap.pas` | FPC `TypInfo` today | keep tied to compiler/runtime type truth | no live `nextpas.core.system.typinfo` unit | collection contract gate proving stable type-kind semantics |
| `TFileStream` | `compiler/toolchain/np_toolchain_runner.pas`, multiple TLS/context units | bootstrap `Classes` | if ever surfaced, treat as IO-facing compatibility seam only | no live `nextpas.core.system.classes` unit | toolchain + file IO consumer gate with leak proof |
| `TStringList` | `rtl/core/classes/np_classes.pas`, compiler/tooling and TLS helpers | bootstrap `Classes` | consider only as a narrow compatibility subset, not container ownership | no live `nextpas.core.system.classes` unit | focused consumer gate proving exact subset |
| file mode constants | `fmCreate`, `fmOpenRead`, `fmShareDenyNone` in stream users | bootstrap `Classes` | keep coupled to any future `TFileStream` review, not standalone expansion | no live `nextpas.core.system.classes` unit | same gate as `TFileStream` |
| `TObject.Free` compatibility | compiler semantic model around object/class truth | compiler/runtime System truth, not core facade | keep under compiler/runtime and `nextpas.core.system` root contract | already documented at root; not a `classes` starter API | compiler/runtime integration gate |
| property reflection helpers | no focused consumer pressure in this lane | historical `TypInfo` surface | out of scope until compiler-backed RTTI model exists | do not add | dedicated reflection design review |
| `TComponent` / `TPersistent` / streaming framework | no focused consumer pressure in this lane | historical `Classes` surface | explicitly out of scope | do not add | separate architecture plan required |

## Interpretation

- Real pressure exists today for bootstrap `SysUtils`, `TypInfo`, and a small
  `Classes` subset.
- The pressure is not yet proof that public `nextpas.core.system.sysutils`,
  `nextpas.core.system.typinfo`, or `nextpas.core.system.classes` units should
  exist.
- `TypInfo` has the strongest architectural pressure, but also the highest ABI
  risk.
- `SysUtils` has the broadest consumer count, but most of that pressure belongs
  to owner modules or bootstrap RTL rather than `system` ownership.
- `Classes` pressure is narrow and concrete, but narrow pressure is exactly why
  the future unit must stay narrow if it is ever approved.

## Recommendation

Stay in design-only mode for S4 until a controller review asks for a named
unlock slice. If that happens, prefer:

1. `system.typinfo` minimal lifecycle-truth subset first
2. `system.classes` file/stream subset second, only if a named consumer needs
   the namespace path
3. `system.sysutils` last, and only as a tiny delegating compatibility layer

