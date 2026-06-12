#!/usr/bin/env python3
"""Fail-close stale CPUInfo runner path and entrypoint drift."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CPUINFO_BATCH = ROOT / "tests" / "nextpas.core.simd.cpuinfo" / "buildOrTest.bat"
CPUINFO_SHELL = ROOT / "tests" / "nextpas.core.simd.cpuinfo" / "BuildOrTest.sh"
CPUINFO_X86_BATCH = ROOT / "tests" / "nextpas.core.simd.cpuinfo.x86" / "buildOrTest.bat"
CPUINFO_X86_SHELL = ROOT / "tests" / "nextpas.core.simd.cpuinfo.x86" / "BuildOrTest.sh"
SIMD_BATCH = ROOT / "tests" / "nextpas.core.simd" / "buildOrTest.bat"
QEMU_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "docker" / "run_multiarch_qemu.sh"
WINDOWS_EVIDENCE_BATCH = ROOT / "tests" / "nextpas.core.simd" / "collect_windows_b07_evidence.bat"
CPUINFO_DOC = ROOT / "docs" / "simd" / "cpuinfo.md"

CLOSEOUT_DOC = ROOT / "docs" / "simd" / "closeout.md"
CHECKLIST_DOC = ROOT / "docs" / "simd" / "checklist.md"
MAINTENANCE_DOC = ROOT / "docs" / "simd" / "maintenance.md"
AVX2_DOC = ROOT / "docs" / "simd" / "intrinsics.avx2.md"
RC_CHECKLIST_DOC = ROOT / "tests" / "nextpas.core.simd" / "docs" / "simd_release_candidate_checklist.md"
COMPLETENESS_DOC = ROOT / "tests" / "nextpas.core.simd" / "docs" / "simd_completeness_matrix.md"
GATE_SUMMARY_SAMPLE = ROOT / "tests" / "nextpas.core.simd" / "generate_gate_summary_sample.py"

ACTIVE_DOCS = (
    CLOSEOUT_DOC,
    CHECKLIST_DOC,
    MAINTENANCE_DOC,
    AVX2_DOC,
    RC_CHECKLIST_DOC,
    COMPLETENESS_DOC,
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def add_issue(a_issues: list[dict[str, str]], a_path: Path, a_message: str) -> None:
    a_issues.append({"file": str(a_path.relative_to(ROOT)), "message": a_message})


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (
        CPUINFO_BATCH,
        CPUINFO_SHELL,
        SIMD_BATCH,
        QEMU_RUNNER,
        WINDOWS_EVIDENCE_BATCH,
        CPUINFO_DOC,
        CLOSEOUT_DOC,
        CHECKLIST_DOC,
        MAINTENANCE_DOC,
        AVX2_DOC,
        RC_CHECKLIST_DOC,
        COMPLETENESS_DOC,
        GATE_SUMMARY_SAMPLE,
    ):
        l_checks += 1
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing CPUInfo runner contract file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_simd_batch = read_text(SIMD_BATCH)
    l_cpuinfo_shell = read_text(CPUINFO_SHELL)
    l_qemu_runner = read_text(QEMU_RUNNER)
    l_windows_evidence = read_text(WINDOWS_EVIDENCE_BATCH)
    l_cpuinfo_doc = read_text(CPUINFO_DOC)
    l_closeout = read_text(CLOSEOUT_DOC)
    l_checklist = read_text(CHECKLIST_DOC)
    l_maintenance = read_text(MAINTENANCE_DOC)
    l_avx2 = read_text(AVX2_DOC)

    l_missing_doc_refs = [
        (CPUINFO_X86_SHELL, "tests/nextpas.core.simd.cpuinfo.x86/BuildOrTest.sh"),
        (CPUINFO_X86_BATCH, r"tests\nextpas.core.simd.cpuinfo.x86\buildOrTest.bat"),
    ]
    for l_missing_path, l_ref in l_missing_doc_refs:
        for l_doc in ACTIVE_DOCS:
            l_checks += 1
            if (not l_missing_path.is_file()) and l_ref in read_text(l_doc):
                add_issue(
                    l_issues,
                    l_doc,
                    f"references missing CPUInfo runner entrypoint `{l_ref}`",
                )

    for l_required in (
        'DEFAULT_OUTPUT_ROOT="${CORE_ROOT}/build/tests/nextpas.core.simd.cpuinfo"',
        'case "${ACTION}" in',
        "log-layout-check",
        'TARGET_CPU="$("${FPC_BIN}" -iTP',
        'TARGET_OS="$("${FPC_BIN}" -iTO',
        'OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${DEFAULT_OUTPUT_ROOT}}"',
        'TARGET_LOG_DIR="${LOG_DIR}/${TARGET_TAG}"',
        'RUNNER_NAME="nextpas.core.simd.cpuinfo.test"',
        'cmp -s "${l_target}" "${l_legacy}"',
    ):
        l_checks += 1
        if l_required not in l_cpuinfo_shell:
            add_issue(
                l_issues,
                CPUINFO_SHELL,
                f"cpuinfo shell runner missing source-contract token `{l_required}`",
            )

    for l_required in (
        "bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh check",
        "bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --list-suites",
        "bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific",
    ):
        l_checks += 1
        if l_required not in l_qemu_runner:
            add_issue(
                l_issues,
                QEMU_RUNNER,
                f"qemu runner missing cpuinfo shell-runner command `{l_required}`",
            )

    for l_required in (
        "bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh test --suite=TTestCase_PlatformSpecific",
        "bash tests/nextpas.core.simd.cpuinfo/BuildOrTest.sh log-layout-check",
        "bash tests/nextpas.core.simd/BuildOrTest.sh qemu-cpuinfo-nonx86-evidence",
    ):
        l_checks += 1
        if l_required not in l_cpuinfo_doc:
            add_issue(
                l_issues,
                CPUINFO_DOC,
                f"cpuinfo doc missing active shell-runner entry `{l_required}`",
            )

    for l_forbidden in (
        r"\nextpas.core.simd.cpuinfo.x86\buildOrTest.bat",
        "=nextpas.core.simd.cpuinfo.x86",
    ):
        l_checks += 1
        if l_forbidden in l_simd_batch:
            add_issue(
                l_issues,
                SIMD_BATCH,
                f"main Windows SIMD runner must not use stale cpuinfo.x86 runner path `{l_forbidden}`",
            )

    for l_required in (
        r"\nextpas.core.simd.cpuinfo\buildOrTest.bat",
        "set \"CPUINFO_X86_OUTPUT_ROOT=",
    ):
        l_checks += 1
        if l_required not in l_simd_batch:
            add_issue(
                l_issues,
                SIMD_BATCH,
                f"main Windows SIMD runner missing CPUInfo gateway token `{l_required}`",
            )

    for l_forbidden in (
        r"\nextpas.core.simd.cpuinfo.x86",
        "nextpas.core.simd.cpuinfo.x86.test.exe",
    ):
        l_checks += 1
        if l_forbidden in l_windows_evidence:
            add_issue(
                l_issues,
                WINDOWS_EVIDENCE_BATCH,
                f"Windows evidence collector must not use stale cpuinfo.x86 runner token `{l_forbidden}`",
            )

    for l_required in (
        r"\nextpas.core.simd.cpuinfo",
        "nextpas.core.simd.cpuinfo.test.exe",
        "TTestCase_Global",
    ):
        l_checks += 1
        if l_required not in l_windows_evidence:
            add_issue(
                l_issues,
                WINDOWS_EVIDENCE_BATCH,
                f"Windows evidence collector missing CPUInfo runner truth token `{l_required}`",
            )

    l_checks += 1
    if "make -C core/tests/nextpas.core.simd cpuinfo-focused" not in l_closeout:
        add_issue(
            l_issues,
            CLOSEOUT_DOC,
            "closeout guide must point Linux CPUInfo verification at `make -C core/tests/nextpas.core.simd cpuinfo-focused`",
        )

    l_checks += 1
    if r"tests\nextpas.core.simd.cpuinfo\buildOrTest.bat test --suite=TTestCase_Global" not in l_closeout:
        add_issue(
            l_issues,
            CLOSEOUT_DOC,
            "closeout guide must point Windows x86/global CPUInfo verification at the cpuinfo batch runner",
        )

    l_checks += 1
    if "`cpuinfo` / `cpuinfo.x86` / `publicabi` / `nonx86.optin`" in l_checklist:
        add_issue(
            l_issues,
            CHECKLIST_DOC,
            "shell checklist must not describe cpuinfo.x86 as a shell sub-runner",
        )

    l_checks += 1
    if "`cpuinfo`、`cpuinfo.x86` 与 `publicabi` 子 runner" in l_maintenance:
        add_issue(
            l_issues,
            MAINTENANCE_DOC,
            "maintenance guide must not describe cpuinfo.x86 as a shell sub-runner",
        )

    for l_forbidden in (
        "nextpas.core.simd.cpuinfo.x86",
        "`cpuinfo`/`cpuinfo.x86` runner",
    ):
        l_checks += 1
        if l_forbidden in l_avx2:
            add_issue(
                l_issues,
                AVX2_DOC,
                f"AVX2 doc must not describe stale cpuinfo.x86 runner token `{l_forbidden}`",
            )

    for l_doc in (RC_CHECKLIST_DOC, COMPLETENESS_DOC):
        l_checks += 1
        if "simd + cpuinfo + cpuinfo.x86" in read_text(l_doc):
            add_issue(
                l_issues,
                l_doc,
                "active release docs must not describe `cpuinfo.x86` as a separate gate module",
            )

    l_checks += 1
    if "tests/nextpas.core.simd.cpuinfo.x86/logs/test.txt" in read_text(GATE_SUMMARY_SAMPLE):
        add_issue(
            l_issues,
            GATE_SUMMARY_SAMPLE,
            "gate summary sample must point cpuinfo-x86 evidence at the unified cpuinfo runner logs",
        )

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "CPUINFO_RUNNER_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[CPUINFO-RUNNER-CONTRACT] CPUInfo runner path/entry contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")
    if a_result["issue_entries"]:
        print("[CPUINFO-RUNNER-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[CPUINFO-RUNNER-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check the SIMD CPUInfo runner contract and stale path drift."
    )
    l_parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    return l_parser.parse_args()


def main() -> int:
    l_args = parse_args()
    l_result = build_result()

    if l_args.json:
        print(json.dumps(l_result, ensure_ascii=False, sort_keys=True, indent=2))
    else:
        print_human_result(l_result)

    if l_args.summary_line:
        print(render_summary_line(l_result))

    return 0 if l_result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
