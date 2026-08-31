# nextpas.core.system

`nextpas.core.system` 是 nextPas 的 namespaced facade 与 compiler/runtime contract
vocabulary 入口，不是 compiler 的 magic `System` root。它承接 FPC `System` 心智里的
最低语言运行期契约，但在 nextPas 中必须保持 owner boundary：能委派给已有 owner 的能力
只做窄 facade，未来 compiler/runtime 才会消费的能力先写成文档 contract，不抢跑成
public ABI。

这个模块不是 `nextpas.core.base` 的机械拆分，也不是新的 `SysUtils` 杂货箱。它的长期目标是让
compiler、toolchain、future public RTL 与 core framework 对同一套 runtime truth 达成一致：
program startup/shutdown、unit initialization/finalization、compiler intrinsic contract、ABI truth、
managed type lifetime、memory primitive、exception/unwinding、RTTI/TypeInfo 和 object/interface
最低语义都必须有明确归属。

## Current authority and status

The compiler and L0 System are one bootstrap spine. M0 truth convergence is in progress:
`rtl/core/system/System.pas` is the canonical compiler-root source,
`units/linux-x86_64/System.pas` is its checked Linux x86_64 projection, and
`nextpas.core.system*` is a facade/contract family rather than another root implementation.

The repository is not self-host ready. Stage0 compiler fixtures and several runtime contracts work,
but a complete executable A -> B -> C rebuild has not executed: the M2 ladder is green through
L0-L2, and L3 (full stage0 driver A -> B link) is blocked on residual undefined symbols at the
LLVM `opt` stage (live status: `self-hosting-readiness.md` and `docs/plans/m2/wave0-ledger.md`).
Historical S0-S12 sections below are capability inventories and proposals; they are not current
readiness authority.

## Position

`nextpas.core.system` is not the RTL root. In the core framework it is the facade/contract
counterpart of `rtl/core/system/`:

- 对编译器/runtime：记录 `np.system.*` contract 名称和未来 runtime helper 边界。
- 对框架消费者：提供少量稳定、低层、可测试的 facade。
- 对 owner 模块：不绕过已有实现所有权，不复制平台、内存、文本、文件、时间、IO 等模块。

## Historical facade and capability inventory

The following S4-S12 records preserve earlier capability assessments. Their completion labels,
surface counts, ABI notes, and test counts are not current evidence of compiler-root ownership,
runtime completeness, self-hosting, or production readiness.

### Historical facade structure (S7-S8)

双编译器架构：
- FPC 路径：`fpc.inc` re-export FPC System 类型
- nextPas 路径：`kernel.inc` → 17 个子模块（base/str/intf/cls/rtti/except/mem/memmgr/lifecycle/endian/barrier/intrinsics/thread/io/comp）

门面文件：
- `system.pas` — 根门面，re-export 基础类型和常量
- `typinfo.pas` — RTTI 门面（PTypeInfo/TTypeKind/GetPropInfo/GetEnumName/GetEnumValue）
- `sysutils.pas` — SysUtils 门面（40+ 函数：数值转换/字符串/日期时间/文件系统/路径/环境变量）
- `errors.pas` — 异常分类门面（38 exception + 18 error category）

### Root facade live surface (historical inventory)

