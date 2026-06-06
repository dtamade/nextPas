#!/usr/bin/env python3
"""Fail-close the nextpas.core.math final public surface contract."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


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
PUBLIC_DOC_PATHS = (
    "docs/math/README.md",
    "docs/math/API.md",
)
SIMD_MATHUTIL_PATH = "src/nextpas.core.simd.mathutil.pas"

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
}


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


def build_report(root: Path) -> Report:
    root = root.resolve()
    findings: list[Finding] = []
    scanned: set[Path] = set()
    findings.extend(scan_missing_required_public_files(root))

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
        findings.extend(scan_required_public_declarations(root, path, text))

    for path in consumer_files:
        scanned.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        findings.extend(scan_math_ffi_uses(root, path, text))
        findings.extend(scan_public_impl_consumers(root, path, text))
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
