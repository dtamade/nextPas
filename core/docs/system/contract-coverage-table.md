# System Contract Coverage Table

This document records the current coverage state of all live `np.system.*` contracts,
mapping each contract name to its HIR evidence, LLVM helper evidence, and test coverage.

**Purpose**: Provide a single reference for landing candidate preparation and Codex review.

## Contract → HIR → Helper → Test Mapping

| Contract | HIR evidence | LLVM helper | Test coverage | Gap |
|----------|-------------|-------------|--------------|-----|
| `np.system.process_init` | `SeedRuntimeContracts` seeds as `runtime-contract` HIR node | No LLVM helper (runtime execution deferred) | `test-process-runtime-contract-seed` (semantic seed proof) | No execution smoke |
| `np.system.process_fini` | `SeedRuntimeContracts` seeds as `runtime-contract` HIR node | No LLVM helper (runtime execution deferred) | `test-process-runtime-contract-seed` (semantic seed proof) | No execution smoke |
| `np.system.object_free` | `np_hir_builder.pas` emits `np.system.object_free` intrinsic (nil guard + lifecycle group) | `@np_object_free_release` | stage0 query gate, HIR object-free focused gates | No direct-consume execution smoke |
| `np.system.object_free.destroy` | `np_hir_builder.pas:3932` sets `IntrinsicName := 'np.system.object_free.destroy'` | Mapped to virtual dispatch (`vcall` intrinsic for Destroy) | HIR object-free focused gates | Direct dispatch path not verified end-to-end |
| `np.system.object_free.cleanup` | `np_hir_builder.pas:4791` sets `IntrinsicName := 'np.system.object_free.cleanup'` | No dedicated LLVM helper (compiler-planned cleanup, currently field-agnostic) | HIR object-free focused gates | Cleanup semantics not tested with managed fields |
| `np.system.object_free.release` | `np_hir_builder.pas:3950` sets `IntrinsicName := 'np.system.object_free.release'` | `@np_object_free_release` → `@np_object_release_valid` / `@np_object_release_invalid` | stage0 query gate, LLVM object-free tests | Release path tested but cleanup-before-release ordering not verified |
| `np.system.interface_addref` | HIR uses `intf_addref` as implementation intrinsic (intentional) | `@np_intf_addref` (line 750) | `test_hir_interface_contract` | **Contract name in docs, impl name in HIR** |
| `np.system.interface_release` | HIR uses `intf_release` as implementation intrinsic (intentional) | `@np_intf_release` (line 756) | `test_hir_interface_contract` | **Contract name in docs, impl name in HIR** |
| `np.system.halt` | HIR uses `halt` as implementation intrinsic (intentional) | inline syscall (`movq $60, %rax; syscall`) | No focused test (halt intrinsic verified by source-contract) | **Contract name in docs, impl name in HIR** |
| `np.system.heap_alloc` | HIR uses `arr_alloc`, `class_alloc` as implementation intrinsics (intentional) | `@np_alloc` (line 686, 698, 1153, 1275), `@np_object_alloc` (line 734) | emitter integration tests (allocator paths covered) | **Contract name in docs, impl names in HIR** |
| `np.system.heap_free` | HIR uses backend helpers directly (intentional) | `@np_free` (line 1439) | emitter integration tests (allocator paths covered) | **Contract name in docs, impl helpers in backend** |
| `np.system.unit_init` | Not seeded (future feature) | No LLVM helper | No test | Fully deferred |
| `np.system.unit_fini` | Not seeded (future feature) | No LLVM helper | No test | Fully deferred |
| `np.system.runtime_fault` | Not seeded (future feature) | `@np_allocator_fault`, `@np_dynarray_fault` are partial evidence | No focused lifecycle fault test | Partial evidence only in allocator/dynarray contexts |

## Backend-Private Helper Names (NOT Public ABI)

The following `@np_*` names are LLVM implementation evidence, not stable public ABI.
They must not be used as facade contract symbols or treated as part of the `np.system.*` vocabulary.

| Helper | Purpose | Contract alignment |
|--------|---------|-------------------|
| `@np_alloc` | Heap allocation | Maps to `np.system.heap_alloc` (future) |
| `@np_free` | Heap release | Maps to `np.system.heap_free` (future) |
| `@np_object_alloc` | Object instance allocation | Part of `np.system.object_free` lifecycle group |
| `@np_object_free_release` | Object nil-guard + release | Maps to `np.system.object_free.release` |
| `@np_object_release_valid` | Release valid object allocation | Backend-private sub-step of object release |
| `@np_object_release_invalid` | Diagnose invalid object release | Backend-private sub-step of object release |
| `@np_intf_addref` | Interface addref | Maps to `np.system.interface_addref` (future) |
| `@np_intf_release` | Interface release | Maps to `np.system.interface_release` (future) |
| `@np_dynarray_resize` | Dynamic array resize | Maps to `np.system.dynarray_set_length` (future) |
| `@np_dynarray_release` | Dynamic array release | Maps to `np.system.dynarray_fini` (future) |
| `@np_dynarray_fault` | Dynamic array fault | Maps to `np.system.runtime_fault` sub-category |
| `@np_allocator_fault` | Allocator fault | Maps to `np.system.runtime_fault` sub-category |
| `@np_str_concat` | String concatenation | Maps to managed string runtime (deferred) |
| `@np_int_to_str` | Integer to string conversion | `nextpas.core.text.conv` owns, not system contract |
| `@np_str_cmp` | String comparison | `nextpas.core.text` owns, not system contract |
| `@np_str_pos` | String position search | `nextpas.core.text` owns, not system contract |
| `@np_memcpy` | Memory copy | Backend-private helper for `np.system.heap_alloc` managed operations; not alias for public `CopyMem` |
| `@np_memzero` | Memory zero | Backend-private helper for allocation zeroing; not alias for public `ZeroMem` |
| `@np_try_push` / `@np_try_pop` | Exception try block | Maps to exception boundary (future) |
| `@np_finally_end` / `@np_except_end` | Exception finally/except end | Maps to exception boundary (future) |
| `@np_raise` | Exception raise | Maps to exception boundary (future) |

