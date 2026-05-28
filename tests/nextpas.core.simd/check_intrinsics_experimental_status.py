#!/usr/bin/env python3
"""Check that experimental SIMD intrinsics stay isolated from default entry points."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


EXPERIMENTAL_UNITS = [
    "nextpas.core.simd.intrinsics.aes",
    "nextpas.core.simd.intrinsics.sha",
    "nextpas.core.simd.intrinsics.avx",
    "nextpas.core.simd.intrinsics.sse3",
    "nextpas.core.simd.intrinsics.sse41",
    "nextpas.core.simd.intrinsics.sse42",
    "nextpas.core.simd.intrinsics.avx512",
    "nextpas.core.simd.intrinsics.fma3",
    "nextpas.core.simd.intrinsics.neon",
    "nextpas.core.simd.intrinsics.rvv",
    "nextpas.core.simd.intrinsics.sve",
    "nextpas.core.simd.intrinsics.sve2",
    "nextpas.core.simd.intrinsics.lasx",
]

DEFAULT_ENTRY_FILES = [
    "src/nextpas.core.simd.pas",
    "src/nextpas.core.simd.intrinsics.pas",
    "tests/nextpas.core.simd/nextpas.core.simd.test.lpr",
    "tests/nextpas.core.simd/BuildOrTest.sh",
    "tests/nextpas.core.simd/buildOrTest.bat",
    "tests/nextpas.core.simd/collect_linux_simd_evidence.sh",
]

# Placeholder-heavy units that must keep an explicit runtime guard.
# Enforce guard-token presence on every unit listed in EXPERIMENTAL_UNITS so
# experimental behavior cannot silently drift into default-callable semantics.
GUARDED_EXPERIMENTAL_FILES = [f"src/{l_unit}.pas" for l_unit in EXPERIMENTAL_UNITS]
REQUIRED_GUARD_TOKEN = "fafafa_simd_experimental_intrinsics"
X86_ONLY_RUNTIME_FAIL_CLOSE_FILES = [
    "src/nextpas.core.simd.intrinsics.avx.pas",
    "src/nextpas.core.simd.intrinsics.sse3.pas",
    "src/nextpas.core.simd.intrinsics.sse41.pas",
    "src/nextpas.core.simd.intrinsics.sse42.pas",
    "src/nextpas.core.simd.intrinsics.avx512.pas",
    "src/nextpas.core.simd.intrinsics.fma3.pas",
]
REQUIRED_X86_ONLY_RUNTIME_FAIL_CLOSE_TOKEN = "only qualified on x86/x86_64"
DEFAULT_OPT_IN_ACROSS_HOSTS_TOKENS = {
    "src/nextpas.core.simd.intrinsics.aes.pas": "remain opt-in across hosts",
    "src/nextpas.core.simd.intrinsics.sha.pas": "remain opt-in across hosts",
}
HOLD_RUNTIME_FAIL_CLOSE_TOKENS = {
    "src/nextpas.core.simd.intrinsics.sve.pas": "only qualified on aarch64 targets whose cpuinfo reports sve",
    "src/nextpas.core.simd.intrinsics.sve2.pas": "only qualified on aarch64 targets whose cpuinfo reports sve2",
    "src/nextpas.core.simd.intrinsics.lasx.pas": "only qualified on loongarch64 targets whose cpuinfo reports lasx",
}
QUALIFICATION_RUNTIME_FAIL_CLOSE_TOKENS = {
    "src/nextpas.core.simd.intrinsics.neon.pas": "only qualified on arm-class targets whose cpuinfo reports neon",
    "src/nextpas.core.simd.intrinsics.rvv.pas": "only qualified on risc-v targets whose cpuinfo reports rvv",
}
FORBIDDEN_DEFAULT_DEFINE_PATTERNS = [
    r"(?i)-dFAFAFA_SIMD_EXPERIMENTAL_INTRINSICS\b",
    r"(?i)\{\$DEFINE\s+FAFAFA_SIMD_EXPERIMENTAL_INTRINSICS\}",
]


def _scan_leaks(a_repo_root: Path, a_entry_files: list[str], a_units: list[str]) -> dict[str, list[str]]:
    l_leaks: dict[str, list[str]] = {}
    for l_rel in a_entry_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        l_hit_units: list[str] = []
        for l_unit in a_units:
            # Token-aware match: avoid false positives like intrinsics.avx vs intrinsics.avx2.
            l_pattern = r"(?<![a-z0-9_])" + re.escape(l_unit) + r"(?![a-z0-9_])"
            if re.search(l_pattern, l_text):
                l_hit_units.append(l_unit)
        if l_hit_units:
            l_leaks[l_rel] = sorted(l_hit_units)
    return l_leaks


def _scan_guard_markers(a_repo_root: Path, a_files: list[str], a_token: str) -> list[str]:
    l_missing: list[str] = []
    for l_rel in a_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        if a_token not in l_text:
            l_missing.append(l_rel)
    return sorted(l_missing)


def _scan_forbidden_default_defines(a_repo_root: Path, a_files: list[str], a_patterns: list[str]) -> list[str]:
    l_hits: list[str] = []
    for l_rel in a_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore")
        for l_pattern in a_patterns:
            if re.search(l_pattern, l_text):
                l_hits.append(l_rel)
                break
    return sorted(l_hits)


def _scan_x86_only_runtime_fail_close_markers(a_repo_root: Path, a_files: list[str], a_token: str) -> list[str]:
    l_missing: list[str] = []
    for l_rel in a_files:
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        if a_token not in l_text:
            l_missing.append(l_rel)
    return sorted(l_missing)


def _scan_required_runtime_fail_close_tokens(a_repo_root: Path, a_file_tokens: dict[str, str]) -> list[str]:
    l_missing: list[str] = []
    for l_rel, l_token in a_file_tokens.items():
        l_path = a_repo_root / l_rel
        if not l_path.is_file():
            l_missing.append(l_rel)
            continue
        l_text = l_path.read_text(encoding="utf-8", errors="ignore").lower()
        if l_token not in l_text:
            l_missing.append(l_rel)
    return sorted(l_missing)


def _render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "INTRINSICS_EXPERIMENTAL_SUMMARY "
        f"experimental_units={a_result['experimental_units']} "
        f"entry_files={a_result['entry_files']} "
        f"leaked_files={a_result['leaked_files']} "
        f"leaked_units={a_result['leaked_units']} "
        f"missing_guard_markers={a_result['missing_guard_markers']} "
        f"default_define_leaks={a_result['default_define_leaks']} "
        f"missing_x86_runtime_fail_close={a_result['missing_x86_runtime_fail_close']} "
        f"missing_cross_host_opt_in={a_result['missing_cross_host_opt_in']} "
        f"missing_hold_runtime_fail_close={a_result['missing_hold_runtime_fail_close']} "
        f"missing_qualification_runtime_fail_close={a_result['missing_qualification_runtime_fail_close']}"
    )


def _print_human_result(a_result: dict[str, Any]) -> None:
    print("[EXPERIMENTAL] SIMD intrinsics entry isolation")
    print(f"  - tracked experimental units: {a_result['experimental_units']}")
    print(f"  - checked entry files:        {a_result['entry_files']}")
    print(f"  - leaked files:               {a_result['leaked_files']}")
    print(f"  - leaked units:               {a_result['leaked_units']}")
    print(f"  - missing guard markers:      {a_result['missing_guard_markers']}")
    print(f"  - default-define leaks:       {a_result['default_define_leaks']}")
    print(f"  - missing x86 fail-close:     {a_result['missing_x86_runtime_fail_close']}")
    print(f"  - missing cross-host opt-in:  {a_result['missing_cross_host_opt_in']}")
    print(f"  - missing hold fail-close:    {a_result['missing_hold_runtime_fail_close']}")
    print(f"  - missing qualification fail-close: {a_result['missing_qualification_runtime_fail_close']}")

    if a_result["leaks"]:
        print("[EXPERIMENTAL] Leaks found:")
        for l_file, l_units in a_result["leaks"].items():
            print(f"  - {l_file}")
            for l_unit in l_units:
                print(f"    * {l_unit}")
    if a_result["missing_guard_files"]:
        print("[EXPERIMENTAL] Missing required guard marker in:")
        for l_file in a_result["missing_guard_files"]:
            print(f"  - {l_file}")

    if a_result["default_define_files"]:
        print("[EXPERIMENTAL] Forbidden default entry define found in:")
        for l_file in a_result["default_define_files"]:
            print(f"  - {l_file}")

    if a_result["missing_x86_runtime_fail_close_files"]:
        print("[EXPERIMENTAL] Missing x86-only runtime fail-close marker in:")
        for l_file in a_result["missing_x86_runtime_fail_close_files"]:
            print(f"  - {l_file}")

    if a_result["missing_cross_host_opt_in_files"]:
        print("[EXPERIMENTAL] Missing cross-host opt-in contract marker in:")
        for l_file in a_result["missing_cross_host_opt_in_files"]:
            print(f"  - {l_file}")

    if a_result["missing_hold_runtime_fail_close_files"]:
        print("[EXPERIMENTAL] Missing hold-family runtime fail-close marker in:")
        for l_file in a_result["missing_hold_runtime_fail_close_files"]:
            print(f"  - {l_file}")

    if a_result["missing_qualification_runtime_fail_close_files"]:
        print("[EXPERIMENTAL] Missing qualification-family runtime fail-close marker in:")
        for l_file in a_result["missing_qualification_runtime_fail_close_files"]:
            print(f"  - {l_file}")

    if (
        (not a_result["leaks"])
        and (not a_result["missing_guard_files"])
        and (not a_result["default_define_files"])
        and (not a_result["missing_x86_runtime_fail_close_files"])
        and (not a_result["missing_cross_host_opt_in_files"])
        and (not a_result["missing_hold_runtime_fail_close_files"])
        and (not a_result["missing_qualification_runtime_fail_close_files"])
    ):
        print("[EXPERIMENTAL] OK (no experimental units in default entry chain)")


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check experimental intrinsics isolation")
    l_parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary")
    l_parser.add_argument(
        "--entry-file",
        action="append",
        dest="entry_files",
        default=None,
        help="override/add entry file to scan (repo-relative)",
    )
    l_args = l_parser.parse_args()

    l_repo_root = Path(__file__).resolve().parents[2]
    l_entry_files = l_args.entry_files if l_args.entry_files else list(DEFAULT_ENTRY_FILES)
    l_leaks = _scan_leaks(a_repo_root=l_repo_root, a_entry_files=l_entry_files, a_units=EXPERIMENTAL_UNITS)
    l_leaked_units = sorted({l_unit for l_units in l_leaks.values() for l_unit in l_units})
    l_missing_guard_files = _scan_guard_markers(
        a_repo_root=l_repo_root,
        a_files=GUARDED_EXPERIMENTAL_FILES,
        a_token=REQUIRED_GUARD_TOKEN,
    )
    l_default_define_files = _scan_forbidden_default_defines(
        a_repo_root=l_repo_root,
        a_files=l_entry_files,
        a_patterns=FORBIDDEN_DEFAULT_DEFINE_PATTERNS,
    )
    l_missing_x86_runtime_fail_close_files = _scan_x86_only_runtime_fail_close_markers(
        a_repo_root=l_repo_root,
        a_files=X86_ONLY_RUNTIME_FAIL_CLOSE_FILES,
        a_token=REQUIRED_X86_ONLY_RUNTIME_FAIL_CLOSE_TOKEN,
    )
    l_missing_cross_host_opt_in_files = _scan_required_runtime_fail_close_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=DEFAULT_OPT_IN_ACROSS_HOSTS_TOKENS,
    )
    l_missing_hold_runtime_fail_close_files = _scan_required_runtime_fail_close_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=HOLD_RUNTIME_FAIL_CLOSE_TOKENS,
    )
    l_missing_qualification_runtime_fail_close_files = _scan_required_runtime_fail_close_tokens(
        a_repo_root=l_repo_root,
        a_file_tokens=QUALIFICATION_RUNTIME_FAIL_CLOSE_TOKENS,
    )

    l_result: dict[str, Any] = {
        "ok": (
            (len(l_leaks) == 0)
            and (len(l_missing_guard_files) == 0)
            and (len(l_default_define_files) == 0)
            and (len(l_missing_x86_runtime_fail_close_files) == 0)
            and (len(l_missing_cross_host_opt_in_files) == 0)
            and (len(l_missing_hold_runtime_fail_close_files) == 0)
            and (len(l_missing_qualification_runtime_fail_close_files) == 0)
        ),
        "experimental_units": len(EXPERIMENTAL_UNITS),
        "entry_files": len(l_entry_files),
        "leaked_files": len(l_leaks),
        "leaked_units": len(l_leaked_units),
        "missing_guard_markers": len(l_missing_guard_files),
        "default_define_leaks": len(l_default_define_files),
        "missing_x86_runtime_fail_close": len(l_missing_x86_runtime_fail_close_files),
        "missing_cross_host_opt_in": len(l_missing_cross_host_opt_in_files),
        "missing_hold_runtime_fail_close": len(l_missing_hold_runtime_fail_close_files),
        "missing_qualification_runtime_fail_close": len(l_missing_qualification_runtime_fail_close_files),
        "entry_file_list": l_entry_files,
        "leaks": l_leaks,
        "leaked_unit_list": l_leaked_units,
        "missing_guard_files": l_missing_guard_files,
        "default_define_files": l_default_define_files,
        "missing_x86_runtime_fail_close_files": l_missing_x86_runtime_fail_close_files,
        "missing_cross_host_opt_in_files": l_missing_cross_host_opt_in_files,
        "missing_hold_runtime_fail_close_files": l_missing_hold_runtime_fail_close_files,
        "missing_qualification_runtime_fail_close_files": l_missing_qualification_runtime_fail_close_files,
    }

    if l_args.json:
        print(json.dumps(l_result, ensure_ascii=False, sort_keys=True, indent=2))
    else:
        _print_human_result(l_result)

    if l_args.summary_line:
        print(_render_summary_line(l_result))

    return 0 if l_result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
