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

- [x] Align managed dynamic-array compiler contract projection with system runtime contract names.
- [x] Prove managed dynamic-array contract vocabulary is explicit without freezing backend-private helper symbols.
- [x] Align process-level startup/shutdown semantic seed with `np.system.process_init` / `np.system.process_fini`.
- [x] Prove process lifecycle semantic seed exact-name order without upgrading runtime execution or unit lifecycle.
- [ ] Align remaining facade docs with compiler runtime contract names and source-backed `System` truth.
- [ ] Prove remaining runtime helper references are explicit, stable and not backend-private magic strings.
- [ ] Add integration smoke once compiler/runtime can consume the core-system contract directly.
- [ ] Prepare a landing candidate only after focused gates and cross-module risks are clean.
