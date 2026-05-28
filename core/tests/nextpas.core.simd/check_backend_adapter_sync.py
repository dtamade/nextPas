#!/usr/bin/env python3
"""Check sync between backend.iface, adapter CSV spec, and generated adapter mappings."""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

from generate_backend_adapter_map import load_mapping_rows, mapping_rows_to_dict, normalize_text, render_include_text


RECORD_RE = re.compile(r"(?ms)^\s*(T[A-Za-z0-9_]+)\s*=\s*record\b(.*?)^\s*end;\s*$")
FIELD_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*;\s*$")

FORWARD_RE = re.compile(r"\btable\.([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*ops\.([A-Za-z_][A-Za-z0-9_\.]*)\s*;")
BACKWARD_RE = re.compile(r"\bops\.([A-Za-z_][A-Za-z0-9_\.]*)\s*:=\s*table\.([A-Za-z_][A-Za-z0-9_]*)\s*;")
FORWARD_LINE_RE = re.compile(r"^\s*table\.([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*ops\.([A-Za-z_][A-Za-z0-9_\.]*)\s*;\s*$")
FORWARD_IF_GUARD_RE = re.compile(r"^\s*if\s+Assigned\(ops\.([A-Za-z_][A-Za-z0-9_\.]*)\)\s+then\s*$")
INCLUDE_RE = re.compile(r"^\s*\{\$I\s+([^}]+)\}\s*$", re.IGNORECASE)
IFDEF_RE = re.compile(r"^\s*\{\$IFDEF\s+([A-Za-z_][A-Za-z0-9_]*)\s*\}\s*$", re.IGNORECASE)
IFNDEF_RE = re.compile(r"^\s*\{\$IFNDEF\s+([A-Za-z_][A-Za-z0-9_]*)\s*\}\s*$", re.IGNORECASE)
ELSE_RE = re.compile(r"^\s*\{\$ELSE\s*\}\s*$", re.IGNORECASE)
ENDIF_RE = re.compile(r"^\s*\{\$ENDIF\s*\}\s*$", re.IGNORECASE)
SLOT_RE = re.compile(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:function|procedure)\b")
ASSIGN_RE = re.compile(r"\b(?:dispatchTable|table)\.([A-Za-z_][A-Za-z0-9_]*)\s*:=")



def extract_records(a_text: str) -> dict[str, list[tuple[str, str]]]:
    l_records: dict[str, list[tuple[str, str]]] = {}
    for l_name, l_body in RECORD_RE.findall(a_text):
        l_fields: list[tuple[str, str]] = []
        for l_line in l_body.splitlines():
            l_clean = l_line.split("//", 1)[0].strip()
            if not l_clean:
                continue
            l_match = FIELD_RE.match(l_clean)
            if l_match:
                l_fields.append((l_match.group(1), l_match.group(2)))
        l_records[l_name] = l_fields
    return l_records


def extract_expected_ops_paths(a_iface_text: str) -> list[str]:
    l_records = extract_records(a_iface_text)
    l_ops_fields = l_records.get("TSimdBackendOps")
    if not l_ops_fields:
        raise RuntimeError("TSimdBackendOps record not found in backend.iface")

    l_expected: set[str] = set()
    for l_field_name, l_field_type in l_ops_fields:
        if l_field_name in ("Backend", "BackendInfo"):
            continue
        l_group_fields = l_records.get(l_field_type)
        if l_group_fields is None:
            # Conservative fallback for any future direct function-pointer field.
            l_expected.add(l_field_name)
            continue
        for l_sub_field_name, _ in l_group_fields:
            l_expected.add(f"{l_field_name}.{l_sub_field_name}")

    return sorted(l_expected)


def extract_section(a_text: str, a_start_marker: str, a_end_marker: str) -> str:
    l_start = a_text.find(a_start_marker)
    if l_start < 0:
        raise RuntimeError(f"start marker not found: {a_start_marker}")
    l_end = a_text.find(a_end_marker, l_start)
    if l_end < 0:
        raise RuntimeError(f"end marker not found after {a_start_marker}: {a_end_marker}")
    return a_text[l_start:l_end]


