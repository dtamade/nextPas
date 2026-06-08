#!/usr/bin/env python3
"""Guard SIMD's consumer-side truth for platform.memory aligned allocation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ALLOC_PATH = ROOT / "src/nextpas.core.simd.alloc.pas"
MEMUTILS_PATH = ROOT / "src/nextpas.core.simd.memutils.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"

REQUIRED_TRUTH_TOKENS = (
    "SimdAlloc platform.memory consumer integration truth:",
    "SIMD consumes only the platform.memory public aligned allocation seam",
    "SIMD must not depend on platform.memory fallback header layout or magic values",
    "SIMD native-ready claims must come from platform_aligned_alloc_is_native/platform_aligned_alloc_backend",
)

REQUIRED_PUBLIC_SEAM_TOKENS = (
    "nextpas.core.platform.memory",
    "platform_aligned_alloc",
    "platform_aligned_realloc",
    "platform_aligned_free",
)

FORBIDDEN_FALLBACK_INTERNAL_TOKENS = (
    "PPlatformAlignedAllocHeader",
    "TPlatformAlignedAllocHeader",
    "PLATFORM_ALIGNED_ALLOC_MAGIC",
    "RawPtr",
    "HeaderOf",
    "SysGetMem",
    "SysFreeMem",
    "GetMem",
    "FreeMem",
    "OrigPtr",
    "TAllocHeader",
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


def check_required_truth(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_TRUTH_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing platform.memory consumer truth token `{l_token}`")


def check_public_seam_consumption(a_issues: list[str]) -> None:
    for l_path in (ALLOC_PATH, MEMUTILS_PATH):
        l_text = read_text(l_path)
        for l_token in REQUIRED_PUBLIC_SEAM_TOKENS:
            if l_token not in l_text:
                add_issue(a_issues, l_path, f"missing public platform.memory seam token `{l_token}`")


def check_no_fallback_header_dependency(a_issues: list[str]) -> None:
    for l_path in (ALLOC_PATH, MEMUTILS_PATH):
        l_code = strip_pascal_comments(read_text(l_path))
        for l_token in FORBIDDEN_FALLBACK_INTERNAL_TOKENS:
            l_pattern = rf"(?<![A-Za-z0-9_]){re.escape(l_token)}(?![A-Za-z0-9_])"
            if re.search(l_pattern, l_code):
                add_issue(a_issues, l_path, f"depends on platform.memory fallback internal token `{l_token}`")


def check_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_simd_platform_memory_consumer_truth.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run platform.memory consumer truth contract")


def render_summary(a_issues: list[str]) -> str:
    return f"SIMD_PLATFORM_MEMORY_CONSUMER_TRUTH_SUMMARY issues={len(a_issues)}"


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check SIMD platform.memory consumer truth")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_args = l_parser.parse_args()

    l_issues: list[str] = []
    check_required_truth(l_issues)
    check_public_seam_consumption(l_issues)
    check_no_fallback_header_dependency(l_issues)
    check_makefile_hook(l_issues)

    if l_args.summary_line:
        print(render_summary(l_issues))

    if l_issues:
        print("[SIMD-PLATFORM-MEMORY-CONSUMER-TRUTH] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[SIMD-PLATFORM-MEMORY-CONSUMER-TRUTH] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
