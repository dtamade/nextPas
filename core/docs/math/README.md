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

The transform convention is:

- vectors are column vectors;
- translation lives in column 3;
- transform composition uses `Translate * Rotate * Scale` for local transforms;
- projection/view/model composition uses `Projection * View * Model`;
- perspective is right-handed and looks down `-Z`;
- NDC is `[-1, +1]`;
- `Camera2D` uses screen-space positive Y down.

Quaternions store vector part `X`, `Y`, `Z` and real part `W`. Zero quaternion normalization returns
identity; zero vector normalization returns zero.

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

Invalid integer and float ranges raise `EArgumentError`. `NextBool` clamps probabilities into false
or true behavior. Dice helpers return `0` for non-positive dice or sides. `WeightedChoice` rejects
empty, negative, and all-zero weights. FBM noise rejects non-positive octaves, lacunarity, and gain.

## SIMD And Platform Boundaries

SIMD is an implementation detail. Public consumers should use the math facade or public math
submodules, not implementation-only acceleration units. Missing SIMD primitives must be added to the
SIMD module with their own tests before math consumes them.

The current trig implementation is protected from a public naked `external 'm'` dependency by source
surface tests and Linux local link tests. macOS and Windows host link smokes are still pending before
the module can claim final cross-platform trig completion.

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
