#!/usr/bin/env python3
"""Source contracts for math-simd lane (F-001 / F-004 / F-012 / F-005).

1) simd production must not uses nextpas.core.math.*
2) System.(Sin|Cos|Exp|Ln|Sqrt|ArcTan) only allowed in mathutil (+ optional allowlist)
3) math value-type units must not uses nextpas.core.simd
4) cpuinfo platform uses must stay on allowlist
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SUMMARY = "MATH_SIMD_SOURCE_CONTRACTS"

USES_RE = re.compile(r"(?is)\buses\b(.*?);")
MATH_USES_RE = re.compile(r"nextpas\.core\.math(?:\.\w+)?")
SIMD_USES_RE = re.compile(r"nextpas\.core\.simd(?:\.\w+)?")
SYSTEM_MATH_RE = re.compile(
    r"\bSystem\.(Sin|Cos|Exp|Ln|Sqrt|ArcTan2?|Tan|ArcSin|ArcCos)\b"
)
PLATFORM_USES_RE = re.compile(r"nextpas\.core\.platform(?:\.\w+)+")

COMMENT_RE = re.compile(r"\{.*?\}|\(\*.*?\*\)|//.*?$", re.S | re.M)

SYSTEM_MATH_ALLOW = {
    "src/nextpas.core.simd.mathutil.pas",
}

VALUE_TYPE_MATH = (
    "src/nextpas.core.math.vec.pas",
    "src/nextpas.core.math.vec.base.pas",
    "src/nextpas.core.math.mat.pas",
    "src/nextpas.core.math.mat.base.pas",
    "src/nextpas.core.math.quat.pas",
    "src/nextpas.core.math.quat.base.pas",
    "src/nextpas.core.math.transform.pas",
    "src/nextpas.core.math.easing.pas",
    "src/nextpas.core.math.random.pas",
    "src/nextpas.core.math.scalar.pas",
    "src/nextpas.core.math.trig.pas",
    "src/nextpas.core.math.base.pas",
)

# path-limited CPUInfo debt (relative to core/)
CPUINFO_PLATFORM_ALLOW = {
    "src/nextpas.core.simd.cpuinfo.pas": {
        "nextpas.core.platform.files",
        "nextpas.core.platform.files.base",
    },
    "src/nextpas.core.simd.cpuinfo.unix.pas": {
        "nextpas.core.platform.linux.base",
        "nextpas.core.platform.posix.ffi",
    },
    "src/nextpas.core.simd.cpuinfo.windows.pas": {
        "nextpas.core.platform.windows.base",
        "nextpas.core.platform.windows.ffi",
    },
    "src/nextpas.core.simd.cpuinfo.arm.pas": {
        "nextpas.core.platform.files",
        "nextpas.core.platform.files.base",
    },
    "src/nextpas.core.simd.cpuinfo.darwin.pas": {
        "nextpas.core.platform.darwin.ffi",
    },
    "src/nextpas.core.simd.cpuinfo.riscv.pas": {
        "nextpas.core.platform.files",
        "nextpas.core.platform.files.base",
    },
    "src/nextpas.core.simd.cpuinfo.loongarch.pas": {
        "nextpas.core.platform.files",
        "nextpas.core.platform.files.base",
    },
    "src/nextpas.core.simd.cpuinfo.lazy.pas": {
        "nextpas.core.platform.files",
        "nextpas.core.platform.files.base",
    },
    "src/nextpas.core.simd.cpuinfo.diagnostic.pas": {
        "nextpas.core.platform.time",
    },
}


def strip_comments(text: str) -> str:
    return COMMENT_RE.sub(" ", text)


def uses_blocks(text: str) -> list[str]:
    return USES_RE.findall(strip_comments(text))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=None)
    ap.add_argument("--summary-line", action="store_true")
    args = ap.parse_args()
    root = (args.root or Path(__file__).resolve().parents[2]).resolve()

    errors: list[str] = []

    # 1) simd ↛ math
    for path in sorted(root.glob("src/nextpas.core.simd*.pas")):
        rel = str(path.relative_to(root))
        text = path.read_text(encoding="utf-8", errors="replace")
        for block in uses_blocks(text):
            if MATH_USES_RE.search(block):
                errors.append(f"{rel}: uses nextpas.core.math (forbidden reverse dep)")

    # 2) System.* math only in allowlist
    for path in sorted(root.glob("src/nextpas.core.simd*.pas")):
        rel = str(path.relative_to(root)).replace("\\", "/")
        if rel in SYSTEM_MATH_ALLOW:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        cleaned = strip_comments(text)
        hits = SYSTEM_MATH_RE.findall(cleaned)
        if hits:
            errors.append(
                f"{rel}: System.* math calls {sorted(set(hits))} (use mathutil)"
            )

    # 3) value-type math no simd
    for rel in VALUE_TYPE_MATH:
        path = root / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for block in uses_blocks(text):
            if SIMD_USES_RE.search(block):
                errors.append(f"{rel}: value-type unit uses simd (forbidden)")

    # 4) cpuinfo platform allowlist
    for rel, allowed in CPUINFO_PLATFORM_ALLOW.items():
        path = root / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        found: set[str] = set()
        for block in uses_blocks(text):
            for m in PLATFORM_USES_RE.finditer(block):
                found.add(m.group(0))
        extra = found - allowed
        if extra:
            errors.append(f"{rel}: unexpected platform uses {sorted(extra)}")

    if errors:
        print("FAIL: math-simd source contracts", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        if args.summary_line:
            print(f"{SUMMARY} status=FAIL count={len(errors)}")
        return 1

    print("OK: math-simd source contracts")
    if args.summary_line:
        print(f"{SUMMARY} status=PASS count=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
