# nextpas.core.math

`nextpas.core.math` is the framework-owned math entry point for scalar helpers, trigonometry,
vectors, matrices, quaternions, transforms, easing, deterministic random generators, and noise.

Most consumers should use:

```pascal
uses
  nextpas.core.math;
```

Use a submodule directly only when you want a narrower import, for example
`nextpas.core.math.vec` or `nextpas.core.math.random`.

For a grouped public API reference, see [nextpas.core.math API](API.md).

## Surface Gate And Facade Example

Run the named surface-only gate when you only want the public API/docs/source-contract proof:

```sh
make -C core core-math-api-surface-smoke
```

`core/examples/nextpas.core.math/math_overview` is a compilable facade-only example. It imports only
`nextpas.core.math` and demonstrates vector normalization, quaternion rotation, transform
composition, projection/view builders, easing, deterministic random state, and noise.
Run the broader facade smoke when you also want that consumer example proof:

```sh
make -C core core-math-smoke
```

The named `core-math-api-surface-smoke` gate in `core/Makefile` wraps
`make -C core/tests/nextpas.core.math/test_api_surface clean test`.
That surface checker also requires the current behavior-test runner markers for each public API
group, so deleting a required focused behavior test now fails before landing.
Use the named overview-only gate when you only want the facade-consumer proof:

```sh
make -C core core-math-overview-local-smoke
```

`core-math-overview-local-smoke` wraps
`make -C core/examples/nextpas.core.math/math_overview clean run`, and `core-math-smoke`
reuses that named example gate after the surface proof.
Use the named facade-only consumer gate when you only want the canonical public consumer contract:

```sh
make -C core core-math-facade-local-smoke
```

`core-math-facade-local-smoke` wraps
`make -C core/tests/nextpas.core.math/test_facade clean test` through the same owner-level
boundary, so the direct facade-consumer proof no longer depends on a trig-specific gate.
Use the named symbol-scope gate when you want to prove `nextpas.core.math` still coexists cleanly
with `nextpas.core.simd.mathutil`:

```sh
make -C core core-math-symbol-scope-local-smoke
```

`core-math-symbol-scope-local-smoke` wraps
`make -C core/tests/nextpas.core.math/test_symbol_scope clean test` through the same owner-level
boundary, so the common-symbol namespace contract no longer depends on a direct subproject command.

## Public Modules

- `nextpas.core.math`: facade that explicitly re-exports the public math API.
- `nextpas.core.math.scalar`: constants, min/max/clamp, interpolation, rounding, float predicates,
  degree/radian conversion, overflow helpers, `GCD`, `LCM`, `Hypot`, and `Fmod`.
- `nextpas.core.math.trig`: trigonometric and exponential helpers such as `Sin`, `Cos`, `Tan`,
  `ArcSin`, `ArcCos`, `ArcTan2`, `Exp`, `Ln`, `Power`, and `Sqrt`.
- `nextpas.core.math.vec`: value types `TVec2f`, `TVec3f`, `TVec4f`, `TVec2d`, `TVec3d`, and
  `TVec4d`.
- `nextpas.core.math.mat`: value types `TMat3f`, `TMat4f`, `TMat3d`, and `TMat4d`.
- `nextpas.core.math.quat`: value types `TQuatf` and `TQuatd`.
- `nextpas.core.math.transform`: `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`,
  `RotateX`, `RotateY`, `RotateZ`, and `Camera2D`.
- `nextpas.core.math.easing`: `TEasingFunction` plus the `Ease*` function family.
- `nextpas.core.math.random`: `TRandomState`, `TRandomGen`, and `TNoiseGen`.

`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.
`Wrap` uses a half-open `[minimum, maximum)` interval, preserves equal-bound behavior by returning the minimum, maps the maximum endpoint back to the minimum, rejects reversed bounds, requires value, minimum, and maximum to be finite, and finite inputs return a finite value in range even when range or delta intermediates are not representable as finite `Double`.
`Lerp`, `InverseLerp`, and `SmoothStep` keep huge finite opposite-sign midpoint interpolation finite; `InverseLerp` returns 0 for equal bounds, and `SmoothStep` propagates NaN values before equal-edge step-boundary handling while preserving the documented step boundary behavior.

`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.

`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.

Vector `Dot` uses a scaled finite path for huge finite inputs: finite cancellation remains finite,
and true out-of-range results return signed infinity without raising intermediate FPU overflow.

`Floor`, `Ceil`, `Round`, `Trunc`, and `Frac` reject `NaN`, positive or negative infinity, and finite values outside the Int64 conversion range with `EArgumentError`; `Round` uses ties away from zero, while `Frac` uses truncation semantics and preserves signed-zero zero results.
`Abs` normalizes negative zero to positive zero; `Fmod` preserves the dividend sign for zero results; finite `Fmod` inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.

`Sin`, `Cos`, and `Tan` propagate `NaN` and return `NaN` for positive or negative infinity.
`ArcSin` and `ArcCos` return `NaN` for `NaN` or values outside `[-1, 1]`. `ArcTan` preserves signed zero, maps infinities to `+/-PI/2`, and returns `NaN` for `NaN`. `ArcTan2` returns `NaN` for `NaN` inputs and explicitly preserves signed-zero and infinite-quadrant behavior.
`ArcTan2` finite extreme ratios stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.

`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`.

`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.
Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.

