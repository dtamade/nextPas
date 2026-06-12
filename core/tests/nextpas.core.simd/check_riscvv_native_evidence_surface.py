#!/usr/bin/env python3
"""Guard the current RISCVV native-evidence helper truth surface."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BATCH_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "buildOrTest.bat"
RUNBOOK = ROOT / "tests" / "nextpas.core.simd" / "docs" / "riscvv_native_closeout_runbook.md"
CLOSEOUT_DOC = ROOT / "docs" / "simd" / "closeout.md"
SCRIPT_MANIFEST = ROOT / "tests" / "nextpas.core.simd" / "scripts" / "SCRIPT_MANIFEST.csv"

MISSING_HELPERS = {
    "run_nonx86_native_evidence_via_clean_worktree.sh",
    "run_nonx86_native_evidence_via_github_actions.sh",
    "verify_riscvv_custom_runner_host.sh",
    "export_release_evidence_bundle.py",
}

REQUIRED_BATCH_FRAGMENTS = [
    ":fail_missing_shell_helper_surface",
    'echo [%SURFACE_LABEL%] FAILED ^(historical shell helper "%SURFACE_ACTION%" is not restored in this worktree^)',
    "collect_nonx86_native_evidence.sh riscvv",
    "BuildOrTest.sh import-nonx86-native-evidence ^<native-evidence-drop^>",
    "BuildOrTest.sh closeout-host-local-from-import ^<native-evidence-drop^>",
    "call :fail_missing_shell_helper_surface RELEASE-EVIDENCE release-evidence",
    "call :fail_missing_shell_helper_surface NATIVE-EVIDENCE-GH native-evidence-via-gh",
    "call :fail_missing_shell_helper_surface NATIVE-EVIDENCE-GH-CLEAN native-evidence-via-gh-clean",
    "call :fail_missing_shell_helper_surface RISCVV-RUNNER riscvv-runner-registration",
    "call :fail_missing_shell_helper_surface RISCVV-RUNNER riscvv-runner-host-preflight",
    "call :fail_missing_shell_helper_surface RISCVV-RUNNER riscvv-runner-3cmd",
    "release-evidence  Historical shell helper surface currently unavailable in this worktree",
    "native-evidence-via-gh  Historical shell helper surface currently unavailable in this worktree",
    "native-evidence-via-gh-clean  Historical shell helper surface currently unavailable in this worktree",
    "riscvv-runner-registration  Historical shell helper surface currently unavailable in this worktree",
    "riscvv-runner-host-preflight  Historical shell helper surface currently unavailable in this worktree",
    "riscvv-runner-3cmd  Historical shell helper surface currently unavailable in this worktree",
]

REQUIRED_RUNBOOK_FRAGMENTS = [
    "当前 repo 当前不提供：",
    "`BuildOrTest.sh native-evidence-via-gh`",
    "`BuildOrTest.sh native-evidence-via-gh-clean`",
    "`BuildOrTest.sh riscvv-runner-registration`",
    "`BuildOrTest.sh riscvv-runner-host-preflight`",
    "`BuildOrTest.sh riscvv-runner-3cmd`",
    "`BuildOrTest.sh release-evidence`",
    "collect_nonx86_native_evidence.sh riscvv",
    "BuildOrTest.sh import-nonx86-native-evidence /path/to/native-evidence-drop",
    "BuildOrTest.sh closeout-host-local-from-import /path/to/native-evidence-drop",
    "BuildOrTest.sh verify-nonx86-native-evidence",
    "历史 runbook / manifest 里提到的 GH dispatch / clean-worktree / runner-registration helper 在当前 worktree 并未恢复",
]

REQUIRED_CLOSEOUT_FRAGMENTS = [
    "Historical `release-evidence` / `riscvv-runner-3cmd` / `native-evidence-via-gh-clean` helper names are not restored in this worktree.",
    "collect_nonx86_native_evidence.sh riscvv",
    "BuildOrTest.sh import-nonx86-native-evidence /path/to/native-evidence-drop",
    "BuildOrTest.sh closeout-host-local-from-import /path/to/native-evidence-drop",
]


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def add_issue(a_issues: list[dict[str, str]], a_path: Path, a_message: str) -> None:
    a_issues.append({"file": str(a_path.relative_to(ROOT)), "message": a_message})


def require_fragment(
    a_text: str,
    a_path: Path,
    a_fragment: str,
    a_message: str,
    a_issues: list[dict[str, str]],
) -> int:
    if a_fragment not in a_text:
        add_issue(a_issues, a_path, a_message)
    return 1


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (BATCH_RUNNER, RUNBOOK, CLOSEOUT_DOC, SCRIPT_MANIFEST):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing truth-source file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_batch_source = read_text(BATCH_RUNNER)
    l_runbook_source = read_text(RUNBOOK)
    l_closeout_source = read_text(CLOSEOUT_DOC)

    for l_fragment in REQUIRED_BATCH_FRAGMENTS:
        l_checks += require_fragment(
            l_batch_source,
            BATCH_RUNNER,
            l_fragment,
            f"batch runner missing required truth fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_RUNBOOK_FRAGMENTS:
        l_checks += require_fragment(
            l_runbook_source,
            RUNBOOK,
            l_fragment,
            f"riscvv runbook missing required truth fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_CLOSEOUT_FRAGMENTS:
        l_checks += require_fragment(
            l_closeout_source,
            CLOSEOUT_DOC,
            l_fragment,
            f"closeout doc missing required truth fragment: {l_fragment}",
            l_issues,
        )

    with SCRIPT_MANIFEST.open("r", encoding="utf-8", newline="") as l_csv_file:
        l_rows = list(csv.DictReader(l_csv_file))

    for l_helper_name in sorted(MISSING_HELPERS):
        l_helper_path = ROOT / "tests" / "nextpas.core.simd" / l_helper_name
        l_rows_for_helper = [l_row for l_row in l_rows if l_row.get("path") == l_helper_name]
        if not l_rows_for_helper:
            add_issue(l_issues, SCRIPT_MANIFEST, f"script manifest missing row for {l_helper_name}")
            continue

        for l_row in l_rows_for_helper:
            l_checks += 1
            if l_helper_path.exists():
                continue
            if l_row.get("status") != "historical":
                add_issue(
                    l_issues,
                    SCRIPT_MANIFEST,
                    f"missing helper {l_helper_name} must not stay active in script manifest",
                )

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "RISCVV_NATIVE_EVIDENCE_SURFACE "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[RISCVV-NATIVE-EVIDENCE-SURFACE] Current RISCVV/native-evidence helper truth")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[RISCVV-NATIVE-EVIDENCE-SURFACE] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[RISCVV-NATIVE-EVIDENCE-SURFACE] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check the current RISCVV/native-evidence helper truth surface."
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
