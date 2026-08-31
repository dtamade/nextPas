# core-system Goal Tree

This goal tree is scoped to `nextpas.core.system` as a core framework module family. It does not replace
the repository-level `rtl/core/system/` architecture docs; it gives this lane a staged path with focused
verification.

## M0 System Truth Convergence (current authority)

- [x] Make `rtl/core/system/System.pas` the canonical compiler-root source.
- [x] Make `units/linux-x86_64/System.pas` a checked projection; canonical projection parity is
  enforced by `make system-projection-check`.
- [x] Add the typed `TSystemContractKind` ledger for the current `np.system.*` vocabulary.
- [x] Make source contracts follow logical compiler owner families rather than one physical include file.
- [~] Move semantic/HIR/backend dispatch from strings to typed contract identity — production
  families landed: object-free (root/destroy/cleanup/release), process init/fini, string
  ownership triad, dynarray set_length/fini, interface addref/release, halt; remaining
  residual families still string-dispatched (`dynarray_init` is vocabulary-only).
- [ ] Add `SystemContractFingerprint` and the immutable semantic snapshot.
- [~] Execute the complete A -> B -> C compiler-system bootstrap chain — M2-0 harness and
  M2-1 ladder L0–L2 are green; L3 (full stage0 driver A→B link) is blocked on residual
  undefined symbols at `opt` (see `docs/plans/m2/wave0-ledger.md` and
  `self-hosting-readiness.md`); B→C not started.

Current M0 evidence is source-contract, projection, and typed-inventory evidence. It does not prove
runtime completeness, ABI stability, or self-host readiness. The compiler-side milestone
authority is `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` (M0–M9); this lane's
M0 items map onto that plan's M0/M1/M2.

## Historical S-stage capability inventory

The S0-S12 sections below preserve earlier facade and kernel assessments. Their checked boxes and
completion labels are not current readiness authority; current bootstrap status is defined by the M0
section above and `docs/architecture/runtime-bootstrap-specification.md`.

## Historical S0 Mapping / Spec / Source Contracts

- [x] Create `core/docs/system/README.md` with position, owner boundary and non-goals.
- [x] Create `core/docs/system/rtl-mapping.md` with FPC `System`, `SysUtils`, `TypInfo`, `Classes` and `ObjPas` mapping.
- [x] Create `core/docs/system/goal-tree.md`.
- [x] Add source-contract tests proving docs exist, mapping statuses exist, and system units avoid direct OS owner bypass.

Exit evidence:

- `make -C core/tests/nextpas.core.system clean test`
- `git diff --check`
- `make hygiene`

## Historical S1 Minimal Facade And Base Compatibility

- [x] Add `nextpas.core.system` facade skeleton.
- [x] Re-export only low-risk base and exception aliases needed by early consumers.
- [x] Delegate memory helper wrappers to `nextpas.core.base.utils` without changing guard semantics.
- [x] Prove `nextpas.core.base` and `nextpas.core.system` can be used in the same program.
- [x] Prove exception root remains canonical through `nextpas.core.exception`.

Exit evidence:

- `make -C core/tests/nextpas.core.system clean test`
- Base focused tests if `base` or `base.utils` is touched.
- Exception focused tests if `exception` or `errors` is touched.

## Historical S2 Memory / Managed / Dynarray / String Runtime Contracts

- [x] Document managed string, dynamic array, interface and managed record lifetime contracts.
- [x] Map heap-manager responsibilities onto `nextpas.core.mem` without moving allocator ownership.
- [x] Add source-contract tests for runtime helper names and owner boundaries.
- [x] Record leak-sensitive test requirements before any runtime-owned implementation appears.

## Historical S3 Exception / RTTI / Unit Lifecycle Contracts

- [x] Document exception raise/unwind boundary between compiler, runtime and exception taxonomy owner.
- [x] Document RTTI / TypeInfo minimum truth and what remains compiler-owned.
- [x] Document unit initialization/finalization ordering and failure behavior.
- [x] Add source-contract tests for `np.system.unit_init`, `np.system.unit_fini` and runtime-fault classification.

## Historical S4 SysUtils / TypInfo / Classes Compatibility Facades

