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

## Facade Overview Example

`core/examples/nextpas.core.math/math_overview` is a compilable facade-only example. It imports only
`nextpas.core.math` and demonstrates vector normalization, quaternion rotation, transform
composition, projection/view builders, easing, deterministic random state, and noise:

```sh
make -C core core-math-smoke
```

The named `core-math-smoke` gate in `core/Makefile` reruns `test_api_surface` and then builds/runs
the overview example. Use the example target directly when you only want the facade-consumer proof:

```sh
make -C core/examples/nextpas.core.math/math_overview clean run
```

## Public Modules

- `nextpas.core.math`: facade that explicitly re-exports the public math API.
- `nextpas.core.math.scalar`: constants, min/max/clamp, interpolation, rounding, float predicates,
  degree/radian conversion, overflow helpers, `GCD`, `LCM`, `Hypot`, and `Fmod`.
- `nextpas.core.math.trig`: trigonometric and exponential helpers such as `Sin`, `Cos`, `Tan`,
  `ArcTan2`, `Exp`, `Ln`, `Power`, and `Sqrt`.
- `nextpas.core.math.vec`: value types `TVec2f`, `TVec3f`, `TVec4f`, `TVec2d`, `TVec3d`, and
  `TVec4d`.
- `nextpas.core.math.mat`: value types `TMat3f`, `TMat4f`, `TMat3d`, and `TMat4d`.
- `nextpas.core.math.quat`: value types `TQuatf` and `TQuatd`.
- `nextpas.core.math.transform`: `Ortho`, `Perspective`, `LookAt`, `Translate`, `Scale`,
  `RotateX`, `RotateY`, `RotateZ`, and `Camera2D`.
- `nextpas.core.math.easing`: `TEasingFunction` plus the `Ease*` function family.
- `nextpas.core.math.random`: `TRandomState`, `TRandomGen`, and `TNoiseGen`.

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

Builder guard rules are explicit: `Ortho` requires non-zero width, height, and depth;
`Perspective` requires positive FOV, aspect, and near plane plus `far > near`; `LookAt` requires
`eye <> target` and an `up` vector that is not parallel to forward; `Camera2D` requires positive
zoom and positive viewport dimensions.
Reversed non-zero `Ortho` bounds are valid and flip the corresponding axis; `Camera2D` relies on a
reversed Y range to keep screen-space `+Y down`.
`LookAt` uses the direction of `up`, not its magnitude, so positive rescaling of the same valid
`up` vector does not change the resulting view matrix.
Easing functions reject `NaN` and infinite input, and finite inputs outside `[0, 1]` extrapolate
through the same formulas rather than clamping to the unit interval.

Quaternions store vector part `X`, `Y`, `Z` and real part `W`. Zero quaternion normalization returns
identity; zero vector normalization returns zero. `FromAxisAngle` normalizes its axis, and a zero
axis returns identity instead of a partial rotation. `ToAxisAngle` normalizes first and returns a
canonical shortest-angle axis-angle pair: zero rotation uses axis `+Z`, and exact half-turns use a
stable axis hemisphere so opposite-sign equivalent quaternions still map to the same output.
`ToRotationMatrix` and `Rotate` also normalize first, so positive scaling of the same input
rotation does not change the result.
`Equals` is a component-wise epsilon comparison; it does not canonicalize opposite-sign equivalent
rotations, and negative epsilon returns `False`.
`Slerp` and `Nlerp` follow the shortest rotational path, so opposite-sign equivalent endpoints are
treated as the same rotation instead of taking the long arc. Finite interpolation factors outside
`[0, 1]` are not clamped, so callers can deliberately extrapolate through the same formulas. Those
same rules also define the interpolation endpoints: `AT = 0` returns the normalized start
rotation, and `AT = 1` returns the normalized end rotation after any opposite-sign canonicalization.
`TryInverse` is epsilon-based: it returns `False` and zeroes the `out` matrix for singular and
numerically singular matrices, and `Inverse` raises `EArgumentError` on the same inputs.

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

Run the local trig link smoke on the current host with:

```sh
make -C core core-math-trig-local-smoke
```

The current trig implementation is protected from a public naked `external 'm'` dependency by
source-surface tests plus this local host link smoke. macOS and Windows host link smokes are still
pending before the module can claim final cross-platform trig completion.

## Verification

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
