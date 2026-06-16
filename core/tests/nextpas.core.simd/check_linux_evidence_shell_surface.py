#!/usr/bin/env python3
"""Guard the current Linux evidence shell surface truth."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SHELL_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "BuildOrTest.sh"
WORKFLOW_DOC = ROOT / "tests" / "nextpas.core.simd" / "docs" / "intrinsics_coverage_workflow.md"
CHECKLIST_DOC = ROOT / "docs" / "simd" / "checklist.md"
CLOSEOUT_DOC = ROOT / "docs" / "simd" / "closeout.md"
SCRIPT_MANIFEST = ROOT / "tests" / "nextpas.core.simd" / "scripts" / "SCRIPT_MANIFEST.csv"

REQUIRED_SHELL_FRAGMENTS = [
    "coverage)",
    "run_intrinsics_coverage",
    "check_intrinsics_coverage_layout_contract.py",
    "check_intrinsics_coverage.py",
    "wiring-sync)",
    "check_nonx86_wiring_sync.py",
    "nonx86-ieee754)",
    "TTestCase_NonX86IEEE754",
    "perf-smoke)",
    "check_perf_smoke_log.py",
    "gate)",
    "gate-strict)",
    'Historical Linux shell gate surface currently unavailable in this worktree',
    'Historical Linux closeout shell surface currently unavailable in this worktree',
    'fail_missing_linux_closeout_surface',
    'fail_missing_linux_gate_surface',
]

REQUIRED_WORKFLOW_FRAGMENTS = [
    '当前 worktree 已恢复 `BuildOrTest.sh coverage`；它会先跑 `check_intrinsics_coverage_layout_contract.py`，再跑 live `check_intrinsics_coverage.py`。',
    '当前 historical `evidence-linux` / `gate` / `gate-strict` shell mainline 仍未恢复。',
    '以当前 HEAD 为准，默认 required coverage 是 `sse` 79/79、`mmx` 75/75、`sse2-x86-raw` 221/221，`missing_required=0 missing_optional=0`。',
    '`tests/nextpas.core.simd/test_mmx_raw_leaf_parity/test_mmx_raw_leaf_parity.lpr`',
    '`tests/nextpas.core.simd.intrinsics.experimental/nextpas.core.simd.intrinsics.experimental.testcase.pas`',
    '`BuildOrTest.sh experimental-intrinsics-tests`',
    '`BuildOrTest.sh experimental-intrinsics-closure`',
    '`make -C core/tests/nextpas.core.simd experimental-intrinsics-focused`',
    '`SIMD_COVERAGE_STRICT_EXTRA=1`',
    '`SIMD_COVERAGE_REQUIRE_AVX2=1`',
    '`SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1`',
    '`aes` 6/6',
    '`sha` 7/7',
    'experimental intrinsics tests 不进入 default stable/nightly blocker',
    '`BuildOrTest.sh wiring-sync`',
    '`BuildOrTest.sh nonx86-ieee754`',
    '`BuildOrTest.sh perf-smoke`',
    '`run_backend_benchmarks.sh`',
    '`BuildOrTest.sh gate-summary-selfcheck`',
    '`BuildOrTest.sh freeze-status-linux`',
]

FORBIDDEN_WORKFLOW_FRAGMENTS = [
    '`.github/workflows/simd-nightly-closeout.yml`',
    '`.github/workflows/simd-windows-b07-evidence.yml`',
    'bash tests/nextpas.core.simd/BuildOrTest.sh evidence-linux',
    'bash tests/nextpas.core.simd/BuildOrTest.sh gate\n',
    'SIMD_GATE_WIRING_SYNC=1 SIMD_WIRING_SYNC_STRICT_EXTRA=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate',
    'BuildOrTest.sh gate` 会将关键步骤写入',
    '当某一步失败时，会记录失败步骤与错误码',
]

FORBIDDEN_CHECKLIST_FRAGMENTS = [
    'FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh gate\n',
    'SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate',
    'bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict\n',
    'bash tests/nextpas.core.simd/BuildOrTest.sh evidence-linux',
]

FORBIDDEN_CLOSEOUT_FRAGMENTS = [
    'FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh gate\n',
    'SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate',
    'bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict\n',
    'bash tests/nextpas.core.simd/BuildOrTest.sh evidence-linux',
    'bash tests/nextpas.core.simd/BuildOrTest.sh adapter-sync\n',
    'bash tests/nextpas.core.simd/BuildOrTest.sh experimental-intrinsics\n',
    '或者走 `evidence-linux` 这条固定会把 perf 带进去的证据链',
    '它也会把 `wiring-sync`、`interface-completeness`、`adapter-sync` 这类结构一致性检查一起带上',
]

REQUIRED_CHECKLIST_FRAGMENTS = [
    '当前 worktree 的 shell runner 已恢复 `coverage`，但 historical Linux gate/closeout mainline 仍未恢复。',
    '`BuildOrTest.sh coverage`',
    '`BuildOrTest.sh wiring-sync`',
    '`BuildOrTest.sh nonx86-ieee754`',
    '`BuildOrTest.sh perf-smoke`',
    '`BuildOrTest.sh gate`',
    '`BuildOrTest.sh gate-strict`',
    '`BuildOrTest.sh evidence-linux`',
]

REQUIRED_CLOSEOUT_FRAGMENTS = [
    'Current worktree restores the Linux shell `coverage` helper, but the historical Linux shell `gate` / `gate-strict` / `evidence-linux` mainline remains unavailable.',
    '`BuildOrTest.sh coverage`',
    '`BuildOrTest.sh wiring-sync`',
    '`BuildOrTest.sh nonx86-ieee754`',
    '`BuildOrTest.sh perf-smoke`',
    '`BuildOrTest.sh gate`',
    '`BuildOrTest.sh gate-strict`',
    '`BuildOrTest.sh evidence-linux`',
]

REQUIRED_MANIFEST_ROWS = {
    "collect_linux_simd_evidence.sh": "historical",
    "run_backend_benchmarks.sh": "active",
    "check_linux_evidence_shell_surface.py": "active",
    "check_intrinsics_coverage_layout_contract.py": "active",
}


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


def forbid_fragment(
    a_text: str,
    a_path: Path,
    a_fragment: str,
    a_message: str,
    a_issues: list[dict[str, str]],
) -> int:
    if a_fragment in a_text:
        add_issue(a_issues, a_path, a_message)
    return 1


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (
        SHELL_RUNNER,
        WORKFLOW_DOC,
        CHECKLIST_DOC,
        CLOSEOUT_DOC,
        SCRIPT_MANIFEST,
    ):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing Linux evidence truth-source file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_shell_source = read_text(SHELL_RUNNER)
    l_workflow_source = read_text(WORKFLOW_DOC)
    l_checklist_source = read_text(CHECKLIST_DOC)
    l_closeout_source = read_text(CLOSEOUT_DOC)

    for l_fragment in REQUIRED_SHELL_FRAGMENTS:
        l_checks += require_fragment(
            l_shell_source,
            SHELL_RUNNER,
            l_fragment,
            f"shell runner missing Linux evidence fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_WORKFLOW_FRAGMENTS:
        l_checks += require_fragment(
            l_workflow_source,
            WORKFLOW_DOC,
            l_fragment,
            f"intrinsics workflow missing current Linux shell surface fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in FORBIDDEN_WORKFLOW_FRAGMENTS:
        l_checks += forbid_fragment(
            l_workflow_source,
            WORKFLOW_DOC,
            l_fragment,
            f"intrinsics workflow still cites unavailable dedicated SIMD workflow: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_CHECKLIST_FRAGMENTS:
        l_checks += require_fragment(
            l_checklist_source,
            CHECKLIST_DOC,
            l_fragment,
            f"checklist missing current Linux shell surface fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in FORBIDDEN_CHECKLIST_FRAGMENTS:
        l_checks += forbid_fragment(
            l_checklist_source,
            CHECKLIST_DOC,
            l_fragment,
            f"checklist still presents historical shell surface as a live command: {l_fragment}",
            l_issues,
        )

    for l_fragment in REQUIRED_CLOSEOUT_FRAGMENTS:
        l_checks += require_fragment(
            l_closeout_source,
            CLOSEOUT_DOC,
            l_fragment,
            f"closeout doc missing current Linux shell surface fragment: {l_fragment}",
            l_issues,
        )

    for l_fragment in FORBIDDEN_CLOSEOUT_FRAGMENTS:
        l_checks += forbid_fragment(
            l_closeout_source,
            CLOSEOUT_DOC,
            l_fragment,
            f"closeout doc still presents historical shell surface as a live command: {l_fragment}",
            l_issues,
        )

    with SCRIPT_MANIFEST.open("r", encoding="utf-8", newline="") as l_csv_file:
        l_rows = list(csv.DictReader(l_csv_file))

    for l_path, l_status in sorted(REQUIRED_MANIFEST_ROWS.items()):
        l_matches = [l_row for l_row in l_rows if l_row.get("path") == l_path]
        if not l_matches:
            add_issue(l_issues, SCRIPT_MANIFEST, f"script manifest missing row for {l_path}")
            continue
        for l_row in l_matches:
            l_checks += 1
            if l_row.get("status") != l_status:
                add_issue(
                    l_issues,
                    SCRIPT_MANIFEST,
                    f"script manifest status drift for {l_path}: expected {l_status}, got {l_row.get('status')}",
                )

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "LINUX_EVIDENCE_SHELL_SURFACE "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[LINUX-EVIDENCE-SHELL-SURFACE] Current Linux evidence shell surface truth")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[LINUX-EVIDENCE-SHELL-SURFACE] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[LINUX-EVIDENCE-SHELL-SURFACE] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check the current Linux evidence shell surface truth."
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