- [x] Record that broad SysUtils and Classes remain deferred and are not a current phase gate.
- [x] Record that `system.classes` now exists as a Classes compatibility shim re-exporting TStream, TFileStream, TList, TInterfaceList, TStringList, TDuplicates, TThread, TSeekOrigin, and file mode constants. Broader Classes surface (THandleStream, TMemoryStream, TStringStream, TInterfacedObject) remains outside system scope.
- [x] Record design-only S4 facade boundaries in `compatibility-facades.md`.
- [x] Record live consumer pressure and migration risk in `compatibility-matrix.md`.
- [x] Record TypInfo minimal pressure audit in `typinfo-minimal-pressure.md`.
- [x] Prepare a TypInfo minimal unlock `Needs Review` packet with exact symbol list, owner boundary, file set, and focused gates.
- [x] Add the minimal live `nextpas.core.system.typinfo` unit for the seven-symbol pressure set. TypInfo minimal live unit is unlocked.
- [x] Add the minimal live `nextpas.core.system.sysutils` exception-formatting unit for `Format` and canonical exception aliases.
- [x] Add the minimal live `SameText` string-comparison facade slice; **owner is `nextpas.core.text.conv`** (ASCII fold), sysutils only re-exports.
- [x] Add the minimal live `IntToStr` numeric conversion slice, delegating to the text owner.
- [x] Add the minimal live `Trim` token-normalization slice for compiler generic parameter matching, delegating to the text owner.
- [x] Expand TypInfo facade: PTypeData, TTypeData, GetPropInfo, GetEnumName, GetEnumValue (S8.11)
- [x] Expand SysUtils facade: S4 minimal text/conv/bytes only — `Format`/`SameText`/`IntToStr`/`Trim` plus `CompareStr`, numeric `TryStrToInt`/`FloatToStr`, `BytesOf`/`StringOf` (zero-copy `bytes.ops`), `UpperCase`/`Pos` etc., no `FileExists`/`ExtractFilePath`/`Now`/`Sleep` (fs/path/time stay with owners) (S8.12 — repaired to S4 minimal)
- [x] Decide whether broader Classes deserve `system.*` facade units. Classes already has a compatibility shim (TStream, TFileStream, TList, TInterfaceList, TStringList, TThread); broader Classes surface (THandleStream, TMemoryStream, TStringStream, TInterfacedObject) does not belong in system scope and stays with owner modules. **Decision: No broader Classes facade. THandleStream/TMemoryStream/TStringStream stay with nextpas.core.io; TInterfacedObject stays with nextpas.core.base.**
- [x] Add only tested aliases or forwarding functions for future compatibility slices; no broad historical copy. **Decision: Only add aliases with real consumer pressure and focused tests.**
- [x] Keep filesystem, time, IO, math, text and collection implementation ownership in their existing modules. **Decision: Confirmed. System only provides thin facades, never owns implementation.**
- [x] Report `Needs Review` before exposing compatibility API with wide consumer impact.

Historical S4 closeout record: TypInfo facade coverage, SysUtils facade coverage, and the Classes
deferral were reported at that time. They are not current compiler-root or readiness evidence.
- SysUtils stays S4 minimal (text/conv/bytes only) via delegation to `text.conv`/`text.format`/`bytes.ops`/`base.utils`; path/file/time/env remain with `fs`/`path`/`time`/`os.env` owners and are not re-exported (repaired 2026-08-31 to restore owner boundary).
- TypInfo minimal unlock was preceded by a dedicated `Needs Review` packet and is limited to
  `PTypeInfo`, `TTypeKind`, `PTypeData`, `TTypeData`, `GetPropInfo`, `GetEnumName`, `GetEnumValue`.
- TypeInfo and GetTypeKind are compiler/System compile-truth imports, not unit-owned wrapper functions in `nextpas.core.system.typinfo`.
- TypInfo `TTypeKind` aliases cover current collections comparer/equality
  dispatch needs without expanding into reflection metadata.
- TypInfo has an interface managed-lifetime proof through managed interface
  array lifecycle helpers, without expanding metadata layout promises.
- `nextpas.core.system.classes` is live as a Classes compatibility shim (TStream, TFileStream, TList, TInterfaceList, TStringList, TDuplicates, TThread, TSeekOrigin, file mode constants). This round does not expand the shim; broader Classes types (THandleStream, TMemoryStream, TStringStream, TInterfacedObject) stay with their owner modules.
- If real consumer pressure appears, reopen as `Needs Review` with focused evidence instead of creating
  broad placeholders.

## Historical S5 Compiler / Runtime Integration Readiness

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
- `runtime-contracts.md:115-116` documents HIR uses `intf_addref`/`intf_release` as internal intrinsic names.
- `runtime-contracts.md:203-208` documents HIR uses `arr_alloc`/`class_alloc` as allocation intrinsics.
- `check_system_source_contracts.sh:681-692` verifies HIR builder and emitter use implementation names.
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

**Historical S5 closeout record**: all four sub-stages (S5.1-S5.4) were reported as addressed.

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

## Historical S6 Contract-to-Implementation Bridge

S6 prepares the contract vocabulary for self-hosting readiness without implementing runtime
behavior. Focus: close documentation gaps, fill test coverage, define self-hosting gates.

