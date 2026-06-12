#!/usr/bin/env python3
"""Guard the public facade RISC-V V opt-in entry contract."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
FACADE_FILE = ROOT / "src" / "nextpas.core.simd.pas"
SMOKE_FILE = ROOT / "tests" / "nextpas.core.simd" / "nextpas.core.simd.riscvv_facade_optin_smoke.pas"
MAKEFILE = ROOT / "tests" / "nextpas.core.simd" / "Makefile"


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
    if re.search(a_pattern, a_text, re.IGNORECASE | re.MULTILINE | re.DOTALL) is None:
        add_issue(a_issues, a_path, a_message)
    return 1


def extract_make_target_body(a_text: str, a_target: str) -> str:
    l_lines = a_text.splitlines()
    for l_index, l_line in enumerate(l_lines):
        if not re.match(rf"^{re.escape(a_target)}\s*:", l_line):
            continue

        l_body: list[str] = []
        for l_body_line in l_lines[l_index + 1:]:
            if l_body_line and not l_body_line.startswith(("\t", " ")):
                break
            l_body.append(l_body_line)
        return "\n".join(l_body)

    return ""


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (FACADE_FILE, SMOKE_FILE, MAKEFILE):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing contract file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_facade = read_text(FACADE_FILE)
    l_smoke = read_text(SMOKE_FILE)
    l_makefile = read_text(MAKEFILE)
    l_audit_body = extract_make_target_body(l_makefile, "audit")
    l_riscvv_target_body = extract_make_target_body(l_makefile, "riscvv-facade-optin-compile")

    l_checks += require_pattern(
        l_facade,
        FACADE_FILE,
        r"\{\$IF\s+DEFINED\(SIMD_RISCV_AVAILABLE\)\s+AND\s+DEFINED\(SIMD_EXPERIMENTAL_RISCVV\)\}\s*,\s*nextpas\.core\.simd\.riscvv\b",
        "RISC-V V facade opt-in uses entry must keep a leading comma in the public umbrella",
        l_issues,
    )
    l_checks += require_pattern(
        l_smoke,
        SMOKE_FILE,
        r"uses\s+nextpas\.core\.simd\s*;",
        "RISC-V V facade opt-in smoke must import the public facade, not the backend directly",
        l_issues,
    )
    for l_token in (
        "-dSIMD_RISCV_AVAILABLE",
        "-dSIMD_EXPERIMENTAL_RISCVV",
        "-gh",
        "$(RISCVV_FACADE_OPTIN_SMOKE).pas",
        "$(BUILD_DIR)/$(RISCVV_FACADE_OPTIN_SMOKE)",
        "unfreed memory blocks",
    ):
        l_checks += require_pattern(
            l_riscvv_target_body,
            MAKEFILE,
            re.escape(l_token),
            f"riscvv-facade-optin-compile target missing token `{l_token}`",
            l_issues,
        )
    l_checks += require_pattern(
        l_makefile,
        MAKEFILE,
        r"^riscvv-facade-optin-compile\s*:",
        "Makefile missing riscvv-facade-optin-compile target",
        l_issues,
    )
    l_checks += require_pattern(
        l_audit_body,
        MAKEFILE,
        r"check_riscvv_facade_optin_contract\.py",
        "audit target must run the RISC-V facade opt-in contract checker",
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
        "RISCVV_FACADE_OPTIN_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[RISCVV-FACADE-OPTIN] Public facade opt-in contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")
    if a_result["issue_entries"]:
        print("[RISCVV-FACADE-OPTIN] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[RISCVV-FACADE-OPTIN] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check RISC-V V public facade opt-in source contracts."
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
