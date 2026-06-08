#!/usr/bin/env python3
"""Guard the static AVX2 misalignment proof surface.

The static AVX2 unit is an opt-in import-time fail-close backend. It must not be
pulled into the default SIMD runner because non-AVX2 hosts should still run the
ordinary scalar/runtime tests. Keep its misalignment smoke as an explicit target.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEST_PATH = ROOT / "tests/nextpas.core.simd/test_static_avx2_misalignment.pas"
PROBE_PATH = ROOT / "tests/nextpas.core.simd/probe_static_avx2_usable.pas"
MAKEFILE_PATH = ROOT / "tests/nextpas.core.simd/Makefile"
DEFAULT_RUNNER_PATH = ROOT / "tests/nextpas.core.simd/nextpas.core.simd.test.lpr"
STATIC_UNIT_PATH = ROOT / "src/nextpas.core.simd.static.avx2.pas"

REQUIRED_TEST_TOKENS = (
    "nextpas.core.simd.static.avx2",
    "HasAVX2",
    "MisalignedPtr",
    "CheckF32x4",
    "CheckF32x8",
    "CheckF64x2",
    "0 unfreed memory blocks",
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def rel(a_path: Path) -> str:
    return str(a_path.relative_to(ROOT))


def add_issue(a_issues: list[str], a_path: Path, a_message: str) -> None:
    a_issues.append(f"{rel(a_path)}: {a_message}")


def require_test_program(a_issues: list[str]) -> None:
    if not TEST_PATH.exists():
        add_issue(a_issues, TEST_PATH, "missing static AVX2 misalignment smoke")
        return

    l_text = read_text(TEST_PATH)
    for l_token in REQUIRED_TEST_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, TEST_PATH, f"missing token `{l_token}`")


def require_makefile_target(a_issues: list[str]) -> None:
    l_text = read_text(MAKEFILE_PATH)
    if "STATIC_AVX2_MISALIGNMENT_TEST" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "missing static AVX2 test binary variable")
    if "STATIC_AVX2_USABLE_PROBE" not in l_text:
        add_issue(a_issues, MAKEFILE_PATH, "missing usable AVX2 probe variable")
    if re.search(r"(?m)^static-avx2-misalignment:\s", l_text) is None:
        add_issue(a_issues, MAKEFILE_PATH, "missing static-avx2-misalignment target")
    if "-gh" not in l_text.split("static-avx2-misalignment:", 1)[-1]:
        add_issue(a_issues, MAKEFILE_PATH, "static AVX2 target must compile with heaptrc")
    if "/proc/cpuinfo" in l_text.split("static-avx2-misalignment:", 1)[-1]:
        add_issue(a_issues, MAKEFILE_PATH, "static AVX2 target must not use raw /proc/cpuinfo gate")


def require_usable_probe(a_issues: list[str]) -> None:
    if not PROBE_PATH.exists():
        add_issue(a_issues, PROBE_PATH, "missing usable AVX2 probe")
        return

    l_text = read_text(PROBE_PATH)
    if "HasAVX2" not in l_text:
        add_issue(a_issues, PROBE_PATH, "probe must use usable HasAVX2 gate")
    if "nextpas.core.simd.static.avx2" in l_text:
        add_issue(a_issues, PROBE_PATH, "probe must not import static.avx2")
    if "Halt(77)" not in l_text:
        add_issue(a_issues, PROBE_PATH, "probe must expose skip exit status")


def require_default_runner_exclusion(a_issues: list[str]) -> None:
    l_text = read_text(DEFAULT_RUNNER_PATH)
    if "nextpas.core.simd.static.avx2" in l_text:
        add_issue(a_issues, DEFAULT_RUNNER_PATH, "default runner must not import static.avx2")


def require_unaligned_mnemonics(a_issues: list[str]) -> None:
    l_text = read_text(STATIC_UNIT_PATH)
    for l_mnemonic in ("vmovups", "vmovupd"):
        if l_mnemonic not in l_text.lower():
            add_issue(a_issues, STATIC_UNIT_PATH, f"missing unaligned mnemonic `{l_mnemonic}`")
    if re.search(r"\bvmovap[sd]\b[^\n;]*\[[^\]\n]+\]", l_text, re.IGNORECASE):
        add_issue(a_issues, STATIC_UNIT_PATH, "must not use aligned AVX memory moves")


def main() -> int:
    l_issues: list[str] = []
    require_test_program(l_issues)
    require_makefile_target(l_issues)
    require_usable_probe(l_issues)
    require_default_runner_exclusion(l_issues)
    require_unaligned_mnemonics(l_issues)

    if l_issues:
        print("[STATIC-AVX2-MISALIGNMENT-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[STATIC-AVX2-MISALIGNMENT-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
