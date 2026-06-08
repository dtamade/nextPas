# nextpas.core.math API

Use `nextpas.core.math` as the default import for application code:

```pascal
uses
  nextpas.core.math;
```

Use a narrower submodule only when a file intentionally depends on one math family, such as
`nextpas.core.math.vec` or `nextpas.core.math.random`.

## Public Modules

- `nextpas.core.math` is the facade. It re-exports the public scalar, trig, vector, matrix,
  quaternion, transform, easing, and random API. Noise is exposed through
  `nextpas.core.math.random.TNoiseGen`; there is no public `nextpas.core.math.noise` unit.
- `nextpas.core.math.scalar` owns scalar constants, numeric helpers, float predicates, interpolation,
  angle conversion, and integer overflow helpers.
- `nextpas.core.math.trig` owns trigonometric, exponential, logarithmic, power, square-root, and
  related transcendental helpers. Angle conversion belongs to `nextpas.core.math.scalar`.
- `nextpas.core.math.vec` owns packed vector value types.
- `nextpas.core.math.mat` owns packed matrix value types.
- `nextpas.core.math.quat` owns packed quaternion value types.
- `nextpas.core.math.transform` owns matrix builders for projection, view, model, and 2D camera use.
- `nextpas.core.math.easing` owns easing functions and the easing callback type.
- `nextpas.core.math.random` owns explicit-state deterministic random and noise generators.

Implementation-only units are not public API. Do not import `math.impl.*` units from application
code, examples, public docs, or public tests.
Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam
benchmarks are negative wiring evidence, and public math source units must not import
`math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.

## Public Surface And Example

Run the named surface-only gate when you only want the public API/docs/source-contract proof:

```sh
make -C core core-math-api-surface-smoke
```

Run the named module smoke when you want the public math gate:

```sh
make -C core core-math-smoke
```

Run the named facade-only overview smoke when you only want the consumer compile/run proof:

```sh
make -C core core-math-overview-local-smoke
```

`core-math-api-surface-smoke` in `core/Makefile` wraps
`make -C core/tests/nextpas.core.math/test_api_surface clean test` through a stable owner-level
entrypoint. The checker also locks required behavior-test runner markers for the public API groups,
so a public surface entry cannot silently lose its focused behavior-test coverage.
`core-math-overview-local-smoke` wraps
`make -C core/examples/nextpas.core.math/math_overview clean run` through the same owner-level
boundary. `core-math-smoke` calls the surface gate first, then reuses the overview gate for the
facade-only consumer proof. The example imports only `nextpas.core.math` and covers vectors, matrices,
quaternions, transforms, easing, deterministic random state, and noise.

Run the named facade-only consumer gate when you only want the canonical public consumer contract:

```sh
make -C core core-math-facade-local-smoke
```

`core-math-facade-local-smoke` wraps
`make -C core/tests/nextpas.core.math/test_facade clean test` through the same owner-level
boundary, so the direct facade-consumer proof stays independently repeatable instead of being tied
to the trig-specific gate.

Run the named symbol-scope gate when you want to prove `nextpas.core.math` still coexists cleanly
with `nextpas.core.simd.mathutil`:

```sh
make -C core core-math-symbol-scope-local-smoke
```

`core-math-symbol-scope-local-smoke` wraps
`make -C core/tests/nextpas.core.math/test_symbol_scope clean test` through the same owner-level
boundary, so the common-symbol namespace contract no longer depends on a direct subproject command.

## Scalar And Trig

Constants:

- `PI_VALUE`
- `TWO_PI`
- `HALF_PI`
- `DEG_TO_RAD`
- `RAD_TO_DEG`

Scalar helpers:

- Overflow checks: `IsAddOverflow`, `IsMulOverflow`
- Bounds and interpolation: `Min`, `Max`, `Clamp`, `Lerp`, `InverseLerp`, `Wrap`, `SmoothStep`
- Integer-like float operations: `Floor`, `Ceil`, `Round`, `Trunc`, `Frac`
- Sign and predicates: `Abs`, `Sign`, `IsNaN`, `IsInfinite`, `FloatEquals`, `FloatIsZero`
- Angle conversion: `DegToRad`, `RadToDeg`
- Number theory and geometry helpers: `GCD`, `LCM`, `Hypot`, `Fmod`

`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.
`Wrap` uses a half-open `[minimum, maximum)` interval, preserves equal-bound behavior by returning the minimum, maps the maximum endpoint back to the minimum, rejects reversed bounds, requires value, minimum, and maximum to be finite, and finite inputs return a finite value in range even when range or delta intermediates are not representable as finite `Double`.
`Lerp`, `InverseLerp`, and `SmoothStep` keep huge finite opposite-sign midpoint interpolation finite; `InverseLerp` returns 0 for equal bounds, and `SmoothStep` propagates NaN values before edge validation, requires finite edges with `EArgumentError`, and preserves the documented equal-edge step boundary behavior.

