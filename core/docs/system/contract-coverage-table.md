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
| `np.system.dynarray_init` | HIR | typed `sckDynArrayInit` + var-decl-arr-runtime | inline store nil/len (bytes.ops single source, ZeroMem/SpanFill) | `test_hir_dynarray_typed_contract` | Typed HIR authority; inline nil/len stores (inline/zero-copy, no leak) |
| `np.system.dynarray_fini` | executable | typed `sckDynArrayFini` + cleanup nodes | `np_dynarray_release` | `test_hir_dynarray_typed_contract` (+ release_runtime_smoke) | Typed HIR authority; managed-element coverage remains partial |
| `np.system.dynarray_set_length` | executable | typed `sckDynArraySetLength` + setlength nodes | `np_dynarray_resize` | `test_hir_dynarray_typed_contract` (+ release_runtime_smoke) | Typed HIR authority; failure cleanup remains partial |
| `np.system.interface_addref` | HIR | typed `sckInterfaceAddRef` + intf-addref-runtime | `np_intf_addref` | `test_hir_interface_contract` | Typed HIR/LLVM call-shape only; not full refcount executable proof |
| `np.system.interface_release` | HIR | typed `sckInterfaceRelease` + intf-release-runtime | `np_intf_release` | `test_hir_interface_contract` | Typed HIR/LLVM call-shape only; not full refcount executable proof |
| `np.system.managed_record_init` | HIR | typed `sckManagedRecordInit` + managed-record-init-runtime | compiler-planned field zeroing (inline stores, bytes.ops single source) | `test_hir_managed_record_contract` | Marker + nested string/dynarray init stores; inline/zero-copy, no leak |
| `np.system.managed_record_fini` | HIR | typed `sckManagedRecordFini` + `managed-record-cleanup-runtime` | compiler-planned field cleanup | `test_hir_managed_record_contract` | Marker + nested string/dynarray; init is typed HIR (field zeroing); not full lifecycle e2e |
| `np.system.heap_alloc` | HIR | typed `sckHeapAlloc` + `getmem-runtime` / field arr path | `np_alloc` | `test_hir_heap_contract` | GetMem + field setlength byte-size path typed; legacy `arr_alloc*` emit remains for dead bare sites |
| `np.system.heap_free` | HIR | typed `sckHeapFree` + `freemem-runtime` | `np_free` | `test_hir_heap_contract` | FreeMem path typed; large-alloc smoke remains secondary executable evidence |
| `np.system.object_alloc` | HIR | typed `sckObjectAlloc` + `class-new-runtime` | `np_object_alloc` | `test_hir_object_alloc_contract` | Typed HIR + call-shape; not full ctor/vmt e2e |
| `np.system.object_free` | backend | object-free runtime contract | `np_object_free_release` | `test_hir_object_free_contract` | Backend call-shape only; no end-to-end ownership executable proof; intentionally deferred (evidence 32) |
| `np.system.object_free.destroy` | HIR | object-free destroy marker | virtual `Destroy` dispatch | `test_hir_object_free_contract` | HIR marker only; direct dispatch not end-to-end proven; intentionally deferred (33) |
| `np.system.object_free.cleanup` | HIR | object-free cleanup marker | compiler-planned cleanup | `test_hir_object_free_contract` | HIR marker only; end-to-end cleanup effects unproven; future executable proof must reuse `bytes.ops` single-source, `inline`/zero-copy, guaranteed release (34) |
| `np.system.object_free.release` | backend | object-free release marker | `np_object_free_release` | `test_hir_object_free_contract` | Backend call-shape only; release effects unproven; intentionally deferred (35) |
| `np.system.runtime_fault` | backend | fault-specific nodes | allocator and dynarray fault helpers | `runtime-contracts.md` (source-contract token only) | No focused lifecycle-fault executable proof; backend helper existence only; intentionally deferred (36) |
| `np.system.exception_try_push` | HIR | typed `sckExceptionTryPush` + `try-begin-runtime` | `np_try_push` | `test_hir_exception_contract` | Typed HIR + setjmp frame shape; not executable unwind proof |
| `np.system.exception_try_pop` | HIR | typed `sckExceptionTryPop` + `try-end-runtime` | `np_try_pop` | `test_hir_exception_contract` | Typed HIR + call-shape; not executable unwind proof |
| `np.system.exception_raise` | HIR | typed `sckExceptionRaise` + `raise-runtime` | `np_raise` | `test_hir_exception_contract` | Typed HIR + unreachable; not exception object model |
| `np.system.exception_finally_end` | HIR | typed `sckExceptionFinallyEnd` + `finally-end-runtime` | `np_finally_end` | `test_hir_exception_contract` | Typed HIR + call-shape; not executable unwind proof |
| `np.system.exception_except_end` | HIR | typed `sckExceptionExceptEnd` + `except-end-runtime` | `np_except_end` | `test_hir_exception_contract` | Typed HIR + call-shape; not executable unwind proof |
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
> **Footnote (M1 typed dynarray init/set_length/fini, 2026-07-23)**: `sckDynArrayInit` / `sckDynArraySetLength`
> / `sckDynArrayFini` are production typed HIR (authority = `SystemContractKind`);
> `sckDynArrayInit` lowers to inline nil/len stores (bytes.ops single source, ZeroMem/SpanFill, inline/zero-copy, no leak);
> `sckDynArraySetLength` / `sckDynArrayFini` map to `np_dynarray_resize` / `np_dynarray_release`. Focused typed identity:
> `test_hir_dynarray_typed_contract`. Existing release/field runtime smokes remain
> executable evidence. Dynamic array family closed as HIR (init via stores, no standalone helper).
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
> **Footnote (M1 typed heap_alloc/free, 2026-07-23)**: `sckHeapAlloc` /
> `sckHeapFree` are production typed HIR (authority = `SystemContractKind`);
> runtime maps to `@np_alloc` / `@np_free`. GetMem/FreeMem plus field setlength
> element-count×8 path use `sckHeapAlloc`. Focused typed identity:
> `test_hir_heap_contract`. Legacy bare `arr_alloc` / `arr_alloc_sized` emit
> remains only for non-production residual. Allocator owner remains
> `nextpas.core.mem`. Evidence is HIR identity + LLVM call-shape; **not** full
> leak/OOM executable proof. Ledger **scelHir**.
>
> **Footnote (M1 typed object_alloc, 2026-07-23)**: `sckObjectAlloc` is
> production typed HIR for class instance allocation (`class-new-runtime`;
> authority = `SystemContractKind`); runtime maps to `@np_object_alloc`.
> Focused typed identity: `test_hir_object_alloc_contract`. Evidence is HIR
> identity + LLVM call-shape; **not** full constructor/vmt e2e. Ledger **scelHir**.
>
> **Footnote (M1 typed managed_record init/fini, 2026-07-23)**: `sckManagedRecordInit` / `sckManagedRecordFini`
> are production typed HIR authority for managed-record scope lifecycle
> (`managed-record-init-runtime` / `managed-record-cleanup-runtime`; authority = `SystemContractKind`).
> `sckManagedRecordInit` lowers to compiler-planned field zeroing (inline stores, bytes.ops single source, inline/zero-copy);
> `sckManagedRecordFini` lowers to compiler-planned field cleanup: nested typed contracts
> (`sckStringFini` / `sckDynArrayFini`) perform release; LLVM emits marker comments only (no standalone helper). Focused typed identity:
> `test_hir_managed_record_contract` (init + fini). Evidence is HIR identity + nested store/call
> shape; **not** full nested/managed-record executable lifecycle. Ledger **scelHir**.
>
> **Footnote (M1 typed production families closed, 2026-07-23)**: Production
> builder sites no longer assign bare `class_alloc` / `arr_alloc` IntrinsicName;
> remaining production lifecycle families are typed under `SystemContractKind`.
> `dynarray_init` and `managed_record_init` are now **HIR** (inline stores, bytes.ops single source, no standalone helper);
> `unit_init` / `unit_fini` stay **semantic** (host-free multi-unit evidence already recorded); `object_free`
> root/release and `runtime_fault` stay at their current **backend** evidence
> boundary (evidence 32-36, gate marks not proven; no end-to-end ownership/fault-path executable proof);
> elevating the whole ledger to `scelExecutable` / runtime-closure is
> **post-M1**. See `docs/plans/goal-tree.md` execution window item 7 closed.
>
> **Footnote (M1 object_free family + runtime_fault intentionally deferred — evidence 32-36, 2026-07-23)**: `np.system.object_free` root/release remain **backend** (`@np_object_free_release` nil-guard + release; evidence 32/35), `object_free.destroy`/`cleanup` remain **HIR markers** (`virtual Destroy` + compiler-planned field cleanup via nested `sckStringFini`/`sckDynArrayFini`; evidence 33/34). `np.system.runtime_fault` remains **backend** fault helpers (`@np_dynarray_fault`/`@np_allocator_fault`; evidence 36). Focused gate `test_hir_object_free_contract` (+ source-contract `@np_object_free_release` existence) proves only HIR identity + backend call-shape, **not** end-to-end ownership transfer or fault-path execution. No executable ownership/fault proof exists; promotion to `scelExecutable` is intentionally deferred for M1 exit. Future executable proof must reuse `nextpas.core.bytes.ops` single-source, keep `inline`/zero-copy `TByteSpan` discipline, preserve L0-L3 / four-piece structure, and guarantee resource release not lost (implicit `try`/`finally` / defer-style cleanup), without creating a new owner or copying FPC `System` grab-bag.
>
> **Footnote (M1 typed exception boundary, 2026-07-23)**: `sckExceptionTryPush` /
> `sckExceptionTryPop` / `sckExceptionRaise` / `sckExceptionFinallyEnd` /
> `sckExceptionExceptEnd` are production typed HIR (authority =
> `SystemContractKind`); LLVM maps to `@np_try_push` / `@np_try_pop` /
> `@np_raise` / `@np_finally_end` / `@np_except_end` (setjmp frame shape).
> Marker-only `hikFinallyBegin` / `hikExceptBegin` remain non-contract.
> Focused typed identity: `test_hir_exception_contract` (+ legacy shape
> `test_hir_exception`). Evidence is HIR identity + call-shape; **not** full
> unwind object model or table-based exception ABI. Ledger **scelHir**.
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
| `@np_alloc` | Heap allocation | Maps to typed `np.system.heap_alloc` (`sckHeapAlloc` / GetMem) |
| `@np_free` | Heap release | Maps to typed `np.system.heap_free` (`sckHeapFree` / FreeMem) |
| `@np_object_alloc` | Object instance allocation | Maps to typed `np.system.object_alloc` (`sckObjectAlloc` / class-new) |
| `@np_object_free_release` | Object nil-guard + release | Maps to `np.system.object_free.release` (backend evidence only; no e2e ownership proof; evidence 35; intentionally deferred) |
| `@np_object_release_valid` | Release valid object allocation | Backend-private sub-step of object release (evidence 35) |
| `@np_object_release_invalid` | Diagnose invalid object release | Backend-private sub-step of object release (evidence 35) |
| `@np_intf_addref` | Interface addref | Maps to `np.system.interface_addref` |
| `@np_intf_release` | Interface release | Maps to `np.system.interface_release` |
| `@np_dynarray_resize` | Dynamic array resize | Maps to typed `np.system.dynarray_set_length` (`sckDynArraySetLength`) |
| `@np_dynarray_release` | Dynamic array release | Maps to typed `np.system.dynarray_fini` (`sckDynArrayFini`) |
| `@np_dynarray_fault` | Dynamic array fault | Maps to `np.system.runtime_fault` sub-category (backend helper existence only; no fault-path executable proof; evidence 36; intentionally deferred) |
| `@np_allocator_fault` | Allocator fault | Maps to `np.system.runtime_fault` sub-category (backend helper existence only; no fault-path executable proof; evidence 36; intentionally deferred) |
| `@np_str_concat` | String concatenation | Maps to managed string runtime (deferred) |
| `@np_int_to_str` | Integer to string conversion | `nextpas.core.text.conv` owns, not system contract |
| `@np_str_cmp` | String comparison | `nextpas.core.text` owns, not system contract |
| `@np_str_pos` | String position search | `nextpas.core.text` owns, not system contract |
| `@np_memcpy` | Memory copy | Backend-private helper for `np.system.heap_alloc` managed operations; not alias for public `CopyMem` |
| `@np_memzero` | Memory zero | Backend-private helper for allocation zeroing; not alias for public `ZeroMem` |
| `@np_try_push` / `@np_try_pop` | Exception try block | Maps to typed `np.system.exception_try_push` / `exception_try_pop` |
| `@np_finally_end` / `@np_except_end` | Exception finally/except end | Maps to typed `np.system.exception_finally_end` / `exception_except_end` |
| `@np_raise` | Exception raise | Maps to typed `np.system.exception_raise` |

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
- Host-truth drift is now gated: `check_system_source_contracts.sh:check_ttypekind_consistency` validates `src/nextpas.core.system.rtti.inc` `TTypeKind` (sorted `tk*` set vs canonical FPC `rttih.inc`) and `test_system_typinfo_collections_consumer` validates metadata-sensitive `TElementManager<string>` (`IsManagedType`/`TypeInfo(string)` → `tkAString`, `ElementSize`, `InitializeArray`/`CopyArray`/`FinalizeArray`) with `try..finally`/`Free` release (no leak). Any byte-level name/span comparison in this gate reuses `nextpas.core.bytes.ops` single source (`SpanEqual`/`SpanCompare`) with `inline`/zero-copy `TByteSpan` views — no duplicate memcompare, no resource loss.

