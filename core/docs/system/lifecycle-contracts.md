# System Lifecycle Contracts

This document records S3-level contracts for exception raise/unwind, RTTI / TypeInfo truth, unit
initialization and unit finalization. These are compiler/runtime handshake contracts, not public ABI and
not current `nextpas.core.system` facade functions.

FPC-compatible source may provide a stage0 host fallback, but lifecycle semantics
remain owned by `np.system.*` contracts and compiler/runtime metadata.

`nextpas.core.system.contracts` mirrors lifecycle vocabulary only. Unit order
comes from compiler metadata, not runtime path discovery or a registry.

## Exception Boundary

`nextpas.core.system` owns the RTL-root vocabulary for exception raise and unwind behavior, but the
exception taxonomy owner remains `nextpas.core.exception` / `nextpas.core.errors`.

Rules:

- The compiler decides where an exception raise enters control flow.
- Runtime performs the raise/unwind mechanics for already-lowered semantics.
- `nextpas.core.exception.ENextPasError` remains the canonical framework root for public taxonomy.
- Runtime fault reporting must not invent a parallel public exception hierarchy inside system.
- Failure diagnostics must preserve the distinction between compile-time diagnostics and runtime faults.

Current S3 stance:

- No callable `RaiseException` facade is exposed by `nextpas.core.system`.
- No new exception class is introduced for system lifecycle work.
- The runtime-fault contract name is `np.system.runtime_fault`.
- Current LLVM exception lowering may use backend-private exception helpers
  such as `@np_try_push`, `@np_try_pop`, `@np_finally_end`,
  `@np_except_end`, and `@np_raise`. These helper names are LLVM/backend
  evidence only, not public ABI, not public Pascal facade, not final unwind ABI,
  and not exception taxonomy owned by system.
- HIR exception tests may use those helpers to prove try/finally/except/raise
  lowering shape. They do not prove final exception object layout, unwinder
  strategy, diagnostics, or public taxonomy behavior.

## RTTI And TypeInfo Boundary

RTTI and TypeInfo need compiler-owned truth before runtime can expose stable data. This boundary states:
minimal TypInfo facade is live, but S3 still does not freeze RTTI metadata layout, binary metadata, or
broader reflection APIs.

Rules:

- Symbol/type identity, layout and generic/specialization facts are compiler-owned.
- Runtime may consume emitted metadata, but it must not re-infer language semantics.
- `TypeInfo` availability must be explicit in compiler output; missing RTTI must fail deterministically.
- Broader TypInfo reflection compatibility work belongs to S4+ and requires separate API tests.
- The `np.system.*` names in this document are contract vocabulary only, not public Pascal facade.

Current S3 stance:

- `nextpas.core.system.typinfo` is live as a minimal facade for `PTypeInfo`, `TTypeKind`, kind aliases
  and `InitializeArray` / `FinalizeArray` / `CopyArray`.
- No RTTI helper symbol name is frozen beyond the minimal live TypInfo surface and this boundary document.
- Broader RTTI metadata and property reflection remain future compiler/runtime work; `TypeInfo` /
  `GetTypeKind` stay compiler/System compile-truth, with the minimal facade only naming identity/kind and
  managed-array helper surface.

## Process Lifecycle

Process startup and shutdown are the first lifecycle contracts with compiler
semantic seed truth. The semantic analyzer records exact process-level
`runtime-contract` nodes for `np.system.process_init` followed by
`np.system.process_fini` when the root is a program, library or package.

Current S3 stance:

- `np.system.process_init` and `np.system.process_fini` are live compiler
  semantic contracts.
- Runtime execution of process startup/shutdown remains deferred.
- No callable `nextpas.core.system` facade function is exposed for either
  contract.
- Unit initialization and finalization are not upgraded by this contract; they
  still require compiler-owned unit graph execution evidence before becoming
  live.

## Unit Lifecycle

Unit initialization and unit finalization must be deterministic and derived from compiler-owned unit graph
truth. Runtime executes a plan; it does not discover or reorder units by scanning paths.

| Contract | Meaning | Owner boundary |
| --- | --- | --- |
| `np.system.unit_init` | enter a unit initialization body chosen by the compiler-owned plan | system contract, runtime implementation deferred |
| `np.system.unit_fini` | enter a unit finalization body from the reverse plan | system contract, runtime implementation deferred |
| `np.system.runtime_fault` | classify non-ignorable runtime lifecycle failure | system contract, taxonomy owner remains exception/errors |

Rules:

- Initialization order comes from the resolved UnitGraph, not from runtime path discovery.
- A unit can initialize at most once in a process execution.
- Only units whose initialization completed may enter finalization.
- finalization uses reverse dependency order, so dependents finalize before the units they depend on.
- If unit initialization fails, the program body must not execute.
- If unit initialization fails, cleanup is limited to units already initialized successfully.
- Unit finalization failure must be reported as a runtime fault and must not be disguised as a compile-time diagnostic.

## Runtime Fault Classification

Runtime failures must be classifiable by harness and smoke tests. S3 keeps the minimum categories aligned
with repository-level runtime bootstrap docs:

| Classification | Meaning |
| --- | --- |
| `runtime-startup-failed` | process-level system startup failed before user program execution |
| `unit-initialization-failed` | a unit initialization body failed and program body must not run |
| `unit-finalization-failed` | a unit finalization body failed during shutdown |
| `runtime-abort` | runtime reached a non-recoverable abort/fault path |

Rules:

- Runtime fault classification is evidence vocabulary for tests and diagnostics.
- Public exception taxonomy still goes through `nextpas.core.exception`.
- A backend must not invent private lifecycle failure categories without updating this contract.

## Verification Expectations

Future implementation work must add focused tests for:

- initialization order and finalization reverse dependency order;
- init failure preventing program-body execution;
- finalization only for successfully initialized units;
- runtime-startup-failed, unit-initialization-failed, unit-finalization-failed and runtime-abort reporting;
- exception raise/unwind behavior once runtime mechanics exist;
- RTTI / TypeInfo metadata availability and deterministic missing-metadata failure once compiler output exists.