`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.

`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.

`Floor`, `Ceil`, `Round`, `Trunc`, and `Frac` reject `NaN`, positive or negative infinity, and finite values outside the Int64 conversion range with `EArgumentError`; `Round` uses ties away from zero, while `Frac` uses truncation semantics and preserves signed-zero zero results.
`Sign` propagates NaN, preserves signed zero, and maps infinities to `+/-1`; `DegToRad` and `RadToDeg` propagate NaN and infinities while preserving signed zero, and `RadToDeg` maps finite overflow to signed infinity.
`Abs` normalizes negative zero to positive zero; `Fmod` preserves the dividend sign for zero results, returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite `Fmod` inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN, returns NaN for NaN-only inputs, and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.

Trig helpers:

- Trig: `Sin`, `Cos`, `Tan`, `ArcSin`, `ArcCos`, `ArcTan`, `ArcTan2`
- Exponential and logarithmic: `Exp`, `Ln`, `Log2`, `Log10`
- Power helpers: `Power`, `Sqrt`

`Sin`, `Cos`, and `Tan` propagate `NaN` and return `NaN` for positive or negative infinity; `Sin` and `Tan` preserve signed zero.
`ArcSin` preserves signed zero; `ArcSin` and `ArcCos` return `NaN` for `NaN` or values outside `[-1, 1]`. `ArcTan` preserves signed zero, maps infinities to `+/-PI/2`, and returns `NaN` for `NaN`. `ArcTan2` returns `NaN` for `NaN` inputs and explicitly preserves signed-zero and infinite-quadrant behavior.
`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.
`Power` preserves negative-zero sign only for odd integer exponents: positive odd exponents return
`-0`, and negative odd exponents return negative infinity. Non-odd zero-base exponents follow the
positive-zero / positive-infinity zero-base behavior. Except for exponent `0`, a NaN exponent takes
priority over zero-base handling, so `0^NaN` and `-0^NaN` return NaN.
`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite
values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`; log identities preserve exact
`+0` for input `1` and exact `1` for `Log2(2)` and `Log10(10)`.
`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves
signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.
`Sqrt` of positive finite maximum, minimum-normal, and minimum-subnormal inputs returns a positive finite result, and squaring that result stays close to the original input instead of flushing to zero; negative minimum-subnormal inputs return `NaN`.
Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.
`Power` returns `1` for base `+1` before NaN-exponent handling and for exponent `0` before NaN-base handling, while exponent `1` preserves the input value exactly after NaN-exponent/base checks. Nonzero NaN bases return `NaN`;
infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases
follow exponent sign and odd/even sign rules. `Power` returns `NaN` for negative finite bases with
non-integer exponents instead of entering host logarithm domain errors.

Most scalar and trig helpers have both `Single` and `Double` overloads. Integer helper overloads are
limited to the signed and unsigned sizes declared in the source interface.

## Vectors

Public vector types:

- `TVec2f`, `TVec3f`, `TVec4f`
- `TVec2d`, `TVec3d`, `TVec4d`

Vectors are packed records with value semantics. They expose named fields and indexed `Data` aliases.
Use `Create` or `Zero` to construct values.

Common vector operations:

