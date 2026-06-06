# Math Final API Migration Implementation Plan

> Target branch: `codex/core-math`

## Goal

Move reusable math capability from `fafafa.game` into `nextpas.core` and make `nextpas.core.math.*` the only official framework math API.

## Architecture

The migration is final-API-first and tests-first. `fafafa.game` is a semantic reference, not a codebase to copy. SIMD is an implementation seam through `nextpas.core.simd`, and trig must be platform-safe without a public naked `external 'm'` binding.

## Hard Boundaries

- Do not touch compiler files, compiler worktrees, or compiler branches.
- Do not work on dirty `main`; use the isolated worktree for this lane.
- Do not preserve `fafafa.game` `Vectors` as a public final API.
- Do not copy `VectorsSIMD.pas` into core.
- Do not let `nextpas.core.math.ffi.pas` remain a public naked `external 'm'` binding.
- Do not claim completion for any public API without unit tests and leak evidence.

## Commit Plan

Each task below should close with a path-limited commit.

### Task 0: Control And Design

Files:

- Create: `docs/math/GOAL_TREE.md`
- Create: `docs/math/FINAL_API_MIGRATION_DESIGN.md`
- Create: `docs/plans/2026-06-06-math-final-api-migration.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

Steps:

- [ ] Record the math goal tree and current roadmap position.
- [ ] Record the final API architecture and rejected approaches.
- [ ] Record implementation tasks, commit order, and verification gates.
- [ ] Run `git diff --check`.
- [ ] Commit with `docs(math): plan final api migration`.

Expected result:

- Design and plan are committed.
- No math implementation has changed.

### Task 1: RED Final API Tests And Surface Contracts

Files:

- Create: `tests/nextpas.core.math/Makefile`
- Create: `tests/nextpas.core.math/test_api_surface/test_api_surface.py`
- Create: `tests/nextpas.core.math/test_api_surface/Makefile`
- Create: `tests/nextpas.core.math/test_facade/test_facade.lpr`
- Create: `tests/nextpas.core.math/test_scalar/test_scalar.lpr`
- Modify: existing `tests/nextpas.core.math/test_trig/test_trig.lpr`
- Create: `tests/nextpas.core.math/test_vec/test_vec.lpr`
- Create: `tests/nextpas.core.math/test_mat/test_mat.lpr`
- Create: `tests/nextpas.core.math/test_quat/test_quat.lpr`
- Create: `tests/nextpas.core.math/test_transform/test_transform.lpr`
- Create: `tests/nextpas.core.math/test_easing/test_easing.lpr`
- Create: `tests/nextpas.core.math/test_random/test_random.lpr`
- Create: `tests/nextpas.core.math/test_noise/test_noise.lpr`

Steps:

- [ ] Resolve and document pre-implementation policy choices: constructor names, singular `Inverse`, zero normalize, random invalid inputs, facade re-export breadth, and whether `TTransform3f/TTransform3d` is in the first cut.
- [ ] Write scalar/trig tests for constants, `Min`, `Max`, `Clamp`, `Lerp`, `Floor`, `Ceil`, `Sqrt`, `Sin`, `Cos`, `Tan`, `Power`, and degree/radian conversion.
- [ ] Write facade-only tests that `uses nextpas.core.math` and calls canonical final APIs without importing implementation units.
- [ ] Write Vec tests for final type names and operators.
- [ ] Write Mat tests for column-major identity/zero/multiply/inverse behavior.
- [ ] Write Quat tests for identity, axis-angle, rotation matrix, rotate, slerp, and nlerp.
- [ ] Write Transform tests with known matrices and transformed vectors.
- [ ] Write Easing tests for every public function.
- [x] Write Random/Noise tests for seed determinism, boundaries, and invalid inputs.
- [ ] Write surface tests that reject `nextpas.core.math.ffi`, naked `external 'm'`, public `Vectors` names, public `uses nextpas.core.math.impl.*`, backend-private SIMD dependencies, and untested public symbols.
- [ ] Run each test project and confirm RED failures only because final API does not exist.
- [ ] Commit with `test(math): lock final api contracts`.

Expected result:

- RED tests define the final public API.
- Surface test protects against the banned bridge/FFI shapes.

### Task 2: Scalar And Trig Foundation

Files:

- Modify: `src/nextpas.core.math.pas`
- Create: `src/nextpas.core.math.scalar.pas`
- Modify: `src/nextpas.core.math.trig.pas`
- Create: `src/nextpas.core.math.impl.scalar.pas`
- Delete or deprecate: `src/nextpas.core.math.ffi.pas`
- Modify: platform helper files only if trig needs host-owned helpers.

Steps:

- [ ] Move scalar helpers into `nextpas.core.math.scalar`.
- [ ] Keep `nextpas.core.math` as explicit facade/re-export.
- [ ] Remove `test_trig` dependency on `nextpas.core.math.ffi`.
- [ ] Route trig through safe scalar/platform implementation.
- [ ] Do not delete `math.ffi` before the RED surface test proves the new boundary; deprecate or delete only after all public/test consumers are removed.
- [ ] Ensure no source contains `external 'm'` under `nextpas.core.math*`.
- [ ] Run local Linux trig/facade link tests; record macOS/Windows host link-smoke status or explicitly mark final cross-platform completion as blocked.
- [ ] Run scalar/trig/surface tests with heaptrc.
- [ ] Commit with `feat(math): add scalar and safe trig foundation`.

Expected result:

- `math.ffi` is gone or inert and blocked from public use.
- Scalar/trig tests pass.

### Task 3: Vec Final Types

Files:

- Create: `src/nextpas.core.math.vec.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_vec/test_vec.lpr`

Steps:

- [x] Implement `TVec2f`, `TVec3f`, `TVec4f`.
- [x] Implement `TVec2d`, `TVec3d`, `TVec4d`.
- [x] Implement final operators and methods.
- [x] Implement component multiply/divide as explicit `MulComponents` and `DivComponents` unless final RED tests intentionally lock Hadamard vector `*`/`/`.
- [x] Define and test zero normalize behavior.
- [x] Run `test_vec` and `test_api_surface`.
- [x] Commit with `feat(math): add final vector types`.

Expected result:

- Final vector API passes all required vector behavior tests.

### Task 4: Mat Final Types

Files:

- Create: `src/nextpas.core.math.mat.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_mat/test_mat.lpr`

Steps:

- [x] Implement `TMat3f`, `TMat4f`, `TMat3d`, `TMat4d`.
- [x] Preserve column-major `Data[column, row]`.
- [x] Implement matrix/vector and matrix/matrix multiply.
- [x] Implement determinant, inverse, try-inverse, transpose, identity, zero.
- [x] Run `test_mat` and `test_api_surface`.
- [x] Commit with `feat(math): add final matrix types`.

Expected result:

- Matrix conventions and singular inverse behavior are locked by tests.
- `nextpas.core.math.mat` is intentionally kept as one cohesive matrix value-type unit for this slice;
  it exceeds the 800-line soft split guideline, but common inversion/determinant helpers are already
  extracted and a forced split is deferred until a later maintainability slice has evidence.

### Task 5: Quat Final Types

Files:

- Create: `src/nextpas.core.math.quat.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_quat/test_quat.lpr`

Steps:

- [x] Implement `TQuatf` and `TQuatd`.
- [x] Implement identity, normalize, conjugate, multiply.
- [x] Implement axis-angle, rotation matrix, rotate, slerp, nlerp.
- [x] Run `test_quat`, `test_mat`, and `test_api_surface`.
- [x] Commit with `feat(math): add final quaternion types`.

Expected result:

- Quaternion API passes behavior tests and integrates with matrix/vector types.

### Task 6: Transform Builders

Files:

- Create: `src/nextpas.core.math.transform.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_transform/test_transform.lpr`

Steps:

- [x] Implement `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`, `RotateX`, `RotateY`, `RotateZ`, `Camera2D`.
- [x] Use final vec/mat types only.
- [x] Test known transformed points and matrix elements.
- [x] Run `test_transform`, `test_mat`, `test_vec`, and `test_api_surface`.
- [x] Commit with `feat(math): add transform builders`.

Expected result:

- Transform conventions are documented by tests.

### Task 7: Easing

Files:

- Create: `src/nextpas.core.math.easing.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_easing/test_easing.lpr`

Steps:

- [x] Implement every easing function from the final public list.
- [x] Depend on `nextpas.core.math.trig`, not FPC `Math`.
- [x] Test endpoints and representative midpoints.
- [x] Run `test_easing`, `test_trig`, and `test_api_surface`.
- [x] Commit with `feat(math): add easing functions`.

Expected result:

- All public easing functions are covered and pass.

### Task 8: Random And Noise

Files:

- Create: `src/nextpas.core.math.random.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_random/test_random.lpr`
- Modify: `tests/nextpas.core.math/test_noise/test_noise.lpr`

Steps:

- [x] Implement deterministic random state.
- [x] Implement range, bool, gaussian, circle, dice, weighted choice, shuffle.
- [x] Implement deterministic noise and FBM.
- [x] Avoid global heap-owned public singletons.
- [x] Test invalid input behavior and object release under heaptrc.
- [x] Run `make -C core/tests/nextpas.core.math/test_random clean test`.
- [x] Run `make -C core/tests/nextpas.core.math/test_noise clean test`.
- [x] Run `make -C core/tests/nextpas.core.math/test_api_surface clean test`.
- [x] Commit with `feat(math): add deterministic random and noise`.

Expected result:

- Random/noise behavior is deterministic and leak-free.
- `nextpas.core.math.random` exposes `TRandomState`, `TRandomGen`, and `TNoiseGen` with explicit
  ownership and no public global singleton.

### Task 9: SIMD Implementation Seam

Files:

- Create: `src/nextpas.core.math.impl.simd.pas`
- Modify: `src/nextpas.core.math.vec.pas`, `mat.pas`, or `quat.pas` only if tests justify acceleration.
- Modify or add `nextpas.core.simd` files only for missing public primitives.
- Create: `tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr`
- Modify: `tests/nextpas.core.math/test_api_surface/test_api_surface.py`
- Add matching SIMD tests if new primitives are added.

Steps:

- [x] Identify an initial public-SIMD-safe helper seam: `TVec4f` add/sub/component-multiply/scale,
  dot, length, and `TVec3f` dot/cross.
- [x] Use only `nextpas.core.simd` public APIs such as `VecF32x4*`, `Array*`, and public utility functions.
- [x] Do not call `nextpas.core.simd.direct`, `GetDirectDispatchTable`, dispatch internals, dataplane internals, or backend-private units.
- [x] Add source-contract coverage requiring the internal seam file and declarations.
- [x] Add internal helper behavior coverage in `test_impl_simd`.
- [x] Add no new SIMD primitives; existing public `VecF32x4*` primitives were sufficient for this slice.
- [x] Run full math tests plus relevant SIMD tests.
- [x] Commit the internal helper seam; no public math acceleration was wired in this slice.
- [x] Add `bench_simd_seam` as a local Linux benchmark harness for scalar-vs-internal-seam evidence.
- [x] Run the benchmark with `NEXTPAS_BENCH_MAX_ITERS=20000`; current public-facade SIMD seam is slower
  than scalar public vector methods for the measured helpers, so public `TVec*` routing remains
  intentionally unwired.
- [x] Extend `bench_simd_seam` with scalar-only baselines for broader M7 candidates
  (`TMat4f * TVec4f`, `TMat4f * TMat4f`, and `TQuatf.Rotate`) and protect those benchmark labels in
  `test_api_surface`.

Expected result:

- SIMD acceleration is optional, tested, and not a public math API dependency.
- Current status is an internal helper seam only; public math value types still run their scalar paths
  until a later profiling-backed acceleration slice wires them intentionally. The first local
  benchmark result is negative evidence for wiring the current seam shape directly into public
  vector methods.

### Task 10: Documentation And Closeout Gates

Files:

- Create: `docs/math/README.md`
- Create: `docs/math/API.md`
- Update: `docs/math/FINAL_API_MIGRATION_DESIGN.md`
- Update: `docs/math/GOAL_TREE.md`
- Update: `task_plan.md`, `findings.md`, `progress.md`

Steps:

- [x] Document public modules and conventions.
- [x] Document grouped public API reference.
- [x] Run all `tests/nextpas.core.math` projects on the local Linux gate.
- [x] Run API surface checker.
- [x] Run heaptrc checks and record local zero-leak evidence.
- [x] Run `git diff --check`.
- [x] Review `docs/math/API.md` and `docs/math/README.md` against current public declarations.
- [x] Commit current documentation and local gate evidence.
- [x] Add a facade-only overview example and run its focused compile/run gate.
- [x] Re-audit root facade constants, public type aliases, and public function names against
  `docs/math/API.md`.
- [x] Add an automated `test_api_surface` rule that fails when root facade API names are missing from
  `docs/math/API.md`; RED was verified by removing `Fmod` in a temporary copy.

Expected result:

- Public docs explain the current module API and conventions.
- Math is not ready for `fafafa.game` cutover until M7 acceleration decisions and host trig link
  evidence are closed.

### Task 11: fafafa.game Cutover

Files:

- Use a separate `fafafa.game` worktree.
- Do not change `lib/nextpas-core` symlink unless explicitly approved.
- Replace public `Vectors` usage with `nextpas.core.math.*`.
- Delete or internalize old `Vectors` public surface.

Steps:

- [ ] Recheck `fafafa.game` git/worktree status.
- [ ] Use `NEXTPAS_CORE_DIR` override to point at the math branch.
- [ ] Convert call sites to final type names and modules.
- [ ] Remove public `Vectors` exports or lower them to internal temporary wrappers.
- [ ] Run focused bridge/cutover smokes, leak checks, API freeze checks, and docs checks.
- [ ] Commit in `fafafa.game`.

Expected result:

- `fafafa.game` consumes final `nextpas.core.math.*` and no longer exposes old `Vectors` as public API.

## Verification Cadence

Per implementation task:

```sh
git status --short --branch
make -C tests/nextpas.core.math/<test_project> clean test
git diff --check
git status --short --branch
```

For allocation-bearing tests, heaptrc output must show:

```text
0 unfreed memory blocks
```

Full math closeout:

```sh
make -C tests/nextpas.core.math clean test
make -C tests/nextpas.core.math/test_api_surface clean test
git diff --check
git status --short --branch
```

Trig final closeout additionally requires:

```sh
make -C tests/nextpas.core.math/test_trig clean test
make -C tests/nextpas.core.math/test_facade clean test
```

Linux runs locally. macOS/Windows must run equivalent host link smokes before trig is marked complete. If they are unavailable, report them as pending blockers.

## Benchmark Policy

Do not start final benchmarks until all public APIs pass behavior tests, API surface checks, and leak checks.

Final benchmark phase should compare:

- scalar nextPas math
- SIMD nextPas math where available
- FPC RTL equivalents where meaningful
- Go and Rust reference implementations for public benchmark data or local harnesses

Benchmark commits must remain separate from correctness/API commits.
