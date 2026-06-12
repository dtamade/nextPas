#!/usr/bin/env python3
"""Guard the minimal shell runner surface that SIMD docs/scripts rely on."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SHELL_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "BuildOrTest.sh"
DOCKER_RUNNER = ROOT / "tests" / "nextpas.core.simd" / "docker" / "run_fpc_tests.sh"
MAIN_MAKEFILE = ROOT / "tests" / "nextpas.core.simd" / "Makefile"
EXPERIMENTAL_MAKEFILE = ROOT / "tests" / "nextpas.core.simd.intrinsics.experimental" / "Makefile"


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
    if not re.search(a_pattern, a_text, re.MULTILINE):
        add_issue(a_issues, a_path, a_message)
    return 1


def require_absent_pattern(
    a_text: str,
    a_path: Path,
    a_pattern: str,
    a_message: str,
    a_issues: list[dict[str, str]],
) -> int:
    if re.search(a_pattern, a_text, re.MULTILINE):
        add_issue(a_issues, a_path, a_message)
    return 1


def build_result() -> dict[str, Any]:
    l_issues: list[dict[str, str]] = []
    l_checks = 0

    for l_path in (SHELL_RUNNER, DOCKER_RUNNER, MAIN_MAKEFILE, EXPERIMENTAL_MAKEFILE):
        if not l_path.is_file():
            add_issue(l_issues, l_path, "missing shell runner contract file")

    if l_issues:
        return {
            "ok": False,
            "checks": l_checks,
            "issues": len(l_issues),
            "issue_entries": l_issues,
        }

    l_shell_runner = read_text(SHELL_RUNNER)
    l_docker_runner = read_text(DOCKER_RUNNER)
    l_main_makefile = read_text(MAIN_MAKEFILE)
    l_experimental_makefile = read_text(EXPERIMENTAL_MAKEFILE)

    for l_pattern, l_message in (
        (r'case "\$\{ACTION\}" in', "shell runner missing action dispatcher"),
        (r'clean\)', "shell runner missing clean action"),
        (r'check\)', "shell runner missing check action"),
        (r'test\)', "shell runner missing test action"),
        (r'contract-signature\)', "shell runner missing dispatch signature action"),
        (r'publicabi-signature\)', "shell runner missing public ABI signature action"),
        (r'experimental-intrinsics-tests\)', "shell runner missing experimental intrinsics test action"),
        (r'experimental-intrinsics-closure\)', "shell runner missing experimental intrinsics closure action"),
        (r'SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1', "shell runner closure missing experimental coverage requirement"),
        (r'SIMD_COVERAGE_STRICT_EXTRA=1', "shell runner closure missing strict-extra coverage requirement"),
        (r'SIMD_COVERAGE_REQUIRE_AVX2=1', "shell runner closure missing AVX2 coverage requirement"),
        (r'nonx86-optin-list-suites\)', "shell runner missing non-x86 opt-in list action"),
        (r'NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND', "shell runner missing NEON test-registration opt-in define"),
        (r'NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND', "shell runner missing RISCVV test-registration opt-in define"),
        (r'SIMD_FPC_EXTRA_DEFINES', "shell runner missing direct-fpc extra-define pass-through"),
        (r'--list-suites', "shell runner missing suite-list passthrough"),
        (r'--suite=', "shell runner missing suite-filter passthrough"),
        (r'check_dispatch_contract_signature\.py', "shell runner missing dispatch signature checker invocation"),
        (r'check_public_abi_signature\.py', "shell runner missing public ABI signature checker invocation"),
        (r'nextpas\.core\.simd\.intrinsics\.experimental/BuildOrTest\.sh', "shell runner missing experimental intrinsics runner delegation"),
        (r'"\$\{PYTHON_BIN\}" -B "\$\{a_script\}" "\$@"', "shell runner python checker path missing -B no-bytecode guard"),
        (r'"\$\{PYTHON_BIN\}" -B "\$\{l_export_script\}"', "shell runner gate-summary export path missing -B no-bytecode guard"),
        (r'"\$\{PYTHON_BIN\}" -B "\$\{l_sample_script\}"', "shell runner gate-summary sample path missing -B no-bytecode guard"),
        (r'"\$\{PYTHON_BIN\}" -B "\$\{l_eval_script\}"', "shell runner freeze-status path missing -B no-bytecode guard"),
        (r'Unsupported action', "shell runner missing fail-close unsupported-action path"),
    ):
        l_checks += require_pattern(
            l_shell_runner,
            SHELL_RUNNER,
            l_pattern,
            l_message,
            l_issues,
        )

    for l_pattern, l_message in (
        (r'^\.DEFAULT_GOAL\s*:=\s*test\s*$', "main Makefile default goal must remain test"),
        (r'^check:\s*$', "main Makefile missing check target"),
        (r'^coverage:\s*$', "main Makefile missing coverage target"),
        (r'^experimental-intrinsics-tests:\s*$', "main Makefile missing experimental intrinsics tests alias"),
        (r'^experimental-intrinsics-focused:\s*$', "main Makefile missing experimental intrinsics focused target"),
        (r'^experimental-intrinsics-closure:\s*$', "main Makefile missing experimental intrinsics closure target"),
        (r'BuildOrTest\.sh check', "main Makefile check target missing shell runner delegation"),
        (r'BuildOrTest\.sh coverage', "main Makefile coverage target missing shell runner delegation"),
        (r'BuildOrTest\.sh experimental-intrinsics-tests', "main Makefile experimental tests target missing shell runner delegation"),
        (r'BuildOrTest\.sh experimental-intrinsics-closure', "main Makefile experimental closure target missing shell runner delegation"),
        (r'^test-all:\s*test test-vec audit cpuinfo-focused\s*$', "main Makefile test-all should remain stable/default and exclude experimental closure"),
    ):
        l_checks += require_pattern(
            l_main_makefile,
            MAIN_MAKEFILE,
            l_pattern,
            l_message,
            l_issues,
        )

    l_checks += require_absent_pattern(
        l_main_makefile,
        MAIN_MAKEFILE,
        r'^test-all:.*experimental-intrinsics',
        "main Makefile test-all must not promote experimental intrinsics into the default stable gate",
        l_issues,
    )

    for l_pattern, l_message in (
        (r'^check:\s*$', "experimental Makefile missing check target"),
        (r'^test-all:\s*$', "experimental Makefile missing test-all target"),
        (r'BuildOrTest\.sh check', "experimental Makefile check target missing runner delegation"),
        (r'BuildOrTest\.sh test-all', "experimental Makefile test-all target missing runner delegation"),
    ):
        l_checks += require_pattern(
            l_experimental_makefile,
            EXPERIMENTAL_MAKEFILE,
            l_pattern,
            l_message,
            l_issues,
        )

    for l_pattern, l_message in (
        (r'BuildOrTest\.sh', "docker runner missing top-level shell-runner delegation"),
        (r'SIMD_FPC_EXTRA_DEFINES', "docker runner missing direct-fpc define pass-through"),
        (r'SIMD_RUN_ONLY_BUILD', "docker runner missing compile-only pass-through"),
        (r'--vector-asm', "docker runner missing vector-asm passthrough"),
        (r'--list-suites', "docker runner missing suite-list passthrough"),
        (r'--suite=', "docker runner missing suite-filter passthrough"),
        (r'clean\)', "docker runner missing clean passthrough"),
        (r'test\)', "docker runner missing explicit test passthrough"),
    ):
        l_checks += require_pattern(
            l_docker_runner,
            DOCKER_RUNNER,
            l_pattern,
            l_message,
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
        "SHELL_RUNNER_CONTRACT "
        f"checks={a_result['checks']} "
        f"issues={a_result['issues']} "
        f"status={'ok' if a_result['ok'] else 'fail'}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[SHELL-RUNNER-CONTRACT] SIMD shell runner minimum contract")
    print(f"  - checks:  {a_result['checks']}")
    print(f"  - issues:  {a_result['issues']}")

    if a_result["issue_entries"]:
        print("[SHELL-RUNNER-CONTRACT] Issues:")
        for l_entry in a_result["issue_entries"]:
            print(f"  - {l_entry['file']}: {l_entry['message']}")
    else:
        print("[SHELL-RUNNER-CONTRACT] OK")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check the minimal SIMD shell-runner source contracts."
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
