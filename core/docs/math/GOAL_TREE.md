# nextpas.core.math Goal Tree

> Last updated: 2026-06-07
> Goal: make `nextpas.core.math.*` the only official framework math API for scalar math, trig, vectors, matrices, quaternions, transforms, easing, random, and noise.

## North Star

`nextpas.core.math` should become the Free Pascal ecosystem's best general-purpose framework math layer:

- Correct first: every public API has behavior tests before it is considered complete.
- Final API first: no long-term dependency on `fafafa.game` `Vectors` or compatibility bridge names.
- Cross-platform: trig must not fail to link on Linux, macOS, or Windows because of a naked `external 'm'`.
- Framework-owned: SIMD acceleration uses `nextpas.core.simd` public surfaces only.
- Maintainable: each module owns one clear responsibility and follows `docs/design-conventions.md`.
- Verifiable: every implementation batch closes with focused tests, API surface checks, heaptrc leak evidence, and a small commit.

## Current Position

This branch has completed the current **M7 internal SIMD seam slice** and should continue toward M8/M9 work.

- M0 design/control is committed as `21e1f510 docs(math): plan final api migration`.
- Earlier slices added scalar/trig/facade/symbol-scope tests and the final vector types.
- `nextpas.core.math.scalar` and `nextpas.core.math.impl.scalar` now exist.
- `nextpas.core.math` is now a scalar/trig facade.
- `nextpas.core.math.trig` no longer depends on `nextpas.core.math.ffi`.
- `nextpas.core.math.ffi.pas` is deleted in this branch.
- `nextpas.core.simd.mathutil` no longer exports common bare math-compatible helper names.
- Added scalar `Single` overloads, `GCD`, `LCM`, `Hypot`, `Fmod`, `SmoothStep`, guarded `Abs(Low(...))`, and IEEE-style `SimdLnF32` boundaries.
- Edge-case fixes are locked by tests for exact owner-level integer conversion and integer-boundary
  messages across `Floor` / `Ceil` / `Round` / `Trunc` / `Frac`, including direct
  `Single` fail-fast parity for the conversion-boundary message families, `GCD` / `LCM`,
  `Abs(Low(...))`, `Hypot(+Inf,+Inf)`, trig NaN/out-of-domain/double-infinity cases plus direct
  `Log2` / `Log10` coverage, selected missing `Single`-path trig parity, and `Power`
  negative-base / zero-base edge semantics, and `SimdLnF32(NaN)`.
- `nextpas.core.math.mat` now provides the final matrix types: `TMat3f`, `TMat4f`, `TMat3d`, and `TMat4d`.
- Matrix tests cover compact layout, column-major `Data[column,row]`, `Items`, `Rows`, `Columns`,
  row/column setter write-through semantics over the same backing storage, `Zero`, `Identity`,
  arithmetic operators, scalar multiply, matrix-vector multiply, matrix-matrix multiply,
  `Transpose`, `Determinant`, `TryInverse`, `Inverse`, exact/epsilon `Equals`, and singular inverse
  behavior, including zeroing the failed `TryInverse` out matrix and directly locking the exact
  owner-level `Inverse` singular-matrix messages for `TMat3f`, `TMat4f`, `TMat3d`, and `TMat4d`.
- `nextpas.core.math.quat` now provides the final quaternion types: `TQuatf` and `TQuatd`.
- Quaternion tests cover compact layout, `Create`, `Identity`, `Data`, zero normalize returning
  identity, zero-quaternion `ToRotationMatrix` / `Rotate` identity behavior, `Conjugate`,
  `FromAxisAngle` axis normalization and zero-axis identity behavior,
  `ToAxisAngle` canonical shortest-angle output including zero-rotation `+Z` fallback, exact
  half-turn stable-axis canonicalization including `FromAxisAngle(..., PI)` paths, and scaled-input normalization, scaled-input
  normalization for `ToRotationMatrix` and `Rotate`, quaternion multiply, `Slerp`, `Nlerp`,
  shortest-path handling for opposite-sign equivalent interpolation endpoints including direct
  start/end midpoint parity plus endpoint canonicalization, finite-guard parameter-position parity
  across `AAxis`, `AAngleRad`, and `AT`, zero-endpoint interpolation normalization, `Equals`, and
  direct `TQuatd` parity coverage for `Create`, `Data`, `Conjugate`, `ToRotationMatrix`,
  quaternion multiply composition, and `Nlerp` midpoint.
