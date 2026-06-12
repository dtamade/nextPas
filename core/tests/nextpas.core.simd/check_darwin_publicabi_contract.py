#!/usr/bin/env python3
"""Guard Darwin-specific publicabi loader/export diagnostics from source."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PUBLICABI_RUNNER = ROOT / "tests" / "nextpas.core.simd.publicabi" / "BuildOrTest.sh"
PUBLICABI_SMOKE = ROOT / "tests" / "nextpas.core.simd.publicabi" / "publicabi_smoke.c"


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

    for l_path in (PUBLICABI_RUNNER, PUBLICABI_SMOKE):
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

    for l_pattern, l_message in (
        (r'libnextpas.*\.dylib', "runner missing dylib library discovery"),
        (r'nm -gU', "runner missing Darwin export inspection path"),
        (r'NEXTPAS_PUBLICABI_DLOPEN_SCOPE=global', "runner missing Darwin global-scope retry"),
        (r'nextpas_simd_get_public_api_v2', "runner no longer requires public_api_v2 export"),
    ):
        l_checks += require_pattern(l_runner, PUBLICABI_RUNNER, l_pattern, l_message, l_issues)

    for l_pattern, l_message in (
        (r'current_dlopen_scope', "smoke harness missing dlopen scope diagnostics"),
        (r'use_global_dlopen_scope', "smoke harness missing selectable dlopen scope"),
        (r'probe_symbol_variant', "smoke harness missing Darwin symbol variant probes"),
        (r'resolve_required_symbol', "smoke harness missing required-symbol resolver"),
        (r'RTLD_DEFAULT underscore', "smoke harness missing RTLD_DEFAULT underscore probe"),
        (r'NEXTPAS_PUBLICABI_DLOPEN_SCOPE', "smoke harness missing env-controlled loader scope"),
        (r'nextpas_simd_get_public_api_v2', "smoke harness lost public_api_v2 coverage"),
    ):
        l_checks += require_pattern(l_smoke, PUBLICABI_SMOKE, l_pattern, l_message, l_issues)

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "DARWIN_PUBLICABI_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[DARWIN-PUBLICABI-CONTRACT] Darwin publicabi loader/export contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[DARWIN-PUBLICABI-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[DARWIN-PUBLICABI-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check Darwin publicabi loader/export source contracts."
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
