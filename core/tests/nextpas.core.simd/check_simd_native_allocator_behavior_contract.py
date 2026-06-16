#!/usr/bin/env python3
"""Guard SIMD's aligned allocator owner boundary."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ALLOC_PATH = ROOT / "src/nextpas.core.simd.alloc.pas"
MEMUTILS_PATH = ROOT / "src/nextpas.core.simd.memutils.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"

REQUIRED_NATIVE_TRUTH_TOKENS = (
    "SimdAlloc native allocator behavior truth:",
    "Aligned allocation owner: nextpas.core.platform.memory",
    "SIMD allocator state: consumes platform-owned aligned allocation seam",
    "SIMD raw host allocator state: no Windows/POSIX allocator FFI declarations",
    "Wine or cross-compile evidence is not real Windows runtime readiness",
)

REQUIRED_PLATFORM_SEAM_TOKENS = (
    "nextpas.core.platform.memory",
    "platform_aligned_alloc",
    "platform_aligned_realloc",
    "platform_aligned_free",
)

FORBIDDEN_SIMD_ALLOCATOR_CODE_TOKENS = (
    "Windows",
    "BaseUnix",
    "Unix",
    "DynLibs",
    "ctypes",
    "_aligned_malloc",
    "_aligned_realloc",
    "_aligned_free",
    "posix_memalign",
    "aligned_alloc",
    "TAllocHeader",
    "OrigPtr",
    "GetMem",
    "FreeMem",
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def rel(a_path: Path) -> str:
    return str(a_path.relative_to(ROOT))


def add_issue(a_issues: list[str], a_path: Path, a_message: str) -> None:
    a_issues.append(f"{rel(a_path)}: {a_message}")


def strip_pascal_comments(a_text: str) -> str:
    a_text = re.sub(r"\(\*.*?\*\)", "", a_text, flags=re.DOTALL)
    a_text = re.sub(r"\{(?!\$).*?\}", "", a_text, flags=re.DOTALL)
    a_text = re.sub(r"//.*", "", a_text)
    return a_text


def check_required_truth_tokens(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_NATIVE_TRUTH_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing native allocator truth token `{l_token}`")


def check_platform_seam_shape(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    l_memutils_text = read_text(MEMUTILS_PATH)
    for l_token in REQUIRED_PLATFORM_SEAM_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing platform seam token `{l_token}`")
        if l_token not in l_memutils_text:
            add_issue(a_issues, MEMUTILS_PATH, f"missing platform seam token `{l_token}`")


def check_no_raw_allocator_in_simd_code(a_issues: list[str]) -> None:
    for l_path in (ALLOC_PATH, MEMUTILS_PATH):
        l_code = strip_pascal_comments(read_text(l_path))
        for l_token in FORBIDDEN_SIMD_ALLOCATOR_CODE_TOKENS:
            l_pattern = rf"(?<![A-Za-z0-9_]){re.escape(l_token)}(?![A-Za-z0-9_])"
            if re.search(l_pattern, l_code, flags=re.IGNORECASE):
                add_issue(a_issues, l_path, f"raw allocator owner token `{l_token}` is present in executable code")


def check_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_simd_native_allocator_behavior_contract.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run native allocator behavior contract")


def render_summary(a_issues: list[str]) -> str:
    return f"SIMD_NATIVE_ALLOCATOR_BEHAVIOR_SUMMARY issues={len(a_issues)}"


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check SIMD aligned allocator owner boundary")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_args = l_parser.parse_args()

    l_issues: list[str] = []
    check_required_truth_tokens(l_issues)
    check_platform_seam_shape(l_issues)
    check_no_raw_allocator_in_simd_code(l_issues)
    check_makefile_hook(l_issues)

    if l_args.summary_line:
        print(render_summary(l_issues))

    if l_issues:
        print("[SIMD-NATIVE-ALLOCATOR-BEHAVIOR-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[SIMD-NATIVE-ALLOCATOR-BEHAVIOR-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
