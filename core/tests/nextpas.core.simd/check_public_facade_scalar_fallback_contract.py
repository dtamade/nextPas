#!/usr/bin/env python3
"""Guard the stable SIMD public facade and scalar fallback contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FACADE_PATH = ROOT / "src/nextpas.core.simd.pas"
RUNTIME_PATH = ROOT / "src/nextpas.core.simd.runtime.pas"
DISPATCH_PATH = ROOT / "src/nextpas.core.simd.dispatch.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"
RUNNER_PATH = ROOT / "tests/nextpas.core.simd/nextpas.core.simd.test.lpr"
RUNTIME_TEST_PATH = ROOT / "tests/nextpas.core.simd/nextpas.core.simd.runtime.testcase.pas"

FORBIDDEN_DEFAULT_UNITS = (
    "nextpas.core.simd.static.avx2",
    "nextpas.core.simd.intrinsics.aes",
    "nextpas.core.simd.intrinsics.sha",
    "nextpas.core.simd.intrinsics.avx",
    "nextpas.core.simd.intrinsics.sse3",
    "nextpas.core.simd.intrinsics.sse41",
    "nextpas.core.simd.intrinsics.sse42",
    "nextpas.core.simd.intrinsics.avx512",
    "nextpas.core.simd.intrinsics.fma3",
    "nextpas.core.simd.intrinsics.neon",
    "nextpas.core.simd.intrinsics.rvv",
    "nextpas.core.simd.intrinsics.sve",
    "nextpas.core.simd.intrinsics.sve2",
    "nextpas.core.simd.intrinsics.lasx",
)

REQUIRED_RUNTIME_TOKENS = (
    "BuildDefaultRuntimeSnapshot",
    "aSnapshot.CurrentBackend := sbScalar",
    "aSnapshot.BestDispatchableBackend := sbScalar",
)

REQUIRED_DISPATCH_TOKENS = (
    "LBestBackend := sbScalar",
    "Result := sbScalar",
    "TrySetActiveBackend(sbScalar)",
)

REQUIRED_TEST_TOKENS = (
    "Test_PublicFacadeScalarFallback_Executes_With_RuntimeDispatch_Disabled",
    "SetVectorAsmEnabled(False)",
    "TrySetCurrentBackend(sbScalar)",
    "GetCurrentRuntimeSnapshot",
    "VecF32x4Add",
    "MemEqual",
    "SumBytes",
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


def first_uses_block(a_text: str) -> str:
    l_text = strip_pascal_comments(a_text)
    l_match = re.search(r"(?is)\buses\b(.*?);", l_text)
    if l_match is None:
        return ""
    return l_match.group(1).lower()


def require_no_default_unit_leaks(a_issues: list[str], a_path: Path) -> None:
    l_text = first_uses_block(read_text(a_path))
    for l_unit in FORBIDDEN_DEFAULT_UNITS:
        l_pattern = r"(?<![a-z0-9_])" + re.escape(l_unit) + r"(?![a-z0-9_])"
        if re.search(l_pattern, l_text):
            add_issue(a_issues, a_path, f"default entry imports forbidden unit `{l_unit}`")


def require_riscvv_opt_in_guard(a_issues: list[str]) -> None:
    l_text = strip_pascal_comments(read_text(FACADE_PATH))
    l_pattern = re.compile(
        r"\{\$IF\s+DEFINED\(SIMD_RISCV_AVAILABLE\)\s+AND\s+DEFINED\(SIMD_EXPERIMENTAL_RISCVV\)\}"
        r"\s*,\s*nextpas\.core\.simd\.riscvv\s*"
        r"\{\$ENDIF\}",
        re.IGNORECASE,
    )
    if l_pattern.search(l_text) is None:
        add_issue(
            a_issues,
            FACADE_PATH,
            "experimental RISCVV facade import must stay opt-in and keep the leading uses-list comma",
        )


def require_makefile_hook(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "check_public_facade_scalar_fallback_contract.py" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "audit target must run public facade scalar fallback contract")


def require_tokens(a_issues: list[str], a_path: Path, a_tokens: tuple[str, ...]) -> None:
    l_text = read_text(a_path)
    for l_token in a_tokens:
        if l_token not in l_text:
            add_issue(a_issues, a_path, f"missing token `{l_token}`")


def main() -> int:
    l_issues: list[str] = []

    require_no_default_unit_leaks(l_issues, FACADE_PATH)
    require_no_default_unit_leaks(l_issues, RUNNER_PATH)
    require_riscvv_opt_in_guard(l_issues)
    require_makefile_hook(l_issues)
    require_tokens(l_issues, RUNTIME_PATH, REQUIRED_RUNTIME_TOKENS)
    require_tokens(l_issues, DISPATCH_PATH, REQUIRED_DISPATCH_TOKENS)
    require_tokens(l_issues, RUNTIME_TEST_PATH, REQUIRED_TEST_TOKENS)

    if l_issues:
        print("[PUBLIC-FACADE-SCALAR-FALLBACK-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[PUBLIC-FACADE-SCALAR-FALLBACK-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