def preprocess_ifdefs(a_text: str, a_defined_symbols: set[str]) -> str:
    l_output_lines: list[str] = []
    l_stack: list[tuple[bool, bool, bool]] = []
    l_active = True

    for l_line in a_text.splitlines():
        l_ifdef = IFDEF_RE.match(l_line)
        if l_ifdef is not None:
            l_cond = l_ifdef.group(1) in a_defined_symbols
            l_stack.append((l_active, l_cond, False))
            l_active = l_active and l_cond
            continue

        l_ifndef = IFNDEF_RE.match(l_line)
        if l_ifndef is not None:
            l_cond = l_ifndef.group(1) not in a_defined_symbols
            l_stack.append((l_active, l_cond, False))
            l_active = l_active and l_cond
            continue

        if ELSE_RE.match(l_line):
            if not l_stack:
                raise RuntimeError("unexpected {$ELSE} without {$IFDEF}/{$IFNDEF}")
            l_parent_active, l_cond, l_seen_else = l_stack.pop()
            if l_seen_else:
                raise RuntimeError("duplicate {$ELSE} in conditional block")
            l_stack.append((l_parent_active, l_cond, True))
            l_active = l_parent_active and (not l_cond)
            continue

        if ENDIF_RE.match(l_line):
            if not l_stack:
                raise RuntimeError("unexpected {$ENDIF} without {$IFDEF}/{$IFNDEF}")
            l_parent_active, _, _ = l_stack.pop()
            l_active = l_parent_active
            continue

        if l_active:
            l_output_lines.append(l_line)

    if l_stack:
        raise RuntimeError("unterminated conditional block in include text")

    return "\n".join(l_output_lines)


def expand_includes(a_section_text: str, a_base_dir: Path, a_defined_symbols: set[str]) -> str:
    l_output_lines: list[str] = []

    for l_line in a_section_text.splitlines():
        l_include = INCLUDE_RE.match(l_line)
        if l_include is None:
            l_output_lines.append(l_line)
            continue

        l_include_name = l_include.group(1).strip().strip("'\"")
        l_include_path = (a_base_dir / l_include_name).resolve()
        if not l_include_path.is_file():
            raise RuntimeError(f"include file not found: {l_include_path}")

        l_include_text = l_include_path.read_text(encoding="utf-8", errors="ignore")
        l_include_processed = preprocess_ifdefs(l_include_text, a_defined_symbols)
        l_output_lines.extend(l_include_processed.splitlines())

    return "\n".join(l_output_lines)


def extract_mapping(
    a_section_text: str,
    a_regex: re.Pattern[str],
    a_ops_group_index: int,
    a_slot_group_index: int,
) -> tuple[dict[str, str], list[dict[str, str]], list[dict[str, str]]]:
    l_mapping: dict[str, str] = {}
    l_path_duplicates: list[dict[str, str]] = []
    l_slot_to_path: dict[str, str] = {}
    l_slot_duplicates: list[dict[str, str]] = []

    for l_match in a_regex.finditer(a_section_text):
        l_slot = l_match.group(a_slot_group_index)
        l_path = l_match.group(a_ops_group_index)
        if l_path in ("Backend", "BackendInfo"):
            continue

        l_old_slot = l_mapping.get(l_path)
        if l_old_slot is not None and l_old_slot != l_slot:
            l_path_duplicates.append({"ops_path": l_path, "slot_old": l_old_slot, "slot_new": l_slot})
        else:
            l_mapping[l_path] = l_slot

        l_old_path = l_slot_to_path.get(l_slot)
        if l_old_path is not None and l_old_path != l_path:
            l_slot_duplicates.append({"slot": l_slot, "ops_path_old": l_old_path, "ops_path_new": l_path})
        else:
            l_slot_to_path[l_slot] = l_path

    return l_mapping, l_path_duplicates, l_slot_duplicates


