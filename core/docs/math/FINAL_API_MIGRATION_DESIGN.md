# nextpas.core.math Final API Migration Design

## Status

This document records the final-state math migration design and the design decisions already locked by
tests in this branch.

The current branch has implemented the scalar/trig facade, final vector/matrix/quaternion value
types, transform builders, easing functions, explicit-state random/noise generators, and the initial
internal SIMD seam. A local SIMD-seam benchmark harness now records scalar-vs-internal-seam evidence
without routing public value-type methods through SIMD, including a negative `TMat4f * TVec4f`
candidate seam result and a negative `TQuatf.Rotate` candidate seam result on the local
x86_64/Linux gate. M8 documentation and named local module gates are now in place via
`make -C core core-math-api-surface-smoke`, `make -C core core-math-overview-local-smoke`,
`make -C core core-math-facade-local-smoke`, `make -C core core-math-symbol-scope-local-smoke`,
`make -C core core-math-smoke`,
`make -C core core-math-full-local-smoke`, `make -C core core-math-impl-simd-local-smoke`,
`make -C core core-math-impl-simd-win64-compile-smoke`, and `make -C core
core-math-trig-local-smoke`. The branch also has a facade-only public example under
`core/examples/nextpas.core.math/math_overview` for common consumer usage. Final cross-platform
completion still requires macOS/Windows trig host link smokes, final API/docs review,
profiling-backed SIMD wiring decisions, and the later `fafafa.game` cutover.

The target is not gradual compatibility. The target is to absorb the useful math semantics from `fafafa.game` into `nextpas.core` and make `nextpas.core.math.*` the only official framework math API.

## Design Inputs

Current nextPas files:

- `src/nextpas.core.math.pas`
- `src/nextpas.core.math.trig.pas`
- `src/nextpas.core.math.ffi.pas` as an initial-state anti-pattern; it is deleted in this branch and must not be restored
- `src/nextpas.core.platform.posix.math.pas`
- `src/nextpas.core.platform.windows.math.pas`
- `src/nextpas.core.simd.*`
- `tests/nextpas.core.math/test_trig`

Source semantics from `fafafa.game`:

- `src/math/Vectors.pas`
- `src/math/VectorsGeneric.inc`
- `src/math/MatrixTransform.pas`
- `src/math/Easing.pas`
- `src/math/MathUtils.pas`
- `src/math/RandomGen.pas`
- `src/math/VectorsSIMD.pas` as audit input only

Framework rules:

- Module names are lowercase dotted namespaces.
- Facades explicitly re-export types and functions.
- `*.ffi.pas` exists only for real ABI declarations.
- Platform feature APIs should use host-owner platform seams instead of feature-local fake FFI files.
- Tests live under `tests/nextpas.core.<module>/`, each as independent `.lpr` projects.

## Non-Goals

- Do not touch compiler worktrees, compiler branches, or compiler code.
- Do not work on dirty `main`.
- Do not keep a long-term bridge to `fafafa.game` `Vectors`.
- Do not make `VectorsSIMD.pas` a public `nextpas.core.math.simd` API.
- Do not let `nextpas.core.math.ffi.pas` continue to bind naked `external 'm'`.
- Do not mechanically copy `fafafa.game` code. Keep good semantics; rewrite bad dependencies and bad ownership.
- Do not run final benchmarks until API, behavior tests, leak checks, and surface checks are stable.

## Approach Options

### Option A: Big-Bang Copy From `fafafa.game`

This would copy `VectorsGeneric.inc`, transform helpers, easing, and random code into `nextPas/core`, then rename types.

Pros:

- Fast initial surface.
- Behavior remains close to `fafafa.game`.

Cons:

- Imports old `Math`, `SysUtils`, text conversion, and engine-shaped assumptions.
- Preserves old names and bridge habits.
- Makes SIMD and platform cleanup harder.
- High risk of shipping untested public APIs.

Decision: reject.

### Option B: Final API, Tests First, Rewrite Semantics

This writes final `nextpas.core.math.*` behavior tests first, then implements the modules with final type names and framework-owned seams.

Pros:

- Matches the stated target: final API, no long-term bridge.
- Lets bad legacy code be discarded while preserving good behavior.
- Keeps commits small and reversible.
- Makes API coverage and heaptrc evidence part of the migration, not an afterthought.

Cons:

- Slower than copying.
- Requires careful test design before implementation.

Decision: use this approach.

