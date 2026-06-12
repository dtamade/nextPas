# core-system Goal Tree

This goal tree is scoped to `nextpas.core.system` as a core framework module family. It does not replace
the repository-level `rtl/core/system/` architecture docs; it gives this lane a staged path with focused
verification.

## S0 Mapping / Spec / Source Contracts

- [x] Create `core/docs/system/README.md` with position, owner boundary and non-goals.
- [x] Create `core/docs/system/rtl-mapping.md` with FPC `System`, `SysUtils`, `TypInfo`, `Classes` and `ObjPas` mapping.
- [x] Create `core/docs/system/goal-tree.md`.
- [x] Add source-contract tests proving docs exist, mapping statuses exist, and system units avoid direct OS owner bypass.

Exit evidence:

- `make -C core/tests/nextpas.core.system clean test`
- `git diff --check`
- `make hygiene`

## S1 Minimal Facade And Base Compatibility

- [x] Add `nextpas.core.system` facade skeleton.
- [x] Re-export only low-risk base and exception aliases needed by early consumers.
- [x] Delegate memory helper wrappers to `nextpas.core.base.utils` without changing guard semantics.
- [x] Prove `nextpas.core.base` and `nextpas.core.system` can be used in the same program.
- [x] Prove exception root remains canonical through `nextpas.core.exception`.

Exit evidence:

- `make -C core/tests/nextpas.core.system clean test`
- Base focused tests if `base` or `base.utils` is touched.
- Exception focused tests if `exception` or `errors` is touched.

## S2 Memory / Managed / Dynarray / String Runtime Contracts

- [x] Document managed string, dynamic array, interface and managed record lifetime contracts.
- [x] Map heap-manager responsibilities onto `nextpas.core.mem` without moving allocator ownership.
- [x] Add source-contract tests for runtime helper names and owner boundaries.
- [x] Record leak-sensitive test requirements before any runtime-owned implementation appears.

## S3 Exception / RTTI / Unit Lifecycle Contracts

- [x] Document exception raise/unwind boundary between compiler, runtime and exception taxonomy owner.
- [x] Document RTTI / TypeInfo minimum truth and what remains compiler-owned.
- [x] Document unit initialization/finalization ordering and failure behavior.
- [x] Add source-contract tests for `np.system.unit_init`, `np.system.unit_fini` and runtime-fault classification.

## S4 SysUtils / TypInfo / Classes Compatibility Facades

- [x] Record that broad SysUtils and Classes remain deferred and are not current phase gates.
- [x] Record that no public unit yet should exist for `system.classes`.
- [x] Record design-only S4 facade boundaries in `compatibility-facades.md`.
- [x] Record live consumer pressure and migration risk in `compatibility-matrix.md`.
- [x] Record TypInfo minimal pressure audit in `typinfo-minimal-pressure.md`.
- [x] Prepare a TypInfo minimal unlock `Needs Review` packet with exact symbol list, owner boundary, file set, and focused gates.
- [x] Add the minimal live `nextpas.core.system.typinfo` unit for the seven-symbol pressure set.
- [x] Add the minimal live `nextpas.core.system.sysutils` exception-formatting unit for `Format` and canonical exception aliases.
- [ ] Decide whether broader SysUtils or Classes deserve `system.*` facade units.
- [ ] Add only tested aliases or forwarding functions for future compatibility slices; no broad historical copy.
- [ ] Keep filesystem, time, IO, math, text and collection implementation ownership in their existing modules.
- [x] Report `Needs Review` before exposing compatibility API with wide consumer impact.

Current phase note:

- S4 is split: TypInfo minimal live unit is unlocked; SysUtils has a minimal
  exception-formatting live unit; Classes remains deferred.
- SysUtils path, file, environment, time, and broad string-helper compatibility
  remain deferred.
- TypInfo minimal unlock was preceded by a dedicated `Needs Review` packet and is limited to
  `PTypeInfo`, `TTypeKind`, `InitializeArray`, `FinalizeArray`, `CopyArray`,
  required `TTypeKind` aliases, plus consumer access to `TypeInfo` and
  `GetTypeKind`.
- TypeInfo and GetTypeKind are compiler/System compile-truth imports, not unit-owned wrapper functions in `nextpas.core.system.typinfo`.
- TypInfo `TTypeKind` aliases cover current collections comparer/equality
  dispatch needs without expanding into reflection metadata.
- S4 is not a current phase gate for this lane.
- no public unit yet should exist for `nextpas.core.system.classes`.
- If real consumer pressure appears, reopen as `Needs Review` with focused evidence instead of creating
  broad placeholders.

## S5 Compiler / Runtime Integration Readiness

### S5.1 Contract Vocabulary Lock