- Vector tests now also have direct `Double`-path parity coverage for `Data` aliases, `Zero`,
  add/subtract/unary minus, scalar multiply left, and representative length/component-multiply
  contracts.
- `nextpas.core.math.transform` now provides projection, view, model, and 2D camera builders for
  both `TMat4f` and `TMat4d`.
- Transform tests cover `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`, `RotateX`,
  `RotateY`, `RotateZ`, `Camera2D`, facade exposure, invalid dimensions, composition order, exact
  owner-level `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`, `Rotate*`, and `Camera2D`
  guard messages, direct `Double`-path parity for projection/view/model/camera builders, and
  direct `Single` / `Double` parity coverage across the public guard-message families, including
  `Scale(Double)` Y-axis finite guard parity, `LookAt` up-direction roll parity,
  `Camera2D` zoom-scaled view semantics, and `Camera2D` zero/negative zoom parity.
- `nextpas.core.math.easing` now provides `TEasingFunction` and the final `Ease*` function family.
- Easing tests cover every public easing function with endpoints, representative midpoint/branch
  points, direct `EaseOutBounce` piecewise-branch coverage, finite out-of-range extrapolation,
  NaN/Inf rejection, and exact owner-level
  `Ease*: T must be finite` messages, and the surface checker rejects direct FPC `Math` usage in
  the easing unit.
- `nextpas.core.math.random` now provides explicit-state `TRandomGen`, `TRandomState`, and
  `TNoiseGen`.
- Random tests cover deterministic seed vectors, state restore, range boundaries, invalid ranges,
  owner-level reversed-range and non-finite-range messages, probability clamp, dice rules,
  `RollMultiple` integer-overflow owner boundary, weighted choice including empty/negative and
  non-finite owner-level messages, shuffle, Gaussian, and unit-circle vector helpers.
- Noise tests cover deterministic permutation repeatability, 1D/2D/3D reference vectors, FBM
  reference vectors, invalid FBM octave/lacunarity/gain inputs with exact owner-level message
  variants across `FBM1D/2D/3D`, negative-fractional coordinate canonicalization across the
  256-periodic seam, finite-combination overflow contracts for coordinates, amplitudes, and
  accumulated results, precision-ceiling stored-value semantics, and
  heaptrc-clean object ownership.
- The public surface checker requires the random/noise declarations and rejects public global
  random/noise singleton variables.
- `nextpas.core.math.impl.simd` now exists as an internal implementation seam for selected
  `TVec3f`/`TVec4f` helpers plus candidate `TMat4f * TVec4f` and `TQuatf.Rotate` helpers. It uses
  only the public `nextpas.core.simd` facade and is not wired into public math value-type methods
  yet.
- `test_impl_simd` validates the internal helper seam, including the candidate `TMat4f * TVec4f`
  path and a `TQuatf.Rotate` helper that matches public rotate semantics for non-unit quaternions,
  and `test_api_surface` keeps public
  consumers/docs/tests from importing `nextpas.core.math.impl.*`.
- `bench_simd_seam` records local scalar-vs-SIMD-seam evidence for `TVec3f`/`TVec4f` helpers without
  routing public value-type methods through the seam, and now also includes a candidate internal
  `TMat4f * TVec4f` seam plus scalar baselines for broader M7 candidates (`TMat4f * TMat4f` and
  `TQuatf.Rotate`) and a measured candidate `TQuatf.Rotate` seam.
- `math_overview` now provides a facade-only public example that compiles and runs without importing
  narrower math submodules or implementation-only units.
- Linux-focused math/SIMD tests pass locally; macOS/Windows trig link smokes remain a later host-gate requirement before final cross-platform completion.

## Map

```text
nextpas.core.math final migration
├── M0: Control, design, and audit                       [complete]
├── M1: RED behavior tests for final API                 [complete for current final API scope]
├── M2: Scalar + trig foundation                         [partial: scalar/trig Linux local gate passed]
├── M3: Vec/Mat/Quat value types                         [complete]
├── M4: Transform builders                               [complete]
├── M5: Easing                                           [complete]
├── M6: Random + noise                                   [complete]
├── M7: SIMD-backed implementation seams                 [partial: internal seam + local benchmark evidence]
├── M8: API surface, docs, leak proof, and module gates   [partial: docs, local Linux gates, API/docs review]
└── M9: fafafa.game cutover and old Vectors retirement    [not started]
```