def read_text_with_local_includes(a_path: Path, a_seen: set[Path] | None = None) -> str:
    if a_seen is None:
        a_seen = set()

    a_path = a_path.resolve()
    if a_path in a_seen:
        return ""
    a_seen.add(a_path)

    l_text = a_path.read_text(encoding="utf-8", errors="ignore")

    def repl(a_match: re.Match[str]) -> str:
        l_include_name = a_match.group(1).strip().strip("'\"")
        l_include_path = (a_path.parent / l_include_name).resolve()
        if not l_include_path.exists():
            return a_match.group(0)
        return read_text_with_local_includes(l_include_path, a_seen)

    return INCLUDE_RE.sub(repl, l_text)


def extract_dispatch_slots(a_dispatch_file: Path) -> list[str]:
    l_text = read_text_with_local_includes(a_dispatch_file).splitlines()
    l_slots: list[str] = []
    l_in_record = False
    for l_line in l_text:
        if not l_in_record:
            if re.search(r"\bTSimdDispatchTable\s*=\s*record\b", l_line):
                l_in_record = True
            continue
        if re.match(r"\s*end;\s*$", l_line):
            break
        l_match = SLOT_RE.match(l_line)
        if l_match:
            l_slots.append(l_match.group(1))
    return l_slots


def extract_assigned_slots(a_text: str, a_slot_set: set[str]) -> set[str]:
    l_assigned = set(ASSIGN_RE.findall(a_text))
    return l_assigned & a_slot_set


def extract_fill_base_section(a_dispatch_text: str) -> str:
    l_impl_parts = a_dispatch_text.split("implementation", 1)
    if len(l_impl_parts) != 2:
        raise RuntimeError("implementation section not found in dispatch")
    l_impl_text = l_impl_parts[1]

    l_start = l_impl_text.rfind("procedure FillBaseDispatchTable")
    if l_start < 0:
        raise RuntimeError("FillBaseDispatchTable implementation not found in dispatch")

    l_rest = l_impl_text[l_start:]
    l_next_proc = re.search(
        r"(?m)^procedure\s+[A-Za-z_][A-Za-z0-9_]*\s*\(",
        l_rest[len("procedure FillBaseDispatchTable"):],
    )
    if l_next_proc is None:
        return l_rest
    return l_rest[: len("procedure FillBaseDispatchTable") + l_next_proc.start()]


def compare_mapping_against_spec(a_spec_map: dict[str, str], a_actual_map: dict[str, str]) -> list[dict[str, str]]:
    l_issues: list[dict[str, str]] = []
    for l_path in sorted(set(a_spec_map) | set(a_actual_map)):
        l_spec_slot = a_spec_map.get(l_path, "")
        l_actual_slot = a_actual_map.get(l_path, "")
        if l_spec_slot != l_actual_slot:
            l_issues.append(
                {
                    "ops_path": l_path,
                    "spec_slot": l_spec_slot,
                    "actual_slot": l_actual_slot,
                }
            )
    return l_issues


def build_text_diff(a_expected_text: str, a_actual_text: str, a_max_lines: int = 40) -> list[str]:
    l_diff = list(
        difflib.unified_diff(
            normalize_text(a_expected_text).splitlines(),
            normalize_text(a_actual_text).splitlines(),
            fromfile="spec-generated",
            tofile="checked-in",
            lineterm="",
        )
    )
    if len(l_diff) <= a_max_lines:
        return l_diff
    return l_diff[:a_max_lines] + [f"... ({len(l_diff) - a_max_lines} more diff lines)"]