### S6.1 Exception Boundary Contract Lock

- [x] Add `np.system.exception_try_push`, `np.system.exception_try_pop`, `np.system.exception_raise`, `np.system.exception_finally_end`, `np.system.exception_except_end` contract names to `lifecycle-contracts.md`.
- [x] Add source-contract checks for all 5 exception helpers (LLVM emitter existence + lifecycle-contracts.md tokens).
- [x] Update `contract-coverage-table.md` with exception contract rows (19 total contracts now).
- [x] Verify all source-contract checks pass.

### S6.2 Leak-Sensitive Test Fill

- [ ] Add heaptrc 0-leak evidence for `array of interface` release path (currently has HIR contract test only, no heaptrc).
- [x] Managed interface dynarray HIR contract projection test exists at `test_hir_dynarray_release_contract.pas:306-327`.
- [ ] Managed record dynarray: compiler does not support managed record types yet — deferred.
- [x] Dynarray resize failure path HIR contract verification exists (checks `@np_dynarray_fault` emission).

**Note**: S6.2 is partially complete. Managed interface dynarray has HIR contract coverage but lacks heaptrc runtime evidence. Managed record dynarray is deferred until the compiler supports managed record types.

### S6.3 Contract Vocabulary Final Audit

- [x] Audit all `19 np.system.*` contracts for owner/status/path consistency.
- [x] Cross-check `contract-coverage-table.md` ↔ `runtime-contracts.md` ↔ `lifecycle-contracts.md`.
- [x] Ensure every live contract has HIR evidence and test coverage documented.
- [x] All contracts present in both contract-coverage-table and respective doc (runtime-contracts.md or lifecycle-contracts.md).

### S6.4 Self-Hosting Readiness Gates

- [x] Create `self-hosting-readiness.md` with 5 gates: RTTI drift detection, unit lifecycle, process lifecycle, heap manager, exception unwind.
- [x] Per-gate owner assignment documented (compiler, mem, collections, rtl, system).
- [x] Acceptance criteria defined for each gate.
- [x] Update `goal-tree.md` with S6 completion status.

**Historical S6 closeout record**: main deliverables were reported as:

1. **Exception contracts**: 5 `np.system.exception_*` names documented, source-contract checked, coverage table updated.
2. **Leak-sensitive gap documented**: Managed interface array has HIR contract coverage, heaptrc evidence still needed.
3. **Contract audit**: All 19 contracts consistent across 3 documentation files.
4. **Self-hosting readiness**: 5 gates with owner assignment, acceptance criteria, and current status.
5. **SysUtils facade expanded**: `SameText`, `IntToStr`, and `Trim` re-exported via `nextpas.core.system.sysutils` **from owner `nextpas.core.text.conv`**, matching pre-existing tests (6/6 pass).
6. **FPC RTL enforcement gate**: File-level allowlist (`fpc_rtl_file_allowlist.txt`) prevents new SysUtils/Classes/TypInfo/DateUtils/BaseUnix/Unix/Windows debt from entering `core/src/nextpas.core.*.pas`.

**Debt Landscape Summary** (as of 2026-06-14):

| Unit | Files | Largest holder |
|------|-------|---------------|
| SysUtils | 272 | tls (~200) |
| Classes | 142 | tls (~138) |
| DateUtils | 18 | tls (~15) |
| TypInfo | 1 | system-kernel-route |
| BaseUnix | 10 | tls (~7) |
| Unix | 7 | tls (~5) |
| Windows | 20 | tls (~18) |

Future migration slices should reduce counts in `fpc_rtl_file_allowlist.txt`, not add new entries.

## Historical S7 System Kernel Implementation

The historical S7 plan treated the system kernel as the compiler-root source of truth. M0 now assigns
that authority only to `rtl/core/system/System.pas`; the facade/kernel inventory below is retained for
traceability. The historical plan used a dual-compiler architecture: FPC uses `fpc.inc` (re-export FPC
types), and nextPas uses `kernel.inc` (full kernel definition).

### S7.1 Dual-Compiler Fork Structure

- [x] Create `nextpas.core.system.fpc.inc` — re-export FPC System types under FPC compilation.
- [x] Create `nextpas.core.system.kernel.inc` — nextPas kernel entry point, includes sub-modules.
- [x] Update `nextpas.core.system.pas` to use `{$IFDEF FPC}` / `{$ELSE}` fork.
- [x] Verify FPC compilation works with new structure.

### S7.2 Kernel Sub-Modules Implementation

