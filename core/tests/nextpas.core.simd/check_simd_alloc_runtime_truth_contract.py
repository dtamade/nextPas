#!/usr/bin/env python3
"""Guard the public SimdAlloc runtime truth across host families."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ALLOC_PATH = ROOT / "src/nextpas.core.simd.alloc.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"

REQUIRED_ALLOC_TRUTH_TOKENS = (
    "SimdAlloc runtime truth:",
    "Delegates storage ownership to nextpas.core.platform.memory",
    "SIMD does not declare raw Windows/POSIX allocator FFI",
    "Native/fallback backend truth is reported by platform_aligned_alloc_backend",
    "Wine or cross-compile evidence is forced-compile truth only",
)

FORBIDDEN_ALLOC_HOST_TOKENS = (
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
    "FreeMem",
    "GetMem",
)

REQUIRED_FALLBACK_TOKENS = (
    "nextpas.core.platform.memory",
    "platform_aligned_alloc",
    "platform_aligned_free",
    "platform_aligned_realloc",
    "SimdAlloc(",
    "SimdFree(",
    "SimdRealloc(",
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
    for l_token in REQUIRED_ALLOC_TRUTH_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing allocator truth token `{l_token}`")


def check_fallback_shape(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_FALLBACK_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing fallback allocator token `{l_token}`")


def check_no_host_allocator_claims(a_issues: list[str]) -> None:
    l_code = strip_pascal_comments(read_text(ALLOC_PATH))
    for l_token in FORBIDDEN_ALLOC_HOST_TOKENS:
        l_pattern = rf"(?<![A-Za-z0-9_]){re.escape(l_token)}(?![A-Za-z0-9_])"
        if re.search(l_pattern, l_code, flags=re.IGNORECASE):
            add_issue(a_issues, ALLOC_PATH, f"host allocator token `{l_token}` is present in executable code")


def check_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_simd_alloc_runtime_truth_contract.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run SimdAlloc runtime truth contract")


def render_summary(a_issues: list[str]) -> str:
    return f"SIMD_ALLOC_RUNTIME_TRUTH_SUMMARY issues={len(a_issues)}"


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check SimdAlloc runtime truth contract")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_args = l_parser.parse_args()

    l_issues: list[str] = []
    check_required_truth_tokens(l_issues)
    check_fallback_shape(l_issues)
    check_no_host_allocator_claims(l_issues)
    check_makefile_hook(l_issues)

    if l_args.summary_line:
        print(render_summary(l_issues))

    if l_issues:
        print("[SIMD-ALLOC-RUNTIME-TRUTH-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[SIMD-ALLOC-RUNTIME-TRUTH-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
