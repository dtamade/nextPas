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
    "examples/nextpas.core.math*/**/*.lpr",
    "examples/nextpas.core.math*/**/*.pas",
)
MATH_BENCHMARK_GLOBS = (
    "benchmarks/nextpas.core.math/**/*.lpr",
    "benchmarks/nextpas.core.math/**/*.pas",
)
PUBLIC_DOC_PATHS = (
    "docs/math/README.md",
    "docs/math/API.md",
)
REQUIRED_CORE_TARGET_DOC_PATHS = (
    "docs/math/README.md",
    "docs/math/API.md",
    "docs/math/GOAL_TREE.md",
    "docs/math/FINAL_API_MIGRATION_DESIGN.md",
)
ROOT_MAKEFILE_PATH = "Makefile"
ROOT_FACADE_PATH = "src/nextpas.core.math.pas"
API_DOC_PATH = "docs/math/API.md"
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
)
BENCH_SIMD_SEAM_PATH = "benchmarks/nextpas.core.math/bench_simd_seam/bench_simd_seam.lpr"
SIMD_MATHUTIL_PATH = "src/nextpas.core.simd.mathutil.pas"
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
    r"Vector[234]|Matrix[34]|Quaternion|Vectors)\b"
)
USES_MATH_FFI_RE = re.compile(
    r"\buses\b(?P<body>.*?);",
    re.IGNORECASE | re.DOTALL,
)
EXTERNAL_M_RE = re.compile(
    r"\bexternal\s+(['\"])\s*m\s*\1",
    re.IGNORECASE,
)
PRIVATE_SIMD_RE = re.compile(
    r"\b("
    r"nextpas\.core\.simd\.direct|"
    r"nextpas\.core\.simd\.dispatch|"
    r"nextpas\.core\.simd\.dataplane|"
    r"nextpas\.core\.simd\.avx2(?:\.[A-Za-z0-9_]+)?|"
    r"nextpas\.core\.simd\.avx512(?:\.[A-Za-z0-9_]+)?|"
    r"nextpas\.core\.simd\.sse(?:\.[A-Za-z0-9_]+)?|"
    r"nextpas\.core\.simd\.sse2(?:\.[A-Za-z0-9_]+)?|"
    r"nextpas\.core\.simd\.neon(?:\.[A-Za-z0-9_]+)?|"
    r"nextpas\.core\.simd\.riscvv(?:\.[A-Za-z0-9_]+)?|"
    r"GetDirectDispatchTable|"
    r"GetCurrentSimdDataPlane(?:Dispatch)?|"
    r"RebindSimdDataPlane|"
    r"TryGetRegisteredBackendDispatchTable"
    r")\b",
    re.IGNORECASE,
)
PUBLIC_IMPL_RE = re.compile(
    r"\bnextpas\.core\.math\.impl\.[A-Za-z0-9_.]+\b",
    re.IGNORECASE,
)
PUBLIC_GLOBAL_RANDOM_RE = re.compile(
    r"^\s*(?:threadvar|var)\s+(?:G(?:Random|Noise)|Global(?:Random|Noise))\b",
    re.IGNORECASE | re.MULTILINE,
)
UNIT_NAME_RE = re.compile(
    r"^\s*unit\s+(?P<name>nextpas\.core\.math(?:\.[A-Za-z0-9_]+)*)\s*;",
    re.IGNORECASE | re.MULTILINE,
)
IMPLEMENTATION_RE = re.compile(
    r"^\s*implementation\b",
    re.IGNORECASE | re.MULTILINE,
)
COMPILER_REF_RE = re.compile(
    r"(?:^|[/\\])compiler(?:[/\\]|$)|scripts/rebuild-compiler\.sh",
    re.IGNORECASE,
)
TRIG_FORBIDDEN_SCALAR_RE = re.compile(
    r"\bfunction\s+("
    r"Min|Max|Floor|Ceil|Round|Trunc|Frac|Abs|Clamp|Sign|Lerp|"
    r"InverseLerp|Wrap|SmoothStep|GCD|LCM|Hypot|Fmod"
    r")\s*\(",
    re.IGNORECASE,
)
SIMD_MATHUTIL_FORBIDDEN_BARE_RE = re.compile(
    r"\bfunction\s+("
    r"Min|Max|Floor|Ceil|Round|Trunc|Frac|Abs|Clamp|Sign|Lerp|"
    r"Sin|Cos|Tan|ArcSin|ArcCos|ArcTan|ArcTan2|Exp|Ln|Log2|Log10|"
    r"Power|Sqrt|Hypot|Fmod|SmoothStep|GCD|LCM|IsNaN|IsNan|IsInfinite"
    r")\s*\(",
    re.IGNORECASE,
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
REQUIRED_PUBLIC_DECLARATIONS: dict[str, tuple[tuple[str, str], ...]] = {
    "src/nextpas.core.math.pas": (
        ("root-single-min", r"\bfunction\s+Min\s*\(\s*AA\s*,\s*AB\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-single-ceil", r"\bfunction\s+Ceil\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("root-gcd", r"\bfunction\s+GCD\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("root-lcm", r"\bfunction\s+LCM\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("root-hypot-double", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-hypot-single", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("root-fmod-double", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("root-smoothstep-single", r"\bfunction\s+SmoothStep\s*\(\s*const\s+AEdge0\s*,\s*AEdge1\s*,\s*AValue\s*:\s*Single\s*\)\s*:\s*Single\b"),
    ),
    "src/nextpas.core.math.scalar.pas": (
        ("scalar-single-min", r"\bfunction\s+Min\s*\(\s*AA\s*,\s*AB\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-single-ceil", r"\bfunction\s+Ceil\s*\(\s*const\s+AValue\s*:\s*Single\s*\)\s*:\s*Int64\b"),
        ("scalar-gcd", r"\bfunction\s+GCD\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("scalar-lcm", r"\bfunction\s+LCM\s*\(\s*AA\s*,\s*AB\s*:\s*Int64\s*\)\s*:\s*Int64\b"),
        ("scalar-hypot-single", r"\bfunction\s+Hypot\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("scalar-fmod-double", r"\bfunction\s+Fmod\s*\(\s*const\s+AX\s*,\s*AY\s*:\s*Double\s*\)\s*:\s*Double\b"),
        ("scalar-smoothstep-double", r"\bfunction\s+SmoothStep\s*\(\s*const\s+AEdge0\s*,\s*AEdge1\s*,\s*AValue\s*:\s*Double\s*\)\s*:\s*Double\b"),
    ),
    "src/nextpas.core.math.trig.pas": (
        ("trig-single-sin", r"\bfunction\s+Sin\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-cos", r"\bfunction\s+Cos\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-ln", r"\bfunction\s+Ln\s*\(\s*const\s+AX\s*:\s*Single\s*\)\s*:\s*Single\b"),
        ("trig-single-power", r"\bfunction\s+Power\s*\(\s*const\s+ABase\s*,\s*AExponent\s*:\s*Single\s*\)\s*:\s*Single\b"),
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
REQUIRED_BENCHMARK_MARKERS: dict[str, tuple[tuple[str, str], ...]] = {
    BENCH_SIMD_SEAM_PATH: (
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
    RequiredBehaviorTestMarker("scalar-constants", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('constants'"),
    RequiredBehaviorTestMarker("scalar-min-max-clamp", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('min max clamp'"),
    RequiredBehaviorTestMarker("scalar-interpolation", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('interpolation'"),
    RequiredBehaviorTestMarker("scalar-rounding-sign", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('rounding and sign'"),
    RequiredBehaviorTestMarker("scalar-float-predicates", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('float predicates'"),
    RequiredBehaviorTestMarker("scalar-extras", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('number theory and scalar extras'"),
    RequiredBehaviorTestMarker("scalar-boundaries", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('integer rounding boundaries'"),
    RequiredBehaviorTestMarker("scalar-owner-messages", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('owner-level boundary messages'"),
    RequiredBehaviorTestMarker("scalar-single-boundary-messages", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('single-precision boundary messages'"),
    RequiredBehaviorTestMarker("scalar-overflow", "tests/nextpas.core.math/test_scalar/test_scalar.lpr", "T.Run('overflow helpers'"),
    RequiredBehaviorTestMarker("trig-basic", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('basic trig values'"),
    RequiredBehaviorTestMarker("trig-inverse-domain", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('inverse trig domain contracts'"),
    RequiredBehaviorTestMarker("trig-atan2-special", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('ArcTan2 special cases'"),
    RequiredBehaviorTestMarker("trig-exp-log-sqrt", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('exp/log/sqrt contracts'"),
    RequiredBehaviorTestMarker("trig-power", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('power edge contracts'"),
    RequiredBehaviorTestMarker("trig-angle-conversions", "tests/nextpas.core.math/test_trig/test_trig.lpr", "T.Run('angle conversions'"),
    RequiredBehaviorTestMarker("vec-2f", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec2f contracts'"),
    RequiredBehaviorTestMarker("vec-3f", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec3f contracts'"),
    RequiredBehaviorTestMarker("vec-4f", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('TVec4f contracts'"),
    RequiredBehaviorTestMarker("vec-double", "tests/nextpas.core.math/test_vec/test_vec.lpr", "T.Run('double precision vector contracts'"),
    RequiredBehaviorTestMarker("mat-3f", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('TMat3f contracts'"),
    RequiredBehaviorTestMarker("mat-4f", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('TMat4f contracts'"),
    RequiredBehaviorTestMarker("mat-double", "tests/nextpas.core.math/test_mat/test_mat.lpr", "T.Run('double precision matrix contracts'"),
    RequiredBehaviorTestMarker("quat-f", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('TQuatf contracts'"),
    RequiredBehaviorTestMarker("quat-d", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('TQuatd contracts'"),
    RequiredBehaviorTestMarker("quat-axis-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('FromAxisAngle rejects non-finite inputs'"),
    RequiredBehaviorTestMarker("quat-interpolation-finite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation rejects non-finite t'"),
    RequiredBehaviorTestMarker("quat-interpolation-extrapolation", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation allows finite extrapolation'"),
    RequiredBehaviorTestMarker("quat-interpolation-endpoints", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation endpoint contracts'"),
    RequiredBehaviorTestMarker("quat-interpolation-shortest-start", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation follows shortest path for opposite-sign start'"),
    RequiredBehaviorTestMarker("quat-interpolation-shortest-end", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation follows shortest path for opposite-sign end'"),
    RequiredBehaviorTestMarker("quat-interpolation-equivalent", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation stays stable for equivalent endpoints'"),
    RequiredBehaviorTestMarker("quat-interpolation-near-identical", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('Interpolation stays stable for near-identical endpoints'"),
    RequiredBehaviorTestMarker("quat-axis-angle-opposite", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle canonicalizes opposite-sign rotations'"),
    RequiredBehaviorTestMarker("quat-axis-angle-multiturn", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle canonicalizes multi-turn inputs'"),
    RequiredBehaviorTestMarker("quat-axis-angle-half-turns", "tests/nextpas.core.math/test_quat/test_quat.lpr", "T.Run('ToAxisAngle canonicalizes FromAxisAngle half-turns'"),
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
    RequiredBehaviorTestMarker("easing-out-of-range", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('finite out-of-range inputs extrapolate'"),
    RequiredBehaviorTestMarker("easing-non-finite", "tests/nextpas.core.math/test_easing/test_easing.lpr", "T.Run('non-finite inputs fail fast'"),
    RequiredBehaviorTestMarker("random-seed", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('seed determinism'"),
    RequiredBehaviorTestMarker("random-zero-seed", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('zero seed uses deterministic default'"),
    RequiredBehaviorTestMarker("random-range", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('range boundaries'"),
    RequiredBehaviorTestMarker("random-state-forced-boundaries", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('state-forced half-open boundaries'"),
    RequiredBehaviorTestMarker("random-unbiased-integer-range", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('integer ranges reject modulo-bias tail states'"),
    RequiredBehaviorTestMarker("random-large-float", "tests/nextpas.core.math/test_random/test_random.lpr", "T.Run('large finite float range stays finite and bounded'"),
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
    RequiredBehaviorTestMarker("noise-huge-lattice", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('huge finite lattice coordinates stay stable'"),
    RequiredBehaviorTestMarker("noise-fbm-coordinate", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('FBM rejects non-finite octave coordinates'"),
    RequiredBehaviorTestMarker("noise-fbm-amplitude", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('FBM rejects non-finite octave amplitude'"),
    RequiredBehaviorTestMarker("noise-fbm-accumulated", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('FBM rejects non-finite accumulated result'"),
    RequiredBehaviorTestMarker("noise-precision-ceiling", "tests/nextpas.core.math/test_noise/test_noise.lpr", "T.Run('precision ceiling follows stored Double value'"),
    RequiredBehaviorTestMarker("impl-simd-vec4f", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('vec4f simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-vec3f", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('vec3f simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-mat4f", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('mat4f simd helpers'"),
    RequiredBehaviorTestMarker("impl-simd-quatf", "tests/nextpas.core.math/test_impl_simd/test_impl_simd.lpr", "T.Run('quatf simd helpers'"),
)


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    text: str


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


def interface_text(text: str) -> str:
    code = strip_pascal_comments_and_strings(text)
    match = IMPLEMENTATION_RE.search(code)
    if match is None:
        return code
    return code[: match.start()]


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
    for match in SIMD_MATHUTIL_FORBIDDEN_BARE_RE.finditer(code):
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


def scan_forbidden_fpc_math_unit_in_easing(root: Path, path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if relative(path, root) != "src/nextpas.core.math.easing.pas":
        return findings

    code = strip_pascal_comments_and_strings(text)
    for match in USES_MATH_FFI_RE.finditer(code):
        for unit in match.group("body").split(","):
            if re.sub(r"\s+", "", unit).lower() != "math":
                continue
            line = line_no_at(code, match.start("body") + match.group("body").find(unit))
            add_finding(
                findings,
                "no-fpc-math-unit-in-easing",
                root,
                path,
                line,
                original_line(text, line),
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
    for rel in REQUIRED_CORE_TARGET_DOC_PATHS:
        path = root / rel
        if not path.is_file():
            continue
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


def scan_required_host_gate_residual_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        REQUIRED_HOST_GATE_RESIDUAL_TRUTH,
        "missing-required-host-gate-truth",
    )


def scan_required_m8_residual_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        REQUIRED_M8_RESIDUAL_TRUTH,
        "missing-required-m8-truth",
    )


def scan_required_transform_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        REQUIRED_TRANSFORM_DOC_TRUTH,
        "missing-required-transform-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_quat_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        REQUIRED_QUAT_DOC_TRUTH,
        "missing-required-quat-doc-truth",
        normalize_whitespace=True,
    )


def scan_required_random_doc_truth(root: Path) -> list[Finding]:
    return scan_required_doc_truth(
        root,
        REQUIRED_RANDOM_DOC_TRUTH,
        "missing-required-random-doc-truth",
        normalize_whitespace=True,
    )


def build_report(root: Path) -> Report:
    root = root.resolve()
    findings: list[Finding] = []
    scanned: set[Path] = set()
    findings.extend(scan_missing_required_public_files(root))
    findings.extend(scan_missing_required_benchmark_markers(root))
    findings.extend(scan_required_behavior_test_markers(root))
    findings.extend(scan_root_facade_api_doc_coverage(root))
    findings.extend(scan_required_core_make_targets(root))
    findings.extend(scan_required_core_make_target_doc_coverage(root))
    findings.extend(scan_required_host_gate_residual_truth(root))
    findings.extend(scan_required_m8_residual_truth(root))
    findings.extend(scan_required_transform_doc_truth(root))
    findings.extend(scan_required_quat_doc_truth(root))
    findings.extend(scan_required_random_doc_truth(root))

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
    benchmark_files = discover_files(root, MATH_BENCHMARK_GLOBS)

    for path in source_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_allowed_math_units(root, path, text))
        findings.extend(scan_math_ffi_uses(root, path, text))
        findings.extend(scan_external_m(root, path, text))
        findings.extend(scan_legacy_public_names(root, path, text))
        findings.extend(scan_private_simd(root, path, text))
        findings.extend(scan_forbidden_trig_scalar_names(root, path, text))
        findings.extend(scan_forbidden_simd_mathutil_bare_names(root, path, text))
        findings.extend(scan_forbidden_fpc_math_unit_in_easing(root, path, text))
        findings.extend(scan_public_global_random_singletons(root, path, text))
        findings.extend(scan_required_public_declarations(root, path, text))

    for path in consumer_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_math_ffi_uses(root, path, text))
        findings.extend(scan_public_impl_consumers(root, path, text))
        findings.extend(scan_compiler_refs(root, path, text))

    for path in benchmark_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_math_ffi_uses(root, path, text))
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
