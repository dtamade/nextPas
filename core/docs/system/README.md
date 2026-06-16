# nextpas.core.system

`nextpas.core.system` 是 nextPas 面向未来 RTL root 的 core 模块族入口。它承接
FPC `System` 心智里的最低语言运行期契约，但在 nextPas 中必须保持 owner boundary：
能委派给已有 owner 的能力只做窄 facade，未来 compiler/runtime 才会消费的能力先写成
文档 contract，不抢跑成 public ABI。

这个模块不是 `nextpas.core.base` 的机械拆分，也不是新的 `SysUtils` 杂货箱。它的长期目标是让
compiler、toolchain、future public RTL 与 core framework 对同一套 runtime truth 达成一致：
program startup/shutdown、unit initialization/finalization、compiler intrinsic contract、ABI truth、
managed type lifetime、memory primitive、exception/unwinding、RTTI/TypeInfo 和 object/interface
最低语义都必须有明确归属。

## Position

`nextpas.core.system` 在 core 框架里对应 `rtl/core/system/` 的设计前哨：

- 对编译器/runtime：记录 `np.system.*` contract 名称和未来 runtime helper 边界。
- 对框架消费者：提供少量稳定、低层、可测试的 RTL root facade。
- 对 owner 模块：不绕过已有实现所有权，不复制平台、内存、文本、文件、时间、IO 等模块。

Bootstrap compatibility rule: keep System-facing code as FPC-compatible source where that
helps genesis builds, but preserve nextPas-owned semantic authority through `np.system.*`
contracts. FPC can be the stage0 host compiler and adapter target; it must not define the
final object lifetime, managed lifetime, RTTI metadata, unit lifecycle, or runtime helper ABI.

首批代码只实现 S1 级 facade skeleton，并继续保持 delegating to owner：

- `TBytes` 等低层基础载体类型来自 `nextpas.core.base`。
- `ENextPasError`、`TErrorCategory` 和错误分类来自 `nextpas.core.exception` / `nextpas.core.errors`。
- `ZeroMem`、`FillMem`、`CopyMem`、`CompareMem`、`FreeAndNil`、`SafeFree` 和 `Supports` 只委派给
  `nextpas.core.base.utils`，保持现有 guard 和异常语义。

Root facade live surface:

| Surface | Current owner | System stance |
| --- | --- | --- |
| `NEXTPAS_SYSTEM_NAME` | `nextpas.core.system` | root module identity only. |
| `MAX_SIZE_INT`, `MAX_SIZE_UINT`, `MIN_SIZE_INT`, `SIZE_PTR`, `SIZE_8`, `SIZE_16`, `SIZE_32`, `SIZE_64` | `nextpas.core.base` | mirrored compile-time constants; no new sizing policy. |
| `SizeInt`, `SizeUInt`, `PtrInt`, `PtrUInt`, `NativeInt`, `NativeUInt` | compiler `System` | ABI carrier aliases; no new target sizing policy or layout promise beyond compiler truth. |
| `TBytes`, `TByteSpan`, `THashCode` | `nextpas.core.base` | carrier aliases for RTL-root consumers; base remains owner. |
| `Exception`, `ExceptClass`, `EConvertError`, `EAssertionFailed`, `ENextPasError`, `TErrorCategory` | `nextpas.core.exception` | canonical exception aliases; no shadow taxonomy. |
| `EArgumentError`, `ETimeoutError`, `EIOError`, `EOutOfMemoryError` and the other `nextpas.core.errors` classes / `ec*` constants | `nextpas.core.errors` public facade; canonical definitions remain in `nextpas.core.exception` | public taxonomy aliases; categories stay canonical. |
| `ZeroMem`, `FillMem`, `CopyMem`, `CompareMem`, `FreeAndNil`, `SafeFree`, `Supports` | `nextpas.core.base.utils` | inline forwarding helpers; guard and nil behavior stay with base utils. |

S2 runtime/managed lifetime contract names live in `runtime-contracts.md`. They are documented
compiler/runtime handshake names, not public ABI and not current facade functions.
The compiler may project managed dynamic-array operations as
`np.system.dynarray_set_length`, `np.system.dynarray_fini` and nested element
contracts such as `np.system.string_fini` and `np.system.interface_release`;
those names describe semantics and do not freeze backend-private helper symbols.

S3 lifecycle contract names and evidence categories live in `lifecycle-contracts.md`. They cover
exception raise/unwind ownership, RTTI / TypeInfo boundary rules, unit initialization/finalization
ordering and runtime-fault classification.

`nextpas.core.system.contracts` is the compact vocabulary anchor for these
runtime and lifecycle names. It is constants-only: no helper implementation, no
runtime registry, and no broader SysUtils, Classes or TypInfo surface.

S4 compatibility facades are now split by evidence. `nextpas.core.system.typinfo`
has a minimal live unit for the seven-symbol TypInfo pressure set, and
`nextpas.core.system.sysutils` has a minimal live exception-formatting,
`SameText`, `IntToStr`, and `Trim` facade for `Format`, `SameText`,
`IntToStr`, `Trim`, plus canonical exception aliases.
Classes remain deferred.
The live TypInfo unit is a compile-truth/runtime-helper bridge; it is not a
complete FPC `TypInfo` reflection facade and does not freeze metadata layout ABI
beyond minimum identity, kind, and managed-array helper contracts. The live
SysUtils unit is not a path, file, environment, time, parsing, case-conversion,
or broad string-helper surface; `SameText`, `IntToStr`, and `Trim` are the only
currently live string helper additions beyond formatting.
The system focused gate also includes a collections consumer proof for
`TElementManager<string>` so TypInfo managed-array helpers stay tied to a real
managed-lifetime path, not just standalone helper calls.

