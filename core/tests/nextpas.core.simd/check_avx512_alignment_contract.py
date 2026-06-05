#!/usr/bin/env python3
"""Guard AVX-512 512-bit alignment source contracts."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

AVX512_BACKEND_GLOBS = (
    "src/nextpas.core.simd.avx512.pas",
    "src/nextpas.core.simd.avx512.*.inc",
)

ALIGNED_512_MEMORY_MNEMONICS = re.compile(
    r"\b(?:vmovaps|vmovapd|vmovdqa(?:32|64)?)\b[^\n;]*\[[^\]\n]+\]",
    re.IGNORECASE,
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8")


def collect_avx512_backend_paths() -> list[Path]:
    l_paths: set[Path] = set()
    for l_glob in AVX512_BACKEND_GLOBS:
        l_paths.update(ROOT.glob(l_glob))
    return sorted(l_paths)


def routine_block(a_text: str, a_name: str) -> str:
    l_headers = list(re.finditer(
        rf"\b(?:function|procedure)\s+{re.escape(a_name)}\b.*?;",
        a_text,
        re.IGNORECASE | re.DOTALL,
    ))
    if not l_headers:
        return ""
    l_implementation_pos = a_text.lower().find("implementation")
    l_header = l_headers[-1]
    for l_candidate in l_headers:
        if l_candidate.start() > l_implementation_pos:
            l_header = l_candidate
            break
    l_next = re.search(
        r"\n(?:function|procedure|initialization|end\.)\b",
        a_text[l_header.end():],
        re.IGNORECASE,
    )
    if l_next is None:
        return a_text[l_header.end():]
    return a_text[l_header.end(): l_header.end() + l_next.start()]


def add_issue(a_issues: list[str], a_path: Path, a_message: str) -> None:
    a_issues.append(f"{a_path.relative_to(ROOT)}: {a_message}")


def check_backend_mnemonics(a_issues: list[str]) -> None:
    for l_path in collect_avx512_backend_paths():
        for l_line_no, l_line in enumerate(read_text(l_path).splitlines(), start=1):
            l_code = l_line.split("//", 1)[0]
            l_match = ALIGNED_512_MEMORY_MNEMONICS.search(l_code)
            if l_match is not None:
                add_issue(
                    a_issues,
                    l_path,
                    f"{l_line_no}: forbidden aligned 512-bit memory operand `{l_match.group(0).strip()}`",
                )


def check_base_contract(a_issues: list[str]) -> None:
    l_path = ROOT / "src/nextpas.core.simd.base.pas"
    l_text = read_text(l_path)
    l_lower = l_text.lower()
    if "编译器通常会保证足够对齐" in l_text:
        add_issue(a_issues, l_path, "ordinary stack/record 64-byte alignment claim is still present")
    if "ordinary record" not in l_lower:
        add_issue(a_issues, l_path, "512-bit contract must explicitly mention ordinary record storage")
    if "not guarantee 64-byte" not in l_lower:
        add_issue(a_issues, l_path, "512-bit contract must explicitly deny a 64-byte address guarantee")
    if "simdalloc" not in l_lower or "sa64" not in l_lower:
        add_issue(a_issues, l_path, "512-bit contract must point callers to SimdAlloc(..., sa64)")


def check_intrinsics_base_contract(a_issues: list[str]) -> None:
    l_path = ROOT / "src/nextpas.core.simd.intrinsics.base.pas"
    l_text = read_text(l_path).lower()
    if "64-byte payload" not in l_text:
        add_issue(a_issues, l_path, "TM512 contract must distinguish payload size from storage alignment")
    if "not a 64-byte storage guarantee" not in l_text:
        add_issue(a_issues, l_path, "TM512 contract must deny ordinary storage 64-byte guarantee")


def check_aligned_intrinsics_assertions(a_issues: list[str]) -> None:
    l_path = ROOT / "src/nextpas.core.simd.intrinsics.avx512.pas"
    l_text = read_text(l_path)
    if "AssertAvx512AlignedPointer64" not in l_text:
        add_issue(a_issues, l_path, "missing 64-byte assertion helper for aligned AVX-512 pointer APIs")

    l_load_block = routine_block(l_text, "avx512_load_ps512")
    if "AssertAvx512AlignedPointer64(Ptr" not in l_load_block:
        add_issue(a_issues, l_path, "avx512_load_ps512 must assert Ptr is 64-byte aligned")

    l_store_block = routine_block(l_text, "avx512_store_ps512")
    if "AssertAvx512AlignedPointer64(@Dest" not in l_store_block:
        add_issue(a_issues, l_path, "avx512_store_ps512 must assert Dest is 64-byte aligned")


def main() -> int:
    l_issues: list[str] = []
    check_backend_mnemonics(l_issues)
    check_base_contract(l_issues)
    check_intrinsics_base_contract(l_issues)
    check_aligned_intrinsics_assertions(l_issues)

    if l_issues:
        print("[AVX512-ALIGNMENT-CONTRACT] FAILED")
        for l_issue in l_issues:
            print(f"- {l_issue}")
        return 1

    print("[AVX512-ALIGNMENT-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
