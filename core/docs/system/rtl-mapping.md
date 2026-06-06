# RTL Mapping For nextpas.core.system

This mapping is intentionally concrete but not exhaustive. Each row names the current nextPas
ownership status so future slices can expand the module without turning it into a historical RTL dump.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `system-owned` | `nextpas.core.system` owns the stable contract and will eventually own the implementation. |
| `system facade delegating to owner` | `system` may expose a compatibility entry point, but implementation remains in the named owner module. |
| `owned by another module, no system facade yet` | Another module owns it and this slice deliberately exposes no system facade. |
| `future compiler/runtime only` | This is a compiler/runtime handshake item, not current public Pascal API. |
| `explicitly out of scope` | The surface is not part of the current nextPas system direction. |

## FPC System

| FPC capability | nextPas status | nextPas owner / notes |
| --- | --- | --- |
| Program startup and shutdown | `future compiler/runtime only` | `rtl/core/system` contract names `np.system.process_init` and `np.system.process_fini`. |
| `Halt` / exit code semantics | `future compiler/runtime only` | `np.system.halt`; no public facade until runtime behavior is testable. |
| Unit initialization/finalization order | `future compiler/runtime only` | Compiler owns `UnitGraph`; runtime executes `np.system.unit_init` / `np.system.unit_fini`. |
| Compiler intrinsic names | `future compiler/runtime only` | Intrinsic contract names stay explicit; backend must not invent private helper strings. |
| Pointer/integer/ABI truth | `system-owned` | Minimal constants can be surfaced from `nextpas.core.base`; host/target ABI remains platform-owned. |
| `TObject`, constructor, destructor, `Free` | `future compiler/runtime only` | Source-backed System truth already exists in compiler/runtime docs; core facade does not re-declare it yet. |
| `TBytes` and basic byte containers | `system facade delegating to owner` | Delegates to `nextpas.core.base.TBytes`. |
| Memory primitives: fill/copy/compare | `system facade delegating to owner` | Delegates to `nextpas.core.base.utils`; heap ownership stays with `nextpas.core.mem`. |
| Heap manager contract | `future compiler/runtime only` | Future contract over `nextpas.core.mem`, not an allocator implementation inside system. |
| Managed strings | `future compiler/runtime only` | Runtime lifetime contract belongs here eventually; advanced Unicode/text APIs stay in `nextpas.core.text`. |
| Dynamic arrays | `future compiler/runtime only` | Managed lifetime and compiler lowering contract; no public ABI in S0/S1. |
| Interfaces | `future compiler/runtime only` | Managed lifetime and reference-count contract; no public ABI in S0/S1. |
| Managed records | `future compiler/runtime only` | Compiler/runtime lifetime contract; no public ABI in S0/S1. |
| Exception raise/unwind root | `system facade delegating to owner` | Canonical owner is `nextpas.core.exception`; `system` aliases only. |
| RTTI / `TypeInfo` primitive contract | `future compiler/runtime only` | Mapping recorded here; implementation deferred to RTTI/typinfo stages. |
| File I/O helpers | `owned by another module, no system facade yet` | `nextpas.core.fs` / `nextpas.core.io`. |
| Time/date helpers | `owned by another module, no system facade yet` | `nextpas.core.time` and platform time modules. |
| Math helpers | `owned by another module, no system facade yet` | `nextpas.core.math`; compatibility aliasing is S4+ only. |

## FPC SysUtils

| FPC capability | nextPas status | nextPas owner / notes |
| --- | --- | --- |
| Exception base aliases | `system facade delegating to owner` | `nextpas.core.exception` and `nextpas.core.errors`. |
| Conversion/parsing helpers | `owned by another module, no system facade yet` | Text/encoding/validation modules decide exact surfaces. |
| Filesystem path and file helpers | `owned by another module, no system facade yet` | `nextpas.core.fs`; system does not own filesystem behavior. |
| Date/time formatting | `owned by another module, no system facade yet` | `nextpas.core.time`; no S0/S1 facade. |
| Environment/process helpers | `owned by another module, no system facade yet` | platform/process modules. |
| Broad historical convenience API | `explicitly out of scope` | Not copied wholesale into nextPas. |

## FPC TypInfo

| FPC capability | nextPas status | nextPas owner / notes |
| --- | --- | --- |
| `TypeInfo` identity | `future compiler/runtime only` | Needs compiler-backed RTTI truth first. |
| Property metadata | `future compiler/runtime only` | Requires RTTI model and reflection policy. |
| String-based property access | `explicitly out of scope` | Not part of S0/S1; future compatibility requires separate design. |

## FPC Classes

| FPC capability | nextPas status | nextPas owner / notes |
| --- | --- | --- |
| `TObject` baseline | `future compiler/runtime only` | Tracked through source-backed System truth, not exposed by core facade yet. |
| Streams | `owned by another module, no system facade yet` | `nextpas.core.io`. |
| Collections | `owned by another module, no system facade yet` | `nextpas.core.collections`. |
| Components/ownership tree | `explicitly out of scope` | Not part of core-system S0/S1. |
| Persistent/streaming framework | `explicitly out of scope` | Future compatibility requires a dedicated plan. |

## FPC ObjPas

| FPC capability | nextPas status | nextPas owner / notes |
| --- | --- | --- |
| Object Pascal mode support | `future compiler/runtime only` | Compiler semantic layer owns language interpretation. |
| Basic object/class vocabulary | `future compiler/runtime only` | Runtime system owns only the minimum helper contract after compiler truth exists. |
| Alternate historical compatibility switches | `explicitly out of scope` | No new syntax or mode compatibility is introduced by this module. |
