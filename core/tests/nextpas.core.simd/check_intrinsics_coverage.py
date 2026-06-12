#!/usr/bin/env python3
"""SIMD intrinsics direct-test coverage checker."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


DECL_RE = re.compile(
    r"^\s*(?:function|procedure)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b",
    re.IGNORECASE | re.MULTILINE,
)
IMPLEMENTATION_RE = re.compile(r"^\s*implementation\b", re.IGNORECASE | re.MULTILINE)
TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@dataclass(frozen=True)
class ModuleConfig:
    name: str
    prefix: str
    test_mode: str
    required: bool
    src: Path
    tests: tuple[Path, ...]
    min_refs: int = 0
    min_ref_overrides: dict[str, int] | None = None


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description=(
            "Check SIMD intrinsics direct-test coverage for stable intrinsics suites "
            "and the SSE2 active raw-leaf surface."
        )
    )
    l_parser.add_argument("--json", action="store_true", dest="as_json", help="print JSON output")
    l_parser.add_argument("--json-file", default="", help="write JSON payload to file")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary for log scraping")
    l_parser.add_argument(
        "--strict-extra",
        action="store_true",
        dest="strict_extra",
        help="treat extra test mappings as failure",
    )
    l_parser.add_argument(
        "--require-avx2",
        action="store_true",
        dest="require_avx2",
        help="treat AVX2 missing mappings as failure",
    )
    l_parser.add_argument(
        "--require-experimental",
        action="store_true",
        dest="require_experimental",
        help="treat experimental AES/SHA missing mappings as failure",
    )
    l_parser.add_argument(
        "--sse2-min-refs",
        type=int,
        default=2,
        help="minimum code-level references required for SSE2 simd_* routines (default: 2)",
    )
    return l_parser.parse_args()


def normalize_name(a_name: str) -> str:
    return a_name.lower()


def mask_pascal_gap_char(a_char: str) -> str:
    if a_char in {"\n", "\r"}:
        return a_char
    return " "


def strip_pascal_non_code(a_text: str) -> str:
    l_chars = list(a_text)
    l_len = len(l_chars)
    l_idx = 0

    while l_idx < l_len:
        l_char = l_chars[l_idx]
        l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""

        if l_char == "'":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                if l_char == "'":
                    if l_next == "'":
                        l_chars[l_idx + 1] = " "
                        l_idx += 2
                        continue
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "{" and l_next != "$":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                if l_char == "}":
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "(" and l_next == "*":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                if l_char == "*" and l_next == ")":
                    l_chars[l_idx] = " "
                    l_chars[l_idx + 1] = " "
                    l_idx += 2
                    break
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                l_idx += 1
            continue

        if l_char == "/" and l_next == "/":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                if l_char in {"\n", "\r"}:
                    l_idx += 1
                    break
                l_chars[l_idx] = " "
                l_idx += 1
            continue

        l_idx += 1

    return "".join(l_chars)


def strip_pascal_comments_only(a_text: str) -> str:
    l_chars = list(a_text)
    l_len = len(l_chars)
    l_idx = 0

    while l_idx < l_len:
        l_char = l_chars[l_idx]
        l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""

        if l_char == "'":
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                if l_char == "'":
                    if l_next == "'":
                        l_idx += 2
                        continue
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "{" and l_next != "$":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                if l_char == "}":
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "(" and l_next == "*":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                if l_char == "*" and l_next == ")":
                    l_chars[l_idx] = " "
                    l_chars[l_idx + 1] = " "
                    l_idx += 2
                    break
                l_chars[l_idx] = mask_pascal_gap_char(l_char)
                l_idx += 1
            continue

        if l_char == "/" and l_next == "/":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                if l_char in {"\n", "\r"}:
                    l_idx += 1
                    break
                l_chars[l_idx] = " "
                l_idx += 1
            continue

        l_idx += 1

    return "".join(l_chars)


def extract_interface_text(a_source_text: str) -> str:
    l_masked = strip_pascal_non_code(a_source_text)
    l_match = IMPLEMENTATION_RE.search(l_masked)
    if l_match is None:
        return a_source_text
    return a_source_text[: l_match.start()]


def extract_declared(a_source_text: str, a_prefix: str) -> dict[str, str]:
    l_interface_text = extract_interface_text(a_source_text)
    l_prefix_lower = normalize_name(a_prefix) + "_"
    l_declared: dict[str, str] = {}
    for l_match in DECL_RE.finditer(l_interface_text):
        l_name = l_match.group("name")
        l_normalized = normalize_name(l_name)
        if l_normalized.startswith(l_prefix_lower):
            l_declared.setdefault(l_normalized, l_name)
    return l_declared


def extract_suite_name_counts(a_test_text: str, a_prefix: str) -> Counter[str]:
    l_masked = strip_pascal_non_code(a_test_text)
    l_pattern = re.compile(
        rf"\bTest_({re.escape(a_prefix)}_[A-Za-z0-9_]+)\b",
        re.IGNORECASE,
    )
    l_counts: Counter[str] = Counter()
    for l_match in l_pattern.finditer(l_masked):
        l_counts[normalize_name(l_match.group(1))] += 1
    return l_counts


def extract_symbol_ref_counts(a_test_text: str, a_prefix: str, *, a_keep_strings: bool) -> Counter[str]:
    if a_keep_strings:
        l_masked = strip_pascal_comments_only(a_test_text)
    else:
        l_masked = strip_pascal_non_code(a_test_text)
    l_prefix_lower = normalize_name(a_prefix) + "_"
    l_counts: Counter[str] = Counter()
    for l_token in TOKEN_RE.findall(l_masked):
        l_normalized = normalize_name(l_token)
        if l_normalized.startswith(l_prefix_lower):
            l_counts[l_normalized] += 1
    return l_counts


def extract_test_counts(
    a_test_text: str,
    a_prefix: str,
    a_mode: str,
    *,
    a_keep_strings: bool,
) -> Counter[str]:
    if a_mode == "suite_name":
        return extract_suite_name_counts(a_test_text=a_test_text, a_prefix=a_prefix)
    if a_mode == "symbol_ref":
        return extract_symbol_ref_counts(
            a_test_text=a_test_text,
            a_prefix=a_prefix,
            a_keep_strings=a_keep_strings,
    )
    raise ValueError(f"unknown test extraction mode: {a_mode}")


def build_current_intrinsics_test_carriers(a_repo_root: Path) -> tuple[Path, ...]:
    l_tests_root = a_repo_root / "tests" / "nextpas.core.simd"
    return (
        l_tests_root / "nextpas.core.simd.intrinsics.avx2.testcase.pas",
        l_tests_root / "nextpas.core.simd.sse2contracts.testcase.pas",
        l_tests_root / "nextpas.core.simd.sse3_correctness.testcase.pas",
        # Symbol-ref coverage scans raw source text, so wrapper-based tests must
        # point at their canonical project file instead of the top-level include.
        l_tests_root / "test_mmx_raw_leaf_parity" / "test_mmx_raw_leaf_parity.lpr",
        l_tests_root / "test_sse_raw_leaf_parity" / "test_sse_raw_leaf_parity.lpr",
        l_tests_root / "test_sse2_raw_leaf_parity.pas",
    )


def build_experimental_intrinsics_test_carriers(a_repo_root: Path) -> tuple[Path, ...]:
    l_tests_root = a_repo_root / "tests" / "nextpas.core.simd.intrinsics.experimental"
    return (
        l_tests_root / "nextpas.core.simd.intrinsics.experimental.testcase.pas",
    )


def build_module_configs(a_repo_root: Path, a_args: argparse.Namespace) -> list[ModuleConfig]:
    l_tests_root = a_repo_root / "tests" / "nextpas.core.simd"
    l_current_intrinsics_tests = build_current_intrinsics_test_carriers(a_repo_root)
    l_experimental_intrinsics_tests = build_experimental_intrinsics_test_carriers(a_repo_root)
    return [
        ModuleConfig(
            name="sse",
            prefix="sse",
            test_mode="symbol_ref",
            required=True,
            src=a_repo_root / "src" / "nextpas.core.simd.intrinsics.sse.pas",
            tests=l_current_intrinsics_tests,
        ),
        ModuleConfig(
            name="mmx",
            prefix="mmx",
            test_mode="symbol_ref",
            required=True,
            src=a_repo_root / "src" / "nextpas.core.simd.intrinsics.mmx.pas",
            tests=l_current_intrinsics_tests,
        ),
        ModuleConfig(
            name="avx2",
            prefix="avx2",
            test_mode="symbol_ref",
            required=a_args.require_avx2,
            src=a_repo_root / "src" / "nextpas.core.simd.intrinsics.avx2.pas",
            tests=(l_tests_root / "nextpas.core.simd.intrinsics.avx2.testcase.pas",),
        ),
        ModuleConfig(
            name="aes",
            prefix="aes",
            test_mode="symbol_ref",
            required=a_args.require_experimental,
            src=a_repo_root / "src" / "nextpas.core.simd.intrinsics.aes.pas",
            tests=l_experimental_intrinsics_tests,
        ),
        ModuleConfig(
            name="sha",
            prefix="sha",
            test_mode="symbol_ref",
            required=a_args.require_experimental,
            src=a_repo_root / "src" / "nextpas.core.simd.intrinsics.sha.pas",
            tests=l_experimental_intrinsics_tests,
        ),
        ModuleConfig(
            name="sse2-x86-raw",
            prefix="simd",
            test_mode="symbol_ref",
            required=True,
            src=a_repo_root / "src" / "nextpas.core.simd.intrinsics.x86.sse2.pas",
            tests=(l_tests_root / "test_sse2_raw_leaf_parity.pas",),
            min_refs=a_args.sse2_min_refs,
        ),
    ]


def check_module(a_config: ModuleConfig) -> dict:
    l_src_text = a_config.src.read_text(encoding="utf-8", errors="ignore")
    l_declared = extract_declared(l_src_text, a_config.prefix)
    l_test_counts: Counter[str] = Counter()
    l_witness_counts: Counter[str] = Counter()
    for l_test_path in a_config.tests:
        l_test_text = l_test_path.read_text(encoding="utf-8", errors="ignore")
        l_test_counts.update(
            extract_test_counts(
                a_test_text=l_test_text,
                a_prefix=a_config.prefix,
                a_mode=a_config.test_mode,
                a_keep_strings=False,
            )
        )
        l_witness_counts.update(
            extract_test_counts(
                a_test_text=l_test_text,
                a_prefix=a_config.prefix,
                a_mode=a_config.test_mode,
                a_keep_strings=a_config.min_refs > 0,
            )
        )

    l_missing = sorted(
        l_declared[l_name]
        for l_name in l_declared
        if l_name not in l_test_counts
    )
    l_extra = sorted(
        l_name
        for l_name in l_test_counts
        if l_name not in l_declared
    )

    l_thin_items: list[dict[str, int | str]] = []
    l_min_ref_overrides = a_config.min_ref_overrides or {}
    if a_config.min_refs > 0:
        for l_name, l_canonical in sorted(l_declared.items(), key=lambda a_item: a_item[1].lower()):
            if l_name not in l_test_counts:
                continue
            l_required_refs = l_min_ref_overrides.get(l_name, a_config.min_refs)
            l_actual_refs = l_witness_counts[l_name]
            if l_actual_refs < l_required_refs:
                l_thin_items.append(
                    {
                        "name": l_canonical,
                        "ref_count": l_actual_refs,
                        "required_refs": l_required_refs,
                    }
                )

    l_recognized_tested = sum(1 for l_name in l_test_counts if l_name in l_declared)
    return {
        "module": a_config.name,
        "prefix": a_config.prefix,
        "test_mode": a_config.test_mode,
        "required": a_config.required,
        "test_files": [
            str(l_path.relative_to(a_config.src.parents[2])).replace("\\", "/")
            for l_path in a_config.tests
        ],
        "declared_count": len(l_declared),
        "tested_count": l_recognized_tested,
        "missing_count": len(l_missing),
        "missing": l_missing,
        "extra_count": len(l_extra),
        "extra": l_extra,
        "min_refs": a_config.min_refs,
        "thin_count": len(l_thin_items),
        "thin": l_thin_items,
        "min_ref_overrides": {
            l_declared.get(l_name, l_name): l_required
            for l_name, l_required in sorted(l_min_ref_overrides.items())
        },
    }


def main() -> int:
    l_args = parse_args()
    if l_args.sse2_min_refs < 1:
        print("[COVERAGE] FAILED (--sse2-min-refs must be >= 1)")
        return 2

    l_repo_root = Path(__file__).resolve().parents[2]
    l_modules = build_module_configs(a_repo_root=l_repo_root, a_args=l_args)

    for l_module in l_modules:
        if not l_module.src.is_file():
            print(f"[COVERAGE] ERROR: missing source file for {l_module.name}: {l_module.src}")
            return 2
        for l_test_path in l_module.tests:
            if not l_test_path.is_file():
                print(
                    f"[COVERAGE] ERROR: missing test carrier for {l_module.name}: {l_test_path}"
                )
                return 2

    l_results = [check_module(a_config=l_module) for l_module in l_modules]

    l_total_missing = sum(l_item["missing_count"] for l_item in l_results)
    l_total_missing_required = sum(
        l_item["missing_count"] for l_item in l_results if l_item["required"]
    )
    l_total_missing_optional = l_total_missing - l_total_missing_required
    l_total_thin = sum(l_item["thin_count"] for l_item in l_results)
    l_total_thin_required = sum(
        l_item["thin_count"] for l_item in l_results if l_item["required"]
    )
    l_total_thin_optional = l_total_thin - l_total_thin_required
    l_total_extra = sum(l_item["extra_count"] for l_item in l_results)
    l_ok = (
        l_total_missing_required == 0
        and l_total_thin_required == 0
        and (not l_args.strict_extra or l_total_extra == 0)
    )
    l_payload = {
        "results": l_results,
        "total_missing": l_total_missing,
        "total_missing_required": l_total_missing_required,
        "total_missing_optional": l_total_missing_optional,
        "total_thin": l_total_thin,
        "total_thin_required": l_total_thin_required,
        "total_thin_optional": l_total_thin_optional,
        "total_extra": l_total_extra,
        "strict_extra": l_args.strict_extra,
        "require_avx2": l_args.require_avx2,
        "require_experimental": l_args.require_experimental,
        "sse2_min_refs": l_args.sse2_min_refs,
        "status": "ok" if l_ok else "fail",
    }

    if l_args.json_file:
        Path(l_args.json_file).write_text(
            json.dumps(l_payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    if l_args.as_json:
        print(json.dumps(l_payload, ensure_ascii=False, indent=2))
    else:
        print("[COVERAGE] SIMD intrinsics direct-test mapping")
        for l_item in l_results:
            l_scope = "required" if l_item["required"] else "optional"
            l_extra_text = (
                f" thin={l_item['thin_count']} min_refs={l_item['min_refs']}"
                if l_item["min_refs"] > 0
                else ""
            )
            print(
                f"  - {l_item['module']}: declared={l_item['declared_count']} "
                f"tested={l_item['tested_count']} missing={l_item['missing_count']} "
                f"extra={l_item['extra_count']} mode={l_item['test_mode']} "
                f"scope={l_scope}{l_extra_text}"
            )
            for l_test_file in l_item["test_files"]:
                print(f"      carrier: {l_test_file}")
            for l_name in l_item["missing"]:
                print(f"      missing: {l_name}")
            for l_name in l_item["extra"]:
                print(f"      extra: {l_name}")
            for l_thin in l_item["thin"]:
                print(
                    "      thin: "
                    f"{l_thin['name']} refs={l_thin['ref_count']} required_refs={l_thin['required_refs']}"
                )

        if l_ok:
            print("[COVERAGE] OK (no missing direct-test mappings)")
            if l_total_missing_optional > 0 or l_total_thin_optional > 0:
                print(
                    "[COVERAGE] WARN "
                    f"(optional gaps: missing={l_total_missing_optional} thin={l_total_thin_optional})"
                )
        elif l_total_missing_required > 0:
            print(f"[COVERAGE] FAILED (missing mappings in required modules: {l_total_missing_required})")
        elif l_total_thin_required > 0:
            print(f"[COVERAGE] FAILED (thin coverage in required modules: {l_total_thin_required})")
        else:
            print(f"[COVERAGE] FAILED (strict-extra enabled, extra mappings: {l_total_extra})")

    if l_args.summary_line:
        print(
            "INTRINSICS_COVERAGE_SUMMARY "
            f"modules={len(l_results)} "
            f"missing_required={l_total_missing_required} "
            f"missing_optional={l_total_missing_optional} "
            f"thin_required={l_total_thin_required} "
            f"thin_optional={l_total_thin_optional} "
            f"extra={l_total_extra} "
            f"strict_extra={int(l_args.strict_extra)} "
            f"require_avx2={int(l_args.require_avx2)} "
            f"require_experimental={int(l_args.require_experimental)} "
            f"sse2_min_refs={l_args.sse2_min_refs} "
            f"status={'ok' if l_ok else 'fail'}"
        )

    if l_total_missing_required > 0:
        return 1
    if l_total_thin_required > 0:
        return 1
    if l_args.strict_extra and l_total_extra > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
