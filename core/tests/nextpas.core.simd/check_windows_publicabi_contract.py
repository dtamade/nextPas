#!/usr/bin/env python3
"""Guard Windows-specific publicabi runner/evidence contracts from source."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PUBLICABI_RUNNER = ROOT / "tests" / "nextpas.core.simd.publicabi" / "BuildOrTest.bat"
PUBLICABI_SMOKE = ROOT / "tests" / "nextpas.core.simd.publicabi" / "publicabi_smoke.ps1"
SIMD_BATCH_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "buildOrTest.bat"
WINDOWS_EVIDENCE = ROOT / "tests" / "nextpas.core.simd" / "collect_windows_b07_evidence.bat"
WINDOWS_RUNBOOK = ROOT / "tests" / "nextpas.core.simd" / "docs" / "windows_b07_closeout_runbook.md"


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
    if not re.search(a_pattern, a_text, re.IGNORECASE | re.MULTILINE):
        add_issue(a_issues, a_path, a_message)
    return 1


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (
        PUBLICABI_RUNNER,
        PUBLICABI_SMOKE,
        SIMD_BATCH_RUNNER,
        WINDOWS_EVIDENCE,
        WINDOWS_RUNBOOK,
    ):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing contract file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_runner = read_text(PUBLICABI_RUNNER)
    l_smoke = read_text(PUBLICABI_SMOKE)
    l_batch = read_text(SIMD_BATCH_RUNNER)
    l_evidence = read_text(WINDOWS_EVIDENCE)
    l_runbook = read_text(WINDOWS_RUNBOOK)

    for l_pattern, l_message in (
        (
            r'DEFAULT_OUTPUT_ROOT=%REPO_ROOT%\\build\\tests\\nextpas\.core\.simd\.publicabi',
            "runner missing core/build publicabi output root",
        ),
        (r'call :resolve_powershell', "runner missing PowerShell resolver call"),
        (r'where pwsh', "runner missing pwsh-first probe"),
        (r'where powershell', "runner missing powershell fallback probe"),
        (r'tried pwsh and powershell', "runner missing fail-close PowerShell error"),
        (r'-ValidateOnly', "runner missing validate-only export path"),
    ):
        l_checks += require_pattern(l_runner, PUBLICABI_RUNNER, l_pattern, l_message, l_issues)

    for l_pattern, l_message in (
        (r'\[switch\]\$ValidateOnly', "PowerShell smoke missing ValidateOnly parameter"),
        (
            r'public struct NextPasSimdBackendPodInfo',
            "PowerShell smoke missing NextPas backend pod contract",
        ),
        (
            r'public struct NextPasSimdPublicApiV2',
            "PowerShell smoke missing NextPas public API v2 contract",
        ),
        (
            r'EntryPoint = "nextpas_simd_get_backend_pod_info"',
            "PowerShell smoke missing backend pod entrypoint",
        ),
        (
            r'EntryPoint = "nextpas_simd_get_public_api_v2"',
            "PowerShell smoke missing public_api_v2 entrypoint",
        ),
        (r'if \(-not \$ValidateOnly\)', "PowerShell smoke missing ValidateOnly fast path"),
    ):
        l_checks += require_pattern(l_smoke, PUBLICABI_SMOKE, l_pattern, l_message, l_issues)

    for l_pattern, l_message in (
        (
            r'PUBLICABI_RUNNER=%ROOT%\.\.\\nextpas\.core\.simd\.publicabi\\BuildOrTest\.bat',
            "SIMD batch runner missing sibling Windows publicabi runner path",
        ),
        (
            r'PUBLICABI_OUTPUT_ROOT=%ROOT%\.\.\\\.\.\\build\\tests\\nextpas\.core\.simd\.publicabi',
            "SIMD batch runner missing explicit core/build publicabi output root",
        ),
        (
            r'SIMD_OUTPUT_ROOT=%PUBLICABI_OUTPUT_ROOT%',
            "SIMD batch runner missing publicabi output-root override",
        ),
    ):
        l_checks += require_pattern(l_batch, SIMD_BATCH_RUNNER, l_pattern, l_message, l_issues)

    for l_pattern, l_message in (
        (
            r'pushd "%TESTS_ROOT%\\nextpas\.core\.simd\.publicabi"',
            "Windows evidence runner missing sibling publicabi pushd",
        ),
        (
            r'PREV_SIMD_OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%',
            "Windows evidence runner missing output-root save/restore guard",
        ),
        (
            r'SIMD_OUTPUT_ROOT=%ROOT%\.\.\\\.\.\\build\\tests\\nextpas\.core\.simd\.publicabi',
            "Windows evidence runner missing explicit core/build publicabi output root",
        ),
        (
            r'call "\.\\BuildOrTest\.bat" test',
            "Windows evidence runner missing publicabi batch smoke call",
        ),
        (
            r'SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%',
            "Windows evidence runner missing output-root restore",
        ),
    ):
        l_checks += require_pattern(l_evidence, WINDOWS_EVIDENCE, l_pattern, l_message, l_issues)

    for l_pattern, l_message in (
        (
            r'collect_windows_b07_evidence\.bat',
            "Windows runbook missing evidence runner reference",
        ),
        (
            r'publicabi-smoke',
            "Windows runbook missing publicabi smoke reference",
        ),
        (
            r'SIMD_OUTPUT_ROOT',
            "Windows runbook missing publicabi output-root contract",
        ),
        (
            r'core/build/tests/nextpas\.core\.simd\.publicabi',
            "Windows runbook missing explicit publicabi output root",
        ),
        (
            r'SIMD_WIN_EVIDENCE_USE_BASH_GATE=1',
            "Windows runbook missing explicit bash fallback opt-in",
        ),
    ):
        l_checks += require_pattern(l_runbook, WINDOWS_RUNBOOK, l_pattern, l_message, l_issues)

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "WINDOWS_PUBLICABI_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[WINDOWS-PUBLICABI-CONTRACT] Windows publicabi runner/evidence contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[WINDOWS-PUBLICABI-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[WINDOWS-PUBLICABI-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check Windows publicabi runner/evidence source contracts."
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