### Option C: Compatibility Bridge First

This would wrap `fafafa.game` `Vectors` from nextPas and gradually rename.

Pros:

- Eases `fafafa.game` cutover.

Cons:

- Violates the hard boundary: `Vectors` must not become the final API.
- Encourages two public math truths.
- Makes API freeze and docs ambiguous.

Decision: reject except for short-lived internal wrappers during the final `fafafa.game` cutover.

## Module Architecture

The final public units are:

- `nextpas.core.math`
- `nextpas.core.math.scalar`
- `nextpas.core.math.trig`
- `nextpas.core.math.vec`
- `nextpas.core.math.mat`
- `nextpas.core.math.quat`
- `nextpas.core.math.transform`
- `nextpas.core.math.easing`
- `nextpas.core.math.random`
- `nextpas.core.math.impl.scalar`
- `nextpas.core.math.impl.simd`

The public consumer-facing modules are the facade and the non-`impl` submodules. `nextpas.core.math.impl.*` units are final internal implementation units, not public API modules.

`nextpas.core.math` is the foundation facade. It keeps scalar constants and explicitly re-exports the
public math API that consumers normally need. Behavior lives in scalar/trig/vec/mat/quat/transform/
easing/random submodules; the facade uses aliases and inline forwarding.

`nextpas.core.math.scalar` owns:

- constants: `PI_VALUE`, `TWO_PI`, `HALF_PI`, `DEG_TO_RAD`, `RAD_TO_DEG`, typed `Single`/`Double` variants where needed
- `Min`, `Max`, `Clamp`, `Lerp`, `InverseLerp`, `Wrap`
- `Abs`, `Sign`, `Floor`, `Ceil`, `Round`, `Trunc`, `Frac`
- `IsNaN`, `IsInfinite`, `FloatEquals`, `FloatIsZero`
- overflow helpers originally held by `nextpas.core.math`

`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.

`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.

`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.

`Round` uses ties away from zero; `Abs` normalizes negative zero to positive zero; `Frac` and `Fmod` preserve the input or dividend sign for zero results; `Fmod` returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.

`nextpas.core.math.trig` owns:

- `Sin`, `Cos`, `Tan`
- `ArcSin`, `ArcCos`, `ArcTan`, `ArcTan2`
- `Exp`, `Ln`, `Log2`, `Log10`, `Power`, `Sqrt`

`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite
values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`.
`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves
signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.
Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.
`Power` returns `1` for base `+1` before NaN-exponent handling and for exponent `0` before NaN-base handling. Nonzero NaN bases return `NaN`;
infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases
follow exponent sign and odd/even sign rules.
`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.

Degree/radian conversion belongs to `nextpas.core.math.scalar`; the root facade re-exports that
scalar owner.

`nextpas.core.math.vec` owns value types:

- `TVec2f`, `TVec3f`, `TVec4f`
- `TVec2d`, `TVec3d`, `TVec4d`

`nextpas.core.math.mat` owns value types:

- `TMat3f`, `TMat4f`
- `TMat3d`, `TMat4d`

`nextpas.core.math.quat` owns value types:

- `TQuatf`
- `TQuatd`

`nextpas.core.math.transform` owns projection/view/model builders:

- `Ortho`
- `Perspective`
- `LookAt`
- `Translate`
- `Scale`
- `RotateX`, `RotateY`, `RotateZ`
- `Camera2D`

`nextpas.core.math.easing` owns all easing functions and `TEasingFunction`.

`nextpas.core.math.random` owns deterministic random and noise APIs.
Noise remains under the `random` capability family unless a later design proves a separate `nextpas.core.math.noise` module is warranted. The final architecture requested for this lane does not include a public `math.noise` module.

`nextpas.core.math.impl.scalar` owns implementation helpers shared by public modules. It is not a consumer-facing namespace.

`nextpas.core.math.impl.simd` owns optional acceleration. It can only depend on supported `nextpas.core.simd` public APIs.

## Public Type Design

The official type names are:

- `TVec2f`, `TVec3f`, `TVec4f`
- `TMat3f`, `TMat4f`
- `TQuatf`
- `TVec2d`, `TVec3d`, `TVec4d`
- `TMat3d`, `TMat4d`
- `TQuatd`

These are records with value semantics. They should use `{$modeswitch advancedrecords}` for methods and operators.

Vectors expose:

- fields `X`, `Y`, `Z`, `W`
- `Data` array aliases for indexed access
- constructors or static `Create` functions
- operators `+`, `-`, unary `-`, scalar `*`, scalar `/`
- component multiplication/division as explicit `MulComponents` and `DivComponents` helpers unless RED tests deliberately lock vector `*`/`/` as Hadamard operations
- `Dot`, `Cross` where applicable, `Length`, `LengthSqr`, `Normalize`, `Lerp`, `Zero`, `Equals`

The dot product is always named `Dot`; vector `*` must not imply dot product. This avoids the legacy ambiguity where `Vec * Vec` was component-wise multiplication.

Matrices expose:

- column-major storage `Data[column, row]`
- `Items[column, row]`, `Rows[row]`, `Columns[column]`
- operators for add/sub/neg/scalar multiply/matrix multiply/matrix-vector multiply
- `Identity`, `Zero`, `Transpose`, `Determinant`, `Inverse`, `TryInverse`, `Equals`

`Items` is the default indexed view. `Rows` and `Columns` are read/write projections over the same
column-major backing storage, so setter writes must alias through instead of updating detached row or
column snapshots.

Quaternions expose:

- vector part `X`, `Y`, `Z` and real part `W`, or an equivalent explicitly documented layout
- `Identity`, `Normalize`, `Conjugate`, `Equals`
- `FromAxisAngle`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`
- quaternion multiplication
- `Slerp`, `Nlerp`

