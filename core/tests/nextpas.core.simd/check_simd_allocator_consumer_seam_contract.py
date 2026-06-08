#!/usr/bin/env python3
"""Guard SIMD consumer requirements for the platform-owned aligned allocation seam."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ALLOC_PATH = ROOT / "src/nextpas.core.simd.alloc.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"

REQUIRED_CONSUMER_TOKENS = (
    "SimdAlloc platform-owned aligned allocation seam consumer contract:",
    "Alignment values must be powers of two",
    "Allocation size calculation must be overflow-guarded before calling the lower seam",
    "Invalid alignment and overflow must fail closed with nil",
    "SimdFree(nil) must be a no-op",
    "SimdAlloc(0, *) must return nil",
    "SimdRealloc(nil, size, alignment) must behave like SimdAlloc",
    "SimdRealloc(ptr, 0, alignment) must free and return nil",
    "SimdRealloc must preserve the requested alignment",
    "SimdRealloc must preserve the overlapping prefix bytes",
    "Current fallback/native backend truth lives in nextpas.core.platform.memory",
    "Native Windows/POSIX allocator runtime readiness requires platform-owned seam integration plus real runtime evidence",
)

REQUIRED_PLATFORM_CONSUMER_TOKENS = (
    "nextpas.core.platform.memory",
    "TryResolveAlignment",
    "platform_aligned_alloc(aSize, LAlign)",
    "platform_aligned_free(aPtr)",
    "platform_aligned_realloc(aPtr, aNewSize, LAlign)",
)

FORBIDDEN_PUBLIC_ALLOC_CODE_TOKENS = (
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
    "GetAlignedAlloc",
    "TAlignedAlloc",
    "mi_malloc_aligned",
    "mi_realloc_aligned",
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


def check_required_consumer_tokens(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_CONSUMER_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing consumer seam contract token `{l_token}`")


def check_platform_consumer_shape(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_PLATFORM_CONSUMER_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing platform consumer token `{l_token}`")


def check_no_owner_boundary_bypass(a_issues: list[str]) -> None:
    l_code = strip_pascal_comments(read_text(ALLOC_PATH))
    for l_token in FORBIDDEN_PUBLIC_ALLOC_CODE_TOKENS:
        l_pattern = rf"(?<![A-Za-z0-9_]){re.escape(l_token)}(?![A-Za-z0-9_])"
        if re.search(l_pattern, l_code, flags=re.IGNORECASE):
            add_issue(a_issues, ALLOC_PATH, f"owner-boundary bypass token `{l_token}` is present in executable code")


def check_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_simd_allocator_consumer_seam_contract.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run SIMD allocator consumer seam contract")


def render_summary(a_issues: list[str]) -> str:
    return f"SIMD_ALLOCATOR_CONSUMER_SEAM_SUMMARY issues={len(a_issues)}"


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check SIMD allocator consumer seam contract")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_args = l_parser.parse_args()

    l_issues: list[str] = []
    check_required_consumer_tokens(l_issues)
    check_platform_consumer_shape(l_issues)
    check_no_owner_boundary_bypass(l_issues)
    check_makefile_hook(l_issues)

    if l_args.summary_line:
        print(render_summary(l_issues))

    if l_issues:
        print("[SIMD-ALLOCATOR-CONSUMER-SEAM-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[SIMD-ALLOCATOR-CONSUMER-SEAM-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