- Arithmetic operators: `+`, `-`, unary `-`
- Scalar operators: vector times scalar, scalar times vector, vector divided by scalar
- Component helpers: `MulComponents`, `DivComponents`
- Measures: `Dot`, `LengthSqr`, `Length`
- Interpolation and comparison: `Lerp`, `Equals`
- Normalization: `Normalize`

`TVec3f` and `TVec3d` also provide `Cross`. Zero vector normalization returns zero.
Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`,
`TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without
overflowing the intermediate squared length.
`LengthSqr` also uses a non-throwing scaled path for huge finite inputs; below-overflow results stay finite, and if the true squared length is outside the target float range, it returns `+Inf` instead of raising an FPU overflow exception.
`Dot` uses the same finite scaling strategy: huge finite inputs do not raise intermediate FPU
overflow, exact finite cancellation stays finite, and true out-of-range results return signed infinity.
`Cross` uses stable finite intermediate paths for huge finite `TVec3f` and `TVec3d` inputs:
finite true components stay finite instead of becoming `NaN` through intermediate overflow,
and true out-of-range components return signed infinity.
`Data` aliases are read/write views over `X/Y/Z/W`, so indexed writes update the named fields.
Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by
`Normalize`.
Vector scalar division and `DivComponents` reject zero, NaN, and infinite divisors with `EArgumentError`.

## Matrices

Public matrix types:

- `TMat3f`, `TMat4f`
- `TMat3d`, `TMat4d`

Matrices are packed records with column-major storage:

```pascal
M.Data[Column, Row]
```

Use `Items[Column, Row]`, `Rows[Row]`, and `Columns[Column]` for explicit access. `Items` is the
default property. `Rows` and `Columns` are read/write views over the same backing storage, so
setter writes update the shared column-major matrix data rather than a detached copy.

Matrix operations:

- Constructors: `Create`, `Zero`, `Identity`
- Arithmetic operators: `+`, `-`, unary `-`
- Scalar multiplication: matrix times scalar and scalar times matrix
- Geometry multiplication: matrix times vector, matrix times matrix
- Transforms: `Transpose`
- Determinant and inverse: `Determinant`, `TryInverse`, `Inverse`
- Comparison: `Equals`

`TryInverse` is epsilon-based: it returns `False` for singular, numerically singular, and
non-finite matrices and sets `AInverse` to `Zero`. `Inverse` raises `EArgumentError` for the same
inputs. A non-zero determinant alone does not guarantee that inverse APIs will succeed if the pivot
falls within the precision threshold.
Matrix inverse failure is fail-close: `TryInverse` treats singular and numerically singular
matrices, plus matrices containing `NaN` or infinity, the same: it returns `False`, zeroes the
failed `out` matrix, and `Inverse` raises `EArgumentError` on the same inputs.
Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on
the previous contents of the destination matrix and fully rewrites it before returning `True`.

## Quaternions

Public quaternion types:

- `TQuatf`
- `TQuatd`

Quaternions are packed records with vector part `X`, `Y`, `Z` and real part `W`. They expose indexed
`Data` aliases.

Quaternion operations:

- Constructors: `Create`, `Identity`, `FromAxisAngle`
- Composition: quaternion multiplication
- Interpolation: `Slerp`, `Nlerp`
- Conversion: `ToAxisAngle`, `ToRotationMatrix`
- Vector rotation: `Rotate`
- Utility operations: `Conjugate`, `Normalize`, `Equals`

