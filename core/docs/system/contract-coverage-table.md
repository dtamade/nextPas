# System Contract Coverage Table

The typed ledger is authoritative for contract identity and traceability. This table is its
human-readable projection; source-contract tests reject missing, extra, or reordered names.

**Purpose**: Show the current evidence boundary without turning vocabulary or backend helper names
into readiness claims or public ABI.

## Contract Ledger Projection

<!-- ledger-table:start -->
| Contract | Evidence level | Source / semantic evidence | Runtime mapping | Focused evidence | Current boundary |
| --- | --- | --- | --- | --- | --- |
| `np.system.process_init` | HIR | `System.np_process_init`; process-start contract | `np_process_init` | `test_process_lifecycle` | Runtime execution deferred |
| `np.system.process_fini` | HIR | `System.np_process_fini`; process-fini contract | `np_process_fini` | `test_process_lifecycle` | Runtime execution deferred |
| `np.system.unit_init` | semantic | System unit initialization | unit-specific init entry | `test_semantic_runtime_contract_seed` | No executable ordering proof |
| `np.system.unit_fini` | semantic | System unit finalization | unit-specific fini entry | `test_semantic_runtime_contract_seed` | No executable ordering proof |
| `np.system.halt` | backend | `halt-call-runtime` | backend halt lowering | `test_hir_node_kind` | Backend-specific lowering |
| `np.system.string_init` | vocabulary | `System.AnsiString` | deferred | `runtime-contracts.md` | No implementation claim |
| `np.system.string_fini` | HIR | string cleanup nodes | string release helpers | `test_hir_string_ownership_contract` | No executable lifecycle proof |
| `np.system.string_assign` | HIR | string assignment nodes | string assignment helpers | `test_hir_string_ownership_contract` | No executable lifecycle proof |
| `np.system.dynarray_init` | vocabulary | System dynamic array | deferred | `runtime-contracts.md` | No implementation claim |
| `np.system.dynarray_fini` | executable | dynarray cleanup contract | `np_dynarray_release` | `test_hir_dynarray_release_runtime_smoke` | Managed-element coverage remains partial |
| `np.system.dynarray_set_length` | executable | set-length array contract | `np_dynarray_resize` | `test_hir_dynarray_release_runtime_smoke` | Failure cleanup remains partial |
| `np.system.interface_addref` | backend | `intf_addref` implementation intrinsic | `np_intf_addref` | `test_hir_interface_contract` | Backend helper, not facade ABI |
| `np.system.interface_release` | backend | `intf_release` implementation intrinsic | `np_intf_release` | `test_hir_interface_contract` | Backend helper, not facade ABI |
| `np.system.managed_record_init` | vocabulary | System managed record | deferred | `runtime-contracts.md` | No implementation claim |
| `np.system.managed_record_fini` | HIR | managed-record cleanup contract | deferred | `test_hir_node_kind` | No executable lifecycle proof |
| `np.system.heap_alloc` | backend | `arr_alloc` and `class_alloc` | `np_alloc`, `np_object_alloc` | `test_hir_class_alloc_contract` | Allocator owner remains outside System |
| `np.system.heap_free` | executable | object and array release nodes | `np_free` | `test_hir_large_alloc_runtime_smoke` | Allocation paths are partial evidence |
| `np.system.object_free` | backend | object-free runtime contract | `np_object_free_release` | `test_hir_object_free_contract` | No full ownership proof |
| `np.system.object_free.destroy` | HIR | object-free destroy marker | virtual `Destroy` dispatch | `test_hir_object_free_contract` | Direct dispatch not end-to-end proven |
| `np.system.object_free.cleanup` | HIR | object-free cleanup marker | compiler-planned cleanup | `test_hir_object_free_contract` | Managed-field cleanup unproven |
| `np.system.object_free.release` | backend | object-free release marker | `np_object_free_release` | `test_hir_object_free_contract` | Cleanup ordering unproven |
| `np.system.runtime_fault` | backend | fault-specific nodes | allocator and dynarray fault helpers | `runtime-contracts.md` | No focused lifecycle-fault proof |
| `np.system.exception_try_push` | backend | try-begin runtime contract | `np_try_push` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_try_pop` | backend | try-end runtime contract | `np_try_pop` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_raise` | backend | raise runtime contract | `np_raise` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_finally_end` | backend | finally-end runtime contract | `np_finally_end` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_except_end` | backend | except-end runtime contract | `np_except_end` | `test_hir_exception` | No executable unwind proof |
<!-- ledger-table:end -->

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

## Remaining Open Risks

The following risks remain open. They must be addressed before the compiler-system bootstrap
spine can claim executable self-host readiness.

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
has semantic contract evidence but no executable ordering proof. This means the compiler can
name lifecycle contracts but cannot yet prove runtime initialization/finalization ordering.

**Current mitigations**:
- `np.system.process_init` / `np.system.process_fini` are seeded as HIR nodes for program/library/package roots.
- Integration smoke via `build/verify_local.sh` is partial compiler-to-executable evidence; it does not
  prove the A -> B -> C bootstrap chain or lifecycle ordering.
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
backend-private LLVM helpers. The typed ledger now maps their `np.system.*` semantic names and
the source contract verifies that vocabulary, but the mapping is not executable unwind proof.

**Current mitigations**:
- `lifecycle-contracts.md` documents the exception boundary and the typed ledger records its mapping.
- The helpers are backend-private evidence, not public ABI.

**What remains**:
- No focused test for exception lowering beyond `test_hir_exception.pas` (which tests HIR shape, not
  runtime behavior).
- No end-to-end exception unwind, failure-path, or ABI-stability proof.

**Severity**: Low — exception helpers are backend-private and not in the `np.system.*` facade scope.
