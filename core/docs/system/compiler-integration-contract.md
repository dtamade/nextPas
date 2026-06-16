# S5 Compiler Integration Contract

This S5 slice defines how the compiler may depend on `nextpas.core.system`
without turning FPC compatibility into semantic authority.

`nextpas.core.system is the root kernel module` for core runtime contracts. The
compiler must consume nextpas.core.system through nextpas.core, and compiler
must not depend on a parallel System implementation. Historical `System`,
`SysUtils`, `TypInfo`, and `Classes` names may remain in stage0 tests or host
adapters, but they are not the nextPas semantic owner.

## Dual Path

| Path | Role | Authority |
| --- | --- | --- |
| FPC stage0 | FPC path is host-backed implementation for genesis builds | no semantic authority |
| nextPas target | nextPas path uses nextPas-owned kernel implementation | `np.system.*` and owner modules |

The shared API surface must stay `nextpas.core.system` plus reviewed child
facades. FPC-compatible source can keep bootstrap builds moving, but
source-backed System truth must be named in this module before compiler or
runtime code treats it as stable.

## Consumer Pressure

| Consumer | Required contract | Evidence |
| --- | --- | --- |
| compiler semantic analyzer | `TObject`, `Free`, `destructor`, `np.system.object_free` | consumer-pressure evidence in `compiler/sema/np_semantic_analyzer.pas` |
| HIR builder and LLVM emitter | `np.system.object_free.destroy`, `np.system.object_free.release` | compile-truth evidence in `compiler/ir/np_hir_builder.pas` and `compiler/ir/np_hir_llvm_emitter.pas` |
| runtime bootstrap plan | `np.system.unit_init`, `np.system.unit_fini` | architecture contract in `docs/architecture/runtime-bootstrap-specification.md` |
| collections and compiler TypInfo contract | `PTypeInfo`, `TTypeKind`, `InitializeArray`, `FinalizeArray`, `CopyArray` | minimal live `nextpas.core.system.typinfo` and focused system gate |

The compiler may emit `np.system.object_free` marker nodes, but backend-private
magic strings are not allowed to become hidden ABI. New helper names must be
documented here or in `runtime-contracts.md` / `lifecycle-contracts.md` before
they become a compiler/runtime dependency.

Guard vocabulary: compiler must not depend on a parallel System implementation;
backend-private magic strings; no broad FPC SysUtils; no live nextpas.core.system.classes.

## Boundary Rules

- Do not create a second long-term `System` surface for the compiler.
- Do not add a broad FPC SysUtils facade to satisfy a single consumer.
- Do not add a live nextpas.core.system.classes unit from bootstrap `Classes`
  pressure alone.
- Do not treat `TypeInfo` metadata layout from host FPC as nextPas target ABI.
- Do not widen object lifetime into a `Classes` facade before `TObject.Free`,
  destructor dispatch, nil guard, and heap release are verified through the
  `np.system.object_free` contract.

## Unlock Conditions

A future live integration slice must name the consumer, exact API or helper,
owner module, focused gate, and leak-sensitive evidence when managed lifetime
or object release is involved. Until then, this document is readiness-only:
it locks the contract vocabulary and the bypass bans, not a complete runtime
implementation.