def build_report(a_repo_root: Path) -> dict:
    l_iface_file = a_repo_root / "src" / "nextpas.core.simd.backend.iface.pas"
    l_adapter_file = a_repo_root / "src" / "nextpas.core.simd.backend.adapter.pas"
    l_adapter_map_csv_file = a_repo_root / "src" / "nextpas.core.simd.backend.adapter.map.csv"
    l_adapter_map_inc_file = a_repo_root / "src" / "nextpas.core.simd.backend.adapter.map.inc"
    l_dispatch_file = a_repo_root / "src" / "nextpas.core.simd.dispatch.pas"

    if not l_iface_file.is_file():
        raise RuntimeError(f"missing file: {l_iface_file}")
    if not l_adapter_file.is_file():
        raise RuntimeError(f"missing file: {l_adapter_file}")
    if not l_adapter_map_csv_file.is_file():
        raise RuntimeError(f"missing file: {l_adapter_map_csv_file}")
    if not l_adapter_map_inc_file.is_file():
        raise RuntimeError(f"missing file: {l_adapter_map_inc_file}")
    if not l_dispatch_file.is_file():
        raise RuntimeError(f"missing file: {l_dispatch_file}")

    l_iface_text = l_iface_file.read_text(encoding="utf-8", errors="ignore")
    l_adapter_text = l_adapter_file.read_text(encoding="utf-8", errors="ignore")
    l_adapter_map_inc_text = l_adapter_map_inc_file.read_text(encoding="utf-8", errors="ignore")
    l_dispatch_text = read_text_with_local_includes(l_dispatch_file)
    l_adapter_impl = l_adapter_text.split("implementation", 1)
    if len(l_adapter_impl) != 2:
        raise RuntimeError("implementation section not found in backend.adapter")
    l_adapter_impl_text = l_adapter_impl[1]

    l_expected_paths = extract_expected_ops_paths(l_iface_text)
    l_expected_set = set(l_expected_paths)
    l_spec_rows = load_mapping_rows(l_adapter_map_csv_file)
    l_spec_map = mapping_rows_to_dict(l_spec_rows)
    l_spec_paths = sorted(l_spec_map.keys())
    l_spec_set = set(l_spec_paths)
    l_missing_spec_paths = sorted(l_expected_set - l_spec_set)
    l_extra_spec_paths = sorted(l_spec_set - l_expected_set)
    l_generated_include_text = render_include_text(l_spec_rows)
    l_generated_include_drift = []
    if normalize_text(l_adapter_map_inc_text) != normalize_text(l_generated_include_text):
        l_generated_include_drift = build_text_diff(l_generated_include_text, l_adapter_map_inc_text)

    l_forward_section_raw = extract_section(
        l_adapter_impl_text,
        "procedure BackendOpsToDispatchTable",
        "procedure DispatchTableToBackendOps",
    )
    l_backward_section_raw = extract_section(
        l_adapter_impl_text,
        "procedure DispatchTableToBackendOps",
        "procedure RegisterBackendOps",
    )
    l_forward_section = expand_includes(
        a_section_text=l_forward_section_raw,
        a_base_dir=l_adapter_file.parent,
        a_defined_symbols={"FAFAFA_SIMD_BACKEND_ADAPTER_FORWARD"},
    )
    l_backward_section = expand_includes(
        a_section_text=l_backward_section_raw,
        a_base_dir=l_adapter_file.parent,
        a_defined_symbols={"FAFAFA_SIMD_BACKEND_ADAPTER_BACKWARD"},
    )

    l_forward_map, l_forward_path_dups, l_forward_slot_dups = extract_mapping(
        a_section_text=l_forward_section,
        a_regex=FORWARD_RE,
        a_ops_group_index=2,
        a_slot_group_index=1,
    )
    l_backward_map, l_backward_path_dups, l_backward_slot_dups = extract_mapping(
        a_section_text=l_backward_section,
        a_regex=BACKWARD_RE,
        a_ops_group_index=1,
        a_slot_group_index=2,
    )

    l_forward_set = set(l_forward_map.keys())
    l_backward_set = set(l_backward_map.keys())
    l_spec_forward_drift = compare_mapping_against_spec(l_spec_map, l_forward_map)
    l_spec_backward_drift = compare_mapping_against_spec(l_spec_map, l_backward_map)

    l_missing_forward = sorted(l_expected_set - l_forward_set)
    l_missing_backward = sorted(l_expected_set - l_backward_set)
    l_extra_forward = sorted(l_forward_set - l_expected_set)
    l_extra_backward = sorted(l_backward_set - l_expected_set)

    l_mismatched_paths: list[dict[str, str]] = []
    for l_path in sorted(l_expected_set & l_forward_set & l_backward_set):
        l_forward_slot = l_forward_map[l_path]
        l_backward_slot = l_backward_map[l_path]
        if l_forward_slot != l_backward_slot:
            l_mismatched_paths.append(
                {
                    "ops_path": l_path,
                    "forward_slot": l_forward_slot,
                    "backward_slot": l_backward_slot,
                }
            )

    l_unconditional_forward_lines: list[str] = []
    l_forward_lines = l_forward_section.splitlines()
    for l_index, l_line in enumerate(l_forward_lines):
        l_match = FORWARD_LINE_RE.match(l_line)
        if l_match is None:
            continue
        if l_match.group(1) in ("Backend", "BackendInfo"):
            continue

        l_prev_index = l_index - 1
        while l_prev_index >= 0 and l_forward_lines[l_prev_index].strip() == "":
            l_prev_index -= 1

        l_prev_line = l_forward_lines[l_prev_index] if l_prev_index >= 0 else ""
        l_guard_match = FORWARD_IF_GUARD_RE.match(l_prev_line)
        if l_guard_match is not None and l_guard_match.group(1) == l_match.group(2):
            continue

        l_unconditional_forward_lines.append(l_line.strip())

    l_unconditional_forward_lines = sorted(set(l_unconditional_forward_lines))

    l_dispatch_slots = extract_dispatch_slots(l_dispatch_file)
    l_dispatch_slot_set = set(l_dispatch_slots)
    l_mapped_slots = sorted({*l_forward_map.values(), *l_backward_map.values()})
    l_mapped_slot_set = set(l_mapped_slots)
    l_missing_dispatch_slot_defs = sorted(l_mapped_slot_set - l_dispatch_slot_set)

    l_fill_base_section = extract_fill_base_section(l_dispatch_text)
    l_fill_base_assigned_slots = sorted(extract_assigned_slots(l_fill_base_section, l_dispatch_slot_set))
    l_fill_base_assigned_set = set(l_fill_base_assigned_slots)
    l_missing_fill_base_assignments = sorted(l_mapped_slot_set - l_fill_base_assigned_set)

    return {
        "expected_ops_paths_count": len(l_expected_paths),
        "expected_ops_paths": l_expected_paths,
        "spec_paths_count": len(l_spec_paths),
        "spec_paths": l_spec_paths,
        "missing_spec_paths": l_missing_spec_paths,
        "extra_spec_paths": l_extra_spec_paths,
        "generated_include_drift": l_generated_include_drift,
        "forward_mapped_count": len(l_forward_map),
        "backward_mapped_count": len(l_backward_map),
        "spec_forward_drift": l_spec_forward_drift,
        "spec_backward_drift": l_spec_backward_drift,
        "missing_forward": l_missing_forward,
        "missing_backward": l_missing_backward,
        "extra_forward": l_extra_forward,
        "extra_backward": l_extra_backward,
        "mismatched_paths": l_mismatched_paths,
        "forward_path_duplicates": l_forward_path_dups,
        "backward_path_duplicates": l_backward_path_dups,
        "forward_slot_duplicates": l_forward_slot_dups,
        "backward_slot_duplicates": l_backward_slot_dups,
        "unconditional_forward_assignments": l_unconditional_forward_lines,
        "dispatch_slots_total": len(l_dispatch_slots),
        "dispatch_slots": l_dispatch_slots,
        "mapped_slots_unique": l_mapped_slots,
        "mapped_slots_unique_count": len(l_mapped_slots),
        "missing_dispatch_slot_defs": l_missing_dispatch_slot_defs,
        "fill_base_assigned_slots": l_fill_base_assigned_slots,
        "fill_base_assigned_slots_count": len(l_fill_base_assigned_slots),
        "missing_fill_base_assignments": l_missing_fill_base_assignments,
    }