- [x] Create `nextpas.core.system.base.inc` — basic types (SizeInt, SizeUInt, TBytes, C ABI types).
- [x] Create `nextpas.core.system.str.inc` — string types (ShortString, AnsiString, WideString, UnicodeString).
- [x] Create `nextpas.core.system.intf.inc` — interface types (TGUID, IUnknown, TInterfaceEntry, TMethod).
- [x] Create `nextpas.core.system.cls.inc` — class types (VMT constants, TVmt record, TObject, TClass).
- [x] Create `nextpas.core.system.rtti.inc` — RTTI types (TTypeKind, TTypeInfo, managed type lifecycle).
- [x] Create `nextpas.core.system.except.inc` — exception classes (Exception, EAbort, EConvertError, etc.).
- [x] Create `nextpas.core.system.mem.inc` — memory operations (FreeAndNil, ZeroMem, Supports).
- [x] Create `nextpas.core.system.comp.inc` — compiler internal functions (fpc_* series).

### S7.3 Compiler Root Directives

- [x] Add `{$compiler_root}` directive to TObject in `cls.inc`.
- [x] Add `{$compiler_type_kind}` directive to TTypeKind in `rtti.inc`.
- [x] Document directive usage in `kernel-design.md`.

### S7.4 VMT Layout Definition

- [x] Define VMT constants matching FPC layout (vmtInstanceSize=0, vmtParent=SizeOf(SizeInt)*2, etc.).
- [x] Define TVmt record with all VMT slots.
- [x] Implement TObject methods that use VMT layout (ClassName, ClassParent, InstanceSize, etc.).

### S7.5 Compiler Internal Functions

- [x] Define fpc_* series functions with `compilerproc` directive.
- [x] Implement stubs for all compiler internal functions.
- [x] Document that real implementations provided by runtime.

**Historical S7 closeout record**: main deliverables were reported as:

1. **Dual-compiler fork**: `fpc.inc` re-exports FPC types, `kernel.inc` defines nextPas kernel.
2. **8 kernel sub-modules**: base, str, intf, cls, rtti, except, mem, comp.
3. **Compiler directives**: `{$compiler_root}` and `{$compiler_type_kind}` directives.
4. **VMT layout**: Constants and TVmt record matching FPC layout.
5. **TObject implementation**: Full TObject class with all methods.
6. **Compiler internal functions**: fpc_* series stubs for runtime integration.

**Next Phase**: S7 completion clears the way for compiler integration. The kernel is ready
for the compiler to recognize `{$compiler_root}` and `{$compiler_type_kind}` directives
and read type information from the kernel.

## Historical S8 Kernel Surface Completeness Audit

The historical S8 plan performed a broad gap analysis between its kernel surface and FPC's System unit.
That broad-surface goal is not the active M0 direction: the canonical System kernel remains limited to
compiler-facing declarations and does not claim production-quality FPC coverage.

### S8.1 FPC System Surface Audit

Compare our kernel against FPC's System unit (`rtl/inc/systemh.inc`, ~206 functions, ~60 types):

| Category | FPC Surface | Kernel Status | Gap |
|----------|-------------|---------------|-----|
| Basic types (SizeInt, etc.) | 12 types | ✅ base.inc | None |
| Pointer types (PByte, etc.) | 9 types | ✅ base.inc | None |
| String types (AnsiString, etc.) | 8 types | ✅ str.inc | None |
| Interface types (IUnknown, etc.) | 6 types | ✅ intf.inc | None |
| Class types (TObject, TClass, VMT) | 3 types + VMT | ✅ cls.inc | None |
| RTTI types (TTypeKind, etc.) | 6 types | ✅ rtti.inc | None |
| Exception types | 20+ classes | ✅ except.inc | None |
| Memory management | 5 functions | ✅ mem.inc | None |
| Compiler internal (fpc_*) | 90+ stubs | ✅ comp.inc | None |
| Variant type | Variant, TVarType, TVarData | ✅ base.inc | None |
| Dynamic array type | TBytes, TCharArray | ✅ base.inc | None |
| Memory manager | TMemoryManager, TMemoryManagerEx | ✅ memmgr.inc | None |
| Program lifecycle | InitModule, FinalizeModule | ✅ lifecycle.inc | None |
| Byte swap / endian | SwapEndian, BEtoN, LEtoN | ✅ endian.inc | None |
| Barrier / prefetch | ReadBarrier, WriteBarrier, Prefetch | ✅ barrier.inc | None |
| Bulk fill/search/compare | FillByte, IndexChar, CompareChar | ✅ intrinsics.inc | None |
| Thread types | TThread, TRTLCriticalSection | ✅ thread.inc | None |
| I/O types | Text, File, TFileRec | ✅ io.inc | None |

### S8.2 Variant Type Support

