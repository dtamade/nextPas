#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


REGISTER_PATTERN = re.compile(r"\bRegisterTest\(\s*(TTestCase_[A-Za-z0-9_]+)\s*\)\s*;")
HANDLE_PATTERN = re.compile(
    r"HandleSuite\(\s*'(?P<label>TTestCase_[A-Za-z0-9_]+)'\s*,\s*(?P<symbol>TTestCase_[A-Za-z0-9_]+)(?:\.Suite\b)?"
)
UNIT_PATTERN = re.compile(r"^\s*unit\s+([A-Za-z0-9_.]+)\s*;", re.IGNORECASE | re.MULTILINE)
USES_TESTCASE_UNIT_PATTERN = re.compile(r"\bfafafa\.core\.simd(?:\.[A-Za-z0-9_]+)*\.testcase\b", re.IGNORECASE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check that the SIMD main runner suite manifest stays in sync with testcase RegisterTest declarations."
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a single-line summary for log scraping.",
    )
    return parser.parse_args()


def extract_unit_name(a_text: str, a_path: Path) -> str:
    match = UNIT_PATTERN.search(a_text)
    if match is None:
        raise ValueError(f"Failed to find unit declaration in {a_path}")
    return match.group(1)


def main() -> int:
    args = parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    tests_root = repo_root / "tests" / "nextpas.core.simd"
    runner_path = tests_root / "nextpas.core.simd.test.lpr"
    testcase_paths = sorted(tests_root.glob("nextpas.core.simd*.testcase.pas"))

    if not runner_path.exists():
        print(f"[SUITE-MANIFEST] Missing runner: {runner_path}")
        return 2
    if not testcase_paths:
        print(f"[SUITE-MANIFEST] No testcase files found under {tests_root}")
        return 2

    suite_to_units: dict[str, list[str]] = {}
    testcase_units_with_registers: set[str] = set()

    for testcase_path in testcase_paths:
        testcase_text = testcase_path.read_text(encoding="utf-8", errors="replace")
        unit_name = extract_unit_name(testcase_text, testcase_path)
        registered_suites = sorted(set(REGISTER_PATTERN.findall(testcase_text)))
        if not registered_suites:
            continue
        testcase_units_with_registers.add(unit_name)
        for suite_name in registered_suites:
            suite_to_units.setdefault(suite_name, []).append(unit_name)

    runner_text = runner_path.read_text(encoding="utf-8", errors="replace")
    used_testcase_units = set(USES_TESTCASE_UNIT_PATTERN.findall(runner_text))

    handle_pairs = HANDLE_PATTERN.findall(runner_text)
    handled_suites = sorted({label for label, _symbol in handle_pairs})
    registered_suites = sorted(suite_to_units)

    label_mismatches = sorted(
        f"{label}!={symbol}" for label, symbol in handle_pairs if label != symbol
    )
    missing_in_runner = sorted(set(registered_suites) - set(handled_suites))
    extra_in_runner = sorted(set(handled_suites) - set(registered_suites))
    missing_units = sorted(testcase_units_with_registers - used_testcase_units)

    print("[SUITE-MANIFEST] simd runner suite manifest sync")
    print(f"  - testcase_files:      {len(testcase_paths)}")
    print(f"  - used_test_units:     {len(used_testcase_units)}")
    print(f"  - registered_suites:   {len(registered_suites)}")
    print(f"  - handled_suites:      {len(handled_suites)}")
    print(f"  - missing_in_runner:   {len(missing_in_runner)}")
    print(f"  - extra_in_runner:     {len(extra_in_runner)}")
    print(f"  - missing_units:       {len(missing_units)}")
    print(f"  - label_mismatches:    {len(label_mismatches)}")

    if args.summary_line:
        print(
            "SUITE_MANIFEST_SUMMARY "
            f"testcase_files={len(testcase_paths)} "
            f"used_test_units={len(used_testcase_units)} "
            f"registered_suites={len(registered_suites)} "
            f"handled_suites={len(handled_suites)} "
            f"missing_in_runner={len(missing_in_runner)} "
            f"extra_in_runner={len(extra_in_runner)} "
            f"missing_units={len(missing_units)} "
            f"label_mismatches={len(label_mismatches)}"
        )

    failed = False

    for suite_name in missing_in_runner:
        owning_units = ", ".join(sorted(suite_to_units.get(suite_name, []))) or "unknown-unit"
        print(f"[SUITE-MANIFEST] FAILED: runner missing suite {suite_name} (registered in {owning_units})")
        failed = True

    for suite_name in extra_in_runner:
        print(f"[SUITE-MANIFEST] FAILED: runner lists suite {suite_name} but no RegisterTest was found")
        failed = True

    for unit_name in missing_units:
        print(f"[SUITE-MANIFEST] FAILED: runner uses list is missing testcase unit {unit_name}")
        failed = True

    for mismatch in label_mismatches:
        print(f"[SUITE-MANIFEST] FAILED: HandleSuite label/symbol mismatch {mismatch}")
        failed = True

    if failed:
        print("[SUITE-MANIFEST] Hint: keep RegisterTest(...), runner uses, and ProcessAllSuites HandleSuite(...) in sync.")
        return 1

    print("[SUITE-MANIFEST] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