## M0: Control, Design, And Audit

Goal: establish the target architecture, migration boundaries, test gates, and task order before implementation.

Deliverables:

- `docs/math/FINAL_API_MIGRATION_DESIGN.md`
- `docs/plans/2026-06-06-math-final-api-migration.md`
- `task_plan.md`, `findings.md`, and `progress.md` updated for this lane.

Completion gate:

- Design and plan files exist.
- `git diff --check` passes.
- This branch has a design-only commit.

Status:

- Complete in commit `21e1f510 docs(math): plan final api migration`.

## M1: RED Behavior Tests For Final API

Goal: lock the final public API before implementation.

Test projects:

- `tests/nextpas.core.math/test_api_surface`
- `tests/nextpas.core.math/test_facade`
- `tests/nextpas.core.math/test_scalar`
- `tests/nextpas.core.math/test_trig`
- `tests/nextpas.core.math/test_vec`
- `tests/nextpas.core.math/test_mat`
- `tests/nextpas.core.math/test_quat`
- `tests/nextpas.core.math/test_transform`
- `tests/nextpas.core.math/test_easing`
- `tests/nextpas.core.math/test_random`
- `tests/nextpas.core.math/test_noise`

Completion gate:

- Tests compile or fail only because the new final API does not exist yet.
- Each public function/type required by the target design has at least one contract test.
- `test_api_surface` rejects `nextpas.core.math.ffi`, naked `external 'm'`, public `Vectors`
  bridge names, public symbols that lack matching behavior tests, and missing required behavior-test
  runner markers for the current public API groups.
- `test_facade` proves a consumer can `uses nextpas.core.math` and call the canonical final API without importing implementation or legacy bridge units.

Status:

- Complete for current final API behavior-test scope. This slice covers API surface, facade, scalar,
  trig, symbol-scope, vec, mat, quat, transform, easing, random, and noise tests.

## M2: Scalar + Trig Foundation

Goal: make `nextpas.core.math` and `nextpas.core.math.trig` safe framework-owned foundations.

Target files:

- `src/nextpas.core.math.pas`
- `src/nextpas.core.math.scalar.pas`
- `src/nextpas.core.math.trig.pas`
- `src/nextpas.core.math.impl.scalar.pas`
- platform-owned trig helpers as needed

Completion gate:

- No public `nextpas.core.math.ffi` dependency remains.
- Trig links on Linux/macOS/Windows route without naked `external 'm'`.
- Scalar and trig tests pass with heaptrc `0 unfreed memory blocks`.

Status:

- Partial. Linux local scalar/trig/facade/symbol-scope tests pass with heaptrc `0 unfreed memory blocks`,
  and `core/Makefile` now exposes `core-math-facade-local-smoke`,
  `core-math-symbol-scope-local-smoke`, plus a `core-math-trig-local-smoke` path that reuses the
  facade gate for the repeatable current-host proof path.
- `nextpas.core.math.ffi.pas` is deleted in this branch.
- API surface checks reject naked `external 'm'`, public/test `math.ffi` consumers, public impl consumers, and legacy vector bridge names.
- macOS/Windows host link smokes are not run in this local round.
- Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.

## M3: Vec/Mat/Quat Value Types

Goal: provide final public value types:

- `TVec2f`, `TVec3f`, `TVec4f`
- `TMat3f`, `TMat4f`
- `TQuatf`
- `TVec2d`, `TVec3d`, `TVec4d`
- `TMat3d`, `TMat4d`
- `TQuatd`

Completion gate:

- Vec/Mat/Quat tests cover every public constructor, operator, and method.
- Singular matrix inversion uses a documented `TryInverse` path, zeroes the failed out matrix, and
  does not return silent garbage.
- Normalize of zero vectors/quaternions is explicitly defined and tested.

Status:

- Complete for the current final Vec/Mat/Quat value-type scope. `nextpas.core.math.vec` now provides
  `TVec2f`, `TVec3f`, `TVec4f`, `TVec2d`,
  `TVec3d`, and `TVec4d`.
