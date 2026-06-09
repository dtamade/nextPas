#!/usr/bin/env python3
"""Guard SIMD allocator runtime truth matrix source-contract."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MATRIX_PATH = ROOT / "tests/nextpas.core.simd/docs/allocator_runtime_truth_matrix.md"
ALLOC_PATH = ROOT / "src/nextpas.core.simd.alloc.pas"
CONSUMER_CHECK_PATH = ROOT / "tests/nextpas.core.simd/check_simd_platform_memory_consumer_truth.py"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"

REQUIRED_MATRIX_TOKENS = (
    "# SIMD Allocator Runtime Truth Matrix",
    "SIMD consumes only nextpas.core.platform.memory public aligned allocation seam",
    "fallback header internals are platform.memory private implementation details",
    "Linux/POSIX host runtime",
    "Windows native runtime",
    "POSIX native runtime",
    "fallback-only runtime",
    "forced compile",
    "Wine",
    "platform/native runner",
    "not native runtime evidence",
    "SimdAlloc",
    "SimdRealloc",
)

REQUIRED_ALLOC_TOKENS = (
    "SimdAlloc runtime truth matrix:",
    "SIMD host runtime evidence is limited to the runner that actually executes the test",
    "Windows/POSIX native runtime truth requires platform/native runner evidence",
)

REQUIRED_CONSUMER_CHECK_TOKENS = (
    "allocator_runtime_truth_matrix.md",
    "SIMD consumes only nextpas.core.platform.memory public aligned allocation seam",
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def rel(a_path: Path) -> str:
    return str(a_path.relative_to(ROOT))


def add_issue(a_issues: list[str], a_path: Path, a_message: str) -> None:
    a_issues.append(f"{rel(a_path)}: {a_message}")


def check_matrix_doc(a_issues: list[str]) -> None:
    if not MATRIX_PATH.exists():
        add_issue(a_issues, MATRIX_PATH, "missing SIMD allocator runtime truth matrix")
        return

    l_text = read_text(MATRIX_PATH)
    for l_token in REQUIRED_MATRIX_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, MATRIX_PATH, f"missing runtime truth matrix token `{l_token}`")


def check_alloc_truth_tokens(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_ALLOC_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing runtime truth matrix token `{l_token}`")


def check_consumer_checker_tokens(a_issues: list[str]) -> None:
    l_text = read_text(CONSUMER_CHECK_PATH)
    for l_token in REQUIRED_CONSUMER_CHECK_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, CONSUMER_CHECK_PATH, f"missing runtime truth matrix hook token `{l_token}`")


def check_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_simd_runtime_truth_matrix_contract.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run SIMD runtime truth matrix contract")


def render_summary(a_issues: list[str]) -> str:
    return f"SIMD_RUNTIME_TRUTH_MATRIX_SUMMARY issues={len(a_issues)}"


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check SIMD runtime truth matrix contract")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_args = l_parser.parse_args()

    l_issues: list[str] = []
    check_matrix_doc(l_issues)
    check_alloc_truth_tokens(l_issues)
    check_consumer_checker_tokens(l_issues)
    check_makefile_hook(l_issues)

    if l_args.summary_line:
        print(render_summary(l_issues))

    if l_issues:
        print("[SIMD-RUNTIME-TRUTH-MATRIX-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[SIMD-RUNTIME-TRUTH-MATRIX-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