| Surface | Current owner | System stance |
| --- | --- | --- |
| `NEXTPAS_SYSTEM_NAME` | `nextpas.core.system` | root module identity only. |
| `MAX_SIZE_INT`, `MAX_SIZE_UINT`, `MIN_SIZE_INT`, `SIZE_PTR`, `SIZE_8`, `SIZE_16`, `SIZE_32`, `SIZE_64` | `nextpas.core.base` | mirrored compile-time constants; no new sizing policy. |
| `SizeInt`, `SizeUInt`, `PtrInt`, `PtrUInt`, `NativeInt`, `NativeUInt` | compiler `System` | ABI carrier aliases; no new target sizing policy or layout promise beyond compiler truth. |
| `TBytes`, `TByteSpan`, `THashCode` | `nextpas.core.base` | carrier aliases for RTL-root consumers; base remains owner. |
| `Exception`, `ExceptClass`, `EConvertError`, `EAssertionFailed`, `ENextPasError`, `TErrorCategory` | `nextpas.core.exception` | canonical exception aliases; no shadow taxonomy. |
| `EArgumentError`, `ETimeoutError`, `EIOError`, `EOutOfMemoryError` and the other `nextpas.core.errors` classes / `ec*` constants | `nextpas.core.errors` public facade; canonical definitions remain in `nextpas.core.exception` | public taxonomy aliases; categories stay canonical. |
| `ZeroMem`, `FillMem`, `CopyMem`, `CompareMem`, `FreeAndNil`, `SafeFree`, `Supports` | `nextpas.core.base.utils` | inline forwarding helpers; guard and nil behavior stay with base utils. |
| `Variant`, `TVarType`, `TVarData` | `nextpas.core.system` (kernel) | Variant type definitions with varEmpty..varUString constants. |
| `TThread`, `TRTLCriticalSection`, `BeginThread`, `EndThread` | `nextpas.core.system` (kernel) | Thread type definitions for compiler type resolution. |
| `Text`, `File`, `TFileRec`, `TTextRec` | `nextpas.core.system` (kernel) | I/O type definitions for compiler. |
| `TMemoryManager`, `TMemoryManagerEx` | `nextpas.core.system` (kernel) | Memory manager interface records. |
| `SwapEndian`, `BEtoN`, `LEtoN`, `NtoBE`, `NtoLE` | `nextpas.core.system` (kernel) | Byte swap/endian conversion functions. |
| `FillByte`, `IndexChar`, `CompareChar`, `MemPos`, `StackTop` | `nextpas.core.system` (kernel) | Bulk fill/search/compare intrinsics. |
| `PTypeInfo`, `TTypeKind`, `PTypeData`, `TTypeData` | `nextpas.core.system.typinfo` | RTTI type aliases for compiler/runtime. |
| `GetPropInfo`, `GetEnumName`, `GetEnumValue` | `nextpas.core.system.typinfo` | RTTI access functions. |
| `Format`, `SameText`, `IntToStr`, `Trim` + 40+ SysUtils-named functions | **owner: `nextpas.core.text.conv`** (and path/fs/platform for non-text slices); surface: `nextpas.core.system.sysutils` | SysUtils **compatibility facade only** — re-exports / forwards to owner modules; never the implementation owner of text APIs. |

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

Historical S4 inventory records the claim that `nextpas.core.system.errors` is
a live facade re-exporting all 38 exception type aliases and 18 error-category
constants from their canonical owners (`nextpas.core.exception`, `nextpas.core.base`,
`nextpas.core.errors`). `nextpas.core.system.typinfo`
has a live unit covering PTypeInfo, TTypeKind, PTypeData, TTypeData, GetPropInfo,
GetEnumName, GetEnumValue. `nextpas.core.system.sysutils` has a live unit with 40+ functions
delegating to owner modules (text.conv, path, fs, platform). `nextpas.core.system.classes` is live as a minimal stream shim (TStream/TFileStream/TStringList etc.); broader Classes surface remains deferred.

The system focused gate also includes a collections consumer proof for
`TElementManager<string>` so TypInfo managed-array helpers stay tied to a real
managed-lifetime path, not just standalone helper calls.

Historical S5 inventory is retained in `goal-tree.md` for traceability.
The contract coverage table in `contract-coverage-table.md` maps all live
`np.system.*` contracts to their HIR evidence, LLVM helper evidence, and test
coverage, with explicit gap annotations for contracts missing HIR intrinsic
names or focused tests.

Historical S6 inventory records exception-boundary contracts, leak-sensitive test fill, contract
vocabulary audit, and self-hosting-readiness gate proposals.

Historical S7 inventory records a dual-compiler fork structure with 8 kernel sub-modules, compiler
root directives (`{$compiler_root}`, `{$compiler_type_kind}`), VMT layout definition,
and compiler internal functions (fpc_* series).