Zero quaternion normalization returns identity.
`Equals` is a component-wise epsilon comparison on quaternion storage. It does not canonicalize
opposite-sign equivalent rotations, and negative epsilon returns `False`.
`Slerp` and `Nlerp` normalize their source quaternions before interpolation, so positive scaling of
equivalent input rotations does not change the result.
`Slerp` and `Nlerp` also follow the shortest rotational path: opposite-sign equivalent endpoints are
treated as the same rotation instead of forcing the long arc.
Finite interpolation factors outside `[0, 1]` are not clamped: `Slerp` and `Nlerp` extrapolate
through the same formulas instead of snapping to either endpoint.
The interpolation endpoints follow the same normalization and shortest-path rules: `AT = 0`
returns the normalized start rotation, and `AT = 1` returns the normalized end rotation after any
opposite-sign canonicalization.
`Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared axis
and interpolate the small remaining angle instead of collapsing or taking a long arc.
`Slerp` and `Nlerp` reject NaN and infinite interpolation factors with `EArgumentError`.
`FromAxisAngle` normalizes its axis, returns identity for a zero axis, and rejects NaN and infinite
axis components or angles with `EArgumentError`.
`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the
intended rotation.
Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd`
inputs preserve direction instead of collapsing through an overflowing squared length.
Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by
`Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.
`Rotate` rejects NaN and infinite vector components with `EArgumentError`.
`ToAxisAngle` normalizes its quaternion first and returns a canonical shortest-angle axis-angle
pair. Opposite-sign equivalent quaternions map to the same output; zero rotation returns axis `+Z`
with angle `0`, and exact half-turn outputs, including `FromAxisAngle(..., PI)` paths, use a
stable axis hemisphere so `angle = PI` remains canonical too.
`ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and
`AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous
contents.
Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first, then
applies the left operand `A`, and non-collinear rotations are non-commutative.
`ToRotationMatrix` and `Rotate` normalize their quaternion first, so positive scaling of an
equivalent input rotation does not change the result.

## Transforms

Transform builders return `TMat4f` for `Single` inputs and `TMat4d` for `Double` inputs:

- Projection: `Ortho`, `Perspective`
- View: `LookAt`
- Model: `Translate`, `Scale`, `RotateX`, `RotateY`, `RotateZ`
- 2D camera: `Camera2D`

The convention is column-major matrices and column vectors. Translation lives in column 3. Local
composition uses `Translate * Rotate * Scale`, and projection/view/model composition uses
`Projection * View * Model`.

