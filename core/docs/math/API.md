# nextpas.core.math API

> **最后更新**：2026-08-31（同步 `CONTRACT.md` v1.5.2；证据链刷新：`2026-08-31 17 PROJECTS ~273 tests 0 fail heaptrc 0`）

Use `nextpas.core.math` as the default import for application code:

```pascal
uses
  nextpas.core.math;
```

Use a narrower submodule only when a file intentionally depends on one math family, such as
`nextpas.core.math.vec` or `nextpas.core.math.random`.

**Application vs kernel:** batch/vector math for apps goes through **math** (`Batch*`,
`TVec*`). Pointer-level `Array*` / `VecF32x*` in `nextpas.core.simd` are **kernel/expert**
APIs (no open-array bounds; caller owns length). Do not use simd as the default app import.

### Batch open-array length policy (usability)

Applies to **all** open-array Batch APIs: scalar (`Batch*F32/F64`) **and** vector
(`BatchDot` / `BatchNormalize` / `BatchTransform` / `BatchLerp` / `BatchClamp` on `TVec*`).

- All related open-array arguments must have the **same Length** when any is non-empty.
- Mismatched non-empty lengths → `EArgumentError` (`Batch: array lengths must match …`).
- Any empty side → return `0`, no raise.
- Return value is the processed count (equal length, or 0).
- Escape hatch for legacy truncate-min: compile with `{$DEFINE NEXTPAS_MATH_BATCH_TRUNCATE_MIN}`.

### Natural log naming

| math (public) | simd leaf | meaning |
|---------------|-----------|---------|
| `BatchLnF32` / `BatchLnF64` | `ArrayLogF32` / `ArrayLogF64` | natural log |
| `BatchLogF32` / `BatchLogF64` | (alias of Ln) | same as Ln |
| `BatchLog2*` / `BatchLog10*` | `ArrayLog2*` / `ArrayLog10*` | base 2 / 10 |

`TryBatchLnF32` / `TryBatchLnF64`: return `False` without writing if lengths differ or any
element is non-positive / non-finite; otherwise run Ln and set `ACount`.

## Public Modules

- `nextpas.core.math` is the facade. It re-exports the public scalar, trig, vector, matrix,
  quaternion, transform, easing, and random API. Noise is exposed through
  `nextpas.core.math.random.TNoiseGen`; there is no public `nextpas.core.math.noise` unit.
- `nextpas.core.math.base` owns the shared point types and canonical compile-time `Double`
  constants.
- `nextpas.core.math.scalar` owns numeric helpers, float predicates, interpolation, angle
  conversion, and integer overflow helpers.
- `nextpas.core.math.trig` owns trigonometric, exponential, logarithmic, power, square-root, and
  related transcendental helpers. It also exposes the trig-facing constant aliases described
  below. Angle conversion belongs to `nextpas.core.math.scalar`.
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
The source-contract gate treats direct `nextpas.core.simd` imports in public math source units as
the same prohibited cutover.
`bench_simd_seam` may import the math-owned internal SIMD seam only to measure that seam; it must
not import private SIMD backend, dispatch, CPUInfo, direct, dataplane, or intrinsic units.

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
The canonical facade consumer test imports `nextpas.core.math` as its only math unit; support
imports such as `SysUtils`, `nextpas.core.testing`, and `nextpas.core.errors` do not count as math
API imports.

Run the named symbol-scope gate when you want to prove `nextpas.core.math` still coexists cleanly
with `nextpas.core.simd.mathutil`:

```sh
make -C core core-math-symbol-scope-local-smoke
```

`core-math-symbol-scope-local-smoke` wraps
`make -C core/tests/nextpas.core.math/test_symbol_scope clean test` through the same owner-level
boundary, so the common-symbol namespace contract no longer depends on a direct subproject command.

Run the named leak-local gate when you want the focused heaptrc-backed runtime smoke set without
promoting to the full math aggregate:

```sh
make -C core core-math-leak-local-smoke
```

`core-math-leak-local-smoke` runs facade, scalar, trig, vector, matrix, quaternion, SIMD seam,
random, and noise local tests through stable owner-level targets or focused subproject Makefiles.
It intentionally avoids examples, benchmarks, compile-only host gates, and the full math aggregate.

## Scalar And Trig

The public constant entry points are:

| Unit | Constants | Role |
| --- | --- | --- |
| `nextpas.core.math.base` | `PI_VALUE`, `TWO_PI`, `HALF_PI`, `QUARTER_PI`, `DEG_TO_RAD`, `RAD_TO_DEG` | Canonical declarations |
| `nextpas.core.math.trig` | `PI_VALUE`, `TWO_PI`, `HALF_PI` | Compile-time aliases to `math.base` |
| `nextpas.core.math` | `PI_VALUE`, `TWO_PI`, `HALF_PI`, `DEG_TO_RAD`, `RAD_TO_DEG` | Compile-time facade aliases to `math.base` |

Canonical constant ownership: `nextpas.core.math.base` is the only unit that declares the numeric
literals. `nextpas.core.math.trig` and `nextpas.core.math` expose only compile-time aliases to those
base constants.

The canonical declarations use the ordinary-constant form `PI_VALUE = Double(...);`. The explicit
conversion keeps the expression type at `Double` instead of allowing a wider real type to be
inferred. An alias such as `PI_VALUE = nextpas.core.math.base.PI_VALUE;` is legal because its source
is an ordinary constant. FPC typed constants (`PI_VALUE: Double = ...;`) cannot be used as the
right-hand side of that alias. `{$J+}` and `{$J-}` only control typed-constant writability and do not
change this rule.

Scalar helpers:

- Overflow checks: `IsAddOverflow`, `IsMulOverflow`
- Bounds and interpolation: `Min`, `Max`, `Clamp`, `Lerp`, `InverseLerp`, `Wrap`, `SmoothStep`
- Integer-like float operations: `Floor`, `Ceil`, `Round`, `Trunc`, `Frac`
- Sign and predicates: `Abs`, `Sign`, `IsNaN`, `IsInfinite`, `FloatEquals`, `FloatIsZero`
- Angle conversion: `DegToRad`, `RadToDeg`
- Number theory and geometry helpers: `GCD`, `LCM`, `Hypot`, `Fmod`

`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.
`Wrap` uses a half-open `[minimum, maximum)` interval, preserves equal-bound behavior by returning the minimum, maps the maximum endpoint back to the minimum, rejects reversed bounds, requires value, minimum, and maximum to be finite, and finite inputs return a finite value in range even when range or delta intermediates are not representable as finite `Double`. In-range signed zero keeps its sign.
`Lerp`, `InverseLerp`, and `SmoothStep` keep huge finite opposite-sign midpoint interpolation finite; `Lerp` preserves endpoint identity for `t=0` and `t=1` before endpoint arithmetic can pollute non-finite endpoints, `Lerp` propagates a NaN `t`, `InverseLerp` returns 0 for equal bounds, and `SmoothStep` propagates NaN values before edge validation, rejects reversed finite edges with `EArgumentError`, requires finite edges with `EArgumentError`, clamps infinite values to the low or high endpoint, and preserves the documented equal-edge step boundary behavior.

`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.
`Min` and `Max` order infinities after NaN handling: negative infinity is less than finite values and positive infinity, positive infinity is greater than finite values and negative infinity, and finite values keep normal numeric ordering.

