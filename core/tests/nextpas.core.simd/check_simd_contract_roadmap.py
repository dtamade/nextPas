#!/usr/bin/env python3
"""Smoke-check the SIMD backend/public-contract roadmap.

This is a source contract, not a feature-completeness proof. It keeps the
public documentation and backend disposition comments honest while the SIMD
roadmap evolves across x86 and non-x86 targets.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def read_text(a_rel: str) -> str:
    return (REPO_ROOT / a_rel).read_text(encoding="utf-8", errors="ignore")


def contains_all(a_text: str, a_tokens: list[str]) -> list[str]:
    l_lower = a_text.lower()
    return [l_token for l_token in a_tokens if l_token.lower() not in l_lower]


def require_tokens(a_errors: list[str], a_rel: str, a_tokens: list[str]) -> None:
    l_missing = contains_all(read_text(a_rel), a_tokens)
    if l_missing:
        a_errors.append(f"{a_rel}: missing tokens: {', '.join(l_missing)}")


def check_no_stable_disposition(a_errors: list[str], a_rel: str) -> None:
    l_text = read_text(a_rel)
    if re.search(r"(?im)^\s*//\s*Disposition:\s*STABLE\b", l_text):
        a_errors.append(f"{a_rel}: RVV/LASX placeholder intrinsics must not claim STABLE disposition")


def check_forbidden_gather_absence_claims(a_errors: list[str]) -> None:
    l_files = [
        "docs/simd/GOAL_TREE.md",
        "docs/simd/architecture-guide.md",
        "docs/simd/maintenance.md",
    ]
    l_patterns = [
        r"gather/scatter\s+(?:is\s+)?(?:completely\s+)?missing",
        r"gather/scatter\s+完全缺失",
        r"gather\s*/\s*scatter\s+完全缺失",
        r"聚集\s*/\s*分散\s+完全缺失",
    ]
    for l_rel in l_files:
        l_text = read_text(l_rel)
        for l_pattern in l_patterns:
            if re.search(l_pattern, l_text, re.IGNORECASE):
                a_errors.append(f"{l_rel}: gather/scatter must be documented as partial coverage, not absent")


def check_public_abi_has_no_future_surface(a_errors: list[str]) -> None:
    l_files = [
        "src/nextpas.core.simd.public_abi.intf.inc",
        "src/nextpas.core.simd.public_abi.impl.inc",
    ]
    l_patterns = [
        r"\b(?:TF16|THalf|TVecF16|TVecBF16)\b",
        r"\bF16\b",
        r"\bBF16\b",
        r"\bGather\b",
        r"\bScatter\b",
        r"\bTranspose\b",
        r"\bLaneTranspose\b",
    ]
    for l_rel in l_files:
        l_text = read_text(l_rel)
        for l_pattern in l_patterns:
            if re.search(l_pattern, l_text):
                a_errors.append(
                    f"{l_rel}: public ABI must not expose gather/F16/transpose before focused API tests"
                )
                break


def main() -> int:
    l_errors: list[str] = []

    require_tokens(
        l_errors,
        "docs/simd/GOAL_TREE.md",
        [
            "G13",
            "SIMD contract qualification roadmap",
            "512-bit record alignment",
            "NEON public backend status",
            "RISC-V V and LoongArch/LASX",
            "gather/scatter partial coverage",
            "F16/half precision design",
            "transpose API boundary",
            "NEON AArch64 ABI GPR-to-vector",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/architecture-guide.md",
        [
            "512-bit record alignment contract",
            "FPC RECORDMIN=32",
            "ordinary record/stack/array/object fields",
            "SimdAlloc(..., sa64)",
            "AlignedAlloc(..., SIMD_ALIGN_64)",
            "NEON public backend status",
            "default scalar fallback",
            "NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM",
            "NEXTPAS_SIMD_ENABLE_NEON_ASM",
            "NEXTPAS_SIMD_NEON_ASM_COMPILER_READY",
            "FPC 3.3.1+",
            "AArch64 ABI",
            "GPR-to-vector",
            "RISC-V V and LoongArch/LASX are experimental/stub",
            "gather/scatter partial coverage",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "avx2_gather",
            "public facade",
            "F16/half precision design",
            "TF16",
            "F16C",
            "AVX512BF16",
            "NEON FP16",
            "scalar fallback",
            "transpose API boundary",
            "linalg matrix transpose",
            "SIMD lane transpose",
            "public ABI wrapper",
            "tests before ABI changes",
            "GatherSelect",
            "ScatterSelect",
        ],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.utils.pas",
        ["VecF32x4GatherSelect", "VecI32x4GatherSelect", "VecF32x4ScatterSelect", "VecI32x4ScatterSelect"],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.avx2.pas",
        ["avx2_gather_epi32", "avx2_gather_epi64", "avx2_gather_ps", "avx2_gather_pd"],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.linalg.pas",
        ["TSimdF32Matrix.Transpose", "TSimdF64Matrix.Transpose"],
    )

    require_tokens(
        l_errors,
        "docs/simd/intrinsics.neon.md",
        [
            "default public backend state is scalar fallback",
            "inline asm is opt-in",
            "FPC 3.3.1+",
            "NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM",
            "NEXTPAS_SIMD_ENABLE_NEON_ASM",
            "NEXTPAS_SIMD_NEON_ASM_COMPILER_READY",
            "AArch64 ABI",
            "GPR-to-vector",
            "benchmark",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/README.md",
        [
            "NEON default public status",
            "default scalar fallback",
            "asm opt-in",
            "FPC 3.3.1+",
            "AArch64 ABI GPR-to-vector",
        ],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.neon.pas",
        ["Disposition: Experimental Isolated", "stub", "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS"],
    )
    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.rvv.pas",
        ["Disposition: Experimental Isolated", "stub", "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS"],
    )
    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.lasx.pas",
        ["Disposition: Experimental Isolated", "stub", "LoongArch/LASX", "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS"],
    )

    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.neon.pas")
    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.rvv.pas")
    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.lasx.pas")
    check_forbidden_gather_absence_claims(l_errors)
    check_public_abi_has_no_future_surface(l_errors)

    if l_errors:
        print("[SIMD-CONTRACT-ROADMAP] FAIL")
        for l_error in l_errors:
            print(f"  - {l_error}")
        return 1

    print("[SIMD-CONTRACT-ROADMAP] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