- [x] Define `Variant` type in `base.inc` (compiler built-in, TVarType/TVarData defined)
- [x] Define `TVarType` (Word alias)
- [x] Define `TVarData` record (variant storage layout)
- [x] Define variant constants (`varEmpty`, `varNull`, `varSmallint`, etc.)
- [x] Define `TVarOp` enum (variant operations)
- [ ] Add variant operator stubs (`=`, `<>`, `+`, `-`, `*`, `/`, etc.) — deferred
- [x] Add `VarType()`, `VarIsNull()`, `VarIsEmpty()` functions

### S8.3 Dynamic Array Type Support

- [x] Define dynamic array type declaration syntax support
- [x] Add `TBytes = array of Byte`
- [x] Add `TCharArray = array of Char`
- [x] Document dynamic array lifecycle (reference counting, copy-on-write)

### S8.4 Thread Types Support

- [x] Define `TThread` class (for compiler type resolution)
- [x] Define `TRTLCriticalSection` record
- [x] Define `TThreadFunc` function type
- [x] Add `BeginThread`, `EndThread` function stubs
- [x] Add `InterlockedIncrement`, `InterlockedDecrement`, `InterlockedExchange` stubs

### S8.5 I/O Types Support

- [x] Define `Text` type (TextFile alias)
- [x] Define `File` type
- [x] Define `TFileRec` record
- [x] Define `TTextRec` record
- [x] Add `AssignFile`, `Reset`, `Rewrite`, `Append`, `CloseFile` stubs
- [x] Add `Read`, `ReadLn`, `Write`, `WriteLn` stubs

### S8.6 Memory Manager Interface

- [x] Define `TMemoryManager` record (GetMem, FreeMem, ReAllocMem, etc.)
- [x] Define `TMemoryManagerEx` record (extended with AllocMem, MemSize)
- [x] Add `GetMemoryManager`, `SetMemoryManager` functions
- [x] Add `IsMemoryManagerSet` function

### S8.7 Program Lifecycle Support

- [x] Define `InitModule` procedure stub
- [x] Define `FinalizeModule` procedure stub
- [x] Define unit initialization/finalization order contracts
- [x] Document `process_init` / `process_fini` lifecycle

### S8.8 Byte Swap and Endian Support

- [x] Add `SwapEndian` overloaded functions (SmallInt, Word, LongInt, DWord, Int64, QWord)
- [x] Add `BEtoN`, `LEtoN`, `NtoBE`, `NtoLE` overloaded functions
- [x] Add `HTonN`, `NToHs` (network byte order) for socket support

### S8.9 Barrier and Prefetch Support

- [x] Add `ReadBarrier`, `ReadWriteBarrier`, `WriteBarrier` intrinsic stubs
- [x] Add `Prefetch` intrinsic stub
- [x] Document memory ordering guarantees

### S8.10 Additional FPC System Functions

- [x] Add `FillByte`, `FillDWord`, `FillQWord` (bulk fill)
- [x] Add `IndexChar`, `IndexByte`, `IndexWord`, `IndexDWord` (search)
- [x] Add `CompareChar`, `CompareByte`, `CompareWord`, `CompareDWord` (compare)
- [x] Add `MoveChar0` (null-terminated move)
- [x] Add `MemPos` (memory search)
- [x] Add `StackTop` function
- [x] Add `Swap` overloaded functions
- [ ] Add `Inc`, `Dec`, `Include`, `Exclude` intrinsic stubs — deferred
- [ ] Add `SetLength`, `Copy`, `Delete`, `Insert`, `Pos`, `Concat` string intrinsics — deferred

### S8.11 TypInfo Facade Completeness

- [x] Audit TypInfo surface: `PTypeInfo`, `TTypeKind`, `TTypeInfo`, `TTypeData`
- [x] Add `PTypeData`, `TTypeData` type aliases
- [x] Add `GetPropInfo` for property RTTI
- [x] Add `GetEnumName`, `GetEnumValue` for enum RTTI
- [ ] Add `GetTypeKind` compiler intrinsic — deferred (compiler built-in, not in TypInfo unit)
- [x] Add `PropInfo`, `PropList` for property RTTI — PPropInfo/PPropList type aliases + GetPropList forwarding

### S8.12 SysUtils Facade Completeness