`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.

`Floor`, `Ceil`, `Round`, `Trunc`, and `Frac` reject `NaN`, positive or negative infinity, and finite values outside the Int64 conversion range with `EArgumentError`; `Round` uses ties away from zero, while `Frac` uses truncation semantics and preserves signed-zero zero results.
`Sign` propagates NaN, preserves signed zero, and maps infinities to `+/-1`; `DegToRad` and `RadToDeg` propagate NaN and infinities while preserving signed zero. `DegToRad` keeps maximum finite inputs finite with their original sign, and `RadToDeg` maps finite overflow to signed infinity.
`Abs` normalizes negative zero to positive zero; `Fmod` preserves the dividend sign for zero results, returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite `Fmod` inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN, returns NaN for NaN-only inputs, and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.
`UInt32` overflow helpers report `High(UInt32)+1` and `High(UInt32)*2` as overflow; `High(UInt32)-1+1` and zero-times-high multiplication in either order return `False` without divide-by-zero.
`GCD` and `LCM` normalize signs and return non-negative `Int64` results; representable `Low(Int64)`/`High(Int64)` boundary cases succeed, zero LCM returns `0` before overflow checks, and unrepresentable results raise `EArgumentError`.

Statistical helpers: `Sum`, `SumToDouble`, `SumInt`, `Mean`, `Variance`, `PopnVariance`, `StdDev`, `PopnStdDev`, `TotalVariance`, `SumSquaredDeviations`.

Batch operations: `BatchDot`, `BatchNormalize`, `BatchTransform`, `BatchLerp`, `BatchClamp` (vector batches); `BatchSinF32`, `BatchCosF32`, `BatchSinCosF32`, `BatchTanF32`, `BatchExpF32`, `BatchLnF32`, `BatchLogF32`, `TryBatchLnF32`, `BatchLog10F32`, `BatchLog2F32`, `BatchSqrtF32`, `BatchAbsF32`, `BatchNegF32`, `BatchCeilF32`, `BatchFloorF32`, `BatchRoundF32`, `BatchTruncF32`, `BatchLerpF32`, `BatchClampF32`, `BatchScaleOffsetF32` (F32 scalar batches); `BatchSinF64`, `BatchCosF64`, `BatchSinCosF64`, `BatchTanF64`, `BatchExpF64`, `BatchLnF64`, `BatchLogF64`, `TryBatchLnF64`, `BatchLog10F64`, `BatchLog2F64`, `BatchSqrtF64`, `BatchAbsF64`, `BatchNegF64`, `BatchCeilF64`, `BatchFloorF64`, `BatchRoundF64`, `BatchTruncF64`, `BatchLerpF64`, `BatchClampF64`, `BatchScaleOffsetF64` (F64 scalar batches, same core set).

Public `Batch*F64` is a thin open-array facade: **equal lengths required** (see length policy
above); empty → `0`; work dispatches to simd `Array*F64`. Extra batch helpers such as
`BatchAtan2F64` / `BatchHypotF64` live on `nextpas.core.math.batch` but are not re-exported
from the root facade (same policy as the F32 extended set). Also: `BatchLogF32/F64` (alias of
`BatchLn*`) and `TryBatchLnF32/F64`.

### SIMD Batch Operations

`nextpas.core.math.batch.simd` provides SIMD-optimized variants of scalar batch operations.
These use SSE/AVX intrinsics via `nextpas.core.simd` for 4-wide F32 and 2-wide F64 processing, with scalar
fallback for remaining elements when the count is not a multiple of the lane width.

SIMD batch functions mirror the scalar batch signatures exactly:

- `BatchSinSimdF32`, `BatchCosSimdF32`, `BatchTanSimdF32`
- `BatchSinCosSimdF32` — computes both sin and cos in a single pass (two output arrays)
- `BatchExpSimdF32`, `BatchLnSimdF32`, `BatchLog2SimdF32`, `BatchLog10SimdF32`
- `BatchSqrtSimdF32` — uses `SQRTPS`/`VSQRTPS` hardware instruction
- `BatchAbsSimdF32` — uses `ANDPS` with sign-bit mask
- `BatchNegSimdF32` — uses `XORPS` with sign-bit mask
- `BatchCeilSimdF32`, `BatchFloorSimdF32`, `BatchRoundSimdF32`, `BatchTruncSimdF32` — use SSE4.1 `ROUNDPS`
- `BatchLerpSimdF32` — uses FMA where available (`fma(t, b-a, a)`)
- `BatchClampSimdF32` — uses `MINPS`+`MAXPS`
- `BatchScaleOffsetSimdF32` — uses FMA (`fma(input, scale, offset)`)
- Matching `Batch*SimdF64` family over simd `Array*F64` (same core set as public F64)

The SIMD suffix signals the dispatch path; the public facade `nextpas.core.math` does not re-export
these functions. They are available through direct import of `nextpas.core.math.batch.simd`.

A benchmark harness (`bench_batch_simd`) compares SIMD vs scalar paths across array sizes
(64, 1024, 16384). Operations with true SIMD intrinsics (Sqrt, Abs, Lerp, Clamp, Ceil, Floor,
Round, Trunc, ScaleOffset) show measurable speedup; operations that delegate to scalar `Sin`/`Cos`/
`Exp` in both paths (no SIMD transcendental approximation yet) show no gain. Run the benchmark with:

```sh
make -C core/tests/nextpas.core.math/bench_batch_simd clean run
```

`SumSquaredDeviations` is an alias for `TotalVariance` (sum of squared deviations from mean).

Trig helpers:

- Trig: `Sin`, `Cos`, `Tan`, `ArcSin`, `ArcCos`, `ArcTan`, `ArcTan2`
- Exponential and logarithmic: `Exp`, `Ln`, `Log2`, `Log10`
- Power helpers: `Power`, `Sqrt`

`Sin`, `Cos`, and `Tan` propagate `NaN` and return `NaN` for positive or negative infinity; `Sin` and `Tan` preserve signed zero. Exact `Tan(+/-HALF_PI)` returns signed infinity for both `Double` and `Single`, while nearby finite inputs remain finite-side results. Large finite circular inputs are guarded as finite and period-stable within broad host-portable tolerances, not as cross-libm bit-exact reductions.
`ArcSin` preserves signed zero; `ArcSin` and `ArcCos` return `NaN` for `NaN` or values outside `[-1, 1]`. Near `+/-1`, inverse trig results stay finite, remain inside the endpoint range, and stay close to the mathematical endpoint. `ArcTan` preserves signed zero, maps infinities to `+/-PI/2`, and returns `NaN` for `NaN`. `ArcTan2` returns `NaN` for `NaN` inputs and explicitly preserves signed-zero and infinite-quadrant behavior.
`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.
`Power` preserves negative-zero sign only for odd integer exponents: positive odd exponents return
`-0`, and negative odd exponents return negative infinity. Non-odd zero-base exponents follow the
positive-zero / positive-infinity zero-base behavior, including negative zero with fractional
exponents: positive fractional exponents return `+0`, and negative fractional exponents return
`+Inf`. Except for exponent `0`, a NaN exponent takes priority over zero-base handling, so
`0^NaN` and `-0^NaN` return NaN.
`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite
values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`; log identities preserve exact
`+0` for input `1` and exact `1` for `Log2(2)` and `Log10(10)`.
`Ln`, `Log2`, and `Log10` accept positive subnormal `Single` and `Double` inputs: results stay finite negative, with `Log2` returning exact exponent positions for the minimum positive subnormal values (`-149` for `Single`, `-1074` for `Double`).
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
- Component helpers: `MulComponents`, `ComponentDiv`
- Dimension conversion: `Vec3fExtend`/`Vec3dExtend` (Vec3→Vec4), `Vec4fTruncate`/`Vec4dTruncate` (Vec4→Vec3)
- Measures: `Dot`, `LengthSqr`, `Length`
- Interpolation and comparison: `Lerp`, `Equals`
- Normalization: `Normalize`