## TypInfo Compile-Truth Privilege

`TypeInfo(T)` and `GetTypeKind(K)` are compiler/System compile-truth imports available
through `nextpas.core.system.typinfo`. Consumers using these are **metadata-sensitive consumers**:

- They depend on the host RTTI shape matching the consumer's type expectations.
- When nextPas's own RTTI shape diverges from FPC host truth, these consumers must enter regression testing.
- `TElementManager<string>` in collections is the primary metadata-sensitive consumer.

| Consumer | Uses | Risk |
|----------|------|------|
| `nextpas.core.collections` | `TypeInfo(T)` for comparer/equality dispatch | RTTI shape drift → silent dispatch wrong |
| `nextpas.core.system.typinfo` test suite | `GetTypeKind`, managed array helpers | Test proof under host truth only |
| Compiler HIR dynarray operations | `InitializeArray` / `FinalizeArray` / `CopyArray` | Compiler-managed type metadata must align with runtime helpers |

## S5.4 Remaining Open Risks

The following risks remain open at the S5.4 boundary. They must be addressed before
a landing candidate can be declared fully ready.

### Risk 1: TypInfo RTTI Shape Drift

**Description**: `TypeInfo(T)` and `GetTypeKind(K)` are compile-truth imports that
reflect the host FPC RTTI layout. When nextPas's own RTTI shape diverges from the
FPC host truth, metadata-sensitive consumers (primarily `nextpas.core.collections`)
may silently dispatch incorrectly without any visible failure.

**Current mitigations**:
- `nextpas.core.system.typinfo` is explicitly scoped to identity/kind/managed-array helpers only.
- Property reflection and metadata layout remain out of scope.
- The TypInfo seven-symbol unlock was preceded by a `Needs Review` packet with consumer pressure evidence.

**What remains**:
- No automated regression test that detects RTTI shape divergence between FPC host and nextPas target.
- When nextPas self-hosts and emits its own RTTI, all TypInfo consumers must enter a dedicated
  regression cycle.

**Severity**: High — silent behavioral bugs in collections comparer/equality dispatch.

### Risk 2: Managed Array Leak-Sensitive Gap

**Description**: `@np_dynarray_release` only operates on ptr/len/elem_size. Managed element cleanup
(array of string, array of interface) depends on compiler contract node projection. If the compiler
fails to project a managed element cleanup contract, the runtime will leak or double-free without
any diagnostic.

**Current mitigations**:
- `test_hir_field_dynarray_contract` and `test_hir_dynarray_release_contract` verify HIR contract
  projection for managed element types.
- `test_hir_field_dynarray_release_runtime_smoke` verifies runtime behavior for managed string arrays.
- Source-contract checks verify dynarray contract name stability.

**What remains**:
- No heaptrc (or equivalent leak-sensitive) evidence for all managed element type paths.
- Managed interface array release (`array of IInterface`) runtime smoke exists in TypInfo tests
  but lacks dedicated heaptrc 0-leak evidence.
- Partial initialization cleanup paths (resize failure, early exit) are not tested.

**Severity**: Medium — leak-sensitive paths exist for some element types but not all.

### Risk 3: Process/Unit Lifecycle Execution Gap

**Description**: Process lifecycle has semantic seed proof (`test-process-runtime-contract-seed`)
but no runtime execution proof. Unit lifecycle (`np.system.unit_init`, `np.system.unit_fini`)
has no semantic seed and no execution at all. This means the compiler can emit contract names
but cannot yet drive runtime initialization/finalization ordering.

**Current mitigations**:
- `np.system.process_init` / `np.system.process_fini` are seeded as HIR nodes for program/library/package roots.
- Integration smoke via `build/verify_local.sh` proves compiler → LLVM → executable for basic program lifecycle.
- Unit lifecycle is explicitly deferred until the compiler has a UnitGraph consumption path.

**What remains**:
- No runtime execution of `np.system.process_init` / `np.system.process_fini` beyond the inline
  syscall path (halt-based programs).
- No unit initialization/finalization ordering at all.
- No runtime fault classification (`np.system.runtime_fault`) beyond partial allocator/dynarray evidence.

**Severity**: Low for current scope (deferred to future compiler/runtime integration) — but high
for self-hosting target.

### Risk 4: Exception Boundary Naming Consistency

**Description**: Exception helpers (`@np_try_push`, `@np_try_pop`, `@np_raise`, etc.) are
backend-private LLVM helpers with no `np.system.*` contract name mapping. They exist in the
emitter but are not covered by source-contract checks or documentation in `runtime-contracts.md`.

**Current mitigations**:
- `lifecycle-contracts.md` documents the exception boundary as a future compiler/runtime contract area.
- The helpers are backend-private evidence, not public ABI.

**What remains**:
- No source-contract check verifying exception helper existence or naming stability.
- No focused test for exception lowering beyond `test_hir_exception.pas` (which tests HIR shape, not
  runtime behavior).

**Severity**: Low — exception helpers are backend-private and not in the `np.system.*` facade scope.