- [x] Audit SysUtils surface used by core modules
- [x] Add `Format` (already present via text.conv)
- [x] Add `SameText` (already present via text.conv)
- [x] Add `IntToStr` (already present via text.conv)
- [x] Add `Trim` (already present via text.conv)
- [x] Add `StrToInt`, `StrToInt64`, `StrToFloat` (numeric parsing)
- [x] Add `FloatToStr`, `CurrToStr` (numeric formatting)
- [x] Add `DateTimeToStr`, `DateToStr`, `TimeToStr` (date/time formatting)
- [x] Add `Now`, `Date`, `Time` (date/time access)
- [x] Add `FileExists`, `DirectoryExists` (filesystem checks)
- [x] Add `CreateDir`, `RemoveDir`, `ForceDirectories` (directory ops)
- [x] Add `DeleteFile`, `RenameFile`, `CopyFile` (file ops)
- [x] Add `ExtractFilePath`, `ExtractFileName`, `ExtractFileExt` (path ops)
- [x] Add `ChangeFileExt`, `IncludeTrailingPathDelimiter` (path manipulation)
- [x] Add `GetCurrentDir`, `SetCurrentDir` (working directory)
- [x] Add `ParamCount`, `ParamStr` (command line)
- [x] Add `GetEnvironmentVariable` (environment)
- [x] Add `Sleep` (timing)
- [x] Add `SysErrorMessage`, `GetLastOSError` (error handling)

**S8 Exit Criteria**:
- All kernel .inc files have complete type definitions matching FPC surface
- All fpc_* stubs in comp.inc have correct signatures
- TypInfo facade covers all RTTI types used by core modules
- SysUtils facade covers all functions used by core modules
- Historical report: `make -C core/tests/nextpas.core.system clean test` passed with 126 tests and 0 leaks
- `fpc -Mobjfpc core/src/nextpas.core.system.pas` compiles cleanly

**Historical S8 completion record** (S8.2-S8.12 were reported as done):

1. **Variant type**: TVarType, TVarData, varEmpty..varUString constants defined in base.inc
2. **Dynamic array types**: TBytes, TCharArray defined in base.inc
3. **Thread types**: TThread, TRTLCriticalSection, BeginThread/EndThread, InterlockedIncrement/Decrement in thread.inc
4. **I/O types**: TFileRec, TTextRec, File, Text, AssignFile/Reset/Rewrite/Append/CloseFile, Read/ReadLn/Write/WriteLn in io.inc
5. **Memory manager**: TMemoryManager, TMemoryManagerEx, GetMemoryManager/SetMemoryManager in memmgr.inc
6. **Program lifecycle**: InitModule, FinalizeModule in lifecycle.inc
7. **Byte swap/endian**: SwapEndian, BEtoN, LEtoN, NtoBE, NtoLE in endian.inc
8. **Barrier/prefetch**: ReadBarrier, WriteBarrier, Prefetch in barrier.inc
9. **Intrinsics**: FillByte, IndexChar, CompareChar, MemPos, StackTop in intrinsics.inc
10. **TypInfo facade**: PTypeData/TTypeData + GetPropInfo/GetEnumName/GetEnumValue
11. **SysUtils facade**: 40+ functions (StrToInt/FloatToStr/FileExists/ExtractFilePath/Now/Sleep etc.)

**Historical S8 closeout record**: all kernel surface items were reported as addressed, with 126 tests
(kernel 92 + source 19 + typinfo 9 + sysutils 6) and 0 leaks. This is not fresh readiness evidence.

**Next Phase**: S8 completion clears the way for compiler integration. The kernel is ready
for the compiler to recognize `{$compiler_root}` and `{$compiler_type_kind}` directives
and read type information from the kernel.

## Historical S9 Compiler Integration

S9 让编译器从"不知道 system 内核存在"到"从内核读取所有根类型"。

### S9.1 Compiler Root Directive Recognition

- [x] 编译器解析 `{$compiler_root}` 注解
- [x] 将标注的类型绑定为编译器根类（TObject/TClass）
- [ ] 编译器从 kernel.inc 读取 VMT 布局常量
- [x] 验证 self-compile 19/19 不回归
- [x] 验证 compiler-pass 49/49 不回归

### S9.2 Compiler Type Kind Directive Recognition

- [x] 编译器解析 `{$compiler_type_kind}` 注解
- [x] 将标注的枚举绑定为类型种类（TTypeKind）
- [ ] 编译器使用内核的 tk* 常量
- [x] 验证类型推断和类型检查不受影响

### S9.3 Compiler Internal Function Binding

- [x] 编译器使用 np_* 函数替代 fpc_* 函数（双编译器架构）
- [x] 编译器将 np_* 调用映射到内核定义
- [x] 验证 np_* 调用生成正确的 LLVM IR

### S9.4 Contract Name to HIR Intrinsic Mapping

- [x] 编译器将 `np.system.*` 契约名称映射到 HIR intrinsic
- [x] 验证关键契约名称在 HIR 中有对应 intrinsic（np_process_init/fini, np_object_free_release, np_intf_addref/release 等）
- [x] 验证 LLVM emitter 正确处理这些 intrinsic