`TVec3f` and `TVec3d` also provide `Cross`. Zero vector normalization returns zero.
Vector `Lerp` delegates component-wise to scalar `Lerp`, so vector interpolation inherits scalar huge-finite stability and signed-zero behavior for every lane.
Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`,
`TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without
overflowing the intermediate squared length.
`LengthSqr` also uses a non-throwing scaled path for huge finite inputs; below-overflow results stay finite, and if the true squared length is outside the target float range, it returns `+Inf` instead of raising an FPU overflow exception.
`Dot` applies the same finite scaling strategy: huge finite inputs do not raise intermediate FPU
overflow, exact finite cancellation stays finite, and true out-of-range results return signed infinity.
`Cross` uses stable finite intermediate paths for huge finite `TVec3f` and `TVec3d` inputs:
finite true components stay finite instead of becoming `NaN` through intermediate overflow,
and true out-of-range components return signed infinity.
`Data` aliases are read/write views over `X/Y/Z/W`, so indexed writes update the named fields.
Vector measure methods are non-throwing for non-finite inputs: NaN operands produce NaN,
infinite operands produce `+Inf` where no NaN is present, and `Dot`/`Cross` use raw IEEE
fallback for non-finite operands, so indeterminate products such as `0 * Inf` produce NaN.
This contract is locked across representative `TVec2*`, `TVec3*`, and `TVec4*` single/double
measure paths, including `Length`, `LengthSqr`, and `Dot` NaN/+Inf propagation.
Signed-zero behavior is canonicalized only at measure/normalization boundaries: zero-vector
`Normalize` returns positive-zero components, exact-zero `Dot` returns `+0`, and `Data` aliases
preserve stored signed-zero bit patterns.
The focused coverage matrix is representative source/runtime truth, not a full Cartesian proof
of every type-operation-special-value combination.
Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by
`Normalize`.
Vector scalar division and `ComponentDiv` reject zero, NaN, and infinite divisors with `EArgumentError`.
Vector `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.

### Batch Operations

Batch operations process vector arrays for bulk computation:

- `BatchDot`: computes dot products of two vector arrays into a results array
- `BatchNormalize`: normalizes a vector array in-place, or from source to dest array
- `BatchTransform`: transforms a vector array by a matrix
- `BatchLerp`: interpolates between two vector arrays
- `BatchClamp`: clamps a vector array to min/max bounds

**F32 core set** (public overloads): `TVec2f`/`TVec3f`/`TVec4f` for Dot and Normalize-in-place;
`TVec3f` source→dest Normalize; `TMat3f×TVec2f` and `TMat4f×TVec3f` Transform; `TVec3f` Lerp/Clamp.
Hot `TVec3f`/`TVec4f` paths may use `vec.batch.simd` (public simd only).

**Double minimal parity (M-V1)**: same core op list for `TVec2d`/`TVec3d`/`TVec4d` with
`Double` results / `T` factor, plus `TMat3d×TVec2d` and `TMat4d×TVec3d` Transform.
Double implementations use value-type element loops (`TVec*d` methods / `TMat4d.MultPoint`);
they do **not** import private simd backends.

All batch functions return the number of processed elements. **Equal lengths required** across
inputs/outputs when non-empty (raise `EArgumentError` on mismatch); empty → `0`.

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
Matrix `Equals` applies scalar `FloatEquals` element-wise: NaN elements and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.

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
Quaternion `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.
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