`Equals` remains a component-wise epsilon comparison on quaternion storage rather than a
rotation-equivalence helper.
Interpolation follows the shortest rotational path: opposite-sign equivalent quaternion endpoints
must be treated as the same rotation instead of forcing the long arc through quaternion space.
Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`, `TVec3*`,
and `TVec4*` inputs preserve finite length, direction, and unit length without overflowing the
intermediate squared length.
`LengthSqr` avoids FPU overflow exceptions for huge finite inputs and returns `+Inf` when the true
squared length is outside the target float range. Vector `Data` aliases write through to named fields.
Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd`
inputs preserve direction instead of collapsing through an overflowing squared length.
`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the
intended rotation.

The facade may include convenience constructors such as `Vec2f`, `Vec3f`, `Vec4f`, `Mat4fIdentity`, or `QuatfIdentity` only if tests lock the exact public names. Constructors must not reintroduce legacy `Vector2`, `TVector3`, `TMatrix4`, or `TQuaternion` as official names.

## Matrix And Transform Conventions

The design keeps the useful `fafafa.game` conventions because they are internally coherent:

- Matrices are column-major: `Data[column, row]`.
- Vectors are column vectors.
- Composition uses `Projection * View * Model`.
- Perspective is right-handed and looks down `-Z`.
- NDC is `[-1,+1]`.
- `Ortho` follows OpenGL-style orthographic projection.
- Reversed non-zero `Ortho` bounds are valid and flip the corresponding axis.
- Translation lives in column 3: `Data[3, 0..2]`.
- `Camera2D` uses orthographic bounds centered on `(CenterX, CenterY)` and supports a screen-space `+Y down` convention by swapping top/bottom bounds.
- `Camera2D` larger zoom values magnify the view, so the same world-space offset maps farther in NDC on both axes.
- Local transform composition, if exposed, uses `Translate * Rotate * Scale`.
- Parent/world transform composition, if exposed, uses `ParentWorld * Local`.
- `LookAt` is a right-handed view-matrix builder. Object-transform `LookAt` semantics are a separate concern and must not share an ambiguous name.
- `LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while flipping `up` to the opposite direction changes roll.
- Guard contracts are part of the public behavior: `Ortho` rejects zero width/height/depth,
  `Perspective` requires positive FOV/aspect/near, vertical FOV `< PI`, plus `far > near`,
  `LookAt` requires `eye <> target` and non-parallel `up`, and `Camera2D` requires positive zoom
  and viewport size.

These conventions must be documented and tested. If any downstream renderer expects different conventions, it must adapt at its boundary instead of changing the core math truth.

## Trig And Platform Strategy

The original `nextpas.core.math.ffi.pas` was not acceptable as final architecture:

- It is module-level public FFI for a feature that should be a safe framework facade.
- It binds `external 'm'` unconditionally.
- Windows does not use a stable `libm` named `m` in the same way POSIX targets do.
- Early tests imported `nextpas.core.math.ffi`, which froze the wrong surface.

Final strategy and current status:

