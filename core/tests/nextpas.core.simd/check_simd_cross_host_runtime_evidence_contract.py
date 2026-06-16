#!/usr/bin/env python3
"""Guard SIMD cross-host runtime evidence source-contract."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DOC_PATH = ROOT / "tests/nextpas.core.simd/docs/cross_host_runtime_evidence_contract.md"
ALLOC_PATH = ROOT / "src/nextpas.core.simd.alloc.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"

REQUIRED_DOC_TOKENS = (
    "# SIMD Cross-Host Runtime Evidence Contract",
    "SIMD consumes only the platform.memory public aligned allocation seam",
    "Linux host runtime",
    "Wine smoke",
    "Windows native runtime",
    "POSIX native runtime",
    "forced compile",
    "native-ready truth remains provisional",
    "platform/native runner artifact",
    "Wine smoke is not native Windows runtime evidence",
    "fallback header internals are private platform.memory details",
)

REQUIRED_ALLOC_TOKENS = (
    "SimdAlloc cross-host runtime evidence truth:",
    "Linux host runtime evidence proves only the executing Linux runner",
    "Wine smoke is compatibility smoke, not native Windows runtime truth",
    "Windows/POSIX native-ready truth requires platform/native runner artifacts",
    "SIMD consumes only the platform.memory public aligned allocation seam",
)

FORBIDDEN_DOC_TOKENS = (
    "Windows native runtime ready",
    "POSIX native runtime ready",
    "Wine proves Windows",
)

FORBIDDEN_SIMD_SOURCE_TOKENS = (
    "PPlatformAlignedAllocHeader",
    "TPlatformAlignedAllocHeader",
    "PLATFORM_ALIGNED_ALLOC_MAGIC",
    "_aligned_malloc",
    "_aligned_realloc",
    "_aligned_free",
    "posix_memalign",
    "aligned_alloc",
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


def check_doc(a_issues: list[str]) -> None:
    if not DOC_PATH.exists():
        add_issue(a_issues, DOC_PATH, "missing cross-host runtime evidence contract")
        return

    l_text = read_text(DOC_PATH)
    for l_token in REQUIRED_DOC_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, DOC_PATH, f"missing cross-host evidence token `{l_token}`")

    for l_token in FORBIDDEN_DOC_TOKENS:
        if l_token in l_text:
            add_issue(a_issues, DOC_PATH, f"must not claim `{l_token}` without native runner artifact")


def check_alloc_truth(a_issues: list[str]) -> None:
    l_text = read_text(ALLOC_PATH)
    for l_token in REQUIRED_ALLOC_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, ALLOC_PATH, f"missing cross-host truth token `{l_token}`")

    l_code = strip_pascal_comments(l_text)
    for l_token in FORBIDDEN_SIMD_SOURCE_TOKENS:
        l_pattern = rf"(?<![A-Za-z0-9_]){re.escape(l_token)}(?![A-Za-z0-9_])"
        if re.search(l_pattern, l_code):
            add_issue(a_issues, ALLOC_PATH, f"depends on allocator internal/native token `{l_token}`")


def check_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_simd_cross_host_runtime_evidence_contract.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run cross-host runtime evidence contract")


def render_summary(a_issues: list[str]) -> str:
    return f"SIMD_CROSS_HOST_RUNTIME_EVIDENCE_SUMMARY issues={len(a_issues)}"


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check SIMD cross-host runtime evidence contract")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_args = l_parser.parse_args()

    l_issues: list[str] = []
    check_doc(l_issues)
    check_alloc_truth(l_issues)
    check_makefile_hook(l_issues)

    if l_args.summary_line:
        print(render_summary(l_issues))

    if l_issues:
        print("[SIMD-CROSS-HOST-RUNTIME-EVIDENCE-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[SIMD-CROSS-HOST-RUNTIME-EVIDENCE-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