**What remains**:
- Self-host target emission (nextPas emitting its own RTTI) remains deferred; when enabled, all TypInfo consumers must re-enter dedicated regression (host vs target truth comparison). Host truth beyond 192-210 is now automated; target truth still requires future gate before self-host claim.
- Four-piece set and L0-L3 preserved: `nextpas.core.system.typinfo` remains facade re-exporting `TypInfo` (base `TTypeKind`/`PTypeInfo` owned by `nextpas.core.base`/`system.rtti.inc`, helpers delegated to `System`), consumers depend downward only, no same-layer cycles.

**Severity**: High if gate skipped — silent comparer/equality dispatch wrong; **Gated** at host truth (drift fails source-contract).

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

### Risk 5: Object-Free Ownership / Runtime-Fault Path Not Executable (evidence 32-36)

**Description**: `np.system.object_free` family (`object_free` root/release `backend` + `destroy`/`cleanup` `HIR` markers) and `np.system.runtime_fault` (`backend` fault helpers) remain at **backend/HIR call-shape** evidence. `test_hir_object_free_contract` proves only HIR identity + `@np_object_free_release` existence/shape; `runtime-contracts.md` token check proves only fault helper name existence. No end-to-end **ownership transfer** (nil-guard → effective `Destroy` → compiler-planned field cleanup → `@np_object_free_release`) and no **fault-path** (`@np_dynarray_fault` / `@np_allocator_fault`) **executable proof** exists. Gate therefore correctly marks evidence **32-36 not proven**; this is intentional M1 deferral, not a silent gap.