1. Add RED surface tests first. They reject public/test `uses nextpas.core.math.ffi`.
1. `nextpas.core.math.trig` exposes safe public functions.
1. `nextpas.core.math.trig` depends on `nextpas.core.math.impl.scalar` or platform-owned helpers.
1. Platform-specific native bindings, if used, belong under host-owner platform seams, not under a public `math.ffi` facade.
1. Where dynamic loading is needed, keep the public facade loading-strategy-agnostic.
1. For first correctness implementation, pure Pascal or host-safe RTL-compatible implementations are acceptable if they pass accuracy tests and link on Linux/macOS/Windows.
1. Delete `nextpas.core.math.ffi.pas` once no source or test uses it. This branch has deleted it; do not reintroduce a deprecated stub unless a landing review finds an external compatibility blocker and the source-surface test still prevents new use.

The first implementation batch should not attempt to be the fastest trig library. It should first be correct, safe, and linkable. SIMD/transcendental acceleration comes later through `nextpas.core.simd` primitives.

Cross-platform link proof has two layers:

- Full local math proof: `make -C core core-math-full-local-smoke` wraps
  `make -C tests/nextpas.core.math clean test` through a stable owner-level `core/Makefile`
  target, so the current full math focused suite does not depend on an ad-hoc direct command.
- Static surface proof: `make -C core core-math-api-surface-smoke` wraps
  `make -C tests/nextpas.core.math/test_api_surface clean test`, which rejects `external 'm'`
  under `src/nextpas.core.math*.pas` and rejects behavior tests that import
  `nextpas.core.math.ffi`.
- Facade consumer proof: `make -C core core-math-facade-local-smoke` wraps
  `make -C tests/nextpas.core.math/test_facade clean test`, so the canonical public consumer
  contract remains independently callable through an owner-level gate instead of only piggybacking
  on the trig host proof.
- Symbol-scope proof: `make -C core core-math-symbol-scope-local-smoke` wraps
  `make -C tests/nextpas.core.math/test_symbol_scope clean test`, so the coexistence contract
  between `nextpas.core.math` and `nextpas.core.simd.mathutil` remains independently callable
  through an owner-level gate instead of a direct subproject command.
- Host link proof: `make -C core core-math-trig-local-smoke` first calls
  `core-math-api-surface-smoke`, then reuses `core-math-facade-local-smoke`, and finally runs
  `test_trig` as the current-host local link proof. macOS/Windows host gates must still rerun
  equivalent checks before trig is marked complete. If macOS/Windows gates are unavailable in a
  round, the round must report that final cross-platform completion is blocked, not complete.
- Win64 compile-only proof: `make -C core core-math-trig-win64-compile-smoke` runs a
  `-Cn -Twin64 -Px86_64` probe that imports both `nextpas.core.math` and
  `nextpas.core.math.trig`. This is useful forced compile evidence for the current toolchain, but
  it is not a Windows host link/run proof and it does not cover macOS.
