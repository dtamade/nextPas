#!/usr/bin/env python3
"""Check that experimental SIMD intrinsics stay isolated from default entry points."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


EXPERIMENTAL_UNITS = [
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
]

DEFAULT_ENTRY_FILES = [
    "src/nextpas.core.simd.pas",
    "src/nextpas.core.simd.intrinsics.pas",
    "tests/nextpas.core.simd/nextpas.core.simd.test.lpr",
    "tests/nextpas.core.simd/BuildOrTest.sh",
    "tests/nextpas.core.simd/buildOrTest.bat",
    "tests/nextpas.core.simd/collect_linux_simd_evidence.sh",
]

# Placeholder-heavy units that must keep an explicit runtime guard.
# Enforce current guard-token presence on every unit listed in
# EXPERIMENTAL_UNITS so experimental behavior cannot silently drift into
# default-callable semantics.
GUARDED_EXPERIMENTAL_FILES = [f"src/{l_unit}.pas" for l_unit in EXPERIMENTAL_UNITS]
REQUIRED_GUARD_TOKEN = "nextpas_simd_experimental_intrinsics"
X86_ONLY_RUNTIME_FAIL_CLOSE_FILES = [
    "src/nextpas.core.simd.intrinsics.avx.pas",
    "src/nextpas.core.simd.intrinsics.sse3.pas",
    "src/nextpas.core.simd.intrinsics.sse41.pas",
    "src/nextpas.core.simd.intrinsics.sse42.pas",
    "src/nextpas.core.simd.intrinsics.avx512.pas",
    "src/nextpas.core.simd.intrinsics.fma3.pas",
]
REQUIRED_X86_ONLY_RUNTIME_FAIL_CLOSE_TOKEN = "only qualified on x86/x86_64"
DEFAULT_OPT_IN_ACROSS_HOSTS_TOKENS = {
    "src/nextpas.core.simd.intrinsics.aes.pas": "remain opt-in across hosts",
    "src/nextpas.core.simd.intrinsics.sha.pas": "remain opt-in across hosts",
}
HOLD_RUNTIME_FAIL_CLOSE_TOKENS = {
    "src/nextpas.core.simd.intrinsics.sve.pas": "only qualified on aarch64 targets whose cpuinfo reports sve",
    "src/nextpas.core.simd.intrinsics.sve2.pas": "only qualified on aarch64 targets whose cpuinfo reports sve2",
    "src/nextpas.core.simd.intrinsics.lasx.pas": "only qualified on loongarch64 targets whose cpuinfo reports lasx",
}
QUALIFICATION_RUNTIME_FAIL_CLOSE_TOKENS = {
    "src/nextpas.core.simd.intrinsics.neon.pas": "only qualified on arm-class targets whose cpuinfo reports neon",
    "src/nextpas.core.simd.intrinsics.rvv.pas": "only qualified on risc-v targets whose cpuinfo reports rvv",
}
EXPERIMENTAL_TEST_RUNTIME_GUARD_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "{$IFNDEF CPUX86_64}",
        "requires a CPUX86_64 SHA-NI implementation path",
    ],
}
SHA_SOURCE_CONTRACT_FILE = "src/nextpas.core.simd.intrinsics.sha.pas"
AES_SOURCE_CONTRACT_FILE = "src/nextpas.core.simd.intrinsics.aes.pas"
SHA_PUBLIC_INTRINSIC_FUNCTIONS = [
    "sha_sha1msg1_epu32",
    "sha_sha1msg2_epu32",
    "sha_sha1nexte_epu32",
    "sha_sha1rnds4_epu32",
    "sha_sha256msg1_epu32",
    "sha_sha256msg2_epu32",
    "sha_sha256rnds2_epu32",
]
SHA_RAW_LEAF_PROCEDURES = [
    "RawSHA1Msg1Epu32",
    "RawSHA1Msg2Epu32",
    "RawSHA1NextEEpu32",
    "RawSHA1Rnds4Epu32",
    "RawSHA256Msg1Epu32",
    "RawSHA256Msg2Epu32",
    "RawSHA256Rnds2Epu32",
]
SHA_REQUIRED_CODE_TOKENS = [
    "nextpas_simd_experimental_intrinsics",
    "ensureexperimentalshaintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_sha",
]
AESENC_REQUIRED_CODE_TOKENS = [
    "ensureaesencintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_aes",
    "rawaesencsi128",
    "constref data",
]
AESENCLAST_REQUIRED_CODE_TOKENS = [
    "ensureaesenclastintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_aes",
    "rawaesenclastsi128",
    "constref data",
]
AESDEC_REQUIRED_CODE_TOKENS = [
    "ensureaesdecintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_aes",
    "rawaesdecsi128",
    "constref data",
]
AESDECLAST_REQUIRED_CODE_TOKENS = [
    "ensureaesdeclastintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_aes",
    "rawaesdeclastsi128",
    "constref data",
]
AESKEYGENASSIST_REQUIRED_CODE_TOKENS = [
    "ensureaeskeygenassistintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_aes",
    "isaeskeygenassistrconsupported",
    "rawaeskeygenassistsi128",
    "constref key",
]
AESIMC_REQUIRED_CODE_TOKENS = [
    "ensureaesimcintrinsicsavailable",
    "{$IFNDEF CPUX86_64}",
    "simd_has_aes",
    "rawaesimcsi128",
    "constref data",
]
AESENC_SEMANTIC_VECTOR_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "test_aes_aesenc_si128_aesnisemanticvector",
        "requireaesencintrinsicsavailable",
        "7a",
        "43",
        "only test_aes_aesenc_si128_aesnisemanticvector proves one aes-ni semantic vector",
    ],
}
AESENCLAST_SEMANTIC_VECTOR_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "test_aes_aesenclast_si128_aesnisemanticvector",
        "requireaesenclastintrinsicsavailable",
        "73",
        "34",
        "only test_aes_aesenclast_si128_aesnisemanticvector proves one aes-ni semantic vector",
    ],
}
AESDEC_SEMANTIC_VECTOR_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "test_aes_aesdec_si128_aesnisemanticvector",
        "requireaesdecintrinsicsavailable",
        "03",
        "4e",
        "only test_aes_aesdec_si128_aesnisemanticvector proves one aes-ni semantic vector",
    ],
}
AESDECLAST_SEMANTIC_VECTOR_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "test_aes_aesdeclast_si128_aesnisemanticvector",
        "requireaesdeclastintrinsicsavailable",
        "42",
        "ca",
        "only test_aes_aesdeclast_si128_aesnisemanticvector proves one aes-ni semantic vector",
    ],
}
AESKEYGENASSIST_SEMANTIC_VECTOR_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "test_aes_aeskeygenassist_si128_aesnisemanticvectors",
        "requireaeskeygenassistintrinsicsavailable",
        "f2",
        "e1",
        "standard rcon values only",
    ],
}
AESIMC_SEMANTIC_VECTOR_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "test_aes_aesimc_si128_aesnisemanticvector",
        "requireaesimcintrinsicsavailable",
        "0a",
        "01",
        "only test_aes_aesimc_si128_aesnisemanticvector proves one aes-ni semantic vector",
    ],
}
AES_HARDWARE_SEMANTIC_BOUNDARY_TOKENS = {
    "tests/nextpas.core.simd/docs/intrinsics_coverage_workflow.md": [
        "aesenc, aesenclast, aesdec, aesdeclast, aeskeygenassist standard-rcon, and aesimc each have hardware semantic evidence",
        "aes_aesenc_si128",
        "aes_aesenclast_si128",
        "aes_aesdec_si128",
        "aes_aesdeclast_si128",
        "aes_aeskeygenassist_si128",
        "aes_aesimc_si128",
        "aes key schedule rcon subset",
        "unsupported rcon values fail-close",
    ],
    "docs/simd/checklist.md": [
        "aesenc, aesenclast, aesdec, aesdeclast, aeskeygenassist standard-rcon, and aesimc each have hardware semantic evidence",
        "aes_aesenc_si128",
        "aes_aesenclast_si128",
        "aes_aesdec_si128",
        "aes_aesdeclast_si128",
        "aes_aeskeygenassist_si128",
        "aes_aesimc_si128",
        "aes key schedule rcon subset",
        "unsupported rcon values fail-close",
    ],
    "docs/simd/closeout.md": [
        "aesenc, aesenclast, aesdec, aesdeclast, aeskeygenassist standard-rcon, and aesimc each have hardware semantic evidence",
        "aes_aesenc_si128",
        "aes_aesenclast_si128",
        "aes_aesdec_si128",
        "aes_aesdeclast_si128",
        "aes_aeskeygenassist_si128",
        "aes_aesimc_si128",
        "aes key schedule rcon subset",
        "unsupported rcon values fail-close",
    ],
}
EXPERIMENTAL_SEMANTIC_BOUNDARY_TOKENS = {
    "tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas": [
        "only test_aes_aesenc_si128_aesnisemanticvector proves one aes-ni semantic vector",
        "only test_aes_aesenclast_si128_aesnisemanticvector proves one aes-ni semantic vector",
        "only test_aes_aesdec_si128_aesnisemanticvector proves one aes-ni semantic vector",
        "only test_aes_aesdeclast_si128_aesnisemanticvector proves one aes-ni semantic vector",
        "test_aes_aeskeygenassist_si128_aesnisemanticvectors proves aes-ni semantic vectors for standard rcon values only",
        "only test_aes_aesimc_si128_aesnisemanticvector proves one aes-ni semantic vector",
        "sha smoke-only availability checks are not sha semantic vectors",
    ],
    "tests/nextpas.core.simd/docs/intrinsics_coverage_workflow.md": [
        "experimental closure proof is not stable public semantic proof",
        "aes_aeskeygenassist_si128",
        "aes_aesimc_si128",
        "aes key schedule rcon subset",
        "unsupported rcon values fail-close",
        "sha smoke-only availability checks are not sha semantic vectors",
    ],
}
FORBIDDEN_AES_COMPLETION_CLAIM_PATTERNS = {
    "tests/nextpas.core.simd/docs/intrinsics_coverage_workflow.md": [
        r"\ball\s+aes\s+intrinsics\s+(?:have|are)\s+.*semantic",
        r"\baes\s+family\s+(?:complete|full|fully)\b",
        r"\bcomplete\s+aes\s+family\b",
        r"\bfull\s+aes(?:-ni)?\s+semantic",
    ],
    "docs/simd/checklist.md": [
        r"\ball\s+aes\s+intrinsics\s+(?:have|are)\s+.*semantic",
        r"\baes\s+family\s+(?:complete|full|fully)\b",
        r"\bcomplete\s+aes\s+family\b",
        r"\bfull\s+aes(?:-ni)?\s+semantic",
    ],
    "docs/simd/closeout.md": [
        r"\ball\s+aes\s+intrinsics\s+(?:have|are)\s+.*semantic",
        r"\baes\s+family\s+(?:complete|full|fully)\b",
        r"\bcomplete\s+aes\s+family\b",
        r"\bfull\s+aes(?:-ni)?\s+semantic",
    ],
}
EXPERIMENTAL_RUNNER_FAIL_CLOSE_TOKENS = {
    "src/nextpas.core.simd.intrinsics.aes.pas": [
        "NEXTPAS_SIMD_TEST_FORCE_NONX86_AES_FAILCLOSE",
        "test-only non-x86 AES fail-close hook",
    ],
    "tests/nextpas.core.simd.intrinsics.experimental/BuildOrTest.sh": [
        "check_sha_default_failclose",
        "check_aeskeygenassist_unsupported_failclose",
        "check_aes_forced_nonx86_import_failclose",
        "check_aes_nonx86_import_failclose",
        "SHA-DEFAULT-FAILCLOSE",
        "AESKEYGENASSIST-UNSUPPORTED-FAILCLOSE",
        "AES-FORCED-NONX86-IMPORT-FAILCLOSE",
        "AES-NONX86-IMPORT-FAILCLOSE",
        "-dNEXTPAS_SIMD_TEST_FORCE_NONX86_AES_FAILCLOSE",
        "expected exit 217",
    ],
    "tests/nextpas.core.simd.intrinsics.experimental/test_sha_default_failclose.pas": [
        "sha_sha1msg1_epu32",
    ],
    "tests/nextpas.core.simd.intrinsics.experimental/test_aeskeygenassist_unsupported_failclose.pas": [
        "aes_aeskeygenassist_si128",
        "$7F",
    ],
    "tests/nextpas.core.simd.intrinsics.experimental/test_aes_nonx86_import_failclose.pas": [
        "non-x86 import/fail-close probe",
        "nextpas.core.simd.intrinsics.aes",
        "aes_aesenc_si128",
    ],
    "tests/nextpas.core.simd/docker/run_multiarch_qemu.sh": [
        "BuildOrTest.sh nonx86-aes-import-failclose",
        "non-x86 AES import/fail-close",
    ],
    "tests/nextpas.core.simd/docs/intrinsics_coverage_workflow.md": [
        "forced non-x86 AES import/fail-close",
        "not real non-x86 runtime evidence",
    ],
    "docs/simd/GOAL_TREE.md": [
        "forced non-x86 AES import/fail-close",
        "not non-x86 runtime evidence",
    ],
    "docs/simd/checklist.md": [
        "forced non-x86 AES import/fail-close",
        "not real non-x86 runtime evidence",
    ],
    "docs/simd/closeout.md": [
        "forced non-x86 AES import/fail-close",
        "not real non-x86 runtime evidence",
    ],
}
FORBIDDEN_DEFAULT_DEFINE_PATTERNS = [
    r"(?i)-dNEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS\b",
    r"(?i)\{\$DEFINE\s+NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS\}",
]
FORCED_NONX86_AES_DEFINE = "-dNEXTPAS_SIMD_TEST_FORCE_NONX86_AES_FAILCLOSE"
FORCED_NONX86_AES_RUNNER_FILE = "tests/nextpas.core.simd.intrinsics.experimental/BuildOrTest.sh"


def _scan_leaks(a_repo_root: Path, a_entry_files: list[str], a_units: list[str]) -> dict[str, list[str]]:
    l_leaks: dict[str, list[str]] = {}
    for l_rel in a_entry_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        l_hit_units: list[str] = []
        for l_unit in a_units:
            # Token-aware match: avoid false positives like intrinsics.avx vs intrinsics.avx2.
            l_pattern = r"(?<![a-z0-9_])" + re.escape(l_unit) + r"(?![a-z0-9_])"
            if re.search(l_pattern, l_text):
                l_hit_units.append(l_unit)
        if l_hit_units:
            l_leaks[l_rel] = sorted(l_hit_units)
    return l_leaks


def _scan_guard_markers(a_repo_root: Path, a_files: list[str], a_token: str) -> list[str]:
    l_missing: list[str] = []
    for l_rel in a_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        if a_token not in l_text:
            l_missing.append(l_rel)
    return sorted(l_missing)


def _scan_forbidden_default_defines(a_repo_root: Path, a_files: list[str], a_patterns: list[str]) -> list[str]:
    l_hits: list[str] = []
    for l_rel in a_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore")
        for l_pattern in a_patterns:
            if re.search(l_pattern, l_text):
                l_hits.append(l_rel)
                break
    return sorted(l_hits)


def _extract_shell_function(a_text: str, a_name: str) -> str:
    l_match = re.search(
        rf"(?ms)^{re.escape(a_name)}\(\)\s*\{{.*?(?=^[A-Za-z0-9_]+\(\)\s*\{{|\Z)",
        a_text,
    )
    return l_match.group(0) if l_match else ""


def _extract_shell_case_branch(a_text: str, a_label_pattern: str) -> str:
    l_match = re.search(
        rf"(?ms)^\s*{a_label_pattern}\)\s*.*?(?=^\s*[A-Za-z0-9_*|?-]+\)\s*$|^\s*esac\b)",
        a_text,
    )
    return l_match.group(0) if l_match else ""


def _scan_forced_nonx86_aes_define_scope(a_repo_root: Path) -> list[str]:
    l_rel = FORCED_NONX86_AES_RUNNER_FILE
    l_path = a_repo_root / l_rel
    if not l_path.is_file():
        return [l_rel]

    l_text = l_path.read_text(encoding="utf-8", errors="ignore")
    l_build_runner = _extract_shell_function(l_text, "build_runner")
    l_check_runner = _extract_shell_function(l_text, "check_aes_forced_nonx86_import_failclose")
    l_probe_action_branch = _extract_shell_case_branch(l_text, "nonx86-aes-import-failclose")
    l_test_branch = _extract_shell_case_branch(l_text, r"test\|test-all")
    l_define_count = l_text.count(FORCED_NONX86_AES_DEFINE)
    l_scoped_define_count = l_check_runner.count(FORCED_NONX86_AES_DEFINE)
    l_issues: list[str] = []

    if FORCED_NONX86_AES_DEFINE in l_build_runner:
        l_issues.append(f"{l_rel}: force define must not be in build_runner")
    if l_define_count != 1:
        l_issues.append(f"{l_rel}: force define must appear exactly once")
    if l_define_count != l_scoped_define_count:
        l_issues.append(f"{l_rel}: force define appears outside AES non-x86 probe")
    if FORCED_NONX86_AES_DEFINE not in l_check_runner:
        l_issues.append(f"{l_rel}: force define must stay scoped to AES non-x86 probe")
    if "check_aes_nonx86_import_failclose" not in l_probe_action_branch:
        l_issues.append(f"{l_rel}: nonx86-aes-import-failclose action must call AES non-x86 probe")
    if "check_aes_nonx86_import_failclose" not in l_test_branch:
        l_issues.append(f"{l_rel}: test/test-all must include AES non-x86 probe")

    return sorted(l_issues)


def _scan_x86_only_runtime_fail_close_markers(a_repo_root: Path, a_files: list[str], a_token: str) -> list[str]:
    l_missing: list[str] = []
    for l_rel in a_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        if a_token not in l_text:
            l_missing.append(l_rel)
    return sorted(l_missing)


def _scan_required_runtime_fail_close_tokens(a_repo_root: Path, a_file_tokens: dict[str, str]) -> list[str]:
    l_missing: list[str] = []
    for l_rel, l_token in a_file_tokens.items():
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        if l_token not in l_text:
            l_missing.append(l_rel)
    return sorted(l_missing)


def _scan_required_test_runtime_guard_tokens(a_repo_root: Path, a_file_tokens: dict[str, list[str]]) -> list[str]:
    l_missing: list[str] = []
    for l_rel, l_tokens in a_file_tokens.items():
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore")
        l_text_lower = l_text.lower()
        for l_token in l_tokens:
            if l_token.lower() not in l_text_lower:
                l_missing.append(l_rel)
                break
    return sorted(l_missing)


def _mask_pascal_gap_char(a_char: str) -> str:
    if a_char in {"\n", "\r"}:
        return a_char
    return " "


def _strip_pascal_non_code(a_text: str) -> str:
    l_chars = list(a_text)
    l_len = len(l_chars)
    l_idx = 0

    while l_idx < l_len:
        l_char = l_chars[l_idx]
        l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""

        if l_char == "'":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                l_chars[l_idx] = _mask_pascal_gap_char(l_char)
                if l_char == "'":
                    if l_next == "'":
                        l_chars[l_idx + 1] = " "
                        l_idx += 2
                        continue
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "{" and l_next != "$":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_chars[l_idx] = _mask_pascal_gap_char(l_char)
                if l_char == "}":
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "(" and l_next == "*":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                if l_char == "*" and l_next == ")":
                    l_chars[l_idx] = " "
                    l_chars[l_idx + 1] = " "
                    l_idx += 2
                    break
                l_chars[l_idx] = _mask_pascal_gap_char(l_char)
                l_idx += 1
            continue

        if l_char == "/" and l_next == "/":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                if l_char in {"\n", "\r"}:
                    l_idx += 1
                    break
                l_chars[l_idx] = " "
                l_idx += 1
            continue

        l_idx += 1

    return "".join(l_chars)


def _scan_required_text_tokens(a_repo_root: Path, a_file_tokens: dict[str, list[str]]) -> list[str]:
    l_missing: list[str] = []
    for l_rel, l_tokens in a_file_tokens.items():
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        for l_token in l_tokens:
            if l_token.lower() not in l_text:
                l_missing.append(l_rel)
                break
    return sorted(l_missing)


def _scan_forbidden_text_patterns(a_repo_root: Path, a_file_patterns: dict[str, list[str]]) -> list[str]:
    l_hits: list[str] = []
    for l_rel, l_patterns in a_file_patterns.items():
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        for l_pattern in l_patterns:
            if re.search(l_pattern, l_text, flags=re.IGNORECASE):
                l_hits.append(l_rel)
                break
    return sorted(l_hits)


def _extract_pascal_routine(a_code: str, a_name: str) -> str:
    l_impl_idx = a_code.lower().find("implementation")
    l_search_code = a_code[l_impl_idx:] if l_impl_idx >= 0 else a_code
    l_start_match = re.search(
        rf"\b(?:procedure|function)\s+{re.escape(a_name)}\b",
        l_search_code,
        flags=re.IGNORECASE,
    )
    if l_start_match is None:
        return ""

    l_end_match = re.search(r"\bend\s*;", l_search_code[l_start_match.start():], flags=re.IGNORECASE)
    if l_end_match is None:
        return l_search_code[l_start_match.start():]

    l_end = l_start_match.start() + l_end_match.end()
    return l_search_code[l_start_match.start():l_end]


def _check_required_patterns(a_text: str, a_patterns: dict[str, str]) -> list[str]:
    l_missing: list[str] = []
    for l_label, l_pattern in a_patterns.items():
        if not re.search(l_pattern, a_text, flags=re.IGNORECASE):
            l_missing.append(l_label)
    return l_missing


def _scan_sha_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / SHA_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {
            "missing_code_tokens": [SHA_SOURCE_CONTRACT_FILE],
            "public_assembler_functions": list(SHA_PUBLIC_INTRINSIC_FUNCTIONS),
            "missing_raw_constref_signatures": list(SHA_RAW_LEAF_PROCEDURES),
        }

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens = [
        l_token for l_token in SHA_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]
    l_public_asm_functions: list[str] = []
    for l_name in SHA_PUBLIC_INTRINSIC_FUNCTIONS:
        l_pattern = re.compile(
            rf"\bfunction\s+{re.escape(l_name)}\b[\s\S]*?:\s*TM128\s*;\s*assembler\b",
            re.IGNORECASE,
        )
        if l_pattern.search(l_code):
            l_public_asm_functions.append(l_name)

    l_missing_raw_constref_signatures: list[str] = []
    for l_name in SHA_RAW_LEAF_PROCEDURES:
        l_pattern = re.compile(
            rf"\bprocedure\s+{re.escape(l_name)}\s*\(\s*constref\b",
            re.IGNORECASE,
        )
        if not l_pattern.search(l_code):
            l_missing_raw_constref_signatures.append(l_name)

    return {
        "missing_code_tokens": sorted(l_missing_tokens),
        "public_assembler_functions": sorted(l_public_asm_functions),
        "missing_raw_constref_signatures": sorted(l_missing_raw_constref_signatures),
    }


def _scan_aesenc_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / AES_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {"missing_code_tokens": [AES_SOURCE_CONTRACT_FILE]}

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens: list[str] = [
        l_token for l_token in AESENC_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]

    l_guard_body = _extract_pascal_routine(l_code, "EnsureAESENCIntrinsicsAvailable").lower()
    l_raw_body = _extract_pascal_routine(l_code, "RawAESENCSi128").lower()
    l_wrapper_body = _extract_pascal_routine(l_code, "aes_aesenc_si128").lower()

    if not l_guard_body:
        l_missing_tokens.append("EnsureAESENCIntrinsicsAvailable body")
    if not l_raw_body:
        l_missing_tokens.append("RawAESENCSi128 body")
    if not l_wrapper_body:
        l_missing_tokens.append("aes_aesenc_si128 body")

    l_missing_tokens.extend(
        _check_required_patterns(
            l_guard_body,
            {
                "EnsureAESENCIntrinsicsAvailable calls opt-in guard": r"\bensureexperimentalintrinsicsenabled\s*\(",
                "EnsureAESENCIntrinsicsAvailable has CPUX86_64 guard": r"\{\$IFNDEF\s+CPUX86_64\}",
                "EnsureAESENCIntrinsicsAvailable checks simd_has_aes": r"\bnot\s+simd_has_aes\b",
            },
        )
    )

    l_raw_patterns = {
        "RawAESENCSi128 constref/var signature": (
            r"\bprocedure\s+rawaesencsi128\s*\(\s*constref\s+data\s*,\s*round_key\s*:\s*tm128\s*;\s*"
            r"var\s+outvalue\s*:\s*tm128\s*\)"
        ),
        "movdqu (%rcx), %xmm0": r"\bmovdqu\s+\(%rcx\)\s*,\s*%xmm0\b",
        "movdqu (%rdx), %xmm1": r"\bmovdqu\s+\(%rdx\)\s*,\s*%xmm1\b",
        "movdqu (%rdi), %xmm0": r"\bmovdqu\s+\(%rdi\)\s*,\s*%xmm0\b",
        "movdqu (%rsi), %xmm1": r"\bmovdqu\s+\(%rsi\)\s*,\s*%xmm1\b",
        "aesenc %xmm1, %xmm0": r"\baesenc\s+%xmm1\s*,\s*%xmm0\b",
        "movdqu %xmm0, (%rdx)": r"\bmovdqu\s+%xmm0\s*,\s*\(%rdx\)",
        "movdqu %xmm0, (%r8)": r"\bmovdqu\s+%xmm0\s*,\s*\(%r8\)",
    }
    l_missing_tokens.extend(_check_required_patterns(l_raw_body, l_raw_patterns))
    l_missing_tokens.extend(
        _check_required_patterns(
            l_wrapper_body,
            {
                "aes_aesenc_si128 calls EnsureAESENCIntrinsicsAvailable": r"\bensureaesencintrinsicsavailable\b",
                "aes_aesenc_si128 calls RawAESENCSi128": r"\brawaesencsi128\s*\(",
            },
        )
    )

    return {"missing_code_tokens": sorted(l_missing_tokens)}


def _scan_aesenclast_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / AES_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {"missing_code_tokens": [AES_SOURCE_CONTRACT_FILE]}

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens: list[str] = [
        l_token for l_token in AESENCLAST_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]

    l_guard_body = _extract_pascal_routine(l_code, "EnsureAESENCLASTIntrinsicsAvailable").lower()
    l_raw_body = _extract_pascal_routine(l_code, "RawAESENCLASTSi128").lower()
    l_wrapper_body = _extract_pascal_routine(l_code, "aes_aesenclast_si128").lower()

    if not l_guard_body:
        l_missing_tokens.append("EnsureAESENCLASTIntrinsicsAvailable body")
    if not l_raw_body:
        l_missing_tokens.append("RawAESENCLASTSi128 body")
    if not l_wrapper_body:
        l_missing_tokens.append("aes_aesenclast_si128 body")

    l_missing_tokens.extend(
        _check_required_patterns(
            l_guard_body,
            {
                "EnsureAESENCLASTIntrinsicsAvailable calls opt-in guard": r"\bensureexperimentalintrinsicsenabled\s*\(",
                "EnsureAESENCLASTIntrinsicsAvailable has CPUX86_64 guard": r"\{\$IFNDEF\s+CPUX86_64\}",
                "EnsureAESENCLASTIntrinsicsAvailable checks simd_has_aes": r"\bnot\s+simd_has_aes\b",
            },
        )
    )

    l_raw_patterns = {
        "RawAESENCLASTSi128 constref/var signature": (
            r"\bprocedure\s+rawaesenclastsi128\s*\(\s*constref\s+data\s*,\s*round_key\s*:\s*tm128\s*;\s*"
            r"var\s+outvalue\s*:\s*tm128\s*\)"
        ),
        "movdqu (%rcx), %xmm0": r"\bmovdqu\s+\(%rcx\)\s*,\s*%xmm0\b",
        "movdqu (%rdx), %xmm1": r"\bmovdqu\s+\(%rdx\)\s*,\s*%xmm1\b",
        "movdqu (%rdi), %xmm0": r"\bmovdqu\s+\(%rdi\)\s*,\s*%xmm0\b",
        "movdqu (%rsi), %xmm1": r"\bmovdqu\s+\(%rsi\)\s*,\s*%xmm1\b",
        "aesenclast %xmm1, %xmm0": r"\baesenclast\s+%xmm1\s*,\s*%xmm0\b",
        "movdqu %xmm0, (%rdx)": r"\bmovdqu\s+%xmm0\s*,\s*\(%rdx\)",
        "movdqu %xmm0, (%r8)": r"\bmovdqu\s+%xmm0\s*,\s*\(%r8\)",
    }
    l_missing_tokens.extend(_check_required_patterns(l_raw_body, l_raw_patterns))
    l_missing_tokens.extend(
        _check_required_patterns(
            l_wrapper_body,
            {
                "aes_aesenclast_si128 calls EnsureAESENCLASTIntrinsicsAvailable": r"\bensureaesenclastintrinsicsavailable\b",
                "aes_aesenclast_si128 calls RawAESENCLASTSi128": r"\brawaesenclastsi128\s*\(",
            },
        )
    )

    return {"missing_code_tokens": sorted(l_missing_tokens)}


def _scan_aesdec_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / AES_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {"missing_code_tokens": [AES_SOURCE_CONTRACT_FILE]}

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens: list[str] = [
        l_token for l_token in AESDEC_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]

    l_guard_body = _extract_pascal_routine(l_code, "EnsureAESDECIntrinsicsAvailable").lower()
    l_raw_body = _extract_pascal_routine(l_code, "RawAESDECSi128").lower()
    l_wrapper_body = _extract_pascal_routine(l_code, "aes_aesdec_si128").lower()

    if not l_guard_body:
        l_missing_tokens.append("EnsureAESDECIntrinsicsAvailable body")
    if not l_raw_body:
        l_missing_tokens.append("RawAESDECSi128 body")
    if not l_wrapper_body:
        l_missing_tokens.append("aes_aesdec_si128 body")

    l_missing_tokens.extend(
        _check_required_patterns(
            l_guard_body,
            {
                "EnsureAESDECIntrinsicsAvailable calls opt-in guard": r"\bensureexperimentalintrinsicsenabled\s*\(",
                "EnsureAESDECIntrinsicsAvailable has CPUX86_64 guard": r"\{\$IFNDEF\s+CPUX86_64\}",
                "EnsureAESDECIntrinsicsAvailable checks simd_has_aes": r"\bnot\s+simd_has_aes\b",
            },
        )
    )

    l_raw_patterns = {
        "RawAESDECSi128 constref/var signature": (
            r"\bprocedure\s+rawaesdecsi128\s*\(\s*constref\s+data\s*,\s*round_key\s*:\s*tm128\s*;\s*"
            r"var\s+outvalue\s*:\s*tm128\s*\)"
        ),
        "movdqu (%rcx), %xmm0": r"\bmovdqu\s+\(%rcx\)\s*,\s*%xmm0\b",
        "movdqu (%rdx), %xmm1": r"\bmovdqu\s+\(%rdx\)\s*,\s*%xmm1\b",
        "movdqu (%rdi), %xmm0": r"\bmovdqu\s+\(%rdi\)\s*,\s*%xmm0\b",
        "movdqu (%rsi), %xmm1": r"\bmovdqu\s+\(%rsi\)\s*,\s*%xmm1\b",
        "aesdec %xmm1, %xmm0": r"\baesdec\s+%xmm1\s*,\s*%xmm0\b",
        "movdqu %xmm0, (%rdx)": r"\bmovdqu\s+%xmm0\s*,\s*\(%rdx\)",
        "movdqu %xmm0, (%r8)": r"\bmovdqu\s+%xmm0\s*,\s*\(%r8\)",
    }
    l_missing_tokens.extend(_check_required_patterns(l_raw_body, l_raw_patterns))
    l_missing_tokens.extend(
        _check_required_patterns(
            l_wrapper_body,
            {
                "aes_aesdec_si128 calls EnsureAESDECIntrinsicsAvailable": r"\bensureaesdecintrinsicsavailable\b",
                "aes_aesdec_si128 calls RawAESDECSi128": r"\brawaesdecsi128\s*\(",
            },
        )
    )

    return {"missing_code_tokens": sorted(l_missing_tokens)}


def _scan_aesdeclast_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / AES_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {"missing_code_tokens": [AES_SOURCE_CONTRACT_FILE]}

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens: list[str] = [
        l_token for l_token in AESDECLAST_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]

    l_guard_body = _extract_pascal_routine(l_code, "EnsureAESDECLASTIntrinsicsAvailable").lower()
    l_raw_body = _extract_pascal_routine(l_code, "RawAESDECLASTSi128").lower()
    l_wrapper_body = _extract_pascal_routine(l_code, "aes_aesdeclast_si128").lower()

    if not l_guard_body:
        l_missing_tokens.append("EnsureAESDECLASTIntrinsicsAvailable body")
    if not l_raw_body:
        l_missing_tokens.append("RawAESDECLASTSi128 body")
    if not l_wrapper_body:
        l_missing_tokens.append("aes_aesdeclast_si128 body")

    l_missing_tokens.extend(
        _check_required_patterns(
            l_guard_body,
            {
                "EnsureAESDECLASTIntrinsicsAvailable calls opt-in guard": r"\bensureexperimentalintrinsicsenabled\s*\(",
                "EnsureAESDECLASTIntrinsicsAvailable has CPUX86_64 guard": r"\{\$IFNDEF\s+CPUX86_64\}",
                "EnsureAESDECLASTIntrinsicsAvailable checks simd_has_aes": r"\bnot\s+simd_has_aes\b",
            },
        )
    )

    l_raw_patterns = {
        "RawAESDECLASTSi128 constref/var signature": (
            r"\bprocedure\s+rawaesdeclastsi128\s*\(\s*constref\s+data\s*,\s*round_key\s*:\s*tm128\s*;\s*"
            r"var\s+outvalue\s*:\s*tm128\s*\)"
        ),
        "movdqu (%rcx), %xmm0": r"\bmovdqu\s+\(%rcx\)\s*,\s*%xmm0\b",
        "movdqu (%rdx), %xmm1": r"\bmovdqu\s+\(%rdx\)\s*,\s*%xmm1\b",
        "movdqu (%rdi), %xmm0": r"\bmovdqu\s+\(%rdi\)\s*,\s*%xmm0\b",
        "movdqu (%rsi), %xmm1": r"\bmovdqu\s+\(%rsi\)\s*,\s*%xmm1\b",
        "aesdeclast %xmm1, %xmm0": r"\baesdeclast\s+%xmm1\s*,\s*%xmm0\b",
        "movdqu %xmm0, (%rdx)": r"\bmovdqu\s+%xmm0\s*,\s*\(%rdx\)",
        "movdqu %xmm0, (%r8)": r"\bmovdqu\s+%xmm0\s*,\s*\(%r8\)",
    }
    l_missing_tokens.extend(_check_required_patterns(l_raw_body, l_raw_patterns))
    l_missing_tokens.extend(
        _check_required_patterns(
            l_wrapper_body,
            {
                "aes_aesdeclast_si128 calls EnsureAESDECLASTIntrinsicsAvailable": r"\bensureaesdeclastintrinsicsavailable\b",
                "aes_aesdeclast_si128 calls RawAESDECLASTSi128": r"\brawaesdeclastsi128\s*\(",
            },
        )
    )

    return {"missing_code_tokens": sorted(l_missing_tokens)}


def _scan_aeskeygenassist_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / AES_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {"missing_code_tokens": [AES_SOURCE_CONTRACT_FILE]}

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens: list[str] = [
        l_token for l_token in AESKEYGENASSIST_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]

    l_guard_body = _extract_pascal_routine(l_code, "EnsureAESKEYGENASSISTIntrinsicsAvailable").lower()
    l_supported_body = _extract_pascal_routine(l_code, "IsAESKEYGENASSISTRconSupported").lower()
    l_raw_body = _extract_pascal_routine(l_code, "RawAESKEYGENASSISTSi128").lower()
    l_wrapper_body = _extract_pascal_routine(l_code, "aes_aeskeygenassist_si128").lower()

    if not l_guard_body:
        l_missing_tokens.append("EnsureAESKEYGENASSISTIntrinsicsAvailable body")
    if not l_supported_body:
        l_missing_tokens.append("IsAESKEYGENASSISTRconSupported body")
    if not l_raw_body:
        l_missing_tokens.append("RawAESKEYGENASSISTSi128 body")
    if not l_wrapper_body:
        l_missing_tokens.append("aes_aeskeygenassist_si128 body")

    l_missing_tokens.extend(
        _check_required_patterns(
            l_guard_body,
            {
                "EnsureAESKEYGENASSISTIntrinsicsAvailable calls opt-in guard": r"\bensureexperimentalintrinsicsenabled\s*\(",
                "EnsureAESKEYGENASSISTIntrinsicsAvailable has CPUX86_64 guard": r"\{\$IFNDEF\s+CPUX86_64\}",
                "EnsureAESKEYGENASSISTIntrinsicsAvailable checks simd_has_aes": r"\bnot\s+simd_has_aes\b",
            },
        )
    )
    l_missing_tokens.extend(
        _check_required_patterns(
            l_supported_body,
            {
                "supports rcon $00": r"\$00",
                "supports rcon $01": r"\$01",
                "supports rcon $02": r"\$02",
                "supports rcon $04": r"\$04",
                "supports rcon $08": r"\$08",
                "supports rcon $10": r"\$10",
                "supports rcon $20": r"\$20",
                "supports rcon $40": r"\$40",
                "supports rcon $80": r"\$80",
                "supports rcon $1B": r"\$1b",
                "supports rcon $36": r"\$36",
            },
        )
    )

    l_raw_patterns = {
        "RawAESKEYGENASSISTSi128 constref/rcon/var signature": (
            r"\bprocedure\s+rawaeskeygenassistsi128\s*\(\s*constref\s+key\s*:\s*tm128\s*;\s*"
            r"rcon\s*:\s*byte\s*;\s*var\s+outvalue\s*:\s*tm128\s*\)"
        ),
        "movdqu (%rcx), %xmm0": r"\bmovdqu\s+\(%rcx\)\s*,\s*%xmm0\b",
        "movdqu (%rdi), %xmm0": r"\bmovdqu\s+\(%rdi\)\s*,\s*%xmm0\b",
        "cmpb $0x01, %dl": r"\bcmpb\s+\$0x01\s*,\s*%dl\b",
        "cmpb $0x01, %sil": r"\bcmpb\s+\$0x01\s*,\s*%sil\b",
        "aeskeygenassist $0x01, %xmm0, %xmm1": r"\baeskeygenassist\s+\$0x01\s*,\s*%xmm0\s*,\s*%xmm1\b",
        "aeskeygenassist $0x36, %xmm0, %xmm1": r"\baeskeygenassist\s+\$0x36\s*,\s*%xmm0\s*,\s*%xmm1\b",
        "movdqu %xmm1, (%r8)": r"\bmovdqu\s+%xmm1\s*,\s*\(%r8\)",
        "movdqu %xmm1, (%rdx)": r"\bmovdqu\s+%xmm1\s*,\s*\(%rdx\)",
    }
    l_missing_tokens.extend(_check_required_patterns(l_raw_body, l_raw_patterns))
    l_missing_tokens.extend(
        _check_required_patterns(
            l_wrapper_body,
            {
                "aes_aeskeygenassist_si128 calls EnsureAESKEYGENASSISTIntrinsicsAvailable": (
                    r"\bensureaeskeygenassistintrinsicsavailable\b"
                ),
                "aes_aeskeygenassist_si128 checks unsupported rcon": (
                    r"\bnot\s+isaeskeygenassistrconsupported\s*\(\s*rcon\s*\)"
                ),
                "aes_aeskeygenassist_si128 fail-closes unsupported rcon": r"\brunerror\s*\(\s*217\s*\)",
                "aes_aeskeygenassist_si128 calls RawAESKEYGENASSISTSi128": (
                    r"\brawaeskeygenassistsi128\s*\("
                ),
            },
        )
    )

    return {"missing_code_tokens": sorted(l_missing_tokens)}


def _scan_aesimc_source_contract(a_repo_root: Path) -> dict[str, list[str]]:
    l_path = a_repo_root / AES_SOURCE_CONTRACT_FILE
    if not l_path.is_file():
        return {"missing_code_tokens": [AES_SOURCE_CONTRACT_FILE]}

    l_code = _strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
    l_code_lower = l_code.lower()
    l_missing_tokens: list[str] = [
        l_token for l_token in AESIMC_REQUIRED_CODE_TOKENS if l_token.lower() not in l_code_lower
    ]

    l_guard_body = _extract_pascal_routine(l_code, "EnsureAESIMCIntrinsicsAvailable").lower()
    l_raw_body = _extract_pascal_routine(l_code, "RawAESIMCSi128").lower()
    l_wrapper_body = _extract_pascal_routine(l_code, "aes_aesimc_si128").lower()

    if not l_guard_body:
        l_missing_tokens.append("EnsureAESIMCIntrinsicsAvailable body")
    if not l_raw_body:
        l_missing_tokens.append("RawAESIMCSi128 body")
    if not l_wrapper_body:
        l_missing_tokens.append("aes_aesimc_si128 body")

    l_missing_tokens.extend(
        _check_required_patterns(
            l_guard_body,
            {
                "EnsureAESIMCIntrinsicsAvailable calls opt-in guard": r"\bensureexperimentalintrinsicsenabled\s*\(",
                "EnsureAESIMCIntrinsicsAvailable has CPUX86_64 guard": r"\{\$IFNDEF\s+CPUX86_64\}",
                "EnsureAESIMCIntrinsicsAvailable checks simd_has_aes": r"\bnot\s+simd_has_aes\b",
            },
        )
    )

    l_raw_patterns = {
        "RawAESIMCSi128 constref/var signature": (
            r"\bprocedure\s+rawaesimcsi128\s*\(\s*constref\s+data\s*:\s*tm128\s*;\s*"
            r"var\s+outvalue\s*:\s*tm128\s*\)"
        ),
        "movdqu (%rcx), %xmm0": r"\bmovdqu\s+\(%rcx\)\s*,\s*%xmm0\b",
        "movdqu (%rdi), %xmm0": r"\bmovdqu\s+\(%rdi\)\s*,\s*%xmm0\b",
        "aesimc %xmm0, %xmm0": r"\baesimc\s+%xmm0\s*,\s*%xmm0\b",
        "movdqu %xmm0, (%rdx)": r"\bmovdqu\s+%xmm0\s*,\s*\(%rdx\)",
        "movdqu %xmm0, (%rsi)": r"\bmovdqu\s+%xmm0\s*,\s*\(%rsi\)",
    }
    l_missing_tokens.extend(_check_required_patterns(l_raw_body, l_raw_patterns))
    l_missing_tokens.extend(
        _check_required_patterns(
            l_wrapper_body,
            {
                "aes_aesimc_si128 calls EnsureAESIMCIntrinsicsAvailable": r"\bensureaesimcintrinsicsavailable\b",
                "aes_aesimc_si128 calls RawAESIMCSi128": r"\brawaesimcsi128\s*\(",
            },
        )
    )

    return {"missing_code_tokens": sorted(l_missing_tokens)}


def _render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "INTRINSICS_EXPERIMENTAL_SUMMARY "
        f"experimental_units={a_result['experimental_units']} "
        f"entry_files={a_result['entry_files']} "
        f"leaked_files={a_result['leaked_files']} "
        f"leaked_units={a_result['leaked_units']} "
        f"missing_guard_markers={a_result['missing_guard_markers']} "
        f"default_define_leaks={a_result['default_define_leaks']} "
        f"missing_x86_runtime_fail_close={a_result['missing_x86_runtime_fail_close']} "
        f"missing_cross_host_opt_in={a_result['missing_cross_host_opt_in']} "
        f"missing_hold_runtime_fail_close={a_result['missing_hold_runtime_fail_close']} "
        f"missing_qualification_runtime_fail_close={a_result['missing_qualification_runtime_fail_close']} "
        f"missing_test_runtime_guards={a_result['missing_test_runtime_guards']} "
        f"missing_sha_code_tokens={a_result['missing_sha_code_tokens']} "
        f"sha_public_asm_functions={a_result['sha_public_asm_functions']} "
        f"sha_raw_constref_missing={a_result['sha_raw_constref_missing']} "
        f"missing_aesenc_code_tokens={a_result['missing_aesenc_code_tokens']} "
        f"missing_aesenc_semantic_vector={a_result['missing_aesenc_semantic_vector']} "
        f"missing_aesenclast_code_tokens={a_result['missing_aesenclast_code_tokens']} "
        f"missing_aesenclast_semantic_vector={a_result['missing_aesenclast_semantic_vector']} "
        f"missing_aesdec_code_tokens={a_result['missing_aesdec_code_tokens']} "
        f"missing_aesdec_semantic_vector={a_result['missing_aesdec_semantic_vector']} "
        f"missing_aesdeclast_code_tokens={a_result['missing_aesdeclast_code_tokens']} "
        f"missing_aesdeclast_semantic_vector={a_result['missing_aesdeclast_semantic_vector']} "
        f"missing_aeskeygenassist_code_tokens={a_result['missing_aeskeygenassist_code_tokens']} "
        f"missing_aeskeygenassist_semantic_vector={a_result['missing_aeskeygenassist_semantic_vector']} "
        f"missing_aesimc_code_tokens={a_result['missing_aesimc_code_tokens']} "
        f"missing_aesimc_semantic_vector={a_result['missing_aesimc_semantic_vector']} "
        f"missing_aes_hardware_boundaries={a_result['missing_aes_hardware_boundaries']} "
        f"forbidden_aes_completion_claims={a_result['forbidden_aes_completion_claims']} "
        f"missing_semantic_boundaries={a_result['missing_semantic_boundaries']} "
        f"missing_runner_fail_close={a_result['missing_runner_fail_close']} "
        f"forced_nonx86_aes_define_scope_issues={a_result['forced_nonx86_aes_define_scope_issues']}"
    )


def _print_human_result(a_result: dict[str, Any]) -> None:
    print("[EXPERIMENTAL] SIMD intrinsics entry isolation")
    print(f"  - tracked experimental units: {a_result['experimental_units']}")
    print(f"  - checked entry files:        {a_result['entry_files']}")
    print(f"  - leaked files:               {a_result['leaked_files']}")
    print(f"  - leaked units:               {a_result['leaked_units']}")
    print(f"  - missing guard markers:      {a_result['missing_guard_markers']}")
    print(f"  - default-define leaks:       {a_result['default_define_leaks']}")
    print(f"  - missing x86 fail-close:     {a_result['missing_x86_runtime_fail_close']}")
    print(f"  - missing cross-host opt-in:  {a_result['missing_cross_host_opt_in']}")
    print(f"  - missing hold fail-close:    {a_result['missing_hold_runtime_fail_close']}")
    print(f"  - missing qualification fail-close: {a_result['missing_qualification_runtime_fail_close']}")
    print(f"  - missing test runtime guards: {a_result['missing_test_runtime_guards']}")
    print(f"  - missing SHA code tokens:    {a_result['missing_sha_code_tokens']}")
    print(f"  - SHA public asm functions:   {a_result['sha_public_asm_functions']}")
    print(f"  - SHA raw constref missing:   {a_result['sha_raw_constref_missing']}")
    print(f"  - missing AESENC code tokens: {a_result['missing_aesenc_code_tokens']}")
    print(f"  - missing AESENC vector:      {a_result['missing_aesenc_semantic_vector']}")
    print(f"  - missing AESENCLAST code tokens: {a_result['missing_aesenclast_code_tokens']}")
    print(f"  - missing AESENCLAST vector:      {a_result['missing_aesenclast_semantic_vector']}")
    print(f"  - missing AESDEC code tokens: {a_result['missing_aesdec_code_tokens']}")
    print(f"  - missing AESDEC vector:      {a_result['missing_aesdec_semantic_vector']}")
    print(f"  - missing AESDECLAST code tokens: {a_result['missing_aesdeclast_code_tokens']}")
    print(f"  - missing AESDECLAST vector:      {a_result['missing_aesdeclast_semantic_vector']}")
    print(f"  - missing AESKEYGENASSIST code tokens: {a_result['missing_aeskeygenassist_code_tokens']}")
    print(f"  - missing AESKEYGENASSIST vector:      {a_result['missing_aeskeygenassist_semantic_vector']}")
    print(f"  - missing AESIMC code tokens: {a_result['missing_aesimc_code_tokens']}")
    print(f"  - missing AESIMC vector:      {a_result['missing_aesimc_semantic_vector']}")
    print(f"  - missing AES hardware boundaries: {a_result['missing_aes_hardware_boundaries']}")
    print(f"  - forbidden AES completion claims: {a_result['forbidden_aes_completion_claims']}")
    print(f"  - missing semantic boundaries: {a_result['missing_semantic_boundaries']}")
    print(f"  - missing runner fail-close:  {a_result['missing_runner_fail_close']}")
    print(f"  - forced non-x86 AES define scope issues: {a_result['forced_nonx86_aes_define_scope_issues']}")

    if a_result["leaks"]:
        print("[EXPERIMENTAL] Leaks found:")
        for l_file, l_units in a_result["leaks"].items():
            print(f"  - {l_file}")
            for l_unit in l_units:
                print(f"    * {l_unit}")
    if a_result["missing_guard_files"]:
        print("[EXPERIMENTAL] Missing required guard marker in:")
        for l_file in a_result["missing_guard_files"]:
            print(f"  - {l_file}")

    if a_result["default_define_files"]:
        print("[EXPERIMENTAL] Forbidden default entry define found in:")
        for l_file in a_result["default_define_files"]:
            print(f"  - {l_file}")

    if a_result["missing_x86_runtime_fail_close_files"]:
        print("[EXPERIMENTAL] Missing x86-only runtime fail-close marker in:")
        for l_file in a_result["missing_x86_runtime_fail_close_files"]:
            print(f"  - {l_file}")

    if a_result["missing_cross_host_opt_in_files"]:
        print("[EXPERIMENTAL] Missing cross-host opt-in contract marker in:")
        for l_file in a_result["missing_cross_host_opt_in_files"]:
            print(f"  - {l_file}")

    if a_result["missing_hold_runtime_fail_close_files"]:
        print("[EXPERIMENTAL] Missing hold-family runtime fail-close marker in:")
        for l_file in a_result["missing_hold_runtime_fail_close_files"]:
            print(f"  - {l_file}")

    if a_result["missing_qualification_runtime_fail_close_files"]:
        print("[EXPERIMENTAL] Missing qualification-family runtime fail-close marker in:")
        for l_file in a_result["missing_qualification_runtime_fail_close_files"]:
            print(f"  - {l_file}")

    if a_result["missing_test_runtime_guard_files"]:
        print("[EXPERIMENTAL] Missing experimental test runtime guard marker in:")
        for l_file in a_result["missing_test_runtime_guard_files"]:
            print(f"  - {l_file}")

    if a_result["missing_sha_code_token_list"]:
        print("[EXPERIMENTAL] Missing SHA source fail-close code tokens:")
        for l_token in a_result["missing_sha_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["sha_public_asm_function_list"]:
        print("[EXPERIMENTAL] SHA public functions must not be raw assembler leaves:")
        for l_name in a_result["sha_public_asm_function_list"]:
            print(f"  - {l_name}")

    if a_result["sha_raw_constref_missing_list"]:
        print("[EXPERIMENTAL] SHA raw leaves must use constref TM128 inputs:")
        for l_name in a_result["sha_raw_constref_missing_list"]:
            print(f"  - {l_name}")

    if a_result["missing_aesenc_code_token_list"]:
        print("[EXPERIMENTAL] Missing AESENC source code tokens:")
        for l_token in a_result["missing_aesenc_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["missing_aesenc_semantic_vector_files"]:
        print("[EXPERIMENTAL] Missing AESENC semantic vector evidence in:")
        for l_file in a_result["missing_aesenc_semantic_vector_files"]:
            print(f"  - {l_file}")

    if a_result["missing_aesenclast_code_token_list"]:
        print("[EXPERIMENTAL] Missing AESENCLAST source code tokens:")
        for l_token in a_result["missing_aesenclast_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["missing_aesenclast_semantic_vector_files"]:
        print("[EXPERIMENTAL] Missing AESENCLAST semantic vector evidence in:")
        for l_file in a_result["missing_aesenclast_semantic_vector_files"]:
            print(f"  - {l_file}")

    if a_result["missing_aesdec_code_token_list"]:
        print("[EXPERIMENTAL] Missing AESDEC source code tokens:")
        for l_token in a_result["missing_aesdec_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["missing_aesdec_semantic_vector_files"]:
        print("[EXPERIMENTAL] Missing AESDEC semantic vector evidence in:")
        for l_file in a_result["missing_aesdec_semantic_vector_files"]:
            print(f"  - {l_file}")

    if a_result["missing_aesdeclast_code_token_list"]:
        print("[EXPERIMENTAL] Missing AESDECLAST source code tokens:")
        for l_token in a_result["missing_aesdeclast_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["missing_aesdeclast_semantic_vector_files"]:
        print("[EXPERIMENTAL] Missing AESDECLAST semantic vector evidence in:")
        for l_file in a_result["missing_aesdeclast_semantic_vector_files"]:
            print(f"  - {l_file}")

    if a_result["missing_aeskeygenassist_code_token_list"]:
        print("[EXPERIMENTAL] Missing AESKEYGENASSIST source code tokens:")
        for l_token in a_result["missing_aeskeygenassist_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["missing_aeskeygenassist_semantic_vector_files"]:
        print("[EXPERIMENTAL] Missing AESKEYGENASSIST semantic vector evidence in:")
        for l_file in a_result["missing_aeskeygenassist_semantic_vector_files"]:
            print(f"  - {l_file}")

    if a_result["missing_aesimc_code_token_list"]:
        print("[EXPERIMENTAL] Missing AESIMC source code tokens:")
        for l_token in a_result["missing_aesimc_code_token_list"]:
            print(f"  - {l_token}")

    if a_result["missing_aesimc_semantic_vector_files"]:
        print("[EXPERIMENTAL] Missing AESIMC semantic vector evidence in:")
        for l_file in a_result["missing_aesimc_semantic_vector_files"]:
            print(f"  - {l_file}")

    if a_result["missing_aes_hardware_boundary_files"]:
        print("[EXPERIMENTAL] Missing AES hardware semantic-boundary wording in:")
        for l_file in a_result["missing_aes_hardware_boundary_files"]:
            print(f"  - {l_file}")

    if a_result["forbidden_aes_completion_claim_files"]:
        print("[EXPERIMENTAL] Forbidden AES completion claim found in:")
        for l_file in a_result["forbidden_aes_completion_claim_files"]:
            print(f"  - {l_file}")

    if a_result["missing_semantic_boundary_files"]:
        print("[EXPERIMENTAL] Missing experimental semantic-boundary wording in:")
        for l_file in a_result["missing_semantic_boundary_files"]:
            print(f"  - {l_file}")

    if a_result["missing_runner_fail_close_files"]:
        print("[EXPERIMENTAL] Missing experimental runner default fail-close contract in:")
        for l_file in a_result["missing_runner_fail_close_files"]:
            print(f"  - {l_file}")

    if a_result["forced_nonx86_aes_define_scope_issue_list"]:
        print("[EXPERIMENTAL] Forced non-x86 AES define scope issues:")
        for l_issue in a_result["forced_nonx86_aes_define_scope_issue_list"]:
            print(f"  - {l_issue}")

    if (
        (not a_result["leaks"])
        and (not a_result["missing_guard_files"])
        and (not a_result["default_define_files"])
        and (not a_result["missing_x86_runtime_fail_close_files"])
        and (not a_result["missing_cross_host_opt_in_files"])
        and (not a_result["missing_hold_runtime_fail_close_files"])
        and (not a_result["missing_qualification_runtime_fail_close_files"])
        and (not a_result["missing_test_runtime_guard_files"])
        and (not a_result["missing_sha_code_token_list"])
        and (not a_result["sha_public_asm_function_list"])
        and (not a_result["sha_raw_constref_missing_list"])
        and (not a_result["missing_aesenc_code_token_list"])
        and (not a_result["missing_aesenc_semantic_vector_files"])
        and (not a_result["missing_aesenclast_code_token_list"])
        and (not a_result["missing_aesenclast_semantic_vector_files"])
        and (not a_result["missing_aesdec_code_token_list"])
        and (not a_result["missing_aesdec_semantic_vector_files"])
        and (not a_result["missing_aesdeclast_code_token_list"])
        and (not a_result["missing_aesdeclast_semantic_vector_files"])
        and (not a_result["missing_aeskeygenassist_code_token_list"])
        and (not a_result["missing_aeskeygenassist_semantic_vector_files"])
        and (not a_result["missing_aesimc_code_token_list"])
        and (not a_result["missing_aesimc_semantic_vector_files"])
        and (not a_result["missing_aes_hardware_boundary_files"])
        and (not a_result["forbidden_aes_completion_claim_files"])
        and (not a_result["missing_semantic_boundary_files"])
        and (not a_result["missing_runner_fail_close_files"])
        and (not a_result["forced_nonx86_aes_define_scope_issue_list"])
    ):
        print("[EXPERIMENTAL] OK (no experimental units in default entry chain)")


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check experimental intrinsics isolation")
    l_parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_parser.add_argument(
        "--entry-file",
        action="append",
        dest="entry_files",
        default=None,
        help="override/add entry file to scan (repo-relative)",
    )
    l_args = l_parser.parse_args()

    l_repo_root = Path(__file__).resolve().parents[2]
    l_entry_files = l_args.entry_files if l_args.entry_files else list(DEFAULT_ENTRY_FILES)
    l_leaks = _scan_leaks(a_repo_root=l_repo_root, a_entry_files=l_entry_files, a_units=EXPERIMENTAL_UNITS)
    l_leaked_units = sorted({l_unit for l_units in l_leaks.values() for l_unit in l_units})
    l_missing_guard_files = _scan_guard_markers(
        a_repo_root=l_repo_root,
        a_files=GUARDED_EXPERIMENTAL_FILES,
        a_token=REQUIRED_GUARD_TOKEN,
    )
    l_default_define_files = _scan_forbidden_default_defines(
        a_repo_root=l_repo_root,
        a_files=l_entry_files,
        a_patterns=FORBIDDEN_DEFAULT_DEFINE_PATTERNS,
    )
    l_missing_x86_runtime_fail_close_files = _scan_x86_only_runtime_fail_close_markers(
        a_repo_root=l_repo_root,
        a_files=X86_ONLY_RUNTIME_FAIL_CLOSE_FILES,
        a_token=REQUIRED_X86_ONLY_RUNTIME_FAIL_CLOSE_TOKEN,
    )
    l_missing_cross_host_opt_in_files = _scan_required_runtime_fail_close_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=DEFAULT_OPT_IN_ACROSS_HOSTS_TOKENS,
    )
    l_missing_hold_runtime_fail_close_files = _scan_required_runtime_fail_close_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=HOLD_RUNTIME_FAIL_CLOSE_TOKENS,
    )
    l_missing_qualification_runtime_fail_close_files = _scan_required_runtime_fail_close_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=QUALIFICATION_RUNTIME_FAIL_CLOSE_TOKENS,
    )
    l_missing_test_runtime_guard_files = _scan_required_test_runtime_guard_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=EXPERIMENTAL_TEST_RUNTIME_GUARD_TOKENS,
    )
    l_sha_source_contract = _scan_sha_source_contract(a_repo_root=l_repo_root)
    l_aesenc_source_contract = _scan_aesenc_source_contract(a_repo_root=l_repo_root)
    l_aesenclast_source_contract = _scan_aesenclast_source_contract(a_repo_root=l_repo_root)
    l_aesdec_source_contract = _scan_aesdec_source_contract(a_repo_root=l_repo_root)
    l_aesdeclast_source_contract = _scan_aesdeclast_source_contract(a_repo_root=l_repo_root)
    l_aeskeygenassist_source_contract = _scan_aeskeygenassist_source_contract(a_repo_root=l_repo_root)
    l_aesimc_source_contract = _scan_aesimc_source_contract(a_repo_root=l_repo_root)
    l_missing_aesenc_semantic_vector_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AESENC_SEMANTIC_VECTOR_TOKENS,
    )
    l_missing_aesenclast_semantic_vector_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AESENCLAST_SEMANTIC_VECTOR_TOKENS,
    )
    l_missing_aesdec_semantic_vector_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AESDEC_SEMANTIC_VECTOR_TOKENS,
    )
    l_missing_aesdeclast_semantic_vector_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AESDECLAST_SEMANTIC_VECTOR_TOKENS,
    )
    l_missing_aeskeygenassist_semantic_vector_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AESKEYGENASSIST_SEMANTIC_VECTOR_TOKENS,
    )
    l_missing_aesimc_semantic_vector_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AESIMC_SEMANTIC_VECTOR_TOKENS,
    )
    l_missing_aes_hardware_boundary_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=AES_HARDWARE_SEMANTIC_BOUNDARY_TOKENS,
    )
    l_forbidden_aes_completion_claim_files = _scan_forbidden_text_patterns(
        a_repo_root=l_repo_root,
        a_file_patterns=FORBIDDEN_AES_COMPLETION_CLAIM_PATTERNS,
    )
    l_missing_semantic_boundary_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=EXPERIMENTAL_SEMANTIC_BOUNDARY_TOKENS,
    )
    l_missing_runner_fail_close_files = _scan_required_text_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=EXPERIMENTAL_RUNNER_FAIL_CLOSE_TOKENS,
    )
    l_forced_nonx86_aes_define_scope_issues = _scan_forced_nonx86_aes_define_scope(a_repo_root=l_repo_root)

    l_result: dict[str, Any] = {
        "ok": (
            (len(l_leaks) == 0)
            and (len(l_missing_guard_files) == 0)
            and (len(l_default_define_files) == 0)
            and (len(l_missing_x86_runtime_fail_close_files) == 0)
            and (len(l_missing_cross_host_opt_in_files) == 0)
            and (len(l_missing_hold_runtime_fail_close_files) == 0)
            and (len(l_missing_qualification_runtime_fail_close_files) == 0)
            and (len(l_missing_test_runtime_guard_files) == 0)
            and (len(l_sha_source_contract["missing_code_tokens"]) == 0)
            and (len(l_sha_source_contract["public_assembler_functions"]) == 0)
            and (len(l_sha_source_contract["missing_raw_constref_signatures"]) == 0)
            and (len(l_aesenc_source_contract["missing_code_tokens"]) == 0)
            and (len(l_aesenclast_source_contract["missing_code_tokens"]) == 0)
            and (len(l_aesdec_source_contract["missing_code_tokens"]) == 0)
            and (len(l_aesdeclast_source_contract["missing_code_tokens"]) == 0)
            and (len(l_aeskeygenassist_source_contract["missing_code_tokens"]) == 0)
            and (len(l_aesimc_source_contract["missing_code_tokens"]) == 0)
            and (len(l_missing_aesenc_semantic_vector_files) == 0)
            and (len(l_missing_aesenclast_semantic_vector_files) == 0)
            and (len(l_missing_aesdec_semantic_vector_files) == 0)
            and (len(l_missing_aesdeclast_semantic_vector_files) == 0)
            and (len(l_missing_aeskeygenassist_semantic_vector_files) == 0)
            and (len(l_missing_aesimc_semantic_vector_files) == 0)
            and (len(l_missing_aes_hardware_boundary_files) == 0)
            and (len(l_forbidden_aes_completion_claim_files) == 0)
            and (len(l_missing_semantic_boundary_files) == 0)
            and (len(l_missing_runner_fail_close_files) == 0)
            and (len(l_forced_nonx86_aes_define_scope_issues) == 0)
        ),
        "experimental_units": len(EXPERIMENTAL_UNITS),
        "entry_files": len(l_entry_files),
        "leaked_files": len(l_leaks),
        "leaked_units": len(l_leaked_units),
        "missing_guard_markers": len(l_missing_guard_files),
        "default_define_leaks": len(l_default_define_files),
        "missing_x86_runtime_fail_close": len(l_missing_x86_runtime_fail_close_files),
        "missing_cross_host_opt_in": len(l_missing_cross_host_opt_in_files),
        "missing_hold_runtime_fail_close": len(l_missing_hold_runtime_fail_close_files),
        "missing_qualification_runtime_fail_close": len(l_missing_qualification_runtime_fail_close_files),
        "missing_test_runtime_guards": len(l_missing_test_runtime_guard_files),
        "missing_sha_code_tokens": len(l_sha_source_contract["missing_code_tokens"]),
        "sha_public_asm_functions": len(l_sha_source_contract["public_assembler_functions"]),
        "sha_raw_constref_missing": len(l_sha_source_contract["missing_raw_constref_signatures"]),
        "missing_aesenc_code_tokens": len(l_aesenc_source_contract["missing_code_tokens"]),
        "missing_aesenc_semantic_vector": len(l_missing_aesenc_semantic_vector_files),
        "missing_aesenclast_code_tokens": len(l_aesenclast_source_contract["missing_code_tokens"]),
        "missing_aesenclast_semantic_vector": len(l_missing_aesenclast_semantic_vector_files),
        "missing_aesdec_code_tokens": len(l_aesdec_source_contract["missing_code_tokens"]),
        "missing_aesdec_semantic_vector": len(l_missing_aesdec_semantic_vector_files),
        "missing_aesdeclast_code_tokens": len(l_aesdeclast_source_contract["missing_code_tokens"]),
        "missing_aesdeclast_semantic_vector": len(l_missing_aesdeclast_semantic_vector_files),
        "missing_aeskeygenassist_code_tokens": len(l_aeskeygenassist_source_contract["missing_code_tokens"]),
        "missing_aeskeygenassist_semantic_vector": len(l_missing_aeskeygenassist_semantic_vector_files),
        "missing_aesimc_code_tokens": len(l_aesimc_source_contract["missing_code_tokens"]),
        "missing_aesimc_semantic_vector": len(l_missing_aesimc_semantic_vector_files),
        "missing_aes_hardware_boundaries": len(l_missing_aes_hardware_boundary_files),
        "forbidden_aes_completion_claims": len(l_forbidden_aes_completion_claim_files),
        "missing_semantic_boundaries": len(l_missing_semantic_boundary_files),
        "missing_runner_fail_close": len(l_missing_runner_fail_close_files),
        "forced_nonx86_aes_define_scope_issues": len(l_forced_nonx86_aes_define_scope_issues),
        "entry_file_list": l_entry_files,
        "leaks": l_leaks,
        "leaked_unit_list": l_leaked_units,
        "missing_guard_files": l_missing_guard_files,
        "default_define_files": l_default_define_files,
        "missing_x86_runtime_fail_close_files": l_missing_x86_runtime_fail_close_files,
        "missing_cross_host_opt_in_files": l_missing_cross_host_opt_in_files,
        "missing_hold_runtime_fail_close_files": l_missing_hold_runtime_fail_close_files,
        "missing_qualification_runtime_fail_close_files": l_missing_qualification_runtime_fail_close_files,
        "missing_test_runtime_guard_files": l_missing_test_runtime_guard_files,
        "missing_sha_code_token_list": l_sha_source_contract["missing_code_tokens"],
        "sha_public_asm_function_list": l_sha_source_contract["public_assembler_functions"],
        "sha_raw_constref_missing_list": l_sha_source_contract["missing_raw_constref_signatures"],
        "missing_aesenc_code_token_list": l_aesenc_source_contract["missing_code_tokens"],
        "missing_aesenc_semantic_vector_files": l_missing_aesenc_semantic_vector_files,
        "missing_aesenclast_code_token_list": l_aesenclast_source_contract["missing_code_tokens"],
        "missing_aesenclast_semantic_vector_files": l_missing_aesenclast_semantic_vector_files,
        "missing_aesdec_code_token_list": l_aesdec_source_contract["missing_code_tokens"],
        "missing_aesdec_semantic_vector_files": l_missing_aesdec_semantic_vector_files,
        "missing_aesdeclast_code_token_list": l_aesdeclast_source_contract["missing_code_tokens"],
        "missing_aesdeclast_semantic_vector_files": l_missing_aesdeclast_semantic_vector_files,
        "missing_aeskeygenassist_code_token_list": l_aeskeygenassist_source_contract["missing_code_tokens"],
        "missing_aeskeygenassist_semantic_vector_files": l_missing_aeskeygenassist_semantic_vector_files,
        "missing_aesimc_code_token_list": l_aesimc_source_contract["missing_code_tokens"],
        "missing_aesimc_semantic_vector_files": l_missing_aesimc_semantic_vector_files,
        "missing_aes_hardware_boundary_files": l_missing_aes_hardware_boundary_files,
        "forbidden_aes_completion_claim_files": l_forbidden_aes_completion_claim_files,
        "missing_semantic_boundary_files": l_missing_semantic_boundary_files,
        "missing_runner_fail_close_files": l_missing_runner_fail_close_files,
        "forced_nonx86_aes_define_scope_issue_list": l_forced_nonx86_aes_define_scope_issues,
    }

    if l_args.json:
        print(json.dumps(l_result, ensure_ascii=False, sort_keys=True, indent=2))
    else:
        _print_human_result(l_result)

    if l_args.summary_line:
        print(_render_summary_line(l_result))

    return 0 if l_result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
