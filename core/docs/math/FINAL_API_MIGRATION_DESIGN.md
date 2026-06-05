# nextpas.core.math Final API Migration Design

## Status

This is the design document for the final-state math migration. It is not an implementation report. The current branch has not changed math behavior yet.

The target is not gradual compatibility. The target is to absorb the useful math semantics from `fafafa.game` into `nextpas.core` and make `nextpas.core.math.*` the only official framework math API.

## Design Inputs

Current nextPas files:

- `src/nextpas.core.math.pas`
- `src/nextpas.core.math.trig.pas`
- `src/nextpas.core.math.ffi.pas`
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

`nextpas.core.math` is the foundation facade. It keeps scalar constants and lightweight helpers, and it explicitly re-exports the public math API that consumers normally need.
The current file contains implementation logic; the migration should move behavior into submodules and leave the facade as re-export plus inline forwarding.

`nextpas.core.math.scalar` owns:

- constants: `PI_VALUE`, `TWO_PI`, `HALF_PI`, `DEG_TO_RAD`, `RAD_TO_DEG`, typed `Single`/`Double` variants where needed
- `Min`, `Max`, `Clamp`, `Lerp`, `InverseLerp`, `Wrap`
- `Abs`, `Sign`, `Floor`, `Ceil`, `Round`, `Trunc`, `Frac`
- `IsNaN`, `IsInfinite`, `FloatEquals`, `FloatIsZero`
- overflow helpers currently in `nextpas.core.math`

`nextpas.core.math.trig` owns:

- `Sin`, `Cos`, `Tan`
- `ArcSin`, `ArcCos`, `ArcTan`, `ArcTan2`
- `Exp`, `Ln`, `Log2`, `Log10`, `Power`, `Sqrt`
- degree/radian conversions if the facade chooses to place them here; scalar may also re-export them

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

Quaternions expose:

- vector part `X`, `Y`, `Z` and real part `W`, or an equivalent explicitly documented layout
- `Identity`, `Normalize`, `Conjugate`
- `FromAxisAngle`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`
- quaternion multiplication
- `Slerp`, `Nlerp`

The facade may include convenience constructors such as `Vec2f`, `Vec3f`, `Vec4f`, `Mat4fIdentity`, or `QuatfIdentity` only if tests lock the exact public names. Constructors must not reintroduce legacy `Vector2`, `TVector3`, `TMatrix4`, or `TQuaternion` as official names.

## Matrix And Transform Conventions

The design keeps the useful `fafafa.game` conventions because they are internally coherent:

- Matrices are column-major: `Data[column, row]`.
- Vectors are column vectors.
- Composition uses `Projection * View * Model`.
- Perspective is right-handed and looks down `-Z`.
- NDC is `[-1,+1]`.
- `Ortho` follows OpenGL-style orthographic projection.
- Translation lives in column 3: `Data[3, 0..2]`.
- `Camera2D` uses orthographic bounds centered on `(CenterX, CenterY)` and supports a screen-space `+Y down` convention by swapping top/bottom bounds.
- Local transform composition, if exposed, uses `Translate * Rotate * Scale`.
- Parent/world transform composition, if exposed, uses `ParentWorld * Local`.
- `LookAt` is a right-handed view-matrix builder. Object-transform `LookAt` semantics are a separate concern and must not share an ambiguous name.

These conventions must be documented and tested. If any downstream renderer expects different conventions, it must adapt at its boundary instead of changing the core math truth.

## Trig And Platform Strategy

The current `nextpas.core.math.ffi.pas` is not acceptable as final architecture:

- It is module-level public FFI for a feature that should be a safe framework facade.
- It binds `external 'm'` unconditionally.
- Windows does not use a stable `libm` named `m` in the same way POSIX targets do.
- Tests currently `uses nextpas.core.math.ffi`, which freezes the wrong surface.

Final strategy:

1. Add RED surface tests first. They should prove current behavior is wrong by rejecting public/test `uses nextpas.core.math.ffi`.
1. `nextpas.core.math.trig` exposes safe public functions.
2. `nextpas.core.math.trig` depends on `nextpas.core.math.impl.scalar` or platform-owned helpers.
3. Platform-specific native bindings, if used, belong under host-owner platform seams, not under a public `math.ffi` facade.
4. Where dynamic loading is needed, keep the public facade loading-strategy-agnostic.
5. For first correctness implementation, pure Pascal or host-safe RTL-compatible implementations are acceptable if they pass accuracy tests and link on Linux/macOS/Windows.
6. Delete `nextpas.core.math.ffi.pas` once no source or test uses it. If deletion temporarily breaks unknown consumers, keep a deprecated compile-time stub only if a source-surface test prevents new use and the final cutover removes it.

The first implementation batch should not attempt to be the fastest trig library. It should first be correct, safe, and linkable. SIMD/transcendental acceleration comes later through `nextpas.core.simd` primitives.

Cross-platform link proof has two layers:

- Static surface proof: `test_api_surface` rejects `external 'm'` under `src/nextpas.core.math*.pas` and rejects behavior tests that import `nextpas.core.math.ffi`.
- Host link proof: `test_trig` and `test_facade` must link on Linux locally and on macOS/Windows host gates before trig is marked complete. If macOS/Windows gates are unavailable in a round, the round must report that final cross-platform completion is blocked, not complete.

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
  - `WeightedChoice([])` or non-positive weights
  - `FBM*` with `Octaves <= 0`, bad `Lacunarity`, or bad `Gain`
- Keep deterministic test vectors for seeds.

The preferred public names should be framework-shaped, for example `TRandomGen` and `TNoiseGen` or `TMathRandom` and `TMathNoise`, but the exact names must be locked by tests before implementation.

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

These should not block the first API implementation. They belong after scalar correctness and full tests.

## Test Strategy

Testing starts before implementation.

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
- Easing: every public easing function.
- Random/Noise: deterministic seed, range boundaries, invalid input behavior.
- Trig: Linux/macOS/Windows link safety and no `external 'm'` surface dependency.

Surface checks:

- No public test may `uses nextpas.core.math.ffi`.
- No `src/nextpas.core.math*.pas` may contain naked `external 'm'`.
- No final public API may expose `TVector*`, `TMatrix*`, `TQuaternion*`, or `Vectors` bridge names.
- No `math.impl.simd` may depend on backend-private SIMD units.
- Public docs, public tests, examples, and downstream consumers must not `uses nextpas.core.math.impl.*`.
- `test_api_surface` maintains a public allowlist. New public symbols must be added to the allowlist and to a matching behavior test in the same commit.
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

## Open Design Points

These must be resolved before implementation starts:

- Exact constructor names: static `Create` only, or also free functions such as `Vec3f`.
- Exact `Inverse` behavior for singular matrices: exception vs returning `Zero`; `TryInverse` must be the non-throwing path either way.
- Exact zero normalize behavior for vectors and quaternions.
- Exact random invalid-input behavior: fail fast with exceptions or deterministic graceful return values.
- Whether `nextpas.core.math` facade re-exports every submodule or keeps some behind explicit `uses`.
- Whether `TTransform3f/TTransform3d` records belong in the first math cut or should wait until vec/mat/quat/transform builders are stable.

Task 1 must turn these open points into explicit RED tests or documented deferrals before adding implementation code. RED tests must not implicitly decide a policy by accident.

The recommended defaults are:

- Use static `Create` plus short free constructors only if tests make them official.
- `Inverse` raises for singular matrices; `TryInverse` returns `False`.
- Zero vector normalize returns zero; zero quaternion normalize returns identity only if explicitly documented and tested.
- Random invalid inputs should fail fast for programmer errors except documented convenience methods such as `Roll(0)`.
- The `nextpas.core.math` facade re-exports core scalar/trig/vector/matrix/quaternion/transform/easing/random APIs because it is the official foundation entry point.