- Vector tests cover compact layout, `Create`, `Zero`, arithmetic operators, explicit
  component multiply/divide, `Dot`, `Cross` for 3D vectors, `Length`, `LengthSqr`,
  `Normalize`, `Lerp`, `Equals`, zero-vector normalize returning zero, and direct `Double`-path
  parity coverage for `Data` aliases, `Zero`, add/subtract/unary minus, scalar multiply left, and
  representative length/component-multiply contracts.
- Facade tests prove consumers can `uses nextpas.core.math` and call the final vector types.
- Matrix tests cover compact layout, column-major storage, row/column accessors, row/column setter
  write-through semantics, arithmetic operators, scalar multiply, matrix-vector multiply,
  matrix-matrix multiply, transpose, determinant, inverse, near-singular and singular `TryInverse`
  zeroing the out matrix, direct pivot-row-swap inversion parity for permutation matrices, 4x4
  determinant sign parity across the same row-swap path, exact/epsilon `Equals` including
  negative-epsilon fail-close behavior, `Inverse` raising `EArgumentError` with exact owner-level
  `'<TMat*>.Inverse: matrix is singular'` messages for the same failure cases, and double-precision
  variants.
- `nextpas.core.math.mat` is a cohesive matrix value-type unit and currently exceeds the 800-line soft
  split guideline; shared inversion/determinant helpers are extracted, and a forced split is deferred
  until a later architecture slice has evidence that it improves maintainability without widening the
  public API boundary.
- `nextpas.core.math.quat` now provides `TQuatf` and `TQuatd`.
- Quaternion tests cover compact layout, `Create`, `Identity`, `Data`, zero normalize returning
  identity, zero-quaternion `ToRotationMatrix` / `Rotate` identity behavior, `Conjugate`,
  axis-angle roundtrip, axis normalization, zero-axis identity behavior,
  `ToAxisAngle` canonical shortest-angle output including zero-rotation `+Z` fallback, direct
  `±3π/2` multi-turn canonicalization, exact half-turn stable-axis canonicalization across
  `x/y/z` axes plus `FromAxisAngle(..., PI)` half-turn paths, and
  scaled-input normalization, scaled-input normalization for rotation matrix conversion and vector
  rotation, quaternion multiply composition,
  `Slerp`, `Nlerp`, shortest-path handling for opposite-sign equivalent interpolation endpoints
  including direct start/end midpoint parity plus endpoint canonicalization, finite out-of-range
  extrapolation, stable degenerate interpolation for identical, scaled-equivalent, and
  opposite-sign equivalent endpoints, finite-guard parameter-position parity across
  `FromAxisAngle(AAxis, AAngleRad)` and `Slerp`/`Nlerp(AT)`, interpolation endpoint
  normalization/canonicalization including zero endpoints, component-wise `Equals` semantics
  including non-canonical opposite-sign behavior and negative epsilon rejection, and direct
  `TQuatd` parity coverage for `Create`, `Data`, `Conjugate`, `ToRotationMatrix`, quaternion
  multiply composition, and `Nlerp` midpoint.
- M3 is complete for current final Vec/Mat/Quat value-type scope.

## M4: Transform Builders

Goal: provide transform builders under `nextpas.core.math.transform`.

Completion gate:

- Ortho, Perspective, LookAt, Translate, Scale, RotateX/Y/Z, and Camera2D are tested against known vectors/matrices.
- Matrix convention is documented and source tests verify column-major layout.

Status:

- Complete for the current builder scope.
- `nextpas.core.math.transform` provides `Single` and `Double` overloads for `Ortho`, `Perspective`,
  `LookAt`, `Translate`, `Scale`, `RotateX`, `RotateY`, `RotateZ`, and `Camera2D`.
