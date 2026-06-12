#!/usr/bin/env python3
"""Guard the minimal QEMU runner surface used by non-x86 SIMD workflows."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
QEMU_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "docker" / "run_multiarch_qemu.sh"


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def add_issue(a_issues: list[dict[str, str]], a_path: Path, a_message: str) -> None:
    a_issues.append({"file": str(a_path.relative_to(ROOT)), "message": a_message})


def require_pattern(
    a_text: str,
    a_path: Path,
    a_pattern: str,
    a_message: str,
    a_issues: list[dict[str, str]],
) -> int:
    if not re.search(a_pattern, a_text, re.MULTILINE):
        add_issue(a_issues, a_path, a_message)
    return 1


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    if not QEMU_RUNNER.is_file():
        add_issue(l_issues, QEMU_RUNNER, "missing qemu runner contract file")
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_runner = read_text(QEMU_RUNNER)
    for l_pattern, l_message in (
        (r'case "\$\{ACTION\}" in', "qemu runner missing action dispatcher"),
        (r'nonx86-evidence\)', "qemu runner missing nonx86-evidence action"),
        (r'cpuinfo-nonx86-evidence\)', "qemu runner missing cpuinfo-nonx86-evidence action"),
        (r'cpuinfo-nonx86-full-evidence\)', "qemu runner missing cpuinfo-nonx86-full-evidence action"),
        (r'cpuinfo-nonx86-full-repeat\)', "qemu runner missing cpuinfo-nonx86-full-repeat action"),
        (r'cpuinfo-nonx86-suite-repeat\)', "qemu runner missing cpuinfo-nonx86-suite-repeat action"),
        (r'arch-matrix-evidence\)', "qemu runner missing arch-matrix-evidence action"),
        (r'nonx86-experimental-asm\)', "qemu runner missing nonx86-experimental-asm action"),
        (r'build_nonx86_evidence_cmd\(\)', "qemu runner missing non-x86 evidence command builder"),
        (
            r'LDirectParityLog="\$\{SIMD_OUTPUT_ROOT\}/logs/direct_nonx86_runtime_parity\.txt"',
            "qemu runner missing direct parity log contract",
        ),
        (
            r'--suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane',
            "qemu runner missing non-x86 runtime parity suite contract",
        ),
        (
            r'bash tests/nextpas\.core\.simd/run_backend_benchmarks\.sh',
            "qemu runner missing backend benchmark command contract",
        ),
        (r'SIMD_QEMU_DRY_RUN', "qemu runner missing dry-run fail-close contract"),
        (r'Unsupported action', "qemu runner missing fail-close unsupported-action path"),
    ):
        l_checks += require_pattern(
            l_runner,
            QEMU_RUNNER,
            l_pattern,
            l_message,
            l_issues,
        )

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "QEMU_RUNNER_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[QEMU-RUNNER-CONTRACT] SIMD qemu runner minimum contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[QEMU-RUNNER-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[QEMU-RUNNER-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check the minimal SIMD qemu-runner source contracts."
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
    sys.exit(main())
