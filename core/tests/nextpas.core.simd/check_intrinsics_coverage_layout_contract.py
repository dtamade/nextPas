#!/usr/bin/env python3
"""Guard that SIMD intrinsics coverage carriers point at live repo paths."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterable

import check_intrinsics_coverage


ROOT = Path(__file__).resolve().parents[2]


def iter_test_paths(a_config: Any) -> Iterable[Path]:
    l_tests = getattr(a_config, "tests", None)
    if l_tests is not None:
        yield from l_tests
        return
    yield a_config.test


def build_result() -> dict[str, Any]:
    l_args = argparse.Namespace(
        require_avx2=False,
        require_experimental=False,
        sse2_min_refs=2,
    )
    l_configs = check_intrinsics_coverage.build_module_configs(
        a_repo_root=ROOT,
        a_args=l_args,
    )

    l_checks = 0
    l_issues: list[dict[str, str]] = []

    for l_config in l_configs:
        l_checks += 1
        if not l_config.src.is_file():
            l_issues.append(
                {
                    "module": l_config.name,
                    "kind": "src",
                    "path": str(l_config.src.relative_to(ROOT)).replace("\\", "/"),
                    "message": "coverage source carrier is missing",
                }
            )
        for l_test_path in iter_test_paths(l_config):
            l_checks += 1
            if not l_test_path.is_file():
                l_issues.append(
                    {
                        "module": l_config.name,
                        "kind": "test",
                        "path": str(l_test_path.relative_to(ROOT)).replace("\\", "/"),
                        "message": "coverage test carrier is missing",
                    }
                )

    return {
        "ok": len(l_issues) == 0,
        "checks": l_checks,
        "issues": len(l_issues),
        "issue_entries": l_issues,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "INTRINSICS_COVERAGE_LAYOUT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[INTRINSICS-COVERAGE-LAYOUT] Current intrinsics coverage carrier truth")
    print(f"  - checks: {a_result['checks']}")
    print(f"  - issues: {a_result['issues']}")
    if a_result["issue_entries"]:
        print("[INTRINSICS-COVERAGE-LAYOUT] Issues:")
        for l_issue in a_result["issue_entries"]:
            print(
                f"  - {l_issue['module']} {l_issue['kind']}: "
                f"{l_issue['path']} ({l_issue['message']})"
            )
    else:
        print("[INTRINSICS-COVERAGE-LAYOUT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check that SIMD intrinsics coverage carriers exist in the current tree."
    )
    l_parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    return l_parser.parse_args()


def main() -> int:
    l_args = parse_args()
    l_result = build_result()

    if l_args.json:
        print(json.dumps(l_result, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_human_result(l_result)

    if l_args.summary_line:
        print(render_summary_line(l_result))

    return 0 if l_result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
