#!/usr/bin/env python3
"""Fail-close the nextpas.core.math final public surface contract."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class RequiredCoreMakeTarget:
    target: str
    command: str
    recipe_steps: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class RequiredBehaviorTestMarker:
    rule: str
    path: str
    marker: str


@dataclass(frozen=True)
class PascalClassContract:
    class_name: str
    public_members: tuple[str, ...]


SUMMARY_PREFIX = "MATH_API_SURFACE"

MATH_SOURCE_GLOBS = (
    "src/nextpas.core.math*.pas",
    "src/nextpas.core.math*.inc",
)
MATH_TEST_GLOBS = (
    "tests/nextpas.core.math/**/*.lpr",
    "tests/nextpas.core.math/**/*.pas",
    "tests/nextpas.core.math/**/Makefile",
)
MATH_EXAMPLE_GLOBS = (
    "examples/nextpas.core.math/**/*.lpr",
    "examples/nextpas.core.math/**/*.pas",
    "examples/nextpas.core.math/**/Makefile",
    "examples/nextpas.core.math*/**/*.lpr",
    "examples/nextpas.core.math*/**/*.pas",
    "examples/nextpas.core.math*/**/Makefile",
)
MATH_BENCHMARK_GLOBS = (
    "benchmarks/nextpas.core.math/**/*.lpr",
    "benchmarks/nextpas.core.math/**/*.pas",
    "benchmarks/nextpas.core.math/**/Makefile",
)
PUBLIC_DOC_PATHS = (
    "docs/math/README.md",
    "docs/math/API.md",
)
CONTROL_DOC_LINE_LIMITS = {
    "docs/math/README.md": 180,
    "docs/math/GOAL_TREE.md": 220,
    "docs/math/FINAL_API_MIGRATION_DESIGN.md": 220,
}
REQUIRED_CONTROL_DOC_MARKERS = (
    (
        "docs/math/README.md",
        "Detailed behavior contracts live in `API.md`; this README stays compact.",
    ),
    (
        "docs/math/README.md",
        "M8 remains partial until host trig link evidence and SIMD cutover decisions are resolved.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Current roadmap position: M8 partial, M7 partial, M9 not started.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "M8 cannot be marked complete without source-contract, focused runtime, heaptrc, and CI matrix evidence.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Detailed behavior contracts live in `API.md`; this design record stays compact.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "The final API rejects a long-term `Vectors` compatibility bridge.",
    ),
)
REQUIRED_CORE_TARGET_DOC_PATHS = (
    "docs/math/README.md",
    "docs/math/API.md",
    "docs/math/GOAL_TREE.md",
    "docs/math/FINAL_API_MIGRATION_DESIGN.md",
)
PUBLIC_MATH_SOURCE_PATHS = {
    "src/nextpas.core.math.pas",
    "src/nextpas.core.math.scalar.pas",
    "src/nextpas.core.math.trig.pas",
    "src/nextpas.core.math.vec.pas",
    "src/nextpas.core.math.mat.pas",
    "src/nextpas.core.math.quat.pas",
    "src/nextpas.core.math.transform.pas",
    "src/nextpas.core.math.easing.pas",
    "src/nextpas.core.math.random.pas",
}
ROOT_MAKEFILE_PATH = "Makefile"
MATH_SUITE_MAKEFILE_PATH = "tests/nextpas.core.math/Makefile"
ROOT_FACADE_PATH = "src/nextpas.core.math.pas"
API_DOC_PATH = "docs/math/API.md"
L1_GOAL_TREE_PATH = "docs/l1-goal-tree.md"
ROOT_FACADE_ALLOWED_USES = {
    "nextpas.core.math.scalar",
    "nextpas.core.math.trig",
    "nextpas.core.math.vec",
    "nextpas.core.math.mat",
    "nextpas.core.math.quat",
    "nextpas.core.math.transform",
    "nextpas.core.math.easing",
    "nextpas.core.math.random",
}
REQUIRED_ROOT_FACADE_TYPE_ALIASES = {
    "tvec2f": "nextpas.core.math.vec.tvec2f",
    "tvec3f": "nextpas.core.math.vec.tvec3f",
    "tvec4f": "nextpas.core.math.vec.tvec4f",
    "tvec2d": "nextpas.core.math.vec.tvec2d",
    "tvec3d": "nextpas.core.math.vec.tvec3d",
    "tvec4d": "nextpas.core.math.vec.tvec4d",
    "tmat3f": "nextpas.core.math.mat.tmat3f",
    "tmat4f": "nextpas.core.math.mat.tmat4f",
    "tmat3d": "nextpas.core.math.mat.tmat3d",
    "tmat4d": "nextpas.core.math.mat.tmat4d",
    "tquatf": "nextpas.core.math.quat.tquatf",
    "tquatd": "nextpas.core.math.quat.tquatd",
    "teasingfunction": "nextpas.core.math.easing.teasingfunction",
    "trandomstate": "nextpas.core.math.random.trandomstate",
    "trandomgen": "nextpas.core.math.random.trandomgen",
    "tnoisegen": "nextpas.core.math.random.tnoisegen",
}
REQUIRED_ROOT_FACADE_CONSTANTS = {
    "pi_value": ("double", "3.14159265358979323846"),
    "two_pi": ("double", "6.28318530717958647692"),
    "half_pi": ("double", "1.57079632679489661923"),
    "deg_to_rad": ("double", "0.01745329251994329577"),
    "rad_to_deg": ("double", "57.2957795130823208768"),
}
ROOT_FACADE_CONSTANT_PARITY_EXPECTATIONS = {
    "src/nextpas.core.math.scalar.pas": REQUIRED_ROOT_FACADE_CONSTANTS,
    "src/nextpas.core.math.trig.pas": {
        "pi_value": REQUIRED_ROOT_FACADE_CONSTANTS["pi_value"],
        "two_pi": REQUIRED_ROOT_FACADE_CONSTANTS["two_pi"],
        "half_pi": REQUIRED_ROOT_FACADE_CONSTANTS["half_pi"],
    },
}
FACADE_TYPE_ALIAS_COMPILE_TEST_PATH = "tests/nextpas.core.math/test_facade/test_facade.lpr"
FACADE_TYPE_ALIAS_COMPILE_TEST_MARKER = "T.Run('facade type alias compile surface'"
FACADE_ROOT_IMPORT_TEST_MARKER = "T.Run('facade imports only root math unit'"
REQUIRED_FACADE_TYPE_ALIAS_COMPILE_USES = {
    "tvec2f": "LVec2f: TVec2f",
    "tvec3f": "LVec3f: TVec3f",
    "tvec4f": "LVec4f: TVec4f",
    "tvec2d": "LVec2d: TVec2d",
    "tvec3d": "LVec3d: TVec3d",
    "tvec4d": "LVec4d: TVec4d",
    "tmat3f": "LMat3f: TMat3f",
    "tmat4f": "LMat4f: TMat4f",
    "tmat3d": "LMat3d: TMat3d",
    "tmat4d": "LMat4d: TMat4d",
    "tquatf": "LQuatf: TQuatf",
    "tquatd": "LQuatd: TQuatd",
    "teasingfunction": "LEasing: TEasingFunction",
    "trandomstate": "LState: TRandomState",
    "trandomgen": "LRng: TRandomGen",
    "tnoisegen": "LNoise: TNoiseGen",
}
ROOT_FACADE_FORWARD_TARGETS = {
    "isaddoverflow": "scalar",
    "ismuloverflow": "scalar",
    "min": "scalar",
    "max": "scalar",
    "clamp": "scalar",
    "lerp": "scalar",
    "inverselerp": "scalar",
    "wrap": "scalar",
    "smoothstep": "scalar",
    "floor": "scalar",
    "ceil": "scalar",
    "round": "scalar",
    "trunc": "scalar",
    "frac": "scalar",
    "abs": "scalar",
    "sign": "scalar",
    "isnan": "scalar",
    "isinfinite": "scalar",
    "floatequals": "scalar",
    "floatiszero": "scalar",
    "degtorad": "scalar",
    "radtodeg": "scalar",
    "gcd": "scalar",
    "lcm": "scalar",
    "hypot": "scalar",
    "fmod": "scalar",
    "sin": "trig",
    "cos": "trig",
    "tan": "trig",
    "arcsin": "trig",
    "arccos": "trig",
    "arctan": "trig",
    "arctan2": "trig",
    "exp": "trig",
    "ln": "trig",
    "log2": "trig",
    "log10": "trig",
    "power": "trig",
    "sqrt": "trig",
    "ortho": "transform",
    "perspective": "transform",
    "lookat": "transform",
    "translate": "transform",
    "scale": "transform",
    "rotatex": "transform",
    "rotatey": "transform",
    "rotatez": "transform",
    "camera2d": "transform",
    "easelinear": "easing",
    "easeinquad": "easing",
    "easeoutquad": "easing",
    "easeinoutquad": "easing",
    "easeincubic": "easing",
    "easeoutcubic": "easing",
    "easeinoutcubic": "easing",
    "easeinquart": "easing",
    "easeoutquart": "easing",
    "easeinoutquart": "easing",
    "easeinexpo": "easing",
    "easeoutexpo": "easing",
    "easeinoutexpo": "easing",
    "easeinelastic": "easing",
    "easeoutelastic": "easing",
    "easeinoutelastic": "easing",
    "easeinback": "easing",
    "easeoutback": "easing",
    "easeinoutback": "easing",
    "easeinbounce": "easing",
    "easeoutbounce": "easing",
    "easeinoutbounce": "easing",
}
REQUIRED_HOST_GATE_RESIDUAL_TRUTH = (
    (
        "docs/math/README.md",
        "Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.",
    ),
    (
        "docs/math/API.md",
        "Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Without macOS/Windows host link smoke runs, final cross-platform trig completion remains blocked, not complete.",
    ),
)
REQUIRED_M8_RESIDUAL_TRUTH = (
    (
        "docs/math/README.md",
        "M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.",
    ),
    (
        "docs/math/API.md",
        "M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "M8 is not complete until broader M7 SIMD acceleration decisions and host trig link evidence are resolved.",
    ),
)
REQUIRED_SIMD_SEAM_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam benchmarks are negative wiring evidence, and public math source units must not import `math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.",
    ),
    (
        "docs/math/API.md",
        "Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam benchmarks are negative wiring evidence, and public math source units must not import `math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam benchmarks are negative wiring evidence, and public math source units must not import `math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Current `TVec*`, `TMat*`, and `TQuat*` public value-type methods remain scalar: local SIMD seam benchmarks are negative wiring evidence, and public math source units must not import `math.impl.simd` until a later profiled cutover adds tested public SIMD primitives.",
    ),
)
REQUIRED_FACADE_ONLY_DOC_TRUTH = (
    (
        "docs/math/API.md",
        "The canonical facade consumer test imports `nextpas.core.math` as its only math unit; support imports such as `SysUtils`, `nextpas.core.testing`, and `nextpas.core.errors` do not count as math API imports.",
    ),
)
REQUIRED_IMPL_SIMD_WIN64_COMPILE_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.",
    ),
    (
        "docs/math/API.md",
        "`core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`core-math-impl-simd-win64-compile-smoke` is compile-only forced coverage for `math.impl.simd` on the Win64 target; it is not Windows host runtime, heaptrc, benchmark, or public SIMD wiring proof.",
    ),
)
REQUIRED_MAT_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "Matrix inverse failure is fail-close: `TryInverse` treats singular and numerically singular matrices, plus matrices containing `NaN` or infinity, the same: it returns `False`, zeroes the failed `out` matrix, and `Inverse` raises `EArgumentError` on the same inputs.",
    ),
    (
        "docs/math/API.md",
        "Matrix inverse failure is fail-close: `TryInverse` treats singular and numerically singular matrices, plus matrices containing `NaN` or infinity, the same: it returns `False`, zeroes the failed `out` matrix, and `Inverse` raises `EArgumentError` on the same inputs.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Matrix inverse failure is fail-close: `TryInverse` treats singular, numerically singular, and non-finite matrices the same, returns `False`, zeroes the failed `out` matrix, and `Inverse` raises `EArgumentError` on the same inputs.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Matrix inverse failure is fail-close: `TryInverse` treats singular, numerically singular, and non-finite matrices the same, returns `False`, zeroes the failed `out` matrix, and `Inverse` raises `EArgumentError` on the same inputs.",
    ),
    (
        "docs/math/README.md",
        "Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on the previous contents of the destination matrix and fully rewrites it before returning `True`.",
    ),
    (
        "docs/math/API.md",
        "Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on the previous contents of the destination matrix and fully rewrites it before returning `True`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on the previous contents of the destination matrix and fully rewrites it before returning `True`.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Matrix inverse success overwrites the `out` parameter completely: `TryInverse` does not depend on the previous contents of the destination matrix and fully rewrites it before returning `True`.",
    ),
    (
        "docs/math/README.md",
        "Matrix `Equals` applies scalar `FloatEquals` element-wise: NaN elements and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/API.md",
        "Matrix `Equals` applies scalar `FloatEquals` element-wise: NaN elements and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Matrix `Equals` applies scalar `FloatEquals` element-wise: NaN elements and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
)
REQUIRED_TRANSFORM_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while flipping `up` to the opposite direction changes roll.",
    ),
    (
        "docs/math/API.md",
        "`LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while flipping `up` to the opposite direction changes roll.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while flipping `up` to the opposite direction changes roll.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`LookAt` treats `up` direction as semantic: positive rescaling preserves the view matrix, while flipping `up` to the opposite direction changes roll.",
    ),
    (
        "docs/math/README.md",
        "`Camera2D` larger zoom values magnify the view, so the same world-space offset maps farther in NDC on both axes.",
    ),
    (
        "docs/math/API.md",
        "`Camera2D` larger zoom values magnify the view, so the same world-space offset maps farther in NDC on both axes.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Camera2D` larger zoom values magnify the view, so the same world-space offset maps farther in NDC on both axes.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Camera2D` larger zoom values magnify the view, so the same world-space offset maps farther in NDC on both axes.",
    ),
)
REQUIRED_QUAT_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`ToAxisAngle` normalizes first and returns a canonical shortest-angle axis-angle pair: zero rotation uses axis `+Z`, and exact half-turns, including `FromAxisAngle(..., PI)` paths, use a stable axis hemisphere so opposite-sign equivalent quaternions still map to the same output.",
    ),
    (
        "docs/math/API.md",
        "`ToAxisAngle` normalizes its quaternion first and returns a canonical shortest-angle axis-angle pair. Opposite-sign equivalent quaternions map to the same output; zero rotation returns axis `+Z` with angle `0`, and exact half-turn outputs, including `FromAxisAngle(..., PI)` paths, use a stable axis hemisphere so `angle = PI` remains canonical too.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`ToAxisAngle` canonical shortest-angle output including zero-rotation `+Z` fallback, direct `±3π/2` multi-turn canonicalization, exact half-turn stable-axis canonicalization across `x/y/z` axes plus mixed-axis `+X/+Y` hemisphere precedence and `FromAxisAngle(..., PI)` half-turn paths",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`ToAxisAngle` normalizes its quaternion first and returns a canonical shortest-angle axis-angle pair: zero rotation uses `+Z` as the fallback axis, and exact half-turns, including `FromAxisAngle(..., PI)` paths, use a stable axis hemisphere so opposite-sign equivalent quaternions map to the same output.",
    ),
    (
        "docs/math/README.md",
        "`Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared axis and interpolate the small remaining angle instead of collapsing or taking a long arc.",
    ),
    (
        "docs/math/API.md",
        "`Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared axis and interpolate the small remaining angle instead of collapsing or taking a long arc.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared axis and interpolate the small remaining angle instead of collapsing or taking a long arc.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Slerp` and `Nlerp` stay stable for near-identical finite endpoints: they preserve the shared axis and interpolate the small remaining angle instead of collapsing or taking a long arc.",
    ),
    (
        "docs/math/README.md",
        "`ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and `AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous contents.",
    ),
    (
        "docs/math/API.md",
        "`ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and `AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous contents.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and `AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous contents.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`ToAxisAngle` overwrites both `out` parameters completely: each call rewrites `AAxis` and `AAngleRad` for zero-rotation fallback and ordinary rotations, independent of their previous contents.",
    ),
    (
        "docs/math/README.md",
        "Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first, then applies the left operand `A`, and non-collinear rotations are non-commutative.",
    ),
    (
        "docs/math/API.md",
        "Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first, then applies the left operand `A`, and non-collinear rotations are non-commutative.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first, then applies the left operand `A`, and non-collinear rotations are non-commutative.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Quaternion multiplication is ordered composition: `A * B` applies the right operand `B` first, then applies the left operand `A`, and non-collinear rotations are non-commutative.",
    ),
    (
        "docs/math/README.md",
        "Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.",
    ),
    (
        "docs/math/API.md",
        "Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Raw quaternion inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`, `ToAxisAngle`, `ToRotationMatrix`, `Rotate`, or as `Slerp`/`Nlerp` endpoints.",
    ),
    (
        "docs/math/README.md",
        "Quaternion `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/API.md",
        "Quaternion `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Quaternion `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
)
REQUIRED_VEC_QUAT_STABLE_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`, `TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without overflowing the intermediate squared length.",
    ),
    (
        "docs/math/API.md",
        "Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`, `TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without overflowing the intermediate squared length.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`, `TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without overflowing the intermediate squared length.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Vector `Length` and `Normalize` use scaled finite length paths, so huge finite `TVec2*`, `TVec3*`, and `TVec4*` inputs preserve finite length, direction, and unit length without overflowing the intermediate squared length.",
    ),
    (
        "docs/math/README.md",
        "`LengthSqr` avoids FPU overflow exceptions for huge finite inputs, keeps below-overflow results finite, and returns `+Inf` when the true squared length is outside the target float range.",
    ),
    (
        "docs/math/API.md",
        "`LengthSqr` also uses a non-throwing scaled path for huge finite inputs; below-overflow results stay finite, and if the true squared length is outside the target float range, it returns `+Inf` instead of raising an FPU overflow exception.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Vector `LengthSqr` avoids FPU overflow exceptions for huge finite inputs, keeps below-overflow results finite, and returns `+Inf` when the true squared length is outside the target float range; vector `Data` aliases write through to named fields.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`LengthSqr` avoids FPU overflow exceptions for huge finite inputs, keeps below-overflow results finite, and returns `+Inf` when the true squared length is outside the target float range.",
    ),
    (
        "docs/math/README.md",
        "`Cross` uses stable finite intermediate paths for huge finite `TVec3f` and `TVec3d` inputs: finite true components stay finite instead of becoming `NaN` through intermediate overflow, and true out-of-range components return signed infinity.",
    ),
    (
        "docs/math/API.md",
        "`Cross` uses stable finite intermediate paths for huge finite `TVec3f` and `TVec3d` inputs: finite true components stay finite instead of becoming `NaN` through intermediate overflow, and true out-of-range components return signed infinity.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Cross` uses stable finite intermediate paths for huge finite `TVec3f` and `TVec3d` inputs: finite true components stay finite instead of becoming `NaN` through intermediate overflow, and true out-of-range components return signed infinity.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Cross` uses stable finite intermediate paths for huge finite `TVec3f` and `TVec3d` inputs: finite true components stay finite instead of becoming `NaN` through intermediate overflow, and true out-of-range components return signed infinity.",
    ),
    (
        "docs/math/README.md",
        "Vector `Data` aliases write through to `X/Y/Z/W`.",
    ),
    (
        "docs/math/API.md",
        "`Data` aliases are read/write views over `X/Y/Z/W`, so indexed writes update the named fields.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Vector `LengthSqr` avoids FPU overflow exceptions for huge finite inputs, keeps below-overflow results finite, and returns `+Inf` when the true squared length is outside the target float range; vector `Data` aliases write through to named fields.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Vector `Data` aliases write through to named fields.",
    ),
    (
        "docs/math/API.md",
        "Vector `Lerp` delegates component-wise to scalar `Lerp`, so vector interpolation inherits scalar huge-finite stability and signed-zero behavior for every lane.",
    ),
    (
        "docs/math/API.md",
        "Vector measure methods are non-throwing for non-finite inputs: NaN operands produce NaN, infinite operands produce `+Inf` where no NaN is present, and `Dot`/`Cross` use raw IEEE fallback for non-finite operands, so indeterminate products such as `0 * Inf` produce NaN.",
    ),
    (
        "docs/math/API.md",
        "Signed-zero behavior is canonicalized only at measure/normalization boundaries: zero-vector `Normalize` returns positive-zero components, exact-zero `Dot` returns `+0`, and `Data` aliases preserve stored signed-zero bit patterns.",
    ),
    (
        "docs/math/README.md",
        "Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`.",
    ),
    (
        "docs/math/API.md",
        "Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Raw vector inputs containing NaN or infinity fail fast with `EArgumentError` when used by `Normalize`.",
    ),
    (
        "docs/math/README.md",
        "Vector scalar division and `DivComponents` reject zero, NaN, and infinite divisors with `EArgumentError`.",
    ),
    (
        "docs/math/API.md",
        "Vector scalar division and `DivComponents` reject zero, NaN, and infinite divisors with `EArgumentError`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Vector scalar division and `DivComponents` reject zero, NaN, and infinite divisors with `EArgumentError`.",
    ),
    (
        "docs/math/README.md",
        "Vector `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/API.md",
        "Vector `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Vector `Equals` applies scalar `FloatEquals` component-wise: NaN components and NaN, infinite, or negative epsilon values return `False`, while matching infinities compare equal with a valid epsilon.",
    ),
    (
        "docs/math/README.md",
        "Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd` inputs preserve direction instead of collapsing through an overflowing squared length.",
    ),
    (
        "docs/math/API.md",
        "Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd` inputs preserve direction instead of collapsing through an overflowing squared length.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd` inputs preserve direction instead of collapsing through an overflowing squared length.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Quaternion `Normalize` uses a scaled finite length path, so huge finite `TQuatf` and `TQuatd` inputs preserve direction instead of collapsing through an overflowing squared length.",
    ),
    (
        "docs/math/README.md",
        "`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the intended rotation.",
    ),
    (
        "docs/math/API.md",
        "`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the intended rotation.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the intended rotation.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`FromAxisAngle` uses vector normalization, so huge finite axes normalize without changing the intended rotation.",
    ),
)
REQUIRED_RANDOM_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on zero-weight prefixes.",
    ),
    (
        "docs/math/API.md",
        "`WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on zero-weight prefixes.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on zero-weight prefixes.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`WeightedChoice` treats `pick = 0` as the first positive-weight slot instead of getting stuck on zero-weight prefixes.",
    ),
    (
        "docs/math/README.md",
        "`NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of producing NaN or infinity.",
    ),
    (
        "docs/math/API.md",
        "`NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of producing NaN or infinity.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of producing NaN or infinity.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`NextGaussian` clamps a zero-state first uniform draw to a finite deterministic fallback instead of producing NaN or infinity.",
    ),
    (
        "docs/math/README.md",
        "`NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single` bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.",
    ),
    (
        "docs/math/API.md",
        "`NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single` bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single` bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`NextFloatRange` returns finite values in the half-open range `[AMin, AMax)` for finite `Single` bounds with `AMin < AMax`, including forced maximum samples over very large finite spans.",
    ),
)
REQUIRED_EASING_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`EaseOutBounce` follows the documented four-piece bounce ladder, and the direct branch tests lock representative points in each non-endpoint segment.",
    ),
    (
        "docs/math/API.md",
        "`EaseOutBounce` follows the documented four-piece bounce ladder, and the direct branch tests lock representative points in each non-endpoint segment.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`EaseOutBounce` follows the documented four-piece bounce ladder, and the direct branch tests lock representative points in each non-endpoint segment.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`EaseOutBounce` follows the documented four-piece bounce ladder, and the direct branch tests lock representative points in each non-endpoint segment.",
    ),
)
REQUIRED_NOISE_DOC_TRUTH = (
    (
        "docs/math/API.md",
        "Noise is exposed through `nextpas.core.math.random.TNoiseGen`; there is no public `nextpas.core.math.noise` unit.",
    ),
    (
        "docs/math/README.md",
        "Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like `-0.25` and `255.75` stay equivalent for the same seeded generator.",
    ),
    (
        "docs/math/API.md",
        "Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like `-0.25` and `255.75` stay equivalent for the same seeded generator.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like `-0.25` and `255.75` stay equivalent for the same seeded generator.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Negative fractional noise coordinates wrap canonically across the 256-period seam, so values like `-0.25` and `255.75` stay equivalent for the same seeded generator.",
    ),
)
REQUIRED_SCALAR_CLAMP_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.",
    ),
    (
        "docs/math/API.md",
        "`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Clamp` fails fast when the minimum exceeds the maximum; `Single` and `Double` clamp bounds must be finite, NaN values propagate as NaN, infinity values clamp to finite bounds, equal bounds return that bound, and in-range signed zero keeps its sign.",
    ),
)
REQUIRED_SCALAR_WRAP_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Wrap` uses a half-open `[minimum, maximum)` interval, preserves equal-bound behavior by returning the minimum, maps the maximum endpoint back to the minimum, rejects reversed bounds, requires value, minimum, and maximum to be finite, and finite inputs return a finite value in range even when range or delta intermediates are not representable as finite `Double`.",
    ),
    (
        "docs/math/API.md",
        "`Wrap` uses a half-open `[minimum, maximum)` interval, preserves equal-bound behavior by returning the minimum, maps the maximum endpoint back to the minimum, rejects reversed bounds, requires value, minimum, and maximum to be finite, and finite inputs return a finite value in range even when range or delta intermediates are not representable as finite `Double`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Wrap` uses a half-open `[minimum, maximum)` interval, preserves equal-bound behavior by returning the minimum, maps the maximum endpoint back to the minimum, rejects reversed bounds, requires value, minimum, and maximum to be finite, and finite inputs return a finite value in range even when range or delta intermediates are not representable as finite `Double`.",
    ),
)
REQUIRED_SCALAR_IEEE_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Abs` normalizes negative zero to positive zero; `Fmod` preserves the dividend sign for zero results, returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite `Fmod` inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN, returns NaN for NaN-only inputs, and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.",
    ),
    (
        "docs/math/API.md",
        "`Abs` normalizes negative zero to positive zero; `Fmod` preserves the dividend sign for zero results, returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite `Fmod` inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN, returns NaN for NaN-only inputs, and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Round` uses ties away from zero; `Abs` normalizes negative zero to positive zero; `Frac` and `Fmod` preserve the input or dividend sign for zero results; `Fmod` returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN, returns NaN for NaN-only inputs, and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Round` uses ties away from zero; `Abs` normalizes negative zero to positive zero; `Frac` and `Fmod` preserve the input or dividend sign for zero results; `Fmod` returns NaN for NaN inputs, zero divisors, and infinite dividends, returns the finite dividend for infinite divisors, and finite inputs avoid non-finite quotient intermediates; `Hypot` treats infinities as dominant over NaN, returns NaN for NaN-only inputs, and uses a scaled finite path; UInt32 and SizeUInt overflow helpers must avoid divide-by-zero paths.",
    ),
)
REQUIRED_SCALAR_INTEGER_BOUNDARY_DOC_TRUTH = (
    (
        "docs/math/API.md",
        "`UInt32` overflow helpers report `High(UInt32)+1` and `High(UInt32)*2` as overflow; `High(UInt32)-1+1` and zero-times-high multiplication in either order return `False` without divide-by-zero.",
    ),
    (
        "docs/math/API.md",
        "`GCD` and `LCM` normalize signs and return non-negative `Int64` results; representable `Low(Int64)`/`High(Int64)` boundary cases succeed, zero LCM returns `0` before overflow checks, and unrepresentable results raise `EArgumentError`.",
    ),
)
REQUIRED_SCALAR_SIGN_ANGLE_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Sign` propagates NaN, preserves signed zero, and maps infinities to `+/-1`; `DegToRad` and `RadToDeg` propagate NaN and infinities while preserving signed zero. `DegToRad` keeps maximum finite inputs finite with their original sign, and `RadToDeg` maps finite overflow to signed infinity.",
    ),
    (
        "docs/math/API.md",
        "`Sign` propagates NaN, preserves signed zero, and maps infinities to `+/-1`; `DegToRad` and `RadToDeg` propagate NaN and infinities while preserving signed zero. `DegToRad` keeps maximum finite inputs finite with their original sign, and `RadToDeg` maps finite overflow to signed infinity.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Sign` propagates NaN, preserves signed zero, and maps infinities to `+/-1`; `DegToRad` and `RadToDeg` propagate NaN and infinities while preserving signed zero. `DegToRad` keeps maximum finite inputs finite with their original sign, and `RadToDeg` maps finite overflow to signed infinity.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Sign` propagates NaN, preserves signed zero, and maps infinities to `+/-1`; `DegToRad` and `RadToDeg` propagate NaN and infinities while preserving signed zero. `DegToRad` keeps maximum finite inputs finite with their original sign, and `RadToDeg` maps finite overflow to signed infinity.",
    ),
)
REQUIRED_SCALAR_INTEGER_CONVERSION_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Floor`, `Ceil`, `Round`, `Trunc`, and `Frac` reject `NaN`, positive or negative infinity, and finite values outside the Int64 conversion range with `EArgumentError`; `Round` uses ties away from zero, while `Frac` uses truncation semantics and preserves signed-zero zero results.",
    ),
    (
        "docs/math/API.md",
        "`Floor`, `Ceil`, `Round`, `Trunc`, and `Frac` reject `NaN`, positive or negative infinity, and finite values outside the Int64 conversion range with `EArgumentError`; `Round` uses ties away from zero, while `Frac` uses truncation semantics and preserves signed-zero zero results.",
    ),
)
REQUIRED_SCALAR_RANGE_DOC_TRUTH = (
    (
        "docs/math/API.md",
        "`Lerp`, `InverseLerp`, and `SmoothStep` keep huge finite opposite-sign midpoint interpolation finite; `InverseLerp` returns 0 for equal bounds, and `SmoothStep` propagates NaN values before edge validation, requires finite edges with `EArgumentError`, and preserves the documented equal-edge step boundary behavior.",
    ),
    (
        "docs/math/README.md",
        "`Lerp`, `InverseLerp`, and `SmoothStep` keep huge finite opposite-sign midpoint interpolation finite; `InverseLerp` returns 0 for equal bounds, and `SmoothStep` propagates NaN values before edge validation, requires finite edges with `EArgumentError`, and preserves the documented equal-edge step boundary behavior.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Lerp`, `InverseLerp`, and `SmoothStep` keep huge finite opposite-sign midpoint interpolation finite; `InverseLerp` returns 0 for equal bounds, and `SmoothStep` propagates NaN values before edge validation, requires finite edges with `EArgumentError`, and preserves the documented equal-edge step boundary behavior.",
    ),
)
REQUIRED_SCALAR_MIN_MAX_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.",
    ),
    (
        "docs/math/API.md",
        "`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Min` and `Max` propagate NaN; mixed signed-zero ties return negative zero for `Min` and positive zero for `Max`, while same-sign zero ties preserve that sign.",
    ),
)
REQUIRED_SCALAR_FLOAT_COMPARE_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.",
    ),
    (
        "docs/math/API.md",
        "`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`FloatEquals` and `FloatIsZero` reject NaN, infinite, or negative epsilon values, reject NaN values, and only treat matching infinities as equal.",
    ),
)
REQUIRED_TRIG_POWER_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`; log identities preserve exact `+0` for input `1` and exact `1` for `Log2(2)` and `Log10(10)`.",
    ),
    (
        "docs/math/API.md",
        "`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`; log identities preserve exact `+0` for input `1` and exact `1` for `Log2(2)` and `Log10(10)`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`; log identities preserve exact `+0` for input `1` and exact `1` for `Log2(2)` and `Log10(10)`.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Ln`, `Log2`, and `Log10` return `-Inf` for positive or negative zero, `NaN` for negative finite values and `-Inf`, propagate `NaN`, and return `+Inf` for `+Inf`; log identities preserve exact `+0` for input `1` and exact `1` for `Log2(2)` and `Log10(10)`.",
    ),
    (
        "docs/math/README.md",
        "`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.",
    ),
    (
        "docs/math/API.md",
        "`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Exp` propagates `NaN`, returns `+Inf` for `+Inf`, and returns `+0` for `-Inf`. `Sqrt` preserves signed zero, returns `+Inf` for `+Inf`, and returns `NaN` for `NaN`, negative finite values, or `-Inf`.",
    ),
    (
        "docs/math/README.md",
        "`Sqrt` of positive finite maximum, minimum-normal, and minimum-subnormal inputs returns a positive finite result, and squaring that result stays close to the original input instead of flushing to zero; negative minimum-subnormal inputs return `NaN`.",
    ),
    (
        "docs/math/API.md",
        "`Sqrt` of positive finite maximum, minimum-normal, and minimum-subnormal inputs returns a positive finite result, and squaring that result stays close to the original input instead of flushing to zero; negative minimum-subnormal inputs return `NaN`.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Sqrt` of positive finite maximum, minimum-normal, and minimum-subnormal inputs returns a positive finite result, and squaring that result stays close to the original input instead of flushing to zero; negative minimum-subnormal inputs return `NaN`.",
    ),
    (
        "docs/math/README.md",
        "`Power` returns `1` for base `+1` before NaN-exponent handling and for exponent `0` before NaN-base handling, while exponent `1` preserves the input value exactly after NaN-exponent/base checks. Nonzero NaN bases return `NaN`; infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases follow exponent sign and odd/even sign rules.",
    ),
    (
        "docs/math/API.md",
        "`Power` returns `1` for base `+1` before NaN-exponent handling and for exponent `0` before NaN-base handling, while exponent `1` preserves the input value exactly after NaN-exponent/base checks. Nonzero NaN bases return `NaN`; infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases follow exponent sign and odd/even sign rules.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Power` returns `1` for base `+1` before NaN-exponent handling and for exponent `0` before NaN-base handling, while exponent `1` preserves the input value exactly after NaN-exponent/base checks. Nonzero NaN bases return `NaN`; infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases follow exponent sign and odd/even sign rules.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`Power` returns `1` for base `+1` before NaN-exponent handling and for exponent `0` before NaN-base handling, while exponent `1` preserves the input value exactly after NaN-exponent/base checks. Nonzero NaN bases return `NaN`; infinite exponents follow `|base|` relative to `1`, with `+1` and `-1` returning `1`; infinite bases follow exponent sign and odd/even sign rules.",
    ),
    (
        "docs/math/API.md",
        "Except for exponent `0`, a NaN exponent takes priority over zero-base handling, so `0^NaN` and `-0^NaN` return NaN.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "zero-base NaN-exponent propagation",
    ),
    (
        "docs/math/README.md",
        "`Power` returns `NaN` for negative finite bases with non-integer exponents instead of entering host logarithm domain errors.",
    ),
    (
        "docs/math/API.md",
        "`Power` returns `NaN` for negative finite bases with non-integer exponents instead of entering host logarithm domain errors.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Power` returns `NaN` for negative finite bases with non-integer exponents instead of entering host logarithm domain errors.",
    ),
    (
        "docs/math/README.md",
        "Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.",
    ),
    (
        "docs/math/API.md",
        "Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "Finite `Exp` overflow returns `+Inf`, and finite `Exp` underflow returns `+0`. Finite `Power` overflow and underflow preserve the mathematically required sign for odd integer exponents with negative finite bases.",
    ),
)
REQUIRED_TRIG_LOG_SUBNORMAL_DOC_TRUTH = (
    (
        "docs/math/API.md",
        "`Ln`, `Log2`, and `Log10` accept positive subnormal `Single` and `Double` inputs: results stay finite negative, with `Log2` returning exact exponent positions for the minimum positive subnormal values (`-149` for `Single`, `-1074` for `Double`).",
    ),
)
REQUIRED_TRIG_CIRCULAR_DOC_TRUTH = (
    (
        "docs/math/README.md",
        "`Sin`, `Cos`, and `Tan` propagate `NaN` and return `NaN` for positive or negative infinity; `Sin` and `Tan` preserve signed zero.",
    ),
    (
        "docs/math/API.md",
        "`Sin`, `Cos`, and `Tan` propagate `NaN` and return `NaN` for positive or negative infinity; `Sin` and `Tan` preserve signed zero.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`Sin`, `Cos`, and `Tan` propagate `NaN` and return `NaN` for positive or negative infinity; `Sin` and `Tan` preserve signed zero.",
    ),
    (
        "docs/math/README.md",
        "`ArcSin` preserves signed zero; `ArcSin` and `ArcCos` return `NaN` for `NaN` or values outside `[-1, 1]`. `ArcTan` preserves signed zero, maps infinities to `+/-PI/2`, and returns `NaN` for `NaN`. `ArcTan2` returns `NaN` for `NaN` inputs and explicitly preserves signed-zero and infinite-quadrant behavior.",
    ),
    (
        "docs/math/API.md",
        "`ArcSin` preserves signed zero; `ArcSin` and `ArcCos` return `NaN` for `NaN` or values outside `[-1, 1]`. `ArcTan` preserves signed zero, maps infinities to `+/-PI/2`, and returns `NaN` for `NaN`. `ArcTan2` returns `NaN` for `NaN` inputs and explicitly preserves signed-zero and infinite-quadrant behavior.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`ArcSin` preserves signed zero; `ArcSin` and `ArcCos` return `NaN` for `NaN` or values outside `[-1, 1]`. `ArcTan` preserves signed zero, maps infinities to `+/-PI/2`, and returns `NaN` for `NaN`. `ArcTan2` returns `NaN` for `NaN` inputs and explicitly preserves signed-zero and infinite-quadrant behavior.",
    ),
    (
        "docs/math/README.md",
        "`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.",
    ),
    (
        "docs/math/API.md",
        "`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.",
    ),
    (
        "docs/math/GOAL_TREE.md",
        "`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.",
    ),
    (
        "docs/math/FINAL_API_MIGRATION_DESIGN.md",
        "`ArcTan2` finite extreme ratios, including min-subnormal/max-finite pairs, stay in the correct quadrant and do not raise host overflow exceptions while reducing the ratio.",
    ),
)
REQUIRED_CORE_MAKE_TARGETS: tuple[RequiredCoreMakeTarget, ...] = (
    RequiredCoreMakeTarget(
        target="core-math-api-surface-smoke",
        command="make -C core core-math-api-surface-smoke",
        recipe_steps=(
            (
                "api-surface",
                "$(MAKE) -C tests/nextpas.core.math/test_api_surface clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-smoke",
        command="make -C core core-math-smoke",
        recipe_steps=(
            (
                "api-surface",
                "$(MAKE) core-math-api-surface-smoke",
            ),
            (
                "overview-local-smoke",
                "$(MAKE) core-math-overview-local-smoke",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-overview-local-smoke",
        command="make -C core core-math-overview-local-smoke",
        recipe_steps=(
            (
                "math-overview",
                "$(MAKE) -C examples/nextpas.core.math/math_overview clean run",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-facade-local-smoke",
        command="make -C core core-math-facade-local-smoke",
        recipe_steps=(
            (
                "test-facade",
                "$(MAKE) -C tests/nextpas.core.math/test_facade clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-symbol-scope-local-smoke",
        command="make -C core core-math-symbol-scope-local-smoke",
        recipe_steps=(
            (
                "test-symbol-scope",
                "$(MAKE) -C tests/nextpas.core.math/test_symbol_scope clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-full-local-smoke",
        command="make -C core core-math-full-local-smoke",
        recipe_steps=(
            (
                "full-math-suite",
                "$(MAKE) -C tests/nextpas.core.math clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-leak-local-smoke",
        command="make -C core core-math-leak-local-smoke",
        recipe_steps=(
            (
                "facade-local-smoke",
                "$(MAKE) core-math-facade-local-smoke",
            ),
            (
                "test-scalar",
                "$(MAKE) -C tests/nextpas.core.math/test_scalar clean test",
            ),
            (
                "test-trig",
                "$(MAKE) -C tests/nextpas.core.math/test_trig clean test",
            ),
            (
                "test-vec",
                "$(MAKE) -C tests/nextpas.core.math/test_vec clean test",
            ),
            (
                "test-impl-simd",
                "$(MAKE) core-math-impl-simd-local-smoke",
            ),
            (
                "test-random",
                "$(MAKE) -C tests/nextpas.core.math/test_random clean test",
            ),
            (
                "test-noise",
                "$(MAKE) -C tests/nextpas.core.math/test_noise clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-impl-simd-local-smoke",
        command="make -C core core-math-impl-simd-local-smoke",
        recipe_steps=(
            (
                "test-impl-simd",
                "$(MAKE) -C tests/nextpas.core.math/test_impl_simd clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-impl-simd-win64-compile-smoke",
        command="make -C core core-math-impl-simd-win64-compile-smoke",
        recipe_steps=(
            (
                "test-impl-simd-win64-compile-gate",
                "$(MAKE) -C tests/nextpas.core.math/test_impl_simd_win64_compile_gate clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-trig-local-smoke",
        command="make -C core core-math-trig-local-smoke",
        recipe_steps=(
            (
                "api-surface",
                "$(MAKE) core-math-api-surface-smoke",
            ),
            (
                "facade-local-smoke",
                "$(MAKE) core-math-facade-local-smoke",
            ),
            (
                "test-trig",
                "$(MAKE) -C tests/nextpas.core.math/test_trig clean test",
            ),
        ),
    ),
    RequiredCoreMakeTarget(
        target="core-math-trig-win64-compile-smoke",
        command="make -C core core-math-trig-win64-compile-smoke",
        recipe_steps=(
            (
                "test-trig-host-compile-gate",
                "$(MAKE) -C tests/nextpas.core.math/test_trig_host_compile_gate clean test",
            ),
        ),
    ),
)
COMPILE_ONLY_GATE_AGGREGATE_EXCLUSIONS = (
    (
        ROOT_MAKEFILE_PATH,
        "test-aggregate",
        (
            "tests/nextpas.core.math/test_trig_host_compile_gate",
            "tests/nextpas.core.math/test_impl_simd_win64_compile_gate",
        ),
    ),
    (
        MATH_SUITE_MAKEFILE_PATH,
        "math-full-local",
        (
            "test_trig_host_compile_gate",
            "test_impl_simd_win64_compile_gate",
        ),
    ),
)
COMPILE_ONLY_GATE_EXCLUSION_MARKER_PREFIX = "# compile-only opt-in gate:"
BENCH_SIMD_SEAM_PATH = "benchmarks/nextpas.core.math/bench_simd_seam/bench_simd_seam.lpr"
SIMD_MATHUTIL_PATH = "src/nextpas.core.simd.mathutil.pas"
MATH_IMPL_SIMD_PATH = "src/nextpas.core.math.impl.simd.pas"
MATH_TRIG_PATH = "src/nextpas.core.math.trig.pas"
TRIG_HOST_COMPILE_GATE_MAKEFILE_PATH = (
    "tests/nextpas.core.math/test_trig_host_compile_gate/Makefile"
)
TRIG_HOST_COMPILE_GATE_SOURCE_PATH = (
    "tests/nextpas.core.math/test_trig_host_compile_gate/test_trig_host_compile_gate.lpr"
)
TRIG_HOST_COMPILE_GATE_ROUTES = (
    ("facade", "nextpas.core.math"),
    ("trig", "nextpas.core.math.trig"),
)
TRIG_HOST_COMPILE_GATE_UNARY_FUNCTIONS = (
    "Sin",
    "Cos",
    "Tan",
    "ArcSin",
    "ArcCos",
    "ArcTan",
    "Exp",
    "Ln",
    "Log2",
    "Log10",
    "Sqrt",
)
TRIG_HOST_COMPILE_GATE_BINARY_FUNCTIONS = (
    "ArcTan2",
    "Power",
)
IMPL_SIMD_WIN64_COMPILE_GATE_MAKEFILE_PATH = (
    "tests/nextpas.core.math/test_impl_simd_win64_compile_gate/Makefile"
)
IMPL_SIMD_WIN64_COMPILE_GATE_SOURCE_PATH = (
    "tests/nextpas.core.math/test_impl_simd_win64_compile_gate/test_impl_simd_win64_compile_gate.lpr"
)
INTERNAL_IMPL_TEST_PREFIXES = (
    "tests/nextpas.core.math/test_impl_",
)

CONSUMER_FACING_UNITS = {
    "nextpas.core.math",
    "nextpas.core.math.scalar",
    "nextpas.core.math.trig",
    "nextpas.core.math.vec",
    "nextpas.core.math.mat",
    "nextpas.core.math.quat",
    "nextpas.core.math.transform",
    "nextpas.core.math.easing",
    "nextpas.core.math.random",
}
INTERNAL_UNITS = {
    "nextpas.core.math.impl.scalar",
    "nextpas.core.math.impl.simd",
}
ALLOWED_MATH_UNITS = CONSUMER_FACING_UNITS | INTERNAL_UNITS

LEGACY_PUBLIC_RE = re.compile(
    r"\b(TVector[234]?[A-Za-z]*|TMatrix[34]?[A-Za-z]*|TQuaternion[A-Za-z]*|"
    r"Vector[234]|Matrix[34]|Quaternion|Vectors)\b",
    re.IGNORECASE,
)
LEGACY_PUBLIC_DOC_SYMBOL_RE = re.compile(
    r"\b(TVector[A-Za-z0-9]*|TMatrix[A-Za-z0-9]*|TQuaternion[A-Za-z0-9]*)\b",
    re.IGNORECASE,
)
LEGACY_PUBLIC_DOC_USES_VECTORS_RE = re.compile(
    r"\buses\b(?P<body>[^;]*\bVectors\b[^;]*);",
    re.IGNORECASE | re.DOTALL,
)
LEGACY_PUBLIC_DOC_VECTORS_PATH_RE = re.compile(
    r"\bsrc/math/Vectors\.pas\b",
    re.IGNORECASE,
)
USES_MATH_FFI_RE = re.compile(
    r"\buses\b(?P<body>.*?);",
    re.IGNORECASE | re.DOTALL,
)
EXTERNAL_M_RE = re.compile(
    r"\bexternal\s+(['\"])\s*m\s*\1",
    re.IGNORECASE,
)
LINKLIB_M_RE = re.compile(
    r"(?:\{\$\s*linklib\s+m\s*\}|\(\*\$\s*linklib\s+m\s*\*\))",
    re.IGNORECASE,
)
NATIVE_MATH_LINK_FLAG_RE = re.compile(
    r"(?<![A-Za-z0-9_./-])(?:-k-lm|-lm)(?![A-Za-z0-9_./-])"
)
NATIVE_MATH_LINKING_RULES = {
    "no-naked-external-m",
    "no-native-math-linklib",
    "no-native-math-link-flag",
}
PRIVATE_SIMD_RE = re.compile(
    r"\b("
    r"nextpas\.core\.simd\.(?:"
    r"backend(?:\.[A-Za-z0-9_]+)?|"
    r"dispatch|"
    r"dataplane|"
    r"direct|"
    r"intrinsics(?:\.[A-Za-z0-9_]+)?|"
    r"static(?:\.[A-Za-z0-9_]+)?|"
    r"runtime|"
    r"cpuinfo(?:\.[A-Za-z0-9_]+)?|"
    r"avx[0-9]*(?:\.[A-Za-z0-9_]+)?|"
    r"sse[0-9]*(?:\.[A-Za-z0-9_]+)?|"
    r"ssse3(?:\.[A-Za-z0-9_]+)?|"
    r"neon(?:\.[A-Za-z0-9_]+)?|"
    r"riscvv(?:\.[A-Za-z0-9_]+)?|"
    r"scalar|"
    r"vec[A-Za-z0-9_]*|"
    r"mask[A-Za-z0-9_]*|"
    r"ops|"
    r"utils|"
    r"memutils|"
    r"mathutil|"
    r"alloc|"
    r"arrays[A-Za-z0-9_]*"
    r")|"
    r"P?TSimd(?:DispatchTable|Backend[A-Za-z0-9_]*|DataPlane)|"
    r"PSimdDispatchTable|"
    r"GetDispatchTable|"
    r"GetSimdFacadeDispatchFastPath|"
    r"GetDirectDispatchTable|"
    r"GetCurrentSimdDataPlane(?:Dispatch)?|"
    r"GetCurrentSimdDataPlane[A-Za-z0-9_]*|"
    r"RebindSimdDataPlane|"
    r"TryGetRegisteredBackendDispatchTable"
    r")\b",
    re.IGNORECASE,
)
MATH_IMPL_SIMD_ALLOWED_INTERFACE_USES = {
    "nextpas.core.math.mat",
    "nextpas.core.math.quat",
    "nextpas.core.math.vec",
}
MATH_IMPL_SIMD_ALLOWED_PUBLIC_ROUTINES = {
    (
        "simdvec4fadd",
        "function",
        (("const", "tvec4f"), ("const", "tvec4f")),
        "tvec4f",
    ),
    (
        "simdvec4fsub",
        "function",
        (("const", "tvec4f"), ("const", "tvec4f")),
        "tvec4f",
    ),
    (
        "simdvec4fmulcomponents",
        "function",
        (("const", "tvec4f"), ("const", "tvec4f")),
        "tvec4f",
    ),
    (
        "simdvec4fscale",
        "function",
        (("const", "tvec4f"), ("const", "single")),
        "tvec4f",
    ),
    (
        "simdvec4fdot",
        "function",
        (("const", "tvec4f"), ("const", "tvec4f")),
        "single",
    ),
    (
        "simdvec4flength",
        "function",
        (("const", "tvec4f"),),
        "single",
    ),
    (
        "simdvec3fdot",
        "function",
        (("const", "tvec3f"), ("const", "tvec3f")),
        "single",
    ),
    (
        "simdvec3fcross",
        "function",
        (("const", "tvec3f"), ("const", "tvec3f")),
        "tvec3f",
    ),
    (
        "simdmat4fmulvec4f",
        "function",
        (("const", "tmat4f"), ("const", "tvec4f")),
        "tvec4f",
    ),
    (
        "simdquatfrotate",
        "function",
        (("const", "tquatf"), ("const", "tvec3f")),
        "tvec3f",
    ),
}
MATH_IMPL_SIMD_PUBLIC_BACKEND_TYPE_RE = re.compile(
    r"\b(?:[PT]?Vec(?:F|I|U)[0-9]+x[0-9]+|[PT]?Mask[A-Za-z0-9_]*|"
    r"P?TSimd[A-Za-z0-9_]*)\b",
    re.IGNORECASE,
)
PUBLIC_IMPL_RE = re.compile(
    r"\bnextpas\.core\.math\.impl\.[A-Za-z0-9_.]+\b",
    re.IGNORECASE,
)
MATH_IMPL_SIMD_RE = re.compile(
    r"\bnextpas\.core\.math\.impl\.simd\b",
    re.IGNORECASE,
)
PUBLIC_MATH_SOURCE_SIMD_RE = re.compile(
    r"\bnextpas\.core\.(?:math\.impl\.simd|simd)\b",
    re.IGNORECASE,
)
PUBLIC_GLOBAL_RANDOM_RE = re.compile(
    r"^[ \t]{0,2}(?:threadvar|var)\s+"
    r"(?:G(?:Random|Noise)|Global(?:Random|Noise)|Default(?:Random|Noise)|"
    r"Shared(?:Random|Noise)|(?:Random|Noise)(?:Instance|Singleton))\b",
    re.IGNORECASE | re.MULTILINE,
)
RANDOM_NOISE_GLOBAL_HELPER_RE = re.compile(
    r"^[ \t]{0,2}(?:function|procedure)\s+("
    r"Random[A-Za-z0-9_]*|Next[A-Za-z0-9_]*|Roll[A-Za-z0-9_]*|"
    r"WeightedChoice|Shuffle|Noise[A-Za-z0-9_]*|FBM[A-Za-z0-9_]*|"
    r"DefaultRandom|DefaultNoise|SharedRandom|SharedNoise|"
    r"GlobalRandom|GlobalNoise"
    r")\b",
    re.IGNORECASE | re.MULTILINE,
)
RANDOM_NOISE_CLASS_SINGLETON_RE = re.compile(
    r"^\s*class\s+var\s+(?:G|F)?(?:Random|Noise|DefaultRandom|DefaultNoise|SharedRandom|SharedNoise)\b",
    re.IGNORECASE | re.MULTILINE,
)
RANDOM_NOISE_GLOBAL_NAME_RE = re.compile(
    r"\b(G(?:Random|Noise)|Global(?:Random|Noise)|Default(?:Random|Noise)|"
    r"Shared(?:Random|Noise)|(?:Random|Noise)(?:Instance|Singleton))\b",
    re.IGNORECASE,
)
UNIT_NAME_RE = re.compile(
    r"^\s*unit\s+(?P<name>nextpas\.core\.math(?:\.[A-Za-z0-9_]+)*)\s*;",
    re.IGNORECASE | re.MULTILINE,
)
IMPLEMENTATION_RE = re.compile(
    r"^\s*implementation\b",
    re.IGNORECASE | re.MULTILINE,
)
INTERFACE_RE = re.compile(
    r"^\s*interface\b",
    re.IGNORECASE | re.MULTILINE,
)
COMPILER_REF_RE = re.compile(
    r"(?:^|[/\\])compiler(?:[/\\]|$)|scripts/rebuild-compiler\.sh",
    re.IGNORECASE,
)
TRIG_FORBIDDEN_SCALAR_RE = re.compile(
    r"(?:"
    r"\bfunction\s+("
    r"Min|Max|Floor|Ceil|Round|Trunc|Frac|Abs|Clamp|Sign|Lerp|"
    r"InverseLerp|Wrap|SmoothStep|DegToRad|RadToDeg|GCD|LCM|Hypot|Fmod"
    r")\s*\("
    r"|^\s*(DEG_TO_RAD|RAD_TO_DEG)\s*:"
    r")",
    re.IGNORECASE | re.MULTILINE,
)
PUBLIC_CONSTANT_RE = re.compile(
    r"^\s*([A-Z][A-Z0-9_]+)\s*:",
    re.MULTILINE,
)
PUBLIC_TYPE_ALIAS_RE = re.compile(
    r"^\s*(T[A-Za-z0-9_]+)\s*=",
    re.MULTILINE,
)
PUBLIC_FUNCTION_RE = re.compile(
    r"^\s*function\s+([A-Za-z0-9_]+)\s*\(",
    re.MULTILINE,
)
RANDOM_NOISE_PUBLIC_CONTRACTS = (
    PascalClassContract(
        "TRandomGen",
        (
            "constructor Create(const ASeed: UInt64 = 0)",
            "procedure SetSeed(const ASeed: UInt64)",
            "function NextInt: Integer",
            "function NextIntRange(const AMin, AMax: Integer): Integer",
            "function NextFloat: Single",
            "function NextFloatRange(const AMin, AMax: Single): Single",
            "function NextDouble: Double",
            "function NextBool(const AProbability: Single = 0.5): Boolean",
            "function NextGaussian: Single",
            "function NextVec2InCircle: TVec2f",
            "function NextVec2OnCircle: TVec2f",
            "function Roll(const ASides: Integer): Integer",
            "function RollMultiple(const ADice, ASides: Integer): Integer",
            "function WeightedChoice(const AWeights: array of Single): Integer",
            "procedure Shuffle(var AValues: array of Integer)",
            "property State: TRandomState read FState write FState",
        ),
    ),
    PascalClassContract(
        "TNoiseGen",
        (
            "constructor Create(const ASeed: UInt64 = 0)",
            "procedure SetSeed(const ASeed: UInt64)",
            "function Noise1D(const AX: Double): Double",
            "function Noise2D(const AX, AY: Double): Double",
            "function Noise3D(const AX, AY, AZ: Double): Double",
            "function FBM1D(const AX: Double; const AOctaves: Integer; const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double",
            "function FBM2D(const AX, AY: Double; const AOctaves: Integer; const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double",
            "function FBM3D(const AX, AY, AZ: Double; const AOctaves: Integer; const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double",
        ),
    ),
)
REQUIRED_PUBLIC_DECLARATIONS: dict[str, tuple[tuple[str, str], ...]] = {
    "src/nextpas.core.math.pas": (
        ("root-single-min", r"\bfunction\s+Min\s*\(\s*AA\s*,\s*AB\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-max", r"\bfunction\s+Max\s*\(\s*AA\s*,\s*AB\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-clamp", r"\bfunction\s+Clamp\s*\(\s*const\s+AValue\s*,\s*AMin\s*,\s*AMax\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-lerp", r"\bfunction\s+Lerp\s*\(\s*const\s+AA\s*,\s*AB\s*,\s*AT\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-inverselerp", r"\bfunction\s+InverseLerp\s*\(\s*const\s+AA\s*,\s*AB\s*,\s*AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-wrap", r"\bfunction\s+Wrap\s*\(\s*const\s+AValue\s*,\s*AMin\s*,\s*AMax\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-ceil", r"\bfunction\s+Ceil\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("root-single-floor", r"\bfunction\s+Floor\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("root-single-round", r"\bfunction\s+Round\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("root-single-trunc", r"\bfunction\s+Trunc\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("root-single-frac", r"\bfunction\s+Frac\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-abs", r"\bfunction\s+Abs\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-sign", r"\bfunction\s+Sign\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-isnan", r"\bfunction\s+IsNaN\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("root-single-isinfinite", r"\bfunction\s+IsInfinite\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("root-single-floatequals", r"\bfunction\s+FloatEquals\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*Single\s*;\s*const\s+AEpsilon\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("root-single-floatiszero", r"\bfunction\s+FloatIsZero\s*\(\s*const\s+AValue\s*:\s*Single\s*;\s*const\s+AEpsilon\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("root-single-degtorad", r"\bfunction\s+DegToRad\s*\(\s*const\s+ADegrees\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-radtodeg", r"\bfunction\s+RadToDeg\s*\(\s*const\s+ARadians\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-gcd", r"\bfunction\s+GCD\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("root-lcm", r"\bfunction\s+LCM\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("root-hypot-double", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-hypot-single", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-fmod-double", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-fmod-single", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-fmod-extended", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Extended\s*\)\s*:\s*Extended\b"),
        ("root-smoothstep-single", r"\bfunction\s+SmoothStep\s*\(\s*const\s+AEdge0\s*,\s*AEdge1\s*,\s*AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-sin-double", r"\bfunction\s+Sin\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-sin-single", r"\bfunction\s+Sin\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-cos-double", r"\bfunction\s+Cos\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-cos-single", r"\bfunction\s+Cos\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-tan-double", r"\bfunction\s+Tan\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-tan-single", r"\bfunction\s+Tan\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-arcsin-double", r"\bfunction\s+ArcSin\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-arcsin-single", r"\bfunction\s+ArcSin\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-arccos-double", r"\bfunction\s+ArcCos\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-arccos-single", r"\bfunction\s+ArcCos\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-arctan-double", r"\bfunction\s+ArcTan\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-arctan-single", r"\bfunction\s+ArcTan\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-arctan2-double", r"\bfunction\s+ArcTan2\s*\(\s*const\s+AY\s*,\s*AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-arctan2-single", r"\bfunction\s+ArcTan2\s*\(\s*const\s+AY\s*,\s*AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-exp-double", r"\bfunction\s+Exp\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-exp-single", r"\bfunction\s+Exp\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-ln-double", r"\bfunction\s+Ln\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-ln-single", r"\bfunction\s+Ln\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-log2-double", r"\bfunction\s+Log2\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-log2-single", r"\bfunction\s+Log2\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-log10-double", r"\bfunction\s+Log10\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-log10-single", r"\bfunction\s+Log10\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-power-double", r"\bfunction\s+Power\s*\(\s*const\s+ABase\s*,\s*AExponent\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-power-single", r"\bfunction\s+Power\s*\(\s*const\s+ABase\s*,\s*AExponent\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-trig-sqrt-double", r"\bfunction\s+Sqrt\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-trig-sqrt-single", r"\bfunction\s+Sqrt\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
    ),
    "src/nextpas.core.math.scalar.pas": (
        ("scalar-single-min", r"\bfunction\s+Min\s*\(\s*AA\s*,\s*AB\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-max", r"\bfunction\s+Max\s*\(\s*AA\s*,\s*AB\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-clamp", r"\bfunction\s+Clamp\s*\(\s*const\s+AValue\s*,\s*AMin\s*,\s*AMax\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-lerp", r"\bfunction\s+Lerp\s*\(\s*const\s+AA\s*,\s*AB\s*,\s*AT\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-inverselerp", r"\bfunction\s+InverseLerp\s*\(\s*const\s+AA\s*,\s*AB\s*,\s*AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-wrap", r"\bfunction\s+Wrap\s*\(\s*const\s+AValue\s*,\s*AMin\s*,\s*AMax\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-ceil", r"\bfunction\s+Ceil\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("scalar-single-floor", r"\bfunction\s+Floor\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("scalar-single-round", r"\bfunction\s+Round\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("scalar-single-trunc", r"\bfunction\s+Trunc\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("scalar-single-frac", r"\bfunction\s+Frac\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-abs", r"\bfunction\s+Abs\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-sign", r"\bfunction\s+Sign\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-isnan", r"\bfunction\s+IsNaN\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("scalar-single-isinfinite", r"\bfunction\s+IsInfinite\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("scalar-single-floatequals", r"\bfunction\s+FloatEquals\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*Single\s*;\s*const\s+AEpsilon\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("scalar-single-floatiszero", r"\bfunction\s+FloatIsZero\s*\(\s*const\s+AValue\s*:\s*Single\s*;\s*const\s+AEpsilon\s*:\s*Single\s*\)\s*:\s*Boolean\b"),
        ("scalar-single-degtorad", r"\bfunction\s+DegToRad\s*\(\s*const\s+ADegrees\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-radtodeg", r"\bfunction\s+RadToDeg\s*\(\s*const\s+ARadians\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-gcd", r"\bfunction\s+GCD\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("scalar-lcm", r"\bfunction\s+LCM\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("scalar-hypot-double", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("scalar-hypot-single", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-fmod-double", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("scalar-fmod-single", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-fmod-extended", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Extended\s*\)\s*:\s*Extended\b"),
        ("scalar-single-smoothstep", r"\bfunction\s+SmoothStep\s*\(\s*const\s+AEdge0\s*,\s*AEdge1\s*,\s*AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-smoothstep-double", r"\bfunction\s+SmoothStep\s*\(\s*const\s+AEdge0\s*,\s*AEdge1\s*,\s*AValue\s*:\s*Double\s*\)\s*:\s*Double\b"),
    ),
    "src/nextpas.core.math.trig.pas": (
        ("trig-single-sin", r"\bfunction\s+Sin\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-cos", r"\bfunction\s+Cos\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-tan", r"\bfunction\s+Tan\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-arcsin", r"\bfunction\s+ArcSin\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-arccos", r"\bfunction\s+ArcCos\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-arctan", r"\bfunction\s+ArcTan\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-arctan2", r"\bfunction\s+ArcTan2\s*\(\s*const\s+AY\s*,\s*AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-exp", r"\bfunction\s+Exp\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-ln", r"\bfunction\s+Ln\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-log2", r"\bfunction\s+Log2\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-log10", r"\bfunction\s+Log10\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-power", r"\bfunction\s+Power\s*\(\s*const\s+ABase\s*,\s*AExponent\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-sqrt", r"\bfunction\s+Sqrt\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
    ),
    "src/nextpas.core.math.vec.pas": (
        ("vec-type-2f", r"\bTVec2f\s*=\s*packed\s+record\b"),
        ("vec-type-3f", r"\bTVec3f\s*=\s*packed\s+record\b"),
        ("vec-type-4f", r"\bTVec4f\s*=\s*packed\s+record\b"),
        ("vec-type-2d", r"\bTVec2d\s*=\s*packed\s+record\b"),
        ("vec-type-3d", r"\bTVec3d\s*=\s*packed\s+record\b"),
        ("vec-type-4d", r"\bTVec4d\s*=\s*packed\s+record\b"),
        ("vec-dot", r"\bclass\s+function\s+Dot\s*\("),
        ("vec-cross", r"\bclass\s+function\s+Cross\s*\("),
        ("vec-mul-components", r"\bclass\s+function\s+MulComponents\s*\("),
        ("vec-div-components", r"\bclass\s+function\s+DivComponents\s*\("),
    ),
    "src/nextpas.core.math.mat.pas": (
        ("mat-type-3f", r"\bTMat3f\s*=\s*packed\s+record\b"),
        ("mat-type-4f", r"\bTMat4f\s*=\s*packed\s+record\b"),
        ("mat-type-3d", r"\bTMat3d\s*=\s*packed\s+record\b"),
        ("mat-type-4d", r"\bTMat4d\s*=\s*packed\s+record\b"),
        ("mat-identity", r"\bclass\s+function\s+Identity\s*:\s*TMat[34][fd]\b"),
        ("mat-try-inverse", r"\bfunction\s+TryInverse\s*\(\s*out\s+AInverse\s*:\s*TMat[34][fd]\s*\)\s*:\s*Boolean\b"),
        ("mat-determinant", r"\bfunction\s+Determinant\s*:\s*(?:Single|Double)\b"),
        ("mat-transpose", r"\bfunction\s+Transpose\s*:\s*TMat[34][fd]\b"),
    ),
    "src/nextpas.core.math.quat.pas": (
        ("quat-type-f", r"\bTQuatf\s*=\s*packed\s+record\b"),
        ("quat-type-d", r"\bTQuatd\s*=\s*packed\s+record\b"),
        ("quat-identity", r"\bclass\s+function\s+Identity\s*:\s*TQuat[fd]\b"),
        ("quat-from-axis-angle", r"\bclass\s+function\s+FromAxisAngle\s*\("),
        ("quat-to-axis-angle", r"\bprocedure\s+ToAxisAngle\s*\("),
        ("quat-to-rotation-matrix", r"\bfunction\s+ToRotationMatrix\s*:\s*TMat3[fd]\b"),
        ("quat-rotate", r"\bfunction\s+Rotate\s*\("),
        ("quat-slerp", r"\bclass\s+function\s+Slerp\s*\("),
        ("quat-nlerp", r"\bclass\s+function\s+Nlerp\s*\("),
    ),
    "src/nextpas.core.math.transform.pas": (
        ("transform-ortho", r"\bfunction\s+Ortho\s*\("),
        ("transform-perspective", r"\bfunction\s+Perspective\s*\("),
        ("transform-lookat", r"\bfunction\s+LookAt\s*\("),
        ("transform-translate", r"\bfunction\s+Translate\s*\("),
        ("transform-scale", r"\bfunction\s+Scale\s*\("),
        ("transform-rotate-x", r"\bfunction\s+RotateX\s*\("),
        ("transform-rotate-y", r"\bfunction\s+RotateY\s*\("),
        ("transform-rotate-z", r"\bfunction\s+RotateZ\s*\("),
        ("transform-camera-2d", r"\bfunction\s+Camera2D\s*\("),
    ),
    "src/nextpas.core.math.easing.pas": (
        ("easing-function-type", r"\bTEasingFunction\s*=\s*function\s*\("),
        ("easing-linear", r"\bfunction\s+EaseLinear\s*\("),
        ("easing-in-quad", r"\bfunction\s+EaseInQuad\s*\("),
        ("easing-out-quad", r"\bfunction\s+EaseOutQuad\s*\("),
        ("easing-in-out-quad", r"\bfunction\s+EaseInOutQuad\s*\("),
        ("easing-in-cubic", r"\bfunction\s+EaseInCubic\s*\("),
        ("easing-out-cubic", r"\bfunction\s+EaseOutCubic\s*\("),
        ("easing-in-out-cubic", r"\bfunction\s+EaseInOutCubic\s*\("),
        ("easing-in-quart", r"\bfunction\s+EaseInQuart\s*\("),
        ("easing-out-quart", r"\bfunction\s+EaseOutQuart\s*\("),
        ("easing-in-out-quart", r"\bfunction\s+EaseInOutQuart\s*\("),
        ("easing-in-expo", r"\bfunction\s+EaseInExpo\s*\("),
        ("easing-out-expo", r"\bfunction\s+EaseOutExpo\s*\("),
        ("easing-in-out-expo", r"\bfunction\s+EaseInOutExpo\s*\("),
        ("easing-in-elastic", r"\bfunction\s+EaseInElastic\s*\("),
        ("easing-out-elastic", r"\bfunction\s+EaseOutElastic\s*\("),
        ("easing-in-out-elastic", r"\bfunction\s+EaseInOutElastic\s*\("),
        ("easing-in-back", r"\bfunction\s+EaseInBack\s*\("),
        ("easing-out-back", r"\bfunction\s+EaseOutBack\s*\("),
        ("easing-in-out-back", r"\bfunction\s+EaseInOutBack\s*\("),
        ("easing-in-bounce", r"\bfunction\s+EaseInBounce\s*\("),
        ("easing-out-bounce", r"\bfunction\s+EaseOutBounce\s*\("),
        ("easing-in-out-bounce", r"\bfunction\s+EaseInOutBounce\s*\("),
    ),
    "src/nextpas.core.math.random.pas": (
        ("random-state-type", r"\bTRandomState\s*=\s*record\b"),
        ("random-gen-class", r"\bTRandomGen\s*=\s*class\b"),
        ("random-next-int-range", r"\bfunction\s+NextIntRange\s*\(\s*const\s+AMin\s*,\s*AMax\s*:\s*Integer\s*\)\s*:\s*Integer\b"),
        ("random-next-float-range", r"\bfunction\s+NextFloatRange\s*\(\s*const\s+AMin\s*,\s*AMax\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("random-next-bool", r"\bfunction\s+NextBool\s*\(\s*const\s+AProbability\s*:\s*Single\s*=\s*0\.5\s*\)\s*:\s*Boolean\b"),
        ("random-gaussian", r"\bfunction\s+NextGaussian\s*:\s*Single\b"),
        ("random-circle-inside", r"\bfunction\s+NextVec2InCircle\s*:\s*TVec2f\b"),
        ("random-circle-on", r"\bfunction\s+NextVec2OnCircle\s*:\s*TVec2f\b"),
        ("random-roll", r"\bfunction\s+Roll\s*\(\s*const\s+ASides\s*:\s*Integer\s*\)\s*:\s*Integer\b"),
        ("random-roll-multiple", r"\bfunction\s+RollMultiple\s*\(\s*const\s+ADice\s*,\s*ASides\s*:\s*Integer\s*\)\s*:\s*Integer\b"),
        ("random-weighted-choice", r"\bfunction\s+WeightedChoice\s*\(\s*const\s+AWeights\s*:\s*array\s+of\s+Single\s*\)\s*:\s*Integer\b"),
        ("random-shuffle", r"\bprocedure\s+Shuffle\s*\(\s*var\s+AValues\s*:\s*array\s+of\s+Integer\s*\)"),
        ("noise-gen-class", r"\bTNoiseGen\s*=\s*class\b"),
        ("noise-1d", r"\bfunction\s+Noise1D\s*\(\s*const\s+AX\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("noise-2d", r"\bfunction\s+Noise2D\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("noise-3d", r"\bfunction\s+Noise3D\s*\(\s*const\s+AX\s*,\s*AY\s*,\s+AZ\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("noise-fbm-1d", r"\bfunction\s+FBM1D\s*\("),
        ("noise-fbm-2d", r"\bfunction\s+FBM2D\s*\("),
        ("noise-fbm-3d", r"\bfunction\s+FBM3D\s*\("),
    ),
    "src/nextpas.core.math.impl.simd.pas": (
        ("impl-simd-vec4f-add", r"\bfunction\s+SimdVec4fAdd\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*TVec4f\s*\)\s*:\s*TVec4f\b"),
        ("impl-simd-vec4f-sub", r"\bfunction\s+SimdVec4fSub\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*TVec4f\s*\)\s*:\s*TVec4f\b"),
        ("impl-simd-vec4f-mul-components", r"\bfunction\s+SimdVec4fMulComponents\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*TVec4f\s*\)\s*:\s*TVec4f\b"),
        ("impl-simd-vec4f-scale", r"\bfunction\s+SimdVec4fScale\s*\(\s*const\s+AValue\s*:\s*TVec4f\s*;\s*const\s+AScalar\s*:\s*Single\s*\)\s*:\s*TVec4f\b"),
        ("impl-simd-vec4f-dot", r"\bfunction\s+SimdVec4fDot\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*TVec4f\s*\)\s*:\s*Single\b"),
        ("impl-simd-vec4f-length", r"\bfunction\s+SimdVec4fLength\s*\(\s*const\s+AValue\s*:\s*TVec4f\s*\)\s*:\s*Single\b"),
        ("impl-simd-vec3f-dot", r"\bfunction\s+SimdVec3fDot\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*TVec3f\s*\)\s*:\s*Single\b"),
        ("impl-simd-vec3f-cross", r"\bfunction\s+SimdVec3fCross\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*TVec3f\s*\)\s*:\s*TVec3f\b"),
        ("impl-simd-mat4f-mul-vec4f", r"\bfunction\s+SimdMat4fMulVec4f\s*\(\s*const\s+AMatrix\s*:\s*TMat4f\s*;\s*const\s+AVector\s*:\s*TVec4f\s*\)\s*:\s*TVec4f\b"),
        ("impl-simd-quatf-rotate", r"\bfunction\s+SimdQuatfRotate\s*\(\s*const\s+AQuat\s*:\s*TQuatf\s*;\s*const\s+AVector\s*:\s*TVec3f\s*\)\s*:\s*TVec3f\b"),
    ),
}
REQUIRED_VECTOR_LENGTH_SQR_RECORD_CONTRACTS = (
    ("vec-2f-lengthsqr", "TVec2f", "Single"),
    ("vec-3f-lengthsqr", "TVec3f", "Single"),
    ("vec-4f-lengthsqr", "TVec4f", "Single"),
    ("vec-2d-lengthsqr", "TVec2d", "Double"),
    ("vec-3d-lengthsqr", "TVec3d", "Double"),
    ("vec-4d-lengthsqr", "TVec4d", "Double"),
)
REQUIRED_VECTOR_PUBLIC_RECORD_CONTRACTS = (
    ("vec-2f", "TVec2f", "Single", ("X", "Y"), "0..1", False),
    ("vec-3f", "TVec3f", "Single", ("X", "Y", "Z"), "0..2", True),
    ("vec-4f", "TVec4f", "Single", ("X", "Y", "Z", "W"), "0..3", False),
    ("vec-2d", "TVec2d", "Double", ("X", "Y"), "0..1", False),
    ("vec-3d", "TVec3d", "Double", ("X", "Y", "Z"), "0..2", True),
    ("vec-4d", "TVec4d", "Double", ("X", "Y", "Z", "W"), "0..3", False),
)
REQUIRED_MATRIX_PUBLIC_RECORD_CONTRACTS = (
    ("mat-3f", "TMat3f", "Single", "TVec3f", "0..2", True),
    ("mat-4f", "TMat4f", "Single", "TVec4f", "0..3", False),
    ("mat-3d", "TMat3d", "Double", "TVec3d", "0..2", True),
    ("mat-4d", "TMat4d", "Double", "TVec4d", "0..3", False),
)
REQUIRED_QUATERNION_PUBLIC_RECORD_CONTRACTS = (
    ("quat-f", "TQuatf", "Single", "TVec3f", "TMat3f"),
    ("quat-d", "TQuatd", "Double", "TVec3d", "TMat3d"),
)
REQUIRED_BENCHMARK_MARKERS: dict[str, tuple[tuple[str, str], ...]] = {
    BENCH_SIMD_SEAM_PATH: (
        (
            "bench-simd-seam-internal-only-decision",
            "decision-note=internal SIMD seam only; public value methods stay scalar",
        ),
        (
            "bench-simd-seam-no-public-cutover",
            "public-cutover=not-approved-without-profiled-runtime-and-public-simd-contracts",
        ),
        ("bench-mat4f-vector-scalar-baseline", "TMat4f scalar mat-vec"),
        ("bench-mat4f-vector-simd-seam", "TMat4f simd seam mat-vec"),
        ("bench-mat4f-matrix-scalar-baseline", "TMat4f scalar mat-mat"),
        ("bench-quatf-rotate-scalar-baseline", "TQuatf scalar rotate"),
        ("bench-quatf-rotate-simd-seam", "TQuatf simd seam rotate"),
    ),
}
REQUIRED_BEHAVIOR_TEST_MARKERS: tuple[RequiredBehaviorTestMarker, ...] = (
    RequiredBehaviorTestMarker("facade-scalar-trig", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('scalar and trig re-export'"),
    RequiredBehaviorTestMarker("facade-rounding", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade scalar rounding surface'"),
    RequiredBehaviorTestMarker("facade-new-scalar", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade new scalar surface'"),
    RequiredBehaviorTestMarker("facade-vector", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade vector surface'"),
    RequiredBehaviorTestMarker("facade-random", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade random surface'"),
    RequiredBehaviorTestMarker("facade-root-forwarders", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade root forwarder compile surface'"),
    RequiredBehaviorTestMarker("facade-root-forwarders-scalar-family", "tests/nextpas.core.math/test_facade/test_facade.lpr", "facade root forwarder compile surface touches scalar family"),
    RequiredBehaviorTestMarker("facade-root-forwarders-trig-family", "tests/nextpas.core.math/test_facade/test_facade.lpr", "facade root forwarder compile surface touches trig family"),
    RequiredBehaviorTestMarker("facade-root-forwarders-transform-family", "tests/nextpas.core.math/test_facade/test_facade.lpr", "facade root forwarder compile surface touches transform family"),
    RequiredBehaviorTestMarker("facade-root-forwarders-easing-family", "tests/nextpas.core.math/test_facade/test_facade.lpr", "facade root forwarder compile surface touches easing family"),
    RequiredBehaviorTestMarker("facade-root-trig-declaration-parity", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade root trig declaration parity compile surface'"),
    RequiredBehaviorTestMarker("facade-trig-power-finite-identity-precision", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade Power finite identity precision contracts'"),
    RequiredBehaviorTestMarker("facade-log-exact-identity", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade Log exact identity contracts'"),
    RequiredBehaviorTestMarker("facade-trig-ieee-domain-smoke", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade trig IEEE domain smoke'"),
    RequiredBehaviorTestMarker("trig-direct-non-finite-overload-parity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('direct trig non-finite overload parity contracts'"),
    RequiredBehaviorTestMarker("trig-atan2-single-second-nan", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2(Single 1,NaN)=NaN"),
    RequiredBehaviorTestMarker("facade-wrap-error-semantics", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade Wrap error semantics'"),
    RequiredBehaviorTestMarker("facade-fmod-huge-untyped-literals", "tests/nextpas.core.math/test_facade/test_facade.lpr", "facade Fmod huge untyped finite literals choose wide finite remainder path"),
    RequiredBehaviorTestMarker("scalar-constants", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('constants'"),
    RequiredBehaviorTestMarker("scalar-min-max-clamp", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('min max clamp'"),
    RequiredBehaviorTestMarker("scalar-clamp-nan-value", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp Double NaN value propagates NaN"),
    RequiredBehaviorTestMarker("scalar-clamp-double-positive-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp Double positive infinity clamps high"),
    RequiredBehaviorTestMarker("scalar-clamp-double-negative-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp Double negative infinity clamps low"),
    RequiredBehaviorTestMarker("scalar-clamp-reversed-bounds", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp: minimum must not exceed maximum"),
    RequiredBehaviorTestMarker("scalar-clamp-finite-bounds", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp: minimum and maximum must be finite"),
    RequiredBehaviorTestMarker("scalar-clamp-equal-bound-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp Double equal negative-zero bounds return bound"),
    RequiredBehaviorTestMarker("scalar-clamp-single-positive-zero-inside-range", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Clamp Single positive zero inside range keeps sign"),
    RequiredBehaviorTestMarker("scalar-ieee-edge-contracts", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('scalar IEEE edge contracts'"),
    RequiredBehaviorTestMarker("scalar-ieee-round-ties-away", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round Double ties away from zero positive"),
    RequiredBehaviorTestMarker("scalar-ieee-abs-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Abs Double negative zero returns positive zero"),
    RequiredBehaviorTestMarker("scalar-ieee-frac-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac Double exact negative integer keeps input sign"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-inf-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Double positive infinity dominates NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-nan-only", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Double NaN-only returns NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-double-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Double signed-zero pair returns positive zero"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-single-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Single signed-zero pair returns positive zero"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-max-finite-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Double max finite pair saturates to positive infinity"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-single-max-finite-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Single max finite pair saturates to positive infinity"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-double-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Double min subnormal 3-4-5 stays subnormal finite"),
    RequiredBehaviorTestMarker("scalar-ieee-hypot-single-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Hypot Single min subnormal 3-4-5 stays subnormal finite"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double exact negative dividend keeps negative zero remainder"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-zero-divisor", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double zero divisor returns NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-negative-zero-divisor", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double negative zero divisor returns NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-non-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double NaN divisor returns NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-cross-infinite-divisor", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double negative finite over positive infinity returns dividend"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-cross-infinite-divisor-symmetric", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double positive finite over negative infinity returns dividend"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-non-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single finite over infinity returns dividend"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-zero-divisor", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single zero divisor returns NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-negative-zero-divisor", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single negative zero divisor returns NaN"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-cross-infinite-divisor", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single negative finite over positive infinity returns dividend"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-cross-infinite-divisor-symmetric", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single positive finite over negative infinity returns dividend"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-huge-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double huge finite quotient stays finite remainder"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-huge-untyped-literals", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod huge untyped finite literals choose wide finite remainder path"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-negative-huge-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single negative huge finite quotient keeps dividend sign"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-double-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Double min subnormal divisor keeps one-ulp remainder"),
    RequiredBehaviorTestMarker("scalar-ieee-fmod-single-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Fmod Single min subnormal divisor keeps one-ulp remainder"),
    RequiredBehaviorTestMarker("scalar-ieee-overflow-no-div-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsMulOverflow SizeUInt zero times high"),
    RequiredBehaviorTestMarker("scalar-ieee-overflow-no-div-zero-symmetric", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsMulOverflow SizeUInt high times zero"),
    RequiredBehaviorTestMarker("scalar-overflow-uint32-add-high-plus-one", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsAddOverflow UInt32 high plus one"),
    RequiredBehaviorTestMarker("scalar-overflow-uint32-add-high-minus-one-plus-one", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsAddOverflow UInt32 high minus one plus one"),
    RequiredBehaviorTestMarker("scalar-overflow-uint32-mul-zero-times-high", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsMulOverflow UInt32 zero times high"),
    RequiredBehaviorTestMarker("scalar-overflow-uint32-mul-high-times-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsMulOverflow UInt32 high times zero"),
    RequiredBehaviorTestMarker("scalar-overflow-uint32-mul-high-times-two", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "IsMulOverflow UInt32 high times two"),
    RequiredBehaviorTestMarker("scalar-min-max-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Min Double propagates NaN first"),
    RequiredBehaviorTestMarker("scalar-min-max-signed-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Min Single keeps negative zero first"),
    RequiredBehaviorTestMarker("scalar-min-max-same-positive-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Min Double same positive zero returns positive zero"),
    RequiredBehaviorTestMarker("scalar-min-max-same-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Max Double same negative zero returns negative zero"),
    RequiredBehaviorTestMarker("scalar-min-max-single-same-positive-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Max Single same positive zero returns positive zero"),
    RequiredBehaviorTestMarker("scalar-min-max-single-same-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Max Single same negative zero returns negative zero"),
    RequiredBehaviorTestMarker("scalar-float-compare-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Double +Inf exact"),
    RequiredBehaviorTestMarker("scalar-float-compare-finite-vs-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Double rejects finite versus +Inf with valid epsilon"),
    RequiredBehaviorTestMarker("scalar-float-compare-single-finite-vs-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Single rejects finite versus +Inf with valid epsilon"),
    RequiredBehaviorTestMarker("scalar-float-compare-invalid-epsilon", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals rejects infinite epsilon"),
    RequiredBehaviorTestMarker("scalar-float-compare-invalid-epsilon-equal-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Double rejects infinite epsilon for equal finite values"),
    RequiredBehaviorTestMarker("scalar-float-compare-single-invalid-epsilon-equal-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Single rejects infinite epsilon for equal finite values"),
    RequiredBehaviorTestMarker("vector-abi-data-offsets", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d Data offsets match packed named fields"),
    RequiredBehaviorTestMarker("vector-min-subnormal-length-normalize", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector min subnormal length and normalize contracts'"),
    RequiredBehaviorTestMarker("matrix-abi-order-contracts", "tests/nextpas.core.math/test_mat/test_mat.lpr", "TMat4d multiplication order is column-vector associative"),
    RequiredBehaviorTestMarker("quaternion-abi-raw-hamilton", "tests/nextpas.core.math/test_quat/test_quat.lpr", "TQuatd operator multiply is raw Hamilton product without normalization"),
    RequiredBehaviorTestMarker("scalar-float-compare-double-nan-first", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Double rejects NaN first"),
    RequiredBehaviorTestMarker("scalar-float-compare-double-nan-second", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Double rejects NaN second"),
    RequiredBehaviorTestMarker("scalar-float-compare-single-nan-first", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Single rejects NaN first"),
    RequiredBehaviorTestMarker("scalar-float-compare-single-nan-second", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatEquals Single rejects NaN second"),
    RequiredBehaviorTestMarker("scalar-float-is-zero-invalid", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatIsZero Double rejects NaN value"),
    RequiredBehaviorTestMarker("scalar-float-is-zero-double-positive-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatIsZero Double rejects +Inf value"),
    RequiredBehaviorTestMarker("scalar-float-is-zero-double-negative-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatIsZero Double rejects -Inf value"),
    RequiredBehaviorTestMarker("scalar-float-is-zero-single-positive-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatIsZero Single rejects +Inf value"),
    RequiredBehaviorTestMarker("scalar-float-is-zero-single-negative-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "FloatIsZero Single rejects -Inf value"),
    RequiredBehaviorTestMarker("scalar-interpolation", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('interpolation'"),
    RequiredBehaviorTestMarker("scalar-lerp-huge-finite-double", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Lerp Double huge opposite finite midpoint stays finite"),
    RequiredBehaviorTestMarker("scalar-lerp-huge-finite-single", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Lerp Single huge opposite finite midpoint stays finite"),
    RequiredBehaviorTestMarker("scalar-lerp-huge-finite-off-center", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Lerp Double huge opposite finite off-center"),
    RequiredBehaviorTestMarker("scalar-lerp-huge-finite-reversed", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Lerp Double huge reversed finite off-center"),
    RequiredBehaviorTestMarker("scalar-inverse-lerp-huge-finite-double", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "InverseLerp Double huge opposite finite midpoint returns half"),
    RequiredBehaviorTestMarker("scalar-inverse-lerp-huge-finite-single", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "InverseLerp Single huge opposite finite midpoint returns half"),
    RequiredBehaviorTestMarker("scalar-inverse-lerp-huge-finite-off-center", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "InverseLerp Double huge opposite finite off-center returns quarter"),
    RequiredBehaviorTestMarker("scalar-inverse-lerp-huge-finite-reversed", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "InverseLerp Double huge reversed finite off-center returns quarter"),
    RequiredBehaviorTestMarker("scalar-smoothstep-huge-finite-double", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Double huge opposite finite midpoint returns half"),
    RequiredBehaviorTestMarker("scalar-smoothstep-huge-finite-single", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Single huge opposite finite midpoint returns half"),
    RequiredBehaviorTestMarker("scalar-wrap-equal-bounds", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Wrap Double equal bounds returns minimum"),
    RequiredBehaviorTestMarker("scalar-wrap-huge-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Wrap Double huge finite range stays finite"),
    RequiredBehaviorTestMarker("scalar-wrap-single-huge-finite", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Wrap Single huge finite range stays finite"),
    RequiredBehaviorTestMarker("scalar-range-boundary-edges", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('scalar range boundary edge contracts'"),
    RequiredBehaviorTestMarker("scalar-inverse-lerp-equal-bounds", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "InverseLerp Double equal bounds returns 0"),
    RequiredBehaviorTestMarker("scalar-smoothstep-equal-edges", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Double equal edges returns step boundary"),
    RequiredBehaviorTestMarker("scalar-smoothstep-equal-edges-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Double equal edges propagates NaN value"),
    RequiredBehaviorTestMarker("scalar-smoothstep-single-equal-edges-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Single equal edges propagates NaN value"),
    RequiredBehaviorTestMarker("scalar-smoothstep-single-nan-before-non-finite-edge", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Single NaN value propagates before non-finite edge validation"),
    RequiredBehaviorTestMarker("scalar-smoothstep-double-nan-before-non-finite-edge", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Double NaN value propagates before non-finite edge validation"),
    RequiredBehaviorTestMarker("scalar-smoothstep-edge-error-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep: edges must be finite"),
    RequiredBehaviorTestMarker("scalar-smoothstep-single-nan-edge", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Single NaN edge"),
    RequiredBehaviorTestMarker("scalar-smoothstep-double-nan-edge", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Double NaN edge"),
    RequiredBehaviorTestMarker("scalar-smoothstep-single-infinite-edge", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Single infinite edge"),
    RequiredBehaviorTestMarker("scalar-smoothstep-double-infinite-edge", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "SmoothStep Double infinite edge"),
    RequiredBehaviorTestMarker("scalar-wrap-reversed-bounds", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Wrap: minimum must not exceed maximum"),
    RequiredBehaviorTestMarker("scalar-wrap-non-finite-inputs", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Wrap: value, minimum, and maximum must be finite"),
    RequiredBehaviorTestMarker("scalar-rounding-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('rounding and sign'"),
    RequiredBehaviorTestMarker("scalar-sign-angle-edge-contracts", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('scalar sign and angle edge contracts'"),
    RequiredBehaviorTestMarker("scalar-sign-int-min-no-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Sign Int64 minimum returns negative one"),
    RequiredBehaviorTestMarker("scalar-sign-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Sign Double NaN propagates NaN"),
    RequiredBehaviorTestMarker("scalar-sign-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Sign Double negative zero keeps negative zero"),
    RequiredBehaviorTestMarker("scalar-degtorad-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Double NaN propagates NaN"),
    RequiredBehaviorTestMarker("scalar-degtorad-single-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Single positive infinity propagates infinity"),
    RequiredBehaviorTestMarker("scalar-degtorad-positive-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Double positive zero keeps positive zero"),
    RequiredBehaviorTestMarker("scalar-degtorad-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Double negative zero keeps negative zero"),
    RequiredBehaviorTestMarker("scalar-degtorad-max-finite-no-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Double max finite stays finite"),
    RequiredBehaviorTestMarker("scalar-degtorad-double-max-finite-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Double max finite stays positive"),
    RequiredBehaviorTestMarker("scalar-degtorad-single-max-finite-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Single max finite stays positive"),
    RequiredBehaviorTestMarker("scalar-degtorad-double-negative-max-finite-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Double negative max finite stays negative"),
    RequiredBehaviorTestMarker("scalar-degtorad-single-negative-max-finite-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "DegToRad Single negative max finite stays negative"),
    RequiredBehaviorTestMarker("scalar-radtodeg-nan", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "RadToDeg Double NaN propagates NaN"),
    RequiredBehaviorTestMarker("scalar-radtodeg-single-infinity", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "RadToDeg Single positive infinity propagates infinity"),
    RequiredBehaviorTestMarker("scalar-radtodeg-positive-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "RadToDeg Double positive zero keeps positive zero"),
    RequiredBehaviorTestMarker("scalar-radtodeg-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "RadToDeg Double negative zero keeps negative zero"),
    RequiredBehaviorTestMarker("scalar-radtodeg-finite-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "RadToDeg Double max finite overflows to positive infinity"),
    RequiredBehaviorTestMarker("scalar-radtodeg-negative-finite-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "RadToDeg Double negative max finite overflows to negative infinity"),
    RequiredBehaviorTestMarker("scalar-float-predicates", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('float predicates'"),
    RequiredBehaviorTestMarker("scalar-extras", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('number theory and scalar extras'"),
    RequiredBehaviorTestMarker("scalar-gcd-lcm-int64-boundary", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('GCD LCM Int64 boundary contracts'"),
    RequiredBehaviorTestMarker("scalar-gcd-low-int64-negative-two-representable", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "GCD Low(Int64) with negative two returns representable divisor"),
    RequiredBehaviorTestMarker("scalar-gcd-zero-negative-high-normalizes-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "GCD zero with negative High(Int64) normalizes sign"),
    RequiredBehaviorTestMarker("scalar-gcd-low-low-raises", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "GCD(Low(Int64), Low(Int64))"),
    RequiredBehaviorTestMarker("scalar-lcm-low-zero-before-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "LCM Low(Int64) with zero returns zero before overflow"),
    RequiredBehaviorTestMarker("scalar-lcm-high-negative-one-normalizes-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "LCM High(Int64) with negative one normalizes sign"),
    RequiredBehaviorTestMarker("scalar-lcm-low-one-raises", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "LCM(Low(Int64), 1)"),
    RequiredBehaviorTestMarker("scalar-lcm-high-times-two-raises", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "LCM(High(Int64), 2)"),
    RequiredBehaviorTestMarker("scalar-angle-conversions", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('angle conversions'"),
    RequiredBehaviorTestMarker("scalar-boundaries", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('integer rounding boundaries'"),
    RequiredBehaviorTestMarker("scalar-rounding-subnormal-contracts", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('scalar rounding subnormal contracts'"),
    RequiredBehaviorTestMarker("scalar-floor-double-negative-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor Double negative min subnormal returns negative one"),
    RequiredBehaviorTestMarker("scalar-ceil-double-positive-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil Double positive min subnormal returns one"),
    RequiredBehaviorTestMarker("scalar-round-double-negative-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round Double negative min subnormal returns zero"),
    RequiredBehaviorTestMarker("scalar-trunc-single-negative-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc Single negative min subnormal returns zero"),
    RequiredBehaviorTestMarker("scalar-frac-double-negative-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac Double negative min subnormal preserves fractional sign"),
    RequiredBehaviorTestMarker("scalar-frac-single-min-subnormal", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac Single min subnormal preserves one-ulp fractional value"),
    RequiredBehaviorTestMarker("scalar-floor-double-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Double 2^63)"),
    RequiredBehaviorTestMarker("scalar-ceil-double-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Double 2^63)"),
    RequiredBehaviorTestMarker("scalar-round-double-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Double 2^63)"),
    RequiredBehaviorTestMarker("scalar-trunc-double-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Double 2^63)"),
    RequiredBehaviorTestMarker("scalar-frac-double-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Double 2^63)"),
    RequiredBehaviorTestMarker("scalar-round-double-near-int64-max-no-spurious-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round Double near Int64 max does not spuriously overflow"),
    RequiredBehaviorTestMarker("scalar-frac-double-near-int64-max-positive-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac Double near 2^63 returns positive zero"),
    RequiredBehaviorTestMarker("scalar-frac-double-int64-min-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac Double -2^63 keeps negative zero"),
    RequiredBehaviorTestMarker("scalar-frac-double-near-int64-min-negative-zero", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac Double near -2^63 keeps negative zero"),
    RequiredBehaviorTestMarker("scalar-floor-double-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Double below -2^63)"),
    RequiredBehaviorTestMarker("scalar-ceil-double-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Double below -2^63)"),
    RequiredBehaviorTestMarker("scalar-round-double-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Double below -2^63)"),
    RequiredBehaviorTestMarker("scalar-trunc-double-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Double below -2^63)"),
    RequiredBehaviorTestMarker("scalar-frac-double-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Double below -2^63)"),
    RequiredBehaviorTestMarker("scalar-floor-double-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(NaN)"),
    RequiredBehaviorTestMarker("scalar-floor-double-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(+Inf)"),
    RequiredBehaviorTestMarker("scalar-floor-double-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(-Inf)"),
    RequiredBehaviorTestMarker("scalar-ceil-double-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Double NaN)"),
    RequiredBehaviorTestMarker("scalar-ceil-double-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Double +Inf)"),
    RequiredBehaviorTestMarker("scalar-ceil-double-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Double -Inf)"),
    RequiredBehaviorTestMarker("scalar-round-double-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(NaN)"),
    RequiredBehaviorTestMarker("scalar-round-double-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(+Inf)"),
    RequiredBehaviorTestMarker("scalar-round-double-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Double -Inf)"),
    RequiredBehaviorTestMarker("scalar-trunc-double-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(NaN)"),
    RequiredBehaviorTestMarker("scalar-trunc-double-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(+Inf)"),
    RequiredBehaviorTestMarker("scalar-trunc-double-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Double -Inf)"),
    RequiredBehaviorTestMarker("scalar-frac-double-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(NaN)"),
    RequiredBehaviorTestMarker("scalar-frac-double-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(+Inf)"),
    RequiredBehaviorTestMarker("scalar-frac-double-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Double -Inf)"),
    RequiredBehaviorTestMarker("scalar-floor-single-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Single NaN)"),
    RequiredBehaviorTestMarker("scalar-floor-single-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Single +Inf)"),
    RequiredBehaviorTestMarker("scalar-floor-single-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Single -Inf)"),
    RequiredBehaviorTestMarker("scalar-floor-single-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Single 2^63)"),
    RequiredBehaviorTestMarker("scalar-ceil-single-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Single NaN)"),
    RequiredBehaviorTestMarker("scalar-ceil-single-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Single +Inf)"),
    RequiredBehaviorTestMarker("scalar-ceil-single-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Single -Inf)"),
    RequiredBehaviorTestMarker("scalar-ceil-single-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Single 2^63)"),
    RequiredBehaviorTestMarker("scalar-round-single-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Single NaN)"),
    RequiredBehaviorTestMarker("scalar-round-single-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Single +Inf)"),
    RequiredBehaviorTestMarker("scalar-round-single-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Single -Inf)"),
    RequiredBehaviorTestMarker("scalar-round-single-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Single 2^63)"),
    RequiredBehaviorTestMarker("scalar-trunc-single-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Single NaN)"),
    RequiredBehaviorTestMarker("scalar-trunc-single-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Single +Inf)"),
    RequiredBehaviorTestMarker("scalar-trunc-single-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Single -Inf)"),
    RequiredBehaviorTestMarker("scalar-trunc-single-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Single 2^63)"),
    RequiredBehaviorTestMarker("scalar-frac-single-nan-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Single NaN)"),
    RequiredBehaviorTestMarker("scalar-frac-single-positive-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Single +Inf)"),
    RequiredBehaviorTestMarker("scalar-frac-single-negative-infinity-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Single -Inf)"),
    RequiredBehaviorTestMarker("scalar-frac-single-int64-max-plus-one-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Single 2^63)"),
    RequiredBehaviorTestMarker("scalar-floor-single-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Floor(Single below -2^63)"),
    RequiredBehaviorTestMarker("scalar-ceil-single-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Ceil(Single below -2^63)"),
    RequiredBehaviorTestMarker("scalar-round-single-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Round(Single below -2^63)"),
    RequiredBehaviorTestMarker("scalar-trunc-single-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Trunc(Single below -2^63)"),
    RequiredBehaviorTestMarker("scalar-frac-single-below-int64-min-boundary-message", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "Frac(Single below -2^63)"),
    RequiredBehaviorTestMarker("scalar-owner-messages", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('owner-level boundary messages'"),
    RequiredBehaviorTestMarker("scalar-single-boundary-messages", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('single-precision boundary messages'"),
    RequiredBehaviorTestMarker("scalar-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('overflow helpers'"),
    RequiredBehaviorTestMarker("trig-basic", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('basic trig values'"),
    RequiredBehaviorTestMarker("trig-inverse-domain", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('inverse trig domain contracts'"),
    RequiredBehaviorTestMarker("trig-inverse-non-finite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('inverse trig non-finite contracts'"),
    RequiredBehaviorTestMarker("trig-inverse-domain-arcsin-low", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcSin below lower domain returns NaN"),
    RequiredBehaviorTestMarker("trig-inverse-domain-arccos-high", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcCos above upper domain returns NaN"),
    RequiredBehaviorTestMarker("trig-circular-non-finite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('circular trig non-finite contracts'"),
    RequiredBehaviorTestMarker("trig-circular-sin-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Sin(+Inf)=NaN"),
    RequiredBehaviorTestMarker("trig-circular-cos-single-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Cos(Single -Inf)=NaN"),
    RequiredBehaviorTestMarker("trig-circular-tan-nan", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Tan(NaN)=NaN"),
    RequiredBehaviorTestMarker("trig-circular-signed-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('circular trig signed zero contracts'"),
    RequiredBehaviorTestMarker("trig-circular-finite-precision", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('circular trig finite precision contracts'"),
    RequiredBehaviorTestMarker("trig-atan-special", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('ArcTan special contracts'"),
    RequiredBehaviorTestMarker("trig-atan2-special", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('ArcTan2 special cases'"),
    RequiredBehaviorTestMarker("trig-atan2-one-infinite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('ArcTan2 one-infinite contracts'"),
    RequiredBehaviorTestMarker("trig-atan2-signed-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('ArcTan2 signed zero contracts'"),
    RequiredBehaviorTestMarker("trig-atan2-double-positive-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2(+0,+0)=+0"),
    RequiredBehaviorTestMarker("trig-atan2-double-zero-negative-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2(+0,-Inf)=+PI"),
    RequiredBehaviorTestMarker("trig-atan2-single-positive-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2(Single +0,+0)=+0"),
    RequiredBehaviorTestMarker("trig-atan2-single-negative-zero-negative-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2(Single -0,-Inf)=-PI"),
    RequiredBehaviorTestMarker("trig-atan2-finite-extreme-ratio", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('ArcTan2 finite extreme ratio contracts'"),
    RequiredBehaviorTestMarker("trig-atan2-double-subnormal-x", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2 subnormal x huge positive finite ratio stays +PI/2"),
    RequiredBehaviorTestMarker("trig-atan2-double-subnormal-y-positive-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2 subnormal y tiny positive finite ratio returns +0"),
    RequiredBehaviorTestMarker("trig-atan2-double-subnormal-y-negative-pi", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2 subnormal y tiny negative ratio with negative x stays -PI"),
    RequiredBehaviorTestMarker("trig-atan2-single-subnormal-x", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2 Single subnormal x huge positive finite ratio stays +PI/2"),
    RequiredBehaviorTestMarker("trig-atan2-single-subnormal-y-negative-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2 Single subnormal y tiny negative finite ratio returns -0"),
    RequiredBehaviorTestMarker("trig-atan2-single-subnormal-y-positive-pi", "tests/nextpas.core.math/test_trig/test_trig.lpr", "ArcTan2 Single subnormal y tiny positive ratio with negative x stays +PI"),
    RequiredBehaviorTestMarker("trig-exp-log-sqrt", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('exp/log/sqrt contracts'"),
    RequiredBehaviorTestMarker("trig-exp-log-sqrt-finite-precision", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('exp log sqrt finite precision contracts'"),
    RequiredBehaviorTestMarker("trig-exp-sqrt-ieee", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('exp sqrt IEEE contracts'"),
    RequiredBehaviorTestMarker("trig-exp-negative-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Exp(-Inf)=+0"),
    RequiredBehaviorTestMarker("trig-exp-finite-overflow-underflow", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('Exp finite overflow underflow contracts'"),
    RequiredBehaviorTestMarker("trig-exp-threshold-double-inside-overflow", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Exp Double below overflow threshold stays finite"),
    RequiredBehaviorTestMarker("trig-exp-threshold-double-underflow-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Exp Double above underflow threshold stays positive finite"),
    RequiredBehaviorTestMarker("trig-exp-threshold-single-inside-overflow", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Exp Single below overflow threshold stays finite"),
    RequiredBehaviorTestMarker("trig-exp-threshold-single-underflow-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Exp Single above underflow threshold stays positive finite"),
    RequiredBehaviorTestMarker("trig-sqrt-finite-extremes-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('Sqrt finite extremes subnormal contracts'"),
    RequiredBehaviorTestMarker("trig-sqrt-negative-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Sqrt(-0)=-0"),
    RequiredBehaviorTestMarker("trig-log-domain-signed-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('log domain signed zero contracts'"),
    RequiredBehaviorTestMarker("trig-log-base-identities", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('log base identity contracts'"),
    RequiredBehaviorTestMarker("trig-log-domain-ln-negative-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Ln(-0)=-Inf"),
    RequiredBehaviorTestMarker("trig-log-identity-ln-one", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Ln(1)=+0"),
    RequiredBehaviorTestMarker("trig-log-identity-log2-one", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log2(1)=+0"),
    RequiredBehaviorTestMarker("trig-log-identity-log10-one", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log10(1)=+0"),
    RequiredBehaviorTestMarker("trig-log-identity-log2-base", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log2(2)=1 exact bits"),
    RequiredBehaviorTestMarker("trig-log-identity-log10-base", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log10(10)=1 exact bits"),
    RequiredBehaviorTestMarker("trig-log-domain-log2-negative-finite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log2(-1.0)"),
    RequiredBehaviorTestMarker("trig-log-domain-log10-single-negative-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log10(SingleNegativeZero)"),
    RequiredBehaviorTestMarker("trig-log-positive-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('log positive subnormal contracts'"),
    RequiredBehaviorTestMarker("trig-log-ln-double-min-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Ln Double min positive subnormal stays finite negative"),
    RequiredBehaviorTestMarker("trig-log-log2-double-min-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log2 Double min positive subnormal returns -1074"),
    RequiredBehaviorTestMarker("trig-log-log10-double-min-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log10 Double min positive subnormal stays finite negative"),
    RequiredBehaviorTestMarker("trig-log-ln-single-min-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Ln Single min positive subnormal stays finite negative"),
    RequiredBehaviorTestMarker("trig-log-log2-single-min-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log2 Single min positive subnormal returns -149"),
    RequiredBehaviorTestMarker("trig-log-log10-single-min-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Log10 Single min positive subnormal stays finite negative"),
    RequiredBehaviorTestMarker("trig-power", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('power edge contracts'"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-max-finite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double max finite exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double min subnormal exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-negative-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double negative min subnormal exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-positive-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double positive zero exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-negative-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double negative zero exponent one preserves negative zero"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-nan-base", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double NaN base exponent one returns NaN"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-positive-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double positive infinity exponent one preserves infinity"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-double-negative-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Double negative infinity exponent one preserves infinity"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-max-finite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single max finite exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single min subnormal exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-negative-subnormal", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single negative min subnormal exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-positive-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single positive zero exponent one preserves input"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-negative-zero", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single negative zero exponent one preserves negative zero"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-nan-base", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single NaN base exponent one returns NaN"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-positive-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single positive infinity exponent one preserves infinity"),
    RequiredBehaviorTestMarker("trig-power-exponent-one-single-negative-infinity", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power Single negative infinity exponent one preserves infinity"),
    RequiredBehaviorTestMarker("trig-power-negative-non-integer", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('power negative finite base non-integer contracts'"),
    RequiredBehaviorTestMarker("trig-power-non-finite", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('power non-finite contracts'"),
    RequiredBehaviorTestMarker("trig-power-nan-base", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power NaN base nonzero exponent returns NaN"),
    RequiredBehaviorTestMarker("trig-power-positive-one-nan-exponent", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power +1 NaN exponent returns 1"),
    RequiredBehaviorTestMarker("trig-power-unit-infinite-exponent", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power -1 +Inf exponent returns 1"),
    RequiredBehaviorTestMarker("trig-power-infinite-base-odd-negative", "tests/nextpas.core.math/test_trig/test_trig.lpr", "Power -Inf odd negative exponent returns -0"),
    RequiredBehaviorTestMarker("trig-power-finite-identity-precision", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('Power finite identity precision contracts'"),
    RequiredBehaviorTestMarker("trig-power-finite-overflow-underflow-sign", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('Power finite overflow underflow sign contracts'"),
    RequiredBehaviorTestMarker("facade-angle-conversions", "tests/nextpas.core.math/test_facade/test_facade.lpr", "facade re-exports RadToDeg"),
    RequiredBehaviorTestMarker("vec-2f", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec2f contracts'"),
    RequiredBehaviorTestMarker("vec-2f-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec2f huge finite length + normalize'"),
    RequiredBehaviorTestMarker("vec-3f", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec3f contracts'"),
    RequiredBehaviorTestMarker("vec-3f-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec3f huge finite length + normalize'"),
    RequiredBehaviorTestMarker("vec-4f", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec4f contracts'"),
    RequiredBehaviorTestMarker("vec-4f-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec4f huge finite length + normalize'"),
    RequiredBehaviorTestMarker("vec-double", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('double precision vector contracts'"),
    RequiredBehaviorTestMarker("vec-3d-scalar-divide", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec3d scalar divide"),
    RequiredBehaviorTestMarker("vec-4d-scalar-divide", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d scalar divide"),
    RequiredBehaviorTestMarker("vec-2d-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec2d huge finite length + normalize'"),
    RequiredBehaviorTestMarker("vec-3d-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec3d huge finite length + normalize'"),
    RequiredBehaviorTestMarker("vec-4d-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec4d huge finite length + normalize'"),
    RequiredBehaviorTestMarker("vec-lengthsqr-huge-finite-overflow", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector huge finite LengthSqr overflow contract'"),
    RequiredBehaviorTestMarker("vec-lengthsqr-below-overflow", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d below overflow LengthSqr remains finite"),
    RequiredBehaviorTestMarker("vec-lengthsqr-exact-boundary", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d exact finite LengthSqr boundary stays finite"),
    RequiredBehaviorTestMarker("vec-lengthsqr-first-overflow-boundary", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d first overflowing LengthSqr boundary saturates to +Inf"),
    RequiredBehaviorTestMarker("vec-dot-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector huge finite Dot contract'"),
    RequiredBehaviorTestMarker("vec-cross-huge-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector huge finite Cross cancellation contract'"),
    RequiredBehaviorTestMarker("vec-cross-huge-finite-cancellation-axis-coverage", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec3d huge finite Cross cancellation preserves finite Y-axis"),
    RequiredBehaviorTestMarker("vec-cross-out-of-range-signed-inf", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector huge finite Cross out-of-range signed infinity contract'"),
    RequiredBehaviorTestMarker("vec-cross-out-of-range-signed-inf-axis-coverage", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec3d huge finite Cross true negative out-of-range Z returns -Inf"),
    RequiredBehaviorTestMarker("vec-data-write-through", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector Data aliases write through'"),
    RequiredBehaviorTestMarker("vec-measure-non-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector measure non-finite contracts'"),
    RequiredBehaviorTestMarker("vec-measure-lengthsqr-inf", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d LengthSqr infinite component returns +Inf"),
    RequiredBehaviorTestMarker("vec-measure-dot-zero-times-inf", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec2f Dot zero times infinity returns NaN"),
    RequiredBehaviorTestMarker("vec-measure-cross-raw-non-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec3d Cross raw non-finite fallback returns NaN component"),
    RequiredBehaviorTestMarker("vec-raw-arithmetic-special-values", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector raw arithmetic special-value contracts'"),
    RequiredBehaviorTestMarker("vec-signed-zero", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector signed-zero contracts'"),
    RequiredBehaviorTestMarker("vec-signed-zero-normalize", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec2f negative-zero Normalize returns positive zero"),
    RequiredBehaviorTestMarker("vec-normalize-signed-zero-vec4d", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d negative-zero Normalize returns positive zero W"),
    RequiredBehaviorTestMarker("vec-signed-zero-dot", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d exact zero Dot returns +0"),
    RequiredBehaviorTestMarker("vec-data-signed-zero-bits", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector Data aliases preserve signed-zero bits'"),
    RequiredBehaviorTestMarker("vec-lerp-scalar-parity", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector Lerp scalar parity contracts'"),
    RequiredBehaviorTestMarker("vec-lerp-endpoint-t0", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec2f Lerp scalar parity t=0"),
    RequiredBehaviorTestMarker("vec-lerp-endpoint-t1", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d Lerp scalar parity t=1"),
    RequiredBehaviorTestMarker("vec-lerp-huge-finite-parity", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d Lerp huge finite scalar parity"),
    RequiredBehaviorTestMarker("vec-normalize-max-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector max finite normalize contract'"),
    RequiredBehaviorTestMarker("vec-normalize-raw-non-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('raw vector normalize non-finite inputs fail fast'"),
    RequiredBehaviorTestMarker("vec-division-invalid-divisors", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector division invalid divisors fail fast'"),
    RequiredBehaviorTestMarker("vec-mixed-invalid-divisor-priority", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector mixed invalid divisor priority contracts'"),
    RequiredBehaviorTestMarker("vec-mixed-invalid-scalar-divisor-priority", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec2f scalar divide NaN dividend by zero divisor"),
    RequiredBehaviorTestMarker("vec-mixed-invalid-component-divisor-priority", "tests/nextpas.core.math/test_vec/test_vec.lpr", "TVec4d component divide finite dividend by zero and infinity divisors"),
    RequiredBehaviorTestMarker("vec-equals-non-finite", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('vector Equals non-finite comparison contracts'"),
    RequiredBehaviorTestMarker("facade-vector-lerp-scalar-parity", "tests/nextpas.core.math/test_facade/test_facade.lpr", "T.Run('facade vector Lerp scalar parity contracts'"),
    RequiredBehaviorTestMarker("mat-3f", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('TMat3f contracts'"),
    RequiredBehaviorTestMarker("mat-4f", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('TMat4f contracts'"),
    RequiredBehaviorTestMarker("mat-double", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('double precision matrix contracts'"),
    RequiredBehaviorTestMarker("mat-inverse-fail-close-single", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('single precision inverse fail-close contracts'"),
    RequiredBehaviorTestMarker("mat-inverse-fail-close-double", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('double precision inverse fail-close contracts'"),
    RequiredBehaviorTestMarker("mat-inverse-overwrite-single", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('single precision inverse overwrites out parameter'"),
    RequiredBehaviorTestMarker("mat-inverse-overwrite-double", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('double precision inverse overwrites out parameter'"),
    RequiredBehaviorTestMarker("mat-indexed-alias-write-through", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('matrix indexed aliases write through'"),
    RequiredBehaviorTestMarker("mat-indexed-alias-signed-zero-bits", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('matrix indexed aliases preserve signed-zero bits'"),
    RequiredBehaviorTestMarker("mat-indexed-alias-data-negative-zero", "tests/nextpas.core.math/test_mat/test_mat.lpr", "TMat4d Data[3,1] preserves negative-zero bits through Items"),
    RequiredBehaviorTestMarker("mat-indexed-alias-row-column-negative-zero", "tests/nextpas.core.math/test_mat/test_mat.lpr", "TMat3f row setter preserves negative-zero bits through Columns"),
    RequiredBehaviorTestMarker("mat-equals-non-finite", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('matrix Equals non-finite comparison contracts'"),
    RequiredBehaviorTestMarker("quat-f", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('TQuatf contracts'"),
    RequiredBehaviorTestMarker("quat-d", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('TQuatd contracts'"),
    RequiredBehaviorTestMarker("quat-data-alias-write-through", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('quaternion Data aliases write through'"),
    RequiredBehaviorTestMarker("quat-data-alias-signed-zero-bits", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('quaternion Data aliases preserve signed-zero bits'"),
    RequiredBehaviorTestMarker("quat-data-alias-f-negative-zero", "tests/nextpas.core.math/test_quat/test_quat.lpr", "TQuatf Data[0] preserves negative-zero bits"),
    RequiredBehaviorTestMarker("quat-data-alias-d-negative-zero", "tests/nextpas.core.math/test_quat/test_quat.lpr", "TQuatd W preserves negative-zero bits in Data[3]"),
    RequiredBehaviorTestMarker("quat-equals-non-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('quaternion Equals non-finite comparison contracts'"),
    RequiredBehaviorTestMarker("quat-axis-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('FromAxisAngle rejects non-finite inputs'"),
    RequiredBehaviorTestMarker("quat-axis-huge-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('FromAxisAngle normalizes huge finite axis'"),
    RequiredBehaviorTestMarker("quat-huge-finite-normalize", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('huge finite normalize'"),
    RequiredBehaviorTestMarker("quat-max-finite-normalize", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('max finite normalize'"),
    RequiredBehaviorTestMarker("quat-interpolation-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation rejects non-finite t'"),
    RequiredBehaviorTestMarker("quat-raw-non-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('raw quaternion non-finite inputs fail fast'"),
    RequiredBehaviorTestMarker("quat-rotate-vector-non-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Rotate rejects non-finite vector inputs'"),
    RequiredBehaviorTestMarker("quat-interpolation-extrapolation", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation allows finite extrapolation'"),
    RequiredBehaviorTestMarker("quat-interpolation-endpoints", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation endpoint contracts'"),
    RequiredBehaviorTestMarker("quat-interpolation-shortest-start", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation follows shortest path for opposite-sign start'"),
    RequiredBehaviorTestMarker("quat-interpolation-shortest-end", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation follows shortest path for opposite-sign end'"),
    RequiredBehaviorTestMarker("quat-interpolation-equivalent", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation stays stable for equivalent endpoints'"),
    RequiredBehaviorTestMarker("quat-interpolation-near-identical", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation stays stable for near-identical endpoints'"),
    RequiredBehaviorTestMarker("quat-axis-angle-opposite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle canonicalizes opposite-sign rotations'"),
    RequiredBehaviorTestMarker("quat-axis-angle-multiturn", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle canonicalizes multi-turn inputs'"),
    RequiredBehaviorTestMarker("quat-axis-angle-half-turns", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle canonicalizes FromAxisAngle half-turns'"),
    RequiredBehaviorTestMarker("quat-axis-angle-overwrite-out", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle overwrites out parameters'"),
    RequiredBehaviorTestMarker("quat-multiply-order", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Quaternion multiplication is non-commutative and right-first'"),
    RequiredBehaviorTestMarker("transform-projection", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('projection builders'"),
    RequiredBehaviorTestMarker("transform-ortho-reversed", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('Ortho allows reversed bounds'"),
    RequiredBehaviorTestMarker("transform-model-view", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('model and view builders'"),
    RequiredBehaviorTestMarker("transform-lookat-up", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('LookAt ignores up magnitude'"),
    RequiredBehaviorTestMarker("transform-lookat-roll", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('LookAt up direction controls roll'"),
    RequiredBehaviorTestMarker("transform-camera-double", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('camera2d and double builders'"),
    RequiredBehaviorTestMarker("transform-camera-zoom", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('Camera2D zoom scales view'"),
    RequiredBehaviorTestMarker("transform-double-parity", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('direct double builder parity'"),
    RequiredBehaviorTestMarker("transform-finite-guards", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('non-finite inputs fail fast'"),
    RequiredBehaviorTestMarker("transform-geometry-guards", "tests/nextpas.core.math/test_transform/test_transform.lpr", "T.Run('geometry guards report public contract messages'"),
    RequiredBehaviorTestMarker("easing-polynomial-expo", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('polynomial and expo easing'"),
    RequiredBehaviorTestMarker("easing-elastic-back-bounce", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('elastic back and bounce easing'"),
    RequiredBehaviorTestMarker("easing-out-bounce-piecewise", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('EaseOutBounce piecewise branches'"),
    RequiredBehaviorTestMarker("easing-out-of-range", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('finite out-of-range inputs extrapolate'"),
    RequiredBehaviorTestMarker("easing-non-finite", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('non-finite inputs fail fast'"),
    RequiredBehaviorTestMarker("random-seed", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('seed determinism'"),
    RequiredBehaviorTestMarker("random-zero-seed", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('zero seed uses deterministic default'"),
    RequiredBehaviorTestMarker("random-range", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('range boundaries'"),
    RequiredBehaviorTestMarker("random-state-forced-boundaries", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('state-forced half-open boundaries'"),
    RequiredBehaviorTestMarker("random-unbiased-integer-range", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('integer ranges reject modulo-bias tail states'"),
    RequiredBehaviorTestMarker("random-large-float", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('large finite float range stays finite and half-open'"),
    RequiredBehaviorTestMarker("random-large-finite-forced-max-float-range", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('large finite forced max float range stays finite and half-open'"),
    RequiredBehaviorTestMarker("random-weight-scale", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('WeightedChoice large finite weights stay scale-invariant'"),
    RequiredBehaviorTestMarker("random-weight-zero", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('WeightedChoice rejects all-zero weights'"),
    RequiredBehaviorTestMarker("random-weight-zero-pick", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('WeightedChoice zero-pick skips zero-weight prefixes'"),
    RequiredBehaviorTestMarker("random-weight-tail", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('WeightedChoice max pick keeps tail weight reachable'"),
    RequiredBehaviorTestMarker("random-invalid-ranges", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('invalid ranges fail fast'"),
    RequiredBehaviorTestMarker("random-roll-overflow", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('RollMultiple rejects overflowing total'"),
    RequiredBehaviorTestMarker("random-probability-dice", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('probability dice weighted choice and shuffle'"),
    RequiredBehaviorTestMarker("random-gaussian-circle", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('gaussian and circle vectors'"),
    RequiredBehaviorTestMarker("random-gaussian-zero-state", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('Gaussian zero-state clamp stays finite'"),
    RequiredBehaviorTestMarker("random-non-finite", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('non-finite parameter validation'"),
    RequiredBehaviorTestMarker("random-bool-non-finite", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('NextBool rejects non-finite probability'"),
    RequiredBehaviorTestMarker("noise-repeatability", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('noise repeatability'"),
    RequiredBehaviorTestMarker("noise-zero-seed", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('zero seed uses deterministic default'"),
    RequiredBehaviorTestMarker("noise-reference", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('noise reference vectors'"),
    RequiredBehaviorTestMarker("noise-invalid", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('noise invalid inputs'"),
    RequiredBehaviorTestMarker("noise-large-periodic", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('large periodic coordinates stay stable'"),
    RequiredBehaviorTestMarker("noise-negative-fractional", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('negative fractional coordinates wrap periodically'"),
    RequiredBehaviorTestMarker("noise-huge-lattice", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('huge finite lattice coordinates stay stable'"),
    RequiredBehaviorTestMarker("noise-fbm-coordinate", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('FBM rejects non-finite octave coordinates'"),
    RequiredBehaviorTestMarker("noise-fbm-amplitude", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('FBM rejects non-finite octave amplitude'"),
    RequiredBehaviorTestMarker("noise-fbm-accumulated", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('FBM rejects non-finite accumulated result'"),
    RequiredBehaviorTestMarker("noise-precision-ceiling", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('precision ceiling follows stored Double value'"),
    RequiredBehaviorTestMarker("impl-simd-vec4f", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('vec4f simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-vec3f", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('vec3f simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-mat4f", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('mat4f simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-quatf", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('quatf simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-runtime-parity", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('simd helpers match public math semantics'"),
    RequiredBehaviorTestMarker("impl-simd-stable-edge-parity", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('simd dot length stable edge parity'"),
    RequiredBehaviorTestMarker("impl-simd-vec4f-length-huge-finite", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec4fLength huge finite stable public parity"),
    RequiredBehaviorTestMarker("impl-simd-vec4f-dot-cancelling-huge", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec4fDot cancelling huge finite stable public parity"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-dot-cancelling-huge", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fDot cancelling huge finite stable public parity"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-cancelling-huge", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross cancelling huge finite stable public parity"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity-positive-x", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity positive X"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity-negative-x", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity negative X"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity-positive-y", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity positive Y"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity-negative-y", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity negative Y"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity-positive-z", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity positive Z"),
    RequiredBehaviorTestMarker("impl-simd-vec3f-cross-signed-infinity-negative-z", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdVec3fCross signed infinity public parity negative Z"),
    RequiredBehaviorTestMarker("impl-simd-vec4f-lane-ieee-parity", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('simd vec4f lane IEEE parity'"),
    RequiredBehaviorTestMarker("impl-simd-vec4f-reduction-ieee-parity", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('simd vec4f reduction IEEE parity'"),
    RequiredBehaviorTestMarker("impl-simd-mat4f-mul-vec4f-ieee-parity", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('simd mat4f mul vec4f IEEE parity'"),
    RequiredBehaviorTestMarker("impl-simd-quatf-rotate-nan-vector", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdQuatfRotate NaN vector public error parity"),
    RequiredBehaviorTestMarker("impl-simd-quatf-rotate-invalid-vector", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdQuatfRotate infinite vector public error parity"),
    RequiredBehaviorTestMarker("impl-simd-quatf-rotate-invalid-priority", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "SimdQuatfRotate invalid quaternion priority public error parity"),
)


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    text: str


@dataclass(frozen=True)
class PublicRoutineSignature:
    unit_name: str
    name: str
    routine_kind: str
    params: tuple[tuple[str, str], ...]
    result_type: str
    line: int

    @property
    def key(self) -> tuple[str, str, tuple[tuple[str, str], ...], str]:
        return (
            self.name.lower(),
            self.routine_kind.lower(),
            self.params,
            self.result_type,
        )


@dataclass(frozen=True)
class PublicTypeAlias:
    unit_name: str
    name: str
    target: str
    line: int


@dataclass(frozen=True)
class PublicConstant:
    unit_name: str
    name: str
    type_name: str
    line: int


@dataclass(frozen=True)
class Report:
    root: str
    scanned_files: int
    findings: list[Finding]

    @property
    def ok(self) -> bool:
        return not self.findings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check nextpas.core.math final public surface boundaries."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root to scan.",
    )
    parser.add_argument(
        "--json-file",
        default="",
        help="Optional path to write a machine-readable report.",
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a one-line summary for runner logs.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print detailed findings even with --summary-line.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run internal regression checks before scanning the workspace.",
    )
    return parser.parse_args()


def mask_char(ch: str) -> str:
    return "\n" if ch in {"\n", "\r"} else " "


def strip_hash_makefile_comments(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines(keepends=True):
        hash_index = line.find("#")
        if hash_index < 0:
            lines.append(line)
            continue

        suffix = line[hash_index:]
        newline = ""
        if suffix.endswith("\n"):
            newline = "\n"
            suffix = suffix[:-1]
        if suffix.endswith("\r"):
            newline = "\r" + newline
            suffix = suffix[:-1]
        lines.append(line[:hash_index] + (" " * len(suffix)) + newline)
    return "".join(lines)


def strip_pascal_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    in_line_comment = False
    in_brace_comment = False
    in_paren_star_comment = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_string:
            out.append(ch)
            if ch == "'" and nxt == "'":
                out.append(nxt)
                i += 2
                continue
            if ch == "'":
                in_string = False
            i += 1
            continue

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append("\n")
            else:
                out.append(" ")
            i += 1
            continue

        if in_brace_comment:
            if ch == "}":
                in_brace_comment = False
            out.append(mask_char(ch))
            i += 1
            continue

        if in_paren_star_comment:
            if ch == "*" and nxt == ")":
                in_paren_star_comment = False
                out.extend("  ")
                i += 2
                continue
            out.append(mask_char(ch))
            i += 1
            continue

        if ch == "'":
            in_string = True
            out.append(ch)
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            out.extend("  ")
            i += 2
            continue

        if ch == "{":
            in_brace_comment = True
            out.append(" ")
            i += 1
            continue

        if ch == "(" and nxt == "*":
            in_paren_star_comment = True
            out.extend("  ")
            i += 2
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def strip_pascal_comments_and_strings(text: str) -> str:
    text = strip_pascal_comments(text)
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_string:
            out.append(mask_char(ch))
            if ch == "'" and nxt == "'":
                out.append(" ")
                i += 2
                continue
            if ch == "'":
                in_string = False
            i += 1
            continue

        if ch == "'":
            in_string = True
            out.append(" ")
            i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def pascal_compiler_directive_text(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    in_line_comment = False
    in_brace_comment = False
    in_paren_star_comment = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_string:
            out.append(mask_char(ch))
            if ch == "'" and nxt == "'":
                out.append(" ")
                i += 2
                continue
            if ch == "'":
                in_string = False
            i += 1
            continue

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append("\n")
            else:
                out.append(" ")
            i += 1
            continue

        if in_brace_comment:
            if ch == "}":
                in_brace_comment = False
            out.append(mask_char(ch))
            i += 1
            continue

        if in_paren_star_comment:
            if ch == "*" and nxt == ")":
                in_paren_star_comment = False
                out.extend("  ")
                i += 2
                continue
            out.append(mask_char(ch))
            i += 1
            continue

        if ch == "'":
            in_string = True
            out.append(" ")
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            out.extend("  ")
            i += 2
            continue

        if ch == "{" and nxt != "$":
            in_brace_comment = True
            out.append(" ")
            i += 1
            continue

        if ch == "(" and nxt == "*" and i + 2 < n and text[i + 2] != "$":
            in_paren_star_comment = True
            out.extend("  ")
            i += 2
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def original_line(text: str, line_no: int) -> str:
    lines = text.splitlines()
    if 1 <= line_no <= len(lines):
        return lines[line_no - 1].strip()
    return ""


def line_no_at(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def discover_files(root: Path, globs: tuple[str, ...]) -> list[Path]:
    files: set[Path] = set()
    for pattern in globs:
        files.update(path for path in root.glob(pattern) if path.is_file())
    return sorted(files)


def discover_public_docs(root: Path) -> list[Path]:
    return [root / rel for rel in PUBLIC_DOC_PATHS if (root / rel).is_file()]


def add_finding(
    findings: list[Finding],
    rule: str,
    root: Path,
    path: Path,
    line: int,
    text: str,
) -> None:
    findings.append(
        Finding(
            rule=rule,
            path=relative(path, root),
            line=line,
            text=text.strip(),
        )
    )


def scan_math_ffi_uses(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = strip_pascal_comments_and_strings(text)
    for match in USES_MATH_FFI_RE.finditer(code):
        body = match.group("body")
        needle = re.search(r"\bnextpas\.core\.math\.ffi\b", body, re.IGNORECASE)
        if needle is None:
            continue
        line = line_no_at(code, match.start("body") + needle.start())
        add_finding(
            findings,
            "no-math-ffi-consumers",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_external_m(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = strip_pascal_comments(text)
    for match in EXTERNAL_M_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-naked-external-m",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_native_math_linking(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    directive_text = (
        pascal_compiler_directive_text(text)
        if path.suffix.lower() in {".inc", ".lpr", ".pas"}
        else text
    )
    for match in LINKLIB_M_RE.finditer(directive_text):
        line = line_no_at(directive_text, match.start())
        add_finding(
            findings,
            "no-native-math-linklib",
            root,
            path,
            line,
            original_line(text, line),
        )

    for index, line in enumerate(text.splitlines(), start=1):
        code_line = line.split("#", 1)[0] if path.name == "Makefile" else line
        if NATIVE_MATH_LINK_FLAG_RE.search(code_line):
            add_finding(
                findings,
                "no-native-math-link-flag",
                root,
                path,
                index,
                line,
            )
    return findings


def interface_text(text: str) -> str:
    code = strip_pascal_comments_and_strings(text)
    match = IMPLEMENTATION_RE.search(code)
    if match is None:
        return code
    return code[: match.start()]


def interface_body_text_with_line_offset(text: str) -> tuple[str, int]:
    code = interface_text(text)
    match = INTERFACE_RE.search(code)
    if match is None:
        return code, 0
    return code[match.end() :], line_no_at(code, match.end()) - 1


def scan_legacy_public_names(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = interface_text(text)
    for match in LEGACY_PUBLIC_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-legacy-public-vector-api",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_legacy_production_names(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = strip_pascal_comments_and_strings(text)
    for match in LEGACY_PUBLIC_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-legacy-production-math-symbol",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_legacy_public_doc_symbols(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for pattern in (
        LEGACY_PUBLIC_DOC_SYMBOL_RE,
        LEGACY_PUBLIC_DOC_USES_VECTORS_RE,
        LEGACY_PUBLIC_DOC_VECTORS_PATH_RE,
    ):
        for match in pattern.finditer(text):
            line = line_no_at(text, match.start())
            add_finding(
                findings,
                "no-legacy-public-doc-vector-api",
                root,
                path,
                line,
                original_line(text, line),
            )
    return findings


def scan_allowed_math_units(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = strip_pascal_comments_and_strings(text)
    match = UNIT_NAME_RE.search(code)
    if match is None:
        return findings

    unit_name = match.group("name").lower()
    if unit_name not in ALLOWED_MATH_UNITS:
        line = line_no_at(code, match.start("name"))
        add_finding(
            findings,
            "no-unplanned-public-math-unit",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_private_simd(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = strip_pascal_comments_and_strings(text)
    for match in PRIVATE_SIMD_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-private-simd-dependency",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_math_impl_simd_facade_only_uses(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / "src/nextpas.core.math.impl.simd.pas"
    if not path.is_file():
        return findings

    text = path.read_text(encoding="utf-8", errors="replace")
    impl_text, line_offset = implementation_text_with_line_offset(text)
    uses_units = active_uses_units_with_lines(impl_text, line_offset)
    simd_uses = [(unit, line) for unit, line in uses_units if unit.startswith("nextpas.core.simd")]

    simd_unit_names = {unit for unit, _line in simd_uses}
    if simd_unit_names == {"nextpas.core.simd"}:
        return findings

    if "nextpas.core.simd" not in simd_unit_names:
        add_finding(
            findings,
            "math-impl-simd-missing-public-simd-facade-use",
            root,
            path,
            line_offset + 1,
            "implementation uses must import nextpas.core.simd",
        )

    for unit, line in simd_uses:
        if unit == "nextpas.core.simd":
            continue
        add_finding(
            findings,
            "math-impl-simd-non-facade-simd-use:" + unit,
            root,
            path,
            line,
            unit,
        )
    return findings


def scan_math_impl_simd_public_seam(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != MATH_IMPL_SIMD_PATH:
        return findings

    interface_body, line_offset = interface_body_text_with_line_offset(text)
    for unit, line in active_uses_units_with_lines(interface_body, line_offset):
        if unit.startswith("nextpas.core.simd"):
            add_finding(
                findings,
                "math-impl-simd-public-simd-interface-use:" + unit,
                root,
                path,
                line,
                original_line(text, line),
            )
            continue
        if unit not in MATH_IMPL_SIMD_ALLOWED_INTERFACE_USES:
            add_finding(
                findings,
                "math-impl-simd-unplanned-public-interface-use:" + unit,
                root,
                path,
                line,
                original_line(text, line),
            )

    for match in MATH_IMPL_SIMD_PUBLIC_BACKEND_TYPE_RE.finditer(interface_body):
        line = line_offset + line_no_at(interface_body, match.start())
        add_finding(
            findings,
            "math-impl-simd-public-simd-type-leak",
            root,
            path,
            line,
            original_line(text, line),
        )

    for routine in extract_public_routines(text):
        if routine.key not in MATH_IMPL_SIMD_ALLOWED_PUBLIC_ROUTINES:
            add_finding(
                findings,
                "math-impl-simd-unplanned-public-routine:" + routine.name,
                root,
                path,
                routine.line,
                original_line(text, routine.line),
            )

    for alias in extract_public_type_aliases(text):
        add_finding(
            findings,
            "math-impl-simd-unplanned-public-type:" + alias.name,
            root,
            path,
            alias.line,
            original_line(text, alias.line),
        )

    return findings


def scan_public_impl_consumers(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    rel = relative(path, root)
    if rel.startswith(INTERNAL_IMPL_TEST_PREFIXES):
        return findings

    code = strip_pascal_comments_and_strings(text)
    for match in PUBLIC_IMPL_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-public-impl-consumer",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_public_math_source_simd_wiring(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) not in PUBLIC_MATH_SOURCE_PATHS:
        return findings

    code = strip_pascal_comments_and_strings(text)
    for uses_match in USES_MATH_FFI_RE.finditer(code):
        body = uses_match.group("body")
        for match in PUBLIC_MATH_SOURCE_SIMD_RE.finditer(body):
            line = line_no_at(code, uses_match.start("body") + match.start())
            add_finding(
                findings,
                "no-public-math-unit-impl-simd-wiring",
                root,
                path,
                line,
                original_line(text, line),
            )
    return findings


def scan_compiler_refs(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for index, line in enumerate(text.splitlines(), start=1):
        if COMPILER_REF_RE.search(line):
            add_finding(
                findings,
                "no-compiler-entrypoint-in-math-tests",
                root,
                path,
                index,
                line,
            )
    return findings


def scan_forbidden_trig_scalar_names(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != "src/nextpas.core.math.trig.pas":
        return findings

    code = interface_text(text)
    for match in TRIG_FORBIDDEN_SCALAR_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-scalar-api-in-math-trig",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_forbidden_simd_mathutil_bare_names(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != SIMD_MATHUTIL_PATH:
        return findings

    code = interface_text(text)
    for match in PUBLIC_FUNCTION_RE.finditer(code):
        name = match.group(1)
        if name.lower().startswith("simd"):
            continue
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-bare-public-math-name-in-simd-mathutil",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def scan_forbidden_fpc_math_unit(
    root: Path,
    path: Path,
    text: str,
    expected_rel: str,
    rule: str,
) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != expected_rel:
        return findings

    code = strip_pascal_comments_and_strings(text)
    for match in USES_MATH_FFI_RE.finditer(code):
        for unit in match.group("body").split(","):
            if re.sub(r"\s+", "", unit).lower() != "math":
                continue
            line = line_no_at(code, match.start("body") + match.group("body").find(unit))
            add_finding(
                findings,
                rule,
                root,
                path,
                line,
                original_line(text, line),
            )
    return findings


def scan_forbidden_fpc_math_unit_in_easing(root: Path, path: Path, text: str) -> list[Finding]:
    return scan_forbidden_fpc_math_unit(
        root,
        path,
        text,
        "src/nextpas.core.math.easing.pas",
        "no-fpc-math-unit-in-easing",
    )


def scan_forbidden_fpc_math_unit_in_trig(root: Path, path: Path, text: str) -> list[Finding]:
    return scan_forbidden_fpc_math_unit(
        root,
        path,
        text,
        "src/nextpas.core.math.trig.pas",
        "no-fpc-math-unit-in-trig",
    )


def extract_pascal_function_body(text: str, function_name: str) -> tuple[int, str] | None:
    pattern = re.compile(
        r"function\s+"
        + re.escape(function_name)
        + r"\s*\([^;]*?\)\s*:\s*Double\s*;"
        + r"(?:\s*(?:overload|inline)\s*;)*\s*begin\b",
        re.IGNORECASE | re.DOTALL,
    )
    match = pattern.search(text)
    if match is None:
        return None

    next_function = re.search(r"\nfunction\s+", text[match.end() :], re.IGNORECASE)
    end = len(text) if next_function is None else match.end() + next_function.start()
    return line_no_at(text, match.start()), text[match.end() : end]


def scan_trig_log_exact_identity_source_contract(
    root: Path, path: Path, text: str
) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != MATH_TRIG_PATH:
        return findings

    code = strip_pascal_comments_and_strings(text)
    for function_name, base_value in (("Log2", "2.0"), ("Log10", "10.0")):
        body_info = extract_pascal_function_body(code, function_name)
        if body_info is None:
            add_finding(
                findings,
                "missing-required-trig-log-exact-identity-source-contract:"
                + function_name.lower(),
                root,
                path,
                1,
                function_name + "(Double) body not found",
            )
            continue

        body_line, body = body_info
        fallback_index = body.lower().find("ln(ax) /")
        if fallback_index < 0:
            add_finding(
                findings,
                "missing-required-trig-log-exact-identity-source-contract:"
                + function_name.lower()
                + "-fallback",
                root,
                path,
                body_line,
                function_name + "(Double) finite fallback Ln(AX) / ... not found",
            )
            continue

        prefix = body[:fallback_index]
        required_markers = (
            (
                "one",
                re.compile(
                    r"AX\s*=\s*1\.0\s+then\s+Exit\s*\(\s*0\.0\s*\)",
                    re.IGNORECASE,
                ),
                function_name + "(Double) must return exact +0 for AX = 1.0 before Ln fallback",
            ),
            (
                "base",
                re.compile(
                    r"AX\s*=\s*"
                    + re.escape(base_value)
                    + r"\s+then\s+Exit\s*\(\s*1\.0\s*\)",
                    re.IGNORECASE,
                ),
                function_name
                + "(Double) must return exact 1.0 for AX = "
                + base_value
                + " before Ln fallback",
            ),
        )
        for rule_suffix, marker, message in required_markers:
            if marker.search(prefix):
                continue
            add_finding(
                findings,
                "missing-required-trig-log-exact-identity-source-contract:"
                + function_name.lower()
                + "-"
                + rule_suffix,
                root,
                path,
                body_line + line_no_at(body, fallback_index) - 1,
                message,
            )
    return findings


def scan_public_global_random_singletons(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    code = interface_text(text)
    for match in PUBLIC_GLOBAL_RANDOM_RE.finditer(code):
        line = line_no_at(code, match.start())
        add_finding(
            findings,
            "no-public-global-random-singleton",
            root,
            path,
            line,
            original_line(text, line),
        )
    return findings


def normalize_pascal_member_statement(statement: str) -> str:
    normalized = " ".join(statement.strip().split())
    normalized = re.sub(r"\s*;\s*$", "", normalized)
    normalized = re.sub(r"\s*;\s*(?:inline|static|overload)\b.*$", "", normalized, flags=re.IGNORECASE)
    return normalized


def split_pascal_member_statements(text: str) -> list[str]:
    statements: list[str] = []
    start = 0
    depth = 0
    for index, char in enumerate(text):
        if char == "(":
            depth += 1
        elif char == ")" and depth > 0:
            depth -= 1
        elif char == ";" and depth == 0:
            statements.append(text[start : index + 1])
            start = index + 1
    return statements


def class_public_member_sets(text: str) -> dict[str, tuple[int, set[str]]]:
    code = interface_text(text)
    classes: dict[str, tuple[int, set[str]]] = {}
    for match in re.finditer(
        r"(?P<name>T[A-Za-z0-9_]*)\s*=\s*class\b(?P<body>.*?)\bend\s*;",
        code,
        re.IGNORECASE | re.DOTALL,
    ):
        class_name = match.group("name")
        body = match.group("body")
        class_line = line_no_at(code, match.start("name"))
        public_match = re.search(
            r"\bpublic\b(?P<body>.*?)(?=\b(?:private|protected|public|published)\b|\Z)",
            body,
            re.IGNORECASE | re.DOTALL,
        )
        if public_match is None:
            classes[class_name.lower()] = (class_line, set())
            continue

        public_body = public_match.group("body")
        members = set()
        for statement in split_pascal_member_statements(public_body):
            member = normalize_pascal_member_statement(statement)
            if member.lower() in {"inline", "static", "overload"}:
                continue
            if member:
                members.add(member)
        classes[class_name.lower()] = (class_line, members)
    return classes


def scan_random_noise_public_contract(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    rel = relative(path, root)
    if rel not in {"src/nextpas.core.math.random.pas", ROOT_FACADE_PATH}:
        return findings

    code = interface_text(text)
    for match in RANDOM_NOISE_GLOBAL_HELPER_RE.finditer(code):
        name = match.group(1)
        add_finding(
            findings,
            "random-noise-public-top-level-helper:" + name,
            root,
            path,
            line_no_at(code, match.start(1)),
            name,
        )

    for line_index, line in enumerate(code.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.lower() in {"var", "threadvar"}:
            continue
        if (len(line) - len(line.lstrip(" "))) > 2:
            continue
        if not re.match(r"(?:var|threadvar)?\s*[A-Za-z_][A-Za-z0-9_]*\s*:", stripped, re.IGNORECASE):
            continue
        name_match = RANDOM_NOISE_GLOBAL_NAME_RE.search(stripped)
        if name_match is None:
            continue
        name = name_match.group(1)
        add_finding(
            findings,
            "random-noise-public-global-state:" + name,
            root,
            path,
            line_index,
            name,
        )

    if rel != "src/nextpas.core.math.random.pas":
        return findings

    class_members = class_public_member_sets(text)
    for contract in RANDOM_NOISE_PUBLIC_CONTRACTS:
        class_line, actual_members = class_members.get(contract.class_name.lower(), (1, set()))
        expected_members = set(contract.public_members)
        for member in sorted(expected_members - actual_members):
            add_finding(
                findings,
                "random-noise-missing-public-member:" + contract.class_name + ":" + member,
                root,
                path,
                class_line,
                member,
            )
        for member in sorted(actual_members - expected_members):
            add_finding(
                findings,
                "random-noise-extra-public-member:" + contract.class_name + ":" + member,
                root,
                path,
                class_line,
                member,
            )

    for match in RANDOM_NOISE_CLASS_SINGLETON_RE.finditer(code):
        add_finding(
            findings,
            "random-noise-public-class-singleton",
            root,
            path,
            line_no_at(code, match.start()),
            original_line(text, line_no_at(code, match.start())),
        )
    return findings


def scan_required_public_declarations(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    rel = relative(path, root)
    declarations = REQUIRED_PUBLIC_DECLARATIONS.get(rel)
    if declarations is None:
        return findings

    code = interface_text(text)
    for rule, pattern in declarations:
        if re.search(pattern, code, re.IGNORECASE) is None:
            add_finding(
                findings,
                "missing-required-public-math-api:" + rule,
                root,
                path,
                1,
                "missing required declaration",
            )
    return findings


def scan_vector_length_sqr_record_contract(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != "src/nextpas.core.math.vec.pas":
        return findings

    code = interface_text(text)
    for rule, record_name, return_type in REQUIRED_VECTOR_LENGTH_SQR_RECORD_CONTRACTS:
        record_match = re.search(
            rf"\b{record_name}\s*=\s*packed\s+record\b(?P<body>.*?)\bend\s*;",
            code,
            re.IGNORECASE | re.DOTALL,
        )
        if record_match is None:
            add_finding(
                findings,
                "missing-vector-lengthsqr-record:" + rule,
                root,
                path,
                1,
                "missing " + record_name + " record",
            )
            continue
        if re.search(
            rf"\bfunction\s+LengthSqr\s*:\s*{return_type}\b",
            record_match.group("body"),
            re.IGNORECASE,
        ) is not None:
            continue
        add_finding(
            findings,
            "missing-vector-lengthsqr-signature:" + rule,
            root,
            path,
            line_no_at(code, record_match.start()),
            "missing " + record_name + ".LengthSqr: " + return_type,
        )
    return findings


def scan_vector_public_record_contract(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != "src/nextpas.core.math.vec.pas":
        return findings

    code = interface_text(text)
    for rule, record_name, scalar_type, fields, index_range, has_cross in REQUIRED_VECTOR_PUBLIC_RECORD_CONTRACTS:
        record_match = re.search(
            rf"\b{record_name}\s*=\s*packed\s+record\b(?P<body>.*?)\bend\s*;",
            code,
            re.IGNORECASE | re.DOTALL,
        )
        if record_match is None:
            add_finding(
                findings,
                "missing-vector-public-contract:" + rule + ":record",
                root,
                path,
                1,
                "missing " + record_name + " record",
            )
            continue

        body = record_match.group("body")
        record_line = line_no_at(code, record_match.start())

        create_args = r"\s*,\s*".join("A" + field for field in fields)
        field_names = r"\s*,\s*".join(fields)
        required_patterns = (
            (
                "tindex",
                rf"\bTIndex\s*=\s*{re.escape(index_range)}\s*;",
            ),
            (
                "create",
                rf"\bclass\s+function\s+Create\s*\(\s*const\s+{create_args}\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "zero",
                rf"\bclass\s+function\s+Zero\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "operator-add",
                rf"\bclass\s+operator\s+\+\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "operator-subtract",
                rf"\bclass\s+operator\s+-\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "operator-negate",
                rf"\bclass\s+operator\s+-\s*\(\s*const\s+AValue\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "operator-scale-right",
                rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AValue\s*:\s*{record_name}\s*;\s*const\s+AScalar\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "operator-scale-left",
                rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AScalar\s*:\s*{scalar_type}\s*;\s*const\s+AValue\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "operator-divide-scalar",
                rf"\bclass\s+operator\s+/\s*\(\s*const\s+AValue\s*:\s*{record_name}\s*;\s*const\s+AScalar\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "mul-components",
                rf"\bclass\s+function\s+MulComponents\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "div-components",
                rf"\bclass\s+function\s+DivComponents\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "dot",
                rf"\bclass\s+function\s+Dot\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{scalar_type}\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "lerp",
                rf"\bclass\s+function\s+Lerp\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*;\s*const\s+AT\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "equals",
                rf"\bclass\s+function\s+Equals\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*;\s*const\s+AEpsilon\s*:\s*{scalar_type}\s*\)\s*:\s*Boolean\s*;\s*static\s*;\s*inline\s*;",
            ),
            (
                "lengthsqr",
                rf"\bfunction\s+LengthSqr\s*:\s*{scalar_type}\s*;\s*inline\s*;",
            ),
            (
                "length",
                rf"\bfunction\s+Length\s*:\s*{scalar_type}\s*;\s*inline\s*;",
            ),
            (
                "normalize",
                rf"\bfunction\s+Normalize\s*:\s*{record_name}\s*;\s*inline\s*;",
            ),
            (
                "data-alias",
                rf"\b0\s*:\s*\(\s*{field_names}\s*:\s*{scalar_type}\s*\)\s*;\s*1\s*:\s*\(\s*Data\s*:\s*array\s*\[\s*TIndex\s*\]\s*of\s*{scalar_type}\s*\)\s*;",
            ),
        )

        for contract_name, pattern in required_patterns:
            if re.search(pattern, body, re.IGNORECASE | re.DOTALL) is not None:
                continue
            add_finding(
                findings,
                "missing-vector-public-contract:" + rule + ":" + contract_name,
                root,
                path,
                record_line,
                "missing " + record_name + "." + contract_name,
            )

        cross_pattern = (
            rf"\bclass\s+function\s+Cross\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;"
        )
        has_cross_signature = re.search(
            cross_pattern,
            body,
            re.IGNORECASE | re.DOTALL,
        ) is not None
        has_cross_declaration = re.search(
            r"\bclass\s+function\s+Cross\s*\(",
            body,
            re.IGNORECASE | re.DOTALL,
        ) is not None
        if has_cross and not has_cross_signature:
            add_finding(
                findings,
                "missing-vector-public-contract:" + rule + ":cross",
                root,
                path,
                record_line,
                "missing " + record_name + ".Cross",
            )
        if (not has_cross) and has_cross_declaration:
            add_finding(
                findings,
                "unexpected-vector-public-contract:" + rule + ":cross",
                root,
                path,
                record_line,
                record_name + ".Cross must stay 3D-only",
            )

        vector_multiply_pattern = (
            rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;"
        )
        if re.search(vector_multiply_pattern, body, re.IGNORECASE | re.DOTALL) is not None:
            add_finding(
                findings,
                "forbidden-vector-vector-operator-multiply:" + rule,
                root,
                path,
                record_line,
                record_name + " must use Dot or MulComponents instead of vector-vector operator *",
            )
    return findings


def scan_matrix_public_record_contract(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != "src/nextpas.core.math.mat.pas":
        return findings

    code = interface_text(text)
    for rule, record_name, scalar_type, vector_type, index_range, is_mat3 in REQUIRED_MATRIX_PUBLIC_RECORD_CONTRACTS:
        record_match = re.search(
            rf"\b{record_name}\s*=\s*packed\s+record\b(?P<body>.*?)\bend\s*;",
            code,
            re.IGNORECASE | re.DOTALL,
        )
        if record_match is None:
            add_finding(
                findings,
                "missing-matrix-public-contract:" + rule + ":record",
                root,
                path,
                1,
                "missing " + record_name + " record",
            )
            continue

        body = record_match.group("body")
        record_line = line_no_at(code, record_match.start())
        column_args = ("AColumn0", "AColumn1", "AColumn2") if is_mat3 else (
            "AColumn0",
            "AColumn1",
            "AColumn2",
            "AColumn3",
        )
        create_args = r"\s*,\s*".join(column_args)
        determinant_suffix = r"\s*;\s*inline\s*;" if is_mat3 else r"\s*;"
        required_patterns = (
            ("tindex", rf"\bTIndex\s*=\s*{re.escape(index_range)}\s*;"),
            ("tcolumn", rf"\bTColumn\s*=\s*array\s*\[\s*TIndex\s*\]\s*of\s*{scalar_type}\s*;"),
            ("get-items", rf"\bfunction\s+GetItems\s*\(\s*const\s+AColumn\s*,\s*ARow\s*:\s*TIndex\s*\)\s*:\s*{scalar_type}\s*;\s*inline\s*;"),
            ("set-items", rf"\bprocedure\s+SetItems\s*\(\s*const\s+AColumn\s*,\s*ARow\s*:\s*TIndex\s*;\s*const\s+AValue\s*:\s*{scalar_type}\s*\)\s*;\s*inline\s*;"),
            ("get-rows", rf"\bfunction\s+GetRows\s*\(\s*const\s+ARow\s*:\s*TIndex\s*\)\s*:\s*{vector_type}\s*;\s*inline\s*;"),
            ("set-rows", rf"\bprocedure\s+SetRows\s*\(\s*const\s+ARow\s*:\s*TIndex\s*;\s*const\s+AValue\s*:\s*{vector_type}\s*\)\s*;\s*inline\s*;"),
            ("get-columns", rf"\bfunction\s+GetColumns\s*\(\s*const\s+AColumn\s*:\s*TIndex\s*\)\s*:\s*{vector_type}\s*;\s*inline\s*;"),
            ("set-columns", rf"\bprocedure\s+SetColumns\s*\(\s*const\s+AColumn\s*:\s*TIndex\s*;\s*const\s+AValue\s*:\s*{vector_type}\s*\)\s*;\s*inline\s*;"),
            ("data", r"\bData\s*:\s*array\s*\[\s*TIndex\s*\]\s*of\s*TColumn\s*;"),
            ("create", rf"\bclass\s+function\s+Create\s*\(\s*const\s+{create_args}\s*:\s*{vector_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;"),
            ("zero", rf"\bclass\s+function\s+Zero\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;"),
            ("identity", rf"\bclass\s+function\s+Identity\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;"),
            ("operator-add", rf"\bclass\s+operator\s+\+\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("operator-subtract", rf"\bclass\s+operator\s+-\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("operator-negate", rf"\bclass\s+operator\s+-\s*\(\s*const\s+AValue\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("operator-scale-right", rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AValue\s*:\s*{record_name}\s*;\s*const\s+AScalar\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("operator-scale-left", rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AScalar\s*:\s*{scalar_type}\s*;\s*const\s+AValue\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("operator-mul-vector", rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AMatrix\s*:\s*{record_name}\s*;\s*const\s+AVector\s*:\s*{vector_type}\s*\)\s*:\s*{vector_type}\s*;\s*inline\s*;"),
            ("operator-mul-matrix", rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;"),
            ("equals", rf"\bclass\s+function\s+Equals\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*;\s*const\s+AEpsilon\s*:\s*{scalar_type}\s*\)\s*:\s*Boolean\s*;\s*static\s*;\s*inline\s*;"),
            ("transpose", rf"\bfunction\s+Transpose\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("determinant", rf"\bfunction\s+Determinant\s*:\s*{scalar_type}{determinant_suffix}"),
            ("try-inverse", rf"\bfunction\s+TryInverse\s*\(\s*out\s+AInverse\s*:\s*{record_name}\s*\)\s*:\s*Boolean\s*;"),
            ("inverse", rf"\bfunction\s+Inverse\s*:\s*{record_name}\s*;"),
            ("property-items", rf"\bproperty\s+Items\s*\[\s*const\s+AColumn\s*,\s*ARow\s*:\s*TIndex\s*\]\s*:\s*{scalar_type}\s+read\s+GetItems\s+write\s+SetItems\s*;\s*default\s*;"),
            ("property-rows", rf"\bproperty\s+Rows\s*\[\s*const\s+ARow\s*:\s*TIndex\s*\]\s*:\s*{vector_type}\s+read\s+GetRows\s+write\s+SetRows\s*;"),
            ("property-columns", rf"\bproperty\s+Columns\s*\[\s*const\s+AColumn\s*:\s*TIndex\s*\]\s*:\s*{vector_type}\s+read\s+GetColumns\s+write\s+SetColumns\s*;"),
        )
        for contract_name, pattern in required_patterns:
            if re.search(pattern, body, re.IGNORECASE | re.DOTALL) is not None:
                continue
            add_finding(
                findings,
                "missing-matrix-public-contract:" + rule + ":" + contract_name,
                root,
                path,
                record_line,
                "missing " + record_name + "." + contract_name,
            )
    return findings


def scan_quaternion_public_record_contract(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != "src/nextpas.core.math.quat.pas":
        return findings

    code = interface_text(text)
    for rule, record_name, scalar_type, vector_type, matrix_type in REQUIRED_QUATERNION_PUBLIC_RECORD_CONTRACTS:
        record_match = re.search(
            rf"\b{record_name}\s*=\s*packed\s+record\b(?P<body>.*?)\bend\s*;",
            code,
            re.IGNORECASE | re.DOTALL,
        )
        if record_match is None:
            add_finding(
                findings,
                "missing-quaternion-public-contract:" + rule + ":record",
                root,
                path,
                1,
                "missing " + record_name + " record",
            )
            continue

        body = record_match.group("body")
        record_line = line_no_at(code, record_match.start())
        required_patterns = (
            ("tindex", r"\bTIndex\s*=\s*0\.\.3\s*;"),
            ("create", rf"\bclass\s+function\s+Create\s*\(\s*const\s+AX\s*,\s*AY\s*,\s*AZ\s*,\s*AW\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;"),
            ("identity", rf"\bclass\s+function\s+Identity\s*:\s*{record_name}\s*;\s*static\s*;\s*inline\s*;"),
            ("operator-mul", rf"\bclass\s+operator\s+\*\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*\)\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("from-axis-angle", rf"\bclass\s+function\s+FromAxisAngle\s*\(\s*const\s+AAxis\s*:\s*{vector_type}\s*;\s*const\s+AAngleRad\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;"),
            ("slerp", rf"\bclass\s+function\s+Slerp\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*;\s*const\s+AT\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;"),
            ("nlerp", rf"\bclass\s+function\s+Nlerp\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*;\s*const\s+AT\s*:\s*{scalar_type}\s*\)\s*:\s*{record_name}\s*;\s*static\s*;"),
            ("equals", rf"\bclass\s+function\s+Equals\s*\(\s*const\s+AA\s*,\s*AB\s*:\s*{record_name}\s*;\s*const\s+AEpsilon\s*:\s*{scalar_type}\s*\)\s*:\s*Boolean\s*;\s*static\s*;\s*inline\s*;"),
            ("to-axis-angle", rf"\bprocedure\s+ToAxisAngle\s*\(\s*out\s+AAxis\s*:\s*{vector_type}\s*;\s*out\s+AAngleRad\s*:\s*{scalar_type}\s*\)\s*;"),
            ("to-rotation-matrix", rf"\bfunction\s+ToRotationMatrix\s*:\s*{matrix_type}\s*;"),
            ("rotate", rf"\bfunction\s+Rotate\s*\(\s*const\s+AVector\s*:\s*{vector_type}\s*\)\s*:\s*{vector_type}\s*;"),
            ("conjugate", rf"\bfunction\s+Conjugate\s*:\s*{record_name}\s*;\s*inline\s*;"),
            ("normalize", rf"\bfunction\s+Normalize\s*:\s*{record_name}\s*;"),
            ("data-alias", rf"\b0\s*:\s*\(\s*X\s*,\s*Y\s*,\s*Z\s*,\s*W\s*:\s*{scalar_type}\s*\)\s*;\s*1\s*:\s*\(\s*Data\s*:\s*array\s*\[\s*TIndex\s*\]\s*of\s*{scalar_type}\s*\)\s*;"),
        )
        for contract_name, pattern in required_patterns:
            if re.search(pattern, body, re.IGNORECASE | re.DOTALL) is not None:
                continue
            add_finding(
                findings,
                "missing-quaternion-public-contract:" + rule + ":" + contract_name,
                root,
                path,
                record_line,
                "missing " + record_name + "." + contract_name,
            )
    return findings


def scan_missing_required_public_files(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for rel in sorted(REQUIRED_PUBLIC_DECLARATIONS):
        path = root / rel
        if path.is_file():
            continue
        add_finding(
            findings,
            "missing-required-public-math-file",
            root,
            path,
            1,
            rel,
        )
    return findings


def run_required_public_declarations_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        src = root / "src"
        src.mkdir(parents=True, exist_ok=True)
        root_facade = src / "nextpas.core.math.pas"
        scalar = src / "nextpas.core.math.scalar.pas"
        root_facade.write_text(
            "unit nextpas.core.math;\n"
            "interface\n"
            "function Fmod(const AX, AY: Double): Double; overload; inline;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        scalar.write_text(
            "unit nextpas.core.math.scalar;\n"
            "interface\n"
            "function Fmod(const AX, AY: Double): Double; overload; inline;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_required_public_declarations(
            root,
            root_facade,
            root_facade.read_text(encoding="utf-8"),
        ) + scan_required_public_declarations(
            root,
            scalar,
            scalar.read_text(encoding="utf-8"),
        )
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "missing-required-public-math-api:root-fmod-extended",
            "missing-required-public-math-api:root-fmod-single",
            "missing-required-public-math-api:root-single-abs",
            "missing-required-public-math-api:root-single-clamp",
            "missing-required-public-math-api:root-single-degtorad",
            "missing-required-public-math-api:root-single-floatequals",
            "missing-required-public-math-api:root-single-floatiszero",
            "missing-required-public-math-api:root-single-floor",
            "missing-required-public-math-api:root-single-frac",
            "missing-required-public-math-api:root-single-inverselerp",
            "missing-required-public-math-api:root-single-isinfinite",
            "missing-required-public-math-api:root-single-isnan",
            "missing-required-public-math-api:root-single-lerp",
            "missing-required-public-math-api:root-single-max",
            "missing-required-public-math-api:root-single-radtodeg",
            "missing-required-public-math-api:root-single-round",
            "missing-required-public-math-api:root-single-sign",
            "missing-required-public-math-api:root-single-trunc",
            "missing-required-public-math-api:root-single-wrap",
            "missing-required-public-math-api:scalar-fmod-extended",
            "missing-required-public-math-api:scalar-fmod-single",
            "missing-required-public-math-api:scalar-single-abs",
            "missing-required-public-math-api:scalar-single-clamp",
            "missing-required-public-math-api:scalar-single-degtorad",
            "missing-required-public-math-api:scalar-single-floatequals",
            "missing-required-public-math-api:scalar-single-floatiszero",
            "missing-required-public-math-api:scalar-single-floor",
            "missing-required-public-math-api:scalar-single-frac",
            "missing-required-public-math-api:scalar-single-inverselerp",
            "missing-required-public-math-api:scalar-single-isinfinite",
            "missing-required-public-math-api:scalar-single-isnan",
            "missing-required-public-math-api:scalar-single-lerp",
            "missing-required-public-math-api:scalar-single-max",
            "missing-required-public-math-api:scalar-single-radtodeg",
            "missing-required-public-math-api:scalar-single-round",
            "missing-required-public-math-api:scalar-single-sign",
            "missing-required-public-math-api:scalar-single-smoothstep",
            "missing-required-public-math-api:scalar-single-trunc",
            "missing-required-public-math-api:scalar-single-wrap",
        }
        if not expected_rules.issubset(rules):
            raise AssertionError(
                "required-public-declarations self-test expected "
                + ", ".join(sorted(expected_rules))
            )


def run_random_noise_public_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.random.pas"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.random;\n"
            "interface\n"
            "type\n"
            "  TRandomState = record S0: UInt64; S1: UInt64; end;\n"
            "  TRandomGen = class\n"
            "  private\n"
            "    FState: TRandomState;\n"
            "  public\n"
            "    constructor Create(const ASeed: UInt64 = 0);\n"
            "    procedure SetSeed(const ASeed: UInt64);\n"
            "    function NextInt: Integer;\n"
            "    function NextIntRange(const AMin, AMax: Integer): Integer;\n"
            "    function NextFloat: Single;\n"
            "    function NextFloatRange(const AMin, AMax: Single): Single;\n"
            "    function NextDouble: Double;\n"
            "    function NextBool(const AProbability: Single = 0.5): Boolean;\n"
            "    function NextGaussian: Single;\n"
            "    function NextVec2InCircle: TVec2f;\n"
            "    function NextVec2OnCircle: TVec2f;\n"
            "    function Roll(const ASides: Integer): Integer;\n"
            "    function RollMultiple(const ADice, ASides: Integer): Integer;\n"
            "    function WeightedChoice(const AWeights: array of Single): Integer;\n"
            "    procedure Shuffle(var AValues: array of Integer);\n"
            "    property State: TRandomState read FState write FState;\n"
            "  end;\n"
            "  TNoiseGen = class\n"
            "  public\n"
            "    constructor Create(const ASeed: UInt64 = 0);\n"
            "    procedure SetSeed(const ASeed: UInt64);\n"
            "    function Noise1D(const AX: Double): Double;\n"
            "    function Noise2D(const AX, AY: Double): Double;\n"
            "    function Noise3D(const AX, AY, AZ: Double): Double;\n"
            "    function FBM1D(const AX: Double; const AOctaves: Integer; const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double;\n"
            "    function FBM2D(const AX, AY: Double; const AOctaves: Integer; const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double;\n"
            "    function FBM3D(const AX, AY, AZ: Double; const AOctaves: Integer; const ALacunarity: Double = 2.0; const AGain: Double = 0.5): Double;\n"
            "  end;\n"
            "function RandomDouble: Double;\n"
            "var GlobalRandom: TRandomGen;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_random_noise_public_contract(root, path, path.read_text(encoding="utf-8"))
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "random-noise-public-top-level-helper:RandomDouble",
            "random-noise-public-global-state:GlobalRandom",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "random-noise-public-contract self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        path.write_text(
            path.read_text(encoding="utf-8")
            .replace("function RandomDouble: Double;\n", "")
            .replace("var GlobalRandom: TRandomGen;\n", ""),
            encoding="utf-8",
        )
        findings = scan_random_noise_public_contract(root, path, path.read_text(encoding="utf-8"))
        if findings:
            raise AssertionError(
                "random-noise-public-contract self-test expected no findings, got "
                + ", ".join(sorted(finding.rule for finding in findings))
            )

        root_facade = root / ROOT_FACADE_PATH
        root_facade.write_text(
            "unit nextpas.core.math;\n"
            "interface\n"
            "uses nextpas.core.math.random;\n"
            "type\n"
            "  TRandomState = nextpas.core.math.random.TRandomState;\n"
            "  TRandomGen = nextpas.core.math.random.TRandomGen;\n"
            "  TNoiseGen = nextpas.core.math.random.TNoiseGen;\n"
            "function DefaultRandom: TRandomGen;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_random_noise_public_contract(
            root, root_facade, root_facade.read_text(encoding="utf-8")
        )
        rules = {finding.rule for finding in findings}
        expected_rule = "random-noise-public-top-level-helper:DefaultRandom"
        if expected_rule not in rules:
            raise AssertionError(
                "random-noise-public-contract self-test expected " + expected_rule
            )


def run_vector_public_record_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.vec.pas"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "type\n"
            "  TVec2f = packed record\n"
            "  public\n"
            "    type\n"
            "      TIndex = 0..1;\n"
            "    class function Create(const AX, AY: Single): TVec2f; static; inline;\n"
            "    class function Zero: TVec2f; static; inline;\n"
            "    class operator + (const AA, AB: TVec2f): TVec2f; inline;\n"
            "    class operator - (const AA, AB: TVec2f): TVec2f; inline;\n"
            "    class operator - (const AValue: TVec2f): TVec2f; inline;\n"
            "    class operator * (const AValue: TVec2f; const AScalar: Single): TVec2f; inline;\n"
            "    class operator * (const AScalar: Single; const AValue: TVec2f): TVec2f; inline;\n"
            "    class operator * (const AA, AB: TVec2f): TVec2f; inline;\n"
            "    class operator / (const AValue: TVec2f; const AScalar: Single): TVec2f; inline;\n"
            "    class function MulComponents(const AA, AB: TVec2f): TVec2f; static; inline;\n"
            "    class function DivComponents(const AA, AB: TVec2f): TVec2f; static; inline;\n"
            "    class function Dot(const AA, AB: TVec2f): Single; static; inline;\n"
            "    class function Cross(const AA, AB: TVec2f): Single; static; inline;\n"
            "    class function Lerp(const AA, AB: TVec2f; const AT: Single): TVec2f; static; inline;\n"
            "    class function Equals(const AA, AB: TVec2f; const AEpsilon: Single): Boolean; static; inline;\n"
            "    function LengthSqr: Single; inline;\n"
            "    function Length: Single; inline;\n"
            "    function Normalize: TVec2f; inline;\n"
            "    var\n"
            "      case Integer of\n"
            "        0: (X, Y: Single);\n"
            "  end;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_vector_public_record_contract(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "forbidden-vector-vector-operator-multiply:vec-2f",
            "missing-vector-public-contract:vec-2f:data-alias",
            "unexpected-vector-public-contract:vec-2f:cross",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "vector-public-record-contract self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        path.write_text(
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "type\n"
            "  TVec2f = packed record\n"
            "  public\n"
            "    type\n"
            "      TIndex = 0..1;\n"
            "    class function Create(const AX, AY: Single): TVec2f; static; inline;\n"
            "    class function Zero: TVec2f; static; inline;\n"
            "    class operator + (const AA, AB: TVec2f): TVec2f; inline;\n"
            "    class operator - (const AA, AB: TVec2f): TVec2f; inline;\n"
            "    class operator - (const AValue: TVec2f): TVec2f; inline;\n"
            "    class operator * (const AValue: TVec2f; const AScalar: Single): TVec2f; inline;\n"
            "    class operator * (const AScalar: Single; const AValue: TVec2f): TVec2f; inline;\n"
            "    class operator / (const AValue: TVec2f; const AScalar: Single): TVec2f; inline;\n"
            "    class function MulComponents(const AA, AB: TVec2f): TVec2f; static; inline;\n"
            "    class function DivComponents(const AA, AB: TVec2f): TVec2f; static; inline;\n"
            "    class function Dot(const AA, AB: TVec2f): Single; static; inline;\n"
            "    class function Lerp(const AA, AB: TVec2f; const AT: Single): TVec2f; static; inline;\n"
            "    class function Equals(const AA, AB: TVec2f; const AEpsilon: Single): Boolean; static; inline;\n"
            "    function LengthSqr: Single; inline;\n"
            "    function Length: Single; inline;\n"
            "    function Normalize: TVec2f; inline;\n"
            "    var\n"
            "      case Integer of\n"
            "        0: (X, Y: Single);\n"
            "        1: (Data: array[TIndex] of Single);\n"
            "  end;\n"
            "  TVec3f = packed record\n"
            "  public\n"
            "    type\n"
            "      TIndex = 0..2;\n"
            "    class function Create(const AX, AY, AZ: Single): TVec3f; static; inline;\n"
            "    class function Zero: TVec3f; static; inline;\n"
            "    class operator + (const AA, AB: TVec3f): TVec3f; inline;\n"
            "    class operator - (const AA, AB: TVec3f): TVec3f; inline;\n"
            "    class operator - (const AValue: TVec3f): TVec3f; inline;\n"
            "    class operator * (const AValue: TVec3f; const AScalar: Single): TVec3f; inline;\n"
            "    class operator * (const AScalar: Single; const AValue: TVec3f): TVec3f; inline;\n"
            "    class operator / (const AValue: TVec3f; const AScalar: Single): TVec3f; inline;\n"
            "    class function MulComponents(const AA, AB: TVec3f): TVec3f; static; inline;\n"
            "    class function DivComponents(const AA, AB: TVec3f): TVec3f; static; inline;\n"
            "    class function Dot(const AA, AB: TVec3f): Single; static; inline;\n"
            "    class function Cross(const AA, AB: TVec3f): TVec3f; static; inline;\n"
            "    class function Lerp(const AA, AB: TVec3f; const AT: Single): TVec3f; static; inline;\n"
            "    class function Equals(const AA, AB: TVec3f; const AEpsilon: Single): Boolean; static; inline;\n"
            "    function LengthSqr: Single; inline;\n"
            "    function Length: Single; inline;\n"
            "    function Normalize: TVec3f; inline;\n"
            "    var\n"
            "      case Integer of\n"
            "        0: (X, Y, Z: Single);\n"
            "        1: (Data: array[TIndex] of Single);\n"
            "  end;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_vector_public_record_contract(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = {finding.rule for finding in findings}
        expected_missing_records = {
            "missing-vector-public-contract:vec-2d:record",
            "missing-vector-public-contract:vec-3d:record",
            "missing-vector-public-contract:vec-4d:record",
            "missing-vector-public-contract:vec-4f:record",
        }
        if rules != expected_missing_records:
            raise AssertionError(
                "vector-public-record-contract self-test expected only missing "
                + "unfixture records, got "
                + ", ".join(sorted(rules))
            )


def run_matrix_public_record_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.mat.pas"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.mat;\n"
            "interface\n"
            "type\n"
            "  TMat3f = packed record\n"
            "  public\n"
            "    type\n"
            "      TIndex = 0..2;\n"
            "      TColumn = array[TIndex] of Single;\n"
            "  strict private\n"
            "    function GetItems(const AColumn, ARow: TIndex): Single; inline;\n"
            "    procedure SetItems(const AColumn, ARow: TIndex; const AValue: Single); inline;\n"
            "    function GetRows(const ARow: TIndex): TVec3f; inline;\n"
            "    procedure SetRows(const ARow: TIndex; const AValue: TVec3f); inline;\n"
            "    function GetColumns(const AColumn: TIndex): TVec3f; inline;\n"
            "    procedure SetColumns(const AColumn: TIndex; const AValue: TVec3f); inline;\n"
            "  public\n"
            "    class function Create(const AColumn0, AColumn1, AColumn2: TVec3f): TMat3f; static; inline;\n"
            "    class function Zero: TMat3f; static; inline;\n"
            "    class function Identity: TMat3f; static; inline;\n"
            "    class operator + (const AA, AB: TMat3f): TMat3f; inline;\n"
            "    class operator - (const AA, AB: TMat3f): TMat3f; inline;\n"
            "    class operator - (const AValue: TMat3f): TMat3f; inline;\n"
            "    class operator * (const AValue: TMat3f; const AScalar: Single): TMat3f; inline;\n"
            "    class operator * (const AScalar: Single; const AValue: TMat3f): TMat3f; inline;\n"
            "    class operator * (const AMatrix: TMat3f; const AVector: TVec3f): TVec3f; inline;\n"
            "    class operator * (const AA, AB: TMat3f): TMat3f;\n"
            "    class function Equals(const AA, AB: TMat3f; const AEpsilon: Single): Boolean; static; inline;\n"
            "    function Transpose: TMat3f; inline;\n"
            "    function Determinant: Single; inline;\n"
            "    function TryInverse(out AInverse: TMat3f): Boolean;\n"
            "    function Inverse: TMat3f;\n"
            "    property Items[const AColumn, ARow: TIndex]: Single read GetItems write SetItems; default;\n"
            "    property Rows[const ARow: TIndex]: TVec3f read GetRows write SetRows;\n"
            "    property Columns[const AColumn: TIndex]: TVec3f read GetColumns write SetColumns;\n"
            "  end;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_matrix_public_record_contract(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = {finding.rule for finding in findings}
        expected_rules = {"missing-matrix-public-contract:mat-3f:data"}
        if not expected_rules <= rules:
            raise AssertionError(
                "matrix-public-record-contract self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )


def run_quaternion_public_record_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.quat.pas"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.quat;\n"
            "interface\n"
            "type\n"
            "  TQuatf = packed record\n"
            "  public\n"
            "    type\n"
            "      TIndex = 0..3;\n"
            "    class function Create(const AX, AY, AZ, AW: Single): TQuatf; static; inline;\n"
            "    class function Identity: TQuatf; static; inline;\n"
            "    class operator * (const AA, AB: TQuatf): TQuatf; inline;\n"
            "    class function FromAxisAngle(const AAxis: TVec3f; const AAngleRad: Single): TQuatf; static;\n"
            "    class function Slerp(const AA, AB: TQuatf; const AT: Single): TQuatf; static;\n"
            "    class function Nlerp(const AA, AB: TQuatf; const AT: Single): TQuatf; static;\n"
            "    class function Equals(const AA, AB: TQuatf; const AEpsilon: Single): Boolean; static; inline;\n"
            "    function ToRotationMatrix: TMat3f;\n"
            "    function Rotate(const AVector: TVec3f): TVec3f;\n"
            "    function Conjugate: TQuatf; inline;\n"
            "    function Normalize: TQuatf;\n"
            "    var\n"
            "      case Integer of\n"
            "        0: (X, Y, Z, W: Single);\n"
            "        1: (Data: array[TIndex] of Single);\n"
            "  end;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_quaternion_public_record_contract(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = {finding.rule for finding in findings}
        expected_rules = {"missing-quaternion-public-contract:quat-f:to-axis-angle"}
        if not expected_rules <= rules:
            raise AssertionError(
                "quaternion-public-record-contract self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )


def scan_missing_required_benchmark_markers(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for rel, markers in REQUIRED_BENCHMARK_MARKERS.items():
        path = root / rel
        if not path.is_file():
            add_finding(
                findings,
                "missing-required-math-benchmark-file",
                root,
                path,
                1,
                rel,
            )
            continue

        text = path.read_text(encoding="utf-8", errors="replace")
        for rule, marker in markers:
            if marker in text:
                continue
            add_finding(
                findings,
                "missing-required-math-benchmark-marker:" + rule,
                root,
                path,
                1,
                "missing benchmark marker " + marker,
            )
    return findings


def scan_required_behavior_test_markers(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    cache: dict[str, str | None] = {}

    for required_marker in REQUIRED_BEHAVIOR_TEST_MARKERS:
        code = cache.get(required_marker.path)
        path = root / required_marker.path
        if code is None and required_marker.path not in cache:
            if not path.is_file():
                cache[required_marker.path] = None
                add_finding(
                    findings,
                    "missing-required-behavior-test-file:" + required_marker.rule,
                    root,
                    path,
                    1,
                    required_marker.path,
                )
                continue
            code = strip_pascal_comments(
                path.read_text(encoding="utf-8", errors="replace")
            )
            cache[required_marker.path] = code

        if code is None:
            continue
        if required_marker.marker in code:
            continue
        add_finding(
            findings,
            "missing-required-behavior-test-marker:" + required_marker.rule,
            root,
            path,
            1,
            "missing behavior test marker " + required_marker.marker,
        )
    return findings


def scan_facade_type_alias_compile_surface(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / FACADE_TYPE_ALIAS_COMPILE_TEST_PATH
    alias_rules = set(REQUIRED_ROOT_FACADE_TYPE_ALIASES)
    compile_rules = set(REQUIRED_FACADE_TYPE_ALIAS_COMPILE_USES)
    for alias in sorted(alias_rules - compile_rules):
        add_finding(
            findings,
            "missing-facade-type-alias-compile-rule:" + alias,
            root,
            root / ROOT_FACADE_PATH,
            1,
            "missing facade compile-use rule for " + alias,
        )
    for alias in sorted(compile_rules - alias_rules):
        add_finding(
            findings,
            "stale-facade-type-alias-compile-rule:" + alias,
            root,
            path,
            1,
            "stale facade compile-use rule for " + alias,
        )

    if not path.is_file():
        add_finding(
            findings,
            "missing-facade-type-alias-compile-test-file",
            root,
            path,
            1,
            FACADE_TYPE_ALIAS_COMPILE_TEST_PATH,
        )
        return findings

    text = strip_pascal_comments(path.read_text(encoding="utf-8", errors="replace"))
    if FACADE_TYPE_ALIAS_COMPILE_TEST_MARKER not in text:
        add_finding(
            findings,
            "missing-facade-type-alias-compile-marker",
            root,
            path,
            1,
            "missing " + FACADE_TYPE_ALIAS_COMPILE_TEST_MARKER,
        )

    normalized_text = re.sub(r"\s+", " ", text).lower()
    for alias, required_snippet in REQUIRED_FACADE_TYPE_ALIAS_COMPILE_USES.items():
        normalized_snippet = re.sub(r"\s+", " ", required_snippet).lower()
        if normalized_snippet in normalized_text:
            continue
        add_finding(
            findings,
            "missing-facade-type-alias-compile-use:" + alias,
            root,
            path,
            1,
            "missing facade consumer compile use for " + alias,
        )
    return findings


def scan_facade_root_import_contract(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / FACADE_TYPE_ALIAS_COMPILE_TEST_PATH
    if not path.is_file():
        add_finding(
            findings,
            "missing-facade-root-import-test-file",
            root,
            path,
            1,
            FACADE_TYPE_ALIAS_COMPILE_TEST_PATH,
        )
        return findings

    text = path.read_text(encoding="utf-8", errors="replace")
    code = strip_pascal_comments_and_strings(text)
    if FACADE_ROOT_IMPORT_TEST_MARKER not in strip_pascal_comments(text):
        add_finding(
            findings,
            "missing-facade-root-import-marker",
            root,
            path,
            1,
            FACADE_ROOT_IMPORT_TEST_MARKER,
        )

    units = active_uses_units_with_lines(interface_text(code))
    seen_units = {unit for unit, _line in units}
    if "nextpas.core.math" not in seen_units:
        add_finding(
            findings,
            "facade-consumer-missing-root-import",
            root,
            path,
            1,
            "nextpas.core.math",
        )
    for unit, line in units:
        if not unit.startswith("nextpas.core.math."):
            continue
        add_finding(
            findings,
            "facade-consumer-disallowed-math-import:" + unit,
            root,
            path,
            line,
            unit,
        )
    return findings


def run_facade_type_alias_compile_surface_self_tests() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        path = root / FACADE_TYPE_ALIAS_COMPILE_TEST_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "program test_facade;\n"
            "begin\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_facade_type_alias_compile_surface(root)
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "missing-facade-type-alias-compile-marker",
            "missing-facade-type-alias-compile-use:tvec2f",
            "missing-facade-type-alias-compile-use:tnoisegen",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "facade-type-alias-compile-surface self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        declarations = "\n".join(
            "  " + required_snippet + ";"
            for required_snippet in REQUIRED_FACADE_TYPE_ALIAS_COMPILE_USES.values()
        )
        path.write_text(
            "program test_facade;\n"
            "procedure TestFacadeTypeAliasCompileSurface;\n"
            "var\n"
            + declarations
            + "\n"
            "begin\n"
            "end;\n"
            "begin\n"
            "  T.Run('facade type alias compile surface', @TestFacadeTypeAliasCompileSurface);\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_facade_type_alias_compile_surface(root)
        if findings:
            raise AssertionError(
                "facade-type-alias-compile-surface self-test expected no findings"
            )


def run_facade_root_import_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        path = root / FACADE_TYPE_ALIAS_COMPILE_TEST_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "program test_facade;\n"
            "uses\n"
            "  SysUtils,\n"
            "  nextpas.core.testing,\n"
            "  nextpas.core.errors,\n"
            "  nextpas.core.math,\n"
            "  nextpas.core.math.vec;\n"
            "begin\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_facade_root_import_contract(root)
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "missing-facade-root-import-marker",
            "facade-consumer-disallowed-math-import:nextpas.core.math.vec",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "facade-root-import-contract self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        path.write_text(
            "program test_facade;\n"
            "uses\n"
            "  SysUtils,\n"
            "  nextpas.core.testing,\n"
            "  nextpas.core.errors,\n"
            "  nextpas.core.math;\n"
            "begin\n"
            "  T.Run('facade imports only root math unit', procedure begin end);\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_facade_root_import_contract(root)
        if findings:
            raise AssertionError(
                "facade-root-import-contract self-test expected no findings"
            )


def run_behavior_marker_self_tests() -> None:
    original_markers = REQUIRED_BEHAVIOR_TEST_MARKERS
    required_marker = RequiredBehaviorTestMarker(
        "selftest-scalar-constants",
        "tests/nextpas.core.math/test_scalar/test_scalar.lpr",
        "T.Run('constants'",
    )
    cases = (
        (
            "active-runner",
            "procedure RegisterTests;\n"
            "begin\n"
            "  T.Run('constants', procedure begin end);\n"
            "end;\n",
            True,
        ),
        (
            "line-comment",
            "procedure RegisterTests;\n"
            "begin\n"
            "  // T.Run('constants', procedure begin end);\n"
            "end;\n",
            False,
        ),
        (
            "brace-comment",
            "procedure RegisterTests;\n"
            "begin\n"
            "  { T.Run('constants', procedure begin end); }\n"
            "end;\n",
            False,
        ),
        (
            "paren-star-comment",
            "procedure RegisterTests;\n"
            "begin\n"
            "  (* T.Run('constants', procedure begin end); *)\n"
            "end;\n",
            False,
        ),
    )

    try:
        globals()["REQUIRED_BEHAVIOR_TEST_MARKERS"] = (required_marker,)
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / required_marker.path
            path.parent.mkdir(parents=True, exist_ok=True)
            expected_rule = (
                "missing-required-behavior-test-marker:" + required_marker.rule
            )

            for case_name, text, expected_ok in cases:
                path.write_text(text, encoding="utf-8")
                findings = scan_required_behavior_test_markers(root)
                rules = {finding.rule for finding in findings}
                if expected_ok and findings:
                    raise AssertionError(
                        f"behavior-marker self-test {case_name} expected no findings"
                    )
                if (not expected_ok) and (expected_rule not in rules):
                    raise AssertionError(
                        "behavior-marker self-test "
                        + case_name
                        + " expected "
                        + expected_rule
                    )
    finally:
        globals()["REQUIRED_BEHAVIOR_TEST_MARKERS"] = original_markers


def run_public_math_source_simd_wiring_self_tests() -> None:
    cases = (
        (
            "active-public-uses",
            "src/nextpas.core.math.vec.pas",
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "uses nextpas.core.math.impl.simd;\n"
            "implementation\n"
            "end.\n",
            True,
        ),
        (
            "active-public-simd-facade-uses",
            "src/nextpas.core.math.vec.pas",
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "uses nextpas.core.simd;\n"
            "implementation\n"
            "end.\n",
            True,
        ),
        (
            "line-comment",
            "src/nextpas.core.math.vec.pas",
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "// uses nextpas.core.math.impl.simd;\n"
            "implementation\n"
            "end.\n",
            False,
        ),
        (
            "brace-comment",
            "src/nextpas.core.math.vec.pas",
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "{ uses nextpas.core.math.impl.simd; }\n"
            "implementation\n"
            "end.\n",
            False,
        ),
        (
            "paren-star-comment",
            "src/nextpas.core.math.vec.pas",
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "(* uses nextpas.core.math.impl.simd; *)\n"
            "implementation\n"
            "end.\n",
            False,
        ),
        (
            "string-literal",
            "src/nextpas.core.math.vec.pas",
            "unit nextpas.core.math.vec;\n"
            "interface\n"
            "const Msg = 'nextpas.core.math.impl.simd';\n"
            "implementation\n"
            "end.\n",
            False,
        ),
        (
            "impl-test",
            "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr",
            "program test_impl_simd;\n"
            "uses nextpas.core.math.impl.simd;\n"
            "begin\n"
            "end.\n",
            False,
        ),
        (
            "impl-benchmark",
            "benchmarks/nextpas.core.math/bench_simd_seam/bench_simd_seam.lpr",
            "program bench_simd_seam;\n"
            "uses nextpas.core.math.impl.simd;\n"
            "begin\n"
            "end.\n",
            False,
        ),
        (
            "internal-unit",
            "src/nextpas.core.math.impl.simd.pas",
            "unit nextpas.core.math.impl.simd;\n"
            "interface\n"
            "uses nextpas.core.math.impl.simd;\n"
            "implementation\n"
            "end.\n",
            False,
        ),
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        expected_rule = "no-public-math-unit-impl-simd-wiring"

        for case_name, rel, text, expected_finding in cases:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            findings = scan_public_math_source_simd_wiring(root, path, text)
            rules = {finding.rule for finding in findings}
            if expected_finding and expected_rule not in rules:
                raise AssertionError(
                    "public-math-source-simd-wiring self-test "
                    + case_name
                    + " expected "
                    + expected_rule
                )
            if (not expected_finding) and findings:
                raise AssertionError(
                    "public-math-source-simd-wiring self-test "
                    + case_name
                    + " expected no findings"
                )


def run_math_impl_simd_facade_only_uses_self_tests() -> None:
    cases = (
        (
            "facade-only",
            "unit nextpas.core.math.impl.simd;\n"
            "interface\n"
            "implementation\n"
            "uses nextpas.core.simd;\n"
            "end.\n",
            set(),
        ),
        (
            "missing-facade",
            "unit nextpas.core.math.impl.simd;\n"
            "interface\n"
            "implementation\n"
            "end.\n",
            {"math-impl-simd-missing-public-simd-facade-use"},
        ),
        (
            "private-plus-facade",
            "unit nextpas.core.math.impl.simd;\n"
            "interface\n"
            "implementation\n"
            "uses nextpas.core.simd, nextpas.core.simd.dispatch;\n"
            "end.\n",
            {"math-impl-simd-non-facade-simd-use:nextpas.core.simd.dispatch"},
        ),
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.impl.simd.pas"
        path.parent.mkdir(parents=True, exist_ok=True)

        for case_name, text, expected_rules in cases:
            path.write_text(text, encoding="utf-8")
            findings = scan_math_impl_simd_facade_only_uses(root)
            rules = {finding.rule for finding in findings}
            if rules != expected_rules:
                raise AssertionError(
                    "math-impl-simd-facade-only-uses self-test "
                    + case_name
                    + " expected "
                    + ", ".join(sorted(expected_rules))
                    + " got "
                    + ", ".join(sorted(rules))
                )


def run_math_impl_simd_public_seam_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / MATH_IMPL_SIMD_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.impl.simd;\n"
            "interface\n"
            "uses\n"
            "  nextpas.core.simd,\n"
            "  nextpas.core.math.vec;\n"
            "function SimdVec4fNormalize(const AValue: TVec4f): TVec4f;\n"
            "function SimdRawAdd(const AA, AB: TVecF32x4): TVecF32x4;\n"
            "implementation\n"
            "uses nextpas.core.simd;\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_math_impl_simd_public_seam(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "math-impl-simd-public-simd-interface-use:nextpas.core.simd",
            "math-impl-simd-unplanned-public-routine:SimdVec4fNormalize",
            "math-impl-simd-public-simd-type-leak",
        }
        if not expected_rules.issubset(rules):
            raise AssertionError(
                "math-impl-simd-public-seam self-test expected "
                + ", ".join(sorted(expected_rules))
                + " got "
                + ", ".join(sorted(rules))
            )

        path.write_text(
            "unit nextpas.core.math.impl.simd;\n"
            "interface\n"
            "uses\n"
            "  nextpas.core.math.mat,\n"
            "  nextpas.core.math.quat,\n"
            "  nextpas.core.math.vec;\n"
            "function SimdVec4fAdd(const AA, AB: TVec4f): TVec4f;\n"
            "function SimdVec4fSub(const AA, AB: TVec4f): TVec4f;\n"
            "function SimdVec4fMulComponents(const AA, AB: TVec4f): TVec4f;\n"
            "function SimdVec4fScale(const AValue: TVec4f; const AScalar: Single): TVec4f;\n"
            "function SimdVec4fDot(const AA, AB: TVec4f): Single;\n"
            "function SimdVec4fLength(const AValue: TVec4f): Single;\n"
            "function SimdVec3fDot(const AA, AB: TVec3f): Single;\n"
            "function SimdVec3fCross(const AA, AB: TVec3f): TVec3f;\n"
            "function SimdMat4fMulVec4f(const AMatrix: TMat4f; const AVector: TVec4f): TVec4f;\n"
            "function SimdQuatfRotate(const AQuat: TQuatf; const AVector: TVec3f): TVec3f;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_math_impl_simd_public_seam(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        if findings:
            raise AssertionError(
                "math-impl-simd-public-seam self-test expected no findings"
            )


def run_forbidden_simd_mathutil_bare_name_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / SIMD_MATHUTIL_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.simd.mathutil;\n"
            "interface\n"
            "function InverseLerp(const AMin, AMax, AValue: Single): Single;\n"
            "function Wrap(const AValue, AMin, AMax: Single): Single;\n"
            "function DegToRad(const ADegrees: Single): Single;\n"
            "function RadToDeg(const ARadians: Single): Single;\n"
            "function RoundToEvenF32(AX: Single): Single;\n"
            "function SimdInverseLerpF32(const AMin, AMax, AValue: Single): Single;\n"
            "function SimdWrapF32(const AValue, AMin, AMax: Single): Single;\n"
            "function SimdDegToRadF32(const ADegrees: Single): Single;\n"
            "function SimdRadToDegF32(const ARadians: Single): Single;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_forbidden_simd_mathutil_bare_names(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = [finding.rule for finding in findings]
        if rules != ["no-bare-public-math-name-in-simd-mathutil"] * 5:
            raise AssertionError(
                "forbidden-simd-mathutil-bare-name self-test expected five bare-name findings"
            )


def run_forbidden_native_math_linking_scope_self_tests() -> None:
    cases = (
        (
            "test-external-m",
            "tests/nextpas.core.math/test_native/test_native.lpr",
            "program test_native;\n"
            "function HostSin(AX: Double): Double; cdecl; external 'm' name 'sin';\n"
            "begin\n"
            "end.\n",
            "no-naked-external-m",
        ),
        (
            "example-external-m",
            "examples/nextpas.core.math/example_native/example_native.lpr",
            "program example_native;\n"
            "function HostCos(AX: Double): Double; cdecl; external 'm' name 'cos';\n"
            "begin\n"
            "end.\n",
            "no-naked-external-m",
        ),
        (
            "benchmark-external-m",
            "benchmarks/nextpas.core.math/bench_native/bench_native.lpr",
            "program bench_native;\n"
            "function HostTan(AX: Double): Double; cdecl; external 'm' name 'tan';\n"
            "begin\n"
            "end.\n",
            "no-naked-external-m",
        ),
        (
            "source-brace-linklib-m",
            "src/nextpas.core.math.native_link.pas",
            "unit nextpas.core.math.native_link;\n"
            "interface\n"
            "{$linklib m}\n"
            "implementation\n"
            "end.\n",
            "no-native-math-linklib",
        ),
        (
            "source-paren-star-linklib-m",
            "src/nextpas.core.math.native_link_paren_star.pas",
            "unit nextpas.core.math.native_link_paren_star;\n"
            "interface\n"
            "(*$linklib m*)\n"
            "implementation\n"
            "end.\n",
            "no-native-math-linklib",
        ),
        (
            "test-makefile-lm",
            "tests/nextpas.core.math/test_native/Makefile",
            "FPCFLAGS += -lm\n",
            "no-native-math-link-flag",
        ),
        (
            "example-makefile-lm",
            "examples/nextpas.core.math/example_native/Makefile",
            "FPCFLAGS += -lm\n",
            "no-native-math-link-flag",
        ),
        (
            "benchmark-makefile-lm",
            "benchmarks/nextpas.core.math/bench_native/Makefile",
            "FPCFLAGS += -lm\n",
            "no-native-math-link-flag",
        ),
        (
            "root-makefile-klm",
            "Makefile",
            "core-math-native:\n"
            "\tfpc -k-lm test_native.lpr\n",
            "no-native-math-link-flag",
        ),
    )
    negative_cases = (
        (
            "commented-source-linklib-m",
            "src/nextpas.core.math.native_link_comment.inc",
            "// {$linklib m}\n"
        ),
        (
            "string-source-linklib-m",
            "src/nextpas.core.math.native_link_string.pas",
            "unit nextpas.core.math.native_link_string;\n"
            "interface\n"
            "const LinkText = '{$linklib m}';\n"
            "implementation\n"
            "end.\n",
        ),
        (
            "commented-test-makefile-lm",
            "tests/nextpas.core.math/test_native_comment/Makefile",
            "# FPCFLAGS += -lm\n",
        ),
        (
            "inline-commented-test-makefile-lm",
            "tests/nextpas.core.math/test_native_inline_comment/Makefile",
            "FPCFLAGS += -O2 # -lm is forbidden when active\n",
        ),
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        for _case_name, rel, text, _expected_rule in cases:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        for _case_name, rel, text in negative_cases:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

        report = build_report(root)
        for case_name, rel, _text, expected_rule in cases:
            if not any(
                finding.path == rel and finding.rule == expected_rule
                for finding in report.findings
            ):
                raise AssertionError(
                    "forbidden-native-math-linking self-test "
                    + case_name
                    + " expected "
                    + expected_rule
                )
        for case_name, rel, _text in negative_cases:
            rules = [
                finding.rule
                for finding in report.findings
                if finding.path == rel and finding.rule in NATIVE_MATH_LINKING_RULES
            ]
            if rules:
                raise AssertionError(
                    "forbidden-native-math-linking self-test "
                    + case_name
                    + " expected no findings, got "
                    + ", ".join(rules)
                )


def run_legacy_production_name_self_tests() -> None:
    cases = (
        (
            "interface-public-legacy-name",
            "unit nextpas.core.math.mat;\n"
            "interface\n"
            "type\n"
            "  TMatrix4f = record end;\n"
            "implementation\n"
            "end.\n",
            {"no-legacy-public-vector-api", "no-legacy-production-math-symbol"},
        ),
        (
            "interface-public-legacy-name-lowercase",
            "unit nextpas.core.math.mat;\n"
            "interface\n"
            "type\n"
            "  tmatrix4f = record end;\n"
            "implementation\n"
            "end.\n",
            {"no-legacy-public-vector-api", "no-legacy-production-math-symbol"},
        ),
        (
            "implementation-legacy-name",
            "unit nextpas.core.math.mat;\n"
            "interface\n"
            "implementation\n"
            "type\n"
            "  TMatrix4Work = array[0..3, 0..3] of Double;\n"
            "end.\n",
            {"no-legacy-production-math-symbol"},
        ),
        (
            "comment-and-string-only",
            "unit nextpas.core.math.mat;\n"
            "interface\n"
            "const Msg = 'TMatrix4Work';\n"
            "// TMatrix4Work\n"
            "{ TVector3f }\n"
            "implementation\n"
            "(* TQuaterniond *)\n"
            "end.\n",
            set(),
        ),
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.mat.pas"
        path.parent.mkdir(parents=True, exist_ok=True)

        for case_name, text, expected_rules in cases:
            path.write_text(text, encoding="utf-8")
            findings = scan_legacy_public_names(
                root,
                path,
                text,
            ) + scan_legacy_production_names(root, path, text)
            rules = {finding.rule for finding in findings}
            if rules != expected_rules:
                raise AssertionError(
                    "legacy-production-name self-test "
                    + case_name
                    + " expected "
                    + ",".join(sorted(expected_rules))
                    + " got "
                    + ",".join(sorted(rules))
                )

        consumer_path = root / "tests/nextpas.core.math/test_legacy_consumer/test_legacy_consumer.lpr"
        consumer_path.parent.mkdir(parents=True, exist_ok=True)
        consumer_path.write_text(
            "program test_legacy_consumer;\n"
            "{$mode objfpc}{$H+}\n"
            "type\n"
            "  TLocal = tmatrix4f;\n"
            "begin\n"
            "end.\n",
            encoding="utf-8",
        )
        report = build_report(root)
        consumer_rules = {
            finding.rule
            for finding in report.findings
            if finding.path == relative(consumer_path, root)
        }
        expected_consumer_rules = {
            "no-legacy-public-vector-api",
            "no-legacy-production-math-symbol",
        }
        if consumer_rules != expected_consumer_rules:
            raise AssertionError(
                "legacy-production-name self-test consumer-legacy-name expected "
                + ",".join(sorted(expected_consumer_rules))
                + " got "
                + ",".join(sorted(consumer_rules))
            )


def run_legacy_public_doc_symbol_self_tests() -> None:
    cases = (
        (
            "legacy-record-name",
            "docs/math/README.md",
            "Use TVector3f and TMatrix2f in public docs.\n",
        ),
        (
            "legacy-uses-vectors",
            "docs/math/API.md",
            "```pascal\nuses SysUtils, Vectors;\n```\n",
        ),
        (
            "legacy-source-path",
            "docs/math/API.md",
            "Legacy source path: src/math/Vectors.pas\n",
        ),
    )
    negative_cases = (
        (
            "plain-english-section",
            "docs/math/API.md",
            "## Vectors, matrices, and quaternions\n"
            "The Vector and Quaternion sections document the final API.\n",
        ),
    )
    expected_rule = "no-legacy-public-doc-vector-api"

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        for case_name, rel, text in cases:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            report = build_report(root)
            if not any(
                finding.path == rel and finding.rule == expected_rule
                for finding in report.findings
            ):
                raise AssertionError(
                    "legacy-public-doc-symbol self-test "
                    + case_name
                    + " expected "
                    + expected_rule
                )
        for case_name, rel, text in negative_cases:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            report = build_report(root)
            rules = {
                finding.rule
                for finding in report.findings
                if finding.path == rel
            }
            if expected_rule in rules:
                raise AssertionError(
                    "legacy-public-doc-symbol self-test "
                    + case_name
                    + " expected no "
                    + expected_rule
                )


def run_forbidden_trig_scalar_name_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / "src/nextpas.core.math.trig.pas"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "const\n"
            "  DEG_TO_RAD: Double = 0.01745329251994329577;\n"
            "function DegToRad(const ADeg: Double): Double; overload; inline;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_forbidden_trig_scalar_names(
            root,
            path,
            path.read_text(encoding="utf-8"),
        )
        rules = [finding.rule for finding in findings]
        if rules != ["no-scalar-api-in-math-trig", "no-scalar-api-in-math-trig"]:
            raise AssertionError(
                "forbidden-trig-scalar-name self-test expected const and function findings"
            )


def run_trig_host_safe_route_self_tests() -> None:
    cases = (
        (
            "active-trig-uses-fpc-math",
            "src/nextpas.core.math.trig.pas",
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "implementation\n"
            "uses Math;\n"
            "end.\n",
            True,
        ),
        (
            "line-comment",
            "src/nextpas.core.math.trig.pas",
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "implementation\n"
            "// uses Math;\n"
            "end.\n",
            False,
        ),
        (
            "brace-comment",
            "src/nextpas.core.math.trig.pas",
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "implementation\n"
            "{ uses Math; }\n"
            "end.\n",
            False,
        ),
        (
            "paren-star-comment",
            "src/nextpas.core.math.trig.pas",
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "implementation\n"
            "(* uses Math; *)\n"
            "end.\n",
            False,
        ),
        (
            "string-literal",
            "src/nextpas.core.math.trig.pas",
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "const Msg = 'Math';\n"
            "implementation\n"
            "end.\n",
            False,
        ),
        (
            "easing-uses-fpc-math",
            "src/nextpas.core.math.easing.pas",
            "unit nextpas.core.math.easing;\n"
            "interface\n"
            "implementation\n"
            "uses Math;\n"
            "end.\n",
            False,
        ),
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        expected_rule = "no-fpc-math-unit-in-trig"

        for case_name, rel, text, expected_finding in cases:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            findings = scan_forbidden_fpc_math_unit_in_trig(root, path, text)
            rules = {finding.rule for finding in findings}
            if expected_finding and expected_rule not in rules:
                raise AssertionError(
                    "trig-host-safe-route self-test "
                    + case_name
                    + " expected "
                    + expected_rule
                )
            if (not expected_finding) and findings:
                raise AssertionError(
                    "trig-host-safe-route self-test "
                    + case_name
                    + " expected no findings"
                )


def run_trig_log_exact_identity_source_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / MATH_TRIG_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "unit nextpas.core.math.trig;\n"
            "implementation\n"
            "function Log2(const AX: Double): Double;\n"
            "begin\n"
            "  Result := Ln(AX) / 0.69314718055994530942;\n"
            "end;\n"
            "function Log10(const AX: Double): Double;\n"
            "begin\n"
            "  Result := Ln(AX) / 2.30258509299404568402;\n"
            "end;\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_trig_log_exact_identity_source_contract(
            root, path, path.read_text(encoding="utf-8")
        )
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "missing-required-trig-log-exact-identity-source-contract:log2-one",
            "missing-required-trig-log-exact-identity-source-contract:log2-base",
            "missing-required-trig-log-exact-identity-source-contract:log10-one",
            "missing-required-trig-log-exact-identity-source-contract:log10-base",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "trig-log-exact-identity-source-contract self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        path.write_text(
            "unit nextpas.core.math.trig;\n"
            "implementation\n"
            "function Log2(const AX: Double): Double;\n"
            "begin\n"
            "  if AX = 1.0 then Exit(0.0);\n"
            "  if AX = 2.0 then Exit(1.0);\n"
            "  Result := Ln(AX) / 0.69314718055994530942;\n"
            "end;\n"
            "function Log10(const AX: Double): Double;\n"
            "begin\n"
            "  if AX = 1.0 then Exit(0.0);\n"
            "  if AX = 10.0 then Exit(1.0);\n"
            "  Result := Ln(AX) / 2.30258509299404568402;\n"
            "end;\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_trig_log_exact_identity_source_contract(
            root, path, path.read_text(encoding="utf-8")
        )
        if findings:
            raise AssertionError(
                "trig-log-exact-identity-source-contract self-test expected no findings"
            )


def run_required_trig_host_compile_gate_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        makefile = root / TRIG_HOST_COMPILE_GATE_MAKEFILE_PATH
        source = root / TRIG_HOST_COMPILE_GATE_SOURCE_PATH
        makefile.parent.mkdir(parents=True, exist_ok=True)
        source.parent.mkdir(parents=True, exist_ok=True)
        makefile.write_text(
            "FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Cn -Twin64 -Px86_64\n",
            encoding="utf-8",
        )
        source.write_text(
            "program test_trig_host_compile_gate;\n"
            "uses\n"
            "  nextpas.core.math.trig;\n"
            "begin\n"
            "  if Sin(0.0) + Cos(0.0) + Tan(0.0) + ArcSin(0.0) + ArcCos(1.0) +\n"
            "    ArcTan(1.0) + ArcTan2(1.0, 1.0) + Exp(0.0) + Ln(1.0) +\n"
            "    Log2(2.0) + Log10(10.0) + Power(2.0, 3.0) + Sqrt(4.0) +\n"
            "    Sin(Single(0.0)) + Cos(Single(0.0)) + Tan(Single(0.0)) +\n"
            "    ArcSin(Single(0.0)) + ArcCos(Single(1.0)) + ArcTan(Single(1.0)) +\n"
            "    ArcTan2(Single(1.0), Single(1.0)) + Exp(Single(0.0)) + Ln(Single(1.0)) +\n"
            "    Log2(Single(2.0)) + Log10(Single(10.0)) + Power(Single(2.0), Single(3.0)) +\n"
            "    Sqrt(Single(4.0)) = 0.0 then\n"
            "    Halt(1);\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_required_trig_host_compile_gate(root)
        rules = {finding.rule for finding in findings}
        expected_rule = (
            "missing-required-trig-host-compile-gate-marker:facade-import"
        )
        if expected_rule not in rules:
            raise AssertionError(
                "trig-host-compile-gate self-test expected " + expected_rule
            )
        expected_rule = (
            "missing-required-trig-host-compile-gate-marker:"
            "facade-sin-double-binding"
        )
        if expected_rule not in rules:
            raise AssertionError(
                "trig-host-compile-gate self-test expected " + expected_rule
            )

        binding_lines = "".join(
            "  " + marker + ";\n"
            for _, marker in required_trig_host_compile_gate_binding_markers()
        )
        source.write_text(
            "program test_trig_host_compile_gate;\n"
            "uses\n"
            "  nextpas.core.math,\n"
            "  nextpas.core.math.trig;\n"
            "\n"
            "type\n"
            "  TUnarySingle = function(const AX: Single): Single;\n"
            "  TUnaryDouble = function(const AX: Double): Double;\n"
            "  TBinarySingle = function(const AX, AY: Single): Single;\n"
            "  TBinaryDouble = function(const AX, AY: Double): Double;\n"
            "\n"
            "procedure RequireUnarySingle(const AValue: TUnarySingle);\n"
            "begin\n"
            "  if not Assigned(AValue) then Halt(1);\n"
            "end;\n"
            "\n"
            "procedure RequireUnaryDouble(const AValue: TUnaryDouble);\n"
            "begin\n"
            "  if not Assigned(AValue) then Halt(1);\n"
            "end;\n"
            "\n"
            "procedure RequireBinarySingle(const AValue: TBinarySingle);\n"
            "begin\n"
            "  if not Assigned(AValue) then Halt(1);\n"
            "end;\n"
            "\n"
            "procedure RequireBinaryDouble(const AValue: TBinaryDouble);\n"
            "begin\n"
            "  if not Assigned(AValue) then Halt(1);\n"
            "end;\n"
            "\n"
            "begin\n"
            + binding_lines +
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_required_trig_host_compile_gate(root)
        if findings:
            raise AssertionError(
                "trig-host-compile-gate self-test expected no findings"
            )


def run_required_impl_simd_win64_compile_gate_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        makefile = root / IMPL_SIMD_WIN64_COMPILE_GATE_MAKEFILE_PATH
        source = root / IMPL_SIMD_WIN64_COMPILE_GATE_SOURCE_PATH
        makefile.parent.mkdir(parents=True, exist_ok=True)
        source.parent.mkdir(parents=True, exist_ok=True)
        makefile.write_text(
            "FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Cn -Twin64 -Px86_64\n",
            encoding="utf-8",
        )
        source.write_text(
            "program test_impl_simd_win64_compile_gate;\n"
            "uses\n"
            "  nextpas.core.math,\n"
            "  nextpas.core.math.mat,\n"
            "  nextpas.core.math.quat,\n"
            "  nextpas.core.math.vec;\n"
            "begin\n"
            "  Halt(Ord(SimdVec4fDot(TVec4f.Zero, TVec4f.Zero) <> 0.0));\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_required_impl_simd_win64_compile_gate(root)
        rules = {finding.rule for finding in findings}
        expected_rule = (
            "missing-required-impl-simd-win64-compile-gate-marker:impl-simd-import"
        )
        if expected_rule not in rules:
            raise AssertionError(
                "impl-simd-win64-compile-gate self-test expected " + expected_rule
            )

        source.write_text(
            "program test_impl_simd_win64_compile_gate;\n"
            "uses\n"
            "  nextpas.core.math,\n"
            "  nextpas.core.math.mat,\n"
            "  nextpas.core.math.quat,\n"
            "  nextpas.core.math.vec,\n"
            "  nextpas.core.math.impl.simd;\n"
            "var\n"
            "  V3: TVec3f;\n"
            "  V4: TVec4f;\n"
            "  M: TMat4f;\n"
            "  Q: TQuatf;\n"
            "begin\n"
            "  V3 := TVec3f.Create(1.0, 2.0, 3.0);\n"
            "  V4 := TVec4f.Create(1.0, 2.0, 3.0, 4.0);\n"
            "  M := TMat4f.Identity;\n"
            "  Q := TQuatf.Identity;\n"
            "  V4 := SimdVec4fAdd(V4, SimdVec4fSub(V4, V4));\n"
            "  V4 := SimdVec4fMulComponents(V4, SimdVec4fScale(V4, 1.0));\n"
            "  V4 := SimdMat4fMulVec4f(M, V4);\n"
            "  V3 := SimdVec3fCross(V3, SimdQuatfRotate(Q, V3));\n"
            "  if SimdVec4fDot(V4, V4) + SimdVec4fLength(V4) + SimdVec3fDot(V3, V3) < 0.0 then\n"
            "    Halt(1);\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_required_impl_simd_win64_compile_gate(root)
        if findings:
            raise AssertionError(
                "impl-simd-win64-compile-gate self-test expected no findings"
            )


def run_required_doc_truth_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        requirement = (("docs/math/README.md", "Current scalar truth."),)
        expected_rule = "missing-required-selftest-doc-truth"

        findings = scan_required_doc_truth(root, requirement, expected_rule)
        rules = {finding.rule for finding in findings}
        if expected_rule not in rules:
            raise AssertionError(
                "required-doc-truth self-test missing-file expected "
                + expected_rule
            )


def run_control_doc_compaction_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        for rel, marker in REQUIRED_CONTROL_DOC_MARKERS:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            existing = path.read_text(encoding="utf-8") if path.exists() else ""
            path.write_text(existing + marker + "\n", encoding="utf-8")
        for rel in CONTROL_DOC_LINE_LIMITS:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists():
                path.write_text("compact\n", encoding="utf-8")

        oversized = root / "docs/math/README.md"
        marker_text = oversized.read_text(encoding="utf-8")
        oversized.write_text(
            marker_text
            + "\n".join("line" for _ in range(CONTROL_DOC_LINE_LIMITS["docs/math/README.md"] + 1))
            + "\n",
            encoding="utf-8",
        )
        findings = scan_control_doc_compaction(root)
        if not any(
            finding.rule == "control-doc-too-large:docs/math/README.md"
            for finding in findings
        ):
            raise AssertionError(
                "control-doc-compaction self-test expected README size finding"
            )

        oversized.write_text(marker_text, encoding="utf-8")
        findings = scan_control_doc_compaction(root)
        if findings:
            raise AssertionError(
                "control-doc-compaction self-test expected no findings, got "
                + ", ".join(sorted(finding.rule for finding in findings))
            )


def root_facade_public_names(text: str) -> list[str]:
    code = interface_text(text)
    names: set[str] = set()
    names.update(PUBLIC_CONSTANT_RE.findall(code))
    names.update(PUBLIC_TYPE_ALIAS_RE.findall(code))
    names.update(PUBLIC_FUNCTION_RE.findall(code))
    return sorted(names)


def scan_root_facade_api_doc_coverage(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    root_facade = root / ROOT_FACADE_PATH
    api_doc = root / API_DOC_PATH
    if not root_facade.is_file() or not api_doc.is_file():
        return findings

    root_names = root_facade_public_names(
        root_facade.read_text(encoding="utf-8", errors="replace")
    )
    api_text = api_doc.read_text(encoding="utf-8", errors="replace")
    for name in root_names:
        if name in api_text:
            continue
        add_finding(
            findings,
            "api-doc-missing-root-facade-name:" + name,
            root,
            api_doc,
            1,
            "missing API.md entry for " + name,
        )
    return findings


def normalize_pascal_type(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip()).lower()


def statement_line_index(code: str, statement_start: int) -> int:
    return code.count("\n", 0, statement_start) + 1


def interface_statements(text: str) -> list[tuple[int, str]]:
    code, line_offset = interface_body_text_with_line_offset(text)
    statements: list[tuple[int, str]] = []
    start = 0
    for match in re.finditer(r";", code):
        statement = code[start : match.end()]
        statements.append((line_offset + statement_line_index(code, start), statement))
        start = match.end()
    return statements


def is_top_level_statement(statement: str) -> bool:
    lines = [line for line in statement.splitlines() if line.strip()]
    if not lines:
        return False
    indent = len(lines[0]) - len(lines[0].lstrip(" "))
    return indent <= 2


def public_unit_name(text: str) -> str:
    match = UNIT_NAME_RE.search(text)
    if match is None:
        return ""
    return match.group("name")


def split_pascal_params(params: str) -> tuple[tuple[str, str], ...]:
    normalized_params: list[tuple[str, str]] = []
    for group in params.split(";"):
        group = group.strip()
        if not group:
            continue
        modifier = ""
        for candidate in ("const", "var", "out"):
            prefix = candidate + " "
            if group.lower().startswith(prefix):
                modifier = candidate
                group = group[len(prefix) :].strip()
                break
        if ":" not in group:
            continue
        names_part, type_part = group.rsplit(":", 1)
        type_name = normalize_pascal_type(type_part.split("=", 1)[0])
        param_count = len([name for name in names_part.split(",") if name.strip()])
        for _ in range(param_count):
            normalized_params.append((modifier, type_name))
    return tuple(normalized_params)


def parse_public_routine_statement(unit_name: str, line: int, statement: str) -> PublicRoutineSignature | None:
    if not is_top_level_statement(statement):
        return None
    normalized = " ".join(statement.split())
    match = re.match(
        r"^(function|procedure)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((?P<params>.*?)\)"
        r"(?:\s*:\s*(?P<result>[^;]+?))?\s*(?:;\s*.*)?;$",
        normalized,
        re.IGNORECASE,
    )
    if match is None:
        return None
    result_type = normalize_pascal_type(match.group("result") or "")
    return PublicRoutineSignature(
        unit_name=unit_name,
        name=match.group(2),
        routine_kind=match.group(1),
        params=split_pascal_params(match.group("params")),
        result_type=result_type,
        line=line,
    )


def parse_public_type_alias_statement(unit_name: str, line: int, statement: str) -> PublicTypeAlias | None:
    if not is_top_level_statement(statement):
        return None
    normalized = " ".join(statement.split())
    normalized = re.sub(r"^(?:type)\s+", "", normalized, flags=re.IGNORECASE)
    match = re.match(
        r"^(T[A-Za-z0-9_]*)\s*=\s*(?P<target>.+?)\s*;$",
        normalized,
        re.IGNORECASE,
    )
    if match is None:
        return None
    return PublicTypeAlias(
        unit_name=unit_name,
        name=match.group(1),
        target=normalize_pascal_type(match.group("target")),
        line=line,
    )


def parse_public_constant_statement(unit_name: str, line: int, statement: str) -> PublicConstant | None:
    if not is_top_level_statement(statement):
        return None
    normalized = " ".join(statement.split())
    normalized = re.sub(r"^(?:const)\s+", "", normalized, flags=re.IGNORECASE)
    match = re.match(
        r"^([A-Z][A-Z0-9_]*)\s*:\s*(?P<type>[^=;]+)\s*=",
        normalized,
    )
    if match is None:
        return None
    return PublicConstant(
        unit_name=unit_name,
        name=match.group(1),
        type_name=normalize_pascal_type(match.group("type")),
        line=line,
    )


def extract_public_routines(text: str) -> list[PublicRoutineSignature]:
    unit_name = public_unit_name(text)
    routines: list[PublicRoutineSignature] = []
    for line, statement in interface_statements(text):
        routine = parse_public_routine_statement(unit_name, line, statement)
        if routine is not None:
            routines.append(routine)
    return routines


def extract_public_type_aliases(text: str) -> list[PublicTypeAlias]:
    unit_name = public_unit_name(text)
    aliases: list[PublicTypeAlias] = []
    for line, statement in interface_statements(text):
        alias = parse_public_type_alias_statement(unit_name, line, statement)
        if alias is not None:
            aliases.append(alias)
    return aliases


def extract_public_constants(text: str) -> list[PublicConstant]:
    unit_name = public_unit_name(text)
    constants: list[PublicConstant] = []
    for line, statement in interface_statements(text):
        constant = parse_public_constant_statement(unit_name, line, statement)
        if constant is not None:
            constants.append(constant)
    return constants


def root_facade_alias_targets(root_facade_text: str) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for alias in extract_public_type_aliases(root_facade_text):
        aliases[alias.name.lower()] = alias.target
    return aliases


def root_facade_constants(root_facade_text: str) -> dict[str, str]:
    constants: dict[str, str] = {}
    for constant in extract_public_constants(root_facade_text):
        constants[constant.name.lower()] = constant.type_name
    return constants


def root_facade_routines(root_facade_text: str) -> set[tuple[str, str, tuple[tuple[str, str], ...], str]]:
    return {routine.key for routine in extract_public_routines(root_facade_text)}


def scan_root_facade_reexport_parity(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    root_facade_path = root / ROOT_FACADE_PATH
    if not root_facade_path.is_file():
        return findings

    root_facade_text = root_facade_path.read_text(encoding="utf-8", errors="replace")
    root_aliases = root_facade_alias_targets(root_facade_text)
    root_constants = root_facade_constants(root_facade_text)
    root_routines = root_facade_routines(root_facade_text)

    for rel in sorted(PUBLIC_MATH_SOURCE_PATHS):
        if rel == ROOT_FACADE_PATH:
            continue
        path = root / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        unit_name = public_unit_name(text)
        if not unit_name:
            continue

        for alias in extract_public_type_aliases(text):
            expected_target = normalize_pascal_type(unit_name + "." + alias.name)
            actual_target = root_aliases.get(alias.name.lower())
            if actual_target == expected_target:
                continue
            rule = "missing-root-facade-type-reexport"
            if actual_target is not None:
                rule = "wrong-root-facade-type-reexport"
            add_finding(
                findings,
                f"{rule}:{unit_name}:{alias.name}",
                root,
                path,
                alias.line,
                alias.name,
            )

        for constant in extract_public_constants(text):
            actual_type = root_constants.get(constant.name.lower())
            if actual_type == constant.type_name:
                continue
            add_finding(
                findings,
                f"missing-root-facade-const-reexport:{unit_name}:{constant.name}",
                root,
                path,
                constant.line,
                constant.name,
            )

        for routine in extract_public_routines(text):
            if routine.key in root_routines:
                continue
            add_finding(
                findings,
                f"missing-root-facade-function-reexport:{unit_name}:{routine.name}",
                root,
                path,
                routine.line,
                routine.name,
            )
    return findings


def run_root_facade_reexport_parity_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        src = root / "src"
        src.mkdir(parents=True, exist_ok=True)
        (src / "nextpas.core.math.trig.pas").write_text(
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "function Log10(const AX: Double): Double; overload; inline;\n"
            "function Log10(const AX: Single): Single; overload; inline;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        (src / "nextpas.core.math.pas").write_text(
            "unit nextpas.core.math;\n"
            "interface\n"
            "uses nextpas.core.math.trig;\n"
            "function Log10(const AX: Double): Double; overload; inline;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )

        findings = scan_root_facade_reexport_parity(root)
        rules = {finding.rule for finding in findings}
        expected_rule = (
            "missing-root-facade-function-reexport:nextpas.core.math.trig:Log10"
        )
        if expected_rule not in rules:
            raise AssertionError(
                "root-facade-reexport-parity self-test expected " + expected_rule
            )


def scan_required_core_make_targets(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / ROOT_MAKEFILE_PATH
    if not path.is_file():
        for required_target in REQUIRED_CORE_MAKE_TARGETS:
            add_finding(
                findings,
                "missing-required-core-makefile:" + required_target.target,
                root,
                path,
                1,
                ROOT_MAKEFILE_PATH,
            )
        return findings

    text = path.read_text(encoding="utf-8", errors="replace")
    for required_target in REQUIRED_CORE_MAKE_TARGETS:
        target_re = re.compile(
            rf"(?ms)^{re.escape(required_target.target)}\s*:(?P<head>[^\n]*)\n"
            r"(?P<body>(?:\t.*\n)+)"
        )
        match = target_re.search(text)
        if match is None:
            add_finding(
                findings,
                "missing-required-core-target:" + required_target.target,
                root,
                path,
                1,
                f"missing {required_target.target} target",
            )
            continue

        recipe = match.group("body")
        for step_name, required_line in required_target.recipe_steps:
            if required_line in recipe:
                continue
            add_finding(
                findings,
                "missing-required-core-step:"
                + required_target.target
                + ":"
                + step_name,
                root,
                path,
                line_no_at(text, match.start("body")),
                required_line,
            )
    return findings


def scan_required_core_make_target_doc_coverage(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / API_DOC_PATH
    if not path.is_file():
        return findings
    text = path.read_text(encoding="utf-8", errors="replace")
    for required_target in REQUIRED_CORE_MAKE_TARGETS:
        if required_target.command in text:
            continue
        add_finding(
            findings,
            "missing-required-core-doc-command:" + required_target.target,
            root,
            path,
            1,
            "missing documented command " + required_target.command,
        )
    return findings


def scan_compile_only_gate_aggregate_exclusions(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for rel, scope, gates in COMPILE_ONLY_GATE_AGGREGATE_EXCLUSIONS:
        path = root / rel
        if not path.is_file():
            add_finding(
                findings,
                "missing-required-compile-only-gate-exclusion-file:" + scope,
                root,
                path,
                1,
                rel,
            )
            continue

        text = path.read_text(encoding="utf-8", errors="replace")
        for gate in gates:
            marker = COMPILE_ONLY_GATE_EXCLUSION_MARKER_PREFIX + gate
            marker_index = text.find(marker)
            if marker_index < 0:
                add_finding(
                    findings,
                    "missing-required-compile-only-gate-aggregate-exclusion:"
                    + scope
                    + ":"
                    + gate,
                    root,
                    path,
                    1,
                    marker,
                )
                continue

        active_text = strip_hash_makefile_comments(text)
        if rel == ROOT_MAKEFILE_PATH:
            opt_in_line = re.search(
                r"(?m)^COMPILE_ONLY_TEST_DIRS\s*:=\s*(?P<body>[^\n]*)$",
                active_text,
            )
            if opt_in_line is None:
                add_finding(
                    findings,
                    "missing-required-compile-only-gate-opt-in-list:" + scope,
                    root,
                    path,
                    1,
                    "COMPILE_ONLY_TEST_DIRS :=",
                )
                continue
            opt_in_body = opt_in_line.group("body")
            for gate in gates:
                if gate in opt_in_body:
                    continue
                add_finding(
                    findings,
                    "missing-required-compile-only-gate-opt-in-list-entry:"
                    + scope
                    + ":"
                    + gate,
                    root,
                    path,
                    line_no_at(text, opt_in_line.start()),
                    gate,
                )

            target_re = re.compile(
                r"(?ms)^test\s*:(?P<head>[^\n]*)\n(?P<body>(?:\t.*\n)+)"
            )
            target_match = target_re.search(active_text)
            if target_match is None:
                add_finding(
                    findings,
                    "missing-required-compile-only-gate-aggregate-test-target:"
                    + scope,
                    root,
                    path,
                    1,
                    "test:",
                )
                continue
            target_body = target_match.group("body")
            if "COMPILE_ONLY_TEST_DIRS" not in target_body or "continue" not in target_body:
                add_finding(
                    findings,
                    "missing-required-compile-only-gate-aggregate-skip:" + scope,
                    root,
                    path,
                    line_no_at(text, target_match.start("body")),
                    "test target must skip COMPILE_ONLY_TEST_DIRS",
                )
        else:
            project_line_match = re.search(
                r"(?m)^PROJECTS\s*:?=\s*(?P<body>[^\n]*)$",
                active_text,
            )
            project_body = (
                project_line_match.group("body") if project_line_match is not None else ""
            )
            for gate in gates:
                if gate not in project_body:
                    continue
                add_finding(
                    findings,
                    "compile-only-gate-leaks-into-aggregate:" + scope + ":" + gate,
                    root,
                    path,
                    line_no_at(text, project_line_match.start()),
                    gate,
                )
    return findings


def run_compile_only_gate_aggregate_exclusion_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        core_makefile = root / ROOT_MAKEFILE_PATH
        math_makefile = root / MATH_SUITE_MAKEFILE_PATH
        math_makefile.parent.mkdir(parents=True, exist_ok=True)

        core_makefile.write_text(
            "test:\n"
            "\tfind tests -mindepth 2 -name Makefile\n",
            encoding="utf-8",
        )
        math_makefile.write_text(
            "PROJECTS := test_api_surface test_trig_host_compile_gate\n",
            encoding="utf-8",
        )
        findings = scan_compile_only_gate_aggregate_exclusions(root)
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "missing-required-compile-only-gate-aggregate-exclusion:"
            "test-aggregate:tests/nextpas.core.math/test_trig_host_compile_gate",
            "missing-required-compile-only-gate-aggregate-exclusion:"
            "math-full-local:test_trig_host_compile_gate",
            "missing-required-compile-only-gate-opt-in-list:test-aggregate",
            "compile-only-gate-leaks-into-aggregate:"
            "math-full-local:test_trig_host_compile_gate",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "compile-only-gate-aggregate-exclusion self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        core_makefile.write_text(
            "# compile-only opt-in gate:tests/nextpas.core.math/test_trig_host_compile_gate\n"
            "# compile-only opt-in gate:tests/nextpas.core.math/test_impl_simd_win64_compile_gate\n"
            "test:\n"
            "\tfind tests -mindepth 2 -name Makefile | grep -v test_trig_host_compile_gate\n",
            encoding="utf-8",
        )
        findings = scan_compile_only_gate_aggregate_exclusions(root)
        rules = {finding.rule for finding in findings}
        expected_leak = (
            "missing-required-compile-only-gate-opt-in-list:test-aggregate"
        )
        if expected_leak not in rules:
            raise AssertionError(
                "compile-only-gate-aggregate-exclusion self-test expected "
                + expected_leak
            )

        core_makefile.write_text(
            "# compile-only opt-in gate:tests/nextpas.core.math/test_trig_host_compile_gate\n"
            "# compile-only opt-in gate:tests/nextpas.core.math/test_impl_simd_win64_compile_gate\n"
            "COMPILE_ONLY_TEST_DIRS := tests/nextpas.core.math/test_trig_host_compile_gate tests/nextpas.core.math/test_impl_simd_win64_compile_gate\n"
            "test:\n"
            "\tfind tests -mindepth 2 -name Makefile | while read mk; do \\\n"
            "\t\tdir=$$(dirname \"$$mk\"); \\\n"
            "\t\tcase \" $(COMPILE_ONLY_TEST_DIRS) \" in *\" $$dir \"*) continue ;; esac; \\\n"
            "\tdone\n",
            encoding="utf-8",
        )
        math_makefile.write_text(
            "# compile-only opt-in gate:test_trig_host_compile_gate\n"
            "# compile-only opt-in gate:test_impl_simd_win64_compile_gate\n"
            "PROJECTS := test_api_surface test_impl_simd\n",
            encoding="utf-8",
        )
        findings = scan_compile_only_gate_aggregate_exclusions(root)
        if findings:
            raise AssertionError(
                "compile-only-gate-aggregate-exclusion self-test expected no findings"
            )


def active_uses_units(text: str) -> set[str]:
    code = strip_pascal_comments_and_strings(text)
    units: set[str] = set()
    for match in USES_MATH_FFI_RE.finditer(code):
        for unit in re.split(r"[,;\s]+", match.group("body")):
            unit = unit.strip().lower()
            if unit:
                units.add(unit)
    return units


def required_trig_host_compile_gate_binding_markers() -> list[tuple[str, str]]:
    required_markers: list[tuple[str, str]] = []
    for route_rule, route_unit in TRIG_HOST_COMPILE_GATE_ROUTES:
        for function_name in TRIG_HOST_COMPILE_GATE_UNARY_FUNCTIONS:
            rule_base = route_rule + "-" + function_name.lower()
            marker_base = route_unit + "." + function_name
            required_markers.append(
                (
                    rule_base + "-double-binding",
                    "RequireUnaryDouble(@" + marker_base + ")",
                )
            )
            required_markers.append(
                (
                    rule_base + "-single-binding",
                    "RequireUnarySingle(@" + marker_base + ")",
                )
            )
        for function_name in TRIG_HOST_COMPILE_GATE_BINARY_FUNCTIONS:
            rule_base = route_rule + "-" + function_name.lower()
            marker_base = route_unit + "." + function_name
            required_markers.append(
                (
                    rule_base + "-double-binding",
                    "RequireBinaryDouble(@" + marker_base + ")",
                )
            )
            required_markers.append(
                (
                    rule_base + "-single-binding",
                    "RequireBinarySingle(@" + marker_base + ")",
                )
            )
    return required_markers


def scan_required_trig_host_compile_gate(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    makefile = root / TRIG_HOST_COMPILE_GATE_MAKEFILE_PATH
    source = root / TRIG_HOST_COMPILE_GATE_SOURCE_PATH

    if not makefile.is_file():
        add_finding(
            findings,
            "missing-required-trig-host-compile-gate-makefile",
            root,
            makefile,
            1,
            TRIG_HOST_COMPILE_GATE_MAKEFILE_PATH,
        )
    else:
        makefile_text = makefile.read_text(encoding="utf-8", errors="replace")
        for rule, marker in (
            ("compile-only", "-Cn"),
            ("win64-target", "-Twin64"),
            ("x86_64-cpu", "-Px86_64"),
        ):
            if marker in makefile_text:
                continue
            add_finding(
                findings,
                "missing-required-trig-host-compile-gate-step:" + rule,
                root,
                makefile,
                1,
                marker,
            )

    if not source.is_file():
        add_finding(
            findings,
            "missing-required-trig-host-compile-gate-source",
            root,
            source,
            1,
            TRIG_HOST_COMPILE_GATE_SOURCE_PATH,
        )
    else:
        source_text = strip_pascal_comments_and_strings(
            source.read_text(encoding="utf-8", errors="replace")
        )
        source_units = active_uses_units(source_text)
        for rule, unit in (
            ("facade-import", "nextpas.core.math"),
            ("trig-import", "nextpas.core.math.trig"),
        ):
            if unit in source_units:
                continue
            add_finding(
                findings,
                "missing-required-trig-host-compile-gate-marker:" + rule,
                root,
                source,
                1,
                unit,
            )

        for rule, marker in required_trig_host_compile_gate_binding_markers():
            if marker in source_text:
                continue
            add_finding(
                findings,
                "missing-required-trig-host-compile-gate-marker:" + rule,
                root,
                source,
                1,
                marker,
            )
    return findings


def scan_required_impl_simd_win64_compile_gate(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    makefile = root / IMPL_SIMD_WIN64_COMPILE_GATE_MAKEFILE_PATH
    source = root / IMPL_SIMD_WIN64_COMPILE_GATE_SOURCE_PATH

    if not makefile.is_file():
        add_finding(
            findings,
            "missing-required-impl-simd-win64-compile-gate-makefile",
            root,
            makefile,
            1,
            IMPL_SIMD_WIN64_COMPILE_GATE_MAKEFILE_PATH,
        )
    else:
        makefile_text = makefile.read_text(encoding="utf-8", errors="replace")
        for rule, marker in (
            ("compile-only", "-Cn"),
            ("win64-target", "-Twin64"),
            ("x86_64-cpu", "-Px86_64"),
        ):
            if marker in makefile_text:
                continue
            add_finding(
                findings,
                "missing-required-impl-simd-win64-compile-gate-step:" + rule,
                root,
                makefile,
                1,
                marker,
            )

    if not source.is_file():
        add_finding(
            findings,
            "missing-required-impl-simd-win64-compile-gate-source",
            root,
            source,
            1,
            IMPL_SIMD_WIN64_COMPILE_GATE_SOURCE_PATH,
        )
    else:
        source_text = strip_pascal_comments_and_strings(
            source.read_text(encoding="utf-8", errors="replace")
        )
        source_units = active_uses_units(source_text)
        for rule, unit in (
            ("facade-import", "nextpas.core.math"),
            ("mat-import", "nextpas.core.math.mat"),
            ("quat-import", "nextpas.core.math.quat"),
            ("vec-import", "nextpas.core.math.vec"),
            ("impl-simd-import", "nextpas.core.math.impl.simd"),
        ):
            if unit in source_units:
                continue
            add_finding(
                findings,
                "missing-required-impl-simd-win64-compile-gate-marker:" + rule,
                root,
                source,
                1,
                unit,
            )

        required_markers = (
            ("vec4f-add-touch", "SimdVec4fAdd("),
            ("vec4f-sub-touch", "SimdVec4fSub("),
            ("vec4f-mul-components-touch", "SimdVec4fMulComponents("),
            ("vec4f-scale-touch", "SimdVec4fScale("),
            ("vec4f-dot-touch", "SimdVec4fDot("),
            ("vec4f-length-touch", "SimdVec4fLength("),
            ("vec3f-dot-touch", "SimdVec3fDot("),
            ("vec3f-cross-touch", "SimdVec3fCross("),
            ("mat4f-mul-vec4f-touch", "SimdMat4fMulVec4f("),
            ("quatf-rotate-touch", "SimdQuatfRotate("),
        )
        for rule, marker in required_markers:
            if marker in source_text:
                continue
            add_finding(
                findings,
                "missing-required-impl-simd-win64-compile-gate-marker:" + rule,
                root,
                source,
                1,
                marker,
            )
    return findings


def root_facade_active_uses(root_facade_text: str) -> set[str]:
    code = strip_pascal_comments_and_strings(root_facade_text)
    match = USES_MATH_FFI_RE.search(interface_text(code))
    if match is None:
        return set()
    units: set[str] = set()
    for unit in re.split(r"[,;\s]+", match.group("body")):
        unit = unit.strip().lower()
        if unit:
            units.add(unit)
    return units


def root_facade_constant_values(root_facade_text: str) -> dict[str, tuple[str, str]]:
    values: dict[str, tuple[str, str]] = {}
    for line, statement in interface_statements(root_facade_text):
        if not is_top_level_statement(statement):
            continue
        normalized = " ".join(statement.split())
        normalized = re.sub(r"^(?:const)\s+", "", normalized, flags=re.IGNORECASE)
        match = re.match(
            r"^([A-Z][A-Z0-9_]*)\s*:\s*(?P<type>[^=;]+)\s*=\s*(?P<value>[^;]+)\s*;$",
            normalized,
        )
        if match is None:
            continue
        values[match.group(1).lower()] = (
            normalize_pascal_type(match.group("type")),
            normalize_pascal_type(match.group("value")),
        )
    return values


def implementation_text_with_line_offset(text: str) -> tuple[str, int]:
    code = strip_pascal_comments_and_strings(text)
    match = IMPLEMENTATION_RE.search(code)
    if match is None:
        return "", 0
    return code[match.end() :], line_no_at(code, match.end()) - 1


def implementation_text(text: str) -> str:
    return implementation_text_with_line_offset(text)[0]


def active_uses_units_with_lines(text: str, line_offset: int = 0) -> list[tuple[str, int]]:
    code = strip_pascal_comments_and_strings(text)
    units: list[tuple[str, int]] = []
    for match in USES_MATH_FFI_RE.finditer(code):
        body = match.group("body")
        for unit_match in re.finditer(r"[A-Za-z_][A-Za-z0-9_.]*", body):
            units.append(
                (
                    unit_match.group(0).lower(),
                    line_offset + line_no_at(code, match.start("body") + unit_match.start()),
                )
            )
    return units


def normalize_pascal_expression(text: str) -> str:
    return re.sub(r"\s+", "", text).lower()


@dataclass(frozen=True)
class RootFacadeForwarderBody:
    name: str
    routine_kind: str
    params: tuple[tuple[str, str], ...]
    param_names: tuple[str, ...]
    result_type: str
    body: str
    line: int

    @property
    def key(self) -> tuple[str, str, tuple[tuple[str, str], ...], str]:
        return (
            self.name.lower(),
            self.routine_kind.lower(),
            self.params,
            self.result_type,
        )


def extract_root_facade_forwarder_bodies(text: str) -> dict[
    tuple[str, str, tuple[tuple[str, str], ...], str], RootFacadeForwarderBody
]:
    code = strip_pascal_comments_and_strings(text)
    impl_match = IMPLEMENTATION_RE.search(code)
    if impl_match is None:
        return {}
    impl = code[impl_match.end() :]
    body_re = re.compile(
        r"\b(?P<kind>function|procedure)\s+"
        r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*"
        r"\((?P<params>.*?)\)"
        r"(?:\s*:\s*(?P<result>[^;]+))?\s*;\s*"
        r"begin\s*(?P<body>.*?)\s*end\s*;",
        re.IGNORECASE | re.DOTALL,
    )
    bodies: dict[
        tuple[str, str, tuple[tuple[str, str], ...], str], RootFacadeForwarderBody
    ] = {}
    for match in body_re.finditer(impl):
        param_names: list[str] = []
        raw_params = match.group("params")
        for group in raw_params.split(";"):
            group = group.strip()
            if not group or ":" not in group:
                continue
            for candidate in ("const", "var", "out"):
                prefix = candidate + " "
                if group.lower().startswith(prefix):
                    group = group[len(prefix) :].strip()
                    break
            names_part = group.rsplit(":", 1)[0]
            param_names.extend(name.strip() for name in names_part.split(",") if name.strip())

        body = RootFacadeForwarderBody(
            name=match.group("name"),
            routine_kind=match.group("kind"),
            params=split_pascal_params(raw_params),
            param_names=tuple(param_names),
            result_type=normalize_pascal_type(match.group("result") or ""),
            body=match.group("body"),
            line=line_no_at(code, impl_match.end() + match.start("body")),
        )
        bodies[body.key] = body
    return bodies


def scan_root_facade_contract(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / ROOT_FACADE_PATH
    if not path.is_file():
        return findings

    text = path.read_text(encoding="utf-8", errors="replace")
    code = strip_pascal_comments_and_strings(text)

    uses_units = root_facade_active_uses(text)
    for unit in sorted(uses_units - ROOT_FACADE_ALLOWED_USES):
        line = 1
        match = re.search(r"\b" + re.escape(unit) + r"\b", code, re.IGNORECASE)
        if match is not None:
            line = line_no_at(code, match.start())
        add_finding(
            findings,
            "root-facade-disallowed-use:" + unit,
            root,
            path,
            line,
            unit,
        )
    for unit in sorted(ROOT_FACADE_ALLOWED_USES - uses_units):
        add_finding(
            findings,
            "root-facade-missing-required-use:" + unit,
            root,
            path,
            1,
            unit,
        )

    impl_text, impl_line_offset = implementation_text_with_line_offset(text)
    for unit, line in active_uses_units_with_lines(impl_text, impl_line_offset):
        add_finding(
            findings,
            "root-facade-implementation-use:" + unit,
            root,
            path,
            line,
            unit,
        )

    aliases = root_facade_alias_targets(text)
    for name, target in REQUIRED_ROOT_FACADE_TYPE_ALIASES.items():
        actual = aliases.get(name)
        if actual == target:
            continue
        add_finding(
            findings,
            "root-facade-type-alias-drift:" + name,
            root,
            path,
            1,
            target,
        )
    for name in sorted(set(aliases) - set(REQUIRED_ROOT_FACADE_TYPE_ALIASES)):
        add_finding(
            findings,
            "root-facade-extra-type-alias:" + name,
            root,
            path,
            1,
            aliases[name],
        )

    constants = root_facade_constant_values(text)
    for name, expected in REQUIRED_ROOT_FACADE_CONSTANTS.items():
        actual = constants.get(name)
        if actual == expected:
            continue
        add_finding(
            findings,
            "root-facade-constant-drift:" + name,
            root,
            path,
            1,
            expected[0] + "=" + expected[1],
        )
    for name in sorted(set(constants) - set(REQUIRED_ROOT_FACADE_CONSTANTS)):
        add_finding(
            findings,
            "root-facade-extra-constant:" + name,
            root,
            path,
            1,
            constants[name][0] + "=" + constants[name][1],
        )

    for rel, expected_constants in ROOT_FACADE_CONSTANT_PARITY_EXPECTATIONS.items():
        parity_path = root / rel
        if not parity_path.is_file():
            continue
        parity_text = parity_path.read_text(encoding="utf-8", errors="replace")
        parity_unit_name = public_unit_name(parity_text) or rel
        parity_constants = root_facade_constant_values(parity_text)
        for name, expected in expected_constants.items():
            actual = parity_constants.get(name)
            if actual == expected:
                continue
            add_finding(
                findings,
                "root-facade-constant-parity:" + parity_unit_name + ":" + name,
                root,
                parity_path,
                1,
                expected[0] + "=" + expected[1],
            )

    forwarder_bodies = extract_root_facade_forwarder_bodies(text)
    for routine in extract_public_routines(text):
        expected_owner = ROOT_FACADE_FORWARD_TARGETS.get(routine.name.lower())
        if expected_owner is None:
            add_finding(
                findings,
                "root-facade-unowned-forwarder:" + routine.name,
                root,
                path,
                routine.line,
                routine.name,
            )
            continue
        body = forwarder_bodies.get(routine.key)
        if body is None:
            add_finding(
                findings,
                "root-facade-missing-forwarder-body:" + routine.name,
                root,
                path,
                routine.line,
                routine.name,
            )
            continue

        expected_call = (
            "Result:=nextpas.core.math."
            + expected_owner
            + "."
            + routine.name
            + "("
            + ",".join(body.param_names)
            + ");"
        )
        actual_body = normalize_pascal_expression(body.body)
        if actual_body == normalize_pascal_expression(expected_call):
            continue
        add_finding(
            findings,
            "root-facade-forwarder-drift:" + routine.name,
            root,
            path,
            body.line,
            routine.name + " -> nextpas.core.math." + expected_owner,
        )
    return findings


def run_root_facade_contract_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        src = root / "src"
        src.mkdir(parents=True, exist_ok=True)
        path = src / "nextpas.core.math.pas"
        (src / "nextpas.core.math.scalar.pas").write_text(
            "unit nextpas.core.math.scalar;\n"
            "interface\n"
            "const\n"
            "  PI_VALUE: Double = 3.14159265358979323846;\n"
            "  TWO_PI: Double = 6.28318530717958647692;\n"
            "  HALF_PI: Double = 1.57079632679489661923;\n"
            "  DEG_TO_RAD: Double = 0.01745329251994329577;\n"
            "  RAD_TO_DEG: Double = 57.2957795130823208768;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        (src / "nextpas.core.math.trig.pas").write_text(
            "unit nextpas.core.math.trig;\n"
            "interface\n"
            "const\n"
            "  PI_VALUE: Double = 3.0;\n"
            "  TWO_PI: Double = 6.28318530717958647692;\n"
            "  HALF_PI: Double = 1.57079632679489661923;\n"
            "  DEG_TO_RAD: Double = 0.01745329251994329577;\n"
            "  RAD_TO_DEG: Double = 57.2957795130823208768;\n"
            "implementation\n"
            "end.\n",
            encoding="utf-8",
        )
        path.write_text(
            "unit nextpas.core.math;\n"
            "interface\n"
            "uses\n"
            "  nextpas.core.math.scalar,\n"
            "  nextpas.core.math.trig,\n"
            "  nextpas.core.math.vec,\n"
            "  nextpas.core.math.mat,\n"
            "  nextpas.core.math.quat,\n"
            "  nextpas.core.math.transform,\n"
            "  nextpas.core.math.easing,\n"
            "  nextpas.core.math.random,\n"
            "  nextpas.core.math.impl.simd;\n"
            "const\n"
            "  PI_VALUE: Double = 3.0;\n"
            "  EXTRA_CONST: Double = 1.0;\n"
            "type\n"
            "  TVec3f = nextpas.core.math.vec.TVec4f;\n"
            "  TExtraVec = nextpas.core.math.vec.TVec2f;\n"
            "function Sin(const AX: Double): Double; overload; inline;\n"
            "function Rogue(const AX: Double): Double; inline;\n"
            "implementation\n"
            "uses nextpas.core.math.impl.scalar;\n"
            "function Sin(const AX: Double): Double;\n"
            "begin\n"
            "  Result := nextpas.core.math.scalar.Sin(AX);\n"
            "end;\n"
            "function Rogue(const AX: Double): Double;\n"
            "begin\n"
            "  Result := AX + 1.0;\n"
            "end;\n"
            "end.\n",
            encoding="utf-8",
        )
        findings = scan_root_facade_contract(root)
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "root-facade-disallowed-use:nextpas.core.math.impl.simd",
            "root-facade-type-alias-drift:tvec3f",
            "root-facade-constant-drift:pi_value",
            "root-facade-forwarder-drift:Sin",
            "root-facade-extra-type-alias:textravec",
            "root-facade-extra-constant:extra_const",
            "root-facade-implementation-use:nextpas.core.math.impl.scalar",
            "root-facade-constant-parity:nextpas.core.math.trig:pi_value",
            "root-facade-unowned-forwarder:Rogue",
        }
        missing = expected_rules - rules
        if missing:
            raise AssertionError(
                "root-facade-contract self-test missing " + ", ".join(sorted(missing))
            )


def scan_required_doc_truth(
    root: Path,
    requirements: tuple[tuple[str, str], ...],
    finding_code: str,
    normalize_whitespace: bool = False,
) -> list[Finding]:
    findings: list[Finding] = []
    for rel, snippet in requirements:
        path = root / rel
        if not path.is_file():
            add_finding(
                findings,
                finding_code,
                root,
                path,
                1,
                "missing required doc " + rel,
            )
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if normalize_whitespace:
            text = " ".join(text.split())
            snippet = " ".join(snippet.split())
        if snippet in text:
            continue
        add_finding(
            findings,
            finding_code,
            root,
            path,
            1,
            snippet,
        )
    return findings


def api_doc_truth(requirements: tuple[tuple[str, str], ...]) -> tuple[tuple[str, str], ...]:
    api_requirements = tuple(
        (rel, snippet) for rel, snippet in requirements if rel == API_DOC_PATH
    )
    if not api_requirements:
        raise AssertionError("doc truth requirement group must include " + API_DOC_PATH)
    return api_requirements


def scan_control_doc_compaction(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for rel, limit in CONTROL_DOC_LINE_LIMITS.items():
        path = root / rel
        if not path.is_file():
            add_finding(
                findings,
                "missing-required-control-doc",
                root,
                path,
                1,
                rel,
            )
            continue
        line_count = len(path.read_text(encoding="utf-8", errors="replace").splitlines())
        if line_count <= limit:
            continue
        add_finding(
            findings,
            "control-doc-too-large:" + rel,
            root,
            path,
            limit + 1,
            f"{line_count} lines exceeds {limit}",
        )

    findings.extend(
        scan_required_doc_truth(
            root,
            REQUIRED_CONTROL_DOC_MARKERS,
            "missing-required-control-doc-marker",
            normalize_whitespace=True,
        )
    )
    return findings


def scan_l1_goal_tree_math_truth(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    path = root / L1_GOAL_TREE_PATH
    if not path.is_file():
        add_finding(
            findings,
            "missing-l1-goal-tree-math-truth",
            root,
            path,
            1,
            L1_GOAL_TREE_PATH,
        )
        return findings

    text = path.read_text(encoding="utf-8", errors="replace")
    if "CI: All tests passed" in text or "2500+ tests, 0 leaks" in text:
        add_finding(
            findings,
            "l1-goal-tree-forbidden-global-green-claim",
            root,
            path,
            1,
            "top-level goal tree must not claim full CI/leak truth",
        )
    if "真相口径: source-contract / focused runtime / forced compile / CI matrix" not in text:
        add_finding(
            findings,
            "l1-goal-tree-missing-truth-header",
            root,
            path,
            1,
            "真相口径: source-contract / focused runtime / forced compile / CI matrix",
        )

    lines = text.splitlines()
    for index, line in enumerate(lines, start=1):
        if re.match(r"^\|\s*`math`\s*\|", line) is None:
            continue
        if "✅ 完成" in line:
            add_finding(
                findings,
                "l1-goal-tree-math-must-not-be-complete",
                root,
                path,
                index,
                line,
            )
        if "M8 partial" not in line:
            add_finding(
                findings,
                "l1-goal-tree-math-missing-partial-marker",
                root,
                path,
                index,
                line,
            )
        if "source-contract" not in line or "CI matrix" not in line:
            add_finding(
                findings,
                "l1-goal-tree-math-missing-truth-levels",
                root,
                path,
                index,
                line,
            )
        return findings

    add_finding(
        findings,
        "l1-goal-tree-math-row-missing",
        root,
        path,
        1,
        "`math` row is required",
    )
    return findings


def run_l1_goal_tree_math_truth_self_tests() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        path = root / L1_GOAL_TREE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "# goal\n\n"
            "> 最后更新: 2026-05-31 | CI: All tests passed | 2500+ tests, 0 leaks\n\n"
            "`math` M8 partial source-contract CI matrix\n"
            "| `math` | 数学函数 | ✅ 完成 |\n",
            encoding="utf-8",
        )
        findings = scan_l1_goal_tree_math_truth(root)
        rules = {finding.rule for finding in findings}
        expected_rules = {
            "l1-goal-tree-forbidden-global-green-claim",
            "l1-goal-tree-missing-truth-header",
            "l1-goal-tree-math-must-not-be-complete",
            "l1-goal-tree-math-missing-partial-marker",
            "l1-goal-tree-math-missing-truth-levels",
        }
        if not expected_rules <= rules:
            raise AssertionError(
                "l1-goal-tree-math-truth self-test missing "
                + ", ".join(sorted(expected_rules - rules))
            )

        path.write_text(
            "# goal\n\n"
            "> 最后更新: 2026-06-09 | 真相口径: source-contract / focused runtime / forced compile / CI matrix\n\n"
            "| `math` | 数学函数 | 🔶 M8 partial: source-contract + Linux focused runtime/heaptrc; Win64 forced compile; macOS/Windows host runtime and CI matrix pending |\n",
            encoding="utf-8",
        )
        findings = scan_l1_goal_tree_math_truth(root)
        if findings:
            raise AssertionError(
                "l1-goal-tree-math-truth self-test expected no findings, got "
                + ", ".join(sorted(finding.rule for finding in findings))
            )


def scan_required_host_gate_residual_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_HOST_GATE_RESIDUAL_TRUTH),
        "missing-required-host-gate-truth",
    )


def scan_required_m8_residual_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_M8_RESIDUAL_TRUTH),
        "missing-required-m8-truth",
    )


def scan_required_simd_seam_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SIMD_SEAM_DOC_TRUTH),
        "missing-required-simd-seam-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_facade_only_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_FACADE_ONLY_DOC_TRUTH),
        "missing-required-facade-only-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_transform_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_TRANSFORM_DOC_TRUTH),
        "missing-required-transform-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_mat_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_MAT_DOC_TRUTH),
        "missing-required-mat-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_quat_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_QUAT_DOC_TRUTH),
        "missing-required-quat-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_vec_quat_stable_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_VEC_QUAT_STABLE_DOC_TRUTH),
        "missing-required-vec-quat-stable-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_random_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_RANDOM_DOC_TRUTH),
        "missing-required-random-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_easing_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_EASING_DOC_TRUTH),
        "missing-required-easing-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_noise_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_NOISE_DOC_TRUTH),
        "missing-required-noise-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_clamp_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_CLAMP_DOC_TRUTH),
        "missing-required-scalar-clamp-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_wrap_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_WRAP_DOC_TRUTH),
        "missing-required-scalar-wrap-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_ieee_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_IEEE_DOC_TRUTH),
        "missing-required-scalar-ieee-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_integer_boundary_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_INTEGER_BOUNDARY_DOC_TRUTH),
        "missing-required-scalar-integer-boundary-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_sign_angle_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_SIGN_ANGLE_DOC_TRUTH),
        "missing-required-scalar-sign-angle-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_integer_conversion_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_INTEGER_CONVERSION_DOC_TRUTH),
        "missing-required-scalar-integer-conversion-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_range_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_RANGE_DOC_TRUTH),
        "missing-required-scalar-range-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_min_max_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_MIN_MAX_DOC_TRUTH),
        "missing-required-scalar-min-max-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_scalar_float_compare_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_SCALAR_FLOAT_COMPARE_DOC_TRUTH),
        "missing-required-scalar-float-compare-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_trig_power_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_TRIG_POWER_DOC_TRUTH),
        "missing-required-trig-power-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_trig_circular_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_TRIG_CIRCULAR_DOC_TRUTH),
        "missing-required-trig-circular-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_trig_log_subnormal_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_TRIG_LOG_SUBNORMAL_DOC_TRUTH),
        "missing-required-trig-log-subnormal-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_impl_simd_win64_compile_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        api_doc_truth(REQUIRED_IMPL_SIMD_WIN64_COMPILE_DOC_TRUTH),
        "missing-required-impl-simd-win64-compile-doc-truth",
        normalize_whitespace=True,
    )


def build_report(root: Path) -> Report:
    root = root.resolve()
    findings: list[Finding] = []
    scanned: set[Path] = set()
    findings.extend(scan_missing_required_public_files(root))
    findings.extend(scan_missing_required_benchmark_markers(root))
    findings.extend(scan_required_behavior_test_markers(root))
    findings.extend(scan_facade_type_alias_compile_surface(root))
    findings.extend(scan_facade_root_import_contract(root))
    findings.extend(scan_root_facade_api_doc_coverage(root))
    findings.extend(scan_root_facade_contract(root))
    findings.extend(scan_root_facade_reexport_parity(root))
    findings.extend(scan_required_core_make_targets(root))
    findings.extend(scan_required_core_make_target_doc_coverage(root))
    findings.extend(scan_compile_only_gate_aggregate_exclusions(root))
    findings.extend(scan_required_trig_host_compile_gate(root))
    findings.extend(scan_required_impl_simd_win64_compile_gate(root))
    findings.extend(scan_math_impl_simd_facade_only_uses(root))
    findings.extend(scan_control_doc_compaction(root))
    findings.extend(scan_l1_goal_tree_math_truth(root))
    findings.extend(scan_required_host_gate_residual_truth(root))
    findings.extend(scan_required_m8_residual_truth(root))
    findings.extend(scan_required_simd_seam_doc_truth(root))
    findings.extend(scan_required_facade_only_doc_truth(root))
    findings.extend(scan_required_impl_simd_win64_compile_doc_truth(root))
    findings.extend(scan_required_mat_doc_truth(root))
    findings.extend(scan_required_transform_doc_truth(root))
    findings.extend(scan_required_quat_doc_truth(root))
    findings.extend(scan_required_vec_quat_stable_doc_truth(root))
    findings.extend(scan_required_random_doc_truth(root))
    findings.extend(scan_required_easing_doc_truth(root))
    findings.extend(scan_required_noise_doc_truth(root))
    findings.extend(scan_required_scalar_clamp_doc_truth(root))
    findings.extend(scan_required_scalar_wrap_doc_truth(root))
    findings.extend(scan_required_scalar_ieee_doc_truth(root))
    findings.extend(scan_required_scalar_integer_boundary_doc_truth(root))
    findings.extend(scan_required_scalar_sign_angle_doc_truth(root))
    findings.extend(scan_required_scalar_integer_conversion_doc_truth(root))
    findings.extend(scan_required_scalar_range_doc_truth(root))
    findings.extend(scan_required_scalar_min_max_doc_truth(root))
    findings.extend(scan_required_scalar_float_compare_doc_truth(root))
    findings.extend(scan_required_trig_power_doc_truth(root))
    findings.extend(scan_required_trig_circular_doc_truth(root))
    findings.extend(scan_required_trig_log_subnormal_doc_truth(root))

    source_files = discover_files(root, MATH_SOURCE_GLOBS)
    math_ffi = root / "src/nextpas.core.math.ffi.pas"
    if math_ffi.exists():
        scanned.add(math_ffi)
        add_finding(
            findings,
            "no-math-ffi-unit",
            root,
            math_ffi,
            1,
            "src/nextpas.core.math.ffi.pas must not exist in the final public math facade",
        )
    simd_mathutil = root / SIMD_MATHUTIL_PATH
    if simd_mathutil.is_file():
        source_files.append(simd_mathutil)
    consumer_files = (
        discover_files(root, MATH_TEST_GLOBS)
        + discover_files(root, MATH_EXAMPLE_GLOBS)
        + discover_public_docs(root)
    )
    root_makefile = root / ROOT_MAKEFILE_PATH
    if root_makefile.is_file():
        scanned.add(root_makefile)
        text = root_makefile.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_native_math_linking(root, root_makefile, text))
    benchmark_files = discover_files(root, MATH_BENCHMARK_GLOBS)

    for path in source_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_allowed_math_units(root, path, text))
        findings.extend(scan_math_ffi_uses(root, path, text))
        findings.extend(scan_external_m(root, path, text))
        findings.extend(scan_native_math_linking(root, path, text))
        findings.extend(scan_legacy_public_names(root, path, text))
        findings.extend(scan_legacy_production_names(root, path, text))
        if relative(path, root) != SIMD_MATHUTIL_PATH:
            findings.extend(scan_private_simd(root, path, text))
        findings.extend(scan_math_impl_simd_public_seam(root, path, text))
        findings.extend(scan_public_math_source_simd_wiring(root, path, text))
        findings.extend(scan_forbidden_trig_scalar_names(root, path, text))
        findings.extend(scan_forbidden_simd_mathutil_bare_names(root, path, text))
        findings.extend(scan_forbidden_fpc_math_unit_in_easing(root, path, text))
        findings.extend(scan_forbidden_fpc_math_unit_in_trig(root, path, text))
        findings.extend(scan_trig_log_exact_identity_source_contract(root, path, text))
        findings.extend(scan_public_global_random_singletons(root, path, text))
        findings.extend(scan_random_noise_public_contract(root, path, text))
        findings.extend(scan_required_public_declarations(root, path, text))
        findings.extend(scan_vector_length_sqr_record_contract(root, path, text))
        findings.extend(scan_vector_public_record_contract(root, path, text))
        findings.extend(scan_matrix_public_record_contract(root, path, text))
        findings.extend(scan_quaternion_public_record_contract(root, path, text))

    for path in consumer_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_math_ffi_uses(root, path, text))
        if path.suffix.lower() in {".lpr", ".pas"} or path.name == "Makefile":
            findings.extend(scan_external_m(root, path, text))
            findings.extend(scan_native_math_linking(root, path, text))
        if path.suffix.lower() in {".lpr", ".pas"}:
            findings.extend(scan_legacy_public_names(root, path, text))
            findings.extend(scan_legacy_production_names(root, path, text))
        elif path.suffix.lower() == ".md":
            findings.extend(scan_legacy_public_doc_symbols(root, path, text))
        if relative(path, root).startswith(INTERNAL_IMPL_TEST_PREFIXES) and path.suffix.lower() in {
            ".lpr",
            ".pas",
        }:
            findings.extend(scan_private_simd(root, path, text))
        findings.extend(scan_public_impl_consumers(root, path, text))
        findings.extend(scan_compiler_refs(root, path, text))

    for path in benchmark_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_math_ffi_uses(root, path, text))
        findings.extend(scan_private_simd(root, path, text))
        if path.suffix.lower() in {".lpr", ".pas"}:
            findings.extend(scan_external_m(root, path, text))
        if path.suffix.lower() in {".lpr", ".pas"} or path.name == "Makefile":
            findings.extend(scan_native_math_linking(root, path, text))
        findings.extend(scan_compiler_refs(root, path, text))

    findings.sort(key=lambda item: (item.path, item.line, item.rule, item.text))
    return Report(str(root), len(scanned), findings)


def print_report(report: Report, summary_line: bool, verbose: bool) -> None:
    if summary_line:
        status = "OK" if report.ok else "FAIL"
        print(
            f"{SUMMARY_PREFIX} {status}: "
            f"scanned={report.scanned_files} findings={len(report.findings)}"
        )

    if (not summary_line) or verbose or (not report.ok):
        if not report.findings:
            print(f"{SUMMARY_PREFIX}: no findings")
            return
        for finding in report.findings:
            print(
                f"{finding.path}:{finding.line}: "
                f"{finding.rule}: {finding.text}"
            )


def main() -> int:
    args = parse_args()
    if args.self_test:
        run_behavior_marker_self_tests()
        run_facade_type_alias_compile_surface_self_tests()
        run_facade_root_import_contract_self_tests()
        run_public_math_source_simd_wiring_self_tests()
        run_math_impl_simd_facade_only_uses_self_tests()
        run_math_impl_simd_public_seam_self_tests()
        run_forbidden_simd_mathutil_bare_name_self_tests()
        run_forbidden_native_math_linking_scope_self_tests()
        run_legacy_production_name_self_tests()
        run_legacy_public_doc_symbol_self_tests()
        run_forbidden_trig_scalar_name_self_tests()
        run_trig_host_safe_route_self_tests()
        run_trig_log_exact_identity_source_contract_self_tests()
        run_required_trig_host_compile_gate_self_tests()
        run_required_impl_simd_win64_compile_gate_self_tests()
        run_required_public_declarations_self_tests()
        run_random_noise_public_contract_self_tests()
        run_vector_public_record_contract_self_tests()
        run_matrix_public_record_contract_self_tests()
        run_quaternion_public_record_contract_self_tests()
        run_required_doc_truth_self_tests()
        run_control_doc_compaction_self_tests()
        run_l1_goal_tree_math_truth_self_tests()
        run_root_facade_contract_self_tests()
        run_root_facade_reexport_parity_self_tests()
        run_compile_only_gate_aggregate_exclusion_self_tests()
    report = build_report(args.root)

    if args.json_file:
        json_path = Path(args.json_file)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(
            json.dumps(asdict(report), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    print_report(report, args.summary_line, args.verbose)
    return 0 if report.ok else 1


if __name__ == "__main__":
    sys.exit(main())