`Power` returns `1` for exponent `0` before NaN-base handling. Nonzero NaN bases return `NaN`; infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases follow exponent sign and odd/even sign rules. `Power` returns `NaN` for negative finite bases with non-integer exponents instead of entering host logarithm domain errors.

## Vector, Matrix, And Quaternion Conventions

Math value types are packed records with value semantics. Vectors expose named components and `Data`
aliases. Matrices use column-major storage:

```pascal
M.Data[Column, Row]
```

`Items[Column, Row]` is the default property. `Rows[Row]` and `Columns[Column]` are read/write
views over that same backing storage, so setter writes alias through immediately to the underlying
column-major matrix data.

The transform convention is:

- vectors are column vectors;
- translation lives in column 3;
- transform composition uses `Translate * Rotate * Scale` for local transforms;
- projection/view/model composition uses `Projection * View * Model`;
- perspective is right-handed and looks down `-Z`;
- NDC is `[-1, +1]`;
- `Camera2D` uses screen-space positive Y down.
- `Camera2D` larger zoom values magnify the view, so the same world-space offset maps farther in NDC on both axes.

Builder guard rules are explicit: `Ortho` requires non-zero width, height, and depth;
`Perspective` requires positive FOV, aspect, and near plane plus `far > near`; `LookAt` requires
`eye <> target` and an `up` vector that is not parallel to forward; `Camera2D` requires positive
zoom and positive viewport dimensions.
Reversed non-zero `Ortho` bounds are valid and flip the corresponding axis; `Camera2D` relies on a
reversed Y range to keep screen-space `+Y down`.
`LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while
flipping `up` to the opposite direction changes roll.
Easing functions reject `NaN` and infinite input, and finite inputs outside `[0, 1]` extrapolate
through the same formulas rather than clamping to the unit interval.

Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`,
`TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without
overflowing the intermediate squared length.
`LengthSqr` avoids FPU overflow exceptions for huge finite inputs, keeps below-overflow results finite, and returns `+Inf` when the true squared length is outside the target float range. Vector `Data` aliases write through to `X/Y/Z/W`.
Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by
`Normalize`.
Vector scalar division and `DivComponents` reject zero, NaN, and infinite divisors with `EArgumentError`.
Quaternions store vector part `X`, `Y`, `Z` and real part `W`. Zero quaternion normalization returns
identity; zero vector normalization returns zero. `FromAxisAngle` normalizes its axis, and a zero
axis returns identity instead of a partial rotation. `ToAxisAngle` normalizes first and returns a
canonical shortest-angle axis-angle pair: zero rotation uses axis `+Z`, and exact half-turns,
including `FromAxisAngle(..., PI)` paths, use a stable axis hemisphere so opposite-sign equivalent
quaternions still map to the same output.
Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd`
inputs preserve direction instead of collapsing through an overflowing squared length.
Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by
`Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.
`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the
intended rotation.
`ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and
`AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous
contents.
Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first, then
applies the left operand `A`, and non-collinear rotations are non-commutative.
`ToRotationMatrix` and `Rotate` also normalize first, so positive scaling of the same input
rotation does not change the result.
`Equals` is a component-wise epsilon comparison; it does not canonicalize opposite-sign equivalent
rotations, and negative epsilon returns `False`.
`Slerp` and `Nlerp` follow the shortest rotational path, so opposite-sign equivalent endpoints are
treated as the same rotation instead of taking the long arc. Finite interpolation factors outside
`[0, 1]` are not clamped, so callers can deliberately extrapolate through the same formulas. Those
same rules also define the interpolation endpoints: `AT = 0` returns the normalized start
rotation, and `AT = 1` returns the normalized end rotation after any opposite-sign canonicalization.
`Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared axis
and interpolate the small remaining angle instead of collapsing or taking a long arc.
`EaseOutBounce` follows the documented four-piece bounce ladder, and the direct branch tests lock
representative points in each non-endpoint segment.
`TryInverse` is epsilon-based: it returns `False` and zeroes the `out` matrix for singular,
numerically singular, and non-finite matrices, and `Inverse` raises `EArgumentError` on the same
inputs.
Matrix inverse failure is fail-close: `TryInverse` treats singular and numerically singular
matrices, plus matrices containing `NaN` or infinity, the same: it returns `False`, zeroes the
failed `out` matrix, and `Inverse` raises `EArgumentError` on the same inputs.
Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on
the previous contents of the destination matrix and fully rewrites it before returning `True`.

## Random And Noise Ownership

Random and noise state is explicit. Create an object, use it, and free it:

```pascal
var
  Rng: TRandomGen;
