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

- [ ] Document managed string, dynamic array, interface and managed record lifetime contracts.
- [ ] Map heap-manager responsibilities onto `nextpas.core.mem` without moving allocator ownership.
- [ ] Add source-contract tests for runtime helper names and owner boundaries.
- [ ] Add leak-sensitive tests before any runtime-owned implementation appears.

## S3 Exception / RTTI / Unit Lifecycle Contracts

- [ ] Document exception raise/unwind boundary between compiler, runtime and exception taxonomy owner.
- [ ] Document RTTI / TypeInfo minimum truth and what remains compiler-owned.
- [ ] Document unit initialization/finalization ordering and failure behavior.
- [ ] Add source-contract tests for `np.system.unit_init`, `np.system.unit_fini` and runtime-fault classification.

## S4 SysUtils / TypInfo / Classes Compatibility Facades

- [ ] Decide which compatibility surfaces deserve `system.*` facade units.
- [ ] Add only tested aliases or forwarding functions; no broad historical copy.
- [ ] Keep filesystem, time, IO, math, text and collection implementation ownership in their existing modules.
- [ ] Report `Needs Review` before exposing compatibility API with wide consumer impact.

## S5 Compiler / Runtime Integration Readiness

- [ ] Align facade docs with compiler runtime contract names and source-backed `System` truth.
- [ ] Prove runtime helper references are explicit, stable and not backend-private magic strings.
- [ ] Add integration smoke once compiler/runtime can consume the core-system contract directly.
- [ ] Prepare a landing candidate only after focused gates and cross-module risks are clean.