- Seeding and state: `Init`, `SetSeed`, `State`
- Uniform values: `NextInt`, `NextIntRange`, `NextFloat`, `NextFloatRange`, `NextDouble`
- Distributions and helpers: `NextBool`, `NextGaussian`, `NextVec2InCircle`, `NextVec2OnCircle`
- Dice and collections: `Roll`, `RollMultiple`, `WeightedChoice`, `Shuffle`

`TRandomGen` is a record value type. Initialize it with `TRandomGen.Init`; it does not require
manual `Free`.

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

## FPU Exception Control

`nextpas.core.math` provides FPU exception mask control for x86_64 **MXCSR (SSE) and
x87 control word** (kept in lockstep; SIMD batch scalar tails use `fsin`/`fyl2x`).
On FPC host builds, `softfloat_exception_mask` is updated as well so `System.Sin`/`Ln`
paths stay consistent. This replaces `Math.GetExceptionMask`/`SetExceptionMask`
without any FPC `Math` unit dependency.

```pascal
uses
  nextpas.core.math;

var
  LOldMask: TFPUExceptionMask;
begin
  LOldMask := GetExceptionMask;
  try
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                      exOverflow, exUnderflow, exPrecision]);
    { ... FPU-intensive work with exceptions masked ... }
  finally
    SetExceptionMask(LOldMask);
  end;
end;
```

### IEEE special values

FPC `Math`-compatible names on the math facade / `math.scalar` (Double payloads,
bit-pattern construction, no exception-raising division):

- `NaN` — quiet NaN
- `Infinity` — positive infinity
- `NegInfinity` — negative infinity

### Types

- `TFPUException` — Enum of FPU exception flags: `exInvalidOp`, `exDenormalized`,
  `exZeroDivide`, `exOverflow`, `exUnderflow`, `exPrecision`.
- `TFPUExceptionMask` — Set of `TFPUException`.

### Functions

- `GetExceptionMask: TFPUExceptionMask` — Intersection of MXCSR and x87 CW masks.
  Returns empty set `[]` on non-x86_64 targets.
- `SetExceptionMask(AMask: TFPUExceptionMask)` — Sets MXCSR, x87 CW, and (FPC)
  softfloat mask together. No-op on non-x86_64 targets.

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

Run the bounded internal SIMD seam benchmark smoke with:

```sh
make -C core core-math-simd-seam-bench-smoke
```

This smoke caps `bench_simd_seam` with `NEXTPAS_BENCH_MAX_ITERS=20000`; it proves the benchmark
entrypoint and negative public-cutover marker stay runnable, not that public SIMD cutover is
approved or that profiling is complete.

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

| Host truth matrix | Current truth |
| --- | --- |
| Linux current-host runtime | Host truth matrix: Linux current-host runtime is the only local runtime proof. |
| Win64 forced compile | Host truth matrix: Win64 forced compile is compile-only proof; it is not Windows host link, run, heaptrc, or precision proof. |
| Windows host runtime | Host truth matrix: Windows host link/runtime proof is pending. |
| macOS host runtime | Host truth matrix: macOS host link/runtime proof is pending. |
| CI matrix | Host truth matrix: CI matrix proof is pending. |

Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.
M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.


## vec.batch Double coverage (F-013)

| Op family | F32 | Double (minimal parity) |
|-----------|-----|-------------------------|
| Dot | yes | yes (2d/3d/4d) |
| Normalize | yes | yes |
| Transform | yes | yes (core) |
| Lerp / Clamp | yes | yes (TVec3d) |
| Full F32-only extras | yes | **no** — not residual; expand only with consumer demand |

