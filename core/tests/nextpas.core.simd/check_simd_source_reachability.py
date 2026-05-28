#!/usr/bin/env python3
"""Check that private SIMD include files stay reachable from live source roots."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / "src"
INCLUDE_RE = re.compile(r"\{\$I\s+([^}]+)\}", re.IGNORECASE)
SIMD_PAS_GLOB = "nextpas.core.simd*.pas"
SIMD_INC_GLOB = "nextpas.core.simd*.inc"
EXPERIMENTAL_UNIT_PREFIX = "nextpas.core.simd.intrinsics"

ALLOWED_UNREACHABLE_INCLUDES = {
    "nextpas.core.simd.neon.scalar.wide_memory.inc": (
        "audit-only checker fixture retained for non-x86 helper semantics"
    ),
}


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def collect_include_names(a_text: str) -> list[str]:
    return [l_match.group(1).strip().strip("'\"") for l_match in INCLUDE_RE.finditer(a_text)]


def build_result() -> dict[str, Any]:
    l_include_files = {l_path.name: l_path for l_path in sorted(SRC_DIR.glob(SIMD_INC_GLOB))}
    l_root_units = sorted(
        l_path
        for l_path in SRC_DIR.glob(SIMD_PAS_GLOB)
        if not l_path.stem.startswith(EXPERIMENTAL_UNIT_PREFIX)
    )
    l_reachable: set[str] = set()
    l_missing_refs: list[dict[str, str]] = []
    l_stack: list[tuple[str, str]] = []

    def queue_include(a_owner: str, a_include_name: str) -> None:
        if a_include_name in l_include_files:
            if a_include_name not in l_reachable:
                l_reachable.add(a_include_name)
                l_stack.append((a_include_name, a_owner))
            return
        if a_include_name.startswith("nextpas.core.simd"):
            l_missing_refs.append({"owner": a_owner, "include": a_include_name})

    for l_unit_path in l_root_units:
        for l_include_name in collect_include_names(read_text(l_unit_path)):
            queue_include(l_unit_path.name, l_include_name)

    while l_stack:
        l_include_name, _ = l_stack.pop()
        l_include_path = l_include_files[l_include_name]
        for l_child_name in collect_include_names(read_text(l_include_path)):
            queue_include(l_include_name, l_child_name)

    l_allowed_present = sorted(
        l_name for l_name in ALLOWED_UNREACHABLE_INCLUDES if l_name in l_include_files
    )
    l_unexpected_unreachable = sorted(
        l_name
        for l_name in l_include_files
        if l_name not in l_reachable and l_name not in ALLOWED_UNREACHABLE_INCLUDES
    )

    return {
        "ok": (len(l_unexpected_unreachable) == 0) and (len(l_missing_refs) == 0),
        "tracked_includes": len(l_include_files),
        "reachable_includes": len(l_reachable),
        "allowed_unreachable": len(l_allowed_present),
        "unexpected_unreachable": len(l_unexpected_unreachable),
        "missing_include_refs": len(l_missing_refs),
        "allowed_unreachable_files": [
            {
                "file": l_name,
                "reason": ALLOWED_UNREACHABLE_INCLUDES[l_name],
            }
            for l_name in l_allowed_present
        ],
        "unexpected_unreachable_files": l_unexpected_unreachable,
        "missing_refs": l_missing_refs,
    }


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "SIMD_SOURCE_REACHABILITY_SUMMARY "
        f"tracked_includes={a_result['tracked_includes']} "
        f"reachable_includes={a_result['reachable_includes']} "
        f"allowed_unreachable={a_result['allowed_unreachable']} "
        f"unexpected_unreachable={a_result['unexpected_unreachable']} "
        f"missing_include_refs={a_result['missing_include_refs']}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print("[SOURCE-REACHABILITY] SIMD source include reachability")
    print(f"  - tracked include files:      {a_result['tracked_includes']}")
    print(f"  - reachable include files:    {a_result['reachable_includes']}")
    print(f"  - allowed unreachable files:  {a_result['allowed_unreachable']}")
    print(f"  - unexpected unreachable:     {a_result['unexpected_unreachable']}")
    print(f"  - missing include refs:       {a_result['missing_include_refs']}")

    if a_result["allowed_unreachable_files"]:
        print("[SOURCE-REACHABILITY] Allowed audit-only unreachable include files:")
        for l_entry in a_result["allowed_unreachable_files"]:
            print(f"  - {l_entry['file']}: {l_entry['reason']}")

    if a_result["unexpected_unreachable_files"]:
        print("[SOURCE-REACHABILITY] Unexpected unreachable include files:")
        for l_name in a_result["unexpected_unreachable_files"]:
            print(f"  - {l_name}")

    if a_result["missing_refs"]:
        print("[SOURCE-REACHABILITY] Missing SIMD include references:")
        for l_entry in a_result["missing_refs"]:
            print(f"  - {l_entry['owner']} -> {l_entry['include']}")

    if a_result["ok"]:
        print("[SOURCE-REACHABILITY] OK (no unexpected unreachable include files)")


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description="Check SIMD include reachability from live source roots."
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
