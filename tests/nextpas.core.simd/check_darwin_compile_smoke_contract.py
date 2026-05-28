#!/usr/bin/env python3
"""Guard Darwin compile-smoke source contracts without requiring osxcross locally."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
TIME_CPU_FILE = ROOT / "src" / "nextpas.core.time.cpu.pas"
CPUINFO_DIAGNOSTIC_FILE = ROOT / "src" / "nextpas.core.simd.cpuinfo.diagnostic.pas"
DARWIN_SMOKE_SCRIPT = ROOT / "tests" / "nextpas.core.simd" / "compile_darwin_smoke_via_osxcross.sh"
DARWIN_LINK_SMOKE_FILE = ROOT / "tests" / "nextpas.core.simd" / "nextpas.core.simd.darwin_link_smoke.pas"
DARWIN_CPUINFO_LINK_SMOKE_FILE = (
    ROOT
    / "tests"
    / "nextpas.core.simd.cpuinfo"
    / "nextpas.core.simd.cpuinfo.darwin_link_smoke.pas"
)


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


def forbid_pattern(
    a_text: str,
    a_path: Path,
    a_pattern: str,
    a_message: str,
    a_issues: list[dict[str, str]],
) -> int:
    if re.search(a_pattern, a_text, re.IGNORECASE | re.MULTILINE):
        add_issue(a_issues, a_path, a_message)
    return 1


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (
        TIME_CPU_FILE,
        CPUINFO_DIAGNOSTIC_FILE,
        DARWIN_SMOKE_SCRIPT,
        DARWIN_LINK_SMOKE_FILE,
        DARWIN_CPUINFO_LINK_SMOKE_FILE,
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

    l_time_cpu = read_text(TIME_CPU_FILE)
    l_diag = read_text(CPUINFO_DIAGNOSTIC_FILE)
    l_script = read_text(DARWIN_SMOKE_SCRIPT)
    l_link_smoke = read_text(DARWIN_LINK_SMOKE_FILE)
    l_cpuinfo_link_smoke = read_text(DARWIN_CPUINFO_LINK_SMOKE_FILE)

    l_checks += require_pattern(
        l_time_cpu,
        TIME_CPU_FILE,
        r"NanoSleep\s*\(\s*1\s*\)\s*;",
        "NanoSleep(1) fallback/yield contract missing",
        l_issues,
    )
    l_checks += forbid_pattern(
        l_diag,
        CPUINFO_DIAGNOSTIC_FILE,
        r"BaseUnix",
        "Darwin diagnostic compile path should not depend on Linux-only BaseUnix",
        l_issues,
    )
    l_checks += forbid_pattern(
        l_diag,
        CPUINFO_DIAGNOSTIC_FILE,
        r"uses\s+\{\$IFDEF\s+WINDOWS\}\s*Windows\s*\{\$ENDIF\}\s*\{\$IFDEF\s+UNIX\}",
        "diagnostic unit still carries the old empty-uses Darwin hazard",
        l_issues,
    )
    for l_required_unit in (
        "src/nextpas.core.simd.cpuinfo.diagnostic.pas",
        "src/nextpas.core.time.tick.pas",
        "src/nextpas.core.time.stopwatch.pas",
        "tests/nextpas.core.simd/nextpas.core.simd.darwin_link_smoke.pas",
        "tests/nextpas.core.simd.cpuinfo/nextpas.core.simd.cpuinfo.darwin_link_smoke.pas",
    ):
        l_checks += require_pattern(
            l_script,
            DARWIN_SMOKE_SCRIPT,
            re.escape(l_required_unit),
            f"compile smoke script missing unit {l_required_unit}",
            l_issues,
        )
    for l_required_flag in (
        r'-Fi"\$\{REPO_ROOT\}/src"',
        r'-FE"\$\{LUnitOutput\}"',
        r'-FU"\$\{LUnitOutput\}"',
    ):
        l_checks += require_pattern(
            l_script,
            DARWIN_SMOKE_SCRIPT,
            l_required_flag,
            f"compile smoke script missing flag pattern {l_required_flag}",
            l_issues,
        )
    for l_required_token in (
        r"SchedYield\s*;",
        r"NanoSleep\s*\(\s*1\s*\)\s*;",
        r"MakeBestTick",
        r"TStopwatch\.StartNew",
    ):
        l_checks += require_pattern(
            l_link_smoke,
            DARWIN_LINK_SMOKE_FILE,
            l_required_token,
            f"darwin link smoke missing token {l_required_token}",
            l_issues,
        )
    l_checks += require_pattern(
        l_cpuinfo_link_smoke,
        DARWIN_CPUINFO_LINK_SMOKE_FILE,
        r"GetCPUInfo",
        "darwin cpuinfo link smoke missing GetCPUInfo call",
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
        "DARWIN_COMPILE_SMOKE_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[DARWIN-COMPILE-CONTRACT] Darwin compile-smoke contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[DARWIN-COMPILE-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[DARWIN-COMPILE-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check Darwin compile-smoke source contracts."
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
