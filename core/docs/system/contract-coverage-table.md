# System Contract Coverage Table

The typed ledger is authoritative for contract identity and traceability. This table is its
human-readable projection; source-contract tests reject missing, extra, or reordered names.

**Purpose**: Show the current evidence boundary without turning vocabulary or backend helper names
into readiness claims or public ABI.

## Contract Ledger Projection

<!-- ledger-table:start -->
| Contract | Evidence level | Source / semantic evidence | Runtime mapping | Focused evidence | Current boundary |
| --- | --- | --- | --- | --- | --- |
| `np.system.process_init` | HIR | `System.np_process_init`; process-start contract | `np_process_init` | `test_process_lifecycle` (+ `test_process_lifecycle_llvm`) | Runtime execution deferred; HIR/LLVM call evidence only (see footnote) |
| `np.system.process_fini` | HIR | `System.np_process_fini`; process-fini contract | `np_process_fini` | `test_process_lifecycle` (+ `test_process_lifecycle_llvm`) | Runtime execution deferred; HIR/LLVM call evidence only (see footnote) |
| `np.system.unit_init` | semantic | System unit initialization | unit-specific init entry | `test_semantic_runtime_contract_seed` (+ `test_unit_lifecycle_llvm_ordering`, `verify_compiler_unit_init_chain`) | Focused host-free multi-unit init side-effect (Halt 33); ledger stays semantic |
| `np.system.unit_fini` | semantic | System unit finalization | unit-specific fini entry | `test_semantic_runtime_contract_seed` (+ `test_unit_lifecycle_llvm_ordering`, `verify_compiler_unit_fini_body`) | Focused host-free fini body/order evidence; ledger stays semantic |
| `np.system.halt` | HIR | typed `sckHalt` + `halt-call` / `halt-call-runtime` | backend halt lowering (syscall) | `test_hir_halt_contract` | Typed HIR identity + syscall lowering; not full process e2e |
| `np.system.string_init` | HIR | `System.AnsiString`; typed `sckStringInit` | `np_tstring_init` | `test_hir_string_ownership_contract` | Typed HIR/LLVM call-shape only; not full string lifecycle executable proof |
| `np.system.string_fini` | HIR | string cleanup nodes; typed `sckStringFini` | `np_tstring_fini` | `test_hir_string_ownership_contract` | Typed HIR/LLVM call-shape only; not full string lifecycle executable proof |
| `np.system.string_assign` | HIR | string assignment nodes; typed `sckStringAssign` | `np_tstring_assign` | `test_hir_string_ownership_contract` | Typed HIR/LLVM call-shape only; not full string lifecycle executable proof |
| `np.system.dynarray_init` | vocabulary | System dynamic array | deferred | `runtime-contracts.md` | No implementation claim; slot nil via stores only |
| `np.system.dynarray_fini` | executable | typed `sckDynArrayFini` + cleanup nodes | `np_dynarray_release` | `test_hir_dynarray_typed_contract` (+ release_runtime_smoke) | Typed HIR authority; managed-element coverage remains partial |
| `np.system.dynarray_set_length` | executable | typed `sckDynArraySetLength` + setlength nodes | `np_dynarray_resize` | `test_hir_dynarray_typed_contract` (+ release_runtime_smoke) | Typed HIR authority; failure cleanup remains partial |
| `np.system.interface_addref` | HIR | typed `sckInterfaceAddRef` + intf-addref-runtime | `np_intf_addref` | `test_hir_interface_contract` | Typed HIR/LLVM call-shape only; not full refcount executable proof |
| `np.system.interface_release` | HIR | typed `sckInterfaceRelease` + intf-release-runtime | `np_intf_release` | `test_hir_interface_contract` | Typed HIR/LLVM call-shape only; not full refcount executable proof |
| `np.system.managed_record_init` | vocabulary | System managed record | deferred | `runtime-contracts.md` | No implementation claim |
| `np.system.managed_record_fini` | HIR | managed-record cleanup contract | deferred | `test_hir_node_kind` | No executable lifecycle proof |
| `np.system.heap_alloc` | backend | `arr_alloc` and `class_alloc` | `np_alloc`, `np_object_alloc` | `test_hir_class_alloc_contract` | Allocator owner remains outside System |
| `np.system.heap_free` | executable | object and array release nodes | `np_free` | `test_hir_large_alloc_runtime_smoke` | Allocation paths are partial evidence |
| `np.system.object_free` | backend | object-free runtime contract | `np_object_free_release` | `test_hir_object_free_contract` | No full ownership proof |
| `np.system.object_free.destroy` | HIR | object-free destroy marker | virtual `Destroy` dispatch | `test_hir_object_free_contract` | Direct dispatch not end-to-end proven |
| `np.system.object_free.cleanup` | HIR | object-free cleanup marker | compiler-planned cleanup | `test_hir_object_free_contract` | End-to-end cleanup effects unproven |
| `np.system.object_free.release` | backend | object-free release marker | `np_object_free_release` | `test_hir_object_free_contract` | End-to-end release effects unproven |
| `np.system.runtime_fault` | backend | fault-specific nodes | allocator and dynarray fault helpers | `runtime-contracts.md` | No focused lifecycle-fault proof |
| `np.system.exception_try_push` | backend | try-begin runtime contract | `np_try_push` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_try_pop` | backend | try-end runtime contract | `np_try_pop` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_raise` | backend | raise runtime contract | `np_raise` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_finally_end` | backend | finally-end runtime contract | `np_finally_end` | `test_hir_exception` | No executable unwind proof |
| `np.system.exception_except_end` | backend | except-end runtime contract | `np_except_end` | `test_hir_exception` | No executable unwind proof |
<!-- ledger-table:end -->

> **Footnote (D3 closed → M1 typed process family, 2026-07-23)**: HIR builder assigns
> `sckProcessInit` / `sckProcessFini` via `AssignSystemContract`; LLVM dispatches those
> kinds before legacy call-target string matching. Evidence remains **call-shape only**
> (typed identity + void IR); **not** full process business init; ledger stays **scelHir**.
> Residual honesty footnotes are closed; further work is whole-family typed migration.
>
> **Footnote (M1 typed string ownership triad, 2026-07-23)**: `sckStringInit` /
> `sckStringFini` / `sckStringAssign` are production typed HIR (authority =
> `SystemContractKind`); runtime maps to `np_tstring_*`. Evidence is HIR identity +
> LLVM call-shape via `test_hir_string_ownership_contract`; **not** full COW/refcount
> executable lifecycle. Ledger **scelHir** for the triad (init promoted from vocabulary).
>
> **Footnote (M1 typed dynarray set_length/fini, 2026-07-23)**: `sckDynArraySetLength`
> / `sckDynArrayFini` are production typed HIR (authority = `SystemContractKind`);
> runtime maps to `np_dynarray_resize` / `np_dynarray_release`. Focused typed identity:
> `test_hir_dynarray_typed_contract`. Existing release/field runtime smokes remain
> executable evidence. `dynarray_init` stays vocabulary (slot nil via stores).
> Managed-element finalization coverage remains partial.
>
> **Footnote (M1 typed interface addref/release, 2026-07-23)**: `sckInterfaceAddRef`
> / `sckInterfaceRelease` are production typed HIR (authority = `SystemContractKind`);
> runtime maps to `np_intf_addref` / `np_intf_release`. Focused typed identity:
> `test_hir_interface_contract`. Evidence is HIR identity + LLVM call-shape only;
> **not** full COM/elision/destruction policy. Ledger **scelHir**.
>
> **Footnote (M1 typed halt, 2026-07-23)**: `sckHalt` is production typed HIR
> (authority = `SystemContractKind`); LLVM lowers to backend-private syscall
> inline asm (no named `@np_halt` helper). Focused typed identity:
> `test_hir_halt_contract`. Evidence is HIR identity + syscall lowering shape;
> **not** full process business e2e. Ledger **scelHir** (promoted from backend).
>
> **Footnote (D3, 2026-07-23; residual honesty same day — historical)**: `process_init` / `process_fini`
> focused HIR/LLVM call evidence (`test_process_lifecycle`, `test_process_lifecycle_llvm`) proves
> `_start` call/declare **void** shape only when typed lifecycle nodes are present (and no calls
> without them). It does **not** prove full runtime business init, host-free process business e2e,
> or justify elevating the typed ledger past `scelHir`. Coverage boundary remains
> **Runtime execution deferred**. Process residual is **closed as this evidence boundary**, not as
> production readiness.
>
> **Footnote (D3 unit ordering, 2026-07-23)**: `test_unit_lifecycle_llvm_ordering` proves LLVM IR
> multi-unit call order only (`process_init` → topo `np_unit_init_*` → reverse `np_unit_fini_*` →
> `process_fini`) when `UnitInitOrder` is set. It does **not** alone justify elevating unit contracts
> past `scelSemantic`.
>
> **Footnote (D3 host-free multi-unit + binding policy, 2026-07-23)**: host-free executable evidence
> **requires** explicit `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` (or gate env
> equivalent). Transcript must show `backend-family=llvm`, `primary-tool-profile-id=llvm-stable`,
> and must **not** be `fpc-stage0-host`. Default stage0 `nextpas build` without that binding remains
> host FPC and **must not** be cited as host-free. Focused gates:
> `make test-compiler-unit-init-chain` (Halt 33), `make test-compiler-unit-fini-body`,
> `make test-compiler-unit-lifecycle-llvm` (count=42; store i64→i32 trunc). Gate scripts refuse silent
> host FPC masquerade. Slice-level unit init/fini proof only — **not** full business process init;
> **does not** raise unit ledger past `scelSemantic`. **Global default binding is intentionally
> unchanged.**


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
| `@np_intf_addref` | Interface addref | Maps to `np.system.interface_addref` |
| `@np_intf_release` | Interface release | Maps to `np.system.interface_release` |
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

**Description**: Process lifecycle has HIR/LLVM call-shape evidence
(`test_process_lifecycle`, `test_process_lifecycle_llvm`) but no full runtime business-init
proof and no `scelExecutable` ledger elevation. Unit lifecycle (`np.system.unit_init`,
`np.system.unit_fini`) has semantic contract evidence, LLVM multi-unit **call-order**
proof (`test_unit_lifecycle_llvm_ordering`), plus a **focused host-free multi-unit
executable slice** (`verify_compiler_unit_init_chain` / `verify_compiler_unit_fini_body`).
Ledger remains `scelSemantic` — slice ≠ full self-host readiness.

**Current mitigations**:
- `np.system.process_init` / `np.system.process_fini` are seeded as HIR nodes for
  program/library/package roots and lower to `_start` calls.
- Focused HIR proof: `compiler/tests/test_process_lifecycle.pas` — `_start` contains
  `np_process_init` / `np_process_fini` call targets when lifecycle typed nodes are present.
- Focused LLVM proof: `compiler/tests/test_process_lifecycle_llvm.pas` — IR contains
  `declare void @np_process_init/fini` and `call void @np_process_init/fini` (void form,
  single fini; re-verified 2026-07-23 after builder ResultId=0 + emitter fini-dedupe fix).
- Phase 0 runtime helper exists (`rtl/runtime/src/nextpas.runtime.lifecycle.ll`: state flag +
  fsync only). This is **not** full process business init (no unit table / heap / ExitProc).
- Unit multi-unit LLVM call-order: `compiler/tests/test_unit_lifecycle_llvm_ordering.pas`
  (topo init / reverse fini around process lifecycle calls when `UnitInitOrder` is set).
- Host-free multi-unit init side-effect: `make test-compiler-unit-init-chain`
  (`llvm_unit_init_chain` Halt 33; asserts `backend-family=llvm` + `primary-tool-profile-id=llvm-stable`).
- Host-free multi-unit fini body: `make test-compiler-unit-fini-body`.
- Host-free `unit_lifecycle_pass` (init side-effect + store trunc): `make test-compiler-unit-lifecycle-llvm`
  (anti-masquerade; IR `trunc i64 … to i32` before `store i32 … @g_Count`; exit 0 / count=42).

**What remains**:
- Process residual is **closed as scelHir call-shape** only; full process business init and
  host-free process business e2e remain **deferred** (not a silent red production knife).
- Default stage0 `unit_lifecycle_pass` (no llvm binding) still lands on **host FPC** (`fpc-stage0-host`);
  that green is **not** host-free evidence. Host-free claims **must** use
  `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` (+ anti-masquerade). **Default binding
  intentionally unchanged.**
- Process ledger stays `scelHir` / unit ledger stays `scelSemantic` — focused host-free unit slice
  ≠ ledger raise / self-host complete.

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