S5 is now split into sub-stages. See `goal-tree.md` for the full staged path.
The contract coverage table in `contract-coverage-table.md` maps all live
`np.system.*` contracts to their HIR evidence, LLVM helper evidence, and test
coverage, with explicit gap annotations for contracts missing HIR intrinsic
names or focused tests.

Detailed S4 design-only material lives in `compatibility-facades.md` and
`compatibility-matrix.md`. Those docs distinguish bootstrap RTL pressure from a
future public `nextpas.core.system.*` compatibility surface.
The bootstrap dual-surface adapter contract lives in
`bootstrap-dual-surface-adapter.md`; it records that FPC-compatible source is a
stage0 build constraint, while nextPas-owned `np.system.*` contracts remain the
semantic authority. Minimal compatibility facades do not own System semantics;
they expose only reviewed, owner-delegating names.
The TypInfo-only minimal pressure audit lives in `typinfo-minimal-pressure.md`;
it records the seven-symbol candidate set without reopening broader SysUtils or
Classes.
The current TypInfo review stop lives in
`../plans/2026-06-07-system-typinfo-minimal-unlock-review.md`; it records how
the earlier `Needs Review` packet moved into this minimal live unlock.
The S5 compiler integration contract lives in
`compiler-integration-contract.md`; it records that source-backed System truth
must flow through `nextpas.core.system` vocabulary and must not become
backend-private magic strings.

## Boundaries

| Area | System stance |
| --- | --- |
| `nextpas.core.base` | source of shared low-level types and constants; system may re-export a small compatible subset. |
| `nextpas.core.exception` / `nextpas.core.errors` | canonical exception taxonomy owner; system may expose aliases only. |
| `nextpas.core.mem` | allocator, pool, arena and heap-manager implementation owner; system documents future heap contract but does not own allocators. |
| `nextpas.core.platform` | OS, ABI, syscall, process and host truth owner; system must not use `Windows`, `BaseUnix` or `Unix` directly. |
| `nextpas.core.text` | advanced string/unicode/text processing owner; system only documents managed string runtime contracts for future compiler work. |
| `nextpas.core.fs` | filesystem owner; no system file facade in S0/S1. |
| `nextpas.core.time` / `nextpas.core.platform.time` | time and clock owners; no system time facade in S0/S1. |
| `nextpas.core.math` | math owner; system may later expose compatibility aliases only after focused tests. |
| `nextpas.core.io` | stream and IO owner; no system IO facade in S0/S1. |
| atomic/sync/thread modules | concurrency owners; system does not own locks, atomics or scheduler policy. |

S4 boundary note:

- no public unit yet for `system.classes`
- `system.sysutils` is live only for `Format`, `SameText`, `IntToStr`, `Trim`,
  `Exception`, `ExceptClass`, `EConvertError`, and `EAssertionFailed`
- `system.typinfo` is live for `PTypeInfo`, `TTypeKind`,
  `InitializeArray`, `FinalizeArray`, `CopyArray`, and the kind aliases used by
  current consumers
- `TypeInfo` and `GetTypeKind` are compiler/System compile-truth imports made
  available to consumers after the facade is in `uses`; they are not unit-owned wrapper functions in `nextpas.core.system.typinfo`
- `TTypeKind` aliases cover live collections kind consumers, but do not expose
  property metadata or reflection layout
- deferred means “documented and guarded by source-contract”, not “silently available”
- any broader compatibility facade must arrive with real consumer pressure and focused API tests

## Contract Names

The stable architecture docs already use explicit runtime contract names. `nextpas.core.system`
documents them here but does not claim implementation readiness in this slice:

| Contract | Meaning | Current state |
| --- | --- | --- |
| `np.system.process_init` | process-level runtime startup | compiler semantic contract live; runtime execution deferred |
| `np.system.process_fini` | process-level runtime shutdown | compiler semantic contract live; runtime execution deferred |
| `np.system.unit_init` | run a unit initialization entry | future compiler/runtime only |
| `np.system.unit_fini` | run a unit finalization entry | future compiler/runtime only |
| `np.system.halt` | explicit program termination | compiler/HIR contract live; no callable public facade |
| `np.system.object_free` | object `Free` nil guard, destructor, optional cleanup and release intent | compiler/HIR contract live; no callable public facade |
| `np.system.runtime_fault` | non-ignorable runtime fault | future compiler/runtime only |

Process-level startup and shutdown currently have compiler semantic seed truth:
program, library and package roots project exact `runtime-contract` entries for
`np.system.process_init` followed by `np.system.process_fini`. Runtime execution,
unit lifecycle ordering and fault handling are still deferred and must not be
treated as a public callable facade.

Object-free lowering now has source-backed System truth: `rtl/core/system/System.pas`
is the compiler-visible minimum root for `TObject.Create`, `TObject.Destroy`,
and `TObject.Free`. The focused `test-stage0-system-object-free-query` gate
provides stage0 query evidence that both explicit `uses System` and implicit
System resolution bind ordinary class `Free` calls to `System.TObject.Free`
with definitions under `units/linux-x86_64/System.pas`. This evidence keeps the
compiler/runtime contract aligned with the source-backed unit, but it still
does not expose `TObject` or `Free` as a public `nextpas.core.system` facade.

## non-goals

- Do not clone the historical FPC `System` / `SysUtils` / `Classes` grab bag into nextPas.
- Do not bypass owner boundary by calling OS units such as `Windows`, `BaseUnix` or `Unix` from system units.
- Do not create a bare `System.pas` in `core/src`; that would conflict with FPC magic-unit expectations.
- Do not expose future compiler/runtime helper names as callable public ABI before tests and runtime integration exist.
- Do not move `nextpas.core.base`, exception, mem, platform, text, fs, time, math or io implementation details into this module.
