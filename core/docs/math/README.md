# nextpas.core.math

`nextpas.core.math` is the framework-owned math entry point for scalar helpers,
trigonometry, vectors, matrices, quaternions, transforms, easing, deterministic
random generators, and noise.

Most consumers should use the facade:

```pascal
uses
  nextpas.core.math;
```

Use submodules only for narrower imports, such as `nextpas.core.math.vec` or
`nextpas.core.math.random`.

Detailed behavior contracts live in `API.md`; this README stays compact.

## Public Modules

- `nextpas.core.math`: facade that explicitly re-exports the public math API.
- `nextpas.core.math.scalar`: constants, scalar helpers, rounding, interpolation,
  predicates, overflow helpers, `GCD`, `LCM`, `Hypot`, and `Fmod`.
- `nextpas.core.math.trig`: `Sin`, `Cos`, `Tan`, inverse trig, `Exp`, `Ln`,
  `Log2`, `Log10`, `Power`, and `Sqrt`.
- `nextpas.core.math.vec`: `TVec2f/3f/4f` and `TVec2d/3d/4d`.
- `nextpas.core.math.mat`: `TMat3f/4f` and `TMat3d/4d`.
- `nextpas.core.math.quat`: `TQuatf` and `TQuatd`.
- `nextpas.core.math.transform`: projection, view, model, and 2D camera builders.
- `nextpas.core.math.easing`: `TEasingFunction` and the `Ease*` family.
- `nextpas.core.math.random`: `TRandomState`, `TRandomGen`, and `TNoiseGen`.

## Verification Entry Points

Run the API/docs/source-contract gate:

```sh
make -C core core-math-api-surface-smoke
```

Run the facade-only consumer gate:

```sh
make -C core core-math-facade-local-smoke
```

Run the facade overview example gate:

```sh
make -C core core-math-overview-local-smoke
```

Run the broader local module smoke:

```sh
make -C core core-math-smoke
```

Run the current-host trig proof:

```sh
make -C core core-math-trig-local-smoke
```

Run the full focused math suite when preparing a broader landing package:

```sh
make -C core core-math-full-local-smoke
```

For landing review, also run:

```sh
git diff --check
make hygiene
git status --short --branch
```

## Current Truth

- `API.md` is the public behavior contract and command reference.
- `GOAL_TREE.md` is the roadmap/status control map.
- `FINAL_API_MIGRATION_DESIGN.md` records stable design decisions only.
- Public docs must not reintroduce legacy vector bridge type names, old
  `Vectors` imports, or old source paths.
- Public math value-type methods currently remain scalar. The internal
  `math.impl.simd` seam is not public API and is not wired into the public
  value-type methods.
- M8 remains partial until host trig link evidence and SIMD cutover decisions are resolved.

## Remaining Gaps

- macOS and Windows host trig link/runtime smoke evidence.
- Profiling-backed SIMD cutover decisions and benchmark evidence.
- `fafafa.game` cutover to final `nextpas.core.math.*` names.
- Remaining scalar/trig/vector hardening slices listed in `GOAL_TREE.md`.
