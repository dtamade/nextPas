#!/usr/bin/env python3
"""Guard the current Windows/freeze shell surface truth."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SHELL_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "BuildOrTest.sh"
BATCH_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "buildOrTest.bat"
RUNBOOK = ROOT / "tests" / "nextpas.core.simd" / "docs" / "windows_b07_closeout_runbook.md"
CLOSEOUT_DOC = ROOT / "docs" / "simd" / "closeout.md"
CHECKLIST_DOC = ROOT / "tests" / "nextpas.core.simd" / "docs" / "simd_release_candidate_checklist.md"
SCRIPT_MANIFEST = ROOT / "tests" / "nextpas.core.simd" / "scripts" / "SCRIPT_MANIFEST.csv"

ACTIVE_LOCAL_TOOLS = {
    "rehearse_gate_summary_thresholds.sh": "active",
    "rehearse_freeze_status.sh": "active",
    "check_historical_closeout_current_head_notes.py": "active",
    "check_active_closeout_current_head_truth.py": "active",
    "print_windows_b07_closeout_3cmd.sh": "active",
    "verify_windows_b07_evidence.sh": "active",
}

HISTORICAL_MISSING_HELPERS = {
    "apply_windows_b07_closeout_updates.sh": "historical",
    "finalize_windows_b07_closeout.sh": "historical",
    "preflight_windows_b07_evidence_gh.sh": "historical",
    "run_windows_b07_closeout_finalize.sh": "historical",
    "run_windows_b07_closeout_via_github_actions.sh": "historical",
}

REQUIRED_SHELL_FRAGMENTS = [
    'gate-summary)',
    'generate_gate_summary_sample.py',
    'rehearse_gate_summary_thresholds.sh',
    'inject_gate_summary_sample.sh',
    'rollback_gate_summary_sample.sh',
    'list_gate_summary_backups.sh',
    'check_historical_closeout_current_head_notes.py',
    'check_active_closeout_current_head_truth.py',
    'verify_windows_b07_evidence.sh',
    'evaluate_simd_freeze_status.py',
    '--linux-only',
    'rehearse_freeze_status.sh',
    'print_windows_b07_closeout_3cmd.sh',
]

REQUIRED_UNAVAILABLE_SHELL_FRAGMENTS = [
    'closeout-release)',
    'win-evidence-preflight)',
    'win-evidence-via-gh)',
    'finalize-win-evidence)',
    'evidence-linux)',
    'win-closeout-snippets)',
    'win-closeout-finalize)',
    'fail_missing_windows_closeout_surface',
    'historical Windows/GH closeout shell helper',
    'fail_missing_linux_closeout_surface',
    'historical Linux closeout shell helper',
]

REQUIRED_BATCH_FRAGMENTS = [
    'closeout-release  Historical Windows/GH closeout shell surface currently unavailable in this worktree',
    'evidence-linux  Historical Linux closeout shell surface currently unavailable in this worktree',
    'win-evidence-preflight  Historical Windows/GH closeout shell surface currently unavailable in this worktree',
    'win-evidence-via-gh  Historical Windows/GH closeout shell surface currently unavailable in this worktree',
    'finalize-win-evidence  Historical Windows/GH closeout shell surface currently unavailable in this worktree',
    'win-closeout-snippets  Historical Windows/GH closeout shell surface currently unavailable in this worktree',
    'win-closeout-finalize  Historical Windows/GH closeout shell surface currently unavailable in this worktree',
]

REQUIRED_RUNBOOK_FRAGMENTS = [
    '当前 worktree 当前不提供：',
    '`BuildOrTest.sh closeout-release`',
    '`BuildOrTest.sh win-evidence-preflight`',
    '`BuildOrTest.sh win-evidence-via-gh`',
    '`BuildOrTest.sh finalize-win-evidence`',
    '`BuildOrTest.sh win-closeout-snippets`',
    '`BuildOrTest.sh win-closeout-finalize`',
    '`BuildOrTest.sh evidence-linux`',
    '`BuildOrTest.sh freeze-status`',
    '`BuildOrTest.sh freeze-status-linux`',
    '`BuildOrTest.sh gate-summary-selfcheck`',
    '`BuildOrTest.sh win-closeout-3cmd`',
    '`buildOrTest.bat evidence-win-verify`',
]

REQUIRED_CLOSEOUT_FRAGMENTS = [
    'Current worktree does not restore the historical Windows/GH closeout shell helpers.',
    '`BuildOrTest.sh closeout-release`',
    '`BuildOrTest.sh win-evidence-preflight`',
    '`BuildOrTest.sh win-evidence-via-gh`',
    '`BuildOrTest.sh finalize-win-evidence`',
    '`BuildOrTest.sh win-closeout-snippets`',
    '`BuildOrTest.sh win-closeout-finalize`',
    '`BuildOrTest.sh evidence-linux`',
    '`BuildOrTest.sh freeze-status`',
    '`BuildOrTest.sh freeze-status-linux`',
    '`BuildOrTest.sh gate-summary-selfcheck`',
    '`BuildOrTest.sh win-closeout-3cmd`',
]

REQUIRED_CHECKLIST_FRAGMENTS = [
    'Historical Windows/GH closeout shell helpers are not restored in this worktree.',
    '`BuildOrTest.sh closeout-release`',
    '`BuildOrTest.sh win-evidence-preflight`',
    '`BuildOrTest.sh win-evidence-via-gh`',
    '`BuildOrTest.sh win-closeout-finalize`',
    '`BuildOrTest.sh freeze-status-linux`',
    '`BuildOrTest.sh gate-summary-selfcheck`',
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

    for l_path in (
        SHELL_RUNNER,
        BATCH_RUNNER,
        RUNBOOK,
        CLOSEOUT_DOC,
        CHECKLIST_DOC,
        SCRIPT_MANIFEST,
    ):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing truth-source file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_shell_source = read_text(SHELL_RUNNER)
    l_batch_source = read_text(BATCH_RUNNER)
    l_runbook_source = read_text(RUNBOOK)
    l_closeout_source = read_text(CLOSEOUT_DOC)
    l_checklist_source = read_text(CHECKLIST_DOC)

    for l_fragment in REQUIRED_SHELL_FRAGMENTS:
        l_checks += require_fragment(
            l_shell_source,
            SHELL_RUNNER,
            l_fragment,
            f"shell runner missing required Windows/freeze fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_UNAVAILABLE_SHELL_FRAGMENTS:
        l_checks += require_fragment(
            l_shell_source,
            SHELL_RUNNER,
            l_fragment,
            f"shell runner missing fail-close Windows/GH fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_BATCH_FRAGMENTS:
        l_checks += require_fragment(
            l_batch_source,
            BATCH_RUNNER,
            l_fragment,
            f"batch runner missing Windows/freeze help truth fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_RUNBOOK_FRAGMENTS:
        l_checks += require_fragment(
            l_runbook_source,
            RUNBOOK,
            l_fragment,
            f"Windows runbook missing current worktree truth fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_CLOSEOUT_FRAGMENTS:
        l_checks += require_fragment(
            l_closeout_source,
            CLOSEOUT_DOC,
            l_fragment,
            f"closeout doc missing current worktree truth fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_CHECKLIST_FRAGMENTS:
        l_checks += require_fragment(
            l_checklist_source,
            CHECKLIST_DOC,
            l_fragment,
            f"release checklist missing current worktree truth fragment: {l_fragment}",
            l_issues,
        )

    with SCRIPT_MANIFEST.open("r", encoding="utf-8", newline="") as l_csv_file:
        l_rows = list(csv.DictReader(l_csv_file))

    for l_helper_name, l_expected_status in sorted(HISTORICAL_MISSING_HELPERS.items()):
        l_helper_path = ROOT / "tests" / "nextpas.core.simd" / l_helper_name
        l_rows_for_helper = [l_row for l_row in l_rows if l_row.get("path") == l_helper_name]
        if not l_rows_for_helper:
            add_issue(l_issues, SCRIPT_MANIFEST, f"script manifest missing row for {l_helper_name}")
            continue

        for l_row in l_rows_for_helper:
            l_checks += 1
            if l_helper_path.exists():
                add_issue(
                    l_issues,
                    SCRIPT_MANIFEST,
                    f"historical helper unexpectedly exists again: {l_helper_name}",
                )
            elif l_row.get("status") != l_expected_status:
                add_issue(
                    l_issues,
                    SCRIPT_MANIFEST,
                    f"missing helper {l_helper_name} must stay {l_expected_status} in script manifest",
                )

    for l_tool_name, l_expected_status in sorted(ACTIVE_LOCAL_TOOLS.items()):
        l_tool_path = ROOT / "tests" / "nextpas.core.simd" / l_tool_name
        l_rows_for_tool = [l_row for l_row in l_rows if l_row.get("path") == l_tool_name]
        if not l_rows_for_tool:
            add_issue(l_issues, SCRIPT_MANIFEST, f"script manifest missing row for {l_tool_name}")
            continue

        if not l_tool_path.exists():
            add_issue(l_issues, SCRIPT_MANIFEST, f"active local tool missing from worktree: {l_tool_name}")
            continue

        for l_row in l_rows_for_tool:
            l_checks += 1
            if l_row.get("status") != l_expected_status:
                add_issue(
                    l_issues,
                    SCRIPT_MANIFEST,
                    f"live local tool {l_tool_name} must be marked {l_expected_status} in script manifest",
                )

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "WINDOWS_FREEZE_SHELL_SURFACE "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[WINDOWS-FREEZE-SHELL-SURFACE] Current Windows/freeze shell surface truth")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[WINDOWS-FREEZE-SHELL-SURFACE] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[WINDOWS-FREEZE-SHELL-SURFACE] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check the current Windows/freeze shell truth surface."
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
