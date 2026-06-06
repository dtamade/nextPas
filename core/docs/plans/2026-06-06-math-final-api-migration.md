# Math Final API Migration Implementation Plan

> Target branch: `codex/math-final-api-20260606`

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
- [ ] Write Random/Noise tests for seed determinism, boundaries, and invalid inputs.
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
- [ ] Commit with `feat(math): add final matrix types`.

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

- [ ] Implement `TQuatf` and `TQuatd`.
- [ ] Implement identity, normalize, conjugate, multiply.
- [ ] Implement axis-angle, rotation matrix, rotate, slerp, nlerp.
- [ ] Run `test_quat`, `test_mat`, and `test_api_surface`.
- [ ] Commit with `feat(math): add final quaternion types`.

Expected result:

- Quaternion API passes behavior tests and integrates with matrix/vector types.

### Task 6: Transform Builders

Files:

- Create: `src/nextpas.core.math.transform.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_transform/test_transform.lpr`

Steps:

- [ ] Implement `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`, `RotateX`, `RotateY`, `RotateZ`, `Camera2D`.
- [ ] Use final vec/mat types only.
- [ ] Test known transformed points and matrix elements.
- [ ] Run `test_transform`, `test_mat`, `test_vec`, and `test_api_surface`.
- [ ] Commit with `feat(math): add transform builders`.

Expected result:

- Transform conventions are documented by tests.

### Task 7: Easing

Files:

- Create: `src/nextpas.core.math.easing.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_easing/test_easing.lpr`

Steps:

- [ ] Implement every easing function from the final public list.
- [ ] Depend on `nextpas.core.math.trig`, not FPC `Math`.
- [ ] Test endpoints and representative midpoints.
- [ ] Run `test_easing`, `test_trig`, and `test_api_surface`.
- [ ] Commit with `feat(math): add easing functions`.

Expected result:

- All public easing functions are covered and pass.

### Task 8: Random And Noise

Files:

- Create: `src/nextpas.core.math.random.pas`
- Modify: `src/nextpas.core.math.pas`
- Modify: `tests/nextpas.core.math/test_random/test_random.lpr`
- Modify: `tests/nextpas.core.math/test_noise/test_noise.lpr`

Steps:

- [ ] Implement deterministic random state.
- [ ] Implement range, bool, gaussian, circle, dice, weighted choice, shuffle.
- [ ] Implement deterministic noise and FBM.
- [ ] Avoid global heap-owned public singletons.
- [ ] Test invalid input behavior and object release under heaptrc.
- [ ] Run `make -C tests/nextpas.core.math/test_random clean test`.
- [ ] Run `make -C tests/nextpas.core.math/test_noise clean test`.
- [ ] Run `make -C tests/nextpas.core.math/test_api_surface clean test`.
- [ ] Commit with `feat(math): add deterministic random and noise`.

Expected result:

- Random/noise behavior is deterministic and leak-free.

### Task 9: SIMD Implementation Seam

Files:

- Create: `src/nextpas.core.math.impl.simd.pas`
- Modify: `src/nextpas.core.math.vec.pas`, `mat.pas`, or `quat.pas` only if tests justify acceleration.
- Modify or add `nextpas.core.simd` files only for missing public primitives.
- Add matching SIMD tests if new primitives are added.

Steps:

- [ ] Identify scalar-hot operations worth accelerating.
- [ ] Use only `nextpas.core.simd` public APIs such as `VecF32x4*`, `Array*`, and public utility functions.
- [ ] Do not call `nextpas.core.simd.direct`, `GetDirectDispatchTable`, dispatch internals, dataplane internals, or backend-private units.
- [ ] Add missing SIMD primitives with dedicated SIMD tests before math consumes them.
- [ ] Run math tests plus relevant SIMD tests.
- [ ] Commit with a precise message for each primitive or math acceleration.

Expected result:

- SIMD acceleration is optional, tested, and not a public math API dependency.

### Task 10: Documentation And Closeout Gates

Files:

- Create: `docs/math/README.md`
- Update: `docs/math/FINAL_API_MIGRATION_DESIGN.md`
- Update: `docs/math/GOAL_TREE.md`
- Update: `task_plan.md`, `findings.md`, `progress.md`

Steps:

- [ ] Document public modules and conventions.
- [ ] Run all `tests/nextpas.core.math` projects.
- [ ] Run API surface checker.
- [ ] Run heaptrc checks and record evidence.
- [ ] Run `git diff --check`.
- [ ] Commit with `docs(math): document final api`.

Expected result:

- Math module is ready for `fafafa.game` cutover.

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