Historical S8 inventory records an earlier kernel-surface audit. It is not a claim of complete FPC
System coverage, a stable ABI, or present self-host readiness.

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
Classes. The minimal live unit for TypInfo covers PTypeInfo, TTypeKind, PTypeData,
TTypeData, GetPropInfo, GetEnumName, GetEnumValue.
The current TypInfo review stop lives in
`../plans/2026-06-07-system-typinfo-minimal-unlock-review.md`; it records how
the earlier `Needs Review` packet moved into this minimal live unlock.
The S5 compiler integration contract lives in
`compiler-integration-contract.md`; it records that source-backed System truth
must flow through `nextpas.core.system` vocabulary and must not become
backend-private magic strings.
The S6 self-hosting readiness gates live in `self-hosting-readiness.md`.
The S7 kernel design lives in `kernel-design.md` with architecture, file inventory,
and FPC System mapping table.
The ABI notes in `abi-specification.md` record proposed VMT layout, `fpc_*` signatures, type memory
layouts, and calling conventions. They are not a current ABI-stability commitment.
The API reference lives in `api-reference.md`; it is the developer quick-reference
for all types, functions, and facades exported by the system kernel.
The design decisions live in `design-decisions.md`; it records 15 key architectural
decisions with background, options, choices, and consequences to prevent future
developers from repeating mistakes or making contradictory changes.
The usage guide lives in `usage-guide.md`; it guides developers on how to
extend the kernel and use its types, functions, and facades in their code.
Error handling guidance lives in `error-handling.md`; it covers exception
hierarchy, error classification, propagation, and best practices.
Thread safety guidance lives in `thread-safety.md`; it covers synchronization
primitives, thread management, and concurrency best practices.
Platform differences live in `platform-differences.md`; it covers type sizes,
byte order, calling conventions, memory layout, thread model, I/O, and
cross-platform programming guidelines.
Dynamic array lifecycle lives in `dynamic-array-lifecycle.md`; it covers
memory layout, reference counting, copy-on-write, and lifecycle management.
Memory ordering guarantees live in `memory-ordering.md`; it covers memory
barriers, atomic operation ordering, and common concurrency patterns.

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

Historical S4 boundary note:

- `system.errors` is live as an exception taxonomy facade, re-exporting all 38
  exception type aliases and 18 error-category constants from canonical owners
- `system.classes` is live as a stream-only bootstrap shim (TStream, THandleStream, TMemoryStream, TStringStream, TSeekOrigin). TThread, TList, TInterfacedObject remain outside system scope and belong to their respective owner modules (thread, collections, base).
- `system.sysutils` is a **live thin facade** (not implementation owner) with 40+ SysUtils-named functions: text (Format, SameText, IntToStr, Trim → **owner `text.conv`**), numeric parsing (→ text.conv), date/time (→ time/platform owners), filesystem (→ fs), path (→ path), environment (→ platform), timing, error helpers. Do not document sysutils as owner of these domains.
- `system.typinfo` is live for `PTypeInfo`, `TTypeKind`, `PTypeData`, `TTypeData`, `GetPropInfo`, `GetEnumName`, `GetEnumValue`
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
`np.system.process_init` followed by `np.system.process_fini`. Focused HIR/LLVM
call-shape evidence exists (`test_process_lifecycle` / `_llvm`); ledger stays
**scelHir**. Runtime **business** execution, full process init, and fault handling
are still deferred and must not be treated as a public callable facade or
self-host proof.

**Host-free policy (stage0)**: claims of host-free executable lifecycle evidence
must use `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` (see Makefile
targets `test-compiler-unit-init-chain`, `test-compiler-unit-fini-body`,
`test-compiler-unit-lifecycle-llvm`). Default `nextpas build` without that binding
uses `fpc-stage0-host` and must not be cited as host-free. The global default
binding is intentionally unchanged.

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

## Current bootstrap roadmap

```
M0    truth convergence: canonical source, checked projection, typed ledger
M1    minimum bootstrap kernel
M2    typed compiler-system dispatch, fingerprint, semantic snapshot
M3    executable runtime behavior
M4    actual A -> B -> C bootstrap
M5    determinism and performance evidence
```

See `goal-tree.md` for current M0 evidence and the archived S-stage inventory.
- Do not move `nextpas.core.base`, exception, mem, platform, text, fs, time, math or io implementation details into this module.