begin
  Rng := TRandomGen.Create(123456789);
  try
    WriteLn(Rng.NextIntRange(1, 6));
  finally
    Rng.Free;
  end;
end;
```

There is no public global random or noise singleton. Seed `0` maps to a deterministic default seed,
so it is repeatable but not magical entropy.

Invalid integer ranges and reversed or non-finite float ranges raise `EArgumentError`. `NextBool`
rejects non-finite probabilities and clamps finite probabilities into false or true behavior. Dice
helpers return `0` for non-positive dice or sides, and `RollMultiple` rejects positive dice/side
combinations whose maximum total would not fit `Integer`. `WeightedChoice` rejects empty,
non-finite, negative, and all-zero weights. `Noise1D`/`2D`/`3D` and `FBM1D`/`2D`/`3D` reject
non-finite coordinate inputs. FBM also rejects non-positive octaves and non-positive or non-finite
lacunarity and gain, plus finite coordinate/lacunarity combinations that would make octave coordinates
non-finite and finite gain combinations that would make octave amplitudes or accumulated results
non-finite.
`WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on
zero-weight prefixes.
`NextInt` covers the full signed `Integer` domain rather than only the non-negative half-range, so
its public contract matches `NextIntRange(Low(Integer), High(Integer))`.
`NextIntRange` uses rejection sampling for non-power-of-two widths, so integer spans such as
`0..9` and `-3..3` stay unbiased instead of inheriting modulo bias from the raw `UInt64` stream.
`NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single`
bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.
`NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of
producing NaN or infinity.
Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like
`-0.25` and `255.75` stay equivalent for the same seeded generator.
Noise and FBM use the stored `Double` coordinate value. Around `2^52` and above, sub-unit deltas
collapse to the same representable coordinate, so the public contract is stable lattice-equivalent
semantics rather than an owner-level precision error.

## SIMD And Platform Boundaries

SIMD is an implementation detail. Public consumers should use the math facade or public math
submodules, not implementation-only acceleration units. Missing SIMD primitives must be added to the
SIMD module with their own tests before math consumes them.

The current internal SIMD seam contains selected `TVec3f`/`TVec4f` helpers plus candidate
`TMat4f * TVec4f` and `TQuatf.Rotate` helpers backed by the public `nextpas.core.simd` facade and
is covered by an implementation-specific test. The candidate quaternion helper normalizes first so
it matches public `TQuatf.Rotate` semantics, but local x86_64/Linux benchmark evidence still keeps
both candidate seams out of the public path because the scalar implementations remain faster. Public
docs, examples, facade tests, and downstream consumers must not import `math.impl.*` units.
Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam
benchmarks are negative wiring evidence, and public math source units must not import
`math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.

Run the internal seam correctness smoke on the current host with:

```sh
make -C core core-math-impl-simd-local-smoke
```

It wraps `make -C core/tests/nextpas.core.math/test_impl_simd clean test` through a stable
owner-level `core/Makefile` entrypoint.

Run the Win64 compile-only internal SIMD seam gate when the local FPC install provides the Win64
target RTL:

```sh
make -C core core-math-impl-simd-win64-compile-smoke
```

`core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.

Run the local trig link smoke on the current host with:

```sh
make -C core core-math-trig-local-smoke
```

Run the Win64 compile-only trig gate when the local FPC install provides the Win64 target RTL:

```sh
make -C core core-math-trig-win64-compile-smoke
```

The current trig implementation is protected from a public naked `external 'm'` dependency by
source-surface tests plus this local host link smoke. `core-math-trig-local-smoke` now reruns
`core-math-api-surface-smoke`, then reuses `core-math-facade-local-smoke`, and finally runs
`test_trig`, so the current-host proof stays self-contained at the `core/Makefile` layer while the
public consumer contract remains independently repeatable. macOS and Windows host link smokes are
still pending before the module can claim final cross-platform trig completion.
`core-math-trig-win64-compile-smoke` is compile-only and uses `-Cn -Twin64 -Px86_64`; it proves the
current facade/trig route compiles for Win64 with this toolchain, but it is not a Windows host
link/run proof and it does not cover macOS.
Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.
M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.

## Verification

Run the named full local math suite with:

```sh
make -C core core-math-full-local-smoke
```

It wraps `make -C core/tests/nextpas.core.math clean test` so the current owner-level full math
focused gate is reachable through a stable `core/Makefile` entrypoint.

Run the focused math gate:

```sh
make -C core/tests/nextpas.core.math clean test
```

For handoff or landing review, also run:

```sh
make hygiene
git diff --check
git status --short --branch
```