- [x] Align managed dynamic-array compiler contract projection with system runtime contract names.
- [x] Prove managed dynamic-array contract vocabulary is explicit without freezing backend-private helper symbols.
- [x] Align process-level startup/shutdown semantic seed with `np.system.process_init` / `np.system.process_fini`.
- [x] Prove process lifecycle semantic seed exact-name order without upgrading runtime execution or unit lifecycle.
- [x] Align remaining facade docs with compiler runtime contract names and source-backed `System` truth.
- [x] Lock `np.system.object_free` and sub-contracts (`.destroy`, `.cleanup`, `.release`) in HIR intrinsic names.
- Object-free source-backed System truth: `rtl/core/system/System.pas` defines `TObject.Create`, `TObject.Destroy`, and `TObject.Free` as the minimum compiler-visible object root.
- Object-free HIR gates and `test-stage0-system-object-free-query` stage0 query evidence prove Free binding resolution.

### S5.2 Helper-Family Mapping Audit

- [x] Audit and document all HIR intrinsic name → LLVM helper name mappings.
- [x] Document `intf_addref` / `intf_release` as implementation names mapping to `np.system.interface_addref` / `np.system.interface_release` contracts.
- [x] Document `halt` as implementation name mapping to `np.system.halt` contract.
- [x] Document `arr_alloc` / `class_alloc` as implementation names mapping to `np.system.heap_alloc` contract.
- [x] Add source-contract checks: HIR intrinsic name existence and LLVM helper mapping.
- [x] Add focused test for interface contract (`test_hir_interface_contract`).

**Decision**: Keep implementation names in HIR (`intf_addref`, `intf_release`, `halt`, `arr_alloc`, `class_alloc`), document mapping in `runtime-contracts.md` and `contract-coverage-table.md`. This is consistent with existing pattern where `np.system.object_free.destroy/cleanup/release` use semantic names but other helpers use implementation names.

**Evidence**:

- `runtime-contracts.md:34-39` documents HIR uses `halt` as internal intrinsic name.
- `runtime-contracts.md:111-112` documents HIR uses `intf_addref`/`intf_release` as internal intrinsic names.
- `runtime-contracts.md:199-201` documents HIR uses `arr_alloc`/`class_alloc` as allocation intrinsics.
- `check_system_source_contracts.sh:681-689` verifies HIR builder and emitter use implementation names.
- `test_hir_interface_contract` verifies `intf_addref`/`intf_release` HIR intrinsics and LLVM helper emission.

### S5.3 Integration Smoke

**Evidence from existing `build/verify_local.sh`**:

The `build/verify_local.sh` script already provides comprehensive integration smoke for:
- Process lifecycle: `llvm-empty-program` (hello.pas → LLVM → executable → exit 0)
- Halt contract: `llvm-halt-program` (halt_42.pas → LLVM IR syscall → exit 42)
- Object-free lifecycle: `llvm_class_basic.pas` (class Create/Free → LLVM helpers → exit 42)

**Key verification points**:
- `runtimeContractCount=2` in build output proves `np.system.process_init` / `np.system.process_fini` semantic seed
- `@np_object_alloc` and `@np_object_free_release` in LLVM IR proves object-free lifecycle helper emission
- `movq $60, %rax; syscall` in LLVM IR proves halt syscall emission
- Executables run with expected exit codes (0 or 42)

**No additional smoke script needed** — existing `verify_local.sh` covers:
- [x] Process lifecycle direct-consume (compiler → HIR → LLVM → executable)
- [x] Object-free lifecycle direct-consume (class Create/Free)
- [x] Halt contract direct-consume (halt syscall emission)

Evidence: `build/verify_local.sh:1740-1769` (llvm-empty-program), `1771-1800` (llvm-halt-program), llvm_class_basic smoke tests.

### S5.4 Landing Candidate Preparation

- [x] Create contract coverage table: all live `np.system.*` contracts with HIR/L证据状态. ✅ Done (contract-coverage-table.md)
- [x] Create helper mapping appendix: HIR intrinsic → LLVM helper → test coverage. ✅ Done (contract-coverage-table.md Backend-Private Helper Names section)
- [x] Document remaining open risks (TypInfo drift, managed array leak gap, lifecycle execution gap). ✅ Done (contract-coverage-table.md S5.4 Remaining Open Risks)

**S5 is now complete**. All four sub-stages (S5.1-S5.4) have been addressed.

**Summary of S5 Deliverables**:

1. **Contract Coverage Table** (`contract-coverage-table.md`): 14 contracts mapped with HIR/LLVM/test evidence and gap annotations.
2. **Helper Mapping Appendix**: 22 backend-private `@np_*` helpers documented with contract alignment.
3. **TypInfo Consumer Risk**: Documented metadata-sensitive consumers and RTTI drift risk.
4. **Open Risks Document**: Four risks (TypInfo drift, managed array leak gap, lifecycle execution gap, exception naming) with severity ratings.
5. **Helper-Family Mapping**: Source-contract checks for halt/intf/arr_alloc/class_alloc, focused test for interface contract.
6. **Integration Smoke**: Verified via existing `build/verify_local.sh` LLVM smoke tests.

**Next Phase**: S5 completion clears the way for landing candidate review. The module
documentation (goal-tree, contract-coverage-table, runtime-contracts, lifecycle-contracts)
is synchronized with source-contract checks and focused tests. The remaining risks are
explicitly documented and scoped for future work.
