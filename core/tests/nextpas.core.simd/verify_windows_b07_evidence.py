#!/usr/bin/env python3
"""Verify Windows B07 evidence logs from the shell side."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED_PATTERNS = (
    "[B07] Windows evidence capture",
    "[B07] Source: collect_windows_b07_evidence.bat",
    "[B07] HostOS: Windows_NT",
    "[B07] CmdVer: Microsoft Windows",
    "[GATE] OK",
    "[B07] GATE_EXIT_CODE=0",
    "[BACKEND-OPS] Building standalone program:",
    "[BACKEND-OPS] Running standalone program:",
    "[SIMD-BOUNDARY] Building standalone program:",
    "[SIMD-BOUNDARY] Running standalone program:",
    "[PUBLIC-SMOKE] Building standalone smoke:",
    "[PUBLIC-SMOKE] Running standalone smoke:",
    "[PASS] Default backend is ",
    "[DISPATCH-PREINIT] Building standalone smoke:",
    "[DISPATCH-PREINIT] Running standalone smoke:",
    "[DISPATCH-PREINIT] OK",
)

FALLBACK_GATE_PATTERNS = (
    "[GATE] 1/6 Build + check SIMD module",
    "[GATE] 2/6 SIMD list suites",
    "[GATE] 3/6 SIMD AVX2 stable vector suites",
    "[GATE] 4/6 CPUInfo portable suites",
    "[GATE] 5/6 CPUInfo x86 suites",
    "[GATE] 6/6 Filtered run_all check chain",
)


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Verify Windows B07 evidence logs from the shell side."
    )
    l_parser.add_argument("log_path", nargs="?", default="", help="evidence log path")
    l_parser.add_argument("summary_json_path", nargs="?", default="", help="gate summary json path")
    l_parser.add_argument(
        "--allow-simulated",
        action="store_true",
        help="allow simulated evidence markers for rehearsal only",
    )
    return l_parser.parse_args()


def extract_b07_value(a_lines: list[str], a_key: str) -> str:
    l_prefix = f"[B07] {a_key}:"
    for l_line in a_lines:
        if l_line.startswith(l_prefix):
            return l_line[len(l_prefix) :].strip()
    return ""


def require_contains(
    a_issues: list[str], a_lines: list[str], a_pattern: str, a_message: str | None = None
) -> None:
    if not any(a_pattern in l_line for l_line in a_lines):
        a_issues.append(a_message or f"Missing pattern: {a_pattern}")


def require_command_marker(a_issues: list[str], a_lines: list[str]) -> None:
    for l_pattern in ("[B07] Command: buildOrTest.bat gate", "[B07] Command: BuildOrTest.sh gate"):
        if any(l_pattern in l_line for l_line in a_lines):
            return
    a_issues.append("Missing command marker for gate entry")


def require_working_dir(a_issues: list[str], a_lines: list[str]) -> None:
    if not any(l_line.startswith("[B07] Working dir: ") for l_line in a_lines):
        a_issues.append("Missing B07 value: Working dir")


def check_simulated_source(a_issues: list[str], a_lines: list[str], a_log_path: Path, a_allow_simulated: bool) -> None:
    if a_allow_simulated:
        return

    l_has_simulated_marker = any(
        l_line == "[B07] Simulated: yes"
        or l_line.startswith("[SIMULATE]")
        or l_line == "[B07] Source: simulate_windows_b07_evidence.sh"
        for l_line in a_lines
    )
    if l_has_simulated_marker or ".simulated." in a_log_path.name:
        a_issues.append("Invalid source: simulated evidence requires --allow-simulated")


def resolve_summary_json_path(a_lines: list[str], a_log_path: Path, a_arg_path: str) -> Path:
    if a_arg_path:
        return Path(a_arg_path).expanduser()

    l_value = extract_b07_value(a_lines, "GateSummaryJson")
    if l_value:
        return Path(l_value).expanduser()
    return a_log_path.with_name("gate_summary.json")


def verify_summary_json(a_path: Path) -> tuple[int, str]:
    if not a_path.is_file():
        return 10, ""

    try:
        l_payload = json.loads(a_path.read_text(encoding="utf-8"))
    except Exception as l_exc:  # pragma: no cover - defensive path
        return 1, f"Invalid gate summary json: {a_path} ({l_exc})"

    if not isinstance(l_payload, dict):
        return 1, f"Invalid gate summary json payload type: {a_path}"

    if "checks" not in l_payload and "rows" not in l_payload and "matched_rows" not in l_payload:
        return 1, f"Invalid gate summary json payload shape: {a_path}"

    return 0, ""


def require_publicabi_fallback(a_issues: list[str], a_lines: list[str]) -> None:
    if any("[GATE] Optional public ABI smoke" in l_line for l_line in a_lines):
        return
    if any(
        "--suite=TTestCase_PublicAbi,TTestCase_SimdConcurrentPublicAbi,TTestCase_SimdConcurrentFramework"
        in l_line
        for l_line in a_lines
    ):
        return
    a_issues.append(
        "Missing public ABI witness (expected old gate marker or current public ABI concurrent suite line)"
    )


def extract_metric(a_lines: list[str], a_name: str) -> str:
    l_pattern = re.compile(rf"^(?:\[B07\]\s*)?{re.escape(a_name)}:\s*(.+?)\s*$")
    l_value = ""
    for l_line in a_lines:
        l_match = l_pattern.match(l_line)
        if l_match:
            l_value = l_match.group(1).strip().replace(" ", "")
    return l_value


def require_metrics(a_issues: list[str], a_lines: list[str]) -> None:
    l_total = extract_metric(a_lines, "Total")
    l_passed = extract_metric(a_lines, "Passed")
    l_failed = extract_metric(a_lines, "Failed")

    if not l_total:
        a_issues.append("Missing summary metric: Total")
    if not l_passed:
        a_issues.append("Missing summary metric: Passed")
    if not l_failed:
        a_issues.append("Missing summary metric: Failed")
    if not l_total or not l_passed or not l_failed:
        return

    if not l_total.isdigit():
        a_issues.append(f"Invalid summary: total is not numeric ({l_total})")
        return
    if not l_passed.isdigit():
        a_issues.append(f"Invalid summary: passed is not numeric ({l_passed})")
        return
    if not l_failed.isdigit():
        a_issues.append(f"Invalid summary: failed is not numeric ({l_failed})")
        return

    l_total_num = int(l_total)
    l_passed_num = int(l_passed)
    l_failed_num = int(l_failed)

    if l_failed_num != 0:
        a_issues.append(f"Invalid summary: failed={l_failed_num} (expect 0)")
    if l_total_num != l_passed_num:
        a_issues.append(
            f"Invalid summary: total={l_total_num} passed={l_passed_num} (expect total==passed)"
        )
    if l_total_num < 3:
        a_issues.append(f"Invalid summary: total={l_total_num} (expect >=3)")


def main() -> int:
    l_args = parse_args()
    l_root = Path(__file__).resolve().parent
    l_log_path = Path(l_args.log_path).expanduser() if l_args.log_path else l_root / "logs" / "windows_b07_gate.log"

    if not l_log_path.is_file():
        print(f"[EVIDENCE] Missing log: {l_log_path}")
        return 2

    l_lines = l_log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    l_issues: list[str] = []

    for l_pattern in REQUIRED_PATTERNS:
        require_contains(l_issues, l_lines, l_pattern)

    require_working_dir(l_issues, l_lines)
    require_command_marker(l_issues, l_lines)
    check_simulated_source(l_issues, l_lines, l_log_path, l_args.allow_simulated)

    l_summary_json_path = resolve_summary_json_path(l_lines, l_log_path, l_args.summary_json_path)
    l_summary_json_rc, l_summary_json_issue = verify_summary_json(l_summary_json_path)
    if l_summary_json_rc == 10:
        for l_pattern in FALLBACK_GATE_PATTERNS:
            require_contains(l_issues, l_lines, l_pattern)
        require_publicabi_fallback(l_issues, l_lines)
    elif l_summary_json_rc != 0:
        l_issues.append(l_summary_json_issue)

    require_metrics(l_issues, l_lines)

    if l_issues:
        for l_issue in l_issues:
            print(f"[EVIDENCE] {l_issue}")
        print(f"[EVIDENCE] FAILED: {l_log_path}")
        return 1

    print(f"[EVIDENCE] OK: {l_log_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
