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
| `np.system.interface_addref` | **No HIR intrinsic** — emitter uses `@np_intf_addref` directly | `@np_intf_addref` (line 750) | No focused test | **Missing contract name in HIR; no focused test** |
| `np.system.interface_release` | **No HIR intrinsic** — emitter uses `@np_intf_release` directly | `@np_intf_release` (line 756) | No focused test | **Missing contract name in HIR; no focused test** |
| `np.system.halt` | **No HIR intrinsic** — backend uses syscall directly | No named helper; inline syscall or `@np_exit` pattern | No focused test | **Missing contract name in HIR; no focused test** |
| `np.system.heap_alloc` | **No HIR intrinsic** — emitter uses `@np_alloc` directly | `@np_alloc` (line 686, 698, 1153, 1275) | allocator-focused tests in LLVM emitter | **Missing contract name mapping** |
| `np.system.heap_free` | **No HIR intrinsic** — emitter uses `@np_free` directly | `@np_free` (line 1439) | allocator-focused tests in LLVM emitter | **Missing contract name mapping** |
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