def has_failures(a_report: dict) -> bool:
    return any(
        [
            len(a_report["missing_spec_paths"]) > 0,
            len(a_report["extra_spec_paths"]) > 0,
            len(a_report["generated_include_drift"]) > 0,
            len(a_report["spec_forward_drift"]) > 0,
            len(a_report["spec_backward_drift"]) > 0,
            len(a_report["missing_forward"]) > 0,
            len(a_report["missing_backward"]) > 0,
            len(a_report["extra_forward"]) > 0,
            len(a_report["extra_backward"]) > 0,
            len(a_report["mismatched_paths"]) > 0,
            len(a_report["forward_path_duplicates"]) > 0,
            len(a_report["backward_path_duplicates"]) > 0,
            len(a_report["forward_slot_duplicates"]) > 0,
            len(a_report["backward_slot_duplicates"]) > 0,
            len(a_report["missing_dispatch_slot_defs"]) > 0,
            len(a_report["missing_fill_base_assignments"]) > 0,
        ]
    )


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Check backend.adapter sync with backend.iface")
    l_parser.add_argument("--json", action="store_true", dest="as_json", help="print JSON output")
    l_parser.add_argument("--summary-line", action="store_true", help="print one-line summary for gate logs")
    l_parser.add_argument("--no-strict", action="store_true", help="always exit 0 even when issues are found")
    l_args = l_parser.parse_args()

    l_repo_root = Path(__file__).resolve().parents[2]

    try:
        l_report = build_report(l_repo_root)
    except Exception as l_ex:  # pylint: disable=broad-except
        print(f"[ADAPTER-SYNC] ERROR: {l_ex}")
        return 2

    l_failed = has_failures(l_report)

    if l_args.as_json:
        print(json.dumps(l_report, ensure_ascii=False, indent=2))
    else:
        print("[ADAPTER-SYNC] backend.iface <-> backend.adapter.csv/.inc")
        print(f"  - expected_ops_paths: {l_report['expected_ops_paths_count']}")
        print(f"  - spec_paths: {l_report['spec_paths_count']}")
        print(f"  - mapped_forward: {l_report['forward_mapped_count']}")
        print(f"  - mapped_backward: {l_report['backward_mapped_count']}")
        print(f"  - dispatch_slots_total: {l_report['dispatch_slots_total']}")
        print(f"  - mapped_slots_unique: {l_report['mapped_slots_unique_count']}")
        print(f"  - fill_base_assigned_slots: {l_report['fill_base_assigned_slots_count']}")
        print(
            "  - issues: "
            f"missing_spec={len(l_report['missing_spec_paths'])}, "
            f"extra_spec={len(l_report['extra_spec_paths'])}, "
            f"generated_include_drift={int(bool(l_report['generated_include_drift']))}, "
            f"spec_forward_drift={len(l_report['spec_forward_drift'])}, "
            f"spec_backward_drift={len(l_report['spec_backward_drift'])}, "
            f"missing_forward={len(l_report['missing_forward'])}, "
            f"missing_backward={len(l_report['missing_backward'])}, "
            f"extra_forward={len(l_report['extra_forward'])}, "
            f"extra_backward={len(l_report['extra_backward'])}, "
            f"mismatched={len(l_report['mismatched_paths'])}, "
            f"dup_path={len(l_report['forward_path_duplicates']) + len(l_report['backward_path_duplicates'])}, "
            f"dup_slot={len(l_report['forward_slot_duplicates']) + len(l_report['backward_slot_duplicates'])}, "
            f"unconditional_forward={len(l_report['unconditional_forward_assignments'])}, "
            f"missing_dispatch_slot_defs={len(l_report['missing_dispatch_slot_defs'])}, "
            f"missing_fill_base_assignments={len(l_report['missing_fill_base_assignments'])}"
        )

        if l_report["missing_spec_paths"]:
            for l_item in l_report["missing_spec_paths"][:20]:
                print(f"      missing-spec: {l_item}")
        if l_report["extra_spec_paths"]:
            for l_item in l_report["extra_spec_paths"][:20]:
                print(f"      extra-spec: {l_item}")
        if l_report["generated_include_drift"]:
            for l_item in l_report["generated_include_drift"][:20]:
                print(f"      generated-include-drift: {l_item}")
        if l_report["spec_forward_drift"]:
            for l_item in l_report["spec_forward_drift"][:20]:
                print(
                    "      spec-forward-drift: "
                    f"{l_item['ops_path']} spec={l_item['spec_slot']} actual={l_item['actual_slot']}"
                )
        if l_report["spec_backward_drift"]:
            for l_item in l_report["spec_backward_drift"][:20]:
                print(
                    "      spec-backward-drift: "
                    f"{l_item['ops_path']} spec={l_item['spec_slot']} actual={l_item['actual_slot']}"
                )
        if l_report["missing_forward"]:
            for l_item in l_report["missing_forward"][:20]:
                print(f"      missing-forward: {l_item}")
        if l_report["missing_backward"]:
            for l_item in l_report["missing_backward"][:20]:
                print(f"      missing-backward: {l_item}")
        if l_report["mismatched_paths"]:
            for l_item in l_report["mismatched_paths"][:20]:
                print(
                    "      mismatched: "
                    f"{l_item['ops_path']} forward={l_item['forward_slot']} backward={l_item['backward_slot']}"
                )
        if l_report["unconditional_forward_assignments"]:
            for l_item in l_report["unconditional_forward_assignments"][:20]:
                print(f"      unconditional-forward: {l_item}")
        if l_report["missing_dispatch_slot_defs"]:
            for l_item in l_report["missing_dispatch_slot_defs"][:20]:
                print(f"      missing-dispatch-slot-def: {l_item}")
        if l_report["missing_fill_base_assignments"]:
            for l_item in l_report["missing_fill_base_assignments"][:20]:
                print(f"      missing-fill-base-assignment: {l_item}")

        print("[ADAPTER-SYNC] OK" if not l_failed else "[ADAPTER-SYNC] FAIL")

    if l_args.summary_line:
        print(
            "ADAPTER_SYNC_SUMMARY "
            f"expected={l_report['expected_ops_paths_count']} "
            f"spec={l_report['spec_paths_count']} "
            f"missing_spec={len(l_report['missing_spec_paths'])} "
            f"extra_spec={len(l_report['extra_spec_paths'])} "
            f"generated_include_drift={int(bool(l_report['generated_include_drift']))} "
            f"spec_forward_drift={len(l_report['spec_forward_drift'])} "
            f"spec_backward_drift={len(l_report['spec_backward_drift'])} "
            f"forward={l_report['forward_mapped_count']} "
            f"backward={l_report['backward_mapped_count']} "
            f"missing_forward={len(l_report['missing_forward'])} "
            f"missing_backward={len(l_report['missing_backward'])} "
            f"extra_forward={len(l_report['extra_forward'])} "
            f"extra_backward={len(l_report['extra_backward'])} "
            f"mismatched={len(l_report['mismatched_paths'])} "
            f"dup_path={len(l_report['forward_path_duplicates']) + len(l_report['backward_path_duplicates'])} "
            f"dup_slot={len(l_report['forward_slot_duplicates']) + len(l_report['backward_slot_duplicates'])} "
            f"unconditional_forward={len(l_report['unconditional_forward_assignments'])} "
            f"dispatch_slots_total={l_report['dispatch_slots_total']} "
            f"mapped_slots_unique={l_report['mapped_slots_unique_count']} "
            f"fill_base_assigned={l_report['fill_base_assigned_slots_count']} "
            f"missing_dispatch_slot_defs={len(l_report['missing_dispatch_slot_defs'])} "
            f"missing_fill_base_assignments={len(l_report['missing_fill_base_assignments'])}"
        )

    if l_args.no_strict:
        return 0
    return 1 if l_failed else 0


if __name__ == "__main__":
    sys.exit(main())
