#!/usr/bin/env python3
"""Guard the SIMD CPUInfo layer and dispatch-consumer boundary.

CPUInfo is used by low-level SIMD dispatch and backend gates, so it must stay
free of L1 text helpers. Keep parsing helpers local to the CPUInfo layer until
the module registry deliberately reclassifies this sublayer.

AVX/AVX2/AVX-512 execution consumers must use the CPU/OS usable view instead of
raw CPUID or GenericRaw evidence. Raw evidence is diagnostic only.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CPUINFO_GLOB = "src/nextpas.core.simd.cpuinfo*.pas"
FORBIDDEN_UNITS = (
    "nextpas.core.text.conv",
    "nextpas.core.text.strings",
)
HELPER_INCLUDE = REPO_ROOT / "src/nextpas.core.simd.cpuinfo.helpers.inc"
REQUIRED_LOCAL_HELPERS = (
    "CpuInfoTrim",
    "CpuInfoLowerCaseAscii",
    "CpuInfoUpperCaseAscii",
    "CpuInfoStrToIntDef",
    "CpuInfoIntToStr",
    "CpuInfoBoolToStr",
    "CpuInfoIntToHex",
    "CpuInfoFormatFixed",
    "CpuInfoPosEx",
    "CpuInfoStringsAppend",
    "CpuInfoStringsJoin",
)
REQUIRED_HELPER_CONTRACT_TOKENS = (
    "CPUInfo-local helper subset only",
    "not a general text helper API",
    "prefer the CpuInfo* names",
)
CONSUMER_CONTRACTS = (
    (
        REPO_ROOT / "src/nextpas.core.hash.sha256.pas",
        (
            "nextpas.core.simd.cpuinfo",
            "HasAVX2 and LCPUInfo.X86.HasBMI2",
        ),
    ),
    (
        REPO_ROOT / "src/nextpas.core.tls.tls13.chacha20poly1305.pas",
        (
            "nextpas.core.simd.cpuinfo",
            "GChaCha20HasAVX2 := HasAVX2",
        ),
    ),
    (
        REPO_ROOT / "src/nextpas.core.simd.static.avx2.pas",
        (
            "nextpas.core.simd.cpuinfo.HasAVX2",
        ),
    ),
)
FORBIDDEN_CONSUMER_PATTERNS = (
    (re.compile(r"\bcpuid(?:ex)?\b", re.IGNORECASE), "raw CPUID probe"),
    (re.compile(r"\bGenericRaw\b", re.IGNORECASE), "GenericRaw execution gate"),
    (
        re.compile(r"\b\w+CPUInfo\s*\.\s*X86\s*\.\s*HasAVX(?:2|512F)?\b", re.IGNORECASE),
        "raw X86 AVX feature execution gate",
    ),
    (
        re.compile(r"\bGetCPUInfo\s*\.\s*X86\s*\.\s*HasAVX(?:2|512F)?\b", re.IGNORECASE),
        "raw GetCPUInfo.X86 AVX feature execution gate",
    ),
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def strip_pascal_comments(a_text: str) -> str:
    l_text = re.sub(r"\(\*.*?\*\)", "", a_text, flags=re.DOTALL)
    l_text = re.sub(r"\{.*?\}", "", l_text, flags=re.DOTALL)
    l_lines = [l_line.split("//", 1)[0] for l_line in l_text.splitlines()]
    return "\n".join(l_lines)


def collect_cpuinfo_units() -> list[Path]:
    return sorted(REPO_ROOT.glob(CPUINFO_GLOB))


def add_issue(a_issues: list[str], a_path: Path, a_message: str) -> None:
    a_issues.append(f"{a_path.relative_to(REPO_ROOT)}: {a_message}")


def check_forbidden_text_units(a_issues: list[str]) -> None:
    for l_path in collect_cpuinfo_units():
        l_text = read_text(l_path)
        for l_unit in FORBIDDEN_UNITS:
            l_pattern = re.compile(rf"\b{re.escape(l_unit)}\b", re.IGNORECASE)
            for l_match in l_pattern.finditer(l_text):
                l_line_no = l_text.count("\n", 0, l_match.start()) + 1
                add_issue(
                    a_issues,
                    l_path,
                    f"{l_line_no}: forbidden L1 dependency `{l_unit}`",
                )


def check_local_helper_contract(a_issues: list[str]) -> None:
    if not HELPER_INCLUDE.exists():
        a_issues.append(f"{HELPER_INCLUDE.relative_to(REPO_ROOT)}: missing local L0 helper include")
        return

    l_text = read_text(HELPER_INCLUDE)
    for l_helper in REQUIRED_LOCAL_HELPERS:
        if re.search(rf"\b{re.escape(l_helper)}\b", l_text) is None:
            add_issue(a_issues, HELPER_INCLUDE, f"missing local L0 helper `{l_helper}`")
    for l_token in REQUIRED_HELPER_CONTRACT_TOKENS:
        if l_token not in l_text:
            add_issue(a_issues, HELPER_INCLUDE, f"missing helper contract token `{l_token}`")


def check_consumer_dispatch_contracts(a_issues: list[str]) -> None:
    for l_path, l_required_tokens in CONSUMER_CONTRACTS:
        if not l_path.exists():
            a_issues.append(f"{l_path.relative_to(REPO_ROOT)}: missing dispatch consumer")
            continue

        l_text = read_text(l_path)
        l_code = strip_pascal_comments(l_text)

        for l_token in l_required_tokens:
            if l_token not in l_text:
                add_issue(a_issues, l_path, f"missing usable CPUInfo dispatch token `{l_token}`")

        for l_pattern, l_label in FORBIDDEN_CONSUMER_PATTERNS:
            for l_match in l_pattern.finditer(l_code):
                l_line_no = l_code.count("\n", 0, l_match.start()) + 1
                add_issue(a_issues, l_path, f"{l_line_no}: forbidden {l_label} `{l_match.group(0)}`")


def main() -> int:
    l_issues: list[str] = []
    check_forbidden_text_units(l_issues)
    check_local_helper_contract(l_issues)
    check_consumer_dispatch_contracts(l_issues)

    if l_issues:
        print("[CPUINFO-BOUNDARY-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[CPUINFO-BOUNDARY-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