**Current mitigations**:
- Ledger states honest levels: `object_free`/`release` `backend`, `destroy`/`cleanup` `HIR`, `runtime_fault` `backend` — not `scelExecutable`.
- Source-contract gate validates HIR typed kinds (`sckObjectFree`/`sckObjectFreeDestroy`/`sckObjectFreeCleanup`/`sckObjectFreeRelease`) + backend helper existence (`@np_object_free_release`, `@np_dynarray_fault`, `@np_allocator_fault`).
- `runtime-contracts.md` documents object-free ordering (nil-guard true, heap-release true, field-agnostic, must not walk fields) + fault taxonomy; coverage footnote explicitly marks 32-36 as intentionally deferred.
- Backend-private helper table annotates `object_free`/`runtime_fault` helpers as backend-only.

**What remains**:
- No executable ownership lifecycle proof (e.g., create → field init via `bytes.ops` zero-copy spans → `Free` → `Destroy` + field `bytes.ops`/`text.conv` cleanup → heap release) with `try..finally`/`FreeAndNil` guarantee that **resource release is not lost**.
- No fault-path executable proof (resize/alloc failure → fault helper → observable diagnostic / non-ignorable abort) for `runtime_fault`.
- Future executable promotion must **reuse `nextpas.core.bytes.ops` single-source** (`TByteSpan` views, `SpanEqual`/`SpanCopySlice`/`SpanClone` etc.), keep `inline`/zero-copy (no duplicate memcompare/copy), preserve four-piece structure (`base ← intf ← impl ← facade`) and **L0-L3 layering** (bytes L1, not bypassing owners), and guarantee release not lost (implicit `try..finally` / defer-style cleanup), without introducing a new owner or copying FPC `System` grab-bag. `object_free.cleanup` will reuse nested `sckStringFini`/`sckDynArrayFini` (which already delegate to `bytes.ops`/`text.conv`) rather than walking fields inside the release helper.

**Severity**: Low for M1 (intentionally deferred, honestly bounded) — but **High** for self-host/ownership correctness if promoted without executable proof.