- Tests lock column-major translation in column 3, right-handed `LookAt`, right-handed perspective
  with NDC `[-1,+1]`, direct `Ortho` reversed-bounds axis flips, direct `Double` parity coverage
  for `Perspective`, `LookAt`, `Translate`, `Scale`, `RotateX`, `RotateY`, `RotateZ`, and
  `Camera2D`, `LookAt` up-vector magnitude invariance for the same direction plus direct
  `AUp` sign-flip roll semantics, screen-space `Camera2D` positive Y down plus zoom-scaled view
  semantics across both axes, geometry guard messages for degenerate `Ortho` / `Perspective` /
  `LookAt` / `Camera2D` inputs, exact
  owner-level `Ortho` finite and zero-extent guard messages, exact owner-level
  `Perspective` finite/positive parameter guard messages including direct negative
  FOV/aspect/near parity plus the
  `Perspective: vertical FOV is invalid` contract and direct far-plane ordering parity for
  `far = near` and `far < near`, exact owner-level finite guard messages for `LookAt`
  eye/target/up inputs plus `Translate` / `Scale` axis inputs, `RotateX/Y/Z` radian inputs, and
  `Camera2D` center/zoom finite inputs plus positive-zoom validation for zero and negative zoom,
  with direct `Single` / `Double` parity coverage across those public guard-message families,
  including `Scale(Double)` Y-axis finite guard parity, invalid projection inputs, and
  `Translate * Rotate * Scale` local composition.

## M5: Easing

Goal: migrate easing functions into `nextpas.core.math.easing`.

Completion gate:

- Every public easing function has endpoint and representative midpoint tests.
- Finite inputs outside `[0, 1]` have explicit documented/tested behavior instead of implicit
  clamping assumptions.
- Functions use `nextpas.core.math.trig`/scalar helpers, not FPC `Math`.

Status:

- Complete for the current final public easing scope.
- `nextpas.core.math.easing` provides `TEasingFunction`, `EaseLinear`, Quad/Cubic/Quart,
  Expo, Elastic, Back, and Bounce variants.
- `test_easing` locks endpoints, midpoints, representative `InOut*` branch points, direct
  `EaseOutBounce` piecewise-branch coverage, finite out-of-range extrapolation, NaN/Inf
  rejection, and exact owner-level
  `Ease*: T must be finite` messages; `test_facade` proves root facade exposure.
- `test_api_surface` rejects a direct `uses Math` dependency in `nextpas.core.math.easing.pas`.

## M6: Random + Noise

Goal: provide deterministic RNG and noise APIs under `nextpas.core.math.random`.

Completion gate:

- Seed determinism, range boundaries, invalid ranges, probability clamps, dice rules, weighted choice, shuffle, and noise repeatability are tested.
- No global heap-owned random/noise singletons are part of the public API.
- Heaptrc confirms object lifetimes are clean.

Status:

- Complete for the current final public random/noise scope.
- `nextpas.core.math.random` provides `TRandomState`, `TRandomGen`, and `TNoiseGen`.
- `TRandomGen` owns xoroshiro-style deterministic state explicitly. It covers `NextInt`,
  integer/float ranges, `NextFloat`, `NextDouble`, `NextBool`, `NextGaussian`,
  `NextVec2InCircle`, `NextVec2OnCircle`, dice helpers, weighted choice, shuffle, and state
  restore.
- Invalid integer/float ranges fail fast with `EArgumentError`; `NextBool` clamps probability into
  false/true behavior; dice helpers return `0` for non-positive dice/sides; `RollMultiple`
  rejects positive dice/side combinations whose maximum total would overflow `Integer`;
  `NextGaussian` clamps a zero-state first uniform draw back to a finite deterministic fallback;
  `test_random` now directly locks owner-level messages for reversed and non-finite integer/float
  range validation, direct zero/negative dice parity, and for empty/negative/non-finite
  weighted-choice inputs plus the `pick = 0` zero-weight-prefix boundary; weighted choice rejects
  empty, negative, non-finite, and all-zero weights.
- `TNoiseGen` owns its permutation table explicitly and exposes `Noise1D`, `Noise2D`, `Noise3D`,
  `FBM1D`, `FBM2D`, and `FBM3D`. Invalid FBM octave, lacunarity, and gain inputs fail fast with
  `EArgumentError`; `test_noise` now directly locks the exact owner-level message variants across
  `FBM1D/2D/3D` for octave/lacunarity/gain validation, finite coordinate validation,
  negative-fractional coordinate canonicalization across the 256-periodic seam, and
  octave-coordinate/amplitude/accumulated-result overflow contracts; finite parameter combinations
  that would make octave coordinates, amplitudes, or accumulated results non-finite also fail fast
  at the `FBM*` owner boundary.
- `test_random`, `test_noise`, `test_facade`, and `test_api_surface` lock behavior, facade export,
  public-surface declarations, no global heap singleton, and heaptrc clean object lifetimes.

## M7: SIMD-Backed Implementation Seams

