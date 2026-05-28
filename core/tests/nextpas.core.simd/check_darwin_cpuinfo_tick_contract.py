#!/usr/bin/env python3
"""Guard Darwin-specific CPUInfo lazy routing and tick ownership contracts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CPUINFO_LAZY_FILE = ROOT / "src" / "nextpas.core.simd.cpuinfo.lazy.pas"
DARWIN_TICK_FILE = ROOT / "src" / "nextpas.core.time.tick.darwin.pas"

CPUINFO_EXPECTED_PATTERNS = (
    (re.compile(r"\{\$IFDEF\s+DARWIN\}", re.IGNORECASE), "missing Darwin routing guard"),
    (
        re.compile(r"fafafa\.core\.simd\.cpuinfo\.darwin", re.IGNORECASE),
        "missing Darwin CPUInfo unit import",
    ),
    (
        re.compile(r"fafafa\.core\.simd\.cpuinfo\.unix", re.IGNORECASE),
        "missing Unix CPUInfo fallback import",
    ),
)

DARWIN_TICK_EXPECTED_PATTERNS = (
    (re.compile(r"\bUnix\b"), "missing Unix RTL dependency"),
    (re.compile(r"\bTStdTick\s*=\s*class\s*\(\s*TTick\s*\)", re.IGNORECASE), "missing local TStdTick implementation"),
    (
        re.compile(r"fpgettimeofday\s*\(\s*@LTV\s*,\s*nil\s*\)\s*;", re.IGNORECASE),
        "missing local fpgettimeofday standard tick path",
    ),
    (
        re.compile(r"Result\s*:=\s*TStdTick\.Create\s*;", re.IGNORECASE),
        "MakeTick no longer binds to local TStdTick",
    ),
)

DARWIN_TICK_FORBIDDEN_PATTERNS = (
    (
        re.compile(r"fafafa\.core\.time\.tick\.unix", re.IGNORECASE),
        "Darwin tick must not depend on nextpas.core.time.tick.unix",
    ),
)


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def add_issue(a_issues: list[dict[str, str]], a_path: Path, a_message: str) -> None:
    a_issues.append({"file": str(a_path.relative_to(ROOT)), "message": a_message})


def check_patterns(
    a_text: str,
    a_path: Path,
    a_expected: tuple[tuple[re.Pattern[str], str], ...],
    a_forbidden: tuple[tuple[re.Pattern[str], str], ...],
    a_issues: list[dict[str, str]],
) -> int:
    l_checks = 0

    for l_pattern, l_message in a_expected:
        l_checks += 1
        if not l_pattern.search(a_text):
            add_issue(a_issues, a_path, l_message)

    for l_pattern, l_message in a_forbidden:
        l_checks += 1
        if l_pattern.search(a_text):
            add_issue(a_issues, a_path, l_message)

    return l_checks


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (CPUINFO_LAZY_FILE, DARWIN_TICK_FILE):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing source file")
            return {
                "ok": False,
                "checks": l_checks,
                "issues": len(l_issues),
                "issue_entries": l_issues,
            }

    l_checks += check_patterns(
        read_text(CPUINFO_LAZY_FILE),
        CPUINFO_LAZY_FILE,
        CPUINFO_EXPECTED_PATTERNS,
        (),
        l_issues,
    )
    l_checks += check_patterns(
        read_text(DARWIN_TICK_FILE),
        DARWIN_TICK_FILE,
        DARWIN_TICK_EXPECTED_PATTERNS,
        DARWIN_TICK_FORBIDDEN_PATTERNS,
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
        "DARWIN_CPUINFO_TICK_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[DARWIN-CONTRACT] Darwin CPUInfo lazy / tick contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[DARWIN-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[DARWIN-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check Darwin CPUInfo lazy routing and tick ownership contracts."
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
