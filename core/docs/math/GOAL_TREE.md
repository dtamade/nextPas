# nextpas.core.math Goal Tree

> Last updated: 2026-06-06
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

This branch is at **M1/M2 focused scalar + trig + symbol-conflict slice**.

- M0 design/control is committed as `21e1f510 docs(math): plan final api migration`.
- This slice adds scalar/trig/facade/symbol-scope tests only; it does not complete Vec/Mat/Quat/Transform/Easing/Random/Noise.
- `nextpas.core.math.scalar` and `nextpas.core.math.impl.scalar` now exist.
- `nextpas.core.math` is now a scalar/trig facade.
- `nextpas.core.math.trig` no longer depends on `nextpas.core.math.ffi`.
- `nextpas.core.math.ffi.pas` is deleted in this branch.
- `nextpas.core.simd.mathutil` no longer exports common bare math-compatible helper names.
- Added scalar `Single` overloads, `GCD`, `LCM`, `Hypot`, `Fmod`, `SmoothStep`, guarded `Abs(Low(...))`, and IEEE-style `SimdLnF32` boundaries.
- Edge-case fixes are locked by tests for guarded integer conversion, `Abs(Low(...))`, `Hypot(+Inf,+Inf)`, trig NaN/out-of-domain/double-infinity cases, and `SimdLnF32(NaN)`.
- Linux-focused math/SIMD tests pass locally; macOS/Windows trig link smokes remain a later host-gate requirement before final cross-platform completion.

## Map

```text
nextpas.core.math final migration
├── M0: Control, design, and audit                       [complete]
├── M1: RED behavior tests for final API                 [partial: scalar/trig/facade/surface]
├── M2: Scalar + trig foundation                         [partial: scalar/trig Linux local gate passed]
├── M3: Vec/Mat/Quat value types                         [not started]
├── M4: Transform builders                               [not started]
├── M5: Easing                                           [not started]
├── M6: Random + noise                                   [not started]
├── M7: SIMD-backed implementation seams                 [not started]
├── M8: API surface, docs, leak proof, and module gates   [not started]
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
- `test_api_surface` rejects `nextpas.core.math.ffi`, naked `external 'm'`, public `Vectors` bridge names, and public symbols that lack matching behavior tests.
- `test_facade` proves a consumer can `uses nextpas.core.math` and call the canonical final API without importing implementation or legacy bridge units.

Status:

- Partial. This slice covers API surface, facade, scalar, trig, and symbol-scope tests.
- Vec/Mat/Quat/Transform/Easing/Random/Noise tests remain pending.

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

- Partial. Linux local scalar/trig/facade/symbol-scope tests pass with heaptrc `0 unfreed memory blocks`.
- `nextpas.core.math.ffi.pas` is deleted in this branch.
- API surface checks reject naked `external 'm'`, public/test `math.ffi` consumers, public impl consumers, and legacy vector bridge names.
- macOS/Windows host link smokes are not run in this local round.

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
- Singular matrix inversion uses a documented `TryInverse` path and does not return silent garbage.
- Normalize of zero vectors/quaternions is explicitly defined and tested.

## M4: Transform Builders

Goal: provide transform builders under `nextpas.core.math.transform`.

Completion gate:

- Ortho, Perspective, LookAt, Translate, Scale, RotateX/Y/Z, and Camera2D are tested against known vectors/matrices.
- Matrix convention is documented and source tests verify column-major layout.

## M5: Easing

Goal: migrate easing functions into `nextpas.core.math.easing`.

Completion gate:

- Every public easing function has endpoint and representative midpoint tests.
- Functions use `nextpas.core.math.trig`/scalar helpers, not FPC `Math`.

## M6: Random + Noise

Goal: provide deterministic RNG and noise APIs under `nextpas.core.math.random`.

Completion gate:

- Seed determinism, range boundaries, invalid ranges, probability clamps, dice rules, weighted choice, shuffle, and noise repeatability are tested.
- No global heap-owned random/noise singletons are part of the public API.
- Heaptrc confirms object lifetimes are clean.

## M7: SIMD-Backed Implementation Seams

Goal: add `nextpas.core.math.impl.simd` without making SIMD a public math API shape.

Completion gate:

- `math.impl.simd` depends only on supported `nextpas.core.simd` public APIs.
- `math.impl.simd` does not call `nextpas.core.simd.direct`, dispatch tables, dataplane internals, or backend-private units.
- Any missing primitive is added to `nextpas.core.simd` with its own tests before math consumes it.
- `VectorsSIMD.pas` is never copied into core.
- Public consumers and public tests do not `uses nextpas.core.math.impl.*`.

## M8: API Surface, Docs, Leak Proof, And Module Gates

Goal: close nextPas/core math as a framework-quality module.

Completion gate:

- All math tests pass.
- API surface checker passes.
- Trig link safety is proven by surface checks plus host link smokes. Linux runs locally; macOS/Windows must run in their host gates or be recorded as pending blockers before final completion.
- Heaptrc leak evidence is recorded for tests that allocate.
- Docs explain the module entry points and matrix/quaternion conventions.

## M9: fafafa.game Cutover And Old Vectors Retirement

Goal: switch `fafafa.game` to `nextpas.core.math.*` and remove or internalize the old `Vectors` system.

Completion gate:

- `fafafa.game` uses final `nextpas.core.math.*` names.
- Old `Vectors` is not a public API.
- Bridge tests, leak checks, API freeze checks, and source-contract smokes pass in the active `fafafa.game` worktree.