Goal: add `nextpas.core.math.impl.simd` without making SIMD a public math API shape.

Completion gate:

- `math.impl.simd` depends only on supported `nextpas.core.simd` public APIs.
- `math.impl.simd` does not call `nextpas.core.simd.direct`, dispatch tables, dataplane internals, or backend-private units.
- Any missing primitive is added to `nextpas.core.simd` with its own tests before math consumes it.
- `VectorsSIMD.pas` is never copied into core.
- Public consumers and public tests do not `uses nextpas.core.math.impl.*`.

Status:

- Partial. `nextpas.core.math.impl.simd` provides internal `TVec4f` add/sub/component-multiply/scale,
  dot, length, and `TVec3f` dot/cross helpers through the public `nextpas.core.simd` facade, plus
  candidate `TMat4f * TVec4f` and `TQuatf.Rotate` helpers for evidence-only measurement.
- `test_impl_simd` locks the helper behavior and heaptrc-clean execution, including the requirement
  that `SimdQuatfRotate` matches public `TQuatf.Rotate` semantics for non-unit quaternions.
- `core/Makefile` now exposes `core-math-impl-simd-local-smoke`, reachable as
  `make -C core core-math-impl-simd-local-smoke`. It reruns
  `make -C tests/nextpas.core.math/test_impl_simd clean test` through a stable owner-level
  targeted proof entrypoint for the internal seam correctness contract.
- `test_api_surface` now requires the internal seam file and declarations, rejects backend-private
  SIMD dependencies, and allows only implementation-specific tests to import `math.impl.*`.
- `bench_simd_seam` now provides a repeatable local Linux benchmark harness for the internal seam:
  `NEXTPAS_BENCH_MAX_ITERS=20000 make -C core/benchmarks/nextpas.core.math/bench_simd_seam clean run`.
  On this x86_64/Linux/FPC 3.3.1 local run with `-MObjFPC -Sh -O2` and 16 fixed
  vector/matrix/quaternion samples, scalar public methods were faster than the current
  public-facade SIMD seam for the measured helpers
  (`TVec4f` add 22.6 vs 242.7 ns/op, scale 22.9 vs 262.8 ns/op, dot 3.3 vs 33.8 ns/op, length 12.7
  vs 44.5 ns/op, `TVec3f` cross 20.9 vs 114.8 ns/op). This is negative wiring evidence for the
  current seam shape, not a
  rejection of later optimized SIMD primitives.
- The harness now preserves scalar baselines for the next likely M7 candidates before any new public
  SIMD primitive is designed: `TMat4f * TMat4f` 206.2 ns/op and `TQuatf.Rotate` 68.9 ns/op on the
  same x86_64/Linux/FPC 3.3.1 local run with `NEXTPAS_BENCH_MAX_ITERS=20000`. It also measures a
  candidate internal `TMat4f * TVec4f` seam using only public `VecF32x4*` operations: the scalar
  operator remained faster at 26.7 ns/op versus 435.9 ns/op for the current seam shape. The same
  harness now measures a candidate internal `TQuatf.Rotate` seam that normalizes the quaternion
  first to match public rotate semantics; the scalar path remained faster at 68.9 ns/op versus
  372.0 ns/op for the current seam shape.
  `test_api_surface` requires both the seam and scalar benchmark markers so later M7 work cannot
  drop the evidence accidentally.
- No public `TVec*`, `TMat*`, or `TQuat*` method has been routed through this seam yet. Broader SIMD
  acceleration, profiling evidence, and any missing public SIMD primitives remain future work. The
  current vector-helper seam and the candidate `TMat4f * TVec4f` and `TQuatf.Rotate` seams are all
  negative wiring evidence on this local x86_64/Linux run, so public value-type operators and
  methods remain intentionally scalar.

## M8: API Surface, Docs, Leak Proof, And Module Gates

Goal: close nextPas/core math as a framework-quality module.

Completion gate:

- All math tests pass.
- API surface checker passes.
- Trig link safety is proven by surface checks plus host link smokes. Linux runs locally; macOS/Windows must run in their host gates or be recorded as pending blockers before final completion.
- Heaptrc leak evidence is recorded for tests that allocate.
- Docs explain the module entry points, public API groups, and matrix/quaternion conventions.

Status:

- Partial. `docs/math/README.md` now documents the public modules, matrix/quaternion conventions,
  random/noise explicit ownership, SIMD boundary, focused verification commands, and the remaining
  macOS/Windows trig host-gate risk. `docs/math/API.md` groups the current public API by module and
  records public behavior boundaries for vectors, matrices, quaternions, transforms, easing, random,
  and noise.
- Local Linux closeout gates have been rerun for the current docs/API surface: `make -C
core/tests/nextpas.core.math clean test` exits 0, `test_api_surface` reports
  `MATH_API_SURFACE OK: scanned=43 findings=0`, allocation-bearing math tests report heaptrc
  `0 unfreed memory blocks`, `make hygiene` reports `build-hygiene=pass`, and `git diff --check`
  has no findings.
- `core/Makefile` now exposes `core-math-api-surface-smoke`, reachable as
  `make -C core core-math-api-surface-smoke`. It reruns
  `make -C tests/nextpas.core.math/test_api_surface clean test` through a stable owner-level
  named entrypoint instead of relying on a direct subproject command.
- `core/Makefile` now exposes `core-math-full-local-smoke`, reachable as
  `make -C core core-math-full-local-smoke`. It reruns `make -C tests/nextpas.core.math clean test`
  through a stable owner-level named entrypoint instead of relying on an ad-hoc direct command.
- `core/Makefile` now exposes `core-math-overview-local-smoke`, reachable as
  `make -C core core-math-overview-local-smoke`. It reruns
  `make -C examples/nextpas.core.math/math_overview clean run` through a stable owner-level named
  entrypoint, so the facade-only consumer example no longer depends on a direct subproject command.
- `core/Makefile` now also exposes `core-math-facade-local-smoke`, reachable as
  `make -C core core-math-facade-local-smoke`. It reruns
  `make -C tests/nextpas.core.math/test_facade clean test` through a stable owner-level named
  entrypoint, so the canonical public consumer contract remains independently repeatable instead of
  only piggybacking on the trig host proof.
- `core/Makefile` now also exposes `core-math-symbol-scope-local-smoke`, reachable as
  `make -C core core-math-symbol-scope-local-smoke`. It reruns
  `make -C tests/nextpas.core.math/test_symbol_scope clean test` through a stable owner-level
  named entrypoint, so the coexistence contract between `nextpas.core.math` and
  `nextpas.core.simd.mathutil` no longer depends on a direct subproject command.
- Current API/docs review checked `docs/math/API.md` and `docs/math/README.md` against the public
  declarations in the facade and scalar/trig/vec/mat/quat/transform/easing/random submodules.
  `test_api_surface` now extracts root facade constants, public type aliases, and public function
  names, then fails if any name is missing from `docs/math/API.md`. The rule was mutation-tested by
  removing `Fmod` from a temporary API doc copy and observing
  `api-doc-missing-root-facade-name:Fmod`; the real docs pass with `scanned=43 findings=0`.
- `test_api_surface` also locks required behavior-test runner markers across the current facade,
  scalar, trig, vector, matrix, quaternion, transform, easing, random/noise, and internal SIMD seam
  tests. This gate was mutation-tested by removing the scalar `T.Run('constants')` marker from a
  temporary tree and observing `missing-required-behavior-test-marker:scalar-constants`.
- `core/Makefile` now exposes `core-math-smoke`, reachable as `make -C core core-math-smoke`. It
  first calls `core-math-api-surface-smoke` and then reruns `core-math-overview-local-smoke`, so
  the facade-only public consumer example is both directly reachable through its own named gate and
  composed into the broader module smoke through stable owner-level entrypoints.
- `core/Makefile` now also exposes `core-math-trig-local-smoke`, reachable as
  `make -C core core-math-trig-local-smoke`. It first calls `core-math-api-surface-smoke`, then
  reuses `core-math-facade-local-smoke`, and finally reruns `test_trig` as the current-host local
  trig link proof without pretending macOS/Windows have already been verified.
- M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.

## M9: fafafa.game Cutover And Old Vectors Retirement

Goal: switch `fafafa.game` to `nextpas.core.math.*` and remove or internalize the old `Vectors` system.

Completion gate:

- `fafafa.game` uses final `nextpas.core.math.*` names.
- Old `Vectors` is not a public API.
- Bridge tests, leak checks, API freeze checks, and source-contract smokes pass in the active `fafafa.game` worktree.
