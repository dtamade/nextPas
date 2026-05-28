#!/usr/bin/env python3
"""
Check non-x86 wiring checklist consistency between:
1) shared helper slot list
2) legacy wiring assertions
3) grouped wiring assertions
4) non-x86 interface checklist markdown markers
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


HELPER_NAME = "AssertNonX86DispatchTableWiringGroupsAssigned"
LEGACY_METHOD = "TTestCase_DispatchAPI.Test_NonX86_DispatchTable_WiringChecklist"
GROUPED_METHOD = "TTestCase_DispatchAPI.Test_NonX86_DispatchTable_WiringChecklist_Grouped"
HELPER_PATTERN = re.compile(rf"^procedure\s+{re.escape(HELPER_NAME)}\b", re.IGNORECASE | re.MULTILINE)
ROUTINE_START_PATTERN = re.compile(r"^(procedure|function)\s+[A-Za-z_][A-Za-z0-9_\.]*\b", re.IGNORECASE | re.MULTILINE)


def extract_routine_block(source_text: str, symbol_name: str) -> str:
    header_pattern = re.compile(
        rf"^(procedure|function)\s+{re.escape(symbol_name)}\b.*$",
        re.IGNORECASE | re.MULTILINE,
    )
    header_match = header_pattern.search(source_text)
    if not header_match:
        raise RuntimeError(f"routine not found: {symbol_name}")

    start = header_match.start()
    next_match = ROUTINE_START_PATTERN.search(source_text, header_match.end())
    while next_match is not None and next_match.start() == start:
        next_match = ROUTINE_START_PATTERN.search(source_text, next_match.end())
    end = next_match.start() if next_match is not None else len(source_text)
    return source_text[start:end]


def parse_slots_from_assigned(method_body: str) -> set[str]:
    return set(re.findall(r"Assigned\((?:LTable|aTable)\.([A-Za-z0-9_]+)\)", method_body))


def parse_slots_from_pointers(method_body: str) -> set[str]:
    return set(re.findall(r"Pointer\((?:LTable|aTable)\.([A-Za-z0-9_]+)\)", method_body))


def parse_slots_from_method(method_body: str, helper_slots: set[str]) -> tuple[set[str], bool]:
    uses_helper = f"{HELPER_NAME}(" in method_body
    if uses_helper:
        return set(helper_slots), True

    assigned_slots = parse_slots_from_assigned(method_body)
    if assigned_slots:
        return assigned_slots, False

    pointer_slots = parse_slots_from_pointers(method_body)
    if pointer_slots:
        return pointer_slots, False

    raise RuntimeError(f"unable to infer slot list from routine body using {HELPER_NAME}")


def evaluate_exit_code(result: dict[str, Any], strict_extra: bool) -> int:
    if result["helper_count"] == 0:
        return 1
    if result["missing_in_grouped"]:
        return 1
    if strict_extra and result["extra_in_grouped"]:
        return 1
    if result["missing_markers"]:
        return 1
    if not result["legacy_uses_shared_helper"]:
        return 1
    if not result["grouped_uses_shared_helper"]:
        return 1
    return 0


def render_summary_line(result: dict[str, Any], strict_extra: bool) -> str:
    return (
        "WIRING_SYNC_SUMMARY "
        f"legacy={result['legacy_count']} "
        f"grouped={result['grouped_count']} "
        f"helper={result['helper_count']} "
        f"missing={len(result['missing_in_grouped'])} "
        f"extra={len(result['extra_in_grouped'])} "
        f"markers_missing={len(result['missing_markers'])} "
        f"strict_extra={1 if strict_extra else 0} "
        f"shared_legacy={1 if result['legacy_uses_shared_helper'] else 0} "
        f"shared_grouped={1 if result['grouped_uses_shared_helper'] else 0}"
    )


def print_human_result(result: dict[str, Any], strict_extra: bool) -> None:
    print("[WIRING-SYNC] non-x86 wiring consistency")
    print(f"  - helper slots:  {result['helper_count']}")
    print(f"  - legacy slots:  {result['legacy_count']}")
    print(f"  - grouped slots: {result['grouped_count']}")
    print(f"  - shared helper in legacy:  {result['legacy_uses_shared_helper']}")
    print(f"  - shared helper in grouped: {result['grouped_uses_shared_helper']}")
    print(f"  - missing in grouped: {len(result['missing_in_grouped'])}")
    print(f"  - extra in grouped:   {len(result['extra_in_grouped'])}")

    if result["missing_in_grouped"]:
        print("[WIRING-SYNC] Missing grouped slots:")
        for slot in result["missing_in_grouped"]:
            print(f"  - {slot}")

    if result["extra_in_grouped"]:
        if strict_extra:
            print("[WIRING-SYNC] Extra grouped slots (strict mode):")
        else:
            print("[WIRING-SYNC] Extra grouped slots (non-strict, info):")
        for slot in result["extra_in_grouped"]:
            print(f"  - {slot}")

    if not result["legacy_uses_shared_helper"]:
        print(f"[WIRING-SYNC] Legacy method does not delegate to {HELPER_NAME}")
    if not result["grouped_uses_shared_helper"]:
        print(f"[WIRING-SYNC] Grouped method does not delegate to {HELPER_NAME}")

    if result["missing_markers"]:
        print("[WIRING-SYNC] Checklist missing markers:")
        for marker in result["missing_markers"]:
            print(f"  - {marker}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Check non-x86 wiring sync")
    parser.add_argument("--strict-extra", action="store_true", help="fail when grouped slots are beyond legacy slots")
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON result")
    parser.add_argument("--summary-line", action="store_true", help="print one-line summary for gate logs")
    parser.add_argument("--testcase", default="tests/nextpas.core.simd/nextpas.core.simd.dispatchapi.testcase.pas")
    parser.add_argument("--checklist", default="docs/nextpas.core.simd.checklist.md")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    testcase_path = repo_root / args.testcase
    checklist_path = repo_root / args.checklist

    if not testcase_path.exists() or not checklist_path.exists():
        error_result = {
            "ok": False,
            "error": "input-file-missing",
            "testcase_exists": testcase_path.exists(),
            "checklist_exists": checklist_path.exists(),
            "testcase": str(testcase_path),
            "checklist": str(checklist_path),
        }
        if args.json:
            print(json.dumps(error_result, ensure_ascii=False, sort_keys=True))
        else:
            if not testcase_path.exists():
                print(f"[WIRING-SYNC] Missing testcase: {testcase_path}")
            if not checklist_path.exists():
                print(f"[WIRING-SYNC] Missing checklist: {checklist_path}")
        return 2

    try:
        testcase_text = testcase_path.read_text(encoding="utf-8")
        checklist_text = checklist_path.read_text(encoding="utf-8")

        helper_body = extract_routine_block(testcase_text, HELPER_NAME)
        legacy_body = extract_routine_block(testcase_text, LEGACY_METHOD)
        grouped_body = extract_routine_block(testcase_text, GROUPED_METHOD)

        helper_slots = parse_slots_from_pointers(helper_body)
        legacy_slots, legacy_uses_shared_helper = parse_slots_from_method(legacy_body, helper_slots)
        grouped_slots, grouped_uses_shared_helper = parse_slots_from_method(grouped_body, helper_slots)

        checklist_markers = {
            "wiring_grouped_line": [
                "Wiring grouped-batch assertions",
                "Wiring 分组批量断言已落地",
                "`Wiring` grouped-batch assertions",
            ],
            "wiring_grouped_method": ["Test_NonX86_DispatchTable_WiringChecklist_Grouped"],
            "wiring_grouped_tag": ["WiringGrouped"],
            "wiring_shared_helper": [HELPER_NAME],
        }

        missing_markers = [
            name
            for name, marker_candidates in checklist_markers.items()
            if not any(marker in checklist_text for marker in marker_candidates)
        ]

        result = {
            "helper_count": len(helper_slots),
            "legacy_count": len(legacy_slots),
            "grouped_count": len(grouped_slots),
            "legacy_uses_shared_helper": legacy_uses_shared_helper,
            "grouped_uses_shared_helper": grouped_uses_shared_helper,
            "missing_in_grouped": sorted(legacy_slots - grouped_slots),
            "extra_in_grouped": sorted(grouped_slots - legacy_slots),
            "missing_markers": missing_markers,
            "strict_extra": bool(args.strict_extra),
            "testcase": str(testcase_path),
            "checklist": str(checklist_path),
        }
        exit_code = evaluate_exit_code(result, bool(args.strict_extra))
        result["ok"] = exit_code == 0
        result["exit_code"] = exit_code

        if args.json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print_human_result(result, bool(args.strict_extra))
            if exit_code == 0:
                print("[WIRING-SYNC] OK")

        if args.summary_line:
            print(render_summary_line(result, bool(args.strict_extra)))

        return exit_code
    except RuntimeError as exc:
        error_result = {
            "ok": False,
            "error": "runtime-error",
            "message": str(exc),
        }
        if args.json:
            print(json.dumps(error_result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[WIRING-SYNC] ERROR: {exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