**S9 Exit Criteria**:
- `{$compiler_root}` 标注的类型被编译器识别为根类 ✅
- `{$compiler_type_kind}` 标注的枚举被编译器识别为类型种类 ✅
- np_* 函数签名被编译器正确绑定 ✅
- self-compile 19/19 通过 ✅
- compiler-pass 49/49 通过 ✅

## Historical S10 Runtime Implementation

S10 将内核从"签名桩"转变为"真实实现"。

> **架构原则**: nextPas 编译器生成 `np_*` 调用，不生成 `fpc_*` 调用。
> `fpc_*` 是 FPC 的内部 ABI，nextPas 不实现 fpc_* 函数。
> 双编译器架构：FPC 编译时用 FPC 的 fpc_*，nextPas 编译时用 nextPas 的 np_*。

### S10.1 np_* Runtime Function Implementation ✅

编译器 LLVM emitter 生成 48 个 np_* 函数调用，运行时全部有真实实现。

**内存管理** (6): ✅ np_alloc / np_realloc / np_free / np_memset / np_memmove / np_memcpy / np_memzero
**对象生命周期** (3): ✅ np_object_alloc / np_object_free_release / np_intf_addref / np_intf_release
**字符串操作** (16): ✅ np_tstring_* (16个) + np_str_* (7个)
**动态数组** (3): ✅ np_dynarray_resize / np_dynarray_release
**异常处理** (5): ✅ np_raise / np_try_push / np_try_pop / np_except_end / np_finally_end
**程序生命周期** (4): ✅ np_process_init / np_process_fini / np_unit_init_* / np_unit_fini_*
**错误处理** (3): ✅ np_string_fault / np_dynarray_fault / np_allocator_fault

运行时文件: `rtl/runtime/src/nextpas.runtime.*.ll` (8 个模块)

### S10.2 Thread Implementation ✅

编译器直接使用 LLVM 原语，不需要 np_* 函数：
- ✅ InterlockedCAS/Xchg/FetchAdd → LLVM cmpxchg/atomicrmw 指令
- ✅ ThreadVar → LLVM thread_local 全局变量
- TThread/BeginThread/EndThread → platform 模块提供（类级别，非编译器内建）

### S10.3 I/O Implementation ✅

编译器使用内建函数，不需要 np_* 函数：
- ✅ WriteInt → write_i64_decimal (runtime helper)
- ✅ WriteStr → np_tstring_* 函数链
- 文件 I/O → nextpas.core.fs 模块提供（类级别，非编译器内建）

### S10.4 Memory Manager Integration ✅

- ✅ np_alloc/np_free/np_realloc → 运行时分配器 (brk + mmap)
- ✅ 小块 (<64K): bump pointer + free list + coalesce
- ✅ 大块 (>=64K): mmap with 16-byte prelude
- TMemoryManager 接口 → kernel 中定义，运行时已实现

### S10.5 Program Lifecycle Implementation ✅

编译器已处理完整的程序生命周期：
- ✅ 编译器 _start → np_process_init → np_unit_init_* (拓扑序) → main → np_unit_fini_* (逆序) → np_process_fini → halt
- ✅ np_process_init/fini: 运行时实现 (Phase 0: fsync + 状态标志)
- ✅ np_unit_init_*/fini_*: 语义分析器为每个有 init/fini section 的单元生成
- ✅ 生命周期顺序: 依赖先 init，逆序 fini

**S10 Exit Criteria** (全部满足):
- ✅ 所有 48 个 np_* 函数有真实实现
- ✅ Interlocked 操作使用 LLVM atomic 原语
- ✅ Write/WriteStr 使用 runtime helpers + np_tstring_*
- ✅ 内存分配器实现 (brk + mmap)
- ✅ 程序生命周期完整 (process_init → unit_init → main → unit_fini → process_fini)
- ✅ 所有测试通过 (smoke + compiler-pass 49/49)

## Historical S11 Self-Hosting Readiness

S11 让编译器能用 nextPas 编译自己，不依赖 FPC System。

### S11.1 RTTI Drift Detection Gate ✅

- ✅ 内核 TTypeKind 与 FPC 完全一致（30 个枚举值）
- ✅ 自动检测 RTTI 定义漂移（source-contracts 测试）
- ✅ 验证编译器和内核的 TTypeKind 枚举值完全匹配

### S11.2 Unit Lifecycle Gate ✅

- ✅ 编译器生成 np_unit_init_*/fini_* 函数（语义分析器）
- ✅ 编译器 _start 调用顺序: process_init → unit_init* → main → unit_fini* → process_fini
- ✅ 单元初始化顺序: 拓扑序（依赖先初始化）
- ✅ 单元终结化顺序: 逆拓扑序（依赖后终结化）