`Perspective` is right-handed, looks down `-Z`, and uses NDC `[-1, +1]`. `Camera2D` uses screen-space
positive Y down. `Camera2D` larger zoom values magnify the view, so the same world-space offset maps
farther in NDC on both axes.
`Ortho` requires non-zero width, height, and depth. `Perspective` requires positive FOV, aspect,
and near plane, plus `far > near`. `LookAt` requires `eye <> target` and an `up` vector that is not
parallel to forward. `Camera2D` requires positive zoom and positive viewport dimensions.
Reversed non-zero `Ortho` bounds are valid and flip the corresponding axis; `Camera2D` uses that
reversed Y range intentionally to keep screen-space `+Y down`.
`LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while
flipping `up` to the opposite direction changes roll.
All transform builders reject NaN and infinite inputs with `EArgumentError`, and geometry guard
failures also raise `EArgumentError`.

## Easing

`TEasingFunction` is:

```pascal
TEasingFunction = function(const AT: Double): Double;
```

Public easing functions:

- Linear: `EaseLinear`
- Quad: `EaseInQuad`, `EaseOutQuad`, `EaseInOutQuad`
- Cubic: `EaseInCubic`, `EaseOutCubic`, `EaseInOutCubic`
- Quart: `EaseInQuart`, `EaseOutQuart`, `EaseInOutQuart`
- Expo: `EaseInExpo`, `EaseOutExpo`, `EaseInOutExpo`
- Elastic: `EaseInElastic`, `EaseOutElastic`, `EaseInOutElastic`
- Back: `EaseInBack`, `EaseOutBack`, `EaseInOutBack`
- Bounce: `EaseInBounce`, `EaseOutBounce`, `EaseInOutBounce`

All easing functions reject NaN and infinite inputs with `EArgumentError`. Finite inputs outside
`[0, 1]` are not clamped; they extrapolate according to the same closed-form or piecewise formulas
used in-range.
`EaseOutBounce` follows the documented four-piece bounce ladder, and the direct branch tests lock
representative points in each non-endpoint segment.

## Random And Noise

Random state is explicit:

- `TRandomState`
- `TRandomGen`
- `TNoiseGen`

`NextInt` samples the full signed `Integer` domain. It is equivalent in public contract to
`NextIntRange(Low(Integer), High(Integer))`, so forced zero/max states hit the exact
`Low(Integer)` / `High(Integer)` boundaries.
`NextIntRange` uses rejection sampling for non-power-of-two span widths, so inclusive integer
ranges stay unbiased instead of inheriting modulo bias from raw `UInt64` samples.

`TRandomGen` methods:

- Seeding and state: `Create`, `SetSeed`, `State`
- Uniform values: `NextInt`, `NextIntRange`, `NextFloat`, `NextFloatRange`, `NextDouble`
- Distributions and helpers: `NextBool`, `NextGaussian`, `NextVec2InCircle`, `NextVec2OnCircle`
- Dice and collections: `Roll`, `RollMultiple`, `WeightedChoice`, `Shuffle`

`NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single`
bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.

`TNoiseGen` methods:

- Seeding: `Create`, `SetSeed`
- Noise: `Noise1D`, `Noise2D`, `Noise3D`
- Fractal Brownian motion: `FBM1D`, `FBM2D`, `FBM3D`

There is no public global random or noise singleton. Seed `0` maps to a deterministic default seed.
Invalid integer ranges and reversed or non-finite float ranges raise `EArgumentError`. `NextBool`
rejects non-finite probabilities and clamps finite probabilities into false or true behavior. Dice
helpers return `0` for non-positive dice or sides, and `RollMultiple` rejects positive
`ADice * ASides` combinations that would exceed `Integer`. `WeightedChoice` rejects empty,
non-finite, negative, and all-zero weights. FBM noise rejects non-positive octaves and non-finite or
non-positive lacunarity and gain. `Noise1D`/`2D`/`3D` and `FBM1D`/`2D`/`3D` reject NaN and infinite
coordinate inputs with `EArgumentError`, and `FBM1D`/`2D`/`3D` also reject finite
coordinate/lacunarity combinations that would make octave coordinates non-finite and finite gain
combinations that would make octave amplitudes or accumulated results non-finite.
`WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on
zero-weight prefixes.
`NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of
producing NaN or infinity.
Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like
`-0.25` and `255.75` stay equivalent for the same seeded generator.
Noise and FBM operate on the stored `Double` coordinate value. At magnitudes around `2^52` and
larger, sub-unit coordinate deltas collapse to the same representable `Double`, so those calls use
stable lattice-equivalent semantics rather than raising an owner-level error.

## Verification

Run the named full local math suite with:

```sh
make -C core core-math-full-local-smoke
```

It wraps the current owner-level full math focused gate:

```sh
make -C core/tests/nextpas.core.math clean test
```

Run the focused math gate after changing public API, behavior, tests, or docs:

```sh
make -C core/tests/nextpas.core.math clean test
```

Run the internal seam correctness smoke on the current host with:

```sh
make -C core core-math-impl-simd-local-smoke
```

It wraps the targeted implementation-only correctness gate:

```sh
make -C core/tests/nextpas.core.math/test_impl_simd clean test
```

Run the Win64 compile-only internal SIMD seam gate when the local FPC install provides the Win64
target RTL:

```sh
make -C core core-math-impl-simd-win64-compile-smoke
```

`core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.

For landing review, also run:

```sh
make hygiene
git diff --check
git status --short --branch
```

Run the local trig link smoke on the current host with:

```sh
make -C core core-math-trig-local-smoke
```

Run the Win64 compile-only trig gate when the local FPC install provides the Win64 target RTL:

```sh
make -C core core-math-trig-win64-compile-smoke
```

It bundles `test_trig` plus the facade-consumer proof as the current-host local link proof. macOS
and Windows trig link smokes remain host-gated and must be reported separately until those hosts
run equivalent checks. The owner-level target first reruns `core-math-api-surface-smoke`, then
reuses `core-math-facade-local-smoke`, so the current-host proof keeps the source-surface
`external 'm'` and consumer-boundary checks coupled to the link smoke without losing an
independently callable facade-consumer gate.
`core-math-trig-win64-compile-smoke` is compile-only and uses `-Cn -Twin64 -Px86_64`; it proves the
current facade/trig route compiles for Win64 with this toolchain, but it is not a Windows host
link/run proof and it does not cover macOS.
Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.
M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.