- Win64 internal SIMD compile-only proof: `make -C core core-math-impl-simd-win64-compile-smoke`
  runs the forced compile gate for the internal seam.
  `core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.
  Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.
  M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.

## Random And Noise Design

`fafafa.game` uses `xoroshiro128+` and a Perlin-style permutation table. The semantics are useful; the public ownership needs improvement.

Final strategy:

- Use a record or class with explicit state ownership.
- Do not expose global heap-owned `GRandom`/`GNoise` as official framework API.
- Treat seed `0` behavior as a documented deterministic default.
- Validate or define behavior for invalid ranges:
  - `NextIntRange(Min, Max)` with `Min > Max`
  - `NextFloatRange(Min, Max)` with `Min > Max`
  - `NextBool(Probability)` outside `[0,1]`
  - `Roll(Sides <= 0)`
  - `RollMultiple(Dice <= 0)`
  - `RollMultiple(Dice > 0, Sides > 0)` when `Dice * Sides` would not fit `Integer`
  - `WeightedChoice([])` or non-positive weights
  - `FBM*` with `Octaves <= 0`, bad `Lacunarity`, bad `Gain`, or finite parameter
    combinations that would make octave coordinates, amplitudes, or accumulated results non-finite
- `NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single`
  bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.
- `WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on zero-weight prefixes.
- `NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of producing NaN or infinity.
- Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like `-0.25` and `255.75` stay equivalent for the same seeded generator.
- For large `Double` noise coordinates above the sub-unit precision ceiling, document stable
  stored-value semantics rather than inventing a fake owner-level precision error.
- Keep deterministic test vectors for seeds.

The public names are now locked by tests as `TRandomState`, `TRandomGen`, and `TNoiseGen`.

## SIMD Strategy

SIMD is an implementation seam, not a public math namespace.

Rules:

- `nextpas.core.math.impl.simd` may call `nextpas.core.simd` public APIs such as `VecF32x4*`, `Array*`, and re-exported public SIMD utility functions.
- It may not include or copy `VectorsSIMD.pas`.
- It may not call backend-private files such as `nextpas.core.simd.avx2.*` directly.
- It may not call `nextpas.core.simd.direct`, `GetDirectDispatchTable`, dispatch internals, dataplane internals, or backend registration units.
- If math needs a primitive that does not exist, add it to `nextpas.core.simd` first with tests and dispatch coverage.
- Small value-type operations should start scalar unless a clear public SIMD primitive already exists.

Initial SIMD candidates:

- `TVec4f` dot/add/sub/mul/scale through public `VecF32x4*` if profiling shows benefit
- batch transform positions/normals
- batch quaternion rotate
- `TMat4f * TVec4f` and `TMat4f * TMat4f` only after profiling proves they are hot enough to justify a public SIMD primitive

The current local benchmark harness now preserves scalar baselines for the next likely candidates
before any new public SIMD primitive is proposed: `TMat4f * TMat4f` and `TQuatf.Rotate`. It also now
includes a candidate internal `TMat4f * TVec4f` seam that uses only public `VecF32x4*` operations
and a candidate internal `TQuatf.Rotate` seam that normalizes the quaternion first to match public
rotate semantics. On the same x86_64/Linux/FPC 3.3.1 local run with
`NEXTPAS_BENCH_MAX_ITERS=20000`, the scalar operator remained faster at 26.7 ns/op versus 435.9
ns/op for the current mat-vec seam shape, and scalar quaternion rotate remained faster at 68.9
ns/op versus 372.0 ns/op for the current quaternion seam shape. This is negative wiring evidence,
so the public `TMat4f * TVec4f` operator and `TQuatf.Rotate` method remain scalar. `test_api_surface`
requires the scalar and seam benchmark labels so future M7 work cannot silently drop the evidence
while experimenting with new primitives.
Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam
benchmarks are negative wiring evidence, and public math source units must not import
`math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.

These should not block the first API implementation. They belong after scalar correctness and full tests.

## Test Strategy

Testing started before implementation and remains the completion gate.

Required projects:

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

Coverage requirements:

- Vec2/Vec3/Vec4: add, sub, component multiply/divide, scalar multiply/divide, `Dot`, `Cross`, `Length`, `Normalize`, `Lerp`, `Zero`, `Equals`.
- Mat3/Mat4: `Identity`, `Zero`, `Transpose`, `Determinant`, `Inverse`, `TryInverse`, matrix multiply, matrix-vector multiply.
- Quat: `Identity`, `Normalize`, `Conjugate`, `FromAxisAngle`, `ToRotationMatrix`, `Rotate`, `Slerp`, `Nlerp`.
- Transform: `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`, `RotateX`, `RotateY`, `RotateZ`, `Camera2D`.
- Easing: every public easing function, including finite out-of-range behavior and NaN/Inf
  rejection. `EaseOutBounce` follows the documented four-piece bounce ladder, and the direct
  branch tests lock representative points in each non-endpoint segment.
- Random/Noise: deterministic seed, range boundaries, invalid input behavior.
- Trig: Linux/macOS/Windows link safety and no `external 'm'` surface dependency.

Surface checks:

- No public test may `uses nextpas.core.math.ffi`.
- No `src/nextpas.core.math*.pas` may contain naked `external 'm'`.
- No final public API may expose `TVector*`, `TMatrix*`, `TQuaternion*`, or `Vectors` bridge names.
- No `math.impl.simd` may depend on backend-private SIMD units.
- Public docs, public tests, examples, and downstream consumers must not `uses nextpas.core.math.impl.*`.
- `test_api_surface` maintains a public allowlist. New public symbols must be added to the allowlist and to a matching behavior test in the same commit.
- `test_api_surface` also locks required behavior-test runner markers for the current public API
  groups, so removing a focused behavior group fails the surface gate instead of silently weakening
  public API coverage.
- Test Makefiles must not reference `compiler/` paths or compiler build entrypoints.

Completion bar:

- Passing unit tests are required for every public API.
- Heaptrc leak proof is required for allocation-bearing tests.
- API surface checks are required before claiming completion.

Heaptrc pass means the focused command exits 0, the test summary has `0 failed`, and heaptrc reports `0 unfreed memory blocks`. Random and noise tests must cover create/reset/free paths with `try/finally` or interface release semantics.

## Migration Route

1. Control and design.
2. RED tests for final public API.
3. Scalar/trig foundation and `math.ffi` removal.
4. Vec/Mat/Quat scalar implementation.
5. Transform implementation.
6. Easing implementation.
7. Random/noise implementation.
8. SIMD implementation seam.
9. Docs, API surface check, leak proof, module gates.
10. `fafafa.game` cutover.
11. Old `Vectors` public API removal or internal wrapper downgrade.

Each step is a separate reversible commit.

## Resolved And Remaining Design Points

Resolved by tests and implementation:

- Constructors use static `Create`; no short free constructors are part of the current public API.
- `Inverse` raises `EArgumentError` for singular, numerically singular, and non-finite matrices;
  `TryInverse` returns `False` and zeroes the failed `out` matrix.
- Matrix inverse failure is fail-close: `TryInverse` treats singular, numerically singular, and
  non-finite matrices the same, returns `False`, zeroes the failed `out` matrix, and `Inverse`
  raises `EArgumentError` on the same inputs.
- Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on
  the previous contents of the destination matrix and fully rewrites it before returning `True`.
- Zero vector normalization returns zero; zero quaternion normalization returns identity.
- Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`,
  `TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without
  overflowing the intermediate squared length.
- Vector `LengthSqr` avoids FPU overflow exceptions for huge finite inputs and returns `+Inf` when
  the true squared length is outside the target float range. Vector `Data` aliases write through to
  named fields.
- Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by
  `Normalize`.
- Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd`
  inputs preserve direction instead of collapsing through an overflowing squared length.
- Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by
  `Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.
- `FromAxisAngle` normalizes its axis and returns identity for a zero axis instead of inventing a
  partial rotation.
- `FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the
  intended rotation.
- `ToAxisAngle` normalizes its quaternion first and returns a canonical shortest-angle axis-angle
  pair: zero rotation uses `+Z` as the fallback axis, and exact half-turns, including
  `FromAxisAngle(..., PI)` paths, use a stable axis hemisphere so opposite-sign equivalent
  quaternions map to the same output.
- `ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and
  `AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous
  contents.
- Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first,
  then applies the left operand `A`, and non-collinear rotations are non-commutative.
- `ToRotationMatrix` and `Rotate` normalize their quaternion first, so positive scaling of an
  equivalent input rotation does not change the result.
- `Equals` is a component-wise epsilon comparison on quaternion storage; it does not canonicalize
  opposite-sign equivalent rotations, and negative epsilon returns `False`.
- Finite interpolation factors outside `[0, 1]` are not clamped: `Slerp` and `Nlerp` extrapolate
  through the same formulas instead of snapping to either endpoint.
- The interpolation endpoints follow the same normalization and shortest-path contract: `AT = 0`
  returns the normalized start rotation, and `AT = 1` returns the normalized end rotation after
  any opposite-sign canonicalization.
- `Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared
  axis and interpolate the small remaining angle instead of collapsing or taking a long arc.
- Random invalid integer/float ranges and invalid weighted choices fail fast with `EArgumentError`.
- Convenience dice helpers return `0` for non-positive dice or sides, and `RollMultiple` rejects
  positive dice/side combinations whose maximum total would overflow `Integer`.
- `NextBool` clamps probability into false or true behavior.
- Invalid FBM octave, lacunarity, and gain inputs fail fast with `EArgumentError`, and owner-level
  FBM checks also reject finite coordinate/lacunarity or gain combinations that would make octave
  coordinates, amplitudes, or accumulated results non-finite.
- `nextpas.core.math` re-exports the scalar/trig/vector/matrix/quaternion/transform/easing/random API.
- The first transform cut exposes builder functions only; no `TTransform3f` or `TTransform3d` records are public.

Remaining design work:

- macOS and Windows trig host link smokes must prove the current safe trig route on those hosts.
- Broader SIMD acceleration needs profiling evidence before wiring public value-type methods through the internal seam.
- `fafafa.game` cutover must decide whether any short-lived internal wrappers are needed without turning legacy `Vectors` names into nextPas public API.