### S11.3 Process Lifecycle Gate ✅

- ✅ np_process_init/fini 运行时实现（Phase 0: fsync + 状态标志）
- ✅ 程序启动序列: 编译器生成 _start → process_init → unit_init* → main
- ✅ 程序关闭序列: 编译器生成 unit_fini* → process_fini → halt
- ✅ 验证 compiler-pass 49/49 通过

### S11.4 Heap Manager Gate ✅

- ✅ np_alloc/np_free/np_realloc 运行时实现（brk + mmap）
- ✅ 内存分配/释放/重分配正常工作
- ✅ 小块 (<64K): bump pointer + free list + coalesce
- ✅ 大块 (>=64K): mmap with 16-byte prelude

### S11.5 Exception Unwind Gate ✅

- ✅ np_raise/np_try_push/np_try_pop 运行时实现（setjmp/longjmp）
- ✅ np_finally_end/np_except_end 运行时实现
- ✅ 异常展开正确恢复栈（control_flow_pass.pas 验证）
- ✅ 验证异常测试通过（compiler-pass 49/49，含 try/except）

**Historical S11 exit-criteria record** (reported as satisfied):
- ✅ nextPas 编译器能编译 nextPas 编译器（self-compile 19/19）
- ✅ 不 uses FPC System（双编译器架构）
- ✅ 所有 19 个自举测试通过
- ✅ 5 个自举就绪门全部通过 (S11.1 ✅, S11.2 ✅, S11.3 ✅, S11.4 ✅, S11.5 ✅)

## Historical S12 Production Readiness

S12 从"能跑"到"好用"。

### S12.1 ABI Stability ✅

- ✅ VMT 布局常量冻结（28 个槽位，偏移 0-216）
- ✅ np_* 函数签名冻结（48 个函数）
- ✅ 内存管理器接口冻结（TMemoryManager 回调）
- Historical report: ABI-stability proposal documented in `abi-specification.md` as `v1.0.0-frozen`

### S12.2 Performance Optimization ✅

- ✅ 异常展开：setjmp/longjmp 实现，最小开销
- ✅ 内存分配：brk + mmap + free list coalesce，小块 <64K 用 bump pointer
- ✅ 字符串操作：SSO (≤15B 内联) + CoW (引用计数)
- ✅ 关键路径：49 compiler-pass 测试通过，含 control_flow + unit_lifecycle

### S12.3 Cross-Platform Support

- ✅ Linux x86_64 完全覆盖（runtime + platform 模块）
- ✅ 编译器支持可配置 target triple/data layout
- ✅ platform 模块支持 Linux/macOS/FreeBSD/Windows
- [ ] macOS x86_64/arm64 runtime 适配（syscall 差异）
- [ ] Windows x86_64 runtime 适配（syscall 差异）
- [ ] 验证跨平台测试通过

### S12.4 Documentation ✅

- ✅ Public API 文档（api-reference.md — 4 门面 + 完整导出清单）
- ✅ 使用指南（usage-guide.md — 内核贡献者 + 框架消费者）
- ✅ 兼容性矩阵（compatibility-matrix.md — 29 个能力点）
- ✅ 设计决策文档（design-decisions.md — 11 个 ADR）

### S12.5 Compatibility Testing ✅

- ✅ 与 FPC 现有代码的兼容性验证（49 compiler-pass 测试）
- ✅ 兼容性矩阵覆盖 29 个能力点
- ✅ 回归测试套件完善（source-contracts 测试 + TTypeKind drift detection）

**Historical S12 exit-criteria record** (reported as partially satisfied):
- Historical claim: ABI stability and backward-compatibility commitment (`v1.0.0-frozen`)
- ✅ 性能优化（brk+mmap 分配器 + setjmp/longjmp 异常 + SSO/CoW 字符串）
- ✅ 文档完善（API 参考 + 使用指南 + 兼容性矩阵 + 设计决策）
- ✅ 兼容性测试通过（49 compiler-pass + 29 能力点矩阵）
- [ ] 跨平台全覆盖（Linux x86_64 ✅, macOS/Windows runtime 适配待做）

## Current direction

The archived S-stage material above is useful for locating old proposals and capability claims, but it
does not establish current runtime, ABI, self-hosting, or production readiness. The active sequence is:

```text
M0 truth convergence
  -> M1 minimum bootstrap kernel
  -> M2 typed dispatch and System identity
  -> M3 executable runtime behavior
  -> M4 actual A -> B -> C bootstrap
  -> M5 determinism and performance evidence
```

The current M0 gate is canonical projection parity plus source-backed contract evidence. Platform
expansion follows only after the executable bootstrap path is proven.
