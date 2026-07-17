# nextpas.core.math

`nextpas.core.math` is the framework-owned math entry point for scalar helpers,
trigonometry, vectors, matrices, quaternions, transforms, easing, deterministic
random generators, noise, and SIMD-backed batch operations.

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
- `nextpas.core.math.base`: shared point types and canonical compile-time `Double`
  constants.
- `nextpas.core.math.scalar`: scalar helpers, rounding, interpolation, predicates,
  overflow helpers, `GCD`, `LCM`, `Hypot`, and `Fmod`.
- `nextpas.core.math.trig`: `Sin`, `Cos`, `Tan`, inverse trig, `Exp`, `Ln`,
  `Log2`, `Log10`, `Power`, and `Sqrt`, plus compile-time aliases for the common
  trig constants.
- `nextpas.core.math.vec`: `TVec2f/3f/4f` and `TVec2d/3d/4d`.
- `nextpas.core.math.mat`: `TMat3f/4f` and `TMat3d/4d`.
- `nextpas.core.math.quat`: `TQuatf` and `TQuatd`.
- `nextpas.core.math.transform`: projection, view, model, and 2D camera builders.
- `nextpas.core.math.easing`: `TEasingFunction` and the `Ease*` family.
- `nextpas.core.math.random`: `TRandomState`, `TRandomGen`, and `TNoiseGen`.
- `nextpas.core.math.batch`: public F32 scalar-array batch API (SIMD-backed).
- `nextpas.core.math.vec.batch`: public vector-array batch API.

## Layer And Ownership

- Registry layer: **L0** (same governance set as `base` / `simd` / `atomic`).
- Batch/impl SIMD units consume only the public `nextpas.core.simd` facade.
- Private SIMD backend/dispatch/cpuinfo/dataplane units must not appear in math
  production sources.

## Verification Entry Points

```sh
# Preferred focused suite (17 projects, heaptrc on Pascal tests)
make -C core/tests/nextpas.core.math clean test

# API/docs/source-contract gate
make -C core core-math-api-surface-smoke

# Broader local smokes
make -C core core-math-smoke
make -C core core-math-full-local-smoke
make -C core core-math-trig-local-smoke
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
- Canonical constant ownership: `nextpas.core.math.base` is the only unit that declares the numeric literals. `nextpas.core.math.trig` and `nextpas.core.math` expose only compile-time aliases to those base constants.
- Public value-type methods remain scalar. SIMD acceleration is exposed through public batch APIs (`math.batch` / `math.vec.batch`), not through value-type methods.
- `math.impl.simd` is an internal seam only and is not public API.
- Public batch surface covers F32 and F64 scalar arrays plus selected vec batch. `Batch*F64` is a thin open-array facade over simd `Array*F64` (same core set as public F32: sin/cos/exp/ln/sqrt/abs/neg/ceil/floor/round/trunc/lerp/clamp/scale-offset).
- Linux local focused suite is green with heaptrc zero evidence.
- Windows trig host link/runtime proof exists via Wine.
- M8 is complete on Linux+Windows; macOS host trig proof is deferred.

## Remaining Gaps

- macOS host trig link/runtime smoke evidence (deferred; blocks full host matrix).
- Vec batch Double parity (`vec.batch` remains primarily Single-oriented).
- `fafafa.game` cutover to final `nextpas.core.math.*` names (M9).
- Do not wire public value-type methods through SIMD without profiled evidence.
